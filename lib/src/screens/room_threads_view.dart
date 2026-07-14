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
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/helpers/threads_provider.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/thread_view.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// A full-screen page that lists all thread roots in a room with progressive
/// loading from the server.
///
/// Provides:
/// - A search bar at the top for filtering by sender name or message text
/// - Progressive loading via the [ThreadsProvider]
/// - Pull-to-refresh to re-fetch the thread list
class FullRoomThreadsList extends StatefulWidget {
  const FullRoomThreadsList({super.key, required this.room});

  final Room room;

  @override
  State<FullRoomThreadsList> createState() => _FullRoomThreadsListState();
}

class _FullRoomThreadsListState extends State<FullRoomThreadsList> {
  late final ThreadsProvider _provider;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _provider = ThreadsProvider(room: widget.room);
    _provider.bind(context.read<SyncPulse>());
    _searchController.addListener(_onSearchChanged);
    _scrollController.addListener(_onScroll);
    _provider.fetch(firstPage: true);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _provider.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  void _onScroll() {
    if (_searchQuery.isNotEmpty) return;
    if (!_provider.hasMore || _provider.isLoading) return;
    if (!_scrollController.hasClients) return;

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _provider.fetch();
    }
  }

  List<Event> get _filteredThreads {
    final threads = _provider.threadRoots;
    if (_searchQuery.isEmpty) return threads;
    return threads.where((event) {
      final sender =
          event.senderFromMemoryOrFallback.calcDisplayname().toLowerCase();
      final body = event.body.toLowerCase();
      return sender.contains(_searchQuery) || body.contains(_searchQuery);
    }).toList();
  }

  Future<void> _onRefresh() async {
    await _provider.fetch(firstPage: true);
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
      body: ListenableBuilder(
        listenable: _provider,
        builder: (context, _) {
          if (_provider.isLoading && _provider.threadRoots.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_provider.threadRoots.isEmpty) {
            return Center(
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
            );
          }

          final filtered = _filteredThreads;

          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: ListView.builder(
                controller: _scrollController,
                itemCount:
                    filtered.length + (_provider.hasMore ? 1 : 0),
                itemBuilder: (context, index) {
                      if (index >= filtered.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final event = filtered[index];

                      return _ThreadListTile(
                        event: event,
                        room: widget.room,
                      );
                    },
                  ),
          );
        },
      ),
    );
  }
}

// ─── Thread list tile ──────────────────────────────────────────────────────────

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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: AvatarFromUriOrFallbackImage(
        client: room.client,
        avatarUri: event.senderFromMemoryOrFallback.avatarUrl,
        radius: 18,
      ),
      title: Text(
        event.senderFromMemoryOrFallback.calcDisplayname(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        event.body.isNotEmpty ? event.body : event.type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: scheme.onSurfaceVariant),
      ),
      trailing: Text(
        event.originServerTs.localizedTimeShort(context),
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ThreadViewPage(
              room: room,
              threadRootEventId: event.eventId,
            ),
          ),
        );
      },
    );
  }
}
