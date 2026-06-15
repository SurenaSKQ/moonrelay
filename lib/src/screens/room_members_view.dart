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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// A full-screen page that lists all members of a room with progressive
/// loading from the server (not limited to lazy-loaded sync data).
///
/// Provides:
/// - A search bar at the top for filtering by display name or Matrix ID
/// - Progressive batch loading: 50 members initially, auto-loads more until
///   the viewport is filled, then loads on scroll
/// - All members fetched server-side via `getJoinedMembersByRoom`
/// - Pull-to-refresh to re-fetch the full member list
/// - A context menu on each member tile (right-click or long-press)
///   with "View Profile" and "Send Message" actions
class FullRoomMembersList extends StatefulWidget {
  const FullRoomMembersList({super.key, required this.room});

  final Room room;

  @override
  State<FullRoomMembersList> createState() => _FullRoomMembersListState();
}

class _FullRoomMembersListState extends State<FullRoomMembersList> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  // Progressive loading state
  static const int _batchSize = 50;
  List<User> _allMembers = [];
  int _displayedCount = 0;
  bool _isLoading = true;

  Object? _loadError;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _fetchAllMembers();
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

  /// Load more members when the user scrolls near the bottom.
  void _onScroll() {
    if (_searchQuery.isNotEmpty) return;
    if (_displayedCount >= _allMembers.length) return;
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _loadNextBatch();
    }
  }

  /// Increases the displayed count by one batch, then auto-advances if the
  /// viewport is still not filled.
  void _loadNextBatch() {
    if (_displayedCount >= _allMembers.length) return;

    setState(() {
      _displayedCount =
          (_displayedCount + _batchSize).clamp(0, _allMembers.length);
    });

    // After the frame renders, check if we should auto-load more to fill
    // the viewport so that scroll events can be triggered.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_displayedCount >= _allMembers.length) return;
      if (_searchQuery.isNotEmpty) return;

      // If the content still doesn't overflow, keep loading.
      if (_scrollController.hasClients &&
          _scrollController.position.maxScrollExtent <=
              _scrollController.position.viewportDimension + 1) {
        _loadNextBatch();
      }
    });
  }

  /// Fetches the full member list from the server using the Matrix API.
  ///
  /// 1. Calls `getJoinedMembersByRoom` to get ALL joined member MXIDs.
  /// 2. Re-uses locally known `User` objects (which carry power level data)
  ///    and falls back to `requestUser` for any missing members (awaited
  ///    properly, unlike the broken sync `orElse` approach).
  /// 3. Sorts by power level descending.
  Future<void> _fetchAllMembers() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _displayedCount = 0;
      _allMembers = [];
    });

    try {
      // ── 1. Fetch all joined member IDs from the server ──────────────
      final joinedMembers =
          await widget.room.client.getJoinedMembersByRoom(widget.room.id);

      if (!mounted) return;

      // ── 2. Build a name-index of locally known participants ─────────
      final localParticipants = widget.room.getParticipants().toList();
      final localById = <String, User>{};
      for (final u in localParticipants) {
        localById[u.id] = u;
      }

      // ── 3. Assemble the full list ───────────────────────────────────
      final members = <User>[];

      if (joinedMembers != null && joinedMembers.isNotEmpty) {
        for (final mxid in joinedMembers.keys) {
          final local = localById[mxid];
          if (local != null) {
            // Use the local object which has power level data.
            members.add(local);
          } else {
            // Fetch from server – awaited correctly.
            try {
              final remote = await widget.room.requestUser(mxid);
              if (remote != null) {
                members.add(remote);
              }
            } catch (_) {
              // If even requestUser fails, create a minimal User with the
              // display name and avatar from the joined-members response.
              final fallback = User(
                mxid,
                room: widget.room,
                displayName: joinedMembers[mxid]?.displayName,
                avatarUrl: joinedMembers[mxid]?.avatarUrl?.toString(),
              );
              members.add(fallback);
            }
          }
        }
      } else {
        // Fallback: use whatever the client already knows.
        members.addAll(localParticipants);
      }

      // ── 4. Sort by power level descending ──────────────────────────
      members.sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));

      _allMembers = members;
    } catch (e) {
      if (!mounted) return;
      // Fallback to locally known members on error.
      _allMembers = widget.room.getParticipants().toList()
        ..sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));
      _loadError = e;
    }

    if (!mounted) return;

    setState(() => _isLoading = false);

    // ── 5. Load initial batch and auto-fill viewport ─────────────────
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _displayedCount = (_allMembers.length > 0)
            ? _batchSize.clamp(0, _allMembers.length)
            : 0;
      });
      // Auto-advance until the viewport is filled.
      if (_displayedCount < _allMembers.length) {
        _loadNextBatch();
      }
    });
  }

  /// Returns the currently visible members, filtered by search query.
  List<User> get _visibleMembers {
    if (_searchQuery.isNotEmpty) {
      return _allMembers.where((m) {
        final displayName = m.calcDisplayname().toLowerCase();
        final userId = m.id.toLowerCase();
        return displayName.contains(_searchQuery) ||
            userId.contains(_searchQuery);
      }).toList();
    }
    return _allMembers.take(_displayedCount).toList();
  }

  /// Whether there are more members to load beyond the current batch.
  bool get _hasMore =>
      _searchQuery.isEmpty && _displayedCount < _allMembers.length;

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
          AppLocalizations.of(context)!.membersCount(totalMembers),
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
                hintText: AppLocalizations.of(context)!.searchMembers,
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

          // Member list or loading/error state
          Expanded(
            child: _isLoading
                ? _buildLoadingState(scheme)
                : _loadError != null && _allMembers.isEmpty
                    ? _buildErrorState(scheme)
                    : _buildMemberList(scheme),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(ColorScheme scheme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.loading,
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(ColorScheme scheme) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 48,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.couldNotLoadMessages,
              style: TextStyle(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: _fetchAllMembers,
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(l10n.retry),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberList(ColorScheme scheme) {
    final members = _visibleMembers;
    final l10n = AppLocalizations.of(context)!;

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
                  ? l10n.noMembersMatchSearch
                  : l10n.noMembersFound,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Total item count: members + loading indicator if there are more.
    final itemCount = members.length + (_hasMore ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _fetchAllMembers,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Loading more indicator at the bottom
          if (index >= members.length) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.loading,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
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

          return _FullMemberTile(
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
    final l10n = AppLocalizations.of(context)!;
    final membershipLabel = switch (member.membership) {
      Membership.ban => l10n.bannedBadge,
      Membership.invite => l10n.invitedBadge,
      Membership.join => null,
      Membership.knock => l10n.knockingBadge,
      Membership.leave => l10n.leftBadge,
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
        PopupMenuItem(
          value: 'profile',
          child: ListTile(
            leading: Icon(Icons.person_rounded),
            title: Text(AppLocalizations.of(context)!.viewProfile),
            dense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        PopupMenuItem(
          value: 'message',
          child: ListTile(
            leading: Icon(Icons.chat_rounded),
            title: Text(AppLocalizations.of(context)!.sendMessage),
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
          room: member.room,
        ),
      ),
    );
  }

  Future<void> _sendMessage(BuildContext context) async {
    final log = context.read<Logger>();
    final goRouter = GoRouter.of(context);
    final navigator = Navigator.of(context);

    final result = await withRetry(
      () => member.startDirectChat(),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'startDirectChat',
    );

    if (!context.mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        navigator.pop();
        goRouter.go('/main/rooms/$value');
      case RetryFailed(:final error):
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error is TimeoutException
                ? AppLocalizations.of(context)!.couldNotStartChatTimeout
                : AppLocalizations.of(context)!.couldNotStartChat('$error')),
          ),
        );
    }
  }
}
