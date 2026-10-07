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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/helpers/log_service.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_controls.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';

// Advanced Settings

/// Debounces, timeouts and the logging policy.
///
/// Every number here is an integer the slider exposes as a double, and this
/// page used to carry its own copy of the slider row to do that conversion,
/// at a third track width of 200px. The shared row takes the same `double` and
/// does the rounding at the call site, so the conversion is written once
/// instead of fourteen times.
class HubAdvancedSettings extends StatelessWidget {
  const HubAdvancedSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        return HubPageBody(
          children: [
            // -- Debounce ----------------------------------------------------
            HubSettingsSection(
              title: l10n.debounceTimings,
              children: [
                HubSliderTile(
                  icon: LucideIcons.refreshCw,
                  title: l10n.syncDebounceMs,
                  value: controller.syncDebounceMs,
                  valueLabel: '${controller.syncDebounceMs} ms',
                  min: 0,
                  max: 5000,
                  divisions: 100,
                  onChanged: (double v) =>
                      controller.updateSyncDebounceMs(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.search,
                  title: l10n.searchDebounceMs,
                  value: controller.searchDebounceMs,
                  valueLabel: '${controller.searchDebounceMs} ms',
                  min: 0,
                  max: 5000,
                  divisions: 100,
                  onChanged: (double v) =>
                      controller.updateSearchDebounceMs(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.fileText,
                  title: l10n.draftAutosaveMs,
                  value: controller.draftAutosaveMs,
                  valueLabel: '${controller.draftAutosaveMs} ms',
                  min: 0,
                  max: 5000,
                  divisions: 100,
                  onChanged: (double v) =>
                      controller.updateDraftAutosaveMs(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.bell,
                  title: l10n.notificationPersistMs,
                  value: controller.notificationPersistMs,
                  valueLabel: '${controller.notificationPersistMs} ms',
                  min: 0,
                  max: 5000,
                  divisions: 100,
                  onChanged: (double v) =>
                      controller.updateNotificationPersistMs(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.link,
                  title: l10n.deepLinkDedupMs,
                  value: controller.deepLinkDedupMs,
                  valueLabel: '${controller.deepLinkDedupMs} ms',
                  min: 0,
                  max: 10000,
                  divisions: 200,
                  onChanged: (double v) =>
                      controller.updateDeepLinkDedupMs(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.shield,
                  title: l10n.encryptionRefreshDebounceMs,
                  value: controller.encryptionRefreshDebounceMs,
                  valueLabel: '${controller.encryptionRefreshDebounceMs} ms',
                  min: 0,
                  max: 5000,
                  divisions: 100,
                  onChanged: (double v) =>
                      controller.updateEncryptionRefreshDebounceMs(v.round()),
                ),
              ],
            ),

            // -- Timeouts -----------------------------------------------------
            HubSettingsSection(
              title: l10n.timeoutsAndLimits,
              children: [
                HubSliderTile(
                  icon: LucideIcons.timer,
                  title: l10n.firstSyncTimeoutS,
                  value: controller.firstSyncTimeoutS,
                  valueLabel: '${controller.firstSyncTimeoutS} s',
                  min: 1,
                  max: 60,
                  divisions: 59,
                  onChanged: (double v) =>
                      controller.updateFirstSyncTimeoutS(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.search,
                  title: l10n.searchPageSize,
                  value: controller.searchPageSize,
                  valueLabel: '${controller.searchPageSize}',
                  min: 10,
                  max: 500,
                  divisions: 49,
                  onChanged: (double v) =>
                      controller.updateSearchPageSize(v.round()),
                ),
                HubSliderTile(
                  icon: LucideIcons.bell,
                  title: l10n.notificationDedupeCacheSize,
                  value: controller.notificationDedupeCacheSize,
                  valueLabel: '${controller.notificationDedupeCacheSize}',
                  min: 0,
                  max: 5000,
                  divisions: 50,
                  onChanged: (double v) =>
                      controller.updateNotificationDedupeCacheSize(v.round()),
                ),
              ],
            ),

            // -- Logs -------------------------------------------------------------
            HubSettingsSection(
              title: l10n.logs,
              children: [
                HubNavTile(
                  icon: LucideIcons.layers,
                  title: l10n.logLevel,
                  value: localizedLogLevel(controller.logLevel, l10n),
                  onTap: () => _pickLogLevel(context, controller, l10n),
                ),
                HubSliderTile(
                  icon: LucideIcons.hardDrive,
                  title: l10n.logMaxFileSizeMb,
                  value: controller.logMaxFileSizeMb,
                  valueLabel: '${controller.logMaxFileSizeMb} MB',
                  min: 1,
                  max: 256,
                  divisions: 255,
                  onChanged: (double v) => _updateLogs(
                    context,
                    controller,
                    (SettingsController c) =>
                        c.updateLogMaxFileSizeMb(v.round()),
                  ),
                ),
                HubSliderTile(
                  icon: LucideIcons.files,
                  title: l10n.logMaxFiles,
                  value: controller.logMaxFiles,
                  valueLabel: '${controller.logMaxFiles}',
                  min: 0,
                  max: 50,
                  divisions: 50,
                  onChanged: (double v) => _updateLogs(
                    context,
                    controller,
                    (SettingsController c) => c.updateLogMaxFiles(v.round()),
                  ),
                ),
                HubSliderTile(
                  icon: LucideIcons.timer,
                  title: l10n.logFlushDelayS,
                  value: controller.logFlushDelayS,
                  valueLabel: '${controller.logFlushDelayS} s',
                  min: 1,
                  max: 600,
                  divisions: 60,
                  onChanged: (double v) => _updateLogs(
                    context,
                    controller,
                    (SettingsController c) => c.updateLogFlushDelayS(v.round()),
                  ),
                ),
                HubSwitchTile(
                  icon: LucideIcons.alertTriangle,
                  title: l10n.logVerboseRelease,
                  description: l10n.logVerboseReleaseDescription,
                  value: controller.logVerboseRelease,
                  onChanged: (v) => controller.updateLogVerboseRelease(v),
                ),
              ],
            ),
          ],
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
                    ? const Icon(LucideIcons.check)
                    : null,
                onTap: () => Navigator.of(ctx).pop(level),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    if (!context.mounted) return;
    _updateLogs(
      context,
      controller,
      (SettingsController c) => c.updateLogLevel(selected),
    );
  }

  /// Persists a logging setting and then pushes the whole policy into the
  /// live sink.
  ///
  /// The four logging controls share one sink, so they are applied as a
  /// set rather than individually: `LogService.reconfigure` rebuilds the
  /// output, and doing that four times for one user action would churn
  /// the file handle for nothing. [mutate] persists first, so the
  /// controller is authoritative by the time the policy is read back.
  ///
  /// The apply is unawaited on purpose. It is a file-handle swap with no
  /// user-visible result, and blocking the slider on it would make
  /// dragging feel sticky. A failure is logged inside `LogService` rather
  /// than surfaced, because the old sink keeps working in that case.
  static void _updateLogs(
    BuildContext context,
    SettingsController controller,
    Future<void> Function(SettingsController) mutate,
  ) {
    // Resolve the service before any await: the read has to happen in the
    // frame the tap arrived in, and holding a `BuildContext` across the
    // persist would trip `use_build_context_synchronously`.
    final logService = context.read<LogService>();
    unawaited(() async {
      await mutate(controller);
      await logService.applyPolicy(
        maxFileSizeMb: controller.logMaxFileSizeMb,
        maxRotatedFiles: controller.logMaxFiles,
        flushDelaySeconds: controller.logFlushDelayS,
        level: controller.logLevel,
      );
    }());
  }
}
