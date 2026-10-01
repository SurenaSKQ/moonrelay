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

// Read-receipt policy tests.  These pin the rule that broke the
// unread affordance: a receipt names the event the user actually
// reached, and it only ever moves forward.  See WORK_NEEDED.md 8.2.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/read_marker_tracker.dart';

import '../helpers/mocks.dart';

/// Records every `setReadMarker` call so a test can assert on the
/// sequence rather than the final state.
class _RecordingRoom extends Mock implements Room {
  final List<String?> posted = [];

  @override
  String get id => '!room:example.com';

  @override
  Future<void> setReadMarker(
    String? eventId, {
    String? mRead,
    bool? public,
  }) async {
    posted.add(eventId);
  }
}

class _RecordingMirror implements NotificationMirror {
  final List<String> seen = [];

  @override
  void onRoomRead(String roomId, String eventId) => seen.add(eventId);
}

Event _event(String id, {required int ts, EventStatus status = EventStatus.synced}) {
  final e = MockEvent();
  when(() => e.eventId).thenReturn(id);
  when(() => e.status).thenReturn(status);
  when(() => e.originServerTs).thenReturn(
    DateTime.fromMillisecondsSinceEpoch(ts, isUtc: true),
  );
  return e;
}

ReadMarkerTracker _tracker(
  _RecordingRoom room, {
  _RecordingMirror? mirror,
  bool sendReceipts = true,
}) {
  return ReadMarkerTracker(
    room: room,
    sendReceipts: sendReceipts,
    notificationService: mirror,
    onLastSeenChanged: (_) {},
  );
}

void main() {
  group('ReadMarkerTracker posts to the read position', () {
    test('posts the event the viewport is sitting on, not the newest', () {
      final room = _RecordingRoom();
      final events = <Event>[
        _event('newest', ts: 300),
        _event('middle', ts: 200),
        _event('oldest', ts: 100),
      ];

      _tracker(room).markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'oldest'),
      );

      expect(room.posted, ['oldest']);
    });

    test('posts nothing when there is no read position', () {
      final room = _RecordingRoom();
      final events = <Event>[_event('newest', ts: 300)];

      _tracker(room).markRoomReadFromSnapshot(
        TimelineSnapshot.fromEvents(events),
      );

      expect(room.posted, isEmpty);
    });

    test('reads to the oldest visible event when parked at the live edge',
        () {
      final room = _RecordingRoom();
      final events = <Event>[
        _event('newest', ts: 300),
        _event('older', ts: 200),
      ];

      // At the bottom of a reverse list the user sees the newest events,
      // so the oldest of those is the read position.  It is not the
      // newest event in the room.
      _tracker(room).markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'older'),
      );

      expect(room.posted, ['older']);
    });

    test('mirrors the read position even when receipts are off', () {
      final room = _RecordingRoom();
      final mirror = _RecordingMirror();
      final events = <Event>[_event('newest', ts: 300)];

      _tracker(room, mirror: mirror, sendReceipts: false)
          .markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'newest'),
      );

      expect(room.posted, isEmpty);
      expect(mirror.seen, ['newest']);
    });
  });

  // A read receipt is a floor, not a cursor.  Retracting it would
  // resurrect the unread pill the user just cleared, which is the
  // "pill abruptly disappears" complaint in reverse.
  group('ReadMarkerTracker never moves the marker backwards', () {
    test('drops a read position older than the last one posted', () {
      final room = _RecordingRoom();
      final tracker = _tracker(room);
      final events = <Event>[
        _event('newest', ts: 300),
        _event('oldest', ts: 100),
      ];

      tracker.markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'newest'),
      );
      tracker.markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'oldest'),
      );

      expect(room.posted, ['newest']);
    });

    test('drops a repeat of the same position', () {
      final room = _RecordingRoom();
      final tracker = _tracker(room);
      final events = <Event>[_event('ev1', ts: 100)];

      final snapshot =
          TimelineSnapshot.atReadPosition(events, readId: 'ev1');
      tracker.markRoomReadFromSnapshot(snapshot);
      tracker.markRoomReadFromSnapshot(snapshot);

      expect(room.posted, ['ev1']);
    });

    test('accepts a strictly newer position', () {
      final room = _RecordingRoom();
      final tracker = _tracker(room);
      final events = <Event>[
        _event('ev2', ts: 200),
        _event('ev1', ts: 100),
      ];

      tracker.markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'ev1'),
      );
      tracker.markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'ev2'),
      );

      expect(room.posted, ['ev1', 'ev2']);
    });

    test('force overrides the floor', () {
      final room = _RecordingRoom();
      final tracker = _tracker(room);
      final events = <Event>[
        _event('newest', ts: 300),
        _event('oldest', ts: 100),
      ];

      tracker.markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'newest'),
      );
      tracker.markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'oldest'),
        force: true,
      );

      expect(room.posted, ['newest', 'oldest']);
    });

    test('falls back to id dedupe when timestamps are unknown', () {
      final room = _RecordingRoom();
      final tracker = _tracker(room);
      // A raw id with no matching event in the list, so readTs is 0.
      final snapshot = TimelineSnapshot.atReadPosition(
        <Event>[],
        readId: 'un-cached',
      );
      expect(snapshot.readTs, 0);

      tracker.markRoomReadFromSnapshot(snapshot);
      tracker.markRoomReadFromSnapshot(snapshot);

      expect(room.posted, ['un-cached']);
    });

    test('bindRoom clears the floor so a new room starts fresh', () {
      final room = _RecordingRoom();
      final tracker = _tracker(room);
      final events = <Event>[
        _event('newest', ts: 300),
        _event('oldest', ts: 100),
      ];

      tracker.markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'newest'),
      );
      tracker.bindRoom(room);
      tracker.markRoomReadFromSnapshot(
        TimelineSnapshot.atReadPosition(events, readId: 'oldest'),
      );

      expect(room.posted, ['newest', 'oldest']);
    });
  });
}
