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

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// -----------------------------------------------------------------------------
// App Settings overview (when the category itself is selected)
// -----------------------------------------------------------------------------

class HubAppSettingsOverview extends StatelessWidget {
  final List<HubNavigationItem> items;
  final void Function(int index) onItemTap;

  const HubAppSettingsOverview({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = theme.moonrelay.tokens;
    return ListView(
      padding: EdgeInsets.all(t.spaceXl),
      children: [
        Text(
          l10n.appSettings,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.customizeExperience,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return Card(
            elevation: t.elevationNone,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(t.radiusMd),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: ListTile(
              leading: Icon(item.icon, size: t.iconSizeLarge),
              title: Text(
                item.label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: Icon(LucideIcons.chevronRight, size: t.iconSizeMedium),
              onTap: () => onItemTap(index),
            ),
          );
        }),
      ],
    );
  }
}
