// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.

// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';

import 'package:moonrelay/src/helpers/debouncer.dart';

/// Owns the read-receipt plumbing for the chat timeline.
///
/// Responsibilities:
/// - Resolve the *read position* (the oldest event still on screen) and
///   POST a `setReadMarker` for it when the user stops scrolling, or for
///   the newest synced event when the viewport is parked at the live
///   edge (gated on [sendReceipts]).
/// - Never move the marker backwards. A receipt is a floor, not a
///   cursor: scrolling back up must not resurrect the unread pill.
/// - Debounce scroll-driven marks so a single drag fires at most one
///   request.
/// - Mirror locally-tracked markers into a [NotificationMirror] so a
///   sync tick right after we marked read doesn't re-emit a stale
///   notification.
/// - Sample [Room.fullyRead] on every parent build (the SDK mutates
///   it on sync) and notify via a debounce so a window resize doesn't
///   fire dozens of state mutations per second.
///
/// The tracker is constructed with the values it needs (room, settings
/// gate, optional notification mirror) so its methods don't reach into
/// [BuildContext] -- keeping it testable without a widget tree.  Use
/// [bindRoom] to re-target a different room; the tracker clears its
/// dedupe cache but keeps its debounce timers.
class ReadMarkerTracker {
  ReadMarkerTracker({
    required Room room,
    required this.sendReceipts,
    required this.notificationService,
    required this.onLastSeenChanged,
    this.logger,
  }) : _room = room;

  /// The room this tracker currently posts read receipts to.  Mutable
  /// via [bindRoom] so the same tracker can follow a parent widget
  /// across room switches without recreating the debounce timers.
  Room _room;

  bool sendReceipts;
  final NotificationMirror? notificationService;
  final Logger? logger;

  /// Fires when [scheduleLastSeenRefresh] observes a change in
  /// [Room.fullyRead].  The parent uses this to refresh its own
  /// pill-dismissed bookkeeping.
  final ValueChanged<String> onLastSeenChanged;

  /// Trailing debounce on the scroll-driven path.  Long enough to be a
  /// dwell rather than a tick, so a fling that ends mid-history does not
  /// leave a receipt behind for a screen the user only flew past.
  static const Duration _scrollDebounce = Duration(milliseconds: 400);
  static const Duration _lastSeenRefreshDebounce =
      Duration(milliseconds: 250);
  static const int _maxDedupeEntries = 64;

  /// Event ids we have already posted a read marker for in this session.
  /// The primary dedupe is [_lastSentTs], which orders correctly; this
  /// set is the fallback for candidates whose timestamp we could not
  /// read, and it keeps a settled viewport from re-POSTing on every
  /// scroll tick.
  final Set<String> _markReadSent = <String>{};

  /// Server timestamp of the newest marker we have posted.  This is the
  /// monotonic floor described in the class docs: a candidate whose
  /// timestamp is not strictly newer is dropped.
  int _lastSentTs = 0;

  /// Cached last-seen event id from [Room.fullyRead].  Sampled via the
  /// [_lastSeenDebouncer] so a burst of build()s only causes one
  /// mutation.
  String _lastSeenEventId = '';

  final Debouncer _markReadDebouncer =
      Debouncer(_scrollDebounce);
  final Debouncer _lastSeenDebouncer =
      Debouncer(_lastSeenRefreshDebounce);

  /// Re-targets the tracker to a different room and clears the dedupe
  /// cache so the next mark-read in the new room always fires.
  void bindRoom(Room room) {
    _room = room;
    _markReadSent.clear();
    _lastSentTs = 0;
  }

  /// The last [Room.fullyRead] value we observed.  Used by the parent
  /// to drive the jump-to-unread pill.
  String get lastSeenEventId => _lastSeenEventId;

