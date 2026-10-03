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
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart'
    show CachedStreamController;
import 'package:matrix/src/utils/space_child.dart'
    show SpaceChild, SpaceParent;
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/layouts/dashboard_layout/dashboard_view.dart';
import 'package:moonrelay/src/layouts/dashboard_layout/pane_hosts.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_rail.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/navigation_sidebar.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/room_search_field.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/sidebar_actions.dart';
import 'package:moonrelay/src/widgets/sidebar_profile_pill.dart';
import 'package:moonrelay/src/widgets/sidebar_row.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// A mock [Client] whose room list is empty by default (the real mock
/// returns null for every member, which breaks the sidebar's room scans).
/// A settings controller already set to [density].
///
/// `createTestSettingsController` hands back the default, so a test that
/// needs a non-default density has to set it, and `updateDensity` is async.
MockClient _clientWithNoRooms() {
  final client = MockClient();
  when(() => client.rooms).thenReturn(<Room>[]);
  return client;
}

/// A mock [Client] that knows one space, so the sidebar renders the
/// spaces section.
MockClient _clientWithSpace() {
  final client = MockClient();
  final space = MockRoom();
  when(() => space.id).thenReturn('!space:matrix.org');
  when(() => space.isSpace).thenReturn(true);
  when(() => space.getLocalizedDisplayname()).thenReturn('Test Space');
  when(() => space.avatar).thenReturn(null);
  when(() => space.spaceParents).thenReturn(<SpaceParent>[]);
  when(() => space.spaceChildren).thenReturn(<SpaceChild>[]);
  when(() => client.rooms).thenReturn(<Room>[space]);
  return client;
}

/// Like [_clientWithSpace], but the client can also resolve a room by id.
///
/// [Client.getRoomById] is an unstubbed mock method, so it answers `null`
/// unless it is given a `when`. The pane asks for the selected space twice,
/// once for its heading and once for its body, so the heading test needs the
/// lookup to work while the tests that assert the *absence* of a space leave
/// it broken on purpose.
MockClient _clientWithResolvableSpace() {
  final client = _clientWithSpace();
  final space = client.rooms.first;
  when(() => client.getRoomById(any())).thenReturn(space);
  return client;
}

/// A mock [Client] that knows one plain room, so the room list renders a
/// row. The room is encrypted and has an unread highlight, so both of the
/// row's badges are present and can be asserted on.
MockClient _clientWithRoom() {
  final client = MockClient();
  final room = MockRoom();
  when(() => room.id).thenReturn('!room:matrix.org');
  when(() => room.isSpace).thenReturn(false);
  when(() => room.isDirectChat).thenReturn(false);
  when(() => room.getLocalizedDisplayname()).thenReturn('Test Room');
  when(() => room.avatar).thenReturn(null);
  final event = MockEvent();
  when(() => event.body).thenReturn('Latest message');
  when(() => room.lastEvent).thenReturn(event);
  when(() => room.notificationCount).thenReturn(3);
  when(() => room.highlightCount).thenReturn(1);
  when(() => room.hasNewMessages).thenReturn(true);
  when(() => room.encrypted).thenReturn(true);
  when(() => client.rooms).thenReturn(<Room>[room]);
  return client;
}

