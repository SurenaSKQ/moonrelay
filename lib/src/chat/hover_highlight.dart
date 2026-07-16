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

/// Wraps a chat item and applies a subtle background tint when the mouse
/// hovers over it, plus a stronger flash when [isHighlighted] is true
/// (triggered by a reply jump-to).
///
/// When hovered and [actions] is non-null, the actions widget is rendered
/// at the top-right corner of the highlight region as an inline hoverbar
/// (no overlay, no geometry tracking).
///
/// Uses [ColorScheme.surfaceContainerHighest] tones that adapt cleanly
/// to both light and dark themes.
class HoverHighlight extends StatefulWidget {
  const HoverHighlight({
    super.key,
    required this.isHighlighted,
    required this.child,
    this.actions,
  });

  final bool isHighlighted;
  final Widget child;

  /// Optional inline hoverbar (e.g. [MessageActions]) shown at the
  /// top-right of the highlight when the cursor is over this item.
  final Widget? actions;

  @override
  State<HoverHighlight> createState() => _HoverHighlightState();
}

class _HoverHighlightState extends State<HoverHighlight> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bgColor;
    if (widget.isHighlighted) {
      bgColor = cs.primary.withValues(alpha: 0.15);
    } else if (_isHovered) {
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.5);
    } else {
      bgColor = Colors.transparent;
    }

    final showActions = _isHovered && widget.actions != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: bgColor,
        ),
        // Always use a Stack so the child subtree stays stable across
        // hover toggles (the Stack's first child never unmounts).
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            widget.child,
            if (showActions)
              Positioned(
                top: 4,
                right: 8,
                child: widget.actions!,
              ),
          ],
        ),
      ),
    );
  }
}
