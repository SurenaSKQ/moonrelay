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
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_members_view.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/friend_chats_pane.dart';
import 'package:moonrelay/src/widgets/navigation_pane.dart';
import 'package:moonrelay/src/widgets/permanent_pane_bottom_items.dart';
import 'package:moonrelay/src/widgets/rooms_pane.dart';
import 'package:moonrelay/src/widgets/spaces_pane.dart';
import 'package:moonrelay/src/widgets/encryption/incoming_verification_listener.dart';
import 'package:moonrelay/src/widgets/encryption/post_login_setup_checker.dart';

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
///
/// The **right sidebar** content is driven by [RightPaneChoice] and reads the
/// currently-active room from [CurrentRoom].
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
                  child: PostLoginSetupChecker(
                    child: IncomingVerificationListener(
                      child: widget.child,
                    ),
                  ),
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
                    body: _ConsumerWrappedRightPane(
                        choice: settings.rightPaneChoice),
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
}

/// Wraps the right-pane content inside a [Consumer<CurrentRoom>] so that it
/// rebuilds whenever the active room changes, even when the intermediate
/// [SettingsController] consumer doesn't fire.
class _ConsumerWrappedRightPane extends StatelessWidget {
  const _ConsumerWrappedRightPane({required this.choice});

  final RightPaneChoice choice;

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrentRoom>(
      builder: (context, currentRoom, _) {
        // Delegate to the existing builder — the Consumer ensures we
        // rebuild on every CurrentRoom notification.
        return _buildPaneForChoice(context, choice);
      },
    );
  }

  Widget _buildPaneForChoice(BuildContext context, RightPaneChoice choice) {
    switch (choice) {
      case RightPaneChoice.none:
        return const SizedBox.shrink();
      case RightPaneChoice.roomInfo:
        return _RoomInfoRightSidebar();
      case RightPaneChoice.members:
        return _MembersRightSidebar();
    }
  }
}

// ─── Right sidebar content widgets ───────────────────────────────────────────

/// Shows a concise room-information panel in the right sidebar.
///
/// Reads the current room from [CurrentRoom].  When no room is active a
/// placeholder message is shown.
class _RoomInfoRightSidebar extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final currentRoom = context.watch<CurrentRoom>();
    final room = currentRoom.room;

    if (room == null) {
      return _emptyPlaceholder(
        context,
        LucideIcons.arrowRightFromLine,
        AppLocalizations.of(context)!.selectCategory,
      );
    }

    return _buildRoomInfo(context, room);
  }

  Widget _buildRoomInfo(BuildContext context, Room room) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final displayName = room.getLocalizedDisplayname();
    final topic = room.topic.isNotEmpty ? room.topic : l10n.noTopicSet;
    final memberCount = (room.summary.mJoinedMemberCount ?? 0) +
        (room.summary.mInvitedMemberCount ?? 0);
    final roomType = room.isDirectChat
        ? l10n.directMessage
        : room.isSpace
            ? l10n.spaceType
            : room.joinRules == JoinRules.public
                ? l10n.publicRoom
                : l10n.privateRoom;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Room avatar + name
          Center(
            child: Column(
              children: [
                AvatarFromUriOrFallbackImage(
                  client: room.client,
                  avatarUri: room.avatar,
                  radius: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  displayName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: scheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Topic
          _InfoRow(
            icon: LucideIcons.alignLeft,
            label: topic,
            scheme: scheme,
          ),
          const SizedBox(height: 8),

          // Room type
          _InfoRow(
            icon: LucideIcons.hash,
            label: roomType,
            scheme: scheme,
          ),
          const SizedBox(height: 8),

          // Room ID
          _InfoRow(
            icon: LucideIcons.tag,
            label: room.id,
            scheme: scheme,
            mono: true,
          ),
          const SizedBox(height: 8),

          // Member count
          _InfoRow(
            icon: LucideIcons.users,
            label: l10n.membersCount(memberCount),
            scheme: scheme,
          ),
          if (room.canonicalAlias.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoRow(
              icon: LucideIcons.atSign,
              label: room.canonicalAlias,
              scheme: scheme,
              mono: true,
            ),
          ],

          const SizedBox(height: 24),

          // Encryption status
          _StatusCard(
            icon: room.encrypted
                ? LucideIcons.shieldCheck
                : LucideIcons.shieldOff,
            label: room.encrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
            color: room.encrypted ? scheme.primary : scheme.error,
            scheme: scheme,
          ),
        ],
      ),
    );
  }

  Widget _emptyPlaceholder(
    BuildContext context,
    IconData icon,
    String message,
  ) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 40, color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A single key-value row in the room-info sidebar.
class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.scheme,
    this.mono = false,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface,
              fontFamily: mono ? 'JetBrainsMono' : null,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// A small card that highlights a status (e.g. encryption state).
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final Color color;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the full room-members list in the right sidebar.
///
/// Reads the current room from [CurrentRoom].  When no room is active a
/// placeholder is shown.
class _MembersRightSidebar extends StatelessWidget {
  const _MembersRightSidebar();

  @override
  Widget build(BuildContext context) {
    final currentRoom = context.watch<CurrentRoom>();
    final room = currentRoom.room;

    if (room == null) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.arrowRightFromLine,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.selectCategory,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // The FullRoomMembersList normally comes with its own Scaffold and
    // AppBar.  For the sidebar we strip those and render only the body.
    return _MembersListWrapper(room: room);
  }
}

/// Wraps [FullRoomMembersList] inside a sidebar-friendly layout that
/// hides the outer Scaffold/AppBar.
class _MembersListWrapper extends StatelessWidget {
  const _MembersListWrapper({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    // FullRoomMembersList is designed as a standalone page with Scaffold.
    // We reuse its logic by sharing the same implementation pattern here.
    return Column(
      children: [
        // Inline search bar
        Expanded(
          child: FullRoomMembersList(room: room),
        ),
      ],
    );
  }
}

// ─── Internal dashboard-layout widgets ───────────────────────────────────────

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
