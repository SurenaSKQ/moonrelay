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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/layouts/dashboard_layout/right_sidebar_content.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Presents the room's detail panes as a modal bottom sheet.
///
/// The dashboard puts these four panes in its right sidebar. The
/// single-pane shell has no right sidebar, so the same panes were simply
/// absent from it, and pinned messages in particular were unreachable
/// below 600px because the one control that opened them lived in the room
/// header's width-gated badge block.
///
/// The sheet hosts [RightSidebarWithSwitcher] unchanged rather than a
/// purpose-built mobile variant, so the switcher, the pane bodies and the
/// `RightPaneChoice` preference are one implementation in both shells. The
/// pane bodies are pane-shaped already: they are scrollable columns with a
/// header, which is what a sheet wants. Re-implementing them for a second
/// presentation is how the compact sidebar ended up a worse product.
///
/// Wrapped in a [LayoutScope] because two of the bodies measure themselves
/// against it (`SidebarRoomInfo` picks its pinned-preview column count from
/// `availableWidth`, and picks 3 when it reads infinity). A bottom sheet
/// spans the window, so its width is a real width and worth reporting.
Future<void> showRoomPaneSheet(
  BuildContext context, {
  required Room room,
}) {
  final t = MoonrelayThemeExtension.of(context).tokens;
  return showModalBottomSheet(
    context: context,
    // Taller than the Material default of 9/16: the member and thread lists
    // are the point of the sheet and are useless in a third of the screen.
    constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
    builder: (BuildContext sheetContext) {
      return LayoutScope(
        size: LayoutSize.compact,
        availableWidth: MediaQuery.sizeOf(sheetContext).width,
        child: Padding(
          // Keep the pane bodies off the bottom system inset, which the
          // sheet already pads for but the body's own scroll view does not.
          padding: EdgeInsets.only(bottom: t.spaceXs),
          child: RightSidebarWithSwitcher(
            key: ValueKey('sheet_${room.id}'),
            room: room,
          ),
        ),
      );
    },
  );
}