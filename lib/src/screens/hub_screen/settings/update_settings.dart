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
import 'package:url_launcher/url_launcher.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_controls.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';
import 'package:moonrelay/src/services/auto_update_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// Update settings page: manual check + startup preference

class HubUpdateSettings extends StatelessWidget {
  const HubUpdateSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        return HubPageBody(
          children: [
            // Two settings, so two groups. They used to be one group cut in
            // half by a `Divider(height: 1)` with no colour, which made the
            // second grey in the app: every other rule in a card is
            // `layers.hairline`.
            HubSettingsSection(
              title: l10n.checkForUpdatesOnStartup,
              children: [
                HubSwitchTile(
                  icon: LucideIcons.rocket,
                  title: l10n.checkForUpdatesOnStartup,
                  description: l10n.checkForUpdatesOnStartupDescription,
                  value: controller.checkForUpdates,
                  onChanged: (v) => controller.updateCheckForUpdates(v),
                ),
              ],
            ),
            HubSettingsSection(
              title: l10n.updates,
              children: [
                HubActionTile(
                  icon: LucideIcons.download,
                  title: l10n.checkForUpdates,
                  description: l10n.updateChecking,
                  onTap: () => _checkNow(context),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Future<void> _checkNow(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final service = context.read<AutoUpdateService>();
    final scaffold = ScaffoldMessenger.of(context);

    // Show a snackbar while checking.
    scaffold.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: t.spaceMd),
            Text(l10n.updateChecking),
          ],
        ),
        duration: const Duration(seconds: 30),
      ),
    );

    final result = await service.check();

    scaffold.hideCurrentSnackBar();

    if (!context.mounted) return;

    if (!result.available) {
      scaffold.showSnackBar(
        SnackBar(
          content: Text(l10n.updateUpToDate(result.currentVersion)),
        ),
      );
      return;
    }

    _showUpdateDialog(context, result);
  }
}

// -- Update-available dialog -------------------------------------------------

void _showUpdateDialog(
  BuildContext context,
  UpdateCheckResult result,
) {
  final l10n = AppLocalizations.of(context)!;
  final t = MoonrelayThemeExtension.of(context).tokens;

  showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: Row(
        children: [
          Icon(
            LucideIcons.download,
            color: Theme.of(ctx).colorScheme.primary,
            size: t.iconSizeLarge,
          ),
          const SizedBox(width: 10),
          Text(l10n.updateAvailable),
        ],
      ),
      content: Text(
        l10n.updateAvailableBody(result.latestVersion, result.currentVersion),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l10n.updateLater),
        ),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(ctx);
            _openDownloadUrl(context, result.releaseUrl);
          },
          icon: Icon(LucideIcons.externalLink, size: t.iconSizeSmall),
          label: Text(l10n.updateDownload),
        ),
      ],
    ),
  );
}

Future<void> _openDownloadUrl(BuildContext context, String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  } else {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppLocalizations.of(context)!.updateCheckFailed,
        ),
      ),
    );
  }
}
