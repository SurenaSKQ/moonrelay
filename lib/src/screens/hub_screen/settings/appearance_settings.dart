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
import 'package:provider/provider.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Appearance Settings
// ─────────────────────────────────────────────────────────────────────────────

class HubAppearanceSettings extends StatelessWidget {
  const HubAppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appearance,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.controlLookAndFeel,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Theme mode
              HubSettingsSection(
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
              const SizedBox(height: 16),

              // Colour theme
              HubSettingsSection(
                title: l10n.colourTheme,
                children: [
                  RadioGroup<MoonrelayThemeOption>(
                    groupValue: controller.themeOption,
                    onChanged: (v) {
                      if (v != null) controller.updateThemeOption(v);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final option in MoonrelayThemeOption.values)
                          RadioListTile<MoonrelayThemeOption>(
                            title: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: option.seedColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(localizedThemeOption(option, l10n)),
                              ],
                            ),
                            value: option,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chat display type
              HubSettingsSection(
                title: l10n.chatDisplayType,
                children: [
                  RadioGroup<DisplayType>(
                    groupValue: controller.displayType,
                    onChanged: (v) => controller.updateDisplayType(v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<DisplayType>(
                          title: Text(l10n.displayModern),
                          value: DisplayType.modern,
                        ),
                        RadioListTile<DisplayType>(
                          title: Text(l10n.displayIrc),
                          value: DisplayType.irc,
                        ),
                        RadioListTile<DisplayType>(
                          title: Text(l10n.displayBubbles),
                          value: DisplayType.bubbles,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Font size
              HubSettingsSection(
                title: 'Font size',
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.type),
                    title: const Text('Message font size'),
                    subtitle: Text('${controller.fontSize.round()} px'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.fontSize,
                        min: 10,
                        max: 28,
                        divisions: 18,
                        label: '${controller.fontSize.round()}',
                        onChanged: (v) => controller.updateFontSize(v),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // UI scale
              HubSettingsSection(
                title: 'UI scale',
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.zoomIn),
                    title: const Text('Interface scale'),
                    subtitle: Text('${controller.uiScale.toStringAsFixed(1)}×'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.uiScale,
                        min: 0.7,
                        max: 2.0,
                        divisions: 13,
                        label: '${controller.uiScale.toStringAsFixed(1)}×',
                        onChanged: (v) => controller.updateUiScale(v),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
