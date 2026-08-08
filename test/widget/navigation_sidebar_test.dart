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
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/utils/cached_stream_controller.dart'
    show CachedStreamController;
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/layouts/dashboard_layout/dashboard_view.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:moonrelay/src/settings/space_preferences.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar.dart';
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

/// Wraps [child] with the providers the navigation sidebar needs: a mock
/// [Client], [NavigationState], [SpacePreferences] and [SyncPulse].
Widget _wrapSidebar(Widget child, {SettingsController? settings}) {
  return MultiProvider(
    providers: [
      Provider<Client>.value(value: _clientWithNoRooms()),
      ChangeNotifierProvider<NavigationState>.value(
        value: NavigationState(),
      ),
      ChangeNotifierProvider<SpacePreferences>.value(
        value: SpacePreferences(SettingsService()),
      ),
      ChangeNotifierProvider<SyncPulse>.value(value: SyncPulse()),
      if (settings != null)
        ChangeNotifierProvider<SettingsController>.value(value: settings),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
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
