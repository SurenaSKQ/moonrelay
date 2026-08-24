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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/common/feedback.dart';

/// A standalone members-list widget designed for the right sidebar.
///
/// Supports progressive loading: local participants are shown immediately,
/// then a server-side fetch backfills any members the local cache missed.
/// A search bar with debounced filtering and a scroll-driven "load more"
/// affordance keep the list responsive even in large rooms.
class SidebarMembersList extends StatefulWidget {
  const SidebarMembersList({super.key, required this.room});

  final Room room;

  @override
  State<SidebarMembersList> createState() => _SidebarMembersListState();
}

class _SidebarMembersListState extends State<SidebarMembersList> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  static const Duration _searchDebounce = Duration(milliseconds: 120);
  Timer? _searchDebounceTimer;

  static const int _batchSize = 50;
  static const int _fetchBatchSize = 10;

  List<User> _allMembers = [];
  int _displayedCount = 0;
  bool _isLoading = true;
  bool _isFetchingMore = false;
  Object? _loadError;

  final Map<String, String> _displayNameCache = {};

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _fetchLocalThenRemote();
  }

  @override
  void didUpdateWidget(SidebarMembersList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      _searchController.clear();
      _searchQuery = '';
      _searchDebounceTimer?.cancel();
      _displayedCount = 0;
      _allMembers = [];
      _displayNameCache.clear();
      _isLoading = true;
      _isFetchingMore = false;
      _loadError = null;
      _fetchLocalThenRemote();
    }
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(_searchDebounce, () {
      if (!mounted) return;
      final next = _searchController.text.trim().toLowerCase();
      if (next == _searchQuery) return;
      setState(() => _searchQuery = next);
    });
  }

  void _onScroll() {
    if (_searchQuery.isNotEmpty) return;
    if (_displayedCount >= _allMembers.length) return;
    if (!_scrollController.hasClients) return;
    final viewport = _scrollController.position.viewportDimension;
    final threshold = (viewport * 0.5).clamp(120.0, 400.0);
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent - threshold) {
      return;
    }
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
              _scrollController.position.viewportDimension + 32) {
        _loadNextBatch();
      }
    });
  }

  Future<void> _fetchLocalThenRemote() async {
    final roomId = widget.room.id;
    setState(() {
      _isLoading = true;
      _loadError = null;
      _displayedCount = 0;
      _allMembers = [];
      _displayNameCache.clear();
    });

    final localParticipants = widget.room.getParticipants().toList()
      ..sort((b, a) => a.powerLevel.level.compareTo(b.powerLevel.level));

    _allMembers = List.from(localParticipants);
    if (mounted && widget.room.id == roomId) {
      setState(() {
        _isLoading = false;
        _displayedCount = _allMembers.isNotEmpty
            ? _batchSize.clamp(0, _allMembers.length)
            : 0;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || widget.room.id != roomId) return;
      if (_displayedCount < _allMembers.length) _loadNextBatch();
    });

    try {
      _isFetchingMore = true;
      final joinedMembers =
          await widget.room.client.getJoinedMembersByRoom(widget.room.id);
      if (!mounted ||
          widget.room.id != roomId ||
          joinedMembers == null ||
          joinedMembers.isEmpty) {
        return;
      }

      var seen = _allMembers.isEmpty
          ? const <String>{}
          : _allMembers.map((u) => u.id).toSet();
      final missingMxids = seen.isEmpty
          ? joinedMembers.keys.toList()
          : joinedMembers.keys.where((id) => !seen.contains(id)).toList();
      if (missingMxids.isEmpty) {
        if (mounted && widget.room.id == roomId) {
          setState(() => _isFetchingMore = false);
        }
        return;
      }

      seen = seen.isEmpty ? <String>{} : Set<String>.from(seen);

      for (int i = 0; i < missingMxids.length; i += _fetchBatchSize) {
        final batch = missingMxids.sublist(
          i,
          (i + _fetchBatchSize).clamp(0, missingMxids.length),
        );
        final results = await Future.wait(
          batch.map((mxid) => _fetchUser(mxid, joinedMembers)),
        );
        if (!mounted || widget.room.id != roomId) return;

        final newUsers = <User>[];
        for (final user in results.whereType<User>()) {
          if (seen.add(user.id)) newUsers.add(user);
        }

        if (newUsers.isEmpty) continue;
        for (final user in newUsers) {
          _insertSortedByPowerLevel(_allMembers, user);
        }

        if (mounted && widget.room.id == roomId) {
          setState(() {
            _displayedCount = (_displayedCount + newUsers.length)
                .clamp(0, _allMembers.length);
          });
        }
      }
    } catch (_) {
      // Silently swallow; local data is already shown.
    }
    if (mounted && widget.room.id == roomId) {
      setState(() => _isFetchingMore = false);
    }
  }

  static void _insertSortedByPowerLevel(List<User> list, User user) {
    var lo = 0;
    var hi = list.length;
    while (lo < hi) {
      final mid = (lo + hi) >> 1;
      if (list[mid].powerLevel.level > user.powerLevel.level) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    list.insert(lo, user);
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

  String _displayNameFor(User user) {
    final cached = _displayNameCache[user.id];
    if (cached != null) return cached;
    final fresh = user.calcDisplayname();
    _displayNameCache[user.id] = fresh;
    return fresh;
  }

  List<User> get _visibleMembers {
    if (_searchQuery.isNotEmpty) {
      return _allMembers.where((m) {
        final dn = _displayNameFor(m).toLowerCase();
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Column(
      children: [
        Padding(
          padding:
              EdgeInsets.fromLTRB(t.spaceMd, t.spaceSm, t.spaceMd, t.spaceXs),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: AppLocalizations.of(context)!.searchMembers,
              prefixIcon: const Icon(LucideIcons.search, size: 18),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: Icon(LucideIcons.x, size: t.iconSizeSmall),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor:
                  scheme.surfaceContainerHighest.withValues(alpha: t.opacitySubtle),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(t.radiusMd),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
            ),
          ),
        ),
        SizedBox(height: t.spaceXxs),
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
      child: Scrollbar(
        controller: _scrollController,
        thumbVisibility: false,
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
            final displayName = _displayNameFor(member);
            final permissionLabel = member.powerLevel.level >= 100
                ? l10n.adminBadge
                : member.powerLevel.level >= 50
                    ? l10n.moderatorBadge
                    : null;

            return SidebarMemberTile(
              member: member,
              displayName: displayName,
              permissionLabel: permissionLabel,
              scheme: scheme,
            );
          },
        ),
      ),
    );
  }
}

/// A compact member tile for sidebar use.
class SidebarMemberTile extends StatelessWidget {
  const SidebarMemberTile({
    super.key,
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    final membershipLabel = switch (member.membership) {
      Membership.ban => l10n.bannedBadge,
      Membership.invite => l10n.invitedBadge,
      Membership.join => null,
      Membership.knock => l10n.knockingBadge,
      Membership.leave => l10n.leftBadge,
    };

    return InkWell(
      borderRadius: BorderRadius.circular(t.radiusSm),
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
                        SizedBox(width: t.spaceXs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 0,
                          ),
                          decoration: BoxDecoration(
                            color:
                                scheme.primaryContainer.withValues(alpha: 0.6),
                            borderRadius: BorderRadius.circular(t.radiusXs),
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
                  color:
                      scheme.tertiaryContainer.withValues(alpha: t.opacitySubtle),
                  borderRadius: BorderRadius.circular(t.radiusXs),
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
          showProfileOverlay(
            context,
            userId: member.id,
            room: member.room,
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
                final message = error is TimeoutException
                    ? l10n.couldNotStartChatTimeout
                    : l10n.couldNotStartChat('$error');
                showFloatingSnackBar(context, message);
            }
          });
      }
    });
  }
}
