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
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';
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

/// The drop highlight for a draggable space or group.
///
/// A border rather than a fill alone, because in the icon rail the only
/// thing that changes during a drag is the tile itself: a fill the same size
/// as the icon reads as the icon changing colour, while a ring reads as
/// "something is being aimed at here".
///
/// [margin] is a parameter because the rail and the room list want different
/// insets around the same target. The old hardcoded 4 was the sidebar row's
/// inset and there is no reason for it to also be the rail icon's.
class SpaceDragTarget extends StatelessWidget {
  const SpaceDragTarget({
    super.key,
    required this.id,
    required this.hover,
    required this.onEnter,
    required this.onLeave,
    required this.onDrop,
    required this.child,
    this.margin = const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
  });

  final String id;
  final bool hover;
  final bool Function(String) onEnter;
  final VoidCallback onLeave;
  final void Function(String) onDrop;
  final Widget child;

  /// Inset around [child], so the hover ring is not flush against the
  /// neighbouring tile.
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final motion = Motion.of(context);
    return DragTarget<String>(
      onWillAcceptWithDetails: (d) => onEnter(d.data),
      onLeave: (_) => onLeave(),
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, _, __) => AnimatedContainer(
        duration: motion.duration(t.durationFast),
        curve: motion.curve(t.curveStandard),
        decoration: hover
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(t.radiusMd),
                border: Border.all(color: scheme.primary, width: 2.5),
                color: scheme.primary.withValues(alpha: t.opacityFocus),
              )
            : null,
        margin: margin,
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

