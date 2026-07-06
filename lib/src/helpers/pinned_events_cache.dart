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

import 'package:matrix/matrix.dart';

/// A process-wide cache of pinned-event lookups.
///
/// Previously [_PinnedSection] (in the room-info sidebar) and
/// [_SidebarPinnedMessages] (full pinned pane) each independently called
/// [Room.getEventById], which means the same pinned event could be fetched
/// twice per room change.  Worse, when the pinned-only filter is active the
/// timeline [_fetchFilteredEvents] would issue yet another round of fetches.
///
/// This cache deduplicates concurrent and sequential requests so each
/// (roomId, eventId) pair is fetched at most once, and stays in memory until
/// the cache is cleared (e.g. on logout).
class PinnedEventsCache {
  PinnedEventsCache._();

  static final PinnedEventsCache instance = PinnedEventsCache._();

  final Map<String, Future<Event?>> _inflight = {};
  final Map<String, Event> _completed = {};

  /// Maximum number of completed entries to retain. Oldest entries are
  /// evicted first; defaults to 512.
  static const int _maxCompleted = 512;

  String _key(String roomId, String eventId) => '$roomId::$eventId';

  /// Returns a cached or freshly-fetched event. Concurrent callers receive
  /// the same [Future].
  Future<Event?> getEvent(Room room, String eventId) {
    final key = _key(room.id, eventId);
    final cached = _completed[key];
    if (cached != null) return Future.value(cached);
    final inflight = _inflight[key];
    if (inflight != null) return inflight;

    final future = _fetch(room, eventId).whenComplete(() {
      _inflight.remove(key);
    });
    _inflight[key] = future;
    return future;
  }

  Future<Event?> _fetch(Room room, String eventId) async {
    try {
      final event = await room.getEventById(eventId);
      if (event != null) {
        _completed[_key(room.id, eventId)] = event;
        _evictIfNeeded();
      }
      return event;
    } catch (_) {
      return null;
    }
  }

  void _evictIfNeeded() {
    while (_completed.length > _maxCompleted) {
      final oldest = _completed.keys.first;
      _completed.remove(oldest);
    }
  }

  /// Drop all cached entries. Should be called on logout / client disposal.
  void clear() {
    _inflight.clear();
    _completed.clear();
  }
}