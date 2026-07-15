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
/// Uses [ColorScheme.surfaceContainerHighest] tones that adapt cleanly
/// to both light and dark themes.
class HoverHighlight extends StatefulWidget {
  const HoverHighlight({
    super.key,
    required this.isHighlighted,
    required this.child,
  });

  final bool isHighlighted;
  final Widget child;

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

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: bgColor,
        ),
        child: widget.child,
      ),
    );
  }
}