  /// Schedules a debounced mark-read triggered by a scroll event.
  ///
  /// [snapshot] must carry a real read position (see
  /// [TimelineSnapshot.atReadPosition]).  A snapshot without one is
  /// ignored rather than defaulted to the newest event: guessing
  /// "newest" is what made merely opening a room mark it read.
  void scheduleOnScroll(TimelineSnapshot snapshot) {
    if (!snapshot.hasReadPosition) return;
    _markReadDebouncer(() => markRoomReadFromSnapshot(snapshot));
  }

  /// Posts a read marker for the read position carried by [snapshot].
  ///
  /// There is deliberately no "mark everything read" overload.  The
  /// read position is always the oldest event on screen, so the whole
  /// conversation has a single rule attached to it: the receipt names
  /// what the user can see, never the newest event in the cache.
  void markRoomReadFromSnapshot(TimelineSnapshot snapshot,
      {bool force = false}) {
    final readId = snapshot.readId;
    if (readId == null || readId.isEmpty) return;

    // A receipt is a floor, not a cursor.  Once we have told the server
    // the user read up to N, scrolling back up must not retract it.
    // The timestamp is the reliable ordering key; when it is unknown,
    // fall back to remembering the ids we have already sent so a
    // settled viewport does not re-POST on every scroll tick.
    final ts = snapshot.readTs;
    if (!force) {
      if (ts > 0) {
        if (ts <= _lastSentTs) return;
      } else if (_markReadSent.contains(readId)) {
        return;
      }
    }

    _markReadSent.add(readId);
    if (ts > 0) _lastSentTs = ts;
    _trimDedupeCache();

    // Mirror locally so a sync tick right after we marked read doesn't
    // re-emit a stale notification.  Done regardless of [sendReceipts];
    // the user visibly reached this event and we shouldn't nag them.
    notificationService?.onRoomRead(_room.id, readId);

    if (!sendReceipts) return;
    unawaited(_sendReadMarker(readId));
  }

  /// Triggers a debounced refresh of [_lastSeenEventId] from the room's
  /// fullyRead account data.  Called from the parent's `build` so any
  /// layout-driven rebuild still picks up the SDK's sync updates.
  void scheduleLastSeenRefresh(String fullyRead) {
    if (_lastSeenDebouncer.isPending) return;
    _lastSeenDebouncer(() {
      if (fullyRead != _lastSeenEventId) {
        _lastSeenEventId = fullyRead;
        onLastSeenChanged(fullyRead);
      }
    });
  }

  /// Forgets the last-seen marker.  Called when the room id changes so
  /// the new room starts with an empty "did the marker advance?" cache.
  void resetForRoom() {
    _lastSeenEventId = '';
  }

  /// Releases any pending timers.  Called from the owning [State]'s
  /// `dispose()`.
  void dispose() {
    _markReadDebouncer.cancel();
    _lastSeenDebouncer.cancel();
  }

  // -- Internals ------------------------------------------------

  Future<void> _sendReadMarker(String latestId) async {
    try {
      await _room.setReadMarker(latestId, mRead: latestId);
    } catch (err) {
      logger?.w('setReadMarker($latestId) failed; ignoring', error: err);
    }
  }

  void _trimDedupeCache() {
    if (_markReadSent.length <= _maxDedupeEntries) return;
    // Snapshot the set before removing so we never mutate it while
    // iterating (Set.iterator throws ConcurrentModificationError).
    // Insertion order is preserved, so the first `drop` entries are the
    // oldest marks.
    final drop = _markReadSent.length ~/ 4;
    final ids = _markReadSent.toList(growable: false);
    for (var i = 0; i < drop; i++) {
      _markReadSent.remove(ids[i]);
    }
  }
}

/// Narrow dependency the tracker uses to mirror local read receipts
/// into the notification service.  Decouples the tracker from the
/// service class so tests can pass a no-op implementation.
abstract class NotificationMirror {
  void onRoomRead(String roomId, String eventId);
}

/// No-op mirror used when the notification service is not provided
/// (mobile builds, tests).
class NoopNotificationMirror implements NotificationMirror {
  const NoopNotificationMirror();
  @override
  void onRoomRead(String roomId, String eventId) {}
}

