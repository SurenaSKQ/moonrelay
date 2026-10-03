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
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
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
    // Section headers were a hard-coded 12pt that ignored the density
    // setting entirely, so the labels sat at a fixed size between rows that
    // moved. They are the pane's wayfinding, so they get the same setting
    // as the rows they head, one step below them rather than a constant.
    //
    // Uppercase and tracked out, at a smaller size than the rows. It reads as
    // a caption on the list rather than as another entry in it, which is the
    // whole job: the room rows are the content and this is the label for a
    // run of them.
    final density = context.select<SettingsController, LayoutDensity>(
      (s) => s.density,
    );
    final comfortable = density == LayoutDensity.comfortable;
    final labelSize = comfortable ? 12.0 : 11.0;
    return Container(
      // No fill. This used to be a lighter band, which on the restated ramp is
      // a full step above the pane and read as a section *divider* rather than
      // as a caption on the list. The mockup's category is text alone, and it
      // is right: one plane with a label in it is easier to scan than a stack
      // of bands, and the rows' own hover and selection are the only fills the
      // list needs.
      color: Colors.transparent,
      padding: EdgeInsets.symmetric(
        horizontal: comfortable ? 14 : 12,
        vertical: comfortable ? 8 : 5,
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: labelSize,
                  letterSpacing: 0.5,
                  color: scheme.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          InkWell(
            onTap: onTap,
            child: Icon(
              collapsed
                  ? (isRtl ? LucideIcons.chevronsLeft : LucideIcons.chevronRight)
                  : LucideIcons.chevronDown,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
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
