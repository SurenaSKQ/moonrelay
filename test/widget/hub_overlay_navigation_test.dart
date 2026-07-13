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

// Pin tests for the hub overlay's internal category navigation.
//
// The bug this guards against: when the user opens the hub as a
// modal overlay and clicks a category in the sidebar, the hub used
// to call `context.go('/hub/<category>')` which routed the GoRouter
// to a full-page hub and *replaced* the room page in the navigator
// stack.  The fix makes that call a no-op when the hub is an
// overlay, so the room stays visible underneath.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'hub overlay stays on top of the room when a category is tapped',
    (tester) async {
      final client = MockClient();
      when(() => client.userID).thenReturn('@me:example.com');
      when(() => client.getProfileFromUserId(any()))
          .thenAnswer((_) async => Profile(userId: '@me:example.com'));
      when(() => client.rooms).thenReturn(<Room>[]);

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('home', key: ValueKey('home')),
                      ElevatedButton(
                        onPressed: () => showHubOverlay(context),
                        child: const Text('open-hub'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-hub'));
      await tester.pumpAndSettle();

      // The hub overlay should be on the stack.
      expect(find.byType(HubScreen), findsOneWidget);

      // Tap a category in the hub sidebar.  We tap by text  the
      // categories are defined in `navigation_items.dart` and their
      // localized labels are listed in app_en.arb.  "About" is
      // always present in the categories list and is the most
      // stable label across locales for the test.
      final aboutLabel = AppLocalizations.of(
        find.byType(HubScreen).evaluate().first,
      )!.about;
      // Make sure the category is visible.  Hub cards may need
      // scrolling to expose the "About" item on small viewports.
      await tester.scrollUntilVisible(
        find.text(aboutLabel),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text(aboutLabel));
      await tester.pumpAndSettle();

      // The home route (with the "home" text) must still be in the
      // navigator stack.  If the bug had regressed, the hub would
      // have routed to /hub/about and removed the home screen.
      expect(find.text('home', skipOffstage: false), findsOneWidget,
          reason:
              'home screen must remain in the navigator stack after a '
              'category tap on the hub overlay');
    },
  );

  testWidgets(
    'hub overlay stays on top of the room when a settings sub-item is tapped',
    (tester) async {
      // Use a large viewport so the hub overlay's sidebar (which
      // has a known overflow issue on small viewports  see
      // `category_sidebar.dart:192`) renders without throwing.
      tester.view.physicalSize = const Size(1920, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final client = MockClient();
      when(() => client.userID).thenReturn('@me:example.com');
      when(() => client.getProfileFromUserId(any()))
          .thenAnswer((_) async => Profile(userId: '@me:example.com'));
      when(() => client.rooms).thenReturn(<Room>[]);

      await tester.pumpWidget(
        wrapWithProviders(
          client: client,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('home', key: ValueKey('home')),
                      ElevatedButton(
                        onPressed: () => showHubOverlay(
                          context,
                          selection: const HubCategorySelection(
                            categoryKey: 'settings',
                          ),
                        ),
                        child: const Text('open-hub'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open-hub'));
      await tester.pumpAndSettle();

      // The hub overlay should be on the stack, opened to Settings.
      expect(find.byType(HubScreen), findsOneWidget);

      // Tap the "Appearance" sub-item.  The settings category shows
      // a "Settings" overview page first; we tap into the menu by
      // tapping on the overview's "Appearance" entry.  Both
      // "Appearance" labels are visually present so just tap the
      // first one.
      final appearanceLabel = AppLocalizations.of(
        find.byType(HubScreen).evaluate().first,
      )!.appearance;
      final appearanceFinder = find.text(appearanceLabel);
      expect(appearanceFinder, findsWidgets);
      await tester.tap(appearanceFinder.first, warnIfMissed: false);
      await tester.pumpAndSettle();

      // The home route must still be in the stack.
      expect(find.text('home', skipOffstage: false), findsOneWidget,
          reason:
              'home screen must remain in the navigator stack after a '
              'sub-item tap on the hub overlay');
    },
  );
}
