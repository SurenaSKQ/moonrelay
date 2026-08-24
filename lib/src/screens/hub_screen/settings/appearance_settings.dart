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
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/theme_spec.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// -----------------------------------------------------------------------------
// Appearance Settings
// -----------------------------------------------------------------------------

class HubAppearanceSettings extends StatelessWidget {
  const HubAppearanceSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final theme = Theme.of(context);
        final t = MoonrelayThemeExtension.of(context).tokens;
        return SingleChildScrollView(
          padding: EdgeInsets.all(t.spaceXl),
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
              SizedBox(height: t.spaceXs),
              Text(
                l10n.controlLookAndFeel,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: t.spaceXl),

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
              SizedBox(height: t.spaceLg),

              // Theme (look and feel)
              HubSettingsSection(
                title: l10n.lookAndFeel,
                subtitle: l10n.lookAndFeelDesc,
                children: [
                  RadioGroup<String>(
                    groupValue: controller.selectedThemeId,
                    onChanged: (v) {
                      if (v != null) controller.updateSelectedTheme(v);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final look in MoonrelayThemes.all)
                          RadioListTile<String>(
                            value: look.id,
                            dense: true,
                            selected: look.id == controller.selectedThemeId,
                            title: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: controller.selectedAccent.seedColor,
                                    borderRadius: BorderRadius.circular(
                                      look.cornerRadius == 0
                                          ? 4
                                          : look.cornerRadius,
                                    ),
                                  ),
                                ),
                                SizedBox(width: t.spaceMd),
                                Text(look.label),
                              ],
                            ),
                            subtitle: Text(
                              look.description,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

              // Accent colour
              HubSettingsSection(
                title: l10n.accentColor,
                subtitle: l10n.accentColorDesc,
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
                            value: accent.id,
                            dense: true,
                            selected: accent.id == controller.selectedAccentId,
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
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

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
              SizedBox(height: t.spaceLg),

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
              SizedBox(height: t.spaceLg),

              // Animations toggle
              HubSettingsSection(
                title: l10n.accessibilityAnimations,
                children: [
                  SwitchListTile(
                    title: Text(l10n.enableAnimations),
                    subtitle: Text(l10n.enableAnimationsDescription),
                    value: controller.enableAnimations,
                    onChanged: (v) => controller.updateEnableAnimations(v),
                    secondary: const Icon(Icons.movie_filter_outlined),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Density
              HubSettingsSection(
                title: l10n.layoutDensity,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.spaceLg,
                      vertical: t.spaceSm,
                    ),
                    child: Wrap(
                      spacing: 8,
                      children: [
                        for (final d in LayoutDensity.values)
                          ChoiceChip(
                            label: Text(localizedLayoutDensity(d, l10n)),
                            selected: d == controller.density,
                            onSelected: (_) => controller.updateDensity(d),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

              // Bubble radius
              HubSettingsSection(
                title: l10n.bubbleRadius,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.square),
                    title: Text(l10n.bubbleRadius),
                    subtitle: Text('${controller.bubbleRadius.round()} px'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.bubbleRadius,
                        min: 0,
                        max: 24,
                        divisions: 24,
                        label: '${controller.bubbleRadius.round()} px',
                        onChanged: (v) => controller.updateBubbleRadius(v),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

              // Window
              HubSettingsSection(
                title: l10n.window,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.appWindow),
                    title: Text(l10n.windowMinWidth),
                    subtitle: Text('${controller.windowMinWidth.round()}'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.windowMinWidth,
                        min: 320,
                        max: 2000,
                        divisions: 168,
                        label: '${controller.windowMinWidth.round()}',
                        onChanged: (v) => controller.updateWindowMinWidth(v),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.appWindow),
                    title: Text(l10n.windowMinHeight),
                    subtitle: Text('${controller.windowMinHeight.round()}'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.windowMinHeight,
                        min: 400,
                        max: 2000,
                        divisions: 160,
                        label: '${controller.windowMinHeight.round()}',
                        onChanged: (v) => controller.updateWindowMinHeight(v),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

              // Fonts
              HubSettingsSection(
                title: l10n.fonts,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.type),
                    title: Text(l10n.fontFamily),
                    subtitle: Text(controller.fontFamily),
                    onTap: () => _editTextField(
                      context,
                      controller,
                      l10n.fontFamily,
                      controller.fontFamily,
                      controller.updateFontFamily,
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.code),
                    title: Text(l10n.monoFontFamily),
                    subtitle: Text(controller.monoFontFamily),
                    onTap: () => _editTextField(
                      context,
                      controller,
                      l10n.monoFontFamily,
                      controller.monoFontFamily,
                      controller.updateMonoFontFamily,
                    ),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),

              // Language
              HubSettingsSection(
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
          ),
        );
      },
    );
  }

  Future<void> _editTextField(
    BuildContext context,
    SettingsController controller,
    String label,
    String initial,
    Future<void> Function(String) onSave,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final c = TextEditingController(text: initial);
        return AlertDialog(
          title: Text(label),
          content: TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(ctx)!.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(c.text.trim()),
              child: Text(AppLocalizations.of(ctx)!.save),
            ),
          ],
        );
      },
    );
    if (result != null && result.isNotEmpty) {
      await onSave(result);
    }
  }
}
