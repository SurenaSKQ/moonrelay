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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/chat_timeline_floating_actions.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';


/// The pill's painted box, without the `Material` and `InkWell` inside it.
Finder thePill() => find.descendant(
      of: find.byType(FloatingPill),
      matching: find.byType(Container),
    );

BoxDecoration pillDecoration(WidgetTester tester) =>
    tester.widget<Container>(thePill().first).decoration! as BoxDecoration;

Widget host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('FloatingPill', () {
    testWidgets('casts a neutral shadow when nothing asks for a glow',
        (tester) async {
      await tester.pumpWidget(host(
        FloatingPill(
          background: const Color(0xFF404040),
          foreground: Colors.white,
          child: const Text('x'),
        ),
      ));

      // A neutral shadow says "this floats above the page". That is the right
      // default for the two quiet pills, which are furniture.
      final shadows = pillDecoration(tester).boxShadow!;
      expect(shadows, isNotEmpty);
      expect(
        shadows.every((s) => s.color.r < 0.9 && s.color.b < 0.9),
        isTrue,
        reason: 'expected a desaturated shadow',
      );
    });

    testWidgets('casts a shadow in the fill colour when a glow is asked for',
        (tester) async {
      const accent = Color(0xFF7C5DFA);
      await tester.pumpWidget(host(
        FloatingPill(
          background: accent,
          foreground: Colors.white,
          glow: accent,
          child: const Text('x'),
        ),
      ));

      // A shadow in the pill's own colour says "this is the accent, and it is
      // the only accent-coloured thing you can act on right now". It is also
      // why the pill belongs on the conversation rather than in a corner: a
      // glow is only legible against something.
      final shadows = pillDecoration(tester).boxShadow!;
      expect(shadows, hasLength(1));
      // Compared against the accent itself rather than against channel
      // thresholds, which would have to be re-guessed for every colour.
      expect(shadows.single.color.r, closeTo(accent.r, 0.01));
      expect(shadows.single.color.g, closeTo(accent.g, 0.01));
      expect(shadows.single.color.b, closeTo(accent.b, 0.01));
      // Tinted, not opaque: a fully saturated shadow would be a second
      // accent shape rather than a shadow of the first.
      expect(shadows.single.color.a, lessThan(1));
      expect(shadows.single.color.a, greaterThan(0.15));
      expect(shadows.single.blurRadius, greaterThan(shadows.single.spreadRadius));
      expect(shadows.single.offset.dy, greaterThan(0));
    });
  });

  group('JumpToUnreadPill', () {
    testWidgets('is filled with the accent and glows in it', (tester) async {
      // The two halves of the same claim. A pill filled with the accent and a
      // pill shadowed in neutral grey make two unrelated statements; filling
      // and glowing in the same colour make one.
      await tester.pumpWidget(host(
        JumpToUnreadPill(
          count: 8,
          isLoading: false,
          onTap: () async {},
          onDismiss: () {},
        ),
      ));

      final scheme = Theme.of(
        tester.element(find.byType(JumpToUnreadPill)),
      ).colorScheme;
      final decoration = pillDecoration(tester);

      expect(decoration.color, scheme.primary);
      final shadows = decoration.boxShadow!;
      expect(shadows, hasLength(1));
      expect(
        shadows.single.color.r,
        closeTo(scheme.primary.r, 0.01),
        reason: 'the shadow should be the accent, not a grey',
      );
    });

    testWidgets('a loading pill still glows, so it does not blink out',
        (tester) async {
      // The label swaps and a spinner appears, but the pill is still the same
      // accent shape. If the glow were tied to the idle state, the one moment
      // the user is waiting would be the moment the affordance disappears.
      await tester.pumpWidget(host(
        JumpToUnreadPill(
          count: 8,
          isLoading: true,
          onTap: () async {},
          onDismiss: () {},
        ),
      ));

      expect(pillDecoration(tester).boxShadow, isNotEmpty);
    });
  });
}
