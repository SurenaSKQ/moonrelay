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

/// Media / cache / auto-download storage settings.
class HubStorageSettings extends StatelessWidget {
  const HubStorageSettings({super.key});

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
                l10n.storage,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              SizedBox(height: t.spaceXs),
              Text(
                l10n.storageDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              SizedBox(height: t.spaceXl),
              HubSettingsSection(
                title: l10n.autoDownloadImages,
                children: [
                  _PolicyPicker(
                    title: l10n.autoDownloadImages,
                    current: controller.autoDownloadImages,
                    onChanged: controller.updateAutoDownloadImages,
                  ),
                  _PolicyPicker(
                    title: l10n.autoDownloadFiles,
                    current: controller.autoDownloadFiles,
                    onChanged: controller.updateAutoDownloadFiles,
                  ),
                  _PolicyPicker(
                    title: l10n.autoDownloadVideos,
                    current: controller.autoDownloadVideos,
                    onChanged: controller.updateAutoDownloadVideos,
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),
              HubSettingsSection(
                title: l10n.attachmentClickThreshold,
                children: [
                  ListTile(
                    leading:
                        const Icon(LucideIcons.mousePointerClick, size: 22),
                    title: Text(l10n.attachmentClickThresholdMb),
                    subtitle:
                        Text('${controller.attachmentClickThresholdMb} MB'),
                    trailing: SizedBox(
                      width: 200,
                      child: Slider(
                        value: controller.attachmentClickThresholdMb.toDouble(),
                        min: 1,
                        max: 200,
                        divisions: 199,
                        label: '${controller.attachmentClickThresholdMb} MB',
                        onChanged: (v) => controller
                            .updateAttachmentClickThresholdMb(v.round()),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: t.spaceLg),
              HubSettingsSection(
                title: l10n.drafts,
                children: [
                  SwitchListTile(
                    title: Text(l10n.draftsEnabled),
                    subtitle: Text(l10n.draftsEnabledDescription),
                    value: controller.draftsEnabled,
                    onChanged: (v) => controller.updateDraftsEnabled(v),
                    secondary: const Icon(LucideIcons.fileText, size: 22),
                  ),
                  ListTile(
                    leading: const Icon(LucideIcons.clock, size: 22),
                    enabled: controller.draftsEnabled,
                    title: Text(l10n.draftRetentionDays),
                    subtitle: Text('${controller.draftRetentionDays}'),
                    trailing: SizedBox(
                      width: 200,
                      child: Slider(
                        value: controller.draftRetentionDays.toDouble(),
                        min: 0,
                        max: 90,
                        divisions: 90,
                        label: '${controller.draftRetentionDays}',
                        onChanged: controller.draftsEnabled
                            ? (v) =>
                                controller.updateDraftRetentionDays(v.round())
                            : null,
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

class _PolicyPicker extends StatelessWidget {
  const _PolicyPicker({
    required this.title,
    required this.current,
    required this.onChanged,
  });

  final String title;
  final AutoDownloadPolicy current;
  final ValueChanged<AutoDownloadPolicy> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceLg,
        vertical: t.spaceSm,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleSmall),
          SizedBox(height: t.spaceSm),
          Wrap(
            spacing: 8,
            children: [
              for (final policy in AutoDownloadPolicy.values)
                ChoiceChip(
                  label: Text(localizedAutoDownloadPolicy(policy, l10n)),
                  selected: policy == current,
                  onSelected: (_) => onChanged(policy),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