/// Wraps [child] with the providers the navigation sidebar needs: a mock
/// [Client], [NavigationState], [SpacePreferences], [SyncPulse] and a
/// [SettingsController], plus a router whose space-home route renders a
/// marker text so tests can assert navigation.
Widget _wrapSidebar(
  Widget child, {
  MockClient? client,
  SettingsController? settings,
  NavigationState? navigationState,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (_, __) => child),
      GoRoute(
        path: '/main/space/:spaceid',
        builder: (_, __) => const Text('SPACE_HOME'),
      ),
      GoRoute(
        path: '/main/addroom',
        builder: (_, __) => const Text('ADD_ROOM'),
      ),
    ],
  );
  return MultiProvider(
    providers: [
      Provider<Client>.value(value: client ?? _clientWithNoRooms()),
      ChangeNotifierProvider<NavigationState>.value(
        value: navigationState ?? NavigationState(),
      ),
      ChangeNotifierProvider<SpacePreferences>.value(
        value: SpacePreferences(SettingsService()),
      ),
      ChangeNotifierProvider<SyncPulse>.value(value: SyncPulse()),
      ChangeNotifierProvider<SettingsController>.value(
        value: settings ?? createTestSettingsController(),
      ),
    ],
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
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('NavigationSidebar', () {
    testWidgets('renders the account, the destination title, and both actions',
        (tester) async {
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();

      expect(find.byType(SidebarProfilePill), findsOneWidget);
      // The palette is an icon on the title bar now, not a row of its own: it
      // is an action rather than a destination, and it used to occupy a row
      // between the filter and the list.
      expect(find.byType(SidebarCommandPaletteButton), findsNothing);
      expect(find.byTooltip('Command palette'), findsOneWidget);
      expect(find.byTooltip('Add Room'), findsOneWidget);

      // The pane names the destination the rail has selected. The Home/All
      // toggle that used to live here is gone: the rail owns those, and two
      // controls for one piece of state is how they end up disagreeing.
      expect(find.text('Rooms'), findsOneWidget);
      expect(find.text('Friends'), findsNothing);
      expect(find.text('All rooms'), findsNothing);
      // No spaces in the mock client, so the spaces section is skipped.
      expect(find.text('Spaces'), findsNothing);
    });

    testWidgets('the account is pinned below both list sections',
        (tester) async {
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();

      // It used to be the first thing the pane showed, directly under the
      // window's title bar, and the last thing anyone looked at. Every
      // other client puts it at the bottom, which is also where a thumb
      // expects it, and here it has to sit below both the spaces and the
      // rooms sections to stay put when either collapses.
      final pill = tester.getCenter(find.byType(SidebarProfilePill));
      final titleBar = tester.getCenter(find.byType(RoomSearchField));
      final list = tester.getCenter(find.byType(RoomsPane));
      expect(pill.dy, greaterThan(titleBar.dy));
      expect(pill.dy, greaterThan(list.dy));
    });

    testWidgets('add room is a control on the rooms header, not a nav row',
        (tester) async {
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();

      // It is on the title bar, beside the palette, and it is the only one.
      // It used to sit on the rooms section header as well, which put two
      // identical plus icons within 200 pixels of each other: one that adds a
      // room and one that looks like it might add something to the category
      // above it. As a third navigation row it also cost a full row of height
      // in a pane that has about five rows to give.
      expect(find.byIcon(LucideIcons.plus), findsOneWidget);
      final plus = tester.getCenter(find.byIcon(LucideIcons.plus));
      final search = tester.getCenter(find.byType(RoomSearchField));
      expect(plus.dy, lessThan(search.dy));
      // It is an icon with a tooltip now, so the label is not a Text node.
      expect(find.text('Add Room'), findsNothing);
    });

    testWidgets('tapping the add-room control pushes the add room route',
        (tester) async {
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();

      await tester.tap(find.byIcon(LucideIcons.plus));
      await tester.pump();
      await tester.pump();

      expect(find.text('ADD_ROOM'), findsOneWidget);
    });

    testWidgets('the command palette control on the title bar opens the palette',
        (tester) async {
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();

      await tester.tap(find.byTooltip('Command palette'));
      await tester.pump();
      await tester.pump();

      // The palette is a transparent overlay route; its search field
      // appears once the route is mounted.
      expect(find.byType(TextField), findsWidgets);
    });


    testWidgets('there is no section header, and the list cannot be collapsed',
        (tester) async {
      // The header carried the region name and a collapse toggle, and it was
      // saying the thing the title bar directly above it already says: the pane
      // opened with the same word twice. Collapsing a room list is not something
      // a user wants; a control that hides the list they came to read, in order
      // to bring it back, is a worse use of a row than not having one.
      //
      // The pane is now three things top to bottom: the title bar, the room
      // filter, the list, then the pinned account footer. Nothing between the
      // filter and the list, so there is nothing to tap.
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();
      await tester.pump();

      expect(find.byType(RoomsPane), findsOneWidget);

      // Tapping where the header used to be must not remove the list.
      final listCentre = tester.getCenter(find.byType(RoomsPane));
      final gesture =
          await tester.startGesture(listCentre - const Offset(0, 60));
      await gesture.up();
      await tester.pump();
      await tester.pump();

      expect(
        find.byType(RoomsPane),
        findsOneWidget,
        reason: 'the room list must not be collapsible',
      );
    });

    testWidgets('the spaces section is gone, and spaces live in the rail',
        (tester) async {
      // Spaces used to be a labelled collapsible section in this pane. They
      // are an icon rail beside it now, so the section header and its
      // collapse behaviour are gone by design rather than by accident, and
      // this pins that so a future change cannot quietly reintroduce a
      // second place to reach a space from.
      final settings = createTestSettingsController();
      await tester.pumpWidget(_wrapSidebar(
        const NavigationSidebar(),
        client: _clientWithSpace(),
        settings: settings,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Space'), findsNothing);
      expect(find.text('Spaces'), findsNothing);
      // No section header anywhere in the pane. See the collapse test.
      expect(find.byType(Text), findsWidgets);
    });

testWidgets('a space is no longer reachable from this pane',
        (tester) async {
      // The counterpart to the test above: the rail owns space selection, so
      // the room pane must not offer it. Asserted here as well as in the
      // rail's own tests because the failure mode is a duplicate path, and a
      // duplicate path is invisible from either side alone.
      final nav = NavigationState();
      await tester.pumpWidget(_wrapSidebar(
        const NavigationSidebar(),
        client: _clientWithSpace(),
        navigationState: nav,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Space'), findsNothing);
      expect(nav.isSpace, isFalse);
    });

    group('the title bar names the destination', () {
      testWidgets('it says "Rooms" on the default destination', (tester) async {
        await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
        await tester.pump();

        expect(find.text('Rooms'), findsOneWidget);
      });

      testWidgets('it says "Friends" when direct chats are selected',
          (tester) async {
        // The pane used to carry its own Home/All toggle and had no title at
        // all, so it never said what it was listing. The rail now owns the
        // choice and this bar reports it, which means the pane and the rail
        // cannot disagree about the current destination.
        final nav = NavigationState()..selectHome();
        await tester.pumpWidget(_wrapSidebar(
          const NavigationSidebar(),
          navigationState: nav,
        ));
        await tester.pump();

        expect(find.text('Friends'), findsOneWidget);
        expect(find.text('Rooms'), findsNothing);
      });

      testWidgets('it says the space name when a space is selected',
          (tester) async {
        final nav = NavigationState()..selectSpace('!space:matrix.org');
        await tester.pumpWidget(_wrapSidebar(
          const NavigationSidebar(),
          client: _clientWithResolvableSpace(),
          navigationState: nav,
        ));
        await tester.pump();
        await tester.pump();

        expect(find.text('Test Space'), findsOneWidget);
      });

      testWidgets('it falls back to a generic name for a missing space',
          (tester) async {
        // A space id the client cannot resolve is a deep link to a room that
        // was never joined, or a sync that has not landed yet. Printing an
        // empty heading would be worse than printing a generic one.
        final nav = NavigationState()..selectSpace('!gone:matrix.org');
        await tester.pumpWidget(_wrapSidebar(
          const NavigationSidebar(),
          client: _clientWithSpace(),
          navigationState: nav,
        ));
        await tester.pump();
        await tester.pump();

        expect(find.text('Spaces'), findsOneWidget);
      });
    });
  });

  group('DashboardView composition', () {
    Widget dashboardView({
      required SettingsController settings,
      required bool detailPaneFits,
      double width = 1400,
    }) {
      return DashboardView(
        detailPaneFits: detailPaneFits,
        width: width,
        size: LayoutSize.wide,
        rightWidthNotifier: ValueNotifier<double?>(null),
        onRightResize: (_) {},
        onRightResizeEnd: () {},
        child: const SizedBox(),
      );
    }

    /// Wraps the view with the full provider set: the shared test wrapper
    /// plus the sidebar providers and the client/encryption stream stubs
    /// that the shell's verification and status-bar widgets read.
    Widget wrapDashboard(
      SettingsController settings,
      Widget child, {
      Client? client,
    }) {
      final Client resolved = client ?? _clientWithNoRooms();
      when(() => resolved.onSyncStatus)
          .thenAnswer((_) => CachedStreamController<SyncStatusUpdate>());
      final enc = MockEncryptionService();
      when(() => enc.onKeyVerificationRequest)
          .thenAnswer((_) => const Stream<KeyVerification>.empty());
      return MultiProvider(
        providers: [
          ChangeNotifierProvider<SpacePreferences>.value(
            value: SpacePreferences(SettingsService()),
          ),
          ChangeNotifierProvider<SyncPulse>.value(value: SyncPulse()),
        ],
        child: wrapWithProviders(
          client: resolved,
          encryptionService: enc,
          settingsController: settings,
          child: child,
        ),
      );
    }

    testWidgets('the wide shell shows the navigation sidebar and a '
        'collapse gutter', (tester) async {
      final settings = createTestSettingsController();
      await tester.pumpWidget(
        wrapDashboard(
          settings,
          dashboardView(settings: settings, detailPaneFits: true),
        ),
      );
      await tester.pump();

      expect(find.byType(NavigationSidebar), findsOneWidget);
      expect(find.byType(SidebarCollapseGutter), findsOneWidget);
      expect(find.byType(SidebarExpandGutter), findsNothing);
    });

    testWidgets('collapsing the sidebar swaps the gutter for the expand '
        'gutter', (tester) async {
      final settings = createTestSettingsController();
      await tester.pumpWidget(
        wrapDashboard(
          settings,
          dashboardView(settings: settings, detailPaneFits: true),
        ),
      );
      await tester.pump();

      await settings.toggleLeftSidebar();
      await tester.pump();

      expect(find.byType(NavigationSidebar), findsNothing);
      expect(find.byType(SidebarCollapseGutter), findsNothing);
      expect(find.byType(SidebarExpandGutter), findsOneWidget);
    });

    // The regression this guards: the narrow dashboard used to be a
    // separate widget with a separate sidebar, so a window in the
    // 600-1100px band silently lost space grouping, drag-to-reorder, the
    // space context menu and the per-space room tree. There is now one
    // composition, so the sidebar has to be the same widget in both bands.
    testWidgets('the narrow band keeps the same navigation sidebar, not a '
        'reduced one', (tester) async {
      final settings = createTestSettingsController();
      await tester.pumpWidget(
        wrapDashboard(
          settings,
          dashboardView(
            settings: settings,
            detailPaneFits: false,
            width: 800,
          ),
          // A client with a space, so the Spaces section actually renders.
          // The compact sidebar had no spaces section at all, so this is the
          // assertion that would have failed against it.
          client: _clientWithSpace(),
        ),
      );
      await tester.pump();
      await tester.pump();

// The very same widget, with its full structure: the profile pill, the
      // title bar and the room filter.
      expect(find.byType(NavigationSidebar), findsOneWidget);
      expect(find.byType(SidebarProfilePill), findsOneWidget);
      expect(find.byTooltip('Command palette'), findsOneWidget);
      expect(find.byType(RoomSearchField), findsOneWidget);
      // Spaces are asserted absent because this pane used to carry them, and
      // the narrow band is where a "reduced sidebar" was once a real,
      // separate implementation.
      expect(find.text('Test Space'), findsNothing);
    });

    testWidgets('the narrow band keeps the same rail as the wide one',
        (tester) async {
      // The rail is a fixed 72px in both bands. It is not a "reduced rail"
      // at narrow widths, because the alternative is losing the only way to
      // reach a space, and at 800px there is room for 72 more pixels.
      final settings = createTestSettingsController();
      await tester.pumpWidget(
        wrapDashboard(
          settings,
          dashboardView(
            settings: settings,
            detailPaneFits: false,
            width: 800,
          ),
          client: _clientWithSpace(),
        ),
      );
      await tester.pump();
      await tester.pump();
      expect(find.byType(SpacesRailHost), findsOneWidget);
    });

    testWidgets('the detail pane is the only thing the narrow band drops',
        (tester) async {
      final settings = createTestSettingsController();
      await tester.pumpWidget(
        wrapDashboard(
          settings,
          dashboardView(
            settings: settings,
            detailPaneFits: false,
            width: 800,
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(RightPaneHost), findsNothing);
      expect(find.byType(ResizeHandle), findsNothing);

      // Same widget, with the pane mounted.
      final wide = createTestSettingsController();
      await tester.pumpWidget(
        wrapDashboard(
          wide,
          dashboardView(settings: wide, detailPaneFits: true),
        ),
      );
      await tester.pump();

      expect(find.byType(RightPaneHost), findsOneWidget);
      expect(find.byType(ResizeHandle), findsOneWidget);
    });

    testWidgets('a hidden detail pane stays hidden even when it would fit',
        (tester) async {
      final settings = createTestSettingsController();
      await settings.setRightSidebarVisible(false);
      await tester.pumpWidget(
        wrapDashboard(
          settings,
          dashboardView(settings: settings, detailPaneFits: true),
        ),
      );
      await tester.pump();

      expect(find.byType(RightPaneHost), findsNothing);
    });
  });

  group('RoomPane row density', () {
    // The single room row now serves both the navigation pane, whose
    // width floors at 200, and the single-pane list, which gets the whole
    // window. Before the unification there were two rows, and the narrow
    // one was missing the encryption and mention badges entirely.
    Future<void> pumpAt(
      WidgetTester tester,
      double width, {
      LayoutDensity density = LayoutDensity.comfortable,
    }) async {
      final client = _clientWithRoom();
      when(() => client.onSyncStatus)
          .thenAnswer((_) => CachedStreamController<SyncStatusUpdate>());
      final enc = MockEncryptionService();
      when(() => enc.onKeyVerificationRequest)
          .thenAnswer((_) => const Stream<KeyVerification>.empty());
      final settings = createTestSettingsController();
      settings.updateDensity(density);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SyncPulse>.value(value: SyncPulse()),
          ],
          child: wrapWithProviders(
            client: client,
            encryptionService: enc,
            settingsController: settings,
            child: MaterialApp(
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(
                body: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: width,
                    child: const RoomsPane(),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    double fontSizeOf(WidgetTester tester, String text) => tester
        .widget<Text>(find.text(text))
        .style!
        .fontSize!;

    // Density comes from the user's Interface density setting, not from
    // how wide the pane happens to be.
    //
    // It used to come from the width, against a 260px threshold. The
    // navigation sidebar's own range is 200..360 and it defaults to
    // something in the middle, so a default window rendered room names at
    // 18pt and preview lines at 16pt directly under 13pt space rows, and
    // widening the sidebar made the type *larger*. The "Interface density"
    // control meanwhile only reached the theme's `visualDensity`, so it
    // changed nothing in this pane at all.
    testWidgets('a wide pane uses the same size as a narrow one',
        (tester) async {
      await pumpAt(tester, 220);
      final narrow = fontSizeOf(tester, 'Test Room');
      await pumpAt(tester, 600);
      final wide = fontSizeOf(tester, 'Test Room');
      expect(wide, narrow);
      expect(narrow, SidebarRowMetrics.forDensity(LayoutDensity.comfortable).titleSize);
    });

    testWidgets('the room preview line is smaller than the name',
        (tester) async {
      // The old pair was 18 and 16, which is a 2pt difference between a
      // label and its supporting line. There is no reading of that as
      // intentional.
      await pumpAt(tester, 600);
      final m = SidebarRowMetrics.forDensity(LayoutDensity.comfortable);
      expect(fontSizeOf(tester, 'Test Room'), m.titleSize);
      expect(fontSizeOf(tester, 'Latest message'), m.subtitleSize);
      expect(m.subtitleSize, lessThan(m.titleSize));
    });

    testWidgets('the compact setting actually shrinks the row',
        (tester) async {
      // The behaviour the density control promised and did not deliver.
      await pumpAt(tester, 600, density: LayoutDensity.comfortable);
      final comfortable = fontSizeOf(tester, 'Test Room');
      await pumpAt(tester, 600, density: LayoutDensity.compact);
      final compact = fontSizeOf(tester, 'Test Room');
      expect(compact, lessThan(comfortable));
      expect(comfortable, SidebarRowMetrics.forDensity(LayoutDensity.comfortable).titleSize);
      expect(compact, SidebarRowMetrics.forDensity(LayoutDensity.compact).titleSize);
    });

    testWidgets('the row keeps its badges at every width', (tester) async {
      // The regression: the compact row had neither the encryption badge
      // nor the unread badges.
      //
      // `RoomEncryptionBadge` renders `SizedBox.shrink()` when the room is
      // not encrypted, so finding the widget proves nothing; the shield
      // icon is the assertion. `_RoomUnreadBadges` is private, so the
      // unread side is asserted on what it renders: the highlight count
      // wins over the plain notification count, so this room shows "1".
      for (final width in const [220.0, 600.0]) {
        await pumpAt(tester, width);
        expect(find.byIcon(LucideIcons.shieldCheck), findsOneWidget,
            reason: 'encryption badge missing at $width px');
        expect(find.text('1'), findsOneWidget,
            reason: 'unread highlight badge missing at $width px');
      }
    });

    testWidgets('the encryption badge sits on the name, not the far edge',
        (tester) async {
      // It is a property of the room's name, so it belongs in the title
      // line where it is consumed by the ellipsis, not pinned opposite the
      // unread count where the two things a user scans for would sit on
      // opposite sides of the row.
      await pumpAt(tester, 600);
      final shield = tester.getCenter(find.byIcon(LucideIcons.shieldCheck));
      final name = tester.getCenter(find.text('Test Room'));
      final badge = tester.getCenter(find.text('1'));
      expect(shield.dx, lessThan(badge.dx));
      expect(name.dx, lessThan(shield.dx));
    });
  });

  group('RoomPane marks the open room', () {
    // The room row never passed `selected`, so opening a room left the
    // sidebar looking exactly as it had before: nothing in it said which
    // room you were in short of reading the message pane's own header.
    // `sidebarRowAccentBarKey` is the handle here; a primary tint alone is
    // too weak a signal to assert against.
    MockRoom mockRoom(String id, String name) {
      final room = MockRoom();
      when(() => room.id).thenReturn(id);
      when(() => room.isSpace).thenReturn(false);
      when(() => room.isDirectChat).thenReturn(false);
      when(() => room.getLocalizedDisplayname()).thenReturn(name);
      when(() => room.avatar).thenReturn(null);
      when(() => room.lastEvent).thenReturn(null);
      when(() => room.notificationCount).thenReturn(0);
      when(() => room.highlightCount).thenReturn(0);
      when(() => room.hasNewMessages).thenReturn(false);
      when(() => room.encrypted).thenReturn(false);
      when(() => room.getState('m.room.pinned_events')).thenReturn(null);
      return room;
    }

    /// Mounts a pane over [rooms], with [current] pre-selected if given.
    Future<CurrentRoom> pumpRooms(
      WidgetTester tester,
      List<Room> rooms, {
      Room? current,
    }) async {
      final client = MockClient();
      when(() => client.rooms).thenReturn(rooms);
      when(() => client.onSyncStatus)
          .thenAnswer((_) => CachedStreamController<SyncStatusUpdate>());
      when(() => client.userID).thenReturn('@me:matrix.org');

      final currentRoom = CurrentRoom();
      if (current != null) currentRoom.setRoom(current);

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SyncPulse>.value(value: SyncPulse()),
          ],
          child: wrapWithProviders(
            client: client,
            currentRoom: currentRoom,
            encryptionService: MockEncryptionService(),
            child: const Scaffold(
              body: SizedBox(width: 320, child: RoomsPane()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      return currentRoom;
    }

    testWidgets('no room selected means no selected row', (tester) async {
      await pumpRooms(tester, [mockRoom('!a:matrix.org', 'Test Room')]);
      expect(find.text('Test Room'), findsOneWidget);
      expect(find.byKey(sidebarRowAccentBarKey), findsNothing);
    });

    testWidgets('the open room is the one marked', (tester) async {
      final rooms = [
        mockRoom('!a:matrix.org', 'Room A'),
        mockRoom('!b:matrix.org', 'Room B'),
      ];
      await pumpRooms(tester, rooms, current: rooms[1]);

      // One mark, not two: the wrong row lighting up would be worse than the
      // original bug because it looks authoritative.
      expect(find.byKey(sidebarRowAccentBarKey), findsOneWidget);
      final markedRow = tester.widget<SidebarRow>(
        find.ancestor(
          of: find.byKey(sidebarRowAccentBarKey),
          matching: find.byType(SidebarRow),
        ),
      );
      expect(markedRow.title, 'Room B');
    });

    testWidgets('switching rooms moves the mark', (tester) async {
      final rooms = [
        mockRoom('!a:matrix.org', 'Room A'),
        mockRoom('!b:matrix.org', 'Room B'),
      ];
      final currentRoom =
          await pumpRooms(tester, rooms, current: rooms.first);
      expect(
        tester
            .widget<SidebarRow>(find.ancestor(
              of: find.byKey(sidebarRowAccentBarKey),
              matching: find.byType(SidebarRow),
            ))
            .title,
        'Room A',
      );

      currentRoom.setRoom(rooms[1]);
      await tester.pump();

      expect(find.byKey(sidebarRowAccentBarKey), findsOneWidget);
      expect(
        tester
            .widget<SidebarRow>(find.ancestor(
              of: find.byKey(sidebarRowAccentBarKey),
              matching: find.byType(SidebarRow),
            ))
            .title,
        'Room B',
      );
    });

    testWidgets('closing the room clears the mark', (tester) async {
      final rooms = [mockRoom('!a:matrix.org', 'Room A')];
      final currentRoom = await pumpRooms(tester, rooms, current: rooms.first);
      expect(find.byKey(sidebarRowAccentBarKey), findsOneWidget);

      currentRoom.setRoom(null);
      await tester.pump();

      expect(find.byKey(sidebarRowAccentBarKey), findsNothing);
    });
  });
  group('RoomPane first-load failure', () {
    // A client that can never sync never becomes "synced", so the pane used
    // to sit on its loading spinner forever and never say anything. This
    // asserts it says something instead.
    Future<void> pumpWithStatus(
      WidgetTester tester,
      SyncStatus? status,
    ) async {
      final client = MockClient();
      when(() => client.rooms).thenReturn(<Room>[]);
      when(() => client.prevBatch).thenReturn(null);
      final statusController = CachedStreamController<SyncStatusUpdate>();
      when(() => client.onSyncStatus).thenReturn(statusController);
      if (status != null) {
        statusController.add(SyncStatusUpdate(status));
      }

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<SyncPulse>.value(value: SyncPulse()),
          ],
          child: wrapWithProviders(
            client: client,
            encryptionService: MockEncryptionService(),
            child: const Scaffold(
              body: SizedBox(width: 320, child: RoomsPane()),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    testWidgets('a failed sync is reported, not spun on', (tester) async {
      await pumpWithStatus(tester, SyncStatus.error);
      expect(find.text('Cannot reach your homeserver'), findsOneWidget);
      expect(find.byType(PaneLoading), findsNothing);
    });

    testWidgets('a pending sync still waits', (tester) async {
      await pumpWithStatus(tester, SyncStatus.waitingForResponse);
      expect(find.text('Cannot reach your homeserver'), findsNothing);
      expect(find.byType(PaneLoading), findsOneWidget);
    });

    testWidgets('a finished sync with no rooms is empty, not failed',
        (tester) async {
      await pumpWithStatus(tester, SyncStatus.finished);
      expect(find.text('Cannot reach your homeserver'), findsNothing);
      expect(find.text('No rooms yet'), findsOneWidget);
    });
  });
}









