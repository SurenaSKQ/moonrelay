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
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Chat Settings
// ─────────────────────────────────────────────────────────────────────────────

class HubChatSettings extends StatelessWidget {
  const HubChatSettings({super.key});

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
                l10n.chatSettings,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: t.spaceXs),
              Text(
                l10n.timelineAndMessages,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: t.spaceXl),
              HubSettingsSection(
                title: l10n.timeline,
                children: [
                  SwitchListTile(
                    title: Text(l10n.showStateEvents),
                    subtitle: Text(l10n.showStateEventsDescription),
                    value: controller.showStateEvents,
                    onChanged: (v) => controller.updateShowStateEvents(v),
                    secondary: const Icon(Icons.info_outline),
                  ),
                  SwitchListTile(
                    title: Text(l10n.sendReadReceipts),
                    subtitle: Text(l10n.sendReadReceiptsDescription),
                    value: controller.sendReadReceipts,
                    onChanged: (v) => controller.updateSendReadReceipts(v),
                    secondary: const Icon(LucideIcons.eye, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.showReadReceipts),
                    subtitle: Text(l10n.showReadReceiptsDescription),
                    value: controller.showReadReceipts,
                    onChanged: (v) => controller.updateShowReadReceipts(v),
                    secondary: const Icon(LucideIcons.eye, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.linkPreviewsEnabled),
                    subtitle: Text(l10n.linkPreviewsEnabledDescription),
                    value: controller.linkPreviewsEnabled,
                    onChanged: (v) => controller.updateLinkPreviewsEnabled(v),
                    secondary: const Icon(LucideIcons.link2, size: 22),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.maximize2, size: 22),
                    title: Text(l10n.replyPreviewThreshold),
                    subtitle: Text('${controller.replyPreviewThreshold}'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.replyPreviewThreshold.toDouble(),
                        min: 20,
                        max: 500,
                        divisions: 48,
                        label: '${controller.replyPreviewThreshold}',
                        onChanged: (v) =>
                            controller.updateReplyPreviewThreshold(v.round()),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),
              HubSettingsSection(
                title: l10n.typing,
                children: [
                  SwitchListTile(
                    title: Text(l10n.sendTypingNotifications),
                    subtitle: Text(l10n.sendTypingNotificationsDescription),
                    value: controller.sendTypingNotifications,
                    onChanged: (v) =>
                        controller.updateSendTypingNotifications(v),
                    secondary: const Icon(LucideIcons.keyboard, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.showTypingIndicator),
                    subtitle: Text(l10n.showTypingIndicatorDescription),
                    value: controller.showTypingIndicator,
                    onChanged: (v) => controller.updateShowTypingIndicator(v),
                    secondary: const Icon(LucideIcons.moreHorizontal, size: 22),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),
              HubSettingsSection(
                title: l10n.composer,
                children: [
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.spaceLg,
                      vertical: t.spaceSm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.sendShortcut,
                          style: Theme.of(context).textTheme.titleSmall,
                        ),
                        SizedBox(height: t.spaceSm),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final s in SendShortcut.values)
                              ChoiceChip(
                                label: Text(localizedSendShortcut(s, l10n)),
                                selected: s == controller.sendShortcut,
                                onSelected: (_) =>
                                    controller.updateSendShortcut(s),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),
              HubSettingsSection(
                title: l10n.mediaSizes,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.image, size: 22),
                    title: Text(l10n.imageThumbnailMaxPx),
                    subtitle: Text('${controller.imageThumbnailMaxPx} px'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.imageThumbnailMaxPx.toDouble(),
                        min: 80,
                        max: 1200,
                        divisions: 112,
                        label: '${controller.imageThumbnailMaxPx} px',
                        onChanged: (v) =>
                            controller.updateImageThumbnailMaxPx(v.round()),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.smile, size: 22),
                    title: Text(l10n.stickerMaxPx),
                    subtitle: Text('${controller.stickerMaxPx} px'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.stickerMaxPx.toDouble(),
                        min: 80,
                        max: 800,
                        divisions: 72,
                        label: '${controller.stickerMaxPx} px',
                        onChanged: (v) =>
                            controller.updateStickerMaxPx(v.round()),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.video, size: 22),
                    title: Text(l10n.videoMaxPx),
                    subtitle: Text('${controller.videoMaxPx} px'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.videoMaxPx.toDouble(),
                        min: 80,
                        max: 1200,
                        divisions: 112,
                        label: '${controller.videoMaxPx} px',
                        onChanged: (v) =>
                            controller.updateVideoMaxPx(v.round()),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.music, size: 22),
                    title: Text(l10n.audioMaxPx),
                    subtitle: Text('${controller.audioMaxPx} px'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.audioMaxPx.toDouble(),
                        min: 80,
                        max: 1200,
                        divisions: 112,
                        label: '${controller.audioMaxPx} px',
                        onChanged: (v) =>
                            controller.updateAudioMaxPx(v.round()),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.file, size: 22),
                    title: Text(l10n.fileMaxPx),
                    subtitle: Text('${controller.fileMaxPx} px'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.fileMaxPx.toDouble(),
                        min: 80,
                        max: 1200,
                        divisions: 112,
                        label: '${controller.fileMaxPx} px',
                        onChanged: (v) => controller.updateFileMaxPx(v.round()),
                      ),
                    ),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.mapPin, size: 22),
                    title: Text(l10n.locationMaxPx),
                    subtitle: Text('${controller.locationMaxPx} px'),
                    trailing: SizedBox(
                      width: 160,
                      child: Slider(
                        value: controller.locationMaxPx.toDouble(),
                        min: 80,
                        max: 1200,
                        divisions: 112,
                        label: '${controller.locationMaxPx} px',
                        onChanged: (v) =>
                            controller.updateLocationMaxPx(v.round()),
                      ),
                    ),
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
