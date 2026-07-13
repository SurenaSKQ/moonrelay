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
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// A Material 3 room header bar that reactively displays the room's name,
/// topic, avatar, and member count.
///
/// Listens to room state changes so that the topic and name stay in sync
/// without requiring a manual rebuild. When the topic is missing or fails to
/// load a friendly placeholder is shown instead.
///
/// Tap behaviour depends on the right-sidebar configuration:
/// - If the right sidebar is **enabled and set to "Room Info"**, tapping
///   opens the sidebar (or does nothing if already open).
/// - Otherwise, tapping navigates to the full [RoomInformations] page.
class ChatRoomHeader extends StatefulWidget {
  const ChatRoomHeader({
    super.key,
    required this.room,
    this.onSearchToggle,
    this.isSearchActive = false,
  });

  final Room room;

  /// Called when the user taps the search button.
  final VoidCallback? onSearchToggle;

  /// Whether the in-room search panel is currently visible.
  final bool isSearchActive;

  @override
  State<ChatRoomHeader> createState() => _ChatRoomHeaderState();
}

class _ChatRoomHeaderState extends State<ChatRoomHeader> {
  late String _displayName;
  late String _topic;
  late int _memberCount;

  @override
  void initState() {
    super.initState();
    _syncRoomState();
  }

