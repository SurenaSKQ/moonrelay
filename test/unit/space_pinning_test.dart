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
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';

void main() {
  group('SettingsService pinnedSpaces', () {
    late SettingsService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = SettingsService();
    });

    test('returns empty set by default', () async {
      final pinned = await service.pinnedSpaces();
      expect(pinned, isEmpty);
    });

    test('persists and retrieves pinned space IDs', () async {
      await service.updatePinnedSpaces({'!a:test', '!b:test'});
      final pinned = await service.pinnedSpaces();
      expect(pinned, containsAll({'!a:test', '!b:test'}));
    });

    test('updating replaces previous values', () async {
      await service.updatePinnedSpaces({'!old:test'});
      await service.updatePinnedSpaces({'!new:test'});
      final pinned = await service.pinnedSpaces();
      expect(pinned, contains('!new:test'));
      expect(pinned, isNot(contains('!old:test')));
    });

    test('handles empty string storage', () async {
      await service.updatePinnedSpaces({});
      final pinned = await service.pinnedSpaces();
      expect(pinned, isEmpty);
    });
  });

  group('SpacePreferences pinning', () {
    late SpacePreferences prefs;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      final service = SettingsService();
      prefs = SpacePreferences(service);
    });

    test('starts with empty pinned set', () async {
      await prefs.load();
      expect(prefs.pinnedSpaces, isEmpty);
    });

    test('togglePinSpace adds a space ID', () async {
      await prefs.load();
      expect(prefs.isSpacePinned('!s:test'), isFalse);

      await prefs.togglePinSpace('!s:test');
      expect(prefs.isSpacePinned('!s:test'), isTrue);
    });

    test('togglePinSpace removes an existing pin', () async {
      await prefs.load();
      await prefs.togglePinSpace('!s:test');
      expect(prefs.isSpacePinned('!s:test'), isTrue);

      await prefs.togglePinSpace('!s:test');
      expect(prefs.isSpacePinned('!s:test'), isFalse);
    });

    test('togglePinSpace notifies listeners', () async {
      await prefs.load();
      int calls = 0;
      prefs.addListener(() => calls++);

      await prefs.togglePinSpace('!s:test');
      expect(calls, greaterThanOrEqualTo(1));
    });

    test('pinnedSpaces returns values matching isSpacePinned', () async {
      await prefs.load();
      await prefs.togglePinSpace('!s:test');

      expect(prefs.pinnedSpaces, contains('!s:test'));
    });
  });
}
