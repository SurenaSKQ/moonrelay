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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/sidebar_profile_pill.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  MockClient clientWith(String userId, {String? displayName}) {
    final client = MockClient();
    when(() => client.userID).thenReturn(userId);
    final profile = MockProfile();
    when(() => profile.displayName).thenReturn(displayName);
    when(() => profile.avatarUrl).thenReturn(null);
    when(() => client.getProfileFromUserId(any()))
        .thenAnswer((_) async => profile);
    return client;
  }

  Future<void> pump(WidgetTester tester, MockClient client) async {
    const pill = Scaffold(
      body: Center(
        child: SizedBox(width: 300, child: SidebarProfilePill()),
      ),
    );
    final router = GoRouter(
      initialLocation: '/',
      routes: <RouteBase>[
        GoRoute(path: '/', builder: (_, __) => pill),
        GoRoute(path: '/hub', builder: (_, __) => const Text('hub')),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      wrapWithProviders(
        client: client,
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  group('SidebarProfilePill', () {
    testWidgets('shows the display name and the localpart', (tester) async {
      // Two lines, because a Matrix client is full of people whose display
      // names collide, and the localpart is what tells two of them apart.
      // It was not on screen at all before.
      await pump(tester, clientWith('@alice:example.org', displayName: 'Alice'));
      expect(find.text('Alice'), findsOneWidget);
      expect(find.text('alice:example.org'), findsOneWidget);
    });

    testWidgets('drops a long homeserver from the identity line',
        (tester) async {
      // A 300px card ellipsises the full id before the useful half is
      // readable, and the localpart is the half people recognise.
      await pump(
        tester,
        clientWith('@alice:a-very-long-homeserver.example.org'),
      );
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('alice:a-very-long-homeserver.example.org'), findsNothing);
    });

    testWidgets('falls back to the user id when the profile has no name',
        (tester) async {
      await pump(tester, clientWith('@bob:example.org'));
      expect(find.text('@bob:example.org'), findsOneWidget);
    });

    testWidgets('is the one lifted surface in the pane', (tester) async {
      // Everything else in the sidebar is a flat fill, which is what lets
      // this read as an object rather than as the last row of a list.
      await pump(tester, clientWith('@alice:example.org'));
      final shadow = tester
          .widgetList<Container>(find.byType(Container))
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.boxShadow != null && d.boxShadow!.isNotEmpty)
          .length;
      expect(shadow, greaterThan(0));
    });

    testWidgets('tapping it opens the hub', (tester) async {
      // `push`, not `go`: the chat the hub was opened from has to still be
      // underneath for the hub's back button to be worth having.
      final client = clientWith('@alice:example.org');
      await pump(tester, client);
      await tester.tap(find.byType(SidebarProfilePill));
      await tester.pump();
      await tester.pump();
      expect(find.text('hub'), findsOneWidget);
    });
  });
}