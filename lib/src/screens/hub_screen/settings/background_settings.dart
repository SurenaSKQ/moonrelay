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
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Background & Tray Settings
// ─────────────────────────────────────────────────────────────────────────────

class HubBackgroundSettings extends StatelessWidget {
  const HubBackgroundSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.backgroundAndTray,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.backgroundAndTrayDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Show tray icon
              HubSettingsSection(
                title: l10n.systemTray,
                children: [
                  SwitchListTile(
                    title: Text(l10n.showTrayIcon),
                    subtitle: Text(l10n.showTrayIconDescription),
                    value: controller.showTrayIcon,
                    onChanged: (v) => controller.updateShowTrayIcon(v),
                    secondary: const Icon(LucideIcons.minimize2, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Close to tray
              HubSettingsSection(
                title: l10n.windowBehaviour,
                children: [
                  SwitchListTile(
                    title: Text(l10n.closeToTray),
                    subtitle: Text(l10n.closeToTrayDescription),
                    value: controller.closeToTray,
                    onChanged: (v) => controller.updateCloseToTray(v),
                    secondary: const Icon(LucideIcons.xCircle, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.minimizeToTray),
                    subtitle: Text(l10n.minimizeToTrayDescription),
                    value: controller.minimizeToTray,
                    onChanged: (v) => controller.updateMinimizeToTray(v),
                    secondary: const Icon(LucideIcons.minimize, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.startMinimized),
                    subtitle: Text(l10n.startMinimizedDescription),
                    value: controller.startMinimized,
                    onChanged: controller.showTrayIcon
                        ? (v) => controller.updateStartMinimized(v)
                        : null,
                    secondary: const Icon(LucideIcons.play, size: 22),
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
