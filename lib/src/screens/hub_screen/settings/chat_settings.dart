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

// Chat Settings

/// How the conversation behaves.
///
/// The six media limits below are one setting repeated: a pixel ceiling on a
/// kind of attachment, each settable over the same range. They were six
/// hand-written `ListTile`s, which is six chances for the slider well to be
/// 160 wide here and 200 on the page above, and it is why this file was 281
/// lines for eleven controls. It is now the same eleven controls in a page
/// that says what it is in the strip above it.
class HubChatSettings extends StatelessWidget {
  const HubChatSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        return HubPageBody(
          children: [
            // -- Timeline -------------------------------------------------
            HubSettingsSection(
              title: l10n.timeline,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.info,
                  title: l10n.showStateEvents,
                  description: l10n.showStateEventsDescription,
                  value: controller.showStateEvents,
                  onChanged: (v) => controller.updateShowStateEvents(v),
                ),
                HubSwitchTile(
                  icon: LucideIcons.eye,
                  title: l10n.sendReadReceipts,
                  description: l10n.sendReadReceiptsDescription,
                  value: controller.sendReadReceipts,
                  onChanged: (v) => controller.updateSendReadReceipts(v),
                ),
                HubSwitchTile(
                  icon: LucideIcons.eye,
                  title: l10n.showReadReceipts,
                  description: l10n.showReadReceiptsDescription,
                  value: controller.showReadReceipts,
                  onChanged: (v) => controller.updateShowReadReceipts(v),
                ),
                HubSwitchTile(
                  icon: LucideIcons.link2,
                  title: l10n.linkPreviewsEnabled,
                  description: l10n.linkPreviewsEnabledDescription,
                  value: controller.linkPreviewsEnabled,
                  onChanged: (v) => controller.updateLinkPreviewsEnabled(v),
                ),
                HubSliderTile(
                  icon: LucideIcons.maximize2,
                  title: l10n.replyPreviewThreshold,
                  value: controller.replyPreviewThreshold.toDouble(),
                  valueLabel: '${controller.replyPreviewThreshold}',
                  min: 20,
                  max: 500,
                  divisions: 48,
                  onChanged: (v) =>
                      controller.updateReplyPreviewThreshold(v.round()),
                ),
              ],
            ),

            // -- Typing ------------------------------------------------------
            HubSettingsSection(
              title: l10n.typing,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.keyboard,
                  title: l10n.sendTypingNotifications,
                  description: l10n.sendTypingNotificationsDescription,
                  value: controller.sendTypingNotifications,
                  onChanged: (v) => controller.updateSendTypingNotifications(v),
                ),
                HubSwitchTile(
                  icon: LucideIcons.moreHorizontal,
                  title: l10n.showTypingIndicator,
                  description: l10n.showTypingIndicatorDescription,
                  value: controller.showTypingIndicator,
                  onChanged: (v) => controller.updateShowTypingIndicator(v),
                ),
              ],
            ),

            // -- Composer ------------------------------------------------------
            HubSettingsSection(
              title: l10n.sendShortcut,
              children: [
                HubChoiceChipRow<SendShortcut>(
                  values: SendShortcut.values,
                  selected: controller.sendShortcut,
                  labelOf: (SendShortcut s) => localizedSendShortcut(s, l10n),
                  onSelected: controller.updateSendShortcut,
                ),
              ],
            ),

            // -- Media ---------------------------------------------------------
            // Every one of these is "the largest this attachment may be", so
            // they are one group rather than six. Splitting them across
            // sections would mean six headings that all say the same thing.
            HubSettingsSection(
              title: l10n.mediaSizes,
              children: [
                HubSliderTile(
                  icon: LucideIcons.image,
                  title: l10n.imageThumbnailMaxPx,
                  value: controller.imageThumbnailMaxPx.toDouble(),
                  valueLabel: '${controller.imageThumbnailMaxPx} px',
                  min: 80,
                  max: 1200,
                  divisions: 112,
                  onChanged: (v) =>
                      controller.updateImageThumbnailMaxPx(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.smile,
                  title: l10n.stickerMaxPx,
                  value: controller.stickerMaxPx.toDouble(),
                  valueLabel: '${controller.stickerMaxPx} px',
                  min: 80,
                  max: 800,
                  divisions: 72,
                  onChanged: (v) => controller.updateStickerMaxPx(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.video,
                  title: l10n.videoMaxPx,
                  value: controller.videoMaxPx.toDouble(),
                  valueLabel: '${controller.videoMaxPx} px',
                  min: 80,
                  max: 1200,
                  divisions: 112,
                  onChanged: (v) => controller.updateVideoMaxPx(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.music,
                  title: l10n.audioMaxPx,
                  value: controller.audioMaxPx.toDouble(),
                  valueLabel: '${controller.audioMaxPx} px',
                  min: 80,
                  max: 1200,
                  divisions: 112,
                  onChanged: (v) => controller.updateAudioMaxPx(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.file,
                  title: l10n.fileMaxPx,
                  value: controller.fileMaxPx.toDouble(),
                  valueLabel: '${controller.fileMaxPx} px',
                  min: 80,
                  max: 1200,
                  divisions: 112,
                  onChanged: (v) => controller.updateFileMaxPx(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.mapPin,
                  title: l10n.locationMaxPx,
                  value: controller.locationMaxPx.toDouble(),
                  valueLabel: '${controller.locationMaxPx} px',
                  min: 80,
                  max: 1200,
                  divisions: 112,
                  onChanged: (v) => controller.updateLocationMaxPx(v.round()),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
