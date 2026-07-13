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

  /// Approximate byte budget for completed entries. Each [Event] is
  /// roughly proportional to its content map size; we use a simple
  /// string-length estimate. 64 MB is enough for several thousand
  /// small pinned messages without bloating the process.
  static const int _maxBytes = 64 * 1024 * 1024;

  final Map<String, Future<Event?>> _inflight = {};
  final Map<String, _Entry> _completed = {};
  final List<String> _lruOrder = [];
  int _bytes = 0;

  String _key(String roomId, String eventId) => '$roomId::$eventId';

  /// Returns a cached or freshly-fetched event. Concurrent callers receive
  /// the same [Future].
  Future<Event?> getEvent(Room room, String eventId) {
    final key = _key(room.id, eventId);
    final cached = _completed[key];
    if (cached != null) {
      _touch(key);
      return Future.value(cached.event);
    }
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
        final key = _key(room.id, eventId);
        final size = _estimateSize(event);
        _completed[key] = _Entry(event: event, size: size);
        _lruOrder.add(key);
        _bytes += size;
        _evictIfNeeded();
      }
      return event;
    } catch (_) {
      return null;
    }
  }

  void _touch(String key) {
    final idx = _lruOrder.indexOf(key);
    if (idx < 0) return;
    if (idx == _lruOrder.length - 1) return;
    _lruOrder.removeAt(idx);
    _lruOrder.add(key);
  }

  void _evictIfNeeded() {
    while (_bytes > _maxBytes && _lruOrder.isNotEmpty) {
      final oldest = _lruOrder.removeAt(0);
      final entry = _completed.remove(oldest);
      if (entry != null) {
        _bytes -= entry.size;
      }
    }
  }

  /// Rough byte estimate for an [Event]. The content map and the
  /// type/keys dominate the size; the rest is small enough to ignore.
  static int _estimateSize(Event event) {
    var bytes = 256; // object header + senderId + originServerTs + ...
    final content = event.content;
    for (final entry in content.entries) {
      bytes += entry.key.length * 2;
      final value = entry.value;
      if (value is String) {
        bytes += value.length * 2;
      } else if (value is Map) {
        // Approximate nested map size by its JSON encoding.
        try {
          bytes += value.toString().length;
        } catch (_) {
          bytes += 64;
        }
      } else {
        bytes += 32;
      }
    }
    return bytes;
  }

  /// Drop all cached entries. Should be called on logout / client disposal.
  void clear() {
    _inflight.clear();
    _completed.clear();
    _lruOrder.clear();
    _bytes = 0;
  }

  /// Diagnostic: total bytes held by the cache.
  int get byteCount => _bytes;
  int get entryCount => _completed.length;
  int get inflightCount => _inflight.length;
}

class _Entry {
  const _Entry({required this.event, required this.size});
  final Event event;
  final int size;
}
