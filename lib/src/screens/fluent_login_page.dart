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

import 'package:azhi_main/src/screens/licenses.dart';
import 'package:azhi_main/src/settings/settings_controller.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:azhi_main/src/widgets/logo_with_text_themed.dart';

class FluentLoginPage extends StatefulWidget {
  const FluentLoginPage({super.key, required this.settingsController});
  static const routeName = "/login";
  final SettingsController settingsController;

  @override
  State<FluentLoginPage> createState() => _FluentLoginPageState();
}

class _FluentLoginPageState extends State<FluentLoginPage> with WindowListener {
  final TextEditingController _usernameBox = TextEditingController();
  final TextEditingController _passwordBox = TextEditingController();
  final TextEditingController _homeserverBox =
      TextEditingController(text: 'matrix.org');

  bool _textActive = true;
  bool _hidePassword = true;
  void _login() async {
    final client = Provider.of<Client>(context, listen: false);
    final log = Provider.of<Logger>(context, listen: false);
    setState(() => _textActive = false);
    if (client.isLogged()) {
      context.go("/chat");
    }
    try {
      await client.checkHomeserver(Uri.https(_homeserverBox.text.trim(), ''));
      await client.login(
        LoginType.mLoginPassword,
        password: _passwordBox.text,
        identifier: AuthenticationUserIdentifier(user: _usernameBox.text),
      );
      if (mounted) {
        context.go("/chat");
      } else {
        throw 'Widget not mounted in async context (internal error)';
      }
    } catch (e) {
      log.e(
        "Login error",
        error: e,
      );
      // FIXME: Better error and localization
      await displayInfoBar(context, builder: (context, close) {
        return InfoBar(
          title: Text(AppLocalizations.of(context)!.error),
          content: Text(e.toString()),
          action: IconButton(
            icon: const Icon(FluentIcons.clear),
            onPressed: close,
          ),
          severity: InfoBarSeverity.error,
        );
      });
    }
    setState(() => _textActive = true);
  }

  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _homeserverBox.dispose();
    _usernameBox.dispose();
    _passwordBox.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      content: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            direction: Axis.horizontal,
            alignment: WrapAlignment.spaceAround,
            children: [
              const LogoWithTextThemed(),
              Container(
                decoration: BoxDecoration(
                  border: Border.fromBorderSide(
                    BorderSide(
                      style: BorderStyle.solid,
                      width: 5,
                      color: FluentTheme.of(context).accentColor,
                      strokeAlign: BorderSide.strokeAlignInside,
                    ),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          InfoLabel(
                            label: AppLocalizations.of(context)!.homeserverText,
                            child: TextBox(
                              controller: _homeserverBox,
                              expands: false,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          InfoLabel(
                            label: AppLocalizations.of(context)!.usernameText,
                            child: TextBox(
                              controller: _usernameBox,
                              expands: false,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          InfoLabel(
                            label: AppLocalizations.of(context)!.passwordText,
                            child: TextBox(
                              controller: _passwordBox,
                              expands: false,
                              obscureText: _hidePassword,
                            ),
                          ),
                          const SizedBox(
                            height: 8,
                          ),
                          ToggleButton(
                            checked: !_hidePassword,
                            onChanged: (_) => setState(
                              () {
                                _hidePassword = !_hidePassword;
                              },
                            ),
                            child: const Icon(FluentIcons.password_field),
                          )
                        ],
                      ),
                    ),
                    Center(
                      child: FilledButton(
                        onPressed: !_textActive ? null : _login,
                        child: !_textActive
                            ? const ProgressBar()
                            : Text(AppLocalizations.of(context)!.loginButton),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          border: Border.fromBorderSide(
                            BorderSide(
                              color: FluentTheme.of(context).cardColor,
                              width: 4,
                            ),
                          ),
                          color: FluentTheme.of(context).accentColor,
                          backgroundBlendMode: BlendMode.color,
                        ),
                        child: Column(
                          children: [
                            Text(
                              AppLocalizations.of(context)!.appLicenseNotice,
                              style: const TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(
                              height: 8,
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Button(
                                  child: Text(AppLocalizations.of(context)!
                                      .privacyPolicy),
                                  onPressed: () {},
                                ),
                                Button(
                                  child: Text(AppLocalizations.of(context)!
                                      .thirdPartyLicense),
                                  onPressed: () {
                                    showDialog(
                                      context: context,
                                      builder: (context) =>
                                          const LicensesScreen(),
                                      barrierColor: Colors.black,
                                    );
                                  },
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void onWindowClose() async {
    windowManager.destroy();
  }
}
