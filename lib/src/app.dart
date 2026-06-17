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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'settings/settings_controller.dart';
import 'settings/theme.dart';
import 'encryption/encryption_service.dart';

final _appTheme = MoonrelayAppTheme();

class MoonrelayApp extends StatelessWidget {
  const MoonrelayApp({super.key});

  static final GoRouter moonrouter = GoRouter(routes: MoonRouter.routes);

  @override
  Widget build(BuildContext context) {
    final AccountManager accountManager = context.watch<AccountManager>();
    final SettingsController settingsController =
        context.watch<SettingsController>();

    // The core MaterialApp.router wrapped in its settings listener.
    Widget app = ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp.router(
          routerConfig: moonrouter,
          debugShowCheckedModeBanner: false,
          restorationScopeId: "approot",
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // TODO: Support persian
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
    // propagates without a full app restart.
    final client = accountManager.client;
    final enc = accountManager.encryptionService;

    if (client != null) {
      app = Provider<Client>.value(value: client, child: app);
    }
    if (enc != null) {
      app = ChangeNotifierProvider<EncryptionService>.value(value: enc, child: app);
    }

    return app;
  }
}
