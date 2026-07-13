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
  const MoonrelayApp({super.key});

  static final GoRouter moonrouter = GoRouter(routes: MoonRouter.routes);

  @override
  State<MoonrelayApp> createState() => _MoonrelayAppState();
}

class _MoonrelayAppState extends State<MoonrelayApp> {
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
        Widget app = ListenableBuilder(
          listenable: settingsController,
          builder: (BuildContext context, Widget? child) {
            return MaterialApp.router(
              routerConfig: MoonrelayApp.moonrouter,
              debugShowCheckedModeBanner: false,
              restorationScopeId: "approot",
              localizationsDelegates:
                  AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              onGenerateTitle: (context) =>
                  AppLocalizations.of(context)!.appTitle,
              theme: MoonrelayTheme.light(settingsController.themeOption),
              darkTheme: MoonrelayTheme.dark(settingsController.themeOption),
              themeMode: settingsController.themeMode,
              builder: (context, child) => Directionality(
                textDirection: _appTheme.textDirection,
                child: child!,
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

        if (client != null) {
          _bindPulse(client);
          app = Provider<Client>.value(value: client, child: app);
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
        }
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
