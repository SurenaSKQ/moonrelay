// Copyright (C) 2024 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <https://www.gnu.org/licenses/>.

import 'package:azhi_main/src/localization/app_localizations.dart';
import 'package:azhi_main/src/locations.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'settings/settings_controller.dart';
import 'settings/theme.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;

final _appTheme = AzhiAppTheme();

class ChatSpacesApp extends StatelessWidget {
  const ChatSpacesApp({super.key});

  static final GoRouter azhirouter =
      GoRouter(routes: AppLocationsHandler.routes);

  @override
  Widget build(BuildContext context) {
    final SettingsController settingsController =
        Provider.of<SettingsController>(context, listen: true);
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return FluentApp.router(
          routerConfig: azhirouter,
          debugShowCheckedModeBanner: false,
          restorationScopeId: "approot",
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          // TODO: Support persian
          supportedLocales: AppLocalizations.supportedLocales,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          // TODO: theme builder, user settings theme management
          theme: FluentThemeData(
            accentColor: _appTheme.color,
            visualDensity: VisualDensity.standard,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen(context) ? 2.0 : 0.0,
            ),
          ),
          darkTheme: FluentThemeData(
            brightness: Brightness.dark,
            accentColor: _appTheme.color,
            visualDensity: VisualDensity.standard,
            focusTheme: FocusThemeData(
              glowFactor: is10footScreen(context) ? 2.0 : 0.0,
            ),
          ),
          themeMode: settingsController.themeMode,
          builder: (context, child) => Directionality(
            textDirection: _appTheme.textDirection,
            child: NavigationPaneTheme(
              data: NavigationPaneThemeData(
                backgroundColor: _appTheme.windowEffect !=
                        flutter_acrylic.WindowEffect.disabled
                    ? Colors.transparent
                    : null,
              ),
              child: child!,
            ),
          ),
        );
      },
    );
  }
}
