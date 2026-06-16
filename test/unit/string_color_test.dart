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

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/string_color.dart';

void main() {
  group('StringColor extension', () {
    test('should return a Color for any non-empty string', () {
      final color = 'hello'.color;
      expect(color, isA<Color>());
    });

    test('should return a dark Color for any non-empty string', () {
      final color = 'hello'.darkColor;
      expect(color, isA<Color>());
    });

    test('should return a light Color for text for any non-empty string', () {
      final color = 'hello'.lightColorText;
      expect(color, isA<Color>());
    });

    test('should return a light Color for avatar for any non-empty string', () {
      final color = 'hello'.lightColorAvatar;
      expect(color, isA<Color>());
    });

    test('.color should be consistent for the same string', () {
      final color1 = 'sameString'.color;
      final color2 = 'sameString'.color;
      expect(color1, equals(color2));
    });

    test('different strings should return different colors', () {
      // It's possible (but extremely unlikely) for two different strings
      // to produce the same color, so we check that they are not always equal.
      // We use multiple pairs to increase confidence.
      final colors = ['A', 'B', 'C', 'D', 'E', 'F'].map((s) => s.color).toSet();
      expect(colors.length, greaterThan(1));
    });

    test('should handle empty string', () {
      // An empty string returns a valid Color (all code units sum to 0).
      expect(''.color, isA<Color>());
    });

    test('.color cache should not affect .darkColor', () {
      final c1 = 'test'.color;
      final c2 = 'test'.darkColor;
      expect(c1, isNot(equals(c2)));
    });

    test('.color returns HSL color with expected lightness ~0.35', () {
      // Extract the HSL lightness from the color.
      final color = 'test'.color;
      final hsl = HSLColor.fromColor(color);
      // The _getColorLight(0.35) is called for .color, so lightness ≈ 0.35.
      expect(hsl.lightness, closeTo(0.35, 0.15));
    });

    test('.darkColor returns HSL color with expected lightness ~0.2', () {
      final color = 'test'.darkColor;
      final hsl = HSLColor.fromColor(color);
      expect(hsl.lightness, closeTo(0.2, 0.1));
    });

    test('.lightColorText returns HSL color with expected lightness ~0.7', () {
      final color = 'test'.lightColorText;
      final hsl = HSLColor.fromColor(color);
      expect(hsl.lightness, closeTo(0.7, 0.1));
    });

    test('.lightColorAvatar returns HSL color with expected lightness ~0.4',
        () {
      final color = 'test'.lightColorAvatar;
      final hsl = HSLColor.fromColor(color);
      expect(hsl.lightness, closeTo(0.4, 0.1));
    });

    test('Unicode strings produce valid colors', () {
      final color = '❤️🔥🌍'.color;
      expect(color, isA<Color>());
      final hsl = HSLColor.fromColor(color);
      expect(hsl.lightness, closeTo(0.35, 0.15));
    });

    test('long strings produce valid colors', () {
      final longString = 'a' * 1000;
      final color = longString.color;
      expect(color, isA<Color>());
    });
  });
}
