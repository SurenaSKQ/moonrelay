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
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart'
    show CachedStreamController;
import 'package:matrix/src/utils/space_child.dart'
    show SpaceChild, SpaceParent;
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/layouts/dashboard_layout/dashboard_view.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/sidebar_actions.dart';
import 'package:moonrelay/src/widgets/sidebar_profile_pill.dart';
import 'package:provider/provider.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// A mock [Client] whose room list is empty by default (the real mock
/// returns null for every member, which breaks the sidebar's room scans).
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
    testWidgets('renders profile pill, command palette, and nav rows',
        (tester) async {
      await tester.pumpWidget(_wrapSidebar(const NavigationSidebar()));
      await tester.pump();

      expect(find.byType(SidebarProfilePill), findsOneWidget);
      expect(find.byType(SidebarCommandPaletteButton), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Add Room'), findsOneWidget);
      expect(find.text('Rooms'), findsOneWidget);
      // No spaces in the mock client, so the spaces section is skipped.
      expect(find.text('Spaces'), findsNothing);
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

  group('DashboardView sidebar collapse', () {
    Widget dashboardView(SettingsController settings) {
      return DashboardView(
        shouldUseCompact: false,
        width: 1400,
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
    Widget wrapDashboard(SettingsController settings, Widget child) {
      final client = _clientWithNoRooms();
      when(() => client.onSyncStatus)
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
          client: client,
          encryptionService: enc,
          settingsController: settings,
          child: child,
        ),
      );
    }

    testWidgets('expanded shell shows the navigation sidebar and a '
        'collapse gutter', (tester) async {
      final settings = createTestSettingsController();
      await tester.pumpWidget(
        wrapDashboard(settings, dashboardView(settings)),
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
        wrapDashboard(settings, dashboardView(settings)),
      );
      await tester.pump();

      await settings.toggleLeftSidebar();
      await tester.pump();

      expect(find.byType(NavigationSidebar), findsNothing);
      expect(find.byType(SidebarCollapseGutter), findsNothing);
      expect(find.byType(SidebarExpandGutter), findsOneWidget);
    });
  });
}
