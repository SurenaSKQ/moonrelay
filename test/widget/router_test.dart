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
// License along with this program.  If not, see
// <https://www.gnu.org/licenses/>.

// Drives the real route table from MoonRouter.
//
// This suite exists because the router used to be the one file nothing
// tested. Three defects lived there for a long time and none of them
// showed up in the unit tests, because every one of them needs the actual
// GoRouter tree mounted:
//
//   * `/main/myprofile` handed a null user id to a widget that treated
//     null as an error, so the user's own profile page rendered an error
//     card.
//   * A `redirect` compared a percent-decoded user id while the
//     neighbouring `builder` passed the raw, still-encoded one.
//   * Every shell flip (a resize across the mobile breakpoint, or a
//     layout-mode change) called `router.go()` from a post-frame
//     callback, replacing the whole page stack and ejecting the user from
//     any room sub-route they had open.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/room_state_bus.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/layouts/mobile_layout.dart';
import 'package:moonrelay/src/widgets/command_palette/command_palette.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/router.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/services/deep_link_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';
import 'package:moonrelay/src/widgets/profile_view.dart';
import 'package:provider/provider.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

const _ownUserId = '@me:example.org';

/// Mounts the real [MoonRouter] route table with mocked SDK services.
Future<GoRouter> pumpRouter(
  WidgetTester tester, {
  required String initialLocation,
  Size size = const Size(1400, 900),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final client = MockClient();
  when(() => client.isLogged()).thenReturn(true);
  when(() => client.userID).thenReturn(_ownUserId);
  when(() => client.rooms).thenReturn(<Room>[]);
  when(() => client.getRoomById(any())).thenReturn(null);
  when(() => client.getRoomSummary(any(), via: any(named: 'via')))
      .thenThrow(Exception('no network in widget tests'));
  // The status bar subscribes to the SDK's sync-status stream; an
  // unstubbed mock returns null where a stream controller is expected.
  final syncStatus = CachedStreamController<SyncStatusUpdate>(null);
  when(() => client.onSyncStatus).thenReturn(syncStatus);

  // The dashboard mounts a verification listener that subscribes to this
  // stream; an unstubbed mock returns null where a Stream is expected.
  final encryption = MockEncryptionService();
  when(() => encryption.onKeyVerificationRequest)
      .thenAnswer((_) => const Stream<KeyVerification>.empty());

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: MoonRouter.routes,
  );

  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<Client>.value(value: client),
        Provider<Logger>.value(value: MockLogger()),
        ChangeNotifierProvider<SettingsController>.value(
          value: SettingsController(SettingsService()),
        ),
        ChangeNotifierProvider<AccountManager>.value(
          value: MockAccountManager(),
        ),
        ChangeNotifierProvider<EncryptionService>.value(
          value: encryption,
        ),
        ChangeNotifierProvider<CurrentRoom>(create: (_) => CurrentRoom()),
        ChangeNotifierProvider<NavigationState>(
            create: (_) => NavigationState()),
        Provider<DeepLinkService>.value(value: MockDeepLinkService()),
        Provider<LayoutShellController>(
          create: (_) => LayoutShellController(),
        ),
        ChangeNotifierProvider<SyncPulse>(create: (_) => SyncPulse()),
        Provider<RoomStateBus>(create: (_) => RoomStateBus()),
        ChangeNotifierProvider<SpacePreferences>(
          create: (_) => SpacePreferences(SettingsService()),
        ),
      ],
      child: MaterialApp.router(
        theme: testMoonrelayTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );

  // Several frames: the shell commits in didChangeDependencies, then the
  // route pages inflate, then the boot-time post-frame callbacks land.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return router;
}

