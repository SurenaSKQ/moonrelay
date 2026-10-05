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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/sidebar_row.dart';
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
    return SidebarRow(
      title: label,
      selected: selected,
      onTap: onTap,
      leading: Icon(
        icon,
        size: t.iconSizeSmall,
        color: selected ? scheme.primary : scheme.onSurfaceVariant,
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
    return SidebarRow(
      title: space.getLocalizedDisplayname(),
      selected: selected,
      onTap: onTap,
      leading: SpaceAvatar(space: space, theme: theme),
    );
  }
}

/// `GroupRow` used to live here and was deleted with the sidebar's space list.
///
/// The rail's group header is [RailGroupHeader] in `rail_group_header.dart`,
/// and it is not a variant of this row: a 72px column cannot hold a title, a
/// count badge, and a chevron on one line, so the header reorders them around
/// a folder glyph and the count becomes the only text in the rail. Keeping a
/// full-width sidebar row around "in case" is how the previous pass ended up
/// describing a group box as still being drawn when nothing drew it.
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
  const SpaceAvatar({super.key, required this.space, required this.theme});

  final Room space;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final scheme = theme.colorScheme;
    final t = theme.moonrelay.tokens;
    final uri = space.avatar;
    final label = space.getLocalizedDisplayname();
    // Derived from the same metrics [SidebarRow] uses for its leading slot,
    // rather than a hard-coded radius 14. At the compact density a 14px
    // radius is 28px across inside a 22px slot, which overflows.
    final radius = sidebarMetricsFor(context).leadingSize / 2;
    if (uri == null) {
      return CircleAvatar(
        radius: radius,
        backgroundColor:
            scheme.onSurfaceVariant.withValues(alpha: t.opacityFocus),
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
            method: ThumbnailMethod.scale,
            width: radius * 2,
            height: radius * 2),
        timeout: kDefaultTimeout,
        fallback: uri,
      ),
      builder: (context, snap) => snap.hasData
          ? CircleAvatar(
              radius: radius,
              backgroundImage: NetworkImage(snap.data.toString(),
                  headers: {'authorization': 'Bearer ${client.accessToken}'}),
              onBackgroundImageError: (_, __) {},
            )
          : CircleAvatar(
              radius: radius,
              backgroundColor: scheme.onSurfaceVariant
                  .withValues(alpha: t.opacityFocus),
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

/// Returns the initials from [name], suitable for avatar fallbacks.
String initials(String name) {
  if (name.isEmpty) return '#';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length >= 2) {
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
  return name[0].toUpperCase();
}
