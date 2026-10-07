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
import 'package:moonrelay/src/settings/settings_controller.dart';

// Privacy Settings

/// Links the app follows, presence it reports, and what it keeps.
///
/// Three of these settings only mean anything together: going offline
/// automatically is useless without the number of minutes, and the number of
/// minutes is not a choice without the switch. They are one group for that
/// reason, and the number greys out with the switch rather than being
/// separately enabled.
class HubPrivacySettings extends StatelessWidget {
  const HubPrivacySettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final bool presence = controller.autoOfflinePresenceEnabled;
        return HubPageBody(
          children: [
            // -- Deep links ---------------------------------------------
            HubSettingsSection(
              title: l10n.deepLinks,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.link,
                  title: l10n.deepLinkAutoJoin,
                  description: l10n.deepLinkAutoJoinDescription,
                  value: controller.deepLinkAutoJoin,
                  onChanged: (v) => controller.updateDeepLinkAutoJoin(v),
                ),
              ],
            ),

            // -- Presence ---------------------------------------------------
            HubSettingsSection(
              title: l10n.presence,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.circleUser,
                  title: l10n.autoOfflinePresenceEnabled,
                  description: l10n.autoOfflinePresenceEnabledDescription,
                  value: controller.autoOfflinePresenceEnabled,
                  onChanged: (v) =>
                      controller.updateAutoOfflinePresenceEnabled(v),
                ),
                HubSliderTile(
                  icon: LucideIcons.timer,
                  title: l10n.autoOfflinePresenceMinutes,
                  value: controller.autoOfflinePresenceMinutes.toDouble(),
                  valueLabel: '${controller.autoOfflinePresenceMinutes}',
                  min: 1,
                  max: 60,
                  divisions: 60,
                  // One gate, not two. The row used to carry both `enabled:
                  // false` and a null `onChanged`, so the label greyed out by
                  // one mechanism while the slider went inert by another, and
                  // the two could disagree.
                  onChanged: presence
                      ? (v) =>
                          controller.updateAutoOfflinePresenceMinutes(v.round())
                      : null,
                ),
              ],
            ),

            // -- Local data --------------------------------------------------
            HubSettingsSection(
              title: l10n.database,
              children: [
                HubSliderTile(
                  icon: LucideIcons.history,
                  title: l10n.dbBackupKeepCount,
                  value: controller.dbBackupKeepCount.toDouble(),
                  valueLabel: '${controller.dbBackupKeepCount}',
                  min: 0,
                  max: 10,
                  divisions: 10,
                  onChanged: (v) =>
                      controller.updateDbBackupKeepCount(v.round()),
                ),
              ],
            ),

            // -- Logs ----------------------------------------------------------
            HubSettingsSection(
              title: l10n.logs,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.eraser,
                  title: l10n.wipeLogsOnLogout,
                  description: l10n.wipeLogsOnLogoutDescription,
                  value: controller.wipeLogsOnLogout,
                  onChanged: (v) => controller.updateWipeLogsOnLogout(v),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
