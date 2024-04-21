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

import 'package:azhi_main/src/screens/fluent_chat_main.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:matrix/matrix.dart';
import 'package:logger/logger.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';
import 'screens/fluent_login_page.dart';
import 'settings/theme.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart' as flutter_acrylic;

final _appTheme = AppTheme();

class ChatSpacesApp extends StatelessWidget {
  const ChatSpacesApp(
      {super.key,
      required this.settingsController,
      required this.client,
      required this.log});
  final SettingsController settingsController;
  final Client client;
  final Logger log;
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return FluentApp(
          restorationScopeId: "approot",
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate
          ],
          // TODO: Support persian
          supportedLocales: const [
            Locale('en', ''),
          ],
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
          builder: (context, child) => Provider(
            create: (context) => client,
            child: Provider(
              create: (context) => log,
              child: Provider(
                create: (context) => settingsController,
                child: Directionality(
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
              ),
            ),
          ),
          // TODO: new routing system!
          onGenerateRoute: (RouteSettings rtsettings) => FluentPageRoute(
            settings: rtsettings,
            builder: (BuildContext context) {
              switch (rtsettings.name) {
                case SettingsView.routeName:
                  return SettingsView(controller: settingsController);
                case FluentLoginPage.routeName:
                  return FluentLoginPage(
                    settingsController: settingsController,
                  );
                case FluentChatMain.routeName:
                  return FluentChatMain(settingsController: settingsController);
                default:
                  return FluentLoginPage(
                    settingsController: settingsController,
                  );
              }
            },
          ),
        );
      },
    );
  }
}
