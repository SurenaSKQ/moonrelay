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

    test('equality distinguishes different read positions', () {
      final a = TimelineSnapshot.atReadPosition(
        <Event>[_stubEvent(id: 'ev1', status: EventStatus.synced)],
        readId: 'ev1',
      );
      final b = TimelineSnapshot.atReadPosition(
        <Event>[_stubEvent(id: 'ev1', status: EventStatus.synced)],
        readId: 'ev9',
      );
      expect(a, isNot(equals(b)));
    });
  });

  // The read position is the whole point of this value object.  Getting
  // it wrong is what made the timeline mark itself read, so the cases
  // below pin the distinction between "the user read up to here" and
  // "here is the newest event in the cache".
  group('TimelineSnapshot read position', () {
    test('fromEvents carries no read position', () {
      final snapshot = TimelineSnapshot.fromEvents(<Event>[
        _stubEvent(id: 'ev1', status: EventStatus.synced, ts: 10),
      ]);
      expect(snapshot.hasReadPosition, isFalse);
      expect(snapshot.readId, isNull);
    });

    test('atReadPosition reads to the given event, not the newest', () {
      final snapshot = TimelineSnapshot.atReadPosition(
        <Event>[
          _stubEvent(id: 'ev3', status: EventStatus.synced, ts: 30),
          _stubEvent(id: 'ev2', status: EventStatus.synced, ts: 20),
          _stubEvent(id: 'ev1', status: EventStatus.synced, ts: 10),
        ],
        readId: 'ev1',
      );
      expect(snapshot.readId, 'ev1');
      expect(snapshot.readTs, 10);
      // The newest event is still reported, so callers can tell how far
      // behind the read position is.
      expect(snapshot.latestSyncedId, 'ev3');
    });

    test('atReadPosition looks the timestamp up when not supplied', () {
      final snapshot = TimelineSnapshot.atReadPosition(
        <Event>[_stubEvent(id: 'ev7', status: EventStatus.synced, ts: 77)],
        readId: 'ev7',
      );
      expect(snapshot.readTs, 77);
    });

    test('atReadPosition reports 0 for an unknown event', () {
      final snapshot = TimelineSnapshot.atReadPosition(
        <Event>[_stubEvent(id: 'ev1', status: EventStatus.synced, ts: 10)],
        readId: 'not-cached',
      );
      expect(snapshot.readId, 'not-cached');
      expect(snapshot.readTs, 0);
    });
  });
}

/// Builds a [MockEvent] with the minimum fields the snapshot reads.
/// All other members throw if touched, which catches accidental
/// over-coupling between the snapshot and the SDK.
Event _stubEvent({
  required String id,
  required EventStatus status,
  int ts = 0,
}) {
  final event = MockEvent();
  when(() => event.eventId).thenReturn(id);
  when(() => event.status).thenReturn(status);
  when(() => event.originServerTs).thenReturn(
    DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
  );
  return event;
}
