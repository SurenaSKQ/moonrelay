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

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/licenses.dart';
import 'package:moonrelay/src/screens/privacy_policy.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class StartupScreen extends StatelessWidget {
  const StartupScreen({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "The Public Benefit Messenger",
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Oxanium',
            fontWeight: FontWeight.bold,
            fontSize: 24,
            color: Colors.white,
          ),
          maxLines: 2,
          overflow: TextOverflow.fade,
        ),
        const SizedBox(
          height: 16.0,
        ),
        Wrap(
          children: [
            ElevatedButton(
              child: const Text(
                "Login",
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onPressed: () => context.push('/welcome/login'),
            ),
            const SizedBox(
              width: 24,
            ),
            ElevatedButton(
              child: const Text(
                "Sign Up!",
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              onPressed: () => context.push('/welcome/register'),
            )
          ],
        ),
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                AppLocalizations.of(context)!.appLicenseNotice,
                textAlign: TextAlign.justify,
                style: const TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 16,
                  color: Colors.white,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(
                height: 16.0,
              ),
              const Text(
                "The Moonrelay team cannot moderate or honour DMCA requests on content that is posted on the Matrix protocol network. Contact room administrators or homeserver owners.",
                textAlign: TextAlign.justify,
                style: TextStyle(
                  fontFamily: 'Rubik',
                  fontSize: 16,
                  color: Colors.white,
                ),
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(
                height: 8.0,
              ),
              Wrap(
                children: [
                  TextButton(
                    child: Text(AppLocalizations.of(context)!.privacyPolicy,
                        style: const TextStyle(fontFamily: 'Rubik')),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const PrivacyPolicyPopupScreen(),
                        barrierColor: Colors.black.withValues(alpha: 0.9),
                      );
                    },
                  ),
                  const SizedBox(
                    width: 32,
                  ),
                  TextButton(
                    child: Text(
                      AppLocalizations.of(context)!.thirdPartyLicense,
                      style: const TextStyle(fontFamily: 'Rubik'),
                    ),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => const LicensesScreen(),
                        barrierColor: Colors.black.withValues(alpha: 0.9),
                      );
                    },
                  )
                ],
              ),
            ],
          ),
        )
      ],
    );
  }
}
