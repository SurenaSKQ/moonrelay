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

import 'package:flutter/material.dart' hide Visibility;
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

/// A full-screen page for discovering and joining rooms on a Matrix
/// homeserver's public room directory.
///
/// Supports:
/// - Text-based search filtering via `PublicRoomQueryFilter`
/// - Paginated browsing (load more on scroll)
/// - Joining a room directly from the result list
/// - Joining by room ID / alias as a fallback option
class RoomDirectorySearch extends StatefulWidget {
  /// When `true`, the widget renders without its own [Scaffold] / [AppBar]
  /// so it can be embedded inside another page (e.g. as a tab in
  /// [AddRoomPage]) without duplicating the chrome.
  final bool embedded;

  const RoomDirectorySearch({super.key, this.embedded = false});

  @override
  State<RoomDirectorySearch> createState() => _RoomDirectorySearchState();
}

class _RoomDirectorySearchState extends State<RoomDirectorySearch> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // Search state
  String _searchQuery = '';
  List<PublicRoomsChunk> _rooms = [];
  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _nextBatch;
  Object? _error;
  String? _joinError;
  String? _joiningRoomId;
  String? _knockingRoomId;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    // Load initial batch
    _searchRooms();
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
    final query = _searchController.text.trim().toLowerCase();
    if (query != _searchQuery) {
      _searchQuery = query;
      _searchRooms(reset: true);
    }
  }

  /// Load more when the user scrolls near the bottom.
  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _searchRooms();
    }
  }

  /// Searches the public room directory.
  ///
  /// When [reset] is `true` the existing result list is cleared and the
  /// first page is fetched. Otherwise the next batch is appended.
  Future<void> _searchRooms({bool reset = false}) async {
    if (_isLoading || _isLoadingMore) return;

    setState(() {
      if (reset) {
        _isLoading = true;
        _rooms = [];
        _nextBatch = null;
        _hasMore = true;
        _error = null;
        _joinError = null;
      } else {
        _isLoadingMore = true;
      }
    });

    try {
      final client = context.read<Client>();
      final filter = _searchQuery.isNotEmpty
          ? PublicRoomQueryFilter(genericSearchTerm: _searchQuery)
          : null;

      final response = await client.queryPublicRooms(
        filter: filter,
        limit: 20,
        since: reset ? null : _nextBatch,
      );

      if (!mounted) return;

      final chunk = response.chunk;

      setState(() {
        if (reset) {
          _rooms = chunk;
        } else {
          _rooms.addAll(chunk);
        }
        _nextBatch = response.nextBatch;
        _hasMore = _nextBatch != null && chunk.length >= 20;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  /// Joins a room by its room ID or alias.
  Future<void> _joinRoom(PublicRoomsChunk room) async {
    final log = context.read<Logger>();
    final client = context.read<Client>();
    final roomIdOrAlias = room.roomId;
    final alias = room.canonicalAlias ?? roomIdOrAlias;

    setState(() {
      _joiningRoomId = alias;
      _joinError = null;
    });

    final l10n = AppLocalizations.of(context)!;
    final result = await withRetry(
      () => client.joinRoom(alias),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'joinRoom',
    );

    if (!mounted) return;

    setState(() => _joiningRoomId = null);

    switch (result) {
      case RetrySuccess():
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.addRoom)),
        );
        context.push('/main/rooms/$alias');
      case RetryFailed(:final error):
        setState(() {
          _joinError = error is TimeoutException
              ? l10n.joiningTimedOut
              : l10n.couldNotJoinRoom('$error');
        });
    }
  }

  /// Knocks on a room that requires approval to join.
  Future<void> _knockRoom(PublicRoomsChunk room) async {
    final client = context.read<Client>();
    final roomIdOrAlias = room.roomId;
    final alias = room.canonicalAlias ?? roomIdOrAlias;

    setState(() {
      _knockingRoomId = alias;
      _joinError = null;
    });

    final l10n = AppLocalizations.of(context)!;
    try {
      await client.knockRoom(alias);
      if (!mounted) return;
      setState(() => _knockingRoomId = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.knockSent(alias))),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _knockingRoomId = null);
      setState(() {
        _joinError = l10n.knockFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final Widget body = Column(
      children: [
        // Search bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: l10n.joinRoomInstructions,
              prefixIcon: const Icon(LucideIcons.search, size: 20),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(LucideIcons.x, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

        // Join error banner
        if (_joinError != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(LucideIcons.alertCircle, size: 18, color: scheme.error),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _joinError!,
                      style: TextStyle(
                        color: scheme.onErrorContainer,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(LucideIcons.x, size: 16, color: scheme.error),
                    onPressed: () => setState(() => _joinError = null),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),

        const SizedBox(height: 4),

        // Results area
        Expanded(
          child: _buildContent(scheme, l10n),
        ),
      ],
    );

    if (widget.embedded) return body;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.addRoom,
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      body: body,
    );
  }

  Widget _buildContent(ColorScheme scheme, AppLocalizations l10n) {
    // Initial loading
    if (_isLoading && _rooms.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: scheme.primary),
            const SizedBox(height: 16),
            Text(l10n.loadingRooms,
                style: TextStyle(color: scheme.onSurfaceVariant)),
          ],
        ),
      );
    }

    // Error with no results
    if (_error != null && _rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.alertCircle, size: 48, color: scheme.error),
              const SizedBox(height: 16),
              Text(
                l10n.couldNotLoadMessages,
                style: TextStyle(color: scheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonalIcon(
                onPressed: () => _searchRooms(reset: true),
                icon: const Icon(LucideIcons.refreshCw, size: 18),
                label: Text(l10n.retry),
              ),
            ],
          ),
        ),
      );
    }

    // Empty results
    if (_rooms.isEmpty && !_isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.searchX,
              size: 48,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty
                  ? l10n.noMembersMatchSearch
                  : l10n.noRoomsYet,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    // Room list
    return RefreshIndicator(
      onRefresh: () => _searchRooms(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _rooms.length + (_hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _rooms.length) {
            // Loading more indicator
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 8),
                    Text(l10n.loading,
                        style: TextStyle(
                            fontSize: 12, color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
            );
          }

          final room = _rooms[index];
          final isJoining =
              _joiningRoomId == (room.canonicalAlias ?? room.roomId);
          final isKnocking =
              _knockingRoomId == (room.canonicalAlias ?? room.roomId);
          final joinRule = room.joinRule;
          final requiresKnock =
              joinRule == 'knock' || joinRule == 'knock_restricted';

          return _PublicRoomTile(
            room: room,
            isJoining: isJoining,
            isKnocking: isKnocking,
            requiresKnock: requiresKnock,
            scheme: scheme,
            onJoin: () => _joinRoom(room),
            onKnock: requiresKnock ? () => _knockRoom(room) : null,
          );
        },
      ),
    );
  }
}

