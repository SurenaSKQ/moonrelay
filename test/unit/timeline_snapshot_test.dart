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

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/read_marker_tracker.dart';

import '../helpers/mocks.dart';

void main() {
  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('TimelineSnapshot', () {
    test('isEmpty is true for the empty constructor', () {
      const snapshot = TimelineSnapshot.empty();
      expect(snapshot.isEmpty, isTrue);
      expect(snapshot.length, 0);
      expect(snapshot.firstId, '');
      expect(snapshot.latestSyncedId, isNull);
    });

    test('fromEvents handles empty input', () {
      final snapshot = TimelineSnapshot.fromEvents(<Event>[]);
      expect(snapshot.isEmpty, isTrue);
    });

    test('fromEvents picks newest synced event id', () {
      final events = <Event>[
        _stubEvent(id: 'ev1', status: EventStatus.sent),
        _stubEvent(id: 'ev2', status: EventStatus.synced),
        _stubEvent(id: 'ev3', status: EventStatus.sending),
      ];
      final snapshot = TimelineSnapshot.fromEvents(events);
      expect(snapshot.length, 3);
      expect(snapshot.firstId, 'ev1');
      expect(snapshot.latestSyncedId, 'ev2');
    });

    test('fromEvents falls back to first id when nothing synced', () {
      final events = <Event>[
        _stubEvent(id: 'ev1', status: EventStatus.sending),
        _stubEvent(id: 'ev2', status: EventStatus.error),
      ];
      final snapshot = TimelineSnapshot.fromEvents(events);
      expect(snapshot.firstId, 'ev1');
      expect(snapshot.latestSyncedId, isNull);
    });

    test('equality holds for identical snapshots', () {
      final a = TimelineSnapshot.fromEvents(<Event>[
        _stubEvent(id: 'ev1', status: EventStatus.synced),
      ]);
      final b = TimelineSnapshot.fromEvents(<Event>[
        _stubEvent(id: 'ev1', status: EventStatus.synced),
      ]);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('equality distinguishes different ids', () {
      final a = TimelineSnapshot.fromEvents(<Event>[
        _stubEvent(id: 'ev1', status: EventStatus.synced),
      ]);
      final b = TimelineSnapshot.fromEvents(<Event>[
        _stubEvent(id: 'ev2', status: EventStatus.synced),
      ]);
      expect(a, isNot(equals(b)));
    });
  });
}

/// Builds a [MockEvent] with the minimum fields the snapshot walks.
/// All other members throw if touched, which catches accidental
/// over-coupling between the snapshot and the SDK.
Event _stubEvent({required String id, required EventStatus status}) {
  final event = MockEvent();
  when(() => event.eventId).thenReturn(id);
  when(() => event.status).thenReturn(status);
  return event;
}
