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
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// One child room of a space, in the space's settings list.
///
/// Carries a room id rather than a [Room] because a space can name a child the
/// local client has never fetched, which is exactly the case where a settings
/// page has to say something useful: it falls back to the id and marks itself
/// as unresolved rather than rendering an empty row.
class SpaceChildRoomRow extends StatelessWidget {
  const SpaceChildRoomRow({
    super.key,
    required this.roomId,
    required this.room,
    required this.suggested,
    required this.canEdit,
    required this.onRemove,
  });

  final String roomId;
  final Room? room;
  final bool suggested;
  final bool canEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = MoonrelayThemeExtension.of(context);
    final t = theme.tokens;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final resolved = room != null;
    final isSpace = room?.isSpace ?? false;
    final name = room?.getLocalizedDisplayname() ?? roomId;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceLg,
        vertical: t.spaceSm,
      ),
      child: Row(
        children: [
          // A glyph rather than an avatar: a child the user cannot open has no
          // avatar, and an empty circle would read as a failed image.
          Container(
            width: t.iconSizeLarge,
            height: t.iconSizeLarge,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.surfaceContainerHigh,
            ),
            child: Icon(
              isSpace ? LucideIcons.folder : LucideIcons.hash,
              size: t.iconSizeSmall,
              color: resolved ? scheme.onSurfaceVariant : scheme.outline,
            ),
          ),
          SizedBox(width: t.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    // Dimmed rather than hidden: the row is a real membership,
                    // and pretending otherwise would understate what leaving
                    // this space would do.
                    color: resolved ? scheme.onSurface : scheme.outline,
                  ),
                ),
                if (!resolved || suggested) ...[
                  SizedBox(height: t.spaceXxs),
                  Text(
                    !resolved ? l10n.roomNotAvailable : l10n.suggested,
                    style: TextStyle(
                      fontSize: 12,
                      color: !resolved
                          ? scheme.outline
                          : scheme.tertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (canEdit)
            IconButton(
              icon: Icon(
                LucideIcons.x,
                size: t.iconSizeMedium,
                color: scheme.error,
              ),
              tooltip: l10n.removeRoomFromSpace,
              onPressed: onRemove,
            ),
        ],
      ),
    );
  }
}

/// A joined room that could be added to a space, with an add affordance.
class AvailableRoomRow extends StatelessWidget {
  const AvailableRoomRow({super.key, required this.room, required this.onAdd});

  final Room room;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceLg,
        vertical: t.spaceXs,
      ),
      child: Row(
        children: [
          SizedBox(
            width: t.iconSizeLarge,
            height: t.iconSizeLarge,
            child: Icon(
              LucideIcons.hash,
              size: t.iconSizeMedium,
              color: scheme.onSurfaceVariant,
            ),
          ),
          SizedBox(width: t.spaceMd),
          Expanded(
            child: Text(
              room.getLocalizedDisplayname(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
            ),
          ),
          IconButton(
            icon: Icon(
              LucideIcons.plus,
              size: t.iconSizeMedium,
              color: scheme.primary,
            ),
            tooltip: l10n.addRoomToSpace,
            onPressed: onAdd,
          ),
        ],
      ),
    );
  }
}