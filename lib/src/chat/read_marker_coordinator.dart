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

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';

/// Owns the read-marker bookkeeping previously inlined in [ChatTimeline].
///
/// Responsibilities:
///  * Debounces scroll-driven marker updates so a continuous drag emits
///    exactly one network write once the user stops scrolling.
///  * Caches the latest IDs already POSTed so the SDK doesn't get
///    hammered with redundant identical writes.
///  * Honours the user's [SettingsController.sendReadReceipts] toggle.
///  * Mirrors the new marker into [NotificationService.onRoomReadByTimeline]
///    so a sync tick immediately after doesn't re-emit a stale summary.
///
/// The coordinator is created and disposed by the [State] that owns the
/// chat surface; it does not own a [Timeline] reference — the events
/// list is read at refresh time.
class ReadMarkerCoordinator {
  ReadMarkerCoordinator({
    required this.context,
    required this.room,
    required this.canEmit,
    Duration markReadDebounce = const Duration(milliseconds: 250),
  }) : _markReadDebounce = markReadDebounce;

  /// Build context used to resolve [SettingsController], [Logger], and the
  /// optional [NotificationService].
  final BuildContext context;

  /// The room whose read marker we manage.
  final Room room;

  /// Whether marker emission should be attempted at all (e.g. disabled when
  /// the timeline isn't loaded yet, or while a scroll-debounce is active).
  final bool Function() canEmit;

  final Duration _markReadDebounce;

  /// Highest event ID we have already pushed a read-marker for in this
  /// session.  Used to avoid repeatedly POSTing the same marker.
  final Set<String> _markReadSent = <String>{};

  /// Pending debounced mark-read timer.
  Timer? _markReadDebounceTimer;

  /// Schedules a debounced mark-read update.
  ///
  /// Called on every scroll event; coalesces a continuous drag into a
  /// single network request once the user has stopped scrolling.
  void scheduleMarkRoomRead(Timeline? timeline, bool scrollDebounced) {
    if (timeline == null) return;
    if (scrollDebounced) return;
    _markReadDebounceTimer?.cancel();
    _markReadDebounceTimer = Timer(_markReadDebounce, () {
      _markReadDebounceTimer = null;
      markRoomRead(timeline: timeline);
    });
  }

  /// Sends a read receipt for the newest *synced* event in [timeline] so
  /// the server and other clients know the user has seen the latest
  /// messages.
  ///
  /// [force] bypasses the local "already sent" cache and posts the
  /// marker unconditionally.
  void markRoomRead({Timeline? timeline, bool force = false}) {
    if (timeline == null) return;
    final events = timeline.events;
    if (events.isEmpty) return;

    // The newest *synced* event in the cache.  Pending local sends are
    // excluded so we don't try to acknowledge a message the homeserver
    // hasn't yet echoed back.
    String? latestId;
    for (final ev in events) {
      if (ev.status == EventStatus.synced) {
        latestId = ev.eventId;
        break;
      }
    }
    latestId ??= events.first.eventId;
    if (latestId.isEmpty) return;

    final sendReceipts = context.read<SettingsController>().sendReadReceipts;
    final alreadySent = !force && _markReadSent.contains(latestId);
    if (!alreadySent) {
      _markReadSent.add(latestId);
      // Bound the cache so it doesn't grow without limit on busy rooms.
      if (_markReadSent.length > 64) {
        // Drop the oldest quarter; Set preserves insertion order.
        final drop = _markReadSent.length ~/ 4;
        final it = _markReadSent.iterator;
        for (var i = 0; i < drop && it.moveNext(); i++) {
          _markReadSent.remove(it.current);
        }
      }
      // Mirror the new marker into the notification service's local
      // bookkeeping so a sync tick right after we marked read doesn't
      // re-emit a stale summary for a room we just caught up on.  The
      // notification service is optional in the provider tree
      // (desktop-only) so guard with a try/read.
      _maybeNotificationService()?.onRoomReadByTimeline(room.id, latestId);
    }
    if (!sendReceipts) return;
    if (alreadySent) return;
    // Fire-and-forget: a stale [latestId] makes the homeserver reply
    // with `M_UNKNOWN`, which the matrix SDK surfaces as an uncaught
    // [Object]. Swallow it here so a single bad marker doesn't tear
    // down the timeline isolate.
    unawaited(_sendReadMarker(latestId));
  }

  /// Sends a read marker and logs (but does not rethrow) any failure.
  Future<void> _sendReadMarker(String latestId) async {
    Logger? logger;
    try {
      logger = context.read<Logger>();
    } catch (_) {
      logger = null;
    }
    try {
      await room.setReadMarker(latestId, mRead: latestId);
    } catch (err) {
      logger?.w('setReadMarker($latestId) failed; ignoring', error: err);
    }
  }

  /// Returns the notification service if it has been provided in this
  /// widget tree, or `null` on platforms (or in tests) where it isn't
  /// available.
  NotificationService? _maybeNotificationService() {
    try {
      return context.read<NotificationService>();
    } catch (_) {
      return null;
    }
  }

  void dispose() {
    _markReadDebounceTimer?.cancel();
    _markReadDebounceTimer = null;
  }
}
