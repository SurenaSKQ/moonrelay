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
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/friend_chats_pane.dart';
import 'package:moonrelay/src/widgets/navigation_pane.dart';
import 'package:moonrelay/src/widgets/permanent_pane_bottom_items.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/spaces_pane.dart';

/// A flexible multi-pane layout that replaces the old rigid TwoColumnLayout.
///
/// Uses [LayoutBuilder] to adapt to available space:
/// - **Wide** (>= 1100px): nav pane + left sidebar + content + optional right sidebar
/// - **Medium** (>= 700px): nav pane + left sidebar + content
/// - **Narrow** (< 700px):  content only, sidebars accessible via overlay
///
/// The leftmost **nav pane** is a permanent narrow rail (Home / All / Spaces).
/// The **left sidebar** (rooms pane) is collapsible via the AppFrame header.
/// Sidebar visibility, width, and pane choice are driven by
/// [SettingsController] and persisted across sessions.
class DashboardLayout extends StatefulWidget {
  /// The main content widget (typically the route's child).
  final Widget child;

  const DashboardLayout({super.key, required this.child});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  // Local drag state for resize handles.
  double? _leftWidth;
  double? _rightWidth;

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, settings, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final bool isWide = constraints.maxWidth >= 1100;

            final bool showLeft = settings.leftSidebarVisible;
            final bool showRight = settings.rightSidebarVisible && isWide;

            final ThemeData theme = Theme.of(context);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Navigation pane (always visible) ─────────────────
                const NavigationPane(),

                // ── Left sidebar (rooms pane, collapsible) ───────────
                if (showLeft)
                  _SidebarPane(
                    width: _leftWidth ?? settings.leftSidebarWidth,
                    minWidth: 200,
                    title: settings.leftPaneChoice.label,
                    body: _buildLeftPane(settings.leftPaneChoice),
                    bottomBar: const PermanentPaneBottomItems(),
                    theme: theme,
                  ),

                if (showLeft)
                  _ResizeHandle(
                    onDrag: (double delta) {
                      setState(() {
                        _leftWidth =
                            (_leftWidth ?? settings.leftSidebarWidth) + delta;
                      });
                    },
                    onDragEnd: () {
                      if (_leftWidth != null) {
                        settings.setLeftSidebarWidth(_leftWidth!);
                        _leftWidth = null;
                      }
                    },
                  ),

                // ── Main content ──────────────────────────────────────
                Expanded(
                  child: widget.child,
                ),

                // ── Right sidebar ─────────────────────────────────────
                if (showRight)
                  _ResizeHandle(
                    onDrag: (double delta) {
                      setState(() {
                        _rightWidth =
                            (_rightWidth ?? settings.rightSidebarWidth) - delta;
                      });
                    },
                    onDragEnd: () {
                      if (_rightWidth != null) {
                        settings.setRightSidebarWidth(_rightWidth!);
                        _rightWidth = null;
                      }
                    },
                  ),

                if (showRight)
                  _SidebarPane(
                    width: _rightWidth ?? settings.rightSidebarWidth,
                    minWidth: 200,
                    title: settings.rightPaneChoice.label,
                    body: _buildRightPane(settings.rightPaneChoice),
                    bottomBar: null,
                    theme: theme,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  /// Build the left pane widget based on the user's choice,
  /// applying the current navigation filter.
  Widget _buildLeftPane(LeftPaneChoice choice) {
    switch (choice) {
      case LeftPaneChoice.rooms:
        return Consumer<NavigationState>(
          builder: (context, nav, _) {
            return RoomsPane(roomFilter: (Room room) {
              if (nav.isAll) return true;
              if (nav.isHome) return room.isDirectChat;
              if (nav.isSpace) {
                return _roomBelongsToSpace(context, room, nav.selectedId);
              }
              return true;
            });
          },
        );
      case LeftPaneChoice.spaces:
        return const SpacesPane();
      case LeftPaneChoice.friends:
        return const FriendsChatsPane();
      case LeftPaneChoice.none:
        return const SizedBox.shrink();
    }
  }

  /// Check whether [room] is a child of the space identified by [spaceId].
  bool _roomBelongsToSpace(BuildContext context, Room room, String spaceId) {
    try {
      final Client client = Provider.of<Client>(context, listen: false);
      final Room? space = client.getRoomById(spaceId);
      if (space == null) return false;
      final Set<String?> childIds =
          space.spaceChildren.map((c) => c.roomId).toSet();
      return childIds.contains(room.id);
    } catch (_) {
      return false;
    }
  }

  /// Build the right pane widget based on the user's choice.
  Widget _buildRightPane(RightPaneChoice choice) {
    switch (choice) {
      case RightPaneChoice.none:
        return const SizedBox.shrink();
      case RightPaneChoice.roomInfo:
        // TODO: Wire up room info panel when implemented
        return const Center(
          child: Text(
            'Room Info',
            style: TextStyle(),
          ),
        );
      case RightPaneChoice.members:
        // TODO: Wire up members panel when implemented
        return const Center(
          child: Text(
            'Members',
            style: TextStyle(),
          ),
        );
    }
  }
}

// ─── Internal widgets ───────────────────────────────────────────────────────

/// A draggable resize handle between panes.
class _ResizeHandle extends StatelessWidget {
  final void Function(double delta) onDrag;
  final VoidCallback? onDragEnd;

  const _ResizeHandle({
    required this.onDrag,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: Container(
          width: 6,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: 1,
            color: Theme.of(context).dividerColor,
          ),
        ),
      ),
    );
  }
}

/// A sidebar pane with a header, scrollable body, and optional bottom bar.
class _SidebarPane extends StatelessWidget {
  final double width;
  final double minWidth;
  final String title;
  final Widget body;
  final Widget? bottomBar;
  final ThemeData theme;

  const _SidebarPane({
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
          // Simple header bar — collapse toggle lives in AppFrame now.
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
