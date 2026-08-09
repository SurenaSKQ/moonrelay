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

/// Debounces, timeouts, and logging settings.
class HubAdvancedSettings extends StatelessWidget {
  const HubAdvancedSettings({super.key});

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
                l10n.advanced,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.advancedDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              HubSettingsSection(
                title: l10n.debounceTimings,
                children: [
                  _SliderTile(
                    icon: LucideIcons.refreshCw,
                    title: l10n.syncDebounceMs,
                    value: controller.syncDebounceMs,
                    min: 0,
                    max: 5000,
                    divisions: 100,
                    onChanged: controller.updateSyncDebounceMs,
                  ),
                  _SliderTile(
                    icon: LucideIcons.search,
                    title: l10n.searchDebounceMs,
                    value: controller.searchDebounceMs,
                    min: 0,
                    max: 5000,
                    divisions: 100,
                    onChanged: controller.updateSearchDebounceMs,
                  ),
                  _SliderTile(
                    icon: LucideIcons.fileText,
                    title: l10n.draftAutosaveMs,
                    value: controller.draftAutosaveMs,
                    min: 0,
                    max: 5000,
                    divisions: 100,
                    onChanged: controller.updateDraftAutosaveMs,
                  ),
                  _SliderTile(
                    icon: LucideIcons.bell,
                    title: l10n.notificationPersistMs,
                    value: controller.notificationPersistMs,
                    min: 0,
                    max: 5000,
                    divisions: 100,
                    onChanged: controller.updateNotificationPersistMs,
                  ),
                  _SliderTile(
                    icon: LucideIcons.link,
                    title: l10n.deepLinkDedupMs,
                    value: controller.deepLinkDedupMs,
                    min: 0,
                    max: 10000,
                    divisions: 200,
                    onChanged: controller.updateDeepLinkDedupMs,
                  ),
                  _SliderTile(
                    icon: LucideIcons.shield,
                    title: l10n.encryptionRefreshDebounceMs,
                    value: controller.encryptionRefreshDebounceMs,
                    min: 0,
                    max: 5000,
                    divisions: 100,
                    onChanged: controller.updateEncryptionRefreshDebounceMs,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              HubSettingsSection(
                title: l10n.timeoutsAndLimits,
                children: [
                  _SliderTile(
                    icon: LucideIcons.timer,
                    title: l10n.firstSyncTimeoutS,
                    unit: 's',
                    value: controller.firstSyncTimeoutS,
                    min: 1,
                    max: 60,
                    divisions: 59,
                    onChanged: controller.updateFirstSyncTimeoutS,
                  ),
                  _SliderTile(
                    icon: LucideIcons.search,
                    title: l10n.searchPageSize,
                    value: controller.searchPageSize,
                    min: 10,
                    max: 500,
                    divisions: 49,
                    onChanged: controller.updateSearchPageSize,
                  ),
                  _SliderTile(
                    icon: LucideIcons.bell,
                    title: l10n.notificationDedupeCacheSize,
                    value: controller.notificationDedupeCacheSize,
                    min: 0,
                    max: 5000,
                    divisions: 50,
                    onChanged: controller.updateNotificationDedupeCacheSize,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              HubSettingsSection(
                title: l10n.logs,
                children: [
                  ListTile(
                    leading: const Icon(LucideIcons.layers, size: 22),
                    title: Text(l10n.logLevel),
                    subtitle:
                        Text(localizedLogLevel(controller.logLevel, l10n)),
                    onTap: () => _pickLogLevel(context, controller, l10n),
                    trailing: const Icon(LucideIcons.chevronRight, size: 18),
                  ),
                  _SliderTile(
                    icon: LucideIcons.hardDrive,
                    title: l10n.logMaxFileSizeMb,
                    unit: ' MB',
                    value: controller.logMaxFileSizeMb,
                    min: 1,
                    max: 256,
                    divisions: 255,
                    onChanged: controller.updateLogMaxFileSizeMb,
                  ),
                  _SliderTile(
                    icon: LucideIcons.files,
                    title: l10n.logMaxFiles,
                    value: controller.logMaxFiles,
                    min: 0,
                    max: 50,
                    divisions: 50,
                    onChanged: controller.updateLogMaxFiles,
                  ),
                  _SliderTile(
                    icon: LucideIcons.timer,
                    title: l10n.logFlushDelayS,
                    unit: 's',
                    value: controller.logFlushDelayS,
                    min: 1,
                    max: 600,
                    divisions: 60,
                    onChanged: controller.updateLogFlushDelayS,
                  ),
                  SwitchListTile(
                    title: Text(l10n.logVerboseRelease),
                    subtitle: Text(l10n.logVerboseReleaseDescription),
                    value: controller.logVerboseRelease,
                    onChanged: (v) => controller.updateLogVerboseRelease(v),
                    secondary: const Icon(LucideIcons.alertTriangle, size: 22),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickLogLevel(
    BuildContext context,
    SettingsController controller,
    AppLocalizations l10n,
  ) async {
    final selected = await showModalBottomSheet<LogLevel>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final level in LogLevel.values)
              ListTile(
                title: Text(localizedLogLevel(level, l10n)),
                trailing: level == controller.logLevel
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop(level),
              ),
          ],
        ),
      ),
    );
    if (selected != null) await controller.updateLogLevel(selected);
  }
}

class _SliderTile extends StatelessWidget {
  const _SliderTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.onChanged,
    this.unit = ' ms',
  });

  final IconData icon;
  final String title;
  final int value;
  final int min;
  final int max;
  final int divisions;
  final ValueChanged<int> onChanged;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, size: 22),
      title: Text(title),
      subtitle: Text('$value$unit'),
      trailing: SizedBox(
        width: 200,
        child: Slider(
          value: value.toDouble().clamp(min.toDouble(), max.toDouble()),
          min: min.toDouble(),
          max: max.toDouble(),
          divisions: divisions,
          label: '$value$unit',
          onChanged: (v) => onChanged(v.round()),
        ),
      ),
    );
  }
}
