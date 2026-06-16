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
import 'package:matrix/src/utils/space_child.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/helpers/space_hierarchy.dart';

class _MockRoom extends Mock implements Room {}

Room _r(String id, String name, {bool isSpace = true}) {
  final r = _MockRoom();
  when(() => r.id).thenReturn(id);
  when(() => r.getLocalizedDisplayname()).thenReturn(name);
  when(() => r.isSpace).thenReturn(isSpace);
  return r;
}

SParent _sp(String pid) => SpaceParent.fromState(StrippedStateEvent(
    type: EventTypes.SpaceParent,
    stateKey: pid,
    content: {},
    senderId: '@t:l'));

SChild _sc(String cid) => SpaceChild.fromState(StrippedStateEvent(
    type: EventTypes.SpaceChild, stateKey: cid, content: {}, senderId: '@t:l'));

void main() {
  group('buildNavItems', () {
    test('all spaces appear as leaves when no groups defined', () {
      final s1 = _r('!a:test', 'Alpha');
      final s2 = _r('!b:test', 'Beta');
      final s3 = _r('!c:test', 'Gamma');
      final items = buildNavItems([s1, s2, s3], collapsedGroupIds: {});
      expect(items.length, 3);
      expect(items.every((i) => i is NavSpaceLeaf), isTrue);
    });

    test('subspaces appear as standalone leaves by default', () {
      final parent = _r('!p:test', 'Parent');
      final child = _r('!c:test', 'Child');
      stubP(child, ['!p:test']);
      final items = buildNavItems([parent, child], collapsedGroupIds: {});
      expect(items.length, 2);
      expect(items[0], isA<NavSpaceLeaf>());
      expect(items[1], isA<NavSpaceLeaf>());
    });

    test('spaceGroups creates groups, removes children from flat list', () {
      final s1 = _r('!a:test', 'Alpha');
      final s2 = _r('!b:test', 'Beta');
      final s3 = _r('!c:test', 'Gamma');
      final items = buildNavItems([
        s1,
        s2,
        s3
      ], collapsedGroupIds: {}, spaceGroups: {
        '_grp_1': ['!a:test', '!b:test']
      });
      expect(items.length, 2);
      expect(items[0], isA<NavSpaceGroup>());
      expect((items[0] as NavSpaceGroup).children.length, 2);
      expect(items[1], isA<NavSpaceLeaf>());
      expect((items[1] as NavSpaceLeaf).space.id, '!c:test');
    });

    test('collapsedGroupIds controls isExpanded', () {
      final s1 = _r('!a:test', 'Alpha');
      final s2 = _r('!b:test', 'Beta');
      final items = buildNavItems([
        s1,
        s2
      ], collapsedGroupIds: {
        '_grp_1'
      }, spaceGroups: {
        '_grp_1': ['!a:test', '!b:test']
      });
      final group = items[0] as NavSpaceGroup;
      expect(group.isExpanded, isFalse);
    });

    test('respects user order for groups and leaves', () {
      final s1 = _r('!a:test', 'Alpha');
      final s2 = _r('!b:test', 'Beta');
      final s3 = _r('!c:test', 'Gamma');
      final items = buildNavItems([
        s1,
        s2,
        s3
      ], collapsedGroupIds: {}, spaceGroups: {
        '_grp_1': ['!a:test']
      }, order: [
        '!c:test',
        '_grp_1'
      ]);
      expect(items[0].id, '!c:test');
      expect(items[1].id, '_grp_1');
    });

    test('non-space rooms are excluded', () {
      final room = _r('!r:test', 'Room', isSpace: false);
      expect(buildNavItems([room], collapsedGroupIds: {}), isEmpty);
    });
  });

  group('computeAutoGroups', () {
    test('creates groups for roots with subspaces', () {
      final root = _r('!root:test', 'Root');
      final c1 = _r('!c1:test', 'Child1');
      final c2 = _r('!c2:test', 'Child2');
      stubP(root, []);
      stubC(root, ['!c1:test', '!c2:test']);
      stubP(c1, ['!root:test']);
      stubP(c2, ['!root:test']);
      final r = computeAutoGroups([root, c1, c2]);
      expect(r, isNotEmpty);
      expect(r['!root:test'], containsAll(['!c1:test', '!c2:test']));
    });

    test('returns empty when no subspaces', () {
      final root = _r('!r:test', 'Root');
      stubP(root, []);
      stubC(root, []);
      expect(computeAutoGroups([root]), isEmpty);
    });
  });
}

// concise test helpers
void stubP(Room room, List<String> ids) {
  final m = room as _MockRoom;
  when(() => m.spaceParents).thenReturn(ids.map((id) => _sp(id)).toList());
}

void stubC(Room room, List<String> ids) {
  final m = room as _MockRoom;
  when(() => m.spaceChildren).thenReturn(ids.map((id) => _sc(id)).toList());
}

typedef SParent = SpaceParent; // shorter alias for readability
typedef SChild = SpaceChild;
