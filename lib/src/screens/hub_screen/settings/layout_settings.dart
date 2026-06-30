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
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/settings_section.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Layout Settings
// ─────────────────────────────────────────────────────────────────────────────

class HubLayoutSettings extends StatelessWidget {
  const HubLayoutSettings({super.key});

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
                l10n.layout,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.customizeLayout,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Left sidebar
              HubSettingsSection(
                title: l10n.leftSidebar,
                children: [
                  SwitchListTile(
                    title: Text(l10n.visible),
                    subtitle: Text(
                      l10n.showOrHideLeftSidebar,
                    ),
                    value: controller.leftSidebarVisible,
                    onChanged: (v) => controller.setLeftSidebarVisible(v),
                    secondary: const Icon(LucideIcons.panelLeft),
                  ),
                  if (controller.leftSidebarVisible) ...[
                    ListTile(
                      title: Text(l10n.widthLabel),
                      subtitle: Text(
                        '${controller.leftSidebarWidth.round()} px',
                      ),
                      leading: const Icon(LucideIcons.moveHorizontal),
                      trailing: SizedBox(
                        width: 160,
                        child: Slider(
                          value: controller.leftSidebarWidth,
                          min: 200,
                          max: 600,
                          divisions: 16,
                          label: '${controller.leftSidebarWidth.round()}',
                          onChanged: (v) => controller.setLeftSidebarWidth(v),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Right sidebar
              HubSettingsSection(
                title: 'Right sidebar (experimental)',
                children: [
                  SwitchListTile(
                    title: const Text('Visible'),
                    subtitle: const Text(
                      'Show or hide the right sidebar (hidden on medium screens)',
                    ),
                    value: controller.rightSidebarVisible,
                    onChanged: (v) => controller.setRightSidebarVisible(v),
                    secondary: const Icon(LucideIcons.panelRight),
                  ),
                  if (controller.rightSidebarVisible) ...[
                    ListTile(
                      title: Text(l10n.content),
                      subtitle: Text(
                        localizedRightPaneChoice(
                            controller.rightPaneChoice, l10n),
                      ),
                      leading: const Icon(LucideIcons.layoutList),
                      trailing: DropdownButton<RightPaneChoice>(
                        value: controller.rightPaneChoice,
                        onChanged: (v) {
                          if (v != null) {
                            controller.setRightPaneChoice(v);
                          }
                        },
                        items: RightPaneChoice.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child:
                                    Text(localizedRightPaneChoice(c, l10n)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ListTile(
                      title: Text(l10n.widthLabel),
                      subtitle: Text(
                        '${controller.rightSidebarWidth.round()} px',
                      ),
                      leading: const Icon(LucideIcons.moveHorizontal),
                      trailing: SizedBox(
                        width: 160,
                        child: Slider(
                          value: controller.rightSidebarWidth,
                          min: 200,
                          max: 500,
                          divisions: 12,
                          label: '${controller.rightSidebarWidth.round()}',
                          onChanged: (v) => controller.setRightSidebarWidth(v),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Header
              HubSettingsSection(
                title: 'Header',
                children: [
                  SwitchListTile(
                    title: const Text('Reversed header'),
                    subtitle: const Text(
                      'Window buttons on the left, title on the right',
                    ),
                    value: controller.headerReversed,
                    onChanged: (v) => controller.updateHeaderReversed(v),
                    secondary: const Icon(LucideIcons.arrowLeftRight),
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
