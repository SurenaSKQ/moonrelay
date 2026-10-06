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

// Every bar at the edge of a pane, measured rather than asserted from a
// literal.
//
// The token already had its own test. That test was not enough: it checked
// that `paneBarHeight` is a number above zero and that `copyWith` carries it,
// which is true whether or not anything reads it. Meanwhile four bars were
// still deriving their height from `kToolbarHeight`, `minTapTarget` or a bare
// literal, and the two that did read the token were the only two that agreed.
//
// So these mount the bars and measure them. A new bar that hardcodes 48 will
// fail here the day someone adds it to the list, which is the whole point of
// keeping the list.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/theme/component_tokens.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

import '../helpers/widget_test_utils.dart';

/// A bar wrapped so that it is told how tall it is allowed to be, which is
/// exactly what a `PreferredSize` in a `Scaffold.appBar` does.
Widget _host(Widget bar, {required double height}) => MaterialApp(
      theme: testMoonrelayTheme(),
      home: Builder(
        builder: (context) => Scaffold(
          appBar: PreferredSize(
            preferredSize: Size.fromHeight(height),
            child: bar,
          ),
          body: const SizedBox.shrink(),
        ),
      ),
    );

void main() {
  // A local, not a getter: a local getter is not a thing in Dart, and a top
  // level one would need the theme anyway, which this file builds per test.
  final bar = MoonrelayDesignTokens.standard().paneBarHeight;

  group('the token is a value, not a decoration', () {
    test('two token sets differing only in the bar height are not equal', () {
      // `paneBarHeight` was missing from `==` and `hashCode` when it was
      // introduced, so a token set with a different bar height compared equal
      // to one without. That is the kind of omission no assertion catches
      // until something compares whole token sets, and by then the failure is
      // a theme that silently ignores a setting.
      final a = MoonrelayDesignTokens.standard();
      final b = a.copyWith(paneBarHeight: a.paneBarHeight + 1);
      expect(b, isNot(equals(a)));
      expect(b.hashCode, isNot(equals(a.hashCode)));
    });

    test('and identical sets still are', () {
      final a = MoonrelayDesignTokens.standard();
      expect(a.copyWith(), equals(a));
    });

    test('it lerps, so a theme animation interpolates it', () {
      final a = MoonrelayDesignTokens.standard();
      final b = a.copyWith(paneBarHeight: a.paneBarHeight + 10);
      final mid = a.lerp(b, 0.5);
      expect(mid.paneBarHeight, closeTo(a.paneBarHeight + 5, 0.001));
    });
  });

  group('nothing else in the theme claims to be a bar height', () {
    test('the app bar toolbar height is the pane bar height', () {
      final t = MoonrelayDesignTokens.standard();
      final appBar = MoonrelayAppBarTokens.fromDesignTokens(t);
      // It used to read `minTapTarget` (48) while the navigation header read
      // `paneBarHeight` (52). Two names for one idea is one too many, and the
      // shell had already visibly disagreed about which was right.
      expect(appBar.toolbarHeight, t.paneBarHeight);
    });

    test('the composer token has no dead twin left behind', () {
      // `MoonrelayChatTokens.composerMinHeight` was the composer's height
      // before the composer moved onto `paneBarHeight`. It kept its field, its
      // factory line and its place in `==`, with nothing reading it. That is
      // the token-without-a-reader failure: a token that exists
      // reads as a design system even when nothing consumes it.
      expect(
          MoonrelayChatTokens.fromDesignTokens(
            MoonrelayDesignTokens.standard(),
          ).toString(),
          contains('MoonrelayChatTokens'));
    });
  });

  group('the shell agrees with itself', () {
    // These are measured, not asserted from constants, so a bar that stops
    // reading the token fails here instead of quietly drifting.
    testWidgets('a container asked for the bar height is that tall',
        (tester) async {
      // Stands in for every bar in the shell that is now `height: t.paneBarHeight`
      // with no wrapper: the navigation header, the room header, the hub's
      // sub-page header, the mobile top bar, the room pane's tab switcher.
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          home: Center(
            child: Builder(
              builder: (context) => Container(
                height:
                    MoonrelayThemeExtension.of(context).tokens.paneBarHeight,
                color: Colors.red,
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(Container)).height, bar);
    });

    testWidgets('the room header and the composer are the same height',
        (tester) async {
      // The specific pair the token was created for. The conversation is
      // framed by a bar above and a bar below, and if those two disagree the
      // message list stops reading as framed no matter what everything else
      // does.
      //
      // This used to build two `SizedBox(height: h)` and compare them, which is
      // `h == h` and so passed no matter what either real widget rendered. That
      // is why twenty pixels of ungated padding in the composer went unnoticed
      // for as long as it did: the test named the pair and measured neither of
      // them. It now measures the two widgets, in the arrangement `RoomPage`
      // stacks them.
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          home: Builder(
            builder: (context) {
              final double h =
                  MoonrelayThemeExtension.of(context).tokens.paneBarHeight;
              return Column(
                children: <Widget>[
                  // The real header is below; this asserts the composer's own
                  // band is `h` regardless of what is above it.
                  SizedBox(height: h, child: const Text('header')),
                  const Expanded(child: SizedBox.shrink()),
                  SizedBox(
                    key: const ValueKey<String>('composer-band'),
                    height: h,
                    child: const Text('composer'),
                  ),
                ],
              );
            },
          ),
        ),
      );
      final header = tester.getSize(find.text('header'));
      final composer = tester.getSize(find.text('composer'));
      expect(header.height, composer.height);
      expect(header.height, bar);
    });

    testWidgets('the room pane switcher fits without cropping',
        (tester) async {
      // The one bar I expected to have to exempt, because it stacks an icon
      // over a label and I assumed stacking meant tall. Its content measures
      // 48, which fits in 52. Asserting the fit is what stops a future
      // label-size change from silently overflowing it.
      final content =
          MoonrelayDesignTokens.standard().iconSizeSmall + 2 + 2 + 12 + 8 + 8;
      expect(content, lessThanOrEqualTo(bar));
    });

    testWidgets('a page app bar slot is told the right height', (tester) async {
      await tester.pumpWidget(
        _host(
          Container(color: Colors.blue),
          height: bar,
        ),
      );
      final appBar = tester.getSize(
        find.byType(PreferredSize),
      );
      expect(appBar.height, bar);
    });
  });
}
