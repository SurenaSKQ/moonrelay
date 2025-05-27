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

import 'package:azhi_main/src/layouts/azhi_custom_scaffold.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:linkify_text/linkify_text.dart';

class RegisterNewUserAccountGuidancePage extends StatelessWidget {
  const RegisterNewUserAccountGuidancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return AzhiCustomScaffold(
      topBar: IconButton(
        icon: const Icon(
          FluentIcons.back,
          color: Colors.white,
        ),
        onPressed: () => context.pop(),
      ),
      content: Column(
        children: [
          const Text(
            "Choose a Homeserver.",
            style: TextStyle(
              color: Colors.white,
              fontFamily: 'Rubic',
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
          const Text(
            "What is a homeserver?",
            style: TextStyle(
              fontFamily: 'Rubik',
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          const Text(
            "A homserver is your gateway into the Matrix network. It is a place where you create an account on, and then you use that account to login to the network.\nIn order to create an account, you need to go into a homeserver's website, and create an account there.\nFor your convenience, a brief list of popular homeservers is presented below\nWe will add the option to register inside the client in later versions.",
            style: TextStyle(
              fontFamily: 'Rubik',
              color: Colors.white,
              fontSize: 16,
            ),
          ),
          LinkifyText(
            "Matrix Organization's own homeserver: app.element.io \nENVS organization homeserver: element.envs.net/ \nYou can find other options with this helpful website: servers.joinmatrix.org/",
            linkColor: const Color.fromARGB(255, 50, 205, 50),
          ),
        ],
      ),
    );
  }
}
