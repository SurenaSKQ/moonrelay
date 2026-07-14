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
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Process-wide fan-out for [Client.onRoomState] events.
///
/// Without this, every widget that needs to react to room state (the
/// right sidebar's `_SidebarRoomInfo`, the members list, the
/// encryption badge, etc.) subscribes its own listener and filters
/// client-side for the relevant room. For a 200-room account every
/// state event traverses every listener — measurable wasted work for
/// the kind of high-frequency events the right sidebar cares about
/// (display name, topic, join rules).
///
/// [RoomStateBus] exposes per-room [ValueListenable]s that consumers
/// can subscribe to with O(1) work; the bus only sees one stream
/// subscription regardless of how many consumers there are.
///
/// Memory bound: the per-room [ValueNotifier] map is LRU-bounded at
/// [_maxRooms] entries. Evicted rooms have their notifier disposed
/// (so listeners drop their subscriptions cleanly) and are removed
/// from the tick counter so a stale "v2" never leaks into a fresh
/// allocation of the same room id.
class RoomStateBus extends ChangeNotifier {
  RoomStateBus({int maxRooms = 500}) : _maxRooms = maxRooms;

  /// Hard cap on tracked rooms. Sized to comfortably hold an entire
  /// large Matrix account (≥500 rooms) without unbounded growth, while
  /// still being small enough that an accidental subscription storm
  /// doesn't OOM the process.
  final int _maxRooms;

  /// One [ValueNotifier] per room id. Lazily allocated the first time
  /// a consumer asks for the room. Backed by a [LinkedHashMap] so we
  /// can implement LRU eviction with O(1) move-to-end semantics.
  final LinkedHashMap<String, ValueNotifier<int>> _perRoomTick =
      LinkedHashMap<String, ValueNotifier<int>>();

  /// Monotonically increasing tick per room; consumers use the value
  /// to know "something changed" without storing the event itself.
  final Map<String, int> _ticks = <String, int>{};

  StreamSubscription<dynamic>? _sub;

  /// Starts the underlying subscription. Idempotent.
  void bind(Client client) {
    if (_sub != null) return;
    _sub = client.onRoomState.stream.listen((event) {
      _onState(event.roomId);
    });
  }

  void _onState(String roomId) {
    final next = (_ticks[roomId] ?? 0) + 1;
    _ticks[roomId] = next;
    final notifier = _perRoomTick[roomId];
    if (notifier != null) {
      // Move-to-end: most-recently-used rooms sit at the tail so the
      // eviction policy below drops the head (least-recently used).
      _perRoomTick.remove(roomId);
      _perRoomTick[roomId] = notifier;
      notifier.value = next;
    }
    _evictIfOverCapacity();
  }

  /// Returns a [ValueListenable] that ticks every time a state event
  /// for [roomId] arrives on the client's [Client.onRoomState] stream.
  /// The same instance is returned for repeated calls so subscribers
  /// share the listener.
  ValueListenable<int> tickFor(String roomId) {
    final existing = _perRoomTick[roomId];
    if (existing != null) {
      // Touch: move-to-end on read so an idle screen that opens and
      // closes without state changes still keeps the room alive.
      _perRoomTick.remove(roomId);
      _perRoomTick[roomId] = existing;
      return existing;
    }
    final notifier = ValueNotifier<int>(_ticks[roomId] ?? 0);
    _perRoomTick[roomId] = notifier;
    _evictIfOverCapacity();
    return notifier;
  }

  /// Drops the bus state for [roomId] (e.g. on room leave). The
  /// returned notifier — if any — is disposed.
  void disposeRoom(String roomId) {
    final notifier = _perRoomTick.remove(roomId);
    notifier?.dispose();
    _ticks.remove(roomId);
  }

  /// Removes the least-recently-used entries until the map is at or
  /// below [_maxRooms].  O(1) amortised because [LinkedHashMap] keeps
  /// insertion order — the head is always the LRU entry.
  void _evictIfOverCapacity() {
    while (_perRoomTick.length > _maxRooms) {
      final oldestKey = _perRoomTick.keys.first;
      final notifier = _perRoomTick.remove(oldestKey);
      notifier?.dispose();
      _ticks.remove(oldestKey);
    }
  }

  /// Read-only count of currently-tracked rooms. Exposed for tests.
  @visibleForTesting
  int get trackedRoomCount => _perRoomTick.length;

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    for (final notifier in _perRoomTick.values) {
      notifier.dispose();
    }
    _perRoomTick.clear();
    _ticks.clear();
    super.dispose();
  }
}
