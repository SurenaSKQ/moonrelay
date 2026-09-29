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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

class NavSectionHeader extends StatelessWidget {
  const NavSectionHeader({
    super.key,
    required this.label,
    required this.collapsed,
    required this.onTap,
  });

  final String label;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return InkWell(
      onTap: onTap,
      child: Container(
        color: scheme.surfaceContainerHighest,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              collapsed
                  ? (isRtl ? LucideIcons.chevronsLeft : LucideIcons.chevronsRight)
                  : LucideIcons.chevronDown,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class DraggableIcon extends StatelessWidget {
  const DraggableIcon({
    super.key,
    required this.data,
    required this.feedback,
    required this.ghost,
    required this.child,
    this.onDragEnd,
  });

  final String data;
  final Widget feedback, ghost, child;
  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) => Draggable<String>(
        data: data,
        feedback: feedback,
        childWhenDragging: ghost,
        onDragEnd: onDragEnd != null ? (_) => onDragEnd!() : null,
        child: child,
      );
}

class SpaceDragTarget extends StatelessWidget {
  const SpaceDragTarget({
    super.key,
    required this.id,
    required this.hover,
    required this.onEnter,
    required this.onLeave,
    required this.onDrop,
    required this.child,
  });

  final String id;
  final bool hover;
  final bool Function(String) onEnter;
  final VoidCallback onLeave;
  final void Function(String) onDrop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => onEnter(d.data),
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, _, __) => AnimatedContainer(
        duration: t.durationFast,
        decoration: hover
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusMd),
                border: Border.all(color: scheme.primary, width: 2.5),
                color: scheme.primary.withValues(alpha: t.opacityFocus),
              )
            : null,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: child,
      ),
    );
  }
}

class DragFeedback extends StatelessWidget {
  const DragFeedback({
    super.key,required this.theme, required this.label, this.uri});

  final ThemeData theme;
  final String label;
  final Uri? uri;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Material(
        color: Colors.transparent,
        child: Card(
          elevation: t.elevationHigh,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (uri != null)
                  CircleAvatar(
                    radius: 12,
                    backgroundImage: NetworkImage(
                      uri.toString(),
                      headers: {
                        'authorization':
                            'Bearer ${Provider.of<Client>(context, listen: false).accessToken}',
                      },
                    ),
                    onBackgroundImageError: (_, __) {},
                  )
                else
                  const Icon(LucideIcons.folder, size: 22),
                SizedBox(width: t.spaceSm),
                Text(label),
              ],
            ),
          ),
        ),
      );
  }
}
