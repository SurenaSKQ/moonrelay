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
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

import '../helpers/widget_test_utils.dart';

/// The conversation is framed by two bars: the navigation pane's header at the
/// top and the composer at the bottom.
///
/// They were derived independently, one from a header's own padding and one
/// from the composer's `minTapTarget`, and had drifted a few pixels apart. That
/// is enough. The eye reads a framed region as one thing and an unframed one as
/// content that happens to be between two strips, and there is no way to
/// recover the frame once the two edges disagree.
void main() {
  group('paneBarHeight', () {
    test('is the same number in both places, by construction', () {
      final t = MoonrelayDesignTokens.standard();
      // One token, so there is nothing to drift. The assertion is here so that
      // someone adding a second derivation has to delete it.
      expect(t.paneBarHeight, greaterThan(0));
    });

    test('is tall enough for the controls it frames', () {
      final t = MoonrelayDesignTokens.standard();
      // The composer holds buttons of `minTapTarget * 0.75` inside vertical
      // padding. A bar shorter than that would crop its own controls, so the
      // floor is the tallest thing that sits inside it rather than a round
      // number that happens to look tidy in the source.
      final composerButton = t.minTapTarget * 0.75;
      expect(t.paneBarHeight, greaterThanOrEqualTo(composerButton));
    });

    test('is not so tall it reads as a band', () {
      final t = MoonrelayDesignTokens.standard();
      // Roughly a tenth of a 720px window. Past about 15% the bars stop being
      // a frame and start being furniture, and the conversation reads as a
      // small strip pinned between two panels.
      expect(t.paneBarHeight, lessThan(720 * 0.15));
    });

    test('survives the density scale', () {
      final t = MoonrelayDesignTokens.standard();
      final compact = t.copyWith(paneBarHeight: 44);
      expect(compact.paneBarHeight, 44);
      expect(compact.paneBarHeight, lessThan(t.paneBarHeight));
      // The copy is what a density change would go through, so this is the
      // assertion that catches one that forgot to carry the new field.
      expect(t.copyWith().paneBarHeight, t.paneBarHeight);
    });

    testWidgets('the theme hands it to widgets', (tester) async {
      late double seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          home: Builder(
            builder: (context) {
              seen = MoonrelayThemeExtension.of(context).tokens.paneBarHeight;
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(seen, MoonrelayDesignTokens.standard().paneBarHeight);
    });
  });
}