  @override
  void didUpdateWidget(ChatRoomHeader oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _syncRoomState();
    }
  }

  /// Copies the current room values into local state so the build is fast
  /// and we can override them gracefully if needed.
  void _syncRoomState() {
    _displayName = widget.room.getLocalizedDisplayname();
    _topic = widget.room.topic;
    _memberCount = (widget.room.summary.mInvitedMemberCount ?? 0) +
        (widget.room.summary.mJoinedMemberCount ?? 0);
  }

  /// React to a tap on the room header.
  ///
  /// *If* the right sidebar is enabled *and* its pane choice is
  /// [`RightPaneChoice.roomInfo`] we toggle the sidebar instead of
  /// navigating to the full-info page.  Otherwise the old push-navigation
  /// behaviour is retained.
  void _onTap() {
    final settings = context.read<SettingsController>();

    if (settings.rightSidebarVisible &&
        settings.rightPaneChoice == RightPaneChoice.roomInfo) {
      // Sidebar is already open and on room_info → no-op.
      // Otherwise (sidebar hidden, or on different pane) → open it.
      return;
    }

    // Fall back to full-page navigation.
    _openRoomInfo();
  }

  /// Navigate to the room info page via go_router.
  void _openRoomInfo() {
    context.push('/main/rooms/${widget.room.id}/profile/roomDetails');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return StreamBuilder<Object>(
      stream: widget.room.client.onRoomState.stream
          .where((event) => event.roomId == widget.room.id),
      builder: (context, snapshot) {
        // Re-read room state whenever the stream fires.
        _syncRoomState();

        final displayName =
            _displayName.isNotEmpty ? _displayName : widget.room.id;
        final topic = _topic.isNotEmpty
            ? _topic
            : AppLocalizations.of(context)!.noTopicSet;

        // Adapt the header to the available width:
        // - Very narrow panes drop badges and the topic line to keep the
        //   title and toolbar reachable.
        // - Narrow panes drop the topic and shrink the avatar.
        final width = MediaQuery.sizeOf(context).width;
        final compactHeader = width < 480;
        final showTopic = !compactHeader;
        final showBadges = width >= 600;
        final avatarRadius = compactHeader ? 16.0 : 20.0;
        final nameFontSize = compactHeader ? 14.0 : 16.0;
        final hPadding = compactHeader ? 8.0 : 12.0;

        return GestureDetector(
          onTap: _onTap,
          child: Container(
            padding: EdgeInsets.symmetric(
                horizontal: hPadding, vertical: compactHeader ? 6 : 8),
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              border: Border(
                bottom: BorderSide(
                  color: scheme.outlineVariant.withValues(alpha: 0.5),
                ),
              ),
            ),
            child: Row(
              children: [
                // Room avatar
                AvatarFromUriOrFallbackImage(
                  client: widget.room.client,
                  avatarUri: widget.room.avatar,
                  radius: avatarRadius,
                ),
                SizedBox(width: compactHeader ? 8 : 12),

                // Name + Topic
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showTopic) ...[
                        const SizedBox(height: 2),
                        Text(
                          topic,
                          style: TextStyle(
                            fontSize: 13,
                            color: scheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                SizedBox(width: compactHeader ? 4 : 8),

                if (showBadges) ...[
                  // Sync status indicator
                  _SyncIndicator(client: widget.room.client),
                  const SizedBox(width: 4),

                  // Member count badge
                  _MemberCountBadge(count: _memberCount, scheme: scheme),
                  const SizedBox(width: 4),

                  // Pinned messages toggle
                  _PinnedFilterButton(room: widget.room),
                  const SizedBox(width: 4),
                ],

                // In-room search toggle
                IconButton(
                  icon: Icon(
                    widget.isSearchActive
                        ? LucideIcons.searchX
                        : LucideIcons.search,
                    size: compactHeader ? 16 : 18,
                  ),
                  onPressed: widget.onSearchToggle,
                  tooltip: AppLocalizations.of(context)!.searchInRoom,
                  visualDensity: compactHeader
                      ? VisualDensity(horizontal: -2, vertical: -2)
                      : VisualDensity.compact,
                  color: widget.isSearchActive
                      ? scheme.primary
                      : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),

                // Settings gear  navigate to room settings
                IconButton(
                  icon: Icon(
                    LucideIcons.settings,
                    size: compactHeader ? 16 : 18,
                  ),
                  onPressed: () =>
                      context.push('/main/rooms/${widget.room.id}/settings'),
                  tooltip: AppLocalizations.of(context)!.roomSettings,
                  visualDensity: compactHeader
                      ? VisualDensity(horizontal: -2, vertical: -2)
                      : VisualDensity.compact,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),

                // Chevron indicating tappable
                Icon(
                  Icons.chevron_right_rounded,
                  size: compactHeader ? 16 : 20,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// A small badge that shows a (• Syncing) indicator while the Matrix sync is
/// in progress (waiting for response, processing, or cleaning up).
///
/// Hides automatically when the sync reaches the [SyncStatus.finished] state.
class _SyncIndicator extends StatelessWidget {
  const _SyncIndicator({required this.client});

  final Client client;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return StreamBuilder<SyncStatusUpdate>(
      stream: client.onSyncStatus.stream,
      builder: (context, snapshot) {
        final status = snapshot.data?.status;
        final isSyncing = status != null && status != SyncStatus.finished;

        if (!isSyncing) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '\u2022', // bullet character
                style: TextStyle(
                  fontSize: 14,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                l10n.statusSyncing,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: scheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A small badge showing the number of room members.
class _MemberCountBadge extends StatelessWidget {
  const _MemberCountBadge({
    required this.count,
    required this.scheme,
  });

  final int count;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.people_rounded,
            size: 14,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// A toggle button that filters the timeline to show only pinned messages.
///
/// Shows an active (filled) style when the pinned filter is on and an
/// inactive (outlined) style when off, so the user knows they can tap
/// again to return to the full timeline.
class _PinnedFilterButton extends StatelessWidget {
  const _PinnedFilterButton({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentRoom = context.watch<CurrentRoom>();
    final isActive = currentRoom.pinnedFilterActive;
    final hasPinned = currentRoom.pinnedEventIds.isNotEmpty;

    // Only show the button if there are pinned messages or the filter
    // is already active.
    if (!hasPinned && !isActive) return const SizedBox.shrink();

    return IconButton(
      icon: Icon(
        isActive ? Icons.push_pin : Icons.push_pin_outlined,
        size: 18,
      ),
      onPressed: () => currentRoom.togglePinnedFilter(),
      tooltip: isActive
          ? AppLocalizations.of(context)!.showPinnedOnly
          : AppLocalizations.of(context)!.showAllMessages,
      visualDensity: VisualDensity.compact,
      style: IconButton.styleFrom(
        backgroundColor:
            isActive ? scheme.primaryContainer : Colors.transparent,
        foregroundColor:
            isActive ? scheme.onPrimaryContainer : scheme.onSurfaceVariant.withValues(alpha: 0.6),
      ),
    );
  }
}
