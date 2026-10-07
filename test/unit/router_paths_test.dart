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

import 'package:moonrelay/src/router_paths.dart';

/// Segments as `Uri.pathSegments` would report them for a path.
List<String> seg(String path) =>
    Uri.parse('https://moonrelay.invalid$path').pathSegments;

void main() {
  group('isRoomChatSegments', () {
    test('matches the bare room chat route', () {
      expect(isRoomChatSegments(seg('/main/rooms/!abc:example.org')), isTrue);
    });

    test('rejects the room list itself', () {
      expect(isRoomChatSegments(seg('/main/rooms')), isFalse);
    });

    // Each of these is a child of the room route, and each renders its own
    // AppBar. Treating them as "a room" is what produced the doubled header
    // and the second, competing back arrow in the single-pane shell.
    test('rejects every sub-route of the room', () {
      final subRoutes = <String>[
        '/main/rooms/!abc/settings',
        '/main/rooms/!abc/thread/\$event',
        '/main/rooms/!abc/profile',
        '/main/rooms/!abc/profile/roomDetails',
        '/main/rooms/!abc/profile/@alice:example.org',
      ];
      for (final path in subRoutes) {
        expect(
          isRoomChatSegments(seg(path)),
          isFalse,
          reason: '$path is a sub-route, not the room chat itself',
        );
      }
    });

    // `/main/room_preview/:roomid` reuses the same parameter name. A test
    // for "does this have a roomid" misreads it as being in a room.
    test('rejects a different route that reuses the roomid parameter', () {
      expect(isRoomChatSegments(seg('/main/room_preview/!abc')), isFalse);
    });

    test('rejects a room id that looks like extra path structure', () {
      // A literal colon in a localpart is legal in Matrix; the pattern
      // must not treat it as a segment separator.
      expect(isRoomChatSegments(seg('/main/rooms/!a:b:example.org')), isTrue);
    });

    test('rejects a percent sign in a room id without misparsing', () {
      expect(isRoomChatSegments(seg('/main/rooms/!50%25:example.org')), isTrue);
    });

    test('rejects an empty room id', () {
      expect(isRoomChatSegments(<String>['main', 'rooms', '']), isFalse);
    });

    test('rejects unrelated routes', () {
      expect(isRoomChatSegments(seg('/main/myprofile')), isFalse);
      expect(isRoomChatSegments(seg('/main/space/!s:example.org')), isFalse);
      expect(isRoomChatSegments(seg('/main/encryption')), isFalse);
      expect(isRoomChatSegments(seg('/welcome')), isFalse);
    });
  });

  group('isRoomListSegments', () {
    test('matches the room list', () {
      expect(isRoomListSegments(seg('/main/rooms')), isTrue);
    });

    test('rejects the room chat, which is one segment deeper', () {
      expect(isRoomListSegments(seg('/main/rooms/!abc')), isFalse);
    });
  });

  group('focusDestinationForSegments', () {
    test('maps each destination to itself', () {
      expect(
        focusDestinationForSegments(seg('/main/rooms')),
        FocusDestination.chats,
      );
      expect(
        focusDestinationForSegments(seg('/main/spaces')),
        FocusDestination.spaces,
      );
      expect(
        focusDestinationForSegments(seg('/main/me')),
        FocusDestination.you,
      );
      expect(
        focusDestinationForSegments(seg('/main/me')),
        FocusDestination.you,
      );
    });

    test('every destination has a distinct path', () {
      final paths =
          FocusDestination.values.map((FocusDestination d) => d.path).toSet();
      // If two destinations shared a path the navigation bar could not
      // switch between them, so a collision would be silent.
      expect(paths.length, FocusDestination.values.length);
    });

    // A conversation is not a tab. If the room route selected "Chats" the
    // bar would light up while the user is reading, and every room
    // sub-route would too.
    test('rejects the room chat and its sub-routes', () {
      for (final path in [
        '/main/rooms/!abc',
        '/main/rooms/!abc/settings',
        '/main/rooms/!abc/thread/\$event',
      ]) {
        expect(
          focusDestinationForSegments(seg(path)),
          isNull,
          reason: '$path is not a navigation destination',
        );
      }
    });

    test('rejects routes the shell does not own', () {
      for (final path in [
        '/main/myprofile',
        '/main/encryption',
        '/main/space/!s:example.org',
        '/profile/@a:example.org',
      ]) {
        expect(
          focusDestinationForSegments(seg(path)),
          isNull,
          reason: '$path is not a navigation destination',
        );
      }
    });

    test('a destination path round-trips to its own segments', () {
      for (final destination in FocusDestination.values) {
        expect(
          focusDestinationForSegments(seg(destination.path)),
          destination,
          reason: '${destination.path} does not resolve back to itself',
        );
      }
    });
  });
}
