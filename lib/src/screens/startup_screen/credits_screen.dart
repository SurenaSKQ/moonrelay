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

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/helpers/app_version.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/auth_surface.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:moonrelay/src/widgets/moonrelay_mark.dart';
import 'package:url_launcher/url_launcher.dart';

/// Where the source lives, and the one link on this page.
const String _repositoryUrl = 'https://codeberg.org/SurenaSKQ/moonrelay/';

/// Who made it, the licence, what it is built on, and where the code is.
///
/// The whole page was hardcoded English except the app name, the author's name
/// and one licence notice, including its own title. A Persian user opening
/// Credits from the welcome footer got an English screen.
///
/// It also reported `Version 0.2.0+1`, written into a `Text` when pubspec was at
/// `0.6.0`, and there is an `AppVersion` helper whose entire reason to exist is
/// to be the one place a version string comes from. A credits page that
/// understates which build you are running is worse than no credits page,
/// because it is where a person goes to find out.
class CreditsScreen extends StatelessWidget {
  const CreditsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;

    return MoonrelayInfoPage(
      title: l10n.credits,
      children: <Widget>[
        // The identity block. A mark at the size the app shows it everywhere else
        // rather than a moon glyph from the icon set, which is what the splash
        // used before it grew the real one and this page never followed.
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              MoonrelayMark(size: 56, color: scheme.primary),
              SizedBox(height: t.spaceMd),
              Text(
                l10n.projectName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily:
                      Theme.of(context).textTheme.titleMedium?.fontFamily,
                  fontSize: 22,
                  height: 1.2,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.4,
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: t.spaceXs),
              Text(
                l10n.creditsVersion(AppVersion.currentVersion),
                style: TextStyle(
                  // The version is an identifier, so it is set in the mono face
                  // and read as a fact rather than as prose.
                  fontFamily:
                      MoonrelayThemeExtension.of(context).monoFontFamily,
                  fontSize: 12,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const InfoSectionGap(first: true),
        InfoPanel(
          title: l10n.author,
          children: <Widget>[
            AuthBody(l10n.creditsAuthorBody),
            SizedBox(height: t.spaceSm),
            AuthBody(l10n.creditsAuthorContactBody),
          ],
        ),
        const InfoSectionGap(),
        InfoPanel(
          title: l10n.creditsLicenseTitle,
          children: <Widget>[
            AuthBody(l10n.creditsLicenseBody),
            SizedBox(height: t.spaceSm),
            AuthBody(l10n.appLicenseNotice),
          ],
        ),
        const InfoSectionGap(),
        InfoPanel(
          title: l10n.creditsOpenSourceTitle,
          children: <Widget>[
            AuthBody(l10n.creditsOpenSourceBody),
            SizedBox(height: t.spaceSm),
            AuthBody(l10n.creditsOpenSourceDerivedBody),
          ],
        ),
        const InfoSectionGap(),
        InfoPanel(
          title: l10n.creditsRepositoryTitle,
          children: <Widget>[
            AuthBody(l10n.creditsRepositoryBody),
            SizedBox(height: t.spaceSm),
            // The link is the page's one action, so it is a button rather than
            // a recogniser buried in a `Text.rich`. A recogniser cannot be
            // focused, cannot be tabbed to, and is not announced as a link.
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => launchUrl(
                  Uri.parse(_repositoryUrl),
                  mode: LaunchMode.externalApplication,
                ),
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: Text(
                  _repositoryUrl,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
