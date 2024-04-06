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

import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

//FIXME - LOTS of internationalization problems
class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameBox = TextEditingController();
  final TextEditingController _passwordBox = TextEditingController();
  final TextEditingController _homeserverBox =
      TextEditingController(text: 'matrix.org');

  bool _textActive = true;

  void _login() async {
    setState(() => _textActive = false);
    final log = Provider.of<Logger>(context, listen: false);
    try {
      final client = Provider.of<Client>(context, listen: false);
      await client.checkHomeserver(Uri.https(_homeserverBox.text.trim(), ''));
      await client.login(
        LoginType.mLoginPassword,
        password: _passwordBox.text,
        identifier: AuthenticationUserIdentifier(user: _usernameBox.text),
      );
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const Placeholder()),
          (route) => false,
        );
      } else {
        throw 'Widget not mounted in async context (internal error)';
      }
    } catch (e) {
      log.e("Login error with",
          error: e, time: DateTime.now(), stackTrace: StackTrace.current);
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
    return SingleChildScrollView(
      // Insurance against items overflow
      child: Padding(
        padding: const EdgeInsets.all(10.0),
        child: Wrap(
          alignment: WrapAlignment.spaceEvenly,
          direction: Axis.horizontal,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: SvgPicture.asset(
                      'assets/images/azhi_logo.svg',
                      colorFilter: ColorFilter.mode(
                          (Theme.of(context).brightness == Brightness.dark)
                              ? Colors.white
                              : Colors.black,
                          BlendMode.srcIn),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    'Project Azhi',
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.dark)
                          ? Colors.white
                          : Colors.black,
                      fontSize: 32,
                    ),
                  ),
                ),
              ],
            ),
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
                    // TODO: I want a drop down menu with an optional text field
                    Padding(
                      padding: const EdgeInsets.all(4),
                      child: TextField(
                        controller: _homeserverBox,
                        autocorrect: false,
                        readOnly: !_textActive,
                        enabled: true,
                        decoration: const InputDecoration(
                          prefixText: 'https://',
                          border: OutlineInputBorder(),
                          labelText: 'Homeserver',
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
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: "Username",
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
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          labelText: 'Password',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      constraints: BoxConstraints.loose(
                        const Size.fromWidth(80),
                      ),
                      child: ElevatedButton(
                        // TODO: Deal
                        onPressed: !_textActive ? null : _login,
                        child: Center(
                          child: !_textActive
                              ? SpinKitChasingDots()
                              : const Text("Login"),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
