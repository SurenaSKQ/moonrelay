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

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({
    super.key,
    required this.account,
    required this.isActive,
    required this.onTap,
  });

  final StoredAccount account;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = MoonrelayThemeExtension.of(context);
    final colors = theme.colorScheme;
    final t = ext.tokens;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.only(bottom: t.spaceSm),
      child: Material(
        // The row has to be a `Material` and not a decorated `Container` with an
        // `InkWell` outside it, which is what it was. An `InkWell` paints its
        // splash on the nearest `Material` ancestor, which here was the Scaffold
        // above the panel, so the ripple drew over the row's own fill instead of
        // under it: pressing a saved account showed a wash floating above it.
        color: isActive
            ? colors.primary.withValues(alpha: ext.tokens.opacityFocus)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(t.radiusMd),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(t.radiusMd),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: t.spaceMd,
              vertical: t.spaceSm + t.spaceXxs,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusMd),
              // An active row is marked by its fill and its check, not by a
              // border. A 38%-alpha hairline around a row is the weakest possible
              // way to say "this is the one you are using".
              border: Border.all(
                color: isActive ? ext.layers.active : colors.outlineVariant,
                width: t.borderWidthMedium,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: t.iconSizeMedium - t.spaceXs,
                  backgroundColor: isActive
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  child: Text(
                    _initial(account.userId),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: isActive
                          ? colors.onPrimaryContainer
                          : colors.onSurfaceVariant,
                    ),
                  ),
                ),
                SizedBox(width: t.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        account.userId,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.3,
                          fontWeight: FontWeight.w500,
                          color: colors.onSurface,
                        ),
                      ),
                      // The homeserver is an identifier, so it is set in the mono
                      // face and a long host name ellipsises rather than pushing
                      // the row's trailing affordance off the panel.
                      Text(
                        account.homeserver,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: MoonrelayTypography.mono(context),
                          fontSize: 12,
                          height: 1.3,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(width: t.spaceSm),
                if (isActive)
                  // The accent, not `Colors.green`. A raw named colour here was
                  // the only place in this segment that stepped outside the
                  // ramp, and it is a checkmark rather than a status, so it does
                  // not need a status colour of its own.
                  Icon(
                    LucideIcons.circleCheck,
                    size: t.iconSizeMedium,
                    color: colors.primary,
                  )
                else
                  Text(
                    l10n.tapToSwitch,
                    style: TextStyle(
                      fontSize: 12,
                      color: colors.primary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The avatar's letter, from a Matrix user id.
  ///
  /// Tolerant of the shapes that used to throw: an empty localpart, an id with
  /// no `@`, and one that is nothing but `@`. The old expression was
  /// `replaceAll('@','').substring(0, 1).toUpperCase()`, which is a crash on a
  /// stored account whose id is `@:example.org`.
  static String _initial(String userId) {
    final String localpart =
        userId.startsWith('@') ? userId.substring(1) : userId;
    final int colon = localpart.indexOf(':');
    final String name = colon > 0 ? localpart.substring(0, colon) : localpart;
    if (name.isEmpty) return '?';
    return name.substring(0, 1).toUpperCase();
  }
}
