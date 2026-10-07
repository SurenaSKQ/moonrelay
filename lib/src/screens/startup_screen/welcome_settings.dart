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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/accents.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:provider/provider.dart';

/// Appearance settings, reachable before sign-in.
///
/// The same three choices the hub's appearance page offers, on the same
/// primitives. It used to carry a private copy of the hub's settings section,
/// with the accent in the heading, which is the single loudest thing the hub
/// pass removed: thirteen pages each drawing their own card was thirteen chances
/// to drift, and this was a fourteenth one that then drifted away from the
/// thirteen.
///
/// So there is no section widget here. [HubSettingsSection] has no provider
/// dependency, it is purely presentational, and using it is what makes the
/// pre-login and in-app settings read as one settings page rather than as two
/// implementations of one.
class WelcomeSettingsScreen extends StatelessWidget {
  const WelcomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Consumer<SettingsController>(
      builder: (BuildContext context, SettingsController controller, _) {
        return MoonrelayInfoPage(
          title: l10n.appSettings,
          children: <Widget>[
            // The heading and its subtitle, at the same size and colour as any
            // other page's. It was a 22pt bold literal for a heading that
            // `IdentityHeader` gives 22 at w600 in the display face.
            AuthPageHeading(
                title: l10n.appearance, subtitle: l10n.customizeExperience),
            InfoSectionGap(first: true),
            HubSettingsSection(
              title: l10n.themeMode,
              children: <Widget>[
                RadioGroup<ThemeMode>(
                  groupValue: controller.themeMode,
                  onChanged: (ThemeMode? v) => controller.updateThemeMode(v!),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      RadioListTile<ThemeMode>(
                        title: Text(l10n.system),
                        value: ThemeMode.system,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text(l10n.light),
                        value: ThemeMode.light,
                      ),
                      RadioListTile<ThemeMode>(
                        title: Text(l10n.dark),
                        value: ThemeMode.dark,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            InfoSectionGap(),
            HubSettingsSection(
              title: l10n.accentColor,
              children: <Widget>[
                RadioGroup<String>(
                  groupValue: controller.selectedAccentId,
                  onChanged: (String? v) {
                    if (v != null) controller.updateSelectedAccent(v);
                  },
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      for (final MoonrelayAccent accent in MoonrelayAccents.all)
                        RadioListTile<String>(
                          // Dense, because nine of them is a list to scan rather
                          // than nine things to press one at a time.
                          dense: true,
                          value: accent.id,
                          title: Row(
                            children: <Widget>[
                              _AccentSwatch(colour: accent.seedColor),
                              SizedBox(width: t.spaceMd),
                              Text(localizedAccent(accent, l10n)),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            InfoSectionGap(),
            HubSettingsSection(
              title: l10n.language,
              children: <Widget>[
                RadioGroup<String?>(
                  groupValue: controller.locale,
                  onChanged: (String? v) => controller.updateLocale(v),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      RadioListTile<String?>(
                        title: Text(l10n.languageSystem),
                        value: null,
                      ),
                      RadioListTile<String?>(
                        title: Text(l10n.languageEnglish),
                        value: 'en',
                      ),
                      RadioListTile<String?>(
                        title: Text(l10n.languagePersian),
                        value: 'fa',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// The accent swatch beside each colour's name.
///
/// `iconSizeMedium` rather than the 20 it was, so it is the app's icon size and
/// not a number that happens to match it. A ring around it, because the swatch
/// is the only thing identifying the accent and a flat circle against a card
/// disappears entirely in one of the nine.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({required this.colour});

  final Color colour;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: t.iconSizeMedium,
      height: t.iconSizeMedium,
      decoration: BoxDecoration(
        color: colour,
        shape: BoxShape.circle,
        border: Border.all(
          color: scheme.onSurface.withValues(alpha: t.opacityFocusRing),
        ),
      ),
    );
  }
}

/// A page's own heading, above its first section.
///
/// Small enough to be a function rather than a class, and the same treatment
/// `IdentityHeader` gives a page's name: display face, w600, `onSurface`.
class AuthPageHeading extends StatelessWidget {
  const AuthPageHeading({super.key, required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final display = Theme.of(context).textTheme.titleMedium?.fontFamily;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontFamily: display,
            fontSize: 22,
            height: 1.2,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.4,
            color: scheme.onSurface,
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(
                fontSize: 13, height: 1.4, color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
