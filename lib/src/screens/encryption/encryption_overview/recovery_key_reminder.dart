// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

class RecoveryKeyReminderCard extends StatelessWidget {
  const RecoveryKeyReminderCard({
    super.key,
    required this.onDismiss,
    required this.loc,
    required this.scheme,
  });

  final Future<void> Function() onDismiss;
  final AppLocalizations loc;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Card(
      elevation: t.elevationNone,
      color: scheme.tertiaryContainer.withValues(alpha: t.opacityDisabled),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
        side: BorderSide(color: scheme.tertiary.withValues(alpha: 0.3)),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  LucideIcons.keyRound,
                  color: scheme.tertiary,
                  size: 22,
                ),
                SizedBox(width: t.spaceMd),
                Expanded(
                  child: Text(
                    loc.encryptionRecoveryKeyReminderTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            SizedBox(height: t.spaceSm),
            Text(
              loc.encryptionRecoveryKeyReminderBody,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
            SizedBox(height: t.spaceMd),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonalIcon(
                icon: Icon(LucideIcons.check, size: t.iconSizeSmall),
                onPressed: () {
                  // ignore: discarded_futures
                  onDismiss();
                },
                label: Text(loc.encryptionRecoveryKeyReminderAck),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
