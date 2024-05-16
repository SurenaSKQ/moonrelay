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
import 'package:azhi_main/src/widgets/logo_with_text_themed.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class FluentHomePage extends StatelessWidget {
  const FluentHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    SettingsController settingsController =
        Provider.of<SettingsController>(context);
    return ScaffoldPage.scrollable(
      children: [
        Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const LogoWithTextThemed(),
              Flexible(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        "The Public Benefit Messaging System, Built on the Matrix Protocol",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.bold,
                          fontSize: 28,
                        ),
                      ),
                      const SizedBox(
                        height: 16.0,
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          FilledButton(
                            child: const Text(
                              "Login",
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            onPressed: () => context.push("/login",
                                extra: settingsController),
                          ),
                          Button(
                              child: const Text(
                                "Sign Up!",
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              onPressed: () {})
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        child: Card(
                          child: Column(
                            children: [
                              Text(
                                AppLocalizations.of(context)!.appLicenseNotice,
                                textAlign: TextAlign.justify,
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(
                                height: 16.0,
                              ),
                              const Text(
                                "The ChatSpaces team cannot and will not moderate or honour DMCA requests on content that is posted on the Matrix protocol network.",
                                textAlign: TextAlign.justify,
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(
                                height: 8.0,
                              ),
                              Wrap(
                                children: [
                                  Button(
                                    child: Text(AppLocalizations.of(context)!
                                        .privacyPolicy),
                                    onPressed: () {},
                                  ),
                                  const SizedBox(
                                    width: 8.0,
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
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
