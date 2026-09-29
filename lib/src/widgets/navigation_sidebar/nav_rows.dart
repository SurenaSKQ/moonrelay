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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_widgets.dart';
import 'package:provider/provider.dart';

class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return InkWell(
      onTap: onTap,
      child: Container(
        color:
            selected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
        padding: EdgeInsets.symmetric(
            horizontal: t.spaceMd, vertical: t.spaceSm),
        child: Row(
          children: [
            Icon(
              icon,
              size: t.iconSizeSmall,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SpaceRow extends StatelessWidget {
  const SpaceRow({
    super.key,
    required this.space,
    required this.selected,
    required this.theme,
    this.onTap,
  });

  final Room space;
  final bool selected;
  final ThemeData theme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    return NavRowShell(
      selected: selected,
      onTap: onTap,
      child: Row(
        children: [
          SpaceAvatar(space: space, theme: theme),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              space.getLocalizedDisplayname(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                color: selected ? scheme.primary : scheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

class GroupRow extends StatelessWidget {
  const GroupRow({
    super.key,
    required this.gid,
    required this.expanded,
    required this.count,
    required this.scheme,
    required this.onTap,
    required this.onDragEnd,
  });

  final String gid;
  final bool expanded;
  final int count;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: t.spaceMd, vertical: t.spaceSm),
        child: Row(
          children: [
            Icon(LucideIcons.folder, size: 18, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Group',
                style: const TextStyle(fontSize: 13),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant.withValues(alpha: t.opacityDisabled),
                  borderRadius: BorderRadius.circular(t.radiusSm),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                      fontSize: 11, color: scheme.onSurfaceVariant),
                ),
              ),
            Icon(
              expanded ? LucideIcons.chevronDown : LucideIcons.chevronRight,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
    if (expanded) return row;
    return DraggableIcon(
      data: gid,
      feedback: DragFeedback(theme: Theme.of(context), label: 'Group', uri: null),
      ghost: Opacity(opacity: 0.3, child: row),
      onDragEnd: onDragEnd,
      child: row,
    );
  }
}

class NavRowShell extends StatelessWidget {
  const NavRowShell({
    super.key,
    required this.selected,
    required this.child,
    this.onTap,
  });

  final bool selected;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(t.radiusSm),
      child: Container(
        decoration: BoxDecoration(
          color:
              selected ? scheme.primaryContainer.withValues(alpha: 0.35) : null,
          borderRadius: BorderRadius.circular(t.radiusSm),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: child,
      ),
    );
  }
}

class SpaceAvatar extends StatelessWidget {
  const SpaceAvatar({
    super.key,required this.space, required this.theme});

  final Room space;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final t = theme.moonrelay.tokens;
    final uri = space.avatar;
    final label = space.getLocalizedDisplayname();
    if (uri == null) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: scheme.onSurfaceVariant.withValues(alpha: t.opacityFocus),
        child: Text(
          initials(label),
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: scheme.onSurfaceVariant,
          ),
        ),
      );
    }
    final client = Provider.of<Client>(context, listen: false);
    return FutureBuilder<Uri>(
      future: withTimeoutOrFallback(
        () => uri.getThumbnailUri(client,
            method: ThumbnailMethod.scale, width: 28, height: 28),
        timeout: kDefaultTimeout,
        fallback: uri,
      ),
      builder: (context, snap) => snap.hasData
          ? CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(snap.data.toString(),
                  headers: {'authorization': 'Bearer ${client.accessToken}'}),
              onBackgroundImageError: (_, __) {},
            )
          : CircleAvatar(
              radius: 14,
              backgroundColor: scheme.onSurfaceVariant.withValues(alpha: t.opacityFocus),
              child: Text(
                initials(label),
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
    );
  }
}

class NavListRow extends StatelessWidget {
  const NavListRow(this.icon, this.label, {super.key});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Row(
        children: [Icon(icon, size: 18), SizedBox(width: t.spaceMd), Text(label)]);
  }
}

/// Returns the initials from [name], suitable for avatar fallbacks.
String initials(String name) {
  if (name.isEmpty) return '#';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name[0].toUpperCase();
}
