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
import 'package:provider/provider.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';

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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
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
              const SizedBox(height: 4),
              Text(
                l10n.timelineAndMessages,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              HubSettingsSection(
                title: l10n.stateEventsSection,
                children: [
                  SwitchListTile(
                    title: Text(l10n.showStateEvents),
                    subtitle: Text(
                      l10n.showStateEventsDescription,
                    ),
                    value: controller.showStateEvents,
                    onChanged: (v) => controller.updateShowStateEvents(v),
                    secondary: const Icon(Icons.info_outline),
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
