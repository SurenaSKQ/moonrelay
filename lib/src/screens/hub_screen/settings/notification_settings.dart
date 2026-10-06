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
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_controls.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';

// -----------------------------------------------------------------------------
// Notification Settings
// -----------------------------------------------------------------------------

class HubNotificationSettings extends StatelessWidget {
  const HubNotificationSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        return HubPageBody(
          children: [
            // The section is "When to notify" rather than a second copy of the
            // page's own name. The strip above already says Notifications and
            // the page used to say it twice, in a 14px strip and a 22px
            // heading, four lines apart.
            HubSettingsSection(
              title: l10n.whenToNotify,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.bell,
                  title: l10n.enableNotifications,
                  description: l10n.enableNotificationsDescription,
                  value: controller.notificationsEnabled,
                  onChanged: (v) => controller.updateNotificationsEnabled(v),
                ),
                HubSwitchTile(
                  icon: LucideIcons.messageCircle,
                  title: l10n.notifyDmsOnly,
                  description: l10n.notifyDmsOnlyDescription,
                  value: controller.notifyDmsOnly,
                  onChanged: (v) => controller.updateNotifyDmsOnly(v),
                ),
                HubSwitchTile(
                  icon: LucideIcons.appWindow,
                  title: l10n.notifyWhenFocused,
                  description: l10n.notifyWhenFocusedDescription,
                  value: controller.notifyWhenFocused,
                  onChanged: (v) => controller.updateNotifyWhenFocused(v),
                ),
                HubSwitchTile(
                  icon: LucideIcons.volume2,
                  title: l10n.notificationSoundEnabled,
                  description: l10n.notificationSoundEnabledDescription,
                  value: controller.notificationSoundEnabled,
                  onChanged: (v) =>
                      controller.updateNotificationSoundEnabled(v),
                ),
              ],
            ),

            // The test notification is not a setting, so it is a section of
            // its own. It used to be the last row of the settings above, cut
            // off with a `Divider(height: 1, indent: 72)` that guessed where
            // the icons ended.
            HubSettingsSection(
              title: l10n.checkItWorks,
              children: [
                HubActionTile(
                  icon: LucideIcons.play,
                  title: l10n.testNotification,
                  description: l10n.testNotificationDescription,
                  onTap: () => _fireTestNotification(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  /// Shows a notification and says whether it arrived.
  ///
  /// Both outcomes are reported. The failure used to be logged nowhere and
  /// shown as a bare interpolated exception, so a reader who had notifications
  /// switched off saw a snackbar about a platform channel instead of about
  /// their own setting.
  Future<void> _fireTestNotification(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<NotificationService>();
    try {
      await service.showTestNotification();
    } catch (e) {
      if (!context.mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.notificationFailed('$e')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(l10n.testNotificationFired),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
