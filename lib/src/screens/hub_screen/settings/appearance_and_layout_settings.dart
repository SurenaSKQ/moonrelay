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

import 'package:moonrelay/src/chat/room_pane/room_pane_tab.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_controls.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/accents.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

// Appearance & Layout

/// How the app looks, and how its panels are arranged.
///
/// Appearance and Layout were separate pages, and it is worth saying why that
/// was wrong rather than only that it is merged. Both were lists of the same
/// kind of row, both were read by the same person in the same sitting, and the
/// only thing separating them was a judgement about which half of one concept
/// belonged to which: the accent colour was "appearance" while the density
/// that changes how large that accent looks was "layout", and the minimum
/// window width, which decides how many panes there are to look at, was
/// "layout" while the bubble radius, which decides how the same word looks,
/// was "appearance". Nobody holds that line in their head. The old Layout page
/// was 154 lines long and about a third of a screen.
///
/// So the split is gone. What is left is grouped by what a control *does*
/// rather than by which half of a word it changes: the theme, the accents, the
/// text, the conversation, the window, and then the arrangement.
///
/// The page has no heading of its own. The strip above it says
/// "Appearance & Layout" and gives it one line of description, which is where
/// the other thirteen pages get theirs from too.
class HubAppearanceLayoutSettings extends StatelessWidget {
  const HubAppearanceLayoutSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final t = MoonrelayThemeExtension.of(context).tokens;
        return HubPageBody(
          children: [
            // -- Theme ---------------------------------------------------
            HubSettingsSection(
              title: l10n.themeMode,
              children: [
                HubRadioRow<ThemeMode>(
                  value: controller.themeMode,
                  onChanged: (ThemeMode? v) {
                    if (v != null) controller.updateThemeMode(v);
                  },
                  options: <HubRadioOption<ThemeMode>>[
                    HubRadioOption<ThemeMode>(
                      value: ThemeMode.system,
                      label: l10n.system,
                    ),
                    HubRadioOption<ThemeMode>(
                      value: ThemeMode.light,
                      label: l10n.light,
                    ),
                    HubRadioOption<ThemeMode>(
                      value: ThemeMode.dark,
                      label: l10n.dark,
                    ),
                  ],
                ),
              ],
            ),

            // -- Accents -------------------------------------------------
            HubSettingsSection(
              title: l10n.accentColor,
              children: [
                // Grouped by the two populations of the lunar surface rather
                // than as one list of nine. The accents are named after
                // features now, and a reader who has looked at the Moon
                // knows there are dark seas and bright craters; showing them
                // in two groups says what the names mean, where a flat list
                // of nine proper nouns does not.
                for (final family in MoonrelayAccentFamily.values) ...[
                  InfoSectionLabel(
                    title: family == MoonrelayAccentFamily.mare
                        ? l10n.accentFamilyMare
                        : l10n.accentFamilyCrater,
                  ),
                  SizedBox(height: t.spaceXs),
                  HubRadioRow<String>(
                    value: controller.selectedAccentId,
                    onChanged: (String? v) {
                      if (v != null) controller.updateSelectedAccent(v);
                    },
                    dense: true,
                    options: <HubRadioOption<String>>[
                      for (final accent in MoonrelayAccents.all
                          .where((a) => a.family == family))
                        HubRadioOption<String>(
                          value: accent.id,
                          label: localizedAccent(accent, l10n),
                          leading: Container(
                            width: t.iconSizeSmall + t.spaceXs,
                            height: t.iconSizeSmall + t.spaceXs,
                            decoration: BoxDecoration(
                              color: accent.seedColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  SizedBox(height: t.spaceSm),
                ],
                InfoFootnote(text: l10n.accentDescription),
              ],
            ),

            // -- Text ----------------------------------------------------
            HubSettingsSection(
              title: l10n.fonts,
              children: [
                HubSliderTile(
                  icon: LucideIcons.type,
                  title: l10n.messageFontSize,
                  value: controller.fontSize,
                  valueLabel: '${controller.fontSize.round()} px',
                  min: 10,
                  max: 28,
                  divisions: 18,
                  onChanged: controller.updateFontSize,
                ),
                HubSliderTile(
                  icon: LucideIcons.zoomIn,
                  title: l10n.interfaceScale,
                  value: controller.uiScale,
                  valueLabel: '${controller.uiScale.toStringAsFixed(1)}\u00d7',
                  min: 0.7,
                  max: 2.0,
                  divisions: 13,
                  onChanged: controller.updateUiScale,
                ),
                HubNavTile(
                  icon: LucideIcons.type,
                  title: l10n.fontFamily,
                  value: controller.fontFamily,
                  onTap: () => _editTextField(
                    context,
                    l10n.fontFamily,
                    controller.fontFamily,
                    controller.updateFontFamily,
                  ),
                ),
                HubNavTile(
                  icon: LucideIcons.code,
                  title: l10n.monoFontFamily,
                  value: controller.monoFontFamily,
                  onTap: () => _editTextField(
                    context,
                    l10n.monoFontFamily,
                    controller.monoFontFamily,
                    controller.updateMonoFontFamily,
                  ),
                ),
              ],
            ),

            // -- Conversation --------------------------------------------
            HubSettingsSection(
              title: l10n.chatDisplayType,
              children: [
                HubRadioRow<DisplayType>(
                  value: controller.displayType,
                  onChanged: (DisplayType? v) {
                    if (v != null) controller.updateDisplayType(v);
                  },
                  options: <HubRadioOption<DisplayType>>[
                    HubRadioOption<DisplayType>(
                      value: DisplayType.modern,
                      label: l10n.displayModern,
                    ),
                    HubRadioOption<DisplayType>(
                      value: DisplayType.irc,
                      label: l10n.displayIrc,
                    ),
                    HubRadioOption<DisplayType>(
                      value: DisplayType.bubbles,
                      label: l10n.displayBubbles,
                    ),
                  ],
                ),
                HubSliderTile(
                  icon: LucideIcons.square,
                  title: l10n.bubbleRadius,
                  value: controller.bubbleRadius,
                  valueLabel: '${controller.bubbleRadius.round()} px',
                  min: 0,
                  max: 24,
                  divisions: 24,
                  onChanged: controller.updateBubbleRadius,
                ),
                HubSwitchTile(
                  icon: LucideIcons.clapperboard,
                  title: l10n.enableAnimations,
                  description: l10n.enableAnimationsDescription,
                  value: controller.enableAnimations,
                  onChanged: controller.updateEnableAnimations,
                ),
              ],
            ),

            // -- Arrangement ----------------------------------------------
            HubSettingsSection(
              title: l10n.layoutMode,
              subtitle: l10n.layoutModeDescription,
              children: [
                HubRadioRow<LayoutMode>(
                  value: controller.layoutMode,
                  onChanged: (LayoutMode? v) {
                    if (v != null) controller.setLayoutMode(v);
                  },
                  options: <HubRadioOption<LayoutMode>>[
                    HubRadioOption<LayoutMode>(
                      value: LayoutMode.auto,
                      label: l10n.layoutModeAuto,
                      icon: LucideIcons.sparkles,
                    ),
                    HubRadioOption<LayoutMode>(
                      value: LayoutMode.compact,
                      label: l10n.layoutModeCompact,
                      icon: LucideIcons.columns2,
                    ),
                    HubRadioOption<LayoutMode>(
                      value: LayoutMode.mobile,
                      label: l10n.layoutModeMobile,
                      icon: LucideIcons.smartphone,
                    ),
                  ],
                ),
              ],
            ),

            // -- Density --------------------------------------------------
            HubSettingsSection(
              title: l10n.layoutDensity,
              children: [
                HubChoiceChipRow<LayoutDensity>(
                  values: LayoutDensity.values,
                  selected: controller.density,
                  labelOf: (LayoutDensity d) => localizedLayoutDensity(d, l10n),
                  onSelected: controller.updateDensity,
                ),
              ],
            ),

            // -- Window ----------------------------------------------------
            HubSettingsSection(
              title: l10n.window,
              children: [
                HubSliderTile(
                  icon: LucideIcons.appWindow,
                  title: l10n.windowMinWidth,
                  value: controller.windowMinWidth,
                  valueLabel: '${controller.windowMinWidth.round()}',
                  min: 320,
                  max: 2000,
                  divisions: 168,
                  onChanged: controller.updateWindowMinWidth,
                ),
                HubSliderTile(
                  icon: LucideIcons.appWindow,
                  title: l10n.windowMinHeight,
                  value: controller.windowMinHeight,
                  valueLabel: '${controller.windowMinHeight.round()}',
                  min: 400,
                  max: 2000,
                  divisions: 160,
                  onChanged: controller.updateWindowMinHeight,
                ),
              ],
            ),

            // -- Room pane -------------------------------------------------
            HubSettingsSection(
              title: l10n.roomPane,
              subtitle: l10n.roomPaneDescription,
              children: [
                HubDropdownTile<RoomPaneTab>(
                  icon: LucideIcons.layoutList,
                  title: l10n.content,
                  value: controller.roomPaneTab,
                  items: RoomPaneTab.restorableOptions,
                  labelOf: (RoomPaneTab tab) => localizedRoomPaneTab(tab, l10n),
                  onChanged: (RoomPaneTab? tab) {
                    if (tab != null) controller.setRoomPaneTab(tab);
                  },
                ),
                HubSliderTile(
                  icon: LucideIcons.moveHorizontal,
                  title: l10n.widthLabel,
                  value: controller.roomPaneWidth,
                  valueLabel: '${controller.roomPaneWidth.round()} px',
                  min: 200,
                  max: 500,
                  divisions: 12,
                  onChanged: controller.setRoomPaneWidth,
                ),
              ],
            ),

            // -- Language ----------------------------------------------------
            HubSettingsSection(
              title: l10n.language,
              children: [
                HubRadioRow<String?>(
                  value: controller.locale,
                  onChanged: controller.updateLocale,
                  options: <HubRadioOption<String?>>[
                    // "Follow the system" has no value of its own, which is
                    // why this group is over `String?` and not over the
                    // locales. It is not the empty locale and it must not
                    // become one.
                    HubRadioOption<String?>(
                      value: null,
                      label: l10n.languageSystem,
                    ),
                    HubRadioOption<String?>(
                      value: 'en',
                      label: l10n.languageEnglish,
                    ),
                    HubRadioOption<String?>(
                      value: 'fa',
                      label: l10n.languagePersian,
                    ),
                  ],
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Asks for a font family by name.
  ///
  /// The three families are not offered as a list because the list would be
  /// the three that happen to be installed on the developer's machine, and a
  /// family nobody has is not a choice. What the app knows about is the name
  /// the theme is currently using, so that is what it shows, and editing it is
  /// a text field rather than a picker.
  Future<void> _editTextField(
    BuildContext context,
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
