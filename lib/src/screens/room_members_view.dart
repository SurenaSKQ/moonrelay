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
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';

/// A full-screen page that lists all members of a room.
///
/// Provides:
/// - A search bar at the top for filtering by display name or Matrix ID
/// - A scrollable list of all members, sorted by power level
/// - A context menu on each member tile (right-click or long-press)
///   with "View Profile" and "Send Message" actions
///
/// The list reactively updates when room state changes.
class FullRoomMembersList extends StatefulWidget {
  const FullRoomMembersList({super.key, required this.room});

  final Room room;

  @override
  State<FullRoomMembersList> createState() => _FullRoomMembersListState();
}

class _FullRoomMembersListState extends State<FullRoomMembersList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  /// Returns all room participants, sorted by power level descending,
  /// then filtered by the current search query.
  List<User> _filteredMembers() {
    final members = widget.room.getParticipants().toList()
      ..sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));

    if (_searchQuery.isEmpty) return members;

    return members.where((m) {
      final displayName = m.calcDisplayname().toLowerCase();
      final userId = m.id.toLowerCase();
      return displayName.contains(_searchQuery) ||
          userId.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final totalMembers = (widget.room.summary.mInvitedMemberCount ?? 0) +
        (widget.room.summary.mJoinedMemberCount ?? 0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Members ($totalMembers)',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search members\u2026',
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
              ),
              textInputAction: TextInputAction.search,
            ),
          ),

          const SizedBox(height: 4),

          // Member list
          Expanded(
            child: StreamBuilder(
              stream: widget.room.client.onRoomState.stream
                  .where((event) => event.roomId == widget.room.id),
              builder: (context, snapshot) {
                final members = _filteredMembers();

                if (members.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.users,
                          size: 48,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'No members match your search'
                              : 'No members found',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: members.length,
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final displayName = member.calcDisplayname();
                    final permissionLabel = member.powerLevel.level >= 100
                        ? 'Admin'
                        : member.powerLevel.level >= 50
                            ? 'Moderator'
                            : null;

                    return _FullMemberTile(
                      member: member,
                      displayName: displayName,
                      permissionLabel: permissionLabel,
                      scheme: scheme,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A member tile used in the full list with context menu support.
class _FullMemberTile extends StatelessWidget {
  const _FullMemberTile({
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
    final membershipLabel = switch (member.membership) {
      Membership.ban => 'Banned',
      Membership.invite => 'Invited',
      Membership.join => null,
      Membership.knock => 'Knocking',
      Membership.leave => 'Left',
    };

    return GestureDetector(
      onLongPress: () => _showContextMenu(context),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _showContextMenu(context),
          onSecondaryTap: () => _showContextMenu(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              children: [
                // Avatar
                SizedBox(
                  width: 40,
                  height: 40,
                  child: AvatarFromUriOrFallbackImage(
                    client: member.room.client,
                    avatarUri: member.avatarUrl,
                  ),
                ),
                const SizedBox(width: 12),

                // Name + ID
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
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (permissionLabel != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primaryContainer
                                    .withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                permissionLabel!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onPrimaryContainer,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      Text(
                        member.id,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Membership badge (if not joined)
                if (membershipLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      membershipLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onTertiaryContainer,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shows a context menu with actions for this member.
  void _showContextMenu(BuildContext context) {
    final renderBox = context.findRenderObject() as RenderBox?;
    final offset = renderBox?.localToGlobal(Offset.zero) ?? Offset.zero;

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 200,
        offset.dy,
        offset.dx + 400,
        offset.dy + 60,
      ),
      items: [
        const PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_rounded),
            title: Text('View Profile'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const PopupMenuItem(
          value: 'message',
          child: ListTile(
            leading: Icon(Icons.chat_rounded),
            title: Text('Send Message'),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'profile':
          _openProfile(context);
        case 'message':
          _sendMessage(context);
      }
    });
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePage(
          client: member.room.client,
          userID: member.id,
        ),
      ),
    );
  }

  void _sendMessage(BuildContext context) {
    final goRouter = GoRouter.of(context);
    final navigator = Navigator.of(context);
    member.startDirectChat().then((roomId) {
      navigator.pop();
      goRouter.go('/main/rooms/$roomId');
    }).catchError((e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open chat: $e'),
          ),
        );
      }
    });
  }
}
