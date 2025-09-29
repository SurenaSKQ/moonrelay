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

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/layouts/custom_scaffold.dart';
import 'package:flutter/material.dart';
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
    final TextEditingController usernameController = TextEditingController();
    final TextEditingController passwordController = TextEditingController();
    final TextEditingController homeserverController = TextEditingController();

    return CustomScaffold(
      topBar: IconButton(
        icon: const Icon(
          LucideIcons.arrowLeft,
          color: Colors.white,
        ),
        onPressed: () => context.pop(),
      ),
      content: Column(
        children: [
          TextField(
            controller: homeserverController,
          ),
          TextField(
            controller: usernameController,
          ),
          TextField(
            controller: passwordController,
          ),
        ],
      ),
    );
  }
}
