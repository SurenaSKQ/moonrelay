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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_members_view.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
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
                    title: '', // managed by the content itself
                    body: const _RightSidebarContent(),
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

// ─── Right sidebar: content with view switcher ──────────────────────────────

/// Manages the right sidebar content with a built-in dropdown to switch
/// between room-info and members views.
///
/// Reads the current pane choice from [SettingsController] and switches
/// the displayed content accordingly.
class _RightSidebarContent extends StatelessWidget {
  const _RightSidebarContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<CurrentRoom>(
      builder: (context, currentRoom, _) {
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

        return _RightSidebarWithSwitcher(room: room);
      },
    );
  }
}

/// The right sidebar body with a segmented/dropdown switcher at the top.
class _RightSidebarWithSwitcher extends StatelessWidget {
  const _RightSidebarWithSwitcher({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final choice = settings.rightPaneChoice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── View switcher header ──────────────────────────────────
        _RightSidebarHeader(
          currentChoice: choice,
          onChanged: (c) => settings.setRightPaneChoice(c),
        ),
        const Divider(height: 1),
        // ── Content ───────────────────────────────────────────────
        Expanded(
          child: switch (choice) {
            RightPaneChoice.none => const SizedBox.shrink(),
            RightPaneChoice.roomInfo => _SidebarRoomInfo(room: room),
            RightPaneChoice.members => _SidebarMembersList(room: room),
          },
        ),
      ],
    );
  }
}

/// A compact header bar with a dropdown to switch between room-info and
/// members views.
class _RightSidebarHeader extends StatelessWidget {
  const _RightSidebarHeader({
    required this.currentChoice,
    required this.onChanged,
  });

  final RightPaneChoice currentChoice;
  final void Function(RightPaneChoice) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Selected view icon
          Icon(
            currentChoice == RightPaneChoice.roomInfo
                ? LucideIcons.info
                : LucideIcons.users,
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          // Dropdown
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RightPaneChoice>(
                value: currentChoice,
                isDense: true,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
                items: [
                  DropdownMenuItem(
                    value: RightPaneChoice.roomInfo,
                    child: Text('Room Info'),
                  ),
                  DropdownMenuItem(
                    value: RightPaneChoice.members,
                    child: Text('Members'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Room Info sidebar content ───────────────────────────────────────────────

/// Shows a concise room-information panel in the right sidebar.
class _SidebarRoomInfo extends StatelessWidget {
  const _SidebarRoomInfo({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
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

// ─── Members list sidebar content (standalone, no Scaffold/AppBar) ───────────

/// A standalone members-list widget designed for the right sidebar.
///
/// Duplicates the progressive-loading logic from [FullRoomMembersList] but
/// without any Scaffold or AppBar — just a search bar and a scrollable list
/// of members.  This avoids the destructive back-button that would otherwise
/// appear when using [FullRoomMembersList] directly inside a sidebar.
class _SidebarMembersList extends StatefulWidget {
  const _SidebarMembersList({required this.room});

  final Room room;

  @override
  State<_SidebarMembersList> createState() => _SidebarMembersListState();
}

class _SidebarMembersListState extends State<_SidebarMembersList> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  static const int _batchSize = 50;
  static const int _fetchBatchSize = 10;

  List<User> _allMembers = [];
  int _displayedCount = 0;
  bool _isLoading = true;
  bool _isFetchingMore = false;
  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _fetchLocalThenRemote();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  void _onScroll() {
    if (_searchQuery.isNotEmpty) return;
    if (_displayedCount >= _allMembers.length) return;
    if (!_scrollController.hasClients) return;
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - 300) return;
    _loadNextBatch();
  }

  void _loadNextBatch() {
    if (_displayedCount >= _allMembers.length) return;
    setState(() {
      _displayedCount =
          (_displayedCount + _batchSize).clamp(0, _allMembers.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_displayedCount >= _allMembers.length) return;
      if (_searchQuery.isNotEmpty) return;
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <=
              _scrollController.position.viewportDimension + 1) {
        _loadNextBatch();
      }
    });
  }

  Future<void> _fetchLocalThenRemote() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _displayedCount = 0;
      _allMembers = [];
    });

    final localParticipants = widget.room.getParticipants().toList()
      ..sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));

    _allMembers = List.from(localParticipants);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _displayedCount = _allMembers.length > 0
            ? _batchSize.clamp(0, _allMembers.length)
            : 0;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_displayedCount < _allMembers.length) _loadNextBatch();
    });

    try {
      _isFetchingMore = true;
      final joinedMembers =
          await widget.room.client.getJoinedMembersByRoom(widget.room.id);
      if (!mounted || joinedMembers == null || joinedMembers.isEmpty) return;

      final existingIds = _allMembers.map((u) => u.id).toSet();
      final missingMxids =
          joinedMembers.keys.where((id) => !existingIds.contains(id)).toList();
      if (missingMxids.isEmpty) {
        if (mounted) setState(() => _isFetchingMore = false);
        return;
      }

      for (int i = 0; i < missingMxids.length; i += _fetchBatchSize) {
        final batch = missingMxids.sublist(
          i,
          (i + _fetchBatchSize).clamp(0, missingMxids.length),
        );
        final results = await Future.wait(
          batch.map((mxid) => _fetchUser(mxid, joinedMembers)),
        );
        if (!mounted) return;

        final newUsers = results.whereType<User>().where((u) {
          return !_allMembers.any((existing) => existing.id == u.id);
        }).toList();

        if (newUsers.isEmpty) continue;
        _allMembers.addAll(newUsers);
        _allMembers
            .sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));

        if (mounted) {
          setState(() {
            _displayedCount = (_displayedCount + newUsers.length)
                .clamp(0, _allMembers.length);
          });
        }
      }
    } catch (_) {
      // Silently swallow – local data is already shown.
    }
    if (mounted) setState(() => _isFetchingMore = false);
  }

  Future<User?> _fetchUser(
    String mxid,
    Map<String, RoomMember> joinedMembers,
  ) async {
    try {
      return await widget.room.requestUser(mxid);
    } catch (_) {
      final info = joinedMembers[mxid];
      if (info == null) return null;
      return User(
        mxid,
        room: widget.room,
        displayName: info.displayName,
        avatarUrl: info.avatarUrl?.toString(),
      );
    }
  }

  List<User> get _visibleMembers {
    if (_searchQuery.isNotEmpty) {
      return _allMembers.where((m) {
        final dn = m.calcDisplayname().toLowerCase();
        final uid = m.id.toLowerCase();
        return dn.contains(_searchQuery) || uid.contains(_searchQuery);
      }).toList();
    }
    return _allMembers.take(_displayedCount).toList();
  }

  bool get _hasMore =>
      _searchQuery.isEmpty && _displayedCount < _allMembers.length;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchMembers,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 16),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Expanded(
          child: _isLoading
              ? _buildLoading(scheme)
              : _loadError != null && _allMembers.isEmpty
                  ? _buildError(scheme)
                  : _buildList(scheme),
        ),
      ],
    );
  }

  Widget _buildLoading(ColorScheme scheme) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 12),
            Text(AppLocalizations.of(context)!.loading,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );

  Widget _buildError(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.alertCircle, size: 40, color: scheme.error),
          const SizedBox(height: 12),
          Text(l10n.couldNotLoadMessages,
              style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: _fetchLocalThenRemote,
            icon: const Icon(LucideIcons.refreshCw, size: 16),
            label: Text(l10n.retry),
          ),
        ],
      ),
    );
  }

  Widget _buildList(ColorScheme scheme) {
    final members = _visibleMembers;
    final l10n = AppLocalizations.of(context)!;

    if (members.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.users,
                size: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
            const SizedBox(height: 10),
            Text(
              _searchQuery.isNotEmpty
                  ? l10n.noMembersMatchSearch
                  : l10n.noMembersFound,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final showIndicator = _isFetchingMore || _hasMore;
    final itemCount = members.length + (showIndicator ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _fetchLocalThenRemote,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          if (index >= members.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: scheme.primary,
                  ),
                ),
              ),
            );
          }

          final member = members[index];
          final displayName = member.calcDisplayname();
          final permissionLabel = member.powerLevel.level >= 100
              ? l10n.adminBadge
              : member.powerLevel.level >= 50
                  ? l10n.moderatorBadge
                  : null;

          return _SidebarMemberTile(
            member: member,
            displayName: displayName,
            permissionLabel: permissionLabel,
            scheme: scheme,
          );
        },
      ),
    );
  }
}

