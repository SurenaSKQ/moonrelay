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

import 'package:logger/logger.dart';
import 'package:azhi_main/src/screens/chat_screen.dart';
import 'package:azhi_main/src/settings/settings_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:azhi_main/src/widgets/themedLogoAndText.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  static const routeName = "/loginScreen";
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameBox = TextEditingController();
  final TextEditingController _passwordBox = TextEditingController();
  final TextEditingController _homeserverBox =
      TextEditingController(text: 'matrix.org');

  bool _textActive = true;
  void _login() async {
    setState(() => _textActive = false);
    final client = Provider.of<Client>(context, listen: false);
    final log = Provider.of<Logger>(context, listen: false);
    try {
      if (client.isLogged()) {
        Navigator.pushNamed(context, ChatScreen.routeName);
      }
      await client.checkHomeserver(Uri.https(_homeserverBox.text.trim(), ''));
      await client.login(
        LoginType.mLoginPassword,
        password: _passwordBox.text,
        identifier: AuthenticationUserIdentifier(user: _usernameBox.text),
      );
      if (mounted) {
        Navigator.pushNamed(context, ChatScreen.routeName);
      } else {
        throw 'Widget not mounted in async context (internal error)';
      }
    } catch (e) {
      log.e(
        "Login error",
        error: e,
      );
      // FIXME: Better error and localization
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
        ),
      );
    }
    setState(() => _textActive = true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () =>
              Navigator.restorablePushNamed(context, SettingsView.routeName),
          icon: const Icon(Icons.settings),
        ),
        title: Text(AppLocalizations.of(context)!.appTitle),
      ),
      backgroundColor: Theme.of(context).colorScheme.background,
      primary: true,
      drawer: Drawer(
        child: Column(
          children: [
            TextButton(
              onPressed: () {},
              child: Text(AppLocalizations.of(context)!.thirdPartyLicense),
            ),
            TextButton(
              onPressed: () {},
              child: Text(AppLocalizations.of(context)!.privacyPolicy),
            )
          ],
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            direction: Axis.horizontal,
            children: [
              const LogoWithTextThemed(),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8.0),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (Theme.of(context).brightness == Brightness.dark)
                        ? Colors.white10
                        : Colors.white70,
                    boxShadow: [
                      BoxShadow(
                        color: (Theme.of(context).brightness == Brightness.dark)
                            ? Colors.white
                            : Colors.black,
                        spreadRadius: 0,
                        blurRadius: 16,
                        blurStyle: BlurStyle.outer,
                      )
                    ],
                    border: Border.all(
                      color: (Theme.of(context).brightness == Brightness.dark)
                          ? Colors.white
                          : Colors.black,
                      width: 5,
                      style: BorderStyle.solid,
                    ),
                    shape: BoxShape.rectangle,
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(4),
                        child: TextField(
                          controller: _homeserverBox,
                          readOnly: !_textActive,
                          enabled: true,
                          autocorrect: false,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText:
                                AppLocalizations.of(context)!.homeserverText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: TextField(
                          controller: _usernameBox,
                          readOnly: !_textActive,
                          enabled: true,
                          autocorrect: false,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText:
                                AppLocalizations.of(context)!.usernameText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.all(4.0),
                        child: TextField(
                          controller: _passwordBox,
                          readOnly: !_textActive,
                          enabled: true,
                          autocorrect: false,
                          obscureText: true,
                          decoration: InputDecoration(
                            border: const OutlineInputBorder(),
                            labelText:
                                AppLocalizations.of(context)!.passwordText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        constraints: BoxConstraints.loose(
                          const Size.fromWidth(80),
                        ),
                        child: ElevatedButton(
                          onPressed: !_textActive ? null : _login,
                          child: Center(
                            child: !_textActive
                                ? const SpinKitChasingDots(
                                    color: Colors.white,
                                  )
                                : Text(
                                    AppLocalizations.of(context)!.loginButton),
                          ),
                        ),
                      ),
                      Container(
                        child: Text(
                            AppLocalizations.of(context)!.appLicenseNotice),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
