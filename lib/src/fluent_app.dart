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

import 'package:azhi_main/src/layouts/empty_space.dart';
import 'package:azhi_main/src/layouts/fluent_main_page.dart';
import 'package:azhi_main/src/screens/fluent_chat_main.dart';
import 'package:azhi_main/src/screens/fluent_home_screen.dart';
import 'package:azhi_main/src/screens/fluent_room_page.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
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
        return FluentApp.router(
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
          builder: (context, child) => MultiProvider(
            providers: [
              Provider(
                create: (context) => client,
              ),
              Provider(
                create: (context) => log,
              ),
              Provider(
                create: (context) => settingsController,
              )
            ],
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
          routeInformationParser: router.routeInformationParser,
          routerDelegate: router.routerDelegate,
          routeInformationProvider: router.routeInformationProvider,
        );
      },
    );
  }
}

final rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();
final router = GoRouter(
  navigatorKey: rootNavigatorKey,
  routes: [
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) {
        SettingsController settingsController =
            context.watch<SettingsController>();
        return FluentMainFrame(
          settingsController: settingsController,
          shellContext: context,
          child: child,
        );
      },
      routes: [
        GoRoute(
          path: "/",
          builder: (context, state) {
            return FluentHomePage();
          },
        ),
        GoRoute(
          path: "/settings",
          builder: (context, state) {
            SettingsController settingsController =
                context.watch<SettingsController>();
            return SettingsView(controller: settingsController);
          },
        ),
        GoRoute(
          path: "/login",
          builder: (context, state) {
            SettingsController stcontrol = state.extra as SettingsController;
            return FluentLoginPage(
              settingsController: stcontrol,
            );
          },
        ),
        GoRoute(
          path: "/chat",
          builder: (context, state) {
            return FluentChatMain();
          },
          routes: [
            GoRoute(
              path: "uncategorized",
              builder: (context, state) {
                return ChatsUncategorized();
              },
            ),
            GoRoute(
              path: "empty",
              builder: (context, state) => const EmptySpace(),
            ),
            GoRoute(
              path: "rooms",
              builder: (context, state) {
                Room room = state.extra as Room;
                return FluentRoomPage(room: room);
              },
            )
          ],
        ),
      ],
    )
  ],
);
