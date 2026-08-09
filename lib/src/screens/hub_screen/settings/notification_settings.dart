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
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Notification Settings
// ─────────────────────────────────────────────────────────────────────────────

class HubNotificationSettings extends StatelessWidget {
  const HubNotificationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        final t = MoonrelayThemeExtension.of(context).tokens;
        return SingleChildScrollView(
          padding: EdgeInsets.all(t.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.notifications,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.notificationsDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              HubSettingsSection(
                title: l10n.notifications,
                children: [
                  SwitchListTile(
                    title: Text(l10n.enableNotifications),
                    subtitle: Text(l10n.enableNotificationsDescription),
                    value: controller.notificationsEnabled,
                    onChanged: (v) => controller.updateNotificationsEnabled(v),
                    secondary: const Icon(LucideIcons.bell, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.notifyDmsOnly),
                    subtitle: Text(l10n.notifyDmsOnlyDescription),
                    value: controller.notifyDmsOnly,
                    onChanged: (v) => controller.updateNotifyDmsOnly(v),
                    secondary: const Icon(LucideIcons.messageCircle, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.notifyWhenFocused),
                    subtitle: Text(l10n.notifyWhenFocusedDescription),
                    value: controller.notifyWhenFocused,
                    onChanged: (v) => controller.updateNotifyWhenFocused(v),
                    secondary: const Icon(LucideIcons.appWindow, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.notificationSoundEnabled),
                    subtitle: Text(l10n.notificationSoundEnabledDescription),
                    value: controller.notificationSoundEnabled,
                    onChanged: (v) =>
                        controller.updateNotificationSoundEnabled(v),
                    secondary: const Icon(LucideIcons.volume2, size: 22),
                  ),
                  const Divider(height: 1, indent: 72),
                  ListTile(
                    leading: const Icon(LucideIcons.play, size: 22),
                    title: Text(l10n.testNotification),
                    subtitle: Text(l10n.testNotificationDescription),
                    onTap: () async {
                      final notif = context.read<NotificationService>();
                      try {
                        await notif.showTestNotification();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.testNotificationFired),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(l10n.notificationFailed('$e')),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
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
