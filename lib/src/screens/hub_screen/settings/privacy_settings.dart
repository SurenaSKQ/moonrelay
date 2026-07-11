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

/// Privacy, deep-link, and data-management settings.
class HubPrivacySettings extends StatelessWidget {
  const HubPrivacySettings({super.key});

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
                l10n.privacy,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.privacyDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

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
              const SizedBox(height: 16),

              HubSettingsSection(
                title: l10n.database,
                children: [
                  SwitchListTile(
                    title: Text(l10n.dbWipeRequiresPrompt),
                    subtitle: Text(l10n.dbWipeRequiresPromptDescription),
                    value: controller.dbWipeRequiresPrompt,
                    onChanged: (v) => controller.updateDbWipeRequiresPrompt(v),
                    secondary: const Icon(LucideIcons.database, size: 22),
                  ),
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
                  ListTile(
                    leading: const Icon(LucideIcons.user, size: 22),
                    title: Text(l10n.avatarCacheTtlDays),
                    subtitle: Text('${controller.avatarCacheTtlDays}'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.avatarCacheTtlDays.toDouble(),
                        min: 0,
                        max: 90,
                        divisions: 90,
                        label: '${controller.avatarCacheTtlDays}',
                        onChanged: (v) =>
                            controller.updateAvatarCacheTtlDays(v.round()),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              HubSettingsSection(
                title: l10n.security,
                children: [
                  SwitchListTile(
                    title: Text(l10n.autoLockEnabled),
                    subtitle: Text(l10n.autoLockEnabledDescription),
                    value: controller.autoLockEnabled,
                    onChanged: (v) => controller.updateAutoLockEnabled(v),
                    secondary: const Icon(LucideIcons.lock, size: 22),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.timer, size: 22),
                    enabled: controller.autoLockEnabled,
                    title: Text(l10n.autoLockMinutes),
                    subtitle: Text('${controller.autoLockMinutes}'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.autoLockMinutes.toDouble(),
                        min: 0,
                        max: 60,
                        divisions: 60,
                        label: '${controller.autoLockMinutes}',
                        onChanged: controller.autoLockEnabled
                            ? (v) => controller.updateAutoLockMinutes(v.round())
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

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