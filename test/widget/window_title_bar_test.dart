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
import 'package:window_manager/window_manager.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/layouts/window_title_bar.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';


Widget host(Widget child) => MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(WindowTitleBar.height),
          child: child,
        ),
        body: const SizedBox.shrink(),
      ),
    );

void main() {
  group('WindowTitleBar', () {
    testWidgets('is one toolbar tall', (tester) async {
      await tester.pumpWidget(host(const WindowTitleBar()));
      expect(
        tester.getSize(find.byType(WindowTitleBar)).height,
        WindowTitleBar.height,
      );
    });

    testWidgets('carries the app name', (tester) async {
      await tester.pumpWidget(host(const WindowTitleBar()));

      // It is also the drag area, so it has to say what the window is. A
      // frameless window with an empty bar is a rectangle.
      expect(find.text('Moonrelay (Alpha)'), findsOneWidget);
    });

    testWidgets('the search control is off by default', (tester) async {
      // The start screen has nothing to search before sign-in, and a search
      // field that opens an empty palette is a dead control with a real-looking
      // border.
      await tester.pumpWidget(host(const WindowTitleBar()));

      expect(find.byType(GlobalSearchControl), findsNothing);
    });

    testWidgets('the search control is opt-in', (tester) async {
      await tester.pumpWidget(host(const WindowTitleBar(showSearch: true)));

      expect(find.byType(GlobalSearchControl), findsOneWidget);
      expect(find.byTooltip('Command palette'), findsOneWidget);
    });

    testWidgets('the search control is outside the drag area', (tester) async {
      await tester.pumpWidget(host(const WindowTitleBar(showSearch: true)));

      // A button inside a drag target swallows its own clicks, and a drag
      // target that swallows clicks is how a search button ends up working only
      // on the second try. Asserted structurally rather than by clicking: a
      // click would pass either way, since the drag area would swallow it and
      // the palette would appear from a hit that should not have landed.
      expect(
        find.descendant(
          of: find.byType(DragToMoveArea),
          matching: find.byType(GlobalSearchControl),
        ),
        findsNothing,
      );
      expect(find.byType(DragToMoveArea), findsOneWidget);
    });

    testWidgets('the search control is a field, not a bare icon',
        (tester) async {
      await tester.pumpWidget(host(const WindowTitleBar(showSearch: true)));
      final theme = Theme.of(
        tester.element(find.byType(GlobalSearchControl)),
      );

      // Shaped like the recessed fields elsewhere in the app, because it is a
      // target with a label rather than a command. A user who has not seen the
      // shortcut is looking for something that says "search".
      final fills = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(GlobalSearchControl),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.color != null && d.color != Colors.transparent)
          .toList();

      expect(fills, isNotEmpty);
      // One step below the bar, so it reads as a field sitting on the chrome
      // rather than as part of the chrome.
      expect(
        fills.map((d) => d.color).contains(theme.colorScheme.surfaceContainerLow),
        isTrue,
      );
    });
  });
}


