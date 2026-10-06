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

// Drives the hub as a routed page rather than a modal overlay.
//
// The overlay is gone, and with it the reason this file existed. The old
// test asserted that tapping a category inside the overlay left the room
// underneath untouched, which was true precisely *because* the hub could not
// navigate: `_pushHubUrl` checked `ModalRoute.of(context).opaque` and
// returned early, so every hub URL in the command palette resolved to
// nothing and the hub's own state was the only source of truth for what was
// on screen.
//
// Now the URL is the source of truth. These tests pin the three properties
// that replaced it: a deep link lands on the right category, a stale or
// malformed hub link is redirected rather than rendering an empty pane, and
// the hub still leaves whatever it was opened over underneath so the back
// button has somewhere to go.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/router.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/screens/encryption/encryption_overview/encryption_overview.dart';
import 'package:moonrelay/src/screens/hub_screen/hub_nav_list.dart';
import 'package:moonrelay/src/screens/hub_screen/hub_screen.dart';
import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/helpers/log_service.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

const String _homeMarker = 'home-marker';
const String _roomListMarker = 'room-list-marker';

/// A router with the hub's three real routes, a stand-in for whatever the
/// hub was opened over, and the real validation redirect.
GoRouter buildHubRouter(Client client, {String initialLocation = '/hub'}) {
  // [MoonRouter.hubRedirect], not a copy. This used to be a local `validate`
  // that reimplemented the rule, and it was already a copy that could drift:
  // when a settings sub-item was retired and the real redirect learned to send
  // it to the page it had become, this one kept rejecting it, so the tests
  // exercised a router the app does not run.
  String? validate(GoRouterState state, {String? subKey}) =>
      MoonRouter.hubRedirect(state, subKey: subKey);

  return GoRouter(
    initialLocation: initialLocation,
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text(_homeMarker)),
      ),
      // Where the hub's Close button lands. Without it a `go` here matches
      // nothing and the router's match list is empty, which surfaces as an
      // opaque "Bad state: No element" from `router.state` rather than as
      // a missing route.
      GoRoute(
        path: MoonRoutePaths.roomListTemplate,
        builder: (_, __) => const Scaffold(body: Text(_roomListMarker)),
      ),
      GoRoute(
        path: MoonRoutePaths.hubIndex,
        builder: (_, __) => HubScreen(
          client: client,
          categoryKey: null,
        ),
      ),
      GoRoute(
        path: MoonRoutePaths.hubTemplate,
        redirect: (context, state) => validate(state),
        builder: (context, state) => HubScreen(
          client: client,
          categoryKey: state.pathParameters['category'],
        ),
      ),
      GoRoute(
        path: MoonRoutePaths.hubSubTemplate,
        redirect: (context, state) =>
            validate(state, subKey: state.pathParameters['sub']),
        builder: (context, state) => HubScreen(
          client: client,
          categoryKey: state.pathParameters['category'],
          subKey: state.pathParameters['sub'],
        ),
      ),
    ],
  );
}

