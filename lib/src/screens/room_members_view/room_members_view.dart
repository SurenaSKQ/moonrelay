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
import 'package:moonrelay/src/screens/room_members_view/full_member_tile.dart';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// A full-screen page that lists all members of a room with progressive
/// loading from the server (not limited to lazy-loaded sync data).
///
/// Provides:
/// - A search bar at the top for filtering by display name or Matrix ID
/// - Progressive rendering: locally-known members appear immediately,
///   then server-only members are fetched in parallel batches and inserted
///   as they arrive
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
  static const int _fetchBatchSize = 10; // parallel requestUser calls at once

  List<User> _allMembers = [];
  int _displayedCount = 0;
  bool _isLoading = true; // true only while waiting for initial local data
  bool _isFetchingMore = false; // true while server-only members are fetched
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

  /// Phase 1: show locally-known members immediately.
  /// Phase 2: fetch the full member set from the server and add missing users
  ///          in parallel batches, re-sorting after each batch.
  Future<void> _fetchLocalThenRemote() async {
    setState(() {
      _isLoading = true;
      _loadError = null;
      _displayedCount = 0;
      _allMembers = [];
    });

    // -- Phase 1: Show local participants right away ----------------
    final localParticipants = widget.room.getParticipants().toList()
      ..sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));

    _allMembers = List.from(localParticipants);
    if (mounted) {
      setState(() {
        _isLoading = false;
        _displayedCount = _allMembers.isNotEmpty
            ? _batchSize.clamp(0, _allMembers.length)
            : 0;
      });
    }

    // Auto-fill viewport with local data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_displayedCount < _allMembers.length) _loadNextBatch();
    });

    // -- Phase 2: Fetch server-side member list ---------------------
    try {
      _isFetchingMore = true;
      final joinedMembers =
          await widget.room.client.getJoinedMembersByRoom(widget.room.id);

      if (!mounted) return;

      if (joinedMembers == null || joinedMembers.isEmpty) return;

      // Determine which MXIDs are not yet in our list.
      final existingIds = _allMembers.map((u) => u.id).toSet();
      final missingMxids =
          joinedMembers.keys.where((id) => !existingIds.contains(id)).toList();

      if (missingMxids.isEmpty) {
        if (mounted) setState(() => _isFetchingMore = false);
        return;
      }

      // Fetch missing members in parallel batches.
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

        // Insert new members into the sorted list (by power level descending).
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
    } catch (e) {
      if (!mounted) return;
      // Silently swallow; we already have local data showing.
    }

    if (mounted) setState(() => _isFetchingMore = false);
  }

  /// Tries to fetch a single User from the server, falling back to a minimal
  /// object built from the joined-members response.
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    final totalMembers = (widget.room.summary.mInvitedMemberCount ?? 0) +
        (widget.room.summary.mJoinedMemberCount ?? 0);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Text(
              l10n.membersCount(totalMembers),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (_isFetchingMore) ...[
              SizedBox(width: t.spaceSm),
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
            ],
          ],
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
                hintText: l10n.searchMembers,
                prefixIcon: Icon(LucideIcons.search, size: t.iconSizeMedium),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                filled: true,
                fillColor: scheme.surfaceContainerHighest
                    .withValues(alpha: t.opacitySubtle),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(t.radiusMd),
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

          SizedBox(height: t.spaceXs),

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
              onPressed: _fetchLocalThenRemote,
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

    // Total item count: members + bottom indicator if fetching or hasMore.
    final showIndicator = _isFetchingMore || _hasMore;
    final itemCount = members.length + (showIndicator ? 1 : 0);

    return RefreshIndicator(
      onRefresh: _fetchLocalThenRemote,
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: itemCount,
        itemBuilder: (context, index) {
          // Bottom indicator
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
                      _isFetchingMore ? l10n.loading : l10n.loading,
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

          return FullMemberTile(
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
