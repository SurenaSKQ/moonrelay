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
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/thread_view.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';

/// A full-screen page that lists all thread roots in a room with progressive
/// loading from the server.
///
/// Provides:
/// - A search bar at the top for filtering by sender name or message text
/// - Progressive loading via `getThreadRoots` API
/// - Pull-to-refresh to re-fetch the thread list
class FullRoomThreadsList extends StatefulWidget {
  const FullRoomThreadsList({super.key, required this.room});

  final Room room;

  @override
  State<FullRoomThreadsList> createState() => _FullRoomThreadsListState();
}

class _FullRoomThreadsListState extends State<FullRoomThreadsList> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  final List<Event> _threadRoots = [];
  bool _isLoading = true;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  String? _nextBatch;

  static const int _batchSize = 30;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _fetchThreads();
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
    if (!_hasMore || _isFetchingMore) return;
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchThreads();
    }
  }

  List<Event> get _filteredThreads {
    if (_searchQuery.isEmpty) return _threadRoots;
    return _threadRoots.where((event) {
      final sender =
          event.senderFromMemoryOrFallback.calcDisplayname().toLowerCase();
      final body = event.body.toLowerCase();
      return sender.contains(_searchQuery) || body.contains(_searchQuery);
    }).toList();
  }

  Future<void> _fetchThreads({bool refresh = false}) async {
    if (_isFetchingMore) return;
    if (!refresh && !_hasMore) return;

    setState(() {
      if (refresh) {
        _isLoading = true;
      } else {
        _isFetchingMore = true;
      }
    });

    try {
      final response = await widget.room.client.getThreadRoots(
        widget.room.id,
        include: Include.all,
        limit: _batchSize,
        from: refresh ? null : _nextBatch,
      );

      if (!mounted) return;

      setState(() {
        if (refresh) {
          _threadRoots.clear();
        }
        _threadRoots.addAll(
          response.chunk
              .map((m) => Event.fromMatrixEvent(m, widget.room)),
        );
        _nextBatch = response.nextBatch;
        _hasMore = response.nextBatch != null;
        _isLoading = false;
        _isFetchingMore = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isFetchingMore = false;
        });
      }
    }
  }

  Future<void> _onRefresh() async {
    _nextBatch = null;
    _hasMore = true;
    await _fetchThreads(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.threads),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.searchThreadsHint,
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
              ),
            ),
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _threadRoots.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.messageSquare,
                        size: 48,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.noThreadsYet,
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _onRefresh,
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _filteredThreads.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= _filteredThreads.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final event = _filteredThreads[index];
                      return _ThreadListTile(
                        event: event,
                        room: widget.room,
                      );
                    },
                  ),
                ),
    );
  }
}

// ─── Thread list tile ──────────────────────────────────────────────────────────

/// A single tile in the thread list showing the thread root preview.
class _ThreadListTile extends StatelessWidget {
  const _ThreadListTile({
    required this.event,
    required this.room,
  });

  final Event event;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sender = event.senderFromMemoryOrFallback;

    return InkWell(
      onTap: () => _openThread(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarFromUriOrFallbackImage(
              client: room.client,
              avatarUri: sender.avatarUrl,
              radius: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          sender.calcDisplayname(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        event.originServerTs.localizedTimeShort(context),
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurface.withValues(alpha: 0.45),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    event.body.isNotEmpty ? event.body : '(image or file)',
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 18,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _openThread(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThreadViewPage(
          room: room,
          threadRootEventId: event.eventId,
        ),
      ),
    );
  }
}
