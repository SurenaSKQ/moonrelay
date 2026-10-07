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
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_controls.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';

// Background & Tray Settings

/// What the window does when it is closed, and what the tray offers.
///
/// "Start minimised" and "what the tray icon's left click does" are both
/// settings that only mean anything while a tray icon exists, so both rows
/// refuse input when the icon is off rather than silently accepting a value
/// that nothing will read.
class HubBackgroundSettings extends StatelessWidget {
  const HubBackgroundSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final bool tray = controller.showTrayIcon;
        return HubPageBody(
          children: [
            // -- Tray ------------------------------------------------------
            HubSettingsSection(
              title: l10n.systemTray,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.minimize2,
                  title: l10n.showTrayIcon,
                  description: l10n.showTrayIconDescription,
                  value: controller.showTrayIcon,
                  onChanged: (v) => controller.updateShowTrayIcon(v),
                ),
              ],
            ),

            // -- Window behaviour --------------------------------------------
            HubSettingsSection(
              title: l10n.windowBehaviour,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.xCircle,
                  title: l10n.closeToTray,
                  description: l10n.closeToTrayDescription,
                  value: controller.closeToTray,
                  onChanged: (v) => controller.updateCloseToTray(v),
                ),
                HubSwitchTile(
                  icon: LucideIcons.minimize,
                  title: l10n.minimizeToTray,
                  description: l10n.minimizeToTrayDescription,
                  value: controller.minimizeToTray,
                  onChanged: (v) => controller.updateMinimizeToTray(v),
                ),
                HubSwitchTile(
                  icon: LucideIcons.play,
                  title: l10n.startMinimized,
                  description: l10n.startMinimizedDescription,
                  value: controller.startMinimized,
                  onChanged:
                      tray ? (v) => controller.updateStartMinimized(v) : null,
                ),
              ],
            ),

            // -- Tray click ----------------------------------------------------
            // The section title was also repeated inside its own card, which
            // is the same double-title the sub-page strip used to have: the
            // name of a group belongs above the group.
            HubSettingsSection(
              title: l10n.trayLeftClick,
              children: [
                HubChoiceChipRow<TrayClickAction>(
                  values: TrayClickAction.values,
                  selected: controller.trayLeftClick,
                  labelOf: (action) => localizedTrayClickAction(action, l10n),
                  onSelected: tray ? controller.updateTrayLeftClick : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
