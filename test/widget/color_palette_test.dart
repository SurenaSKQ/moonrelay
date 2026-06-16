import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/color_palette.dart';

void main() {
  group('MoonrelayColorPalette', () {
    test('has expected constant colors', () {
      expect(MoonrelayColorPalette.blackChocolate, isA<Color>());
      expect(MoonrelayColorPalette.ordinaryRed, isA<Color>());
      expect(MoonrelayColorPalette.ordinaryBlue, isA<Color>());
      expect(MoonrelayColorPalette.cpgDarkest, isA<Color>());
      expect(MoonrelayColorPalette.primaryColor, isA<Color>());
    });

    test('getColorFromString returns a Color', () {
      final palette = MoonrelayColorPalette();
      expect(palette.getColorFromString('test'), isA<Color>());
    });

    test('getDarkColorFromString returns a Color', () {
      final palette = MoonrelayColorPalette();
      expect(palette.getDarkColorFromString('test'), isA<Color>());
    });

    test('getLightColorTextFromString returns a Color', () {
      final palette = MoonrelayColorPalette();
      expect(palette.getLightColorTextFromString('test'), isA<Color>());
    });

    test('getLightColorAvatarFromString returns a Color', () {
      final palette = MoonrelayColorPalette();
      expect(palette.getLightColorAvatarFromString('test'), isA<Color>());
    });
  });
}
