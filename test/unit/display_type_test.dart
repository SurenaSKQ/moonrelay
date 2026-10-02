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

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/display_type.dart';

/// User-facing names for each display type, keyed by the ARB convention
/// `display` + the PascalCase enum name.  Derived from the enum so adding a
/// value without a label is a failing test rather than a blank radio button.
String _labelKey(DisplayType type) {
  final name = type.name;
  return 'display${name[0].toUpperCase()}${name.substring(1)}';
}

void main() {
  group('DisplayType', () {
    test('has exactly three values', () {
      expect(DisplayType.values.length, 3);
      expect(DisplayType.values, contains(DisplayType.modern));
      expect(DisplayType.values, contains(DisplayType.irc));
      expect(DisplayType.values, contains(DisplayType.bubbles));
    });

    test('default value is modern', () {
      // When parsed from index 0, it should be modern
      expect(DisplayType.values[0], DisplayType.modern);
    });

    test('the ordinal is stable, because it is the persisted format', () {
      // SettingsService stores the enum *index*, not the name.  Inserting a
      // value in the middle would silently reinterpret every saved choice.
      expect(DisplayType.values, [
        DisplayType.modern,
        DisplayType.irc,
        DisplayType.bubbles,
      ]);
    });
  });

  group('DisplayType labels', () {
    late Map<String, dynamic> arb;

    setUpAll(() {
      final file = File('lib/src/localization/app_en.arb');
      arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    });

    test('every display type has a non-empty label in the ARB', () {
      for (final type in DisplayType.values) {
        final value = arb[_labelKey(type)];
        expect(
          value,
          isA<String>(),
          reason: 'missing ARB key "${_labelKey(type)}" for $type',
        );
        expect((value! as String).trim(), isNotEmpty);
      }
    });

    // Only the forward direction is asserted.  The reverse ("no unclaimed
    // `display*` key") would need an exclusion list, because `displayName`,
    // `displayNameHint`, and `displayNameUpdated` are profile strings that
    // share the prefix, and that list would go stale the next time one is
    // added.  A missing label is the failure a user can see; an extra key is
    // not.
  });
}
