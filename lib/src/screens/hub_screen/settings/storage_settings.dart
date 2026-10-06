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

// -----------------------------------------------------------------------------
// Storage Settings
// -----------------------------------------------------------------------------

/// What arrives on its own, and what the app holds on disk.
///
/// The three auto-download policies were a private widget that drew a bold
/// label and then a row of chips, repeated three times over, so the section it
/// sat in had four headings in it where three would do. They are now three
/// labelled chip rows in one group.
class HubStorageSettings extends StatelessWidget {
  const HubStorageSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        return HubPageBody(
          children: [
            // -- Auto download ---------------------------------------------
            HubSettingsSection(
              title: l10n.autoDownload,
              children: [
                HubChoiceChipRow<AutoDownloadPolicy>(
                  label: l10n.autoDownloadImages,
                  values: AutoDownloadPolicy.values,
                  selected: controller.autoDownloadImages,
                  labelOf: (AutoDownloadPolicy p) =>
                      localizedAutoDownloadPolicy(p, l10n),
                  onSelected: controller.updateAutoDownloadImages,
                ),
                HubChoiceChipRow<AutoDownloadPolicy>(
                  label: l10n.autoDownloadFiles,
                  values: AutoDownloadPolicy.values,
                  selected: controller.autoDownloadFiles,
                  labelOf: (AutoDownloadPolicy p) =>
                      localizedAutoDownloadPolicy(p, l10n),
                  onSelected: controller.updateAutoDownloadFiles,
                ),
                HubChoiceChipRow<AutoDownloadPolicy>(
                  label: l10n.autoDownloadVideos,
                  values: AutoDownloadPolicy.values,
                  selected: controller.autoDownloadVideos,
                  labelOf: (AutoDownloadPolicy p) =>
                      localizedAutoDownloadPolicy(p, l10n),
                  onSelected: controller.updateAutoDownloadVideos,
                ),
              ],
            ),

            // -- Attachments --------------------------------------------------
            HubSettingsSection(
              title: l10n.attachmentClickThreshold,
              children: [
                HubSliderTile(
                  icon: LucideIcons.mousePointerClick,
                  title: l10n.attachmentClickThresholdMb,
                  value: controller.attachmentClickThresholdMb.toDouble(),
                  valueLabel: '${controller.attachmentClickThresholdMb} MB',
                  min: 1,
                  max: 200,
                  divisions: 199,
                  onChanged: (v) =>
                      controller.updateAttachmentClickThresholdMb(v.round()),
                ),
              ],
            ),

            // -- Drafts ----------------------------------------------------------
            HubSettingsSection(
              title: l10n.drafts,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.fileText,
                  title: l10n.draftsEnabled,
                  description: l10n.draftsEnabledDescription,
                  value: controller.draftsEnabled,
                  onChanged: (v) => controller.updateDraftsEnabled(v),
                ),
                HubSliderTile(
                  icon: LucideIcons.clock,
                  title: l10n.draftRetentionDays,
                  value: controller.draftRetentionDays.toDouble(),
                  valueLabel: '${controller.draftRetentionDays}',
                  min: 0,
                  max: 90,
                  divisions: 90,
                  // Keeping drafts for 30 days while drafts are switched off
                  // describes a state the user cannot reach, so the number
                  // goes with the switch.
                  onChanged: controller.draftsEnabled
                      ? (v) => controller.updateDraftRetentionDays(v.round())
                      : null,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
