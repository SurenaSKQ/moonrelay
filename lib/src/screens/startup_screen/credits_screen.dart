// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:url_launcher/url_launcher.dart';

class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Credits'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // -- Project identity card --------------------------------
          Card(
            child: Padding(
              padding: EdgeInsets.all(t.spaceXl),
              child: Column(
                children: [
                  Icon(
                    LucideIcons.moon,
                    size: 48,
                    color: colors.primary,
                  ),
                  SizedBox(height: t.spaceMd),
                  Text(
                    l10n.projectName,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: colors.onSurface,
                    ),
                  ),
                  SizedBox(height: t.spaceXs),
                  Text(
                    'Version 0.2.0+1',
                    style: TextStyle(
                      fontSize: 14,
                      color: colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(height: t.spaceLg),

          // -- Author -----------------------------------------------
          CreditsSection(
            icon: LucideIcons.user,
            title: l10n.author,
            children: [
              Text(
                'Surena Karimpour Ghannadi is the creator and primary '
                'maintainer of Moonrelay.',
              ),
              Text(
                'You can reach the project via Matrix or by opening an '
                'issue on the project repository.',
              ),
            ],
          ),
          SizedBox(height: t.spaceLg),

          // -- License ----------------------------------------------
          CreditsSection(
            icon: LucideIcons.scrollText,
            title: 'License',
            children: [
              Text(
                'Moonrelay is free software released under the GNU Affero '
                'General Public License version 3 or later.',
              ),
              Text(l10n.appLicenseNotice),
            ],
          ),
          SizedBox(height: t.spaceLg),

          // -- Open Source Credits ----------------------------------
          CreditsSection(
            icon: LucideIcons.code2,
            title: 'Open Source Acknowledgements',
            children: [
              Text(
                'Moonrelay builds on the Matrix Dart SDK and many other '
                'open-source packages. See the Third Party Licenses '
                'screen for the full list.',
              ),
              Text(
                'Portions of the date/time formatting and colour utilities '
                'are derived from FluffyChat, used under the terms of '
                'the AGPLv3.',
              ),
            ],
          ),
          SizedBox(height: t.spaceLg),

          // -- Repository -------------------------------------------
          CreditsSection(
            icon: LucideIcons.gitBranch,
            title: 'Repository',
            children: [
              Text(
                'The complete source code is available for inspection, '
                'audit, and contribution at the project repository:',
              ),
              Padding(
                padding: EdgeInsets.only(top: t.spaceSm),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: 'https://codeberg.org/SurenaSKQ/moonrelay/',
                        style: TextStyle(
                          color: theme.colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                        recognizer: TapGestureRecognizer()
                          ..onTap = () => launchUrl(
                                Uri.parse(
                                  'https://codeberg.org/SurenaSKQ/moonrelay/',
                                ),
                                mode: LaunchMode.externalApplication,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class CreditsSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final List<Widget> children;

  const CreditsSection({

    super.key,
    required this.icon,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 22, color: theme.colorScheme.primary),
                SizedBox(width: t.spaceMd),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            SizedBox(height: t.spaceMd),
            DefaultTextStyle(
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: children,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
