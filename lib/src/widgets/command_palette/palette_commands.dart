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
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/widgets/command_palette/palette_models.dart';
import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';

/// Opens the hub at [category], optionally at one of its sub-items.
///
/// `push`, so the chat the palette was opened over is still underneath and
/// the hub's back button returns to it. This is what the modal overlay used
/// to do; the difference is that the hub is now a real location, so the
/// palette's `/hub/...` entries and its six `>`-mode actions resolve to the
/// same place instead of only one of them working.
void openHub(BuildContext context, {String? category, String? sub}) {
  context.push(hubPath(category: category, sub: sub));
}

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


List<CommandAction> buildPaletteActions(BuildContext context, AppLocalizations loc) {
  final settings = settingsControllerOrNull(context);
  return [
    CommandAction(
      key: 'open_settings',
      label: loc.commandPaletteOpenSettings,
      icon: LucideIcons.settings,
      callback: (ctx) {
        openHub(ctx, category: HubRouteKeys.settings);
      },
    ),
    CommandAction(
      key: 'open_accounts',
      label: loc.commandPaletteOpenAccounts,
      icon: LucideIcons.userRound,
      callback: (ctx) {
        openHub(ctx, category: HubRouteKeys.accounts);
      },
    ),
    CommandAction(
      key: 'open_logs',
      label: loc.commandPaletteOpenLogs,
      icon: LucideIcons.scrollText,
      callback: (ctx) {
        openHub(ctx, category: HubRouteKeys.settings, sub: HubRouteKeys.logs);
      },
    ),
    CommandAction(
      key: 'open_profile',
      label: loc.commandPaletteOpenProfile,
      icon: LucideIcons.userCircle,
      callback: (ctx) {
        openHub(ctx);
      },
    ),
    CommandAction(
      key: 'open_about',
      label: loc.commandPaletteOpenAbout,
      icon: LucideIcons.info,
      callback: (ctx) {
        openHub(ctx, category: HubRouteKeys.about);
      },
    ),
    CommandAction(
      key: 'open_security',
      label: loc.commandPaletteOpenSecurity,
      icon: LucideIcons.shield,
      callback: (ctx) {
        openHub(ctx, category: HubRouteKeys.settings, sub: HubRouteKeys.security);
      },
    ),
    CommandAction(
      key: 'toggle_left_sidebar',
      label: loc.commandPaletteToggleSidebar,
      icon: LucideIcons.panelLeft,
      callback: (ctx) {
        if (settings != null) {
          settings.setLeftSidebarVisible(!settings.leftSidebarVisible);
        }
      },
    ),
    CommandAction(
      key: 'toggle_right_sidebar',
      label: loc.commandPaletteToggleRightSidebar,
      icon: LucideIcons.panelRight,
      callback: (ctx) {
        if (settings != null) {
          settings.setRightSidebarVisible(!settings.rightSidebarVisible);
        }
      },
    ),
    CommandAction(
      key: 'add_room',
      label: loc.commandPaletteAddRoom,
      icon: LucideIcons.plusCircle,
      callback: (ctx) => ctx.push('/main/addroom'),
    ),
  ];
}

List<SettingsEntry> buildSettingsEntries(AppLocalizations loc) => [
      SettingsEntry(
        label: loc.appearance,
        description: loc.commandPaletteAppearanceDesc,
        icon: LucideIcons.palette,
        path: hubPath(category: HubRouteKeys.settings, sub: HubRouteKeys.appearance),
      ),
      SettingsEntry(
        label: loc.layout,
        description: loc.commandPaletteLayoutDesc,
        icon: LucideIcons.layoutDashboard,
        path: hubPath(category: HubRouteKeys.settings, sub: HubRouteKeys.layout),
      ),
      SettingsEntry(
        label: loc.encryptionAndSecurity,
        description: loc.commandPaletteSecurityDesc,
        icon: LucideIcons.shield,
        path: hubPath(category: HubRouteKeys.settings, sub: HubRouteKeys.security),
      ),
      SettingsEntry(
        label: loc.chatSettings,
        description: loc.commandPaletteChatDesc,
        icon: LucideIcons.messageSquare,
        path: hubPath(category: HubRouteKeys.settings, sub: HubRouteKeys.chat),
      ),

      SettingsEntry(
        label: loc.backgroundAndTray,
        description: loc.commandPaletteBackgroundDesc,
        icon: LucideIcons.minimize2,
        path: hubPath(category: HubRouteKeys.settings, sub: HubRouteKeys.background),
      ),
      SettingsEntry(
        label: loc.notifications,
        description: loc.commandPaletteNotificationsDesc,
        icon: LucideIcons.bell,
        path: hubPath(category: HubRouteKeys.settings, sub: HubRouteKeys.notifications),
      ),
      SettingsEntry(
        label: loc.blockedUsers,
        description: loc.commandPaletteBlockedDesc,
        icon: LucideIcons.ban,
        path: hubPath(category: HubRouteKeys.settings, sub: HubRouteKeys.blocked),
      ),
      SettingsEntry(
        label: loc.logs,
        description: loc.commandPaletteLogsDesc,
        icon: LucideIcons.fileText,
        path: hubPath(category: HubRouteKeys.settings, sub: HubRouteKeys.logs),
      ),
  ];