Future<void> pumpHub(
  WidgetTester tester, {
  String initialLocation = '/hub',
  double shellWidth = 420,
}) async {
  tester.view.physicalSize = Size(shellWidth, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final client = MockClient();
  when(() => client.userID).thenReturn('@me:example.com');
  when(() => client.getProfileFromUserId(any()))
      .thenAnswer((_) async => Profile(userId: '@me:example.com'));
  when(() => client.rooms).thenReturn(<Room>[]);

  final GoRouter router =
      buildHubRouter(client, initialLocation: initialLocation);
  addTearDown(router.dispose);

  // The hub hosts settings pages that read services the shared wrapper does
  // not supply: `LogsPage` reads `LogService`, and the profile editor reads
  // the encryption service. Both are stubbed rather than constructed.
  // `LogsPage` reads `LogService.logDir` (and calls `wipeLogs` from its clear
  // confirmation), so the mock needs the directory and the method. It lists
  // the real directory on disk, which in a test is an empty temp tree, so
  // nothing else has to be stubbed.
  final logService = MockLogService();
  when(() => logService.logDir).thenReturn(Directory.systemTemp.path);
  when(() => logService.wipeLogs).thenReturn(() async {});

  final encryption = MockEncryptionService();
  when(() => encryption.onKeyVerificationRequest)
      .thenAnswer((_) => const Stream<KeyVerification>.empty());
  // The encryption section reads a dozen fields off the service on its
  // first build. Stubbed to an unbootstrapped, unsupported state, which is
  // the shape that renders without further ceremony. This is the cost of
  // pointing a test at a page that was previously only reachable through
  // the hub's own routing, which is what made it worth adding.
  when(() => encryption.isSupported).thenReturn(false);
  when(() => encryption.crossSigningBootstrapped).thenReturn(false);
  when(() => encryption.keyBackupExists).thenReturn(false);
  when(() => encryption.keyBackupCached).thenReturn(false);
  when(() => encryption.keyBackupAlgorithm).thenReturn(null);
  when(() => encryption.masterKeyFingerprint).thenReturn(null);
  when(() => encryption.isThisDeviceVerified).thenReturn(false);
  // `countUnverified()` and `refresh()` are methods, not getters, so they are
  // stubbed with the call.
  when(() => encryption.countUnverified())
      .thenAnswer((_) async => (own: 0, other: 0));
  when(() => encryption.myDevices).thenReturn([]);
  when(() => encryption.refresh()).thenAnswer((_) async {});

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<LogService>.value(value: logService),
        ListenableProvider<EncryptionService>.value(value: encryption),
        ChangeNotifierProvider<SyncPulse>.value(value: SyncPulse()),
        // The hub reads this to decide between one pane and two. Committed
        // to [LayoutShell.mobile] here so the tests exercise the narrow
        // arrangement; the wide one is asserted separately by the
        // dual-pane group below, which commits the opposite.
        Provider<LayoutShellController>.value(
          value: LayoutShellController()
            ..resolve(rawWidth: shellWidth, layoutMode: LayoutMode.auto),
        ),
      ],
      child: wrapWithProviders(
        client: client,
        // Forwarded so the inner provider is the stubbed instance. Without
        // this, `wrapWithProviders` registers its own unstubbed fallback
        // closer to the tree than the one above, and it is that one the hub
        // ends up watching, which reads as a screen that will not build.
        encryptionService: encryption,
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
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  // These assert on which section [HubContent] was handed, not on text it
  // happened to render. Text assertions here would be testing the strings a
  // settings page happens to use; what matters is that the URL dispatched to
  // the right section, and that is observable from the widget.
  ({String? category, String? sub}) dispatched(WidgetTester tester) {
    final HubContent content =
        tester.widget<HubContent>(find.byType(HubContent));
    return (category: content.categoryKey, sub: content.subKey);
  }

  group('hub routes', () {
    testWidgets('the index renders the profile, not a section', (tester) async {
      await pumpHub(tester, initialLocation: '/hub');
      // A null category is the index. The profile used to be a fourth
      // category as well, which meant `/hub` and `/hub/profile` were two
      // URLs for one page and the narrow index had to choose between showing
      // the profile and listing it.
      expect(dispatched(tester).category, isNull);
    });

    testWidgets('a section deep link dispatches that section', (tester) async {
      await pumpHub(tester, initialLocation: '/hub/settings/logs');
      expect(
        dispatched(tester),
        (category: HubRouteKeys.settings, sub: HubRouteKeys.logs),
      );
    });

    testWidgets('a section overview dispatches with no sub-item',
        (tester) async {
      await pumpHub(tester, initialLocation: '/hub/settings');
      expect(
        dispatched(tester),
        (category: HubRouteKeys.settings, sub: null),
      );
    });

    // This is the class of bug the `network` palette entry was: a path
    // naming a sub-item that had never existed, rendering an empty pane.
    testWidgets('a sub-key with no matching page falls back to the category',
        (tester) async {
      await pumpHub(tester, initialLocation: '/hub/settings/network');
      expect(
        dispatched(tester),
        (category: HubRouteKeys.settings, sub: null),
      );
    });

    testWidgets('a sub-key under a section with no sub-items is dropped',
        (tester) async {
      await pumpHub(tester, initialLocation: '/hub/about/logs');
      expect(
        dispatched(tester),
        (category: HubRouteKeys.about, sub: null),
      );
    });

    testWidgets('an unknown section falls back to the index', (tester) async {
      await pumpHub(tester, initialLocation: '/hub/nonsense');
      // The index is the hub's front door, so a mistyped or retired link
      // lands on the profile rather than on an empty pane.
      expect(dispatched(tester).category, isNull);
    });

    // `profile` was a category key until it was folded into the index. A
    // link to it is from before that, or from a stale bookmark, and must not
    // become a section again.
    testWidgets('the retired profile section resolves to the index',
        (tester) async {
      await pumpHub(tester, initialLocation: '/hub/profile');
      expect(dispatched(tester).category, isNull);
    });
  });
  group('hub keys stay in step with the routes', () {
    test('every settings sub-item is a key the router accepts', () {
      // The router rejects anything not in these lists. A sub-item added to
      // the hub without adding its key here would render a pane that the
      // palette can link to and the router will redirect away from.
      expect(HubRouteKeys.settingsSubItems, isNotEmpty);
      for (final String sub in HubRouteKeys.settingsSubItems) {
        expect(HubRouteKeys.isSettingsSubItem(sub), isTrue, reason: sub);
      }
    });

    test('every category is a key the router accepts', () {
      for (final String category in HubRouteKeys.categories) {
        expect(HubRouteKeys.isCategory(category), isTrue, reason: category);
      }
    });

    test('hubPath round-trips through the segment matcher', () {
      expect(hubPath(category: HubRouteKeys.settings), '/hub/settings');
      expect(
        hubPath(
          category: HubRouteKeys.settings,
          sub: HubRouteKeys.appearance,
        ),
        '/hub/settings/appearance',
      );
      // An empty sub is the category, not a trailing slash.
      expect(
        hubPath(category: HubRouteKeys.settings, sub: ''),
        '/hub/settings',
      );
    });

    // Appearance and Layout were two pages and are one now. The old key still
    // resolves, because a bookmark, a command-palette hit from an older
    // session, or a link somebody was sent should land on the settings it
    // names rather than on the section's list of other settings.
    test('the retired layout key resolves to the page it became', () {
      expect(
        HubRouteKeys.replacementFor(HubRouteKeys.retiredLayout),
        HubRouteKeys.appearance,
      );
      // And it is genuinely retired: a key that stayed in the live list would
      // keep a row in the nav pointing at a page that no longer renders.
      expect(
        HubRouteKeys.isSettingsSubItem(HubRouteKeys.retiredLayout),
        isFalse,
      );
      expect(
        HubRouteKeys.settingsSubItems,
        isNot(contains(HubRouteKeys.retiredLayout)),
      );
    });

    test('every retired key points at a live sub-item', () {
      for (final entry in HubRouteKeys.retiredSubItems.entries) {
        expect(
          HubRouteKeys.isSettingsSubItem(entry.value),
          isTrue,
          reason: '${entry.key} -> ${entry.value}',
        );
      }
    });
  });

  // The point of the redesign: one set of destinations, two arrangements.
  // These pin which arrangement each shell gets, because the failure mode is
  // a hub that is subtly *different* in the two places rather than merely
  // sized differently.
  // Reported as: pressing back on the hub does nothing, after opening it and
// navigating around including in settings.
//
// The cause was not the button. It was a `BackButton`, which is
// `Navigator.maybePop` and is *disabled* when there is nothing to pop. The
// cause of *that* was that a section switch inside the hub used `go`, and
// `go` replaces the whole page stack: the first click destroyed the route
// the hub was opened from, so from that point on there was nothing to pop
// and nothing to return to.
//
// These pin the invariant that fixes it rather than the button's handler:
// the hub is a stack, so Back works at every depth and walking out of it
// returns to the entry point.
  group('hub is a stack, so Back always has somewhere to go', () {
    Key row(String category, [String? sub]) =>
        HubNavList.rowKey(category: category, subItem: sub);

    testWidgets('switching sections keeps the hub history', (tester) async {
      await pumpHub(tester, shellWidth: 1500, initialLocation: '/hub');
      final GoRouter router =
          GoRouter.of(tester.element(find.byType(HubNavList)));

      await tester.tap(find.byKey(row(HubRouteKeys.settings)));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/hub/settings');

      // The wide shell reveals the settings children inline, so a sub-item is
      // reachable without leaving the list.
      await tester.tap(
        find.byKey(row(HubRouteKeys.settings, HubRouteKeys.appearance)),
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/hub/settings/appearance');

      // The load-bearing assertion. With `go` here this is false, the back
      // button is inert, and the chat the hub was opened from is unrecoverable.
      expect(
        router.canPop(),
        isTrue,
        reason: 'a section switch must not discard the hub history',
      );
    });

    testWidgets('Back walks out of the hub section by section', (tester) async {
      await pumpHub(tester, shellWidth: 1500, initialLocation: '/hub');
      final GoRouter router =
          GoRouter.of(tester.element(find.byType(HubNavList)));

      await tester.tap(find.byKey(row(HubRouteKeys.settings)));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(row(HubRouteKeys.settings, HubRouteKeys.appearance)),
      );
      await tester.pumpAndSettle();

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/hub/settings');

      router.pop();
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/hub');

      // And out of the hub, back to where it was opened from.
      expect(router.canPop(), isFalse);
    });

    testWidgets('re-tapping the current row does not stack a duplicate',
        (tester) async {
      await pumpHub(tester, shellWidth: 1500, initialLocation: '/hub');
      final GoRouter router =
          GoRouter.of(tester.element(find.byType(HubNavList)));

      await tester.tap(find.byKey(row(HubRouteKeys.accounts)));
      await tester.pumpAndSettle();
      expect(router.canPop(), isTrue);

      await tester.tap(find.byKey(row(HubRouteKeys.accounts)));
      await tester.pumpAndSettle();

      // A second tap on the row you are already on would make Back appear to
      // do nothing for one press, which is the same symptom as the bug above
      // and would be easy to misreport as "back is broken again".
      expect(router.state.uri.path, '/hub/accounts');
      router.pop();
      await tester.pumpAndSettle();
      // One press, and we are at the index rather than still on Accounts.
      expect(router.state.uri.path, '/hub');
    });
  });

  // The hub has two exits and they are not interchangeable, which is the
  // point of having two. Back is a history step: it undoes one section
  // switch and, at the entry point, returns to whatever opened the hub.
  // Close is an exit: it discards the hub's whole stack and goes to the
  // dashboard, for someone who opened the hub to change one setting and
  // has changed it.
  testWidgets('close leaves the hub from any depth, in one press',
      (tester) async {
    await pumpHub(
      tester,
      initialLocation: '/hub/settings/layout',
      shellWidth: 1500,
    );
    final GoRouter router =
        GoRouter.of(tester.element(find.byType(HubNavList)));

    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    expect(router.state.uri.path, MoonRoutePaths.roomListTemplate);
    // Nothing left to walk back into. A pop would have left the sections
    // the user visited, which is the whole difference.
    expect(router.canPop(), isFalse);
  });

  testWidgets('close is offered next to back, and back is still a history step',
      (tester) async {
    await pumpHub(tester, initialLocation: '/hub', shellWidth: 1500);
    final GoRouter router =
        GoRouter.of(tester.element(find.byType(HubNavList)));

    expect(find.byTooltip('Back'), findsOneWidget);
    expect(find.byTooltip('Close'), findsOneWidget);

    await tester
        .tap(find.byKey(HubNavList.rowKey(category: HubRouteKeys.settings)));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/hub/settings');

    // Back unwinds one section, and the hub is still there.
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, MoonRoutePaths.hubIndex);
  });

  testWidgets('the encryption section carries a refresh action',
      (tester) async {
    await pumpHub(
      tester,
      initialLocation: '/hub/settings/security',
      shellWidth: 1500,
    );

    // The one section with a control of its own. It used to arrive with an
    // AppBar that the embedded presentation threw away, which left the hub
    // as the only place in the app where the only way to pick up a change
    // made on another device was to leave and open /main/encryption instead.
    expect(find.byType(EncryptionRefreshAction), findsOneWidget);
  });

  testWidgets('a section with no actions of its own has none', (tester) async {
    await pumpHub(
      tester,
      initialLocation: '/hub/settings/layout',
      shellWidth: 1500,
    );
    expect(find.byType(EncryptionRefreshAction), findsNothing);
  });

  group('hub arrangement', () {
    testWidgets('a wide window puts the section list beside the content',
        (tester) async {
      await pumpHub(tester, shellWidth: 1500);

      final HubNavList nav = tester.widget<HubNavList>(find.byType(HubNavList));
      expect(
        nav.expandActive,
        isTrue,
        reason: 'a sidebar beside the content has room to reveal the active '
            "section's children inline",
      );
      expect(find.byType(HubContent), findsOneWidget);
    });

    testWidgets('a narrow window does not expand the list inline',
        (tester) async {
      await pumpHub(tester, shellWidth: 420);

      final HubNavList nav = tester.widget<HubNavList>(find.byType(HubNavList));
      // Inline children here would be a list inside a list; on a stack of
      // full-screen pages the sub-item list is its own page instead.
      expect(nav.expandActive, isFalse);
    });

    testWidgets('the narrow index shows the profile and the list together',
        (tester) async {
      await pumpHub(tester, initialLocation: '/hub', shellWidth: 420);
      // "Your profile, then where you can go": the profile is not a separate
      // destination the user has to find, it is the first thing on the page.
      expect(find.byType(HubContent), findsOneWidget);
      expect(find.byType(HubNavList), findsOneWidget);
    });

    testWidgets('a section page on a narrow window drops the list',
        (tester) async {
      await pumpHub(tester, initialLocation: '/hub/about', shellWidth: 420);
      // Full-screen, with Back returning to the index. Repeating the list
      // under every section would make the hub feel like a menu rather than
      // a stack of pages.
      expect(find.byType(HubContent), findsOneWidget);
      expect(find.byType(HubNavList), findsNothing);
    });
  });
}

class MockLogService extends Mock implements LogService {}
