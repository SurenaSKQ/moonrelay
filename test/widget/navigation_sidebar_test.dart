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
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_widgets.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/navigation_sidebar.dart';
import 'package:moonrelay/src/widgets/room_list_filter.dart';
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
SettingsController _settingsAt(LayoutDensity density) {
  final settings = createTestSettingsController();
  settings.updateDensity(density);
  return settings;
}

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
    testWidgets('renders the account card, command palette, and the filter',
        (tester) async {
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();

      expect(find.byType(SidebarProfilePill), findsOneWidget);
      expect(find.byType(SidebarCommandPaletteButton), findsOneWidget);
      // The filter replaced two rows labelled "Home" and "All", which were
      // navigation words for what is a filter over one list.
      expect(find.byType(RoomListFilter), findsOneWidget);
      expect(find.text('Friends'), findsOneWidget);
      expect(find.text('All rooms'), findsOneWidget);
      expect(find.text('Home'), findsNothing);
      expect(find.text('Rooms'), findsOneWidget);
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
      final roomsHeader = tester.getCenter(find.text('Rooms'));
      final palette = tester.getCenter(find.byType(SidebarCommandPaletteButton));
      expect(pill.dy, greaterThan(roomsHeader.dy));
      expect(pill.dy, greaterThan(palette.dy));
    });

    testWidgets('add room is a control on the rooms header, not a nav row',
        (tester) async {
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();

      // It creates something that appears in the rooms section, so it
      // belongs on that section's header. As a third navigation row it cost
      // a full row of vertical space in a pane that has about five rows of
      // height to give.
      expect(find.byIcon(LucideIcons.plus), findsOneWidget);
      final plus = tester.getCenter(find.byIcon(LucideIcons.plus));
      final roomsHeader = tester.getCenter(find.text('Rooms'));
      expect(plus.dy, closeTo(roomsHeader.dy, 1.0));
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

    testWidgets('opening the command palette row pushes a palette route',
        (tester) async {
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();

      await tester.tap(find.byType(SidebarCommandPaletteButton));
      await tester.pump();
      await tester.pump();

      // The palette is a transparent overlay route; its search field
      // appears once the route is mounted.
      expect(find.byType(TextField), findsWidgets);
    });

    testWidgets('the section header labels react to density', (tester) async {
      // They were a hard-coded 12pt that ignored the setting, so the
      // wayfinding sat at a fixed size between rows that moved. A label
      // that does not change with the rows it heads is the clearest sign
      // that a pane was assembled rather than designed.
      Future<double> headerSizeAt(LayoutDensity density) async {
        await tester.pumpWidget(
          _wrapSidebar(
            const NavigationSidebar(),
            settings: _settingsAt(density),
          ),
        );
        await tester.pump();
        return tester.widget<Text>(find.text('Rooms')).style!.fontSize!;
      }

      final comfortable = await headerSizeAt(LayoutDensity.comfortable);
      final compact = await headerSizeAt(LayoutDensity.compact);

      expect(compact, lessThan(comfortable));
      // Sized from the same setting as the rows, one step below them.
      final metrics = SidebarRowMetrics.forDensity(LayoutDensity.comfortable);
      expect(comfortable, lessThan(metrics.titleSize));
      expect(comfortable, greaterThanOrEqualTo(metrics.titleSize - 2));
    });

    testWidgets('tapping the rooms header collapses the rooms section',
        (tester) async {
      final settings = createTestSettingsController();
      await tester.pumpWidget(
        _wrapSidebar(const NavigationSidebar(), settings: settings),
      );
      await tester.pump();

      // RoomsPane renders the loading spinner before the first sync.
      expect(find.byType(RoomsPane), findsOneWidget);

      await tester.tap(find.text('Rooms'));
      await tester.pump();
      await tester.pump();

      expect(find.byType(RoomsPane), findsNothing);
      expect(settings.collapsedSidebarSections, contains('rooms'));
      // The header itself stays visible.
      expect(find.text('Rooms'), findsOneWidget);
    });

    testWidgets('tapping the spaces header collapses the spaces section',
        (tester) async {
      final settings = createTestSettingsController();
      await tester.pumpWidget(_wrapSidebar(
        const NavigationSidebar(),
        client: _clientWithSpace(),
        settings: settings,
      ));
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Space'), findsOneWidget);

      await tester.tap(find.text('Spaces'));
      await tester.pump();
      await tester.pump();

      expect(find.text('Test Space'), findsNothing);
      expect(settings.collapsedSidebarSections, contains('spaces'));
    });

    testWidgets('a persisted collapsed section stays collapsed',
        (tester) async {
      final settings = createTestSettingsController();
      await settings.setSidebarSectionCollapsed('rooms', true);
      await tester.pumpWidget(
        _wrapSidebar(const NavigationSidebar(), settings: settings),
      );
      await tester.pump();

      expect(find.byType(RoomsPane), findsNothing);
      expect(find.text('Rooms'), findsOneWidget);
    });

    testWidgets('tapping a space highlights it and opens its home page',
        (tester) async {
      final nav = NavigationState();
      await tester.pumpWidget(_wrapSidebar(
        const NavigationSidebar(),
        client: _clientWithSpace(),
        navigationState: nav,
      ));
      await tester.pump();
      await tester.pump();

      await tester.tap(find.text('Test Space'));
      await tester.pump();
      await tester.pump();

      // A) the space is highlighted: the navigation state selects it.
      expect(nav.isSpace, isTrue);
      expect(nav.selectedId, '!space:matrix.org');
      // B) the space home page is shown.
      expect(find.text('SPACE_HOME'), findsOneWidget);
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

      // The very same widget, with its full structure: the profile pill,
      // the command palette, and both collapsible section headers.
      expect(find.byType(NavigationSidebar), findsOneWidget);
      expect(find.byType(SidebarProfilePill), findsOneWidget);
      expect(find.byType(SidebarCommandPaletteButton), findsOneWidget);
      expect(find.byType(NavSectionHeader), findsNWidgets(2));
      expect(find.text('Test Space'), findsOneWidget);
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