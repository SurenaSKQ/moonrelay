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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/helpers/room_avatar.dart';

import '../helpers/mocks.dart';

class _MockRoom extends Mock implements Room {}

/// A direct chat whose `m.room.avatar` points at [roomAvatar], which is what
/// a client writes when the local user is the one who opened it.
Room _dm({
  required Uri? roomAvatar,
  required Uri? counterpartAvatar,
  String counterpartId = '@friend:matrix.org',
}) {
  final room = _MockRoom();
  when(() => room.directChatMatrixID).thenReturn(counterpartId);
  when(() => room.avatar).thenReturn(roomAvatar);

  final counterpart = MockUser();
  when(() => counterpart.id).thenReturn(counterpartId);
  when(() => counterpart.avatarUrl).thenReturn(counterpartAvatar);
  when(() => room.unsafeGetUserFromMemoryOrFallback(counterpartId))
      .thenReturn(counterpart);

  return room;
}

/// A room with no counterpart: a group, or a space.
Room _notADm({required Uri? roomAvatar}) {
  final room = _MockRoom();
  when(() => room.directChatMatrixID).thenReturn(null);
  when(() => room.avatar).thenReturn(roomAvatar);
  return room;
}

void main() {
  group('avatarForRoomList', () {
    test('a DM shows the counterpart, not the room avatar', () {
      // The regression. `Room.avatar` returns the room's `m.room.avatar`
      // first and only falls back to the counterpart's profile, and a client
      // sets that event to the avatar of whoever started the conversation. So
      // a DM you opened yourself came back carrying your own avatar and the
      // sidebar drew your face next to your friend's name.
      final room = _dm(
        roomAvatar: Uri.parse('mxc://matrix.org/mine'),
        counterpartAvatar: Uri.parse('mxc://matrix.org/theirs'),
      );

      expect(
        avatarForRoomList(room),
        Uri.parse('mxc://matrix.org/theirs'),
      );
    });

    test('a DM does not fall back to the room avatar', () {
      // Falling back would reintroduce the bug exactly when the counterpart
      // has no picture of their own: least noticeable, most wrong. The right
      // answer is the initial, which is what the row already shows for every
      // other reason a thumbnail fails.
      final room = _dm(
        roomAvatar: Uri.parse('mxc://matrix.org/mine'),
        counterpartAvatar: null,
      );

      expect(avatarForRoomList(room), isNull);
    });

    test('a DM with no room avatar still shows the counterpart', () {
      final room = _dm(
        roomAvatar: null,
        counterpartAvatar: Uri.parse('mxc://matrix.org/theirs'),
      );

      expect(
        avatarForRoomList(room),
        Uri.parse('mxc://matrix.org/theirs'),
      );
    });

    test('a group room uses its own avatar', () {
      // No counterpart, so the room's own picture is correct and nothing
      // about groups should change.
      final room = _notADm(roomAvatar: Uri.parse('mxc://matrix.org/group'));

      expect(avatarForRoomList(room), Uri.parse('mxc://matrix.org/group'));
    });

    test('a group room with no avatar is null', () {
      expect(avatarForRoomList(_notADm(roomAvatar: null)), isNull);
    });

    test('a space uses its own avatar', () {
      // Spaces are rooms but never DMs, and the picture is the point of one.
      final room = _notADm(roomAvatar: Uri.parse('mxc://matrix.org/space'));

      expect(avatarForRoomList(room), Uri.parse('mxc://matrix.org/space'));
    });
  });
}