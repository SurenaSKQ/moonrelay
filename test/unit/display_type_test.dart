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
import 'package:moonrelay/src/settings/display_type.dart';

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
  });

  group('DisplayTypeExtension', () {
    test('modern label is "Modern"', () {
      expect(DisplayType.modern.label, 'Modern');
    });

    test('irc label is "IRC"', () {
      expect(DisplayType.irc.label, 'IRC');
    });

    test('bubbles label is "Bubbles"', () {
      expect(DisplayType.bubbles.label, 'Bubbles');
    });

    test('all labels are non-empty', () {
      for (final type in DisplayType.values) {
        expect(type.label.isNotEmpty, isTrue);
      }
    });
  });
}
