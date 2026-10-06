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
import 'package:provider/provider.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_controls.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:moonrelay/src/widgets/shortcut_reference.dart';

// -----------------------------------------------------------------------------
// Keybinds Settings
// -----------------------------------------------------------------------------

/// The keys, grouped by where they apply.
///
/// The grouping is the whole point of this page. It used to file `Ctrl+F` and
/// `Ctrl+Shift+M` under "Global shortcuts", which they are not, so the page
/// was describing an app that does not exist. Both are now under the room,
/// because both act on whichever room happens to be open.
///
/// The chord list itself comes from [shortcutReference], which the cheat sheet
/// also reads, so this page can no longer fall behind the overlay: a chord
/// added to the app is added here by writing it once.
class HubKeybindSettings extends StatelessWidget {
  const HubKeybindSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final List<ShortcutReferenceEntry> all = shortcutReference();
        return HubPageBody(
          children: [
            // -- Send shortcut -------------------------------------------
            HubSettingsSection(
              title: l10n.sendShortcut,
              subtitle: l10n.sendShortcutDescription,
              children: [
                HubChoiceChipRow<SendShortcut>(
                  values: SendShortcut.values,
                  selected: controller.sendShortcut,
                  labelOf: (SendShortcut s) => localizedSendShortcut(s, l10n),
                  onSelected: controller.updateSendShortcut,
                ),
              ],
            ),

            // -- Everywhere ------------------------------------------------
            HubSettingsSection(
              title: l10n.shortcutsEverywhere,
              children: [
                for (final entry in shortcutsInScope(
                  all,
                  ShortcutScope.global,
                ))
                  HubShortcutRow(entry: entry, l10n: l10n),
              ],
            ),

            // -- In a room ---------------------------------------------------
            HubSettingsSection(
              title: l10n.shortcutsInRoom,
              children: [
                for (final entry in shortcutsInScope(all, ShortcutScope.room))
                  HubShortcutRow(entry: entry, l10n: l10n),
              ],
            ),

            // -- While typing -------------------------------------------------
            HubSettingsSection(
              title: l10n.shortcutsWhileTyping,
              children: [
                for (final entry in shortcutsInScope(
                  all,
                  ShortcutScope.composer,
                ))
                  HubShortcutRow(entry: entry, l10n: l10n),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// One chord, described, with its keys shown as keycaps.
///
/// The keys render in the app's monospace face. This row used to say
/// `fontFamily: 'monospace'`, which is the CSS keyword rather than a font:
/// on a machine with no family by that exact name it silently falls back to the
/// UI face, so the keycaps were not reliably monospace at all, and they were
/// the one row in the app where that mattered most.
class HubShortcutRow extends StatelessWidget {
  const HubShortcutRow({super.key, required this.entry, required this.l10n});

  final ShortcutReferenceEntry entry;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final mono = MoonrelayTypography.mono(context);

    final caption = entry.layoutDependent
        ? '${entry.description(l10n)} · ${l10n.shortcutLayoutDependent}'
        : entry.description(l10n);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceLg,
        vertical: t.spaceMd,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              caption,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ),
          SizedBox(width: t.spaceLg),
          Wrap(
            spacing: t.spaceXs,
            children: [
              for (final key in entry.keys)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.spaceSm,
                    vertical: t.spaceXxs + 1,
                  ),
                  decoration: BoxDecoration(
                    // The card's own step, so a keycap reads as a raised key
                    // rather than as a second card inside the card.
                    color: scheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(t.radiusSm),
                    border: Border.all(
                      color:
                          MoonrelayThemeExtension.of(context).layers.hairline,
                    ),
                  ),
                  child: Text(
                    key,
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: mono,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