/// A tile showing a single public room from the directory.
class _PublicRoomTile extends StatelessWidget {
  const _PublicRoomTile({
    required this.room,
    required this.isJoining,
    required this.isKnocking,
    required this.requiresKnock,
    required this.scheme,
    required this.onJoin,
    this.onKnock,
  });

  final PublicRoomsChunk room;
  final bool isJoining;
  final bool isKnocking;
  final bool requiresKnock;
  final ColorScheme scheme;
  final VoidCallback onJoin;
  final VoidCallback? onKnock;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = room.name?.isNotEmpty == true ? room.name : room.roomId;
    final topic = room.topic?.isNotEmpty == true ? room.topic : null;
    final alias = room.canonicalAlias;
    final memberCount = room.numJoinedMembers;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Room avatar placeholder
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: room.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        room.avatarUrl!.toString(),
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(
                          LucideIcons.hash,
                          color: scheme.onPrimaryContainer,
                          size: 24,
                        ),
                      ),
                    )
                  : Icon(
                      LucideIcons.hash,
                      color: scheme.onPrimaryContainer,
                      size: 24,
                    ),
            ),
            const SizedBox(width: 12),

            // Room info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayName ?? l10n.unknown,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (alias != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        alias,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                          fontFamily: 'JetBrainsMono',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  if (topic != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        topic,
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      children: [
                        Icon(LucideIcons.users,
                            size: 14,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                        const SizedBox(width: 4),
                        Text(
                          '$memberCount',
                          style: TextStyle(
                            fontSize: 12,
                            color:
                                scheme.onSurfaceVariant.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Action button
            const SizedBox(width: 8),
            if (isJoining || isKnocking)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              )
            else if (requiresKnock)
              FilledButton.tonalIcon(
                onPressed: onKnock,
                icon: Icon(LucideIcons.logIn, size: 14),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                label: Text(
                  l10n.knockRoom,
                  style: const TextStyle(fontSize: 13),
                ),
              )
            else
              FilledButton.tonal(
                onPressed: onJoin,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.addRoom,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
