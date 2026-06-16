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
import 'package:moonrelay/src/helpers/navigation_state.dart';

void main() {
  group('NavigationState', () {
    late NavigationState nav;

    setUp(() {
      nav = NavigationState();
    });

    test('starts with "All" selected by default', () {
      expect(nav.isAll, isTrue);
      expect(nav.isHome, isFalse);
      expect(nav.isSpace, isFalse);
      expect(nav.selectedId, equals('___all___'));
    });

    test('selectHome switches to Home', () {
      nav.selectHome();
      expect(nav.isHome, isTrue);
      expect(nav.isAll, isFalse);
      expect(nav.isSpace, isFalse);
      expect(nav.selectedId, equals('___home___'));
    });

    test('selectAll switches to All', () {
      nav.selectHome();
      expect(nav.isHome, isTrue);

      nav.selectAll();
      expect(nav.isAll, isTrue);
      expect(nav.isHome, isFalse);
      expect(nav.isSpace, isFalse);
      expect(nav.selectedId, equals('___all___'));
    });

    test('selectSpace switches to a specific space', () {
      const spaceId = '!space123:example.org';
      nav.selectSpace(spaceId);

      expect(nav.isSpace, isTrue);
      expect(nav.isHome, isFalse);
      expect(nav.isAll, isFalse);
      expect(nav.selectedId, equals(spaceId));
    });

    test('selectHome from space switches to Home', () {
      nav.selectSpace('!space123:example.org');
      expect(nav.isSpace, isTrue);

      nav.selectHome();
      expect(nav.isHome, isTrue);
      expect(nav.isSpace, isFalse);
    });

    test('re-selecting the same destination is a no-op', () {
      int calls = 0;
      nav.addListener(() => calls++);

      // Selecting same value should not notify.
      nav.selectAll();
      expect(calls, equals(0));

      nav.selectAll();
      expect(calls, equals(0));
    });

    test('selecting a different destination notifies', () {
      int calls = 0;
      nav.addListener(() => calls++);

      nav.selectHome();
      expect(calls, equals(1));

      nav.selectSpace('!space:test');
      expect(calls, equals(2));
    });

    test('isSpace is true for any non-home, non-all ID', () {
      nav.selectSpace('!custom:server.org');
      expect(nav.isSpace, isTrue);

      nav.selectSpace('!another:space');
      expect(nav.isSpace, isTrue);
    });
  });
}
