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
import 'package:moonrelay/src/helpers/room_dates.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  group('formatIsoDay', () {
    test('pads month and day to two digits', () {
      expect(formatIsoDay(DateTime(2024, 1, 5)), '2024-01-05');
    });

    test('leaves two digit values alone', () {
      expect(formatIsoDay(DateTime(2024, 12, 31)), '2024-12-31');
    });

    test('sorts lexicographically the same way it sorts chronologically', () {
      final days = [
        DateTime(2024, 2, 9),
        DateTime(2023, 12, 31),
        DateTime(2024, 10, 1),
      ]..sort();
      final rendered = days.map(formatIsoDay).toList();
      expect(rendered, ['2023-12-31', '2024-02-09', '2024-10-01']);
    });
  });

  group('roomCreatedAt', () {
    late MockRoom room;
    late MockEvent create;

    setUp(() {
      room = MockRoom();
      create = MockEvent();
      when(() => room.getState(EventTypes.RoomCreate))
          .thenReturn(create);
      when(() => create.content).thenReturn(<String, dynamic>{});
    });

    test('parses created_at when the room has one', () {
      when(() => create.content).thenReturn(<String, dynamic>{
        'created_at': '2024-03-09T10:11:12.000Z',
      });
      expect(roomCreatedAt(room), DateTime.utc(2024, 3, 9, 10, 11, 12));
    });

    test('returns null when the room has no create state yet', () {
      when(() => room.getState(EventTypes.RoomCreate)).thenReturn(null);
      expect(roomCreatedAt(room), isNull);
    });

    test('returns null for a pre-2021 room with no created_at', () {
      when(() => create.content).thenReturn(<String, dynamic>{'creator': '@a:b'});
      expect(roomCreatedAt(room), isNull);
    });

    test('returns null for an empty created_at', () {
      when(() => create.content)
          .thenReturn(<String, dynamic>{'created_at': ''});
      expect(roomCreatedAt(room), isNull);
    });

    test('returns null for an unparseable created_at', () {
      when(() => create.content)
          .thenReturn(<String, dynamic>{'created_at': 'not a date'});
      expect(roomCreatedAt(room), isNull);
    });

    test('returns null when created_at is not a string', () {
      when(() => create.content)
          .thenReturn(<String, dynamic>{'created_at': 1234});
      expect(roomCreatedAt(room), isNull);
    });
  });
}
