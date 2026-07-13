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
class RoomStateBus extends ChangeNotifier {
  RoomStateBus();

  /// One [ValueNotifier] per room id. Lazily allocated the first time
  /// a consumer asks for the room.
  final Map<String, ValueNotifier<int>> _perRoomTick = {};

  /// Monotonically increasing tick per room; consumers use the value
  /// to know "something changed" without storing the event itself.
  final Map<String, int> _ticks = {};

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
    _perRoomTick[roomId]?.value = next;
  }

  /// Returns a [ValueListenable] that ticks every time a state event
  /// for [roomId] arrives on the client's [Client.onRoomState] stream.
  /// The same instance is returned for repeated calls so subscribers
  /// share the listener.
  ValueListenable<int> tickFor(String roomId) {
    final existing = _perRoomTick[roomId];
    if (existing != null) return existing;
    final notifier = ValueNotifier<int>(_ticks[roomId] ?? 0);
    _perRoomTick[roomId] = notifier;
    return notifier;
  }

  /// Drops the bus state for [roomId] (e.g. on room leave). The
  /// returned notifier — if any — is disposed.
  void disposeRoom(String roomId) {
    final notifier = _perRoomTick.remove(roomId);
    notifier?.dispose();
    _ticks.remove(roomId);
  }

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
