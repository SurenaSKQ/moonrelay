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

import 'package:azhi_main/src/widgets/logo_with_text_themed.dart';
import 'package:blurrycontainer/blurrycontainer.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';

class RegisterInClientPage extends StatefulWidget {
  const RegisterInClientPage({super.key});

  @override
  State<RegisterInClientPage> createState() => _RegisterInClientPageState();
}

class _RegisterInClientPageState extends State<RegisterInClientPage> {
  Future<void> registerUser(String username, String password, String homserver,
      Client client, Logger log) async {
    try {
      //TODO: Better registeration
      Uri homeserverUri = Uri.parse(homserver);
      client.checkHomeserver(homeserverUri);
      final response = await client.register(
        username: username,
        password: password,
      );
      log.i("User registeration successful");
    } catch (e) {
      log.f(
        "Registration failed",
        error: e,
        stackTrace: StackTrace.current,
        time: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextEditingController _usernameController = TextEditingController();
    final TextEditingController _passwordController = TextEditingController();
    final TextEditingController _homeserverController = TextEditingController();

    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
            image: AssetImage('assets/images/abstract_bg.jpg'),
            fit: BoxFit.cover),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Flexible(
            flex: 4,
            child: LogoWithTextThemed(
              themeModeOverride: Brightness.dark,
            ),
          ),
          Flexible(
            flex: 6,
            child: BlurryContainer.expand(
              child: ScaffoldPage(
                header: IconButton(
                  icon: const Icon(
                    FluentIcons.back,
                    color: Colors.white,
                  ),
                  onPressed: () => context.pop(),
                ),
                content: Column(
                  children: [
                    TextBox(
                      controller: _homeserverController,
                    ),
                    TextBox(
                      controller: _usernameController,
                    ),
                    TextBox(
                      controller: _passwordController,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