void main() {
  group('MoonRouter routes', () {
    // The single-pane shell's "You" navigation destination used to render
    // `OwnAccountPage`, a page hosting the profile editor plus three links
    // into the hub. That meant two routes rendering the same editor and the
    // hub's section list existed in two places that had to be kept in step.
    // The hub's index is the profile followed by that list, in the same
    // order, so the destination now redirects there.
    //
    // Pinned against the real route table, not a test-local copy: the thing
    // worth protecting is the redirect on `MoonRoutePaths.youTemplate`, and
    // a local router that omitted the route would agree with any change.
    testWidgets('/main/me redirects to the hub index', (tester) async {
      final router = await pumpRouter(tester, initialLocation: '/main/me');
      expect(router.state.uri.path, MoonRoutePaths.hubIndex);
    });

    testWidgets('/main/myprofile shows the signed-in user, not an error',
        (tester) async {
      final router = await pumpRouter(
        tester,
        initialLocation: '/main/myprofile',
      );

      // The bug: this route passed a null id down, and a null was rendered
      // as an error state on the user's own profile page.
      expect(find.byType(EmptyState), findsNothing);
      expect(find.byType(ProfileView), findsOneWidget);
      expect(find.text('Error'), findsNothing);
      expect(
        tester.widget<ProfileView>(find.byType(ProfileView)).userId,
        _ownUserId,
      );

      router.dispose();
    });

    testWidgets(
        '/main/rooms with no room selected is a dashboard, not an error',
        (tester) async {
      final router = await pumpRouter(
        tester,
        initialLocation: '/main/rooms',
      );

      // The bug: this page used to build a RoomDelegate with a null room
      // id, which rendered "Room not found" in the middle of a perfectly
      // healthy dashboard. It must never show an error here again.
      expect(find.text('Room not found'), findsNothing);

      // What it shows now: a home dashboard with somewhere to go, because
      // "pick a room from the sidebar" told a user who had just signed in to
      // an account with a hundred rooms to use a control they had not been
      // told about.
      expect(find.text('Welcome to Moonrelay'), findsOneWidget);
      expect(find.text('Create Room'), findsOneWidget);
      expect(find.text('Join a room'), findsOneWidget);
      expect(find.text('Explore spaces'), findsOneWidget);

      router.dispose();
    });

    testWidgets(
        'a pushed route survives a resize across the mobile '
        'breakpoint', (tester) async {
      final router = await pumpRouter(
        tester,
        initialLocation: '/main/rooms',
      );

      // Pushed, not navigated to, so it sits on the navigator stack. The
      // old code answered every shell flip with `router.go(...)`, which
      // replaced that stack; the pushed page was gone the moment the window
      // crossed the mobile boundary.
      router.push('/main/myprofile');
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.byType(ProfileView), findsOneWidget);

      // Cross down through mobile and back up. Pump enough frames for a
      // post-frame navigation to have happened if one were scheduled.
      for (final size in const [
        Size(400, 900),
        Size(1400, 900),
        Size(400, 900),
      ]) {
        tester.view.physicalSize = size;
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 60));
        }
        expect(find.byType(ProfileView), findsOneWidget,
            reason: 'the pushed page was dropped at $size');
      }

      router.dispose();
    });

    // The single-pane shell used to answer "am I in a room?" by testing for
    // the presence of a `roomid` path parameter, which is true for every
    // child of the room route. It then drew a top bar on top of whatever the
    // page had already drawn, so room settings, thread view and room details
    // each got a doubled header and a second, competing back arrow stacked
    // above the `AppBar` they already render. These pin the corrected rule:
    // the shell decorates only the routes it owns, and it never drops the
    // page.
    group('single-pane shell chrome', () {
      // Narrow enough to resolve the mobile shell (mobileMax is 600).
      const Size phone = Size(420, 900);

      // The shell top bar's title. It names the destination rather than the
      // app, because the navigation bar directly below already says where
      // you are. Scoped to the bar by key, because the navigation bar
      // deliberately repeats the same label and a bare text count would
      // conflate the two.
      const String shellTitle = 'Chats';
      int shellTitleCount(WidgetTester tester) => tester
          .widgetList<Text>(
            find.descendant(
              of: find.byKey(kMobileShellTopBar),
              matching: find.text(shellTitle),
            ),
          )
          .length;

      testWidgets('draws its own top bar on the room list', (tester) async {
        final router = await pumpRouter(
          tester,
          initialLocation: '/main/rooms',
          size: phone,
        );

        // RoomsPane only mounts under the mobile shell; the desktop branch
        // is an EmptyState. So the shell title here is the shell's own bar.
        expect(shellTitleCount(tester), 1);
        router.dispose();
      });

      testWidgets('renders the page on a route the shell does not decorate',
          (tester) async {
        final router = await pumpRouter(
          tester,
          initialLocation: '/main/myprofile',
          size: phone,
        );

        // The regression this guards: the shell once returned a
        // SizedBox.shrink() for any route it did not decorate, which blanked
        // the whole page instead of just omitting the bar.
        expect(find.byType(ProfileView), findsOneWidget);
        expect(shellTitleCount(tester), 0);
        router.dispose();
      });

      testWidgets('adds no top bar above a pushed sub-page', (tester) async {
        final router = await pumpRouter(
          tester,
          initialLocation: '/main/rooms',
          size: phone,
        );

        final int onList = shellTitleCount(tester);
        expect(onList, 1, reason: 'precondition: the list has the shell bar');

        router.push('/main/myprofile');
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.byType(ProfileView), findsOneWidget);
        expect(
          shellTitleCount(tester),
          0,
          reason: 'the shell stacked its own top bar on a page that already '
              'renders an AppBar',
        );
        router.dispose();
      });

      // The gap that made the single-pane shell unusable: its two entry
      // points to search and to the user's own profile lived in a sidebar it
      // does not mount, so both were unreachable, and with them every page
      // behind them (settings, accounts, devices, logs, logout).
      testWidgets('shows the navigation bar on a destination', (tester) async {
        final router = await pumpRouter(
          tester,
          initialLocation: '/main/rooms',
          size: phone,
        );

        expect(find.byKey(kMobileShellNavigationBar), findsOneWidget);
        expect(find.byType(NavigationDestination), findsNWidgets(4));
        router.dispose();
      });

      testWidgets('hides the navigation bar inside a room', (tester) async {
        final router = await pumpRouter(
          tester,
          initialLocation: '/main/rooms/!room:example.org',
          size: phone,
        );

        // A conversation is not a tab, and the bar would cost the chat its
        // vertical space.
        expect(find.byKey(kMobileShellNavigationBar), findsNothing);
        router.dispose();
      });

      testWidgets('a destination switch is lateral, not a history step',
          (tester) async {
        final router = await pumpRouter(
          tester,
          initialLocation: '/main/rooms',
          size: phone,
        );

        // Chats, then Spaces. The bar's Search destination is gone: search is
        // the palette, which is a modal on every shell rather than a tab you
        // can be "on".
        await tester.tap(
          find.descendant(
            of: find.byKey(kMobileShellNavigationBar),
            matching: find.text('Spaces'),
          ),
        );
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(router.state.uri.path, MoonRoutePaths.spacesTemplate);
        // `go`, so switching tabs did not stack a page the user would have
        // to walk back through.
        expect(router.canPop(), isFalse);
        router.dispose();
      });

      testWidgets('the top bar opens the palette rather than navigating',
          (tester) async {
        final router = await pumpRouter(
          tester,
          initialLocation: '/main/rooms',
          size: phone,
        );

        // The bar's search button used to `go` to `/main/search`, a fourth
        // destination holding a page with its own copy of the search. It now
        // opens the palette, so the URL does not change and the conversation
        // underneath keeps its position.
        await tester.tap(find.byIcon(LucideIcons.search).first);
        for (var i = 0; i < 8; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.byType(CommandPalettePage), findsOneWidget);
        expect(router.state.uri.path, MoonRoutePaths.roomListTemplate);
        router.dispose();
      });
    });

    testWidgets(
        'path parameters reach the profile view exactly once '
        'decoded', (tester) async {
      // A user ID may legitimately contain a percent sign. GoRouter decodes
      // matched segments itself, so decoding again here would either mangle
      // the value or throw on the stray `%`. These are the characters that
      // make the difference.
      for (final userId in const [
        '@alice:example.org',
        '@a/b:example.org',
        '@a%b:example.org',
        '@a+b:example.org',
      ]) {
        final router = await pumpRouter(
          tester,
          initialLocation: '/profile/${Uri.encodeComponent(userId)}',
        );

        expect(
          tester.widget<ProfileView>(find.byType(ProfileView)).userId,
          userId,
          reason: 'user id $userId was mangled in transit',
        );
        expect(find.byType(EmptyState), findsNothing);

        router.dispose();
        await tester.pumpWidget(const SizedBox.shrink());
      }
    });
  });
}
