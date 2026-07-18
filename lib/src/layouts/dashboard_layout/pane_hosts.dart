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
import 'package:provider/provider.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/navigation_pane.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/space_rooms_tree.dart';
import 'package:moonrelay/src/widgets/spaces_pane.dart';

import 'right_sidebar_content.dart';

// --- Resize handle ---------------------------------------------------------

/// A draggable resize handle between panes.
class ResizeHandle extends StatelessWidget {
  final void Function(double delta) onDrag;
  final VoidCallback? onDragEnd;

  const ResizeHandle({
    super.key,
    required this.onDrag,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Wider hit target (8px) so the handle is easier to grab on small panes,
    // with a subtle always-visible track.
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: Container(
          width: 8,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: 1,
            color: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

// --- Sidebar pane ----------------------------------------------------------

/// A sidebar pane with a header, scrollable body, and optional bottom bar.
class SidebarPane extends StatelessWidget {
  final double width;
  final double minWidth;
  final String title;
  final Widget body;
  final Widget? bottomBar;
  final ThemeData theme;

  const SidebarPane({
    super.key,
    required this.width,
    required this.minWidth,
    required this.title,
    required this.body,
    this.bottomBar,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width.clamp(minWidth, double.infinity),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Simple header bar  collapse toggle lives in AppFrame now.
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          Expanded(child: body),
          if (bottomBar != null) ...[
            const Divider(height: 1),
            bottomBar!,
          ],
        ],
      ),
    );
  }
}

// --- Left pane content factory ---------------------------------------------

/// Builds the body of the left pane based on the user's [LeftPaneChoice] and
/// the current [NavigationState].
Widget buildLeftPaneContent(BuildContext context, LeftPaneChoice choice) {
  switch (choice) {
    case LeftPaneChoice.rooms:
      return Consumer<NavigationState>(
        builder: (context, nav, _) {
          final Client? client;
          try {
            client = Provider.of<Client>(context, listen: false);
          } catch (_) {
            // Client may be absent during logout transition; show
            // nothing until the route changes away from the dashboard.
            return const SizedBox.shrink();
          }
          if (nav.isSpace) {
            final Room? space = client.getRoomById(nav.selectedId);
            if (space != null) {
              return SpaceRoomsPane(space: space, client: client);
            }
          }

          return RoomsPane(roomFilter: (Room room) {
            if (nav.isAll) return !room.isSpace;
            if (nav.isHome) return room.isDirectChat;
            return true;
          });
        },
      );
    case LeftPaneChoice.spaces:
      return const SpacesPane();
    case LeftPaneChoice.friends:
      // DMs only  the same list shown on the Home navigation destination.
      return RoomsPane(roomFilter: (Room room) => room.isDirectChat);
    case LeftPaneChoice.none:
      return const SizedBox.shrink();
  }
}

// --- Left pane host --------------------------------------------------------

/// Hosts the left side pane (navigation rail + room list) when the layout has
/// room for a pinned sidebar.
///
/// The drag width is observed via [ListenableBuilder] so resize updates don't
/// rebuild the entire dashboard tree.
class LeftPaneHost extends StatelessWidget {
  const LeftPaneHost({
    super.key,
    required this.widthNotifier,
    required this.onResize,
    required this.onResizeEnd,
    required this.theme,
  });

  final ValueNotifier<double?> widthNotifier;
  final void Function(double) onResize;
  final VoidCallback onResizeEnd;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Row(
      textDirection: TextDirection.ltr,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const NavigationPane(),
        ResizeHandle(
          onDrag: onResize,
          onDragEnd: onResizeEnd,
        ),
        ListenableBuilder(
          listenable: widthNotifier,
          builder: (context, _) {
            return SidebarPane(
              width: widthNotifier.value ?? settings.leftSidebarWidth,
              minWidth: LayoutBreakpoints.minSidebarWidth,
              title: settings.leftPaneChoice.label,
              body: buildLeftPaneContent(context, settings.leftPaneChoice),
              bottomBar: null,
              theme: theme,
            );
          },
        ),
      ],
    );
  }
}

// --- Right pane host -------------------------------------------------------

/// Hosts the right side pane (room info, members, threads, pinned).
class RightPaneHost extends StatelessWidget {
  const RightPaneHost({
    super.key,
    required this.widthNotifier,
    required this.theme,
  });

  final ValueNotifier<double?> widthNotifier;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return ListenableBuilder(
      listenable: widthNotifier,
      builder: (context, _) {
        return SidebarPane(
          width: widthNotifier.value ?? settings.rightSidebarWidth,
          minWidth: LayoutBreakpoints.minSidebarWidth,
          title: '',
          body: const RightSidebarContent(),
          bottomBar: null,
          theme: theme,
        );
      },
    );
  }
}
