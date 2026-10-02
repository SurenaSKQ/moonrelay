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
  });

  group('text scale', () {
    final theme = MoonrelayTheme.light(const Color(0xFF3F51B5));
    final text = theme.textTheme;

    test('tracking tightens as the display sizes grow', () {
      final steps = <double>[
        text.displayLarge!.letterSpacing!,
        text.displayMedium!.letterSpacing!,
        text.displaySmall!.letterSpacing!,
        text.headlineLarge!.letterSpacing!,
        text.headlineMedium!.letterSpacing!,
        text.headlineSmall!.letterSpacing!,
      ];
      for (var i = 1; i < steps.length; i++) {
        expect(steps[i], greaterThan(steps[i - 1]),
            reason: 'step $i must track less tightly than the one above it');
      }
      expect(steps.every((s) => s < 0), isTrue);
    });

    test('small labels track outward', () {
      expect(text.labelSmall!.letterSpacing!, greaterThan(0));
      expect(text.labelMedium!.letterSpacing!, greaterThan(0));
      expect(
        text.labelSmall!.letterSpacing!,
        greaterThan(text.labelMedium!.letterSpacing!),
      );
    });

    test('body copy does not carry negative tracking', () {
      for (final style in <TextStyle>[
        text.bodyLarge!,
        text.bodyMedium!,
        text.bodySmall!,
      ]) {
        expect(style.letterSpacing ?? 0, greaterThanOrEqualTo(0));
      }
    });

    test('numeric labels use tabular figures', () {
      // Timestamps, unread counts and ids live in the label roles. Without
      // tnum their digits change width as they change, so the column
      // jitters on every tick.
      for (final style in <TextStyle>[
        text.labelSmall!,
        text.labelMedium!,
      ]) {
        expect(style.fontFeatures, isNotNull);
        expect(
          style.fontFeatures!.any((f) => f.feature == 'tnum' && f.value == 1),
          isTrue,
          reason: 'expected the tnum feature, got ${style.fontFeatures}',
        );
      }
    });

    test('display roles use the display face, titles stay on the body face', () {
      expect(text.displayLarge!.fontFamily,
          MoonrelayTheme.displayFontFamilyFallback);
      expect(text.headlineSmall!.fontFamily,
          MoonrelayTheme.displayFontFamilyFallback);
      // titleLarge sits next to body text in lists; a family break here
      // would split the scale in the middle of the UI.
      expect(text.titleLarge!.fontFamily, MoonrelayTheme.fontFamilyFallback);
      expect(text.bodyLarge!.fontFamily, MoonrelayTheme.fontFamilyFallback);
      expect(text.labelLarge!.fontFamily, MoonrelayTheme.fontFamilyFallback);
    });

    test('a body-font override pulls the display roles with it', () {
      final overridden = MoonrelayTheme.light(
        const Color(0xFF3F51B5),
        fontFamily: 'Inter',
      );
      expect(overridden.textTheme.displayLarge!.fontFamily, 'Inter');
      expect(overridden.textTheme.titleLarge!.fontFamily, 'Inter');
    });

    test('an explicit display face is not overridden by the body face', () {
      final split = MoonrelayTheme.light(
        const Color(0xFF3F51B5),
        fontFamily: 'Inter',
        displayFontFamily: 'Oxanium',
      );
      expect(split.textTheme.displayLarge!.fontFamily, 'Oxanium');
      expect(split.textTheme.titleLarge!.fontFamily, 'Inter');
    });

    test('dark theme receives the dark shadow scale', () {
      final darkTheme = MoonrelayTheme.dark(const Color(0xFF3F51B5));
      final darkTokens = darkTheme.extension<MoonrelayThemeExtension>()!.tokens;
      expect(_rimsOf(darkTokens), isNotEmpty);
    });
  });
}