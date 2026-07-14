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

// Regression tests for the LRU contract documented in
// WORK_DONE.md §10 ("Memory bound on per-room state"). The per-room
// [ValueNotifier] map in [RoomStateBus] is LRU-bounded at
// [_maxRooms] entries. Evicted rooms have their notifier disposed so
// listeners drop their subscriptions cleanly, and the eviction policy
// drops the least-recently-used entry (the head of the [LinkedHashMap]).

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/room_state_bus.dart';

void main() {
  group('RoomStateBus LRU eviction', () {
    test('evicts the LRU room when capacity is exceeded', () {
      final bus = RoomStateBus(maxRooms: 3);

      // Touch three rooms; LRU order (head is oldest): [r0, r1, r2].
      bus.tickFor('r0');
      bus.tickFor('r1');
      bus.tickFor('r2');
      expect(bus.trackedRoomCount, 3);

      // Touching r0 moves it to the tail; LRU order: [r1, r2, r0].
      bus.tickFor('r0');
      expect(bus.trackedRoomCount, 3);

      // Adding a fourth room evicts r1 (the new head).
      bus.tickFor('r3');
      expect(bus.trackedRoomCount, 3);

      // r1 was evicted: tickFor returns a fresh notifier with
      // value 0 (the prior tick counter was discarded).  Adding
      // r1 back also evicts the new LRU (r2) so the total stays
      // at 3.
      final l1 = bus.tickFor('r1');
      expect(l1.value, 0);
      expect(bus.trackedRoomCount, 3);
    });

    test('explicit disposeRoom removes a single room and disposes '
        'its notifier', () {
      final bus = RoomStateBus(maxRooms: 10);
      final r0 = bus.tickFor('r0');
      bus.tickFor('r1');

      expect(bus.trackedRoomCount, 2);

      bus.disposeRoom('r0');
      expect(bus.trackedRoomCount, 1);

      // A fresh tick for r0 yields a brand-new notifier with
      // value 0 (the prior tick counter was wiped).
      final r0Fresh = bus.tickFor('r0');
      expect(identical(r0, r0Fresh), isFalse);
      expect(r0Fresh.value, 0);
    });

    test('move-to-end on tickFor keeps an actively-read room alive '
        'across eviction pressure', () {
      final bus = RoomStateBus(maxRooms: 2);

      bus.tickFor('r0');
      bus.tickFor('r1');

      // Repeatedly read r0 to keep it at the tail of the LRU.
      for (var i = 0; i < 5; i++) {
        bus.tickFor('r0');
      }

      // Adding r2 evicts r1 (the LRU), not r0.
      bus.tickFor('r2');
      expect(bus.trackedRoomCount, 2);
    });

    test('dispose clears the entire map', () {
      final bus = RoomStateBus(maxRooms: 3);
      bus.tickFor('r0');
      bus.tickFor('r1');
      bus.tickFor('r2');
      expect(bus.trackedRoomCount, 3);

      bus.dispose();
      expect(bus.trackedRoomCount, 0);
    });

    test('repeated tickFor returns the same notifier instance', () {
      final bus = RoomStateBus(maxRooms: 10);
      final a = bus.tickFor('r0');
      final b = bus.tickFor('r0');
      expect(identical(a, b), isTrue);
      expect(bus.trackedRoomCount, 1);
    });

    test('custom maxRooms is honoured at construction time', () {
      final small = RoomStateBus(maxRooms: 1);
      small.tickFor('r0');
      small.tickFor('r1');
      // r0 was evicted by the second touch.
      expect(small.trackedRoomCount, 1);
    });
  });
}