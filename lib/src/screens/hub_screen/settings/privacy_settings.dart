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
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Privacy, deep-link, and data-management settings.
class HubPrivacySettings extends StatelessWidget {
  const HubPrivacySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final t = MoonrelayThemeExtension.of(context).tokens;
        return SingleChildScrollView(
          padding: EdgeInsets.all(t.spaceXl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.privacy,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: t.spaceXs),
              Text(
                l10n.privacyDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: t.spaceXl),
              HubSettingsSection(
                title: l10n.deepLinks,
                children: [
                  SwitchListTile(
                    title: Text(l10n.deepLinkAutoJoin),
                    subtitle: Text(l10n.deepLinkAutoJoinDescription),
                    value: controller.deepLinkAutoJoin,
                    onChanged: (v) => controller.updateDeepLinkAutoJoin(v),
                    secondary: const Icon(LucideIcons.link, size: 22),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),
              HubSettingsSection(
                title: l10n.database,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.history, size: 22),
                    title: Text(l10n.dbBackupKeepCount),
                    subtitle: Text('${controller.dbBackupKeepCount}'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.dbBackupKeepCount.toDouble(),
                        min: 0,
                        max: 10,
                        divisions: 10,
                        label: '${controller.dbBackupKeepCount}',
                        onChanged: (v) =>
                            controller.updateDbBackupKeepCount(v.round()),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),
              HubSettingsSection(
                title: l10n.presence,
                children: [
                  SwitchListTile(
                    title: Text(l10n.autoOfflinePresenceEnabled),
                    subtitle:
                        Text(l10n.autoOfflinePresenceEnabledDescription),
                    value: controller.autoOfflinePresenceEnabled,
                    onChanged: (v) =>
                        controller.updateAutoOfflinePresenceEnabled(v),
                    secondary: const Icon(LucideIcons.circleUser, size: 22),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.timer, size: 22),
                    enabled: controller.autoOfflinePresenceEnabled,
                    title: Text(l10n.autoOfflinePresenceMinutes),
                    subtitle: Text('${controller.autoOfflinePresenceMinutes}'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.autoOfflinePresenceMinutes
                            .toDouble(),
                        min: 1,
                        max: 60,
                        divisions: 60,
                        label: '${controller.autoOfflinePresenceMinutes}',
                        onChanged: controller.autoOfflinePresenceEnabled
                            ? (v) => controller
                                .updateAutoOfflinePresenceMinutes(v.round())
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),
              HubSettingsSection(
                title: l10n.logs,
                children: [
                  SwitchListTile(
                    title: Text(l10n.wipeLogsOnLogout),
                    subtitle: Text(l10n.wipeLogsOnLogoutDescription),
                    value: controller.wipeLogsOnLogout,
                    onChanged: (v) => controller.updateWipeLogsOnLogout(v),
                    secondary: const Icon(LucideIcons.eraser, size: 22),
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
