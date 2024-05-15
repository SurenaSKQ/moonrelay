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

import 'package:azhi_main/src/settings/settings_controller.dart';
import 'package:azhi_main/src/widgets/logo_with_text_themed.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

class FluentHomePage extends StatelessWidget {
  const FluentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    SettingsController settingsController =
        Provider.of<SettingsController>(context);
    return ScaffoldPage(
      content: Center(
        child: Column(
          children: [
            const LogoWithTextThemed(),
            const SizedBox(
              height: 8,
            ),
            const Text("The Public Benefit Messaging System, Built on Matrix"),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Button(
                      child: const Text("Login"),
                      onPressed: () =>
                          context.go("/login", extra: settingsController)),
                  Button(child: const Text("Sign Up!"), onPressed: () {})
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}
