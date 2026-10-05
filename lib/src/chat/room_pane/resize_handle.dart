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

// The drag handle between the conversation and its side pane.

import 'package:flutter/material.dart';

/// A draggable divider between the conversation and the room's side pane.
///
/// Reports a delta rather than an absolute position, so the caller decides what
/// the width means and can clamp it. The pane's owner keeps the dragged width
/// as ephemeral state and only writes it to preferences when the drag ends, which
/// is why this does not know about `SettingsController`.
///
/// Was in `pane_hosts.dart` next to `SidebarPane` and `RightPaneHost`, both of
/// which described a pane that belonged to the dashboard rather than to a room.
class ResizeHandle extends StatelessWidget {
  const ResizeHandle({super.key, required this.onDrag, this.onDragEnd});

  /// Horizontal movement since the last call, positive to the right.
  final void Function(double delta) onDrag;

  final VoidCallback? onDragEnd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (DragUpdateDetails details) =>
            onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: SizedBox(
          width: 8,
          // Transparent rather than absent: the 8 pixels are the target, and a
          // zero-width handle is a handle you cannot grab.
          child: Center(
            child: SizedBox(
              width: 1,
              height: double.infinity,
              child: ColoredBox(color: scheme.outlineVariant),
            ),
          ),
        ),
      ),
    );
  }
}
