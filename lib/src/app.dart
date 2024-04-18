import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:matrix/matrix.dart';
import 'package:logger/logger.dart';
import 'helpers/theme_provider.dart';
import 'settings/settings_controller.dart';
import 'settings/settings_view.dart';
import 'screens/loginPage.dart';
import 'screens/chat_screen.dart';

/// The base starting widget of the application.
class AzhiStartApp extends StatelessWidget {
  const AzhiStartApp({
    super.key,
    required this.settingsController,
    required this.client,
    required this.log,
  });

  final SettingsController settingsController;
  final Client client;
  final Logger log;

  @override
  Widget build(BuildContext context) {
    // Glue the SettingsController to the MaterialApp.
    //
    // The ListenableBuilder Widget listens to the SettingsController for changes.
    // Whenever the user updates their settings, the MaterialApp is rebuilt.
    return ListenableBuilder(
      listenable: settingsController,
      builder: (BuildContext context, Widget? child) {
        return MaterialApp(
          // Providing a restorationScopeId allows the Navigator built by the
          // MaterialApp to restore the navigation stack when a user leaves and
          // returns to the app after it has been killed while running in the
          // background.
          restorationScopeId: 'AppRoot',

          // Provide the generated AppLocalizations to the MaterialApp. This
          // allows descendant Widgets to display the correct translations
          // depending on the user's locale.
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('en', ''), // English, no country code
            Locale('fa', 'IR'),
          ],

          // Use AppLocalizations to configure the correct application title
          // depending on the user's locale.
          //
          // The appTitle is defined in .arb files found in the localization
          // directory.
          onGenerateTitle: (BuildContext context) =>
              AppLocalizations.of(context)!.appTitle,

          // Define a light and dark color theme. Then, read the user's
          // preferred ThemeMode (light, dark, or system default) from the
          // SettingsController to display the correct theme.
          theme: AppThemeProvider().lightTheme(),
          darkTheme: AppThemeProvider().darkTheme(),
          themeMode: settingsController.themeMode,

          builder: (context, child) => Provider<Client>(
              create: (context) => client,
              child: Provider<Logger>(
                create: (context) => log,
                child: child,
              )),

          // Define a function to handle named routes in order to support
          // Flutter web url navigation and deep linking.
          onGenerateRoute: (RouteSettings routeSettings) {
            return MaterialPageRoute<void>(
              settings: routeSettings,
              builder: (BuildContext context) {
                switch (routeSettings.name) {
                  case SettingsView.routeName:
                    return SettingsView(controller: settingsController);
                  case LoginPage.routeName:
                    return const LoginPage();
                  case ChatScreen.routeName:
                    return const ChatScreen();
                  default:
                    return const LoginPage();
                }
              },
            );
          },
        );
      },
    );
  }
}
