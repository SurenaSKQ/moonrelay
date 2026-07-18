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
/// - Resolve the newest *synced* event from [Timeline.events] and POST
///   a `setReadMarker` to the homeserver when the user scrolls or lands
///   on the bottom (gated on [sendReceipts]).
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

  static const Duration _scrollDebounce = Duration(milliseconds: 250);
  static const Duration _lastSeenRefreshDebounce =
      Duration(milliseconds: 250);
  static const int _maxDedupeEntries = 64;

  /// Highest event ID we've already pushed a read-marker for in this
  /// session.  Used to dedupe a few back-to-back identical POSTs during
  /// a single drag (the SDK also dedupes, but a local guard keeps the
  /// network quiet).
  final Set<String> _markReadSent = <String>{};

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
  }

  /// The last [Room.fullyRead] value we observed.  Used by the parent
  /// to drive the jump-to-unread pill.
  String get lastSeenEventId => _lastSeenEventId;

  /// Schedules a debounced mark-read triggered by a scroll event.
  ///
  /// The caller passes a [TimelineSnapshot] -- a tiny value object
  /// holding just the data the tracker needs (length + newest synced
  /// event id).  This avoids retaining the full [Timeline.events]
  /// list as a closure capture on every scroll tick, which is the
  /// dominant allocation cost during rapid scrolling.
  void scheduleOnScroll(TimelineSnapshot snapshot) {
    if (snapshot.isEmpty) return;
    _markReadDebouncer(() => markRoomReadFromSnapshot(snapshot));
  }

  /// Posts a read marker using just the data captured in [snapshot].
  /// Splits the scroll-driven path from the snapshotless path so
  /// callers don't need to assemble an event list for the common case.
  void markRoomReadFromSnapshot(TimelineSnapshot snapshot,
      {bool force = false}) {
    if (snapshot.isEmpty) return;
    final latestId = snapshot.latestSyncedId ?? snapshot.firstId;
    if (latestId.isEmpty) return;

    final alreadySent = !force && _markReadSent.contains(latestId);
    if (!alreadySent) {
      _markReadSent.add(latestId);
      _trimDedupeCache();
      // Mirror locally so a sync tick right after we marked read
      // doesn't re-emit a stale notification.  Done regardless of
      // [sendReceipts]; the user visibly reached the latest message
      // and we shouldn't nag them about it.
      notificationService?.onRoomRead(_room.id, latestId);
    }

    if (!sendReceipts || alreadySent) return;
    unawaited(_sendReadMarker(latestId));
  }

  /// Posts a read marker for the newest synced event in [events].
  ///
  /// [force] bypasses the local "already sent" cache so the caller can
  /// force a marker after navigating to the latest message via the
  /// jump-to-unread affordance.
  void markRoomRead(List<Event> events, {bool force = false}) {
    if (events.isEmpty) return;
    markRoomReadFromSnapshot(TimelineSnapshot.fromEvents(events),
        force: force);
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
    final drop = _markReadSent.length ~/ 4;
    final it = _markReadSent.iterator;
    for (var i = 0; i < drop && it.moveNext(); i++) {
      _markReadSent.remove(it.current);
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
/// the data that [ReadMarkerTracker] needs to decide whether to post a
/// read marker.
///
/// Pass this (instead of the full event list) to
/// [ReadMarkerTracker.scheduleOnScroll] to avoid retaining the entire
/// events list as a closure capture on every scroll tick.  Capturing
/// the full list means the list can't be GC'd while the debounce is
/// pending, which adds up over a long-lived chat session with rapid
/// scrolling.
class TimelineSnapshot {
  /// Creates a snapshot from a fully-materialized [events] list.  Walks
  /// the list once to pick the newest synced event id, falling back to
  /// the first event id when no synced event is present.
  factory TimelineSnapshot.fromEvents(List<Event> events) {
    if (events.isEmpty) {
      return const TimelineSnapshot._(length: 0, firstId: '', latestSyncedId: null);
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
    );
  }

  const TimelineSnapshot._({
    required this.length,
    required this.firstId,
    required this.latestSyncedId,
  });

  /// Convenience constructor for the empty case.
  const TimelineSnapshot.empty()
      : length = 0,
        firstId = '',
        latestSyncedId = null;

  final int length;
  final String firstId;
  final String? latestSyncedId;

  bool get isEmpty => length == 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimelineSnapshot &&
        other.length == length &&
        other.firstId == firstId &&
        other.latestSyncedId == latestSyncedId;
  }

  @override
  int get hashCode => Object.hash(length, firstId, latestSyncedId);
}