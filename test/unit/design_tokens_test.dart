// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Returns the shadows in [tokens] that are a light rim rather than a dark
/// drop, identified by being white with a partial alpha.
///
/// A rim is the only depth cue that survives on a near-black surface, so
/// "dark tokens contain a rim" is the property worth pinning, not the exact
/// alpha it happens to use.
List<BoxShadow> _rimsOf(MoonrelayDesignTokens tokens) {
  return <BoxShadow>[
    ...tokens.shadowLow,
    ...tokens.shadowMedium,
    ...tokens.shadowHigh,
  ].where((shadow) {
    final c = shadow.color;
    return c.a > 0 && c.r == 1.0 && c.g == 1.0 && c.b == 1.0;
  }).toList();
}

bool _isDrop(BoxShadow shadow) {
  final c = shadow.color;
  return c.a > 0 && c.r == 0.0 && c.g == 0.0 && c.b == 0.0;
}

void main() {
  group('shadow scale follows brightness', () {
    final light = MoonrelayDesignTokens.standard();
    final dark =
        MoonrelayDesignTokens.standard(brightness: Brightness.dark);

    test('defaults to the light scale', () {
      expect(light.shadowLow, isNot(dark.shadowLow));
      expect(_rimsOf(light), isEmpty,
          reason: 'light surfaces must not get a white rim');
    });

    test('dark tokens carry a rim in every level', () {
      for (final scale in <List<BoxShadow>>[
        dark.shadowLow,
        dark.shadowMedium,
        dark.shadowHigh,
      ]) {
        expect(_rimsOf(dark), isNotEmpty);
        expect(
          scale.where(
            (s) => s.color.a > 0 && s.color.r == 1.0 && s.color.g == 1.0,
          ),
          isNotEmpty,
          reason: 'each level needs its own lit top edge',
        );
      }
    });

    test('dark rims sit above the surface, drops sit below it', () {
      for (final rim in _rimsOf(dark)) {
        expect(rim.offset.dy, lessThan(0),
            reason: 'a rim at or below the drop is hidden by it');
      }
      for (final drop in dark.shadowLow.where(_isDrop)) {
        expect(drop.offset.dy, greaterThan(0));
      }
    });

    test('dark drops are deeper than light drops', () {
      // Light drops are 8-16% black on a near-white plane. On a near-black
      // plane that range is arithmetically present and visually absent, so
      // dark has to push past it or the lift is lost rather than softened.
      final darkestLight = light.shadowLow
          .map((s) => s.color.a)
          .reduce((a, b) => a > b ? a : b);
      final deepestDark = dark.shadowLow
          .map((s) => s.color.a)
          .reduce((a, b) => a > b ? a : b);
      expect(deepestDark, greaterThan(darkestLight));
    });

    test('brightness changes nothing except the shadows', () {
      expect(dark.spaceLg, light.spaceLg);
      expect(dark.radiusMd, light.radiusMd);
      expect(dark.minTapTarget, light.minTapTarget);
      expect(dark.durationMedium, light.durationMedium);
      expect(dark.borderWidthThin, light.borderWidthThin);
      expect(dark.opacityHover, light.opacityHover);
    });

    test('the dark theme reaches the dark scale', () {
      // The tokens could be correct and still never be asked for, which is
      // how the light-only scale survived in the first place: the only
      // readers were three widgets that all read whatever they were given.
      final darkTheme = MoonrelayTheme.dark(const Color(0xFF3F51B5));
      final darkTokens = darkTheme.extension<MoonrelayThemeExtension>()!.tokens;
      expect(_rimsOf(darkTokens), isNotEmpty);

      final lightTheme = MoonrelayTheme.light(const Color(0xFF3F51B5));
      final lightTokens = lightTheme.extension<MoonrelayThemeExtension>()!.tokens;
      expect(_rimsOf(lightTokens), isEmpty);
    });
  });
}
