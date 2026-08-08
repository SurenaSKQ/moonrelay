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

import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/room_state_bus.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router.dart';
import 'package:moonrelay/src/widgets/deep_link_listener.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'settings/settings_controller.dart';
import 'settings/theme.dart';
import 'encryption/encryption_service.dart';

final _appTheme = MoonrelayAppTheme();

class MoonrelayApp extends StatefulWidget {
  const MoonrelayApp({super.key, this.navigatorKey});

  /// Optional navigator key handed to the router.  Lets code above the
  /// [MaterialApp.router] (e.g. the boot pipeline's startup update
  /// check) look up a context that lives inside the app so dialogs
  /// resolve [Localizations] and the [Navigator].
  final GlobalKey<NavigatorState>? navigatorKey;

  @override
  State<MoonrelayApp> createState() => _MoonrelayAppState();
}

class _MoonrelayAppState extends State<MoonrelayApp> {
  /// The app's router.  Created per [State] (not static) so that every
  /// app instance owns a fresh navigation stack; a static router would
  /// carry route state and the mounted pages (with their open database
  /// connections and live timelines) across test instances, which made
  /// the E2E suite leak pages and hit "readonly database" errors once
  /// the second test in a file booted.
  late final GoRouter _router = GoRouter(
    navigatorKey: widget.navigatorKey,
    routes: MoonRouter.routes,
  );
  /// Process-wide sync pulse, owned by this widget so its lifetime
  /// matches the running app. Re-bound to the active client every time
  /// the account manager swaps in a new [Client].
  final SyncPulse _syncPulse = SyncPulse();

  /// Per-room state-event fan-out. Owned by this widget for the same
  /// lifetime reason as [_syncPulse].
  final RoomStateBus _roomStateBus = RoomStateBus();

  Client? _boundClient;

  @override
  void dispose() {
    _router.dispose();
    _syncPulse.dispose();
    _roomStateBus.dispose();
    super.dispose();
  }

  void _bindPulse(Client client) {
    if (identical(_boundClient, client)) return;
    _boundClient = client;
    _syncPulse.bind(client);
    _roomStateBus.bind(client);
  }

  @override
  Widget build(BuildContext context) {
    final SettingsController settingsController =
        context.watch<SettingsController>();

    // The core MaterialApp.router wrapped in its settings listener.
    //
    // We also subscribe to [AccountManager] inside this builder so the
    // `Provider<Client>.value` and `ChangeNotifierProvider<EncryptionService>`
    // entries below pick up freshly-logged-in / switched clients on the
    // same frame as the [AccountManager.notifyListeners] broadcast.
    // Reading `accountManager.client` / `accountManager.encryptionService`
    // outside the builder would leave `Provider<Client>.value` caching the
    // previous client for one frame after a login, which manifested as
    // every `Client.userID` (display name, avatar, profile route, etc.)
    // briefly showing the prior account right after a fresh login.
    return Consumer<AccountManager>(
      builder: (context, accountManager, _) {
        // Derive text direction from the selected locale so RTL
        // languages (Persian) flip the entire app layout.
        _appTheme.updateFromLocale(settingsController.locale);

        Widget app = ListenableBuilder(
          listenable: settingsController,
          builder: (BuildContext context, Widget? child) {
            return MaterialApp.router(
              routerConfig: _router,
              debugShowCheckedModeBanner: false,
              restorationScopeId: "approot",
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: settingsController.locale != null
                  ? Locale(settingsController.locale!)
                  : null,
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)!.appTitle,
              theme: MoonrelayTheme.light(
                settingsController.themeOption,
                settingsController.density,
              ),
              darkTheme: MoonrelayTheme.dark(
                settingsController.themeOption,
                settingsController.density,
              ),
              themeMode: settingsController.themeMode,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  // The user-facing "Interface scale" slider
                  // (SettingsController.uiScale) only notified listeners but
                  // was never applied; route it through the root MediaQuery so
                  // every Text widget in the tree scales with it.
                  textScaler: TextScaler.linear(settingsController.uiScale),
                ),
                child: Directionality(
                  textDirection: _appTheme.textDirection,
                  child: child!,
                ),
              ),
            );
          },
        );

        // When an account is active, override the static Client and
        // EncryptionService providers so the entire widget tree reads
        // the live account's session.  This is how account switching
        // propagates without a full app restart.  Reads happen here
        // (inside the builder) rather than at the top of `build` so
        // a freshly-installed client after login is wired into the
        // provider tree on the same frame.
        final client = accountManager.client;
        final enc = accountManager.encryptionService;

        // SyncPulse and RoomStateBus are always provided — they are owned
        // by this widget and survive logout so that downstream widgets
        // (RoomsPane, NavigationPane, SpacesPane) can safely reference
        // them during the logout transition before the route changes.
        // Client and EncryptionService are only provided when active.
        if (client != null) {
          _bindPulse(client);
          app = Provider<Client>.value(value: client, child: app);
        }
        app = ChangeNotifierProvider<SyncPulse>.value(
          value: _syncPulse,
          child: app,
        );
        // RoomStateBus is a ChangeNotifier (subscribers listen to
        // per-room ValueNotifiers via the bus), so it must be
        // wrapped in a ChangeNotifierProvider; a plain Provider
        // would assert at runtime.
        app = ChangeNotifierProvider<RoomStateBus>.value(
          value: _roomStateBus,
          child: app,
        );
        if (enc != null) {
          app = ChangeNotifierProvider<EncryptionService>.value(
            value: enc,
            child: app,
          );
        }

        return DeepLinkListener(child: app);
      },
    );
  }
}
