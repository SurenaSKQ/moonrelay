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

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/accents.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/surface_layers.dart';

/// WCAG 2.2 relative-luminance contrast ratio between two opaque colours.
///
/// Written out rather than pulled from a package because the whole point of
/// these tests is to make the numbers in the token comments checkable. The
/// assertions below reference specific ratios, so this helper has to be
/// right; it follows the spec literally, including the sRGB gamma step.
double contrastRatio(Color a, Color b) {
  double channel(double c) => c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

  double luminance(Color c) =>
      0.2126 * channel(c.r) +
      0.7152 * channel(c.g) +
      0.0722 * channel(c.b);

  final la = luminance(a);
  final lb = luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  group('surface ramp is a ramp', () {
    for (final brightness in Brightness.values) {
      final base = ColorScheme.fromSeed(
        seedColor: const Color(0xFF7255F5),
        brightness: brightness,
      );
      final scheme = MoonrelaySurfaceLayers.apply(base, brightness);
      final label = brightness.name;

      test('$label: each container step is distinct', () {
        final steps = <Color>[
          scheme.surface,
          scheme.surfaceContainerLowest,
          scheme.surfaceContainerLow,
          scheme.surfaceContainer,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
        ];
        for (var i = 0; i < steps.length; i++) {
          for (var j = i + 1; j < steps.length; j++) {
            expect(
              steps[i],
              isNot(steps[j]),
              reason: '$label: steps $i and $j are the same colour',
            );
          }
        }
      });

      test('$label: the ramp is monotonic', () {
        // Reading order runs left to right across the shell: rail, room
        // list, then the conversation. Each pane has to be a step away from
        // the last, or the shell reads as one flat wall and the eye has
        // nothing to hold on to. Direction flips with brightness: on dark,
        // nearer surfaces are lighter; on light, they are darker.
        final ramp = brightness == Brightness.dark
            ? <Color>[
                scheme.surface,
                scheme.surfaceContainerLow,
                scheme.surfaceContainer,
                scheme.surfaceContainerHigh,
                scheme.surfaceContainerHighest,
              ]
            : <Color>[
                scheme.surface,
                scheme.surfaceContainerLow,
                scheme.surfaceContainer,
                scheme.surfaceContainerHigh,
                scheme.surfaceContainerHighest,
              ];
        for (var i = 1; i < ramp.length; i++) {
          final previous = ramp[i - 1].computeLuminance();
          final current = ramp[i].computeLuminance();
          if (brightness == Brightness.dark) {
            expect(
              current,
              greaterThan(previous),
              reason: '$label: step $i should be lighter than step ${i - 1}',
            );
          } else {
            expect(
              current,
              lessThan(previous),
              reason: '$label: step $i should be darker than step ${i - 1}',
            );
          }
        }
      });

      test('$label: adjacent steps are close enough to read as one material', () {
        // A large jump reads as a different material rather than a
        // different depth. Anything above about 1:2.5 between neighbours
        // starts to look like a card on a page instead of a wall.
        final neighbours = <List<Color>>[
          [scheme.surface, scheme.surfaceContainerLow],
          [scheme.surfaceContainerLow, scheme.surfaceContainer],
          [scheme.surfaceContainer, scheme.surfaceContainerHigh],
          [scheme.surfaceContainerHigh, scheme.surfaceContainerHighest],
        ];
        for (final pair in neighbours) {
          final ratio = contrastRatio(pair[0], pair[1]);
          expect(
            ratio,
            lessThan(2.5),
            reason: '$label: ${pair[0]} vs ${pair[1]} is a $ratio jump, '
                'which reads as two materials rather than two depths',
          );
        }
      });
    }
  });

  group('text contrast', () {
    for (final brightness in Brightness.values) {
      final base = ColorScheme.fromSeed(
        seedColor: const Color(0xFF7255F5),
        brightness: brightness,
      );
      final scheme = MoonrelaySurfaceLayers.apply(base, brightness);
      final label = brightness.name;

      test('$label: body text clears 4.5:1 on every surface', () {
        for (final surface in <Color>[
          scheme.surface,
          scheme.surfaceContainerLow,
          scheme.surfaceContainer,
          scheme.surfaceContainerHigh,
          scheme.surfaceContainerHighest,
          scheme.surfaceContainerLowest,
        ]) {
          expect(
            contrastRatio(scheme.onSurface, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$label: onSurface on $surface',
          );
          expect(
            contrastRatio(scheme.onSurfaceVariant, surface),
            greaterThanOrEqualTo(4.5),
            reason: '$label: onSurfaceVariant on $surface',
          );
        }
      });

      test('$label: text on the accent fill clears 4.5:1', () {
        // Every filled accent button in the app puts this pair on it. The
        // assertion is deliberately against the scheme's own `onPrimary`
        // rather than against white: Material's dark scheme deliberately
        // makes `primary` a light tint with a dark `onPrimary`, so a hardcoded
        // white expectation is the wrong contract and, when it was tried, the
        // pair sat at 1.8:1.
        expect(
          contrastRatio(scheme.onPrimary, scheme.primary),
          greaterThanOrEqualTo(4.5),
          reason: '$label: onPrimary ${scheme.onPrimary} on '
              'primary ${scheme.primary}',
        );
      });

      test('$label: the accent keeps the seed hue', () {
        // The clamp may move lightness. It must not turn one accent into
        // another, or the user's accent picker becomes a nine-way choice of
        // "some purple".
        final bare = ColorScheme.fromSeed(
          seedColor: const Color(0xFF7255F5),
          brightness: brightness,
        );
        void hueOf(Color c, void Function(double) out) {
          final max = <double>[c.r, c.g, c.b].reduce((a, b) => a > b ? a : b);
          final min = <double>[c.r, c.g, c.b].reduce((a, b) => a < b ? a : b);
          if (max == min) {
            out(0);
            return;
          }
          final d = max - min;
          if (max == c.r) {
            out(((c.g - c.b) / d) % 6);
          } else if (max == c.g) {
            out((c.b - c.r) / d + 2);
          } else {
            out((c.r - c.g) / d + 4);
          }
        }

        late double seededHue;
        late double appliedHue;
        hueOf(bare.primary, (h) => seededHue = h);
        hueOf(scheme.primary, (h) => appliedHue = h);
        expect(
          appliedHue,
          closeTo(seededHue, 0.6),
          reason: '$label: clamping shifted the accent hue',
        );
      });

      test('$label: accent text on its container clears 4.5:1', () {
        expect(
          contrastRatio(scheme.onPrimaryContainer, scheme.primaryContainer),
          greaterThanOrEqualTo(4.5),
        );
      });
    }
  });

  group('the rail accent carries a white glyph', () {
    for (final brightness in Brightness.values) {
      final label = brightness.name;

      test('$label: the active tile clears AA against white', () {
        // The mockup's accent `#7C5DFA` is 4.37:1 against white, which is
        // under the 4.5 that the selected space's icon has to clear. This is
        // the assertion that would have caught it: the tile is a fill and the
        // thing on it is white in both brightnesses, so this is deliberately
        // not the scheme's own `primary`/`onPrimary` question.
        final layers = MoonrelaySurfaceLayers.forBrightness(
          brightness,
          accent: const Color(0xFF7C5DFA),
        );
        expect(
          contrastRatio(Colors.white, layers.railActive),
          greaterThanOrEqualTo(4.5),
          reason: '$label: white on ${layers.railActive}',
        );
      });

      test('$label: the active tile follows the accent the user picked', () {
        // The rail hardcoded a purple, so choosing a green accent changed the
        // app and left the one place where selection is most visible still
        // purple. Green is the awkward case: it is a mid-lightness hue, so
        // both directions of the white pairing are close to the limit and it
        // is the accent that exposes a clamp which only works one way.
        final purple = MoonrelaySurfaceLayers.forBrightness(
          brightness,
          accent: const Color(0xFF7C5DFA),
        );
        final green = MoonrelaySurfaceLayers.forBrightness(
          brightness,
          accent: const Color(0xFF23A559),
        );
        expect(purple.railActive, isNot(green.railActive));
        expect(
          contrastRatio(Colors.white, green.railActive),
          greaterThanOrEqualTo(4.5),
          reason: '$label: white on ${green.railActive}',
        );
      });

      test('$label: the tile hover step is lighter than its rest state', () {
        final layers = MoonrelaySurfaceLayers.forBrightness(
          brightness,
          accent: const Color(0xFF7C5DFA),
        );
        expect(
          layers.accentHover.computeLuminance(),
          greaterThan(layers.railActive.computeLuminance()),
        );
      });
    }
  });

  group('the accent clamp converges', () {
    // Every accent the picker offers, in both brightnesses, on both accent
    // pairings the app draws.
    for (final brightness in Brightness.values) {
      final label = brightness.name;

test('$label: primary on onPrimary clears 4.5:1 for every accent', () {
        // Honest about what this does and does not catch. The loop stepped
        // from the seed rather than from the candidate, so it applied 2%
        // exactly once and gave up. For `primary` that was invisible, because
        // `fromSeed` already returns a pair between 6.4:1 and 7.8:1 for every
        // accent here, so this assertion passes with or without the fix. It is
        // kept because it is the contract, not because it once failed.
        //
        // The assertion that does catch it is the rail tile one below, which
        // asks the same loop a different question and needs ten steps to
        // answer.
        for (final accent in MoonrelayAccents.all) {
          final scheme = MoonrelaySurfaceLayers.apply(
            ColorScheme.fromSeed(
              seedColor: accent.seedColor,
              brightness: brightness,
            ),
            brightness,
          );
          expect(
            contrastRatio(scheme.onPrimary, scheme.primary),
            greaterThanOrEqualTo(4.5),
            reason: '$label: ${accent.id} came out as ${scheme.primary} '
                'under ${scheme.onPrimary}',
          );
        }
      });

      test('$label: the rail tile clears 4.5:1 for every accent', () {
        // The failing-first test for the clamp. White against a mid-lightness
        // seed needs up to ten steps, and the loop used to manage one, so
        // every one of these accents came out short: the mockup's own purple
        // at 4.37:1 and the picker's green at 3.30:1.
        for (final accent in MoonrelayAccents.all) {
          final layers = MoonrelaySurfaceLayers.forBrightness(
            brightness,
            accent: accent.seedColor,
          );
          expect(
            contrastRatio(Colors.white, layers.railActive),
            greaterThanOrEqualTo(4.5),
            reason: '$label: ${accent.id} came out as ${layers.railActive}',
          );
        }
      });

      test('$label: a clamped accent is a whole ARGB value', () {
        // `Color.from` keeps floats, so a float clamp yields a colour with no
        // integer representation. It then differs by platform and cannot be
        // persisted or compared, which is a strange thing for a theme value to
        // be.
        for (final accent in MoonrelayAccents.all) {
          final scheme = MoonrelaySurfaceLayers.apply(
            ColorScheme.fromSeed(
              seedColor: accent.seedColor,
              brightness: brightness,
            ),
            brightness,
          );
          final roundTripped = Color(scheme.primary.toARGB32());
          expect(roundTripped, scheme.primary, reason: '$label: ${accent.id}');
        }
      });
    }
  });

  group('secondary text', () {
    test('dark: the mockup own grey fails and ours does not', () {
      // Recorded because the next person to "match the palette to the
      // mockup" will reach for `#949BA4` again. On the composer step it is
      // 4.05:1, and the composer's hint is the one string in the app that is
      // permanently sitting on that step.
      expect(
        contrastRatio(const Color(0xFF949BA4), const Color(0xFF383A40)),
        lessThan(4.5),
        reason: 'if this ever fails, the mockup grey became usable and the '
            'comment in surface_layers.dart can go',
      );

      final scheme = MoonrelaySurfaceLayers.apply(
        ColorScheme.fromSeed(
          seedColor: const Color(0xFF7C5DFA),
          brightness: Brightness.dark,
        ),
        Brightness.dark,
      );
      expect(
        contrastRatio(scheme.onSurfaceVariant, scheme.surfaceContainerHighest),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('hover and selection are states, not accent tints', () {
    for (final brightness in Brightness.values) {
      final layers =
          MoonrelaySurfaceLayers.forBrightness(brightness);
      final label = brightness.name;

      test('$label: hover and active differ from each other', () {
        expect(layers.hover, isNot(layers.active));
      });

      test('$label: the hairline is faint but not invisible', () {
        // A hairline at zero alpha is a divider that is not drawn, and one
        // at full opacity is a rule, not a hairline. Between roughly three
        // and fifteen percent is the band.
        expect(layers.hairline.a, greaterThan(0.02));
        expect(layers.hairline.a, lessThan(0.16));
      });
    }
  });

  group('corner radii', () {
    test('the scale never collapses to zero at the bottom', () {
      // The previous formula subtracted eight from a base of twelve and
      // clamped, which made the smallest step exactly zero: a square corner
      // wearing the name of a small radius.
      final t = MoonrelayDesignTokens.standard();
      expect(t.radiusXs, greaterThan(0));
      expect(t.radiusXs, lessThan(t.radiusSm));
      expect(t.radiusSm, lessThan(t.radiusMd));
      expect(t.radiusMd, lessThan(t.radiusLg));
      expect(t.radiusLg, lessThan(t.radiusXl));
    });

    test('the base is the standard for cards and buttons', () {
      expect(MoonrelayDesignTokens.baseCornerRadius, 8.0);
    });

    test('a 36px room avatar still visibly clears the card radius', () {
      // The reason the base dropped from twelve to eight: at twelve, a
      // 36px avatar's corners and a card's corners were close enough that
      // the pairing read as decoration rather than as two different shapes.
      final t = MoonrelayDesignTokens.standard();
      const avatar = 36.0;
      expect(t.radiusMd * 2, lessThan(avatar / 2));
    });
  });

  group('rail geometry', () {
    test('the rail is wide enough for its icon and gutter', () {
      const icon = MoonrelayDesignTokens.spaceIconSize;
      const rail = MoonrelayDesignTokens.navRailWidth;
      expect(icon, lessThan(rail));
      // Twelve of gutter each side reads as an inset rather than as a
      // crowded edge.
      expect((rail - icon) / 2, greaterThanOrEqualTo(8));
    });
  });

  group('the built themes carry the ramp', () {
    test('dark theme uses the dark surface floor', () {
      final theme = MoonrelayTheme.dark(
        const Color(0xFF7255F5),
        density: LayoutDensity.comfortable,
        fontFamily: 'Rubik',
        displayFontFamily: 'SpaceGrotesk',
        monoFontFamily: 'FiraCode',
        enableAnimations: true,
      );
      expect(theme.colorScheme.surface, const Color(0xFF0F0F14));
      expect(theme.scaffoldBackgroundColor, theme.colorScheme.surface);
      expect(
        theme.extension<MoonrelayThemeExtension>()!.layers.hover,
        const Color(0xFF35373C),
      );
      expect(theme.hoverColor, const Color(0xFF35373C));
    });

    test('light theme uses the light surface floor', () {
      final theme = MoonrelayTheme.light(
        const Color(0xFF7255F5),
        density: LayoutDensity.comfortable,
        fontFamily: 'Rubik',
        displayFontFamily: 'SpaceGrotesk',
        monoFontFamily: 'FiraCode',
        enableAnimations: true,
      );
      expect(theme.colorScheme.surface, const Color(0xFFFBFBFD));
      expect(theme.colorScheme.surface, isNot(const Color(0xFF000000)));
    });
  });
}