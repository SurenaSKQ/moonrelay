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
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    testWidgets('shows the display name', (tester) async {
      await pump(tester, clientWith('@alice:example.org', displayName: 'Alice'));
      expect(find.text('Alice'), findsOneWidget);
    });

    testWidgets('falls back to the user id when the profile has no name',
        (tester) async {
      await pump(tester, clientWith('@bob:example.org'));
      expect(find.text('@bob:example.org'), findsOneWidget);
    });

    testWidgets('the second line is presence, not the localpart',
        (tester) async {
      // The localpart never changed, so a user glancing at the footer had no
      // way to tell whether they were showing up as online. That is the one
      // question this row exists to answer. It falls back to the localpart
      // only while no presence has arrived, because a blank line reads as a
      // rendering fault.
      await pump(tester, clientWith('@alice:example.org', displayName: 'Alice'));
      expect(find.text('alice'), findsOneWidget);
      expect(find.text('Online'), findsNothing);
    });

    testWidgets('is a flat band, not a lifted card', (tester) async {
      // It used to be the only shadowed object in the sidebar, which was how
      // it was distinguished from the rows above it. As a footer with the new
      // surface ramp that is one container too many: the pane has an edge,
      // the footer is a step darker, and a border plus two shadow layers on
      // top of that reads as a control sitting in a list.
      await pump(tester, clientWith('@alice:example.org'));
      // Scoped to the pill's own subtree: an unrelated Container elsewhere in the
      // harness is not this row's business.
      final inPill = find.descendant(
        of: find.byType(SidebarProfilePill),
        matching: find.byType(Container),
      );
      final decorations = tester
          .widgetList<Container>(inPill)
          .map((c) => c.decoration)
          .whereType<BoxDecoration>();
      expect(
        decorations.where((d) => d.boxShadow?.isNotEmpty ?? false),
        isEmpty,
        reason: 'the footer should not be lifted',
      );
      // The avatar's ring is a deliberate 2px circle, so the assertion is
      // about the footer's own box: a hairline around a band at the bottom of
      // a pane reads as a text field.
      expect(
        decorations.where(
          (d) => d.border != null && d.shape != BoxShape.circle,
        ),
        isEmpty,
        reason: 'a hairline around a footer reads as a text field',
      );
    });

    testWidgets('sits on the rail step, darker than the pane above it',
        (tester) async {
      // The depth step that replaced the shadow. It used to be the app floor,
      // which is darker again and read as a separate surface dropped in
      // rather than as the base the room list stands on. The rail step is also
      // what the search field is filled with, which is what gives the presence
      // dot a ring colour that is already in the pane.
      await pump(tester, clientWith('@alice:example.org'));
      final scheme = Theme.of(
        tester.element(find.byType(SidebarProfilePill)),
      ).colorScheme;
      final material = tester
          .widgetList<Material>(find.byType(Material))
          .map((m) => m.color)
          .whereType<Color>()
          .toList();
      expect(material, contains(scheme.surfaceContainerLow));
    });

    testWidgets('presence is a dot, not a ring around the avatar',
        (tester) async {
      // A two-pixel ring around a thirty-two pixel avatar is a fifth of its
      // diameter, so the avatar reads as a badge with a person in it rather
      // than as a person's avatar, and presence is announced twice with nothing
      // tying the ring to the status line.
      await pump(tester, clientWith('@alice:example.org'));

final circles = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(SidebarProfilePill),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .where((d) => d.shape == BoxShape.circle);

      // Filtered on the border, because `CircleAvatar` builds its own circular
      // `Container` and would otherwise be counted. The border is exactly what
      // distinguishes the dot: an avatar's ring was one too, so counting
      // bordered circles is counting the two states this test is about.
      final rings = circles.where((d) => d.border != null);
      expect(rings, hasLength(1), reason: 'a ring around the avatar would make two');

      final dot = rings.single;
      expect(dot.color, isNotNull, reason: 'the dot carries the presence');
      // And that ring is the band's own colour, which is what makes the dot
      // read as sitting on top of the avatar instead of clipped by it.
      expect(
        dot.border!.top.color,
        Theme.of(tester.element(find.byType(SidebarProfilePill)))
            .colorScheme
            .surfaceContainerLow,
      );
    });

    testWidgets('the settings affordance is visible without hovering',
        (tester) async {
      // It used to fade in on hover, which made a control that is the only
      // route to the hub appear to be missing from the row it belongs to.
      await pump(tester, clientWith('@alice:example.org'));
      expect(
        find.descendant(
          of: find.byType(SidebarProfilePill),
          matching: find.byIcon(LucideIcons.settings),
        ),
        findsOneWidget,
      );
      // No AnimatedOpacity wrapping it any more, which is the direct evidence
      // that nothing is gating it on a hover.
      expect(
        find.descendant(
          of: find.byType(SidebarProfilePill),
          matching: find.byType(AnimatedOpacity),
        ),
        findsNothing,
      );
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