/// A compact member tile for sidebar use (same as _FullMemberTile but without
/// the full-page context menu navigation since the sidebar context differs).
class _SidebarMemberTile extends StatelessWidget {
  const _SidebarMemberTile({
    required this.member,
    required this.displayName,
    this.permissionLabel,
    required this.scheme,
  });

  final User member;
  final String displayName;
  final String? permissionLabel;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final membershipLabel = switch (member.membership) {
      Membership.ban => l10n.bannedBadge,
      Membership.invite => l10n.invitedBadge,
      Membership.join => null,
      Membership.knock => l10n.knockingBadge,
      Membership.leave => l10n.leftBadge,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _showContextMenu(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
        child: Row(
          children: [
            SizedBox(
              width: 32,
              height: 32,
              child: AvatarFromUriOrFallbackImage(
                client: member.room.client,
                avatarUri: member.avatarUrl,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (permissionLabel != null) ...[
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color:
                                scheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            permissionLabel!,
                            style: TextStyle(
                              fontSize: 10,
                              color: scheme.onPrimaryContainer,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (membershipLabel != null)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  membershipLabel,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 160,
        offset.dy,
        offset.dx + 320,
        offset.dy + 60,
      ),
      items: [
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: const Icon(Icons.person_rounded),
            title: Text(AppLocalizations.of(context)!.viewProfile),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'message',
          child: ListTile(
            leading: const Icon(Icons.chat_rounded),
            title: Text(AppLocalizations.of(context)!.sendMessage),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((v) {
      if (v == null || !context.mounted) return;
      switch (v) {
        case 'profile':
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => ProfilePage(
                client: member.room.client,
                userID: member.id,
                room: member.room,
              ),
            ),
          );
        case 'message':
          final log = context.read<Logger>();
          final l10n = AppLocalizations.of(context)!;
          withRetry(
            () => member.startDirectChat(),
            maxRetries: 1,
            timeout: kDefaultTimeout,
            log: log,
            label: 'startDirectChat',
          ).then((result) {
            if (!context.mounted) return;
            switch (result) {
              case RetrySuccess(:final value):
                GoRouter.of(context).go('/main/rooms/$value');
              case RetryFailed(:final error):
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      error is TimeoutException
                          ? l10n.couldNotStartChatTimeout
                          : l10n.couldNotStartChat('$error'),
                    ),
                  ),
                );
            }
          });
      }
    });
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