/// Lightweight projection of the [Timeline.events] list, holding just
/// the data that [ReadMarkerTracker] needs to decide whether to post
/// a read marker.
///
/// Pass this (instead of the full event list) to
/// [ReadMarkerTracker.scheduleOnScroll] to avoid retaining the entire
/// events list as a closure capture on every scroll tick.
///
/// [readId] is the important field: it is the event the user has
/// actually reached, which is the oldest event still on screen and not
/// the newest event in the cache.  A snapshot with no read position is
/// deliberately inert, because "assume the newest" is
/// indistinguishable from "the user read everything" and silently
/// retires the unread affordance.
class TimelineSnapshot {
  /// Creates a snapshot from a fully-materialized [events] list.  Walks
  /// the list once to pick the newest synced event id, falling back to
  /// the first event id when no synced event is present.
  ///
  /// The result carries no read position; use [atReadPosition] for a
  /// snapshot the tracker will act on.
  factory TimelineSnapshot.fromEvents(List<Event> events) {
    if (events.isEmpty) {
      return const TimelineSnapshot._(
        length: 0,
        firstId: '',
        latestSyncedId: null,
        readId: null,
        readTs: 0,
      );
    }
    String? synced;
    for (final ev in events) {
      if (ev.status == EventStatus.synced) {
        synced = ev.eventId;
        break;
      }
    }
    return TimelineSnapshot._(
      length: events.length,
      firstId: events.first.eventId,
      latestSyncedId: synced,
      readId: null,
      readTs: 0,
    );
  }

  /// Snapshot for a viewport that has settled at [readId], the oldest
  /// event still visible.  [readTs] is that event's `originServerTs` and
  /// drives the tracker's monotonic guard; pass 0 to have it looked up
  /// in [events], and if that also fails the tracker falls back to
  /// id-based dedupe.
  factory TimelineSnapshot.atReadPosition(
    List<Event> events, {
    required String readId,
    int readTs = 0,
  }) {
    final base = TimelineSnapshot.fromEvents(events);
    return TimelineSnapshot._(
      length: base.length,
      firstId: base.firstId,
      latestSyncedId: base.latestSyncedId,
      readId: readId,
      readTs: readTs != 0 ? readTs : _timestampOf(events, readId),
    );
  }

  /// Origin timestamp of [id] within [events], or 0 when absent.
  ///
  /// Best-effort by design: the timestamp only feeds the monotonic
  /// dedupe guard, so failing to read one must degrade to id-based
  /// dedupe rather than block the receipt.  An exception escaping here
  /// would propagate into the scroll and jump handlers that triggered
  /// it, which is how a read receipt ends up breaking navigation.
  static int _timestampOf(List<Event> events, String id) {
    try {
      for (final ev in events) {
        if (ev.eventId == id) return ev.originServerTs.millisecondsSinceEpoch;
      }
    } catch (_) {
      // Expected only from partially-stubbed events in tests; a real
      // Event always answers.  0 is the documented "unknown" value.
    }
    return 0;
  }

  const TimelineSnapshot._({
    required this.length,
    required this.firstId,
    required this.latestSyncedId,
    required this.readId,
    required this.readTs,
  });

  /// Convenience constructor for the empty case.
  const TimelineSnapshot.empty()
      : length = 0,
        firstId = '',
        latestSyncedId = null,
        readId = null,
        readTs = 0;

  final int length;
  final String firstId;
  final String? latestSyncedId;

  /// Event the user has read up to, or null when unknown.
  final String? readId;

  /// `originServerTs` of [readId], or 0 when unknown.
  final int readTs;

  bool get isEmpty => length == 0;

  /// True when there is a concrete event to post a receipt for.
  bool get hasReadPosition => readId != null && readId!.isNotEmpty;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimelineSnapshot &&
        other.length == length &&
        other.firstId == firstId &&
        other.latestSyncedId == latestSyncedId &&
        other.readId == readId &&
        other.readTs == readTs;
  }

  @override
  int get hashCode =>
      Object.hash(length, firstId, latestSyncedId, readId, readTs);
}