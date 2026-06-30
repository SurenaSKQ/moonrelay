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
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Network Settings
// ─────────────────────────────────────────────────────────────────────────────

class HubNetworkSettings extends StatelessWidget {
  const HubNetworkSettings({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final scheme = Theme.of(context).colorScheme;
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.network,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.networkDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              HubSettingsSection(
                title: l10n.statusBarSection,
                children: [
                  SwitchListTile(
                    title: Text(l10n.showStatusBar),
                    subtitle: Text(
                      l10n.showStatusBarDescription,
                    ),
                    value: controller.showStatusBar,
                    onChanged: (v) => controller.updateShowStatusBar(v),
                    secondary: const Icon(LucideIcons.activity, size: 22),
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
