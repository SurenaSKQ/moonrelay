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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/accents.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

class WelcomeSettingsScreen extends StatelessWidget {
  const WelcomeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.appSettings),
        leading: IconButton(
          icon: const Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Consumer<SettingsController>(
        builder: (context, controller, _) {
          return ListView(
            padding: EdgeInsets.all(t.spaceXl),
            children: [
              Text(
                l10n.appearance,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              SizedBox(height: t.spaceXs),
              Text(
                l10n.customizeExperience,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: t.spaceXl),

              // Theme mode
              WelcomeSettingsSection(
                title: l10n.themeMode,
                children: [
                  RadioGroup<ThemeMode>(
                    groupValue: controller.themeMode,
                    onChanged: (v) => controller.updateThemeMode(v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
              SizedBox(height: t.spaceLg),

              // Accent colour
              WelcomeSettingsSection(
                title: l10n.accentColor,
                children: [
                  RadioGroup<String>(
                    groupValue: controller.selectedAccentId,
                    onChanged: (v) {
                      if (v != null) controller.updateSelectedAccent(v);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final accent in MoonrelayAccents.all)
                          RadioListTile<String>(
                            title: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: accent.seedColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                SizedBox(width: t.spaceMd),
                                Text(accent.label),
                              ],
                            ),
                            value: accent.id,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

              // Language
              WelcomeSettingsSection(
                title: l10n.language,
                children: [
                  RadioGroup<String?>(
                    groupValue: controller.locale,
                    onChanged: (v) => controller.updateLocale(v),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
      ),
    );
  }
}

class WelcomeSettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const WelcomeSettingsSection({

    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        SizedBox(height: t.spaceSm),
        Card(
          elevation: t.elevationNone,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusMd),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
