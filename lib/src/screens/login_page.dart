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

import 'package:moonrelay/src/layouts/custom_scaffold.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';
import 'package:window_manager/window_manager.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> with WindowListener {
  final TextEditingController _usernameBox = TextEditingController();
  final TextEditingController _passwordBox = TextEditingController();
  final TextEditingController _homeserverBox =
      TextEditingController(text: 'matrix.org');

  bool _textActive = true;

  void _login() async {
    if (context.mounted) {
      final client = Provider.of<Client>(context, listen: false);
      final log = Provider.of<Logger>(context, listen: false);
      setState(() => _textActive = false);
      try {
        await client.checkHomeserver(Uri.https(_homeserverBox.text.trim(), ''));
        await client.login(
          LoginType.mLoginPassword,
          password: _passwordBox.text,
          identifier: AuthenticationUserIdentifier(user: _usernameBox.text),
        );
        // ignore: use_build_context_synchronously
        context.go('/main/rooms');
      } catch (e) {
        log.e(
          "Login error",
          error: e,
        );
        // FIXME: Better error and localization
        // ignore: use_build_context_synchronously
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
    return CustomScaffold(
      topBar: IconButton(
        icon: const Icon(
          FluentIcons.back,
          color: Colors.white,
        ),
        onPressed: () => context.pop(),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                InfoLabel(
                  label: AppLocalizations.of(context)!.homeserverText,
                  labelStyle: const TextStyle(color: Colors.white),
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
                  labelStyle: const TextStyle(color: Colors.white),
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
                  labelStyle: const TextStyle(color: Colors.white),
                  child: PasswordBox(
                    controller: _passwordBox,
                  ),
                ),
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
          const SizedBox(
            height: 8.0,
          ),
        ],
      ),
    );
  }
}
