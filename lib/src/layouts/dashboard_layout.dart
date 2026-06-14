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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/friend_chats_pane.dart';
import 'package:moonrelay/src/widgets/permanent_pane_bottom_items.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/spaces_pane.dart';

/// A flexible multi-pane layout that replaces the old rigid TwoColumnLayout.
///
/// Uses [LayoutBuilder] to adapt to available space:
/// - **Wide** (>= 1000px): left sidebar + content + optional right sidebar
/// - **Medium** (>= 700px): left sidebar + content, right sidebar hidden
/// - **Narrow** (< 700px):  content only, sidebars accessible via overlay
///
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
  // Local drag state for resize handles (clamped against settings when persisted).
  double? _leftWidth;
  double? _rightWidth;

  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, settings, _) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final double availableWidth = constraints.maxWidth;
            final bool isWide = availableWidth >= 1000;
            final bool isMedium = availableWidth >= 700;

            final bool showLeft = settings.leftSidebarVisible;
            final bool showRight = settings.rightSidebarVisible && isWide;

            final ThemeData theme = Theme.of(context);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Left sidebar ──────────────────────────────────────
                if (showLeft)
                  _SidebarPane(
                    width: _leftWidth ?? settings.leftSidebarWidth,
                    minWidth: 200,
                    header: _SidebarHeader(
                      title: settings.leftPaneChoice.label,
                      onToggle: () => settings.toggleLeftSidebar(),
                    ),
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
                    header: _SidebarHeader(
                      title: settings.rightPaneChoice.label,
                      onToggle: () => settings.toggleRightSidebar(),
                    ),
                    body: _buildRightPane(settings.rightPaneChoice),
                    bottomBar: null,
                    theme: theme,
                  ),

                // ── Medium-screen floating toggle for right sidebar ───
                if (isMedium && !isWide && settings.rightSidebarVisible)
                  // This case is handled by hiding the right sidebar in medium mode.
                  // A floating action could be added here later.
                  const SizedBox.shrink(),
              ],
            );
          },
        );
      },
    );
  }

  /// Build the left pane widget based on the user's choice.
  Widget _buildLeftPane(LeftPaneChoice choice) {
    switch (choice) {
      case LeftPaneChoice.rooms:
        return const RoomsPane();
      case LeftPaneChoice.spaces:
        return const SpacesPane();
      case LeftPaneChoice.friends:
        return const FriendsChatsPane();
      case LeftPaneChoice.none:
        return const SizedBox.shrink();
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
            style: TextStyle(fontFamily: 'Rubik'),
          ),
        );
      case RightPaneChoice.members:
        // TODO: Wire up members panel when implemented
        return const Center(
          child: Text(
            'Members',
            style: TextStyle(fontFamily: 'Rubik'),
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
  final Widget header;
  final Widget body;
  final Widget? bottomBar;
  final ThemeData theme;

  const _SidebarPane({
    required this.width,
    required this.minWidth,
    required this.header,
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
          header,
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

/// A small header row for a sidebar, with a title and a collapse button.
class _SidebarHeader extends StatelessWidget {
  final String title;
  final VoidCallback onToggle;

  const _SidebarHeader({
    required this.title,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontFamily: 'Rubik',
                fontWeight: FontWeight.w600,
                fontSize: 13,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 28,
            height: 28,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              icon: Icon(LucideIcons.chevronLeft),
              onPressed: onToggle,
              tooltip: 'Toggle sidebar',
            ),
          ),
        ],
      ),
    );
  }
}
