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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';

/// A full-screen overlay for searching rooms, spaces, and messages.
///
/// Opens as an overlay on top of the dashboard. The user types a query and
/// results are grouped into sections:
/// - **Rooms**: joined rooms whose display name matches the query
/// - **Spaces**: joined spaces whose display name matches the query
/// - **Messages**: server-side full-text search via `client.search()`
/// - **Homeserver**: public room directory search (bottom section)
///
/// Tapping any result navigates to the corresponding room, space, or message.
class GlobalSearchOverlay extends StatefulWidget {
  const GlobalSearchOverlay({super.key});

  @override
  State<GlobalSearchOverlay> createState() => _GlobalSearchOverlayState();
}

class _GlobalSearchOverlayState extends State<GlobalSearchOverlay> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _debounce;

  // Search state
  String _query = '';
  bool _isSearchingMessages = false;

  // Local results (filtered from client.rooms)
  List<Room> _matchedRooms = [];
  List<Room> _matchedSpaces = [];

  // Server-side message search results
  List<_MessageSearchResult> _messageResults = [];

  // Homeserver-wide search
  List<PublishedRoomsChunk> _homeserverResults = [];
  bool _isSearchingHomeserver = false;

  @override
  void initState() {
    super.initState();
    _searchFocus.requestFocus();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    if (query == _query) return;

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      _query = query;
      _performSearch();
    });
  }

  void _performSearch() {
    if (_query.isEmpty) {
      setState(() {
        _matchedRooms = [];
        _matchedSpaces = [];
        _messageResults = [];
        _homeserverResults = [];
        _isSearchingMessages = false;
        _isSearchingHomeserver = false;
      });
      return;
    }

    _searchLocalRooms();
    _searchMessages();
    _searchHomeserver();
  }

  // ── Local room/space search ───────────────────────────────────────

  void _searchLocalRooms() {
    final client = context.read<Client>();
    final rooms = client.rooms.where((r) => r.membership == Membership.join);

    final matchedRooms = <Room>[];
    final matchedSpaces = <Room>[];

    for (final room in rooms) {
      final name = room.getLocalizedDisplayname().toLowerCase();
      if (!name.contains(_query)) continue;

      if (room.isSpace) {
        matchedSpaces.add(room);
      } else {
        matchedRooms.add(room);
      }
    }

    setState(() {
      _matchedRooms = matchedRooms;
      _matchedSpaces = matchedSpaces;
    });
  }

  // ── Server-side message search ────────────────────────────────────

  Future<void> _searchMessages() async {
    if (_query.isEmpty) return;

    setState(() => _isSearchingMessages = true);

    try {
      final client = context.read<Client>();
      final results = await client.search(
        Categories(
          roomEvents: RoomEventsCriteria(
            searchTerm: _query,
            filter: SearchFilter(limit: 20),
          ),
        ),
      );

      if (!mounted) return;

      final roomEvents = results.searchCategories.roomEvents;
      final resultsList = roomEvents?.results ?? [];
      final rooms = client.rooms;

      final messages = <_MessageSearchResult>[];
      for (final result in resultsList) {
        final event = result.result;
        if (event == null) continue;

        final roomId = event.roomId;
        final room = rooms.firstWhere(
          (r) => r.id == roomId,
          orElse: () => rooms.first,
        );

        messages.add(_MessageSearchResult(
          event: Event.fromMatrixEvent(event, room),
          room: room,
          rank: result.rank ?? 0,
        ));
      }

      setState(() {
        _messageResults = messages;
        _isSearchingMessages = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearchingMessages = false);
    }
  }

  // ── Homeserver-wide room search ───────────────────────────────────

  Future<void> _searchHomeserver() async {
    if (_query.isEmpty) return;

    setState(() => _isSearchingHomeserver = true);

    try {
      final client = context.read<Client>();
      final response = await client.queryPublicRooms(
        filter: PublicRoomQueryFilter(genericSearchTerm: _query),
        limit: 10,
      );

      if (!mounted) return;

      setState(() {
        _homeserverResults = response.chunk;
        _isSearchingHomeserver = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSearchingHomeserver = false);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────

  void _openRoom(Room room) {
    context.pop();
    context.go('/main/rooms/${room.id}');
  }

  void _openHomeserverRoom(PublishedRoomsChunk room) {
    final alias = room.canonicalAlias ?? room.roomId;
    context.pop();
    context.go('/main/rooms/$alias');
  }

  void _openMessageEvent(_MessageSearchResult msg) {
    context.pop();
    context.go('/main/rooms/${msg.room.id}');
  }

  // ── Build ─────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return GestureDetector(
      onTap: () => _searchFocus.requestFocus(),
      child: Scaffold(
        backgroundColor: scheme.surface.withValues(alpha: 0.97),
        body: Column(
          children: [
            // ── Search field ──────────────────────────────────────
            _buildSearchBar(scheme, l10n),

            // ── Results ───────────────────────────────────────────
            Expanded(
              child: _query.isEmpty
                  ? _buildEmptyState(scheme, l10n)
                  : _buildResults(scheme, l10n),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar(ColorScheme scheme, AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        bottom: 8,
        left: 16,
        right: 16,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(LucideIcons.arrowLeft),
            onPressed: () => context.pop(),
            tooltip: l10n.back,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocus,
              decoration: InputDecoration(
                hintText: l10n.globalSearch,
                prefixIcon: const Icon(LucideIcons.search, size: 20),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(LucideIcons.x, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          _searchFocus.requestFocus();
                        },
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
              onSubmitted: (_) {
                _debounce?.cancel();
                _query = _searchController.text.trim().toLowerCase();
                _performSearch();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(ColorScheme scheme, AppLocalizations l10n) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            LucideIcons.search,
            size: 64,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.globalSearch,
            style: TextStyle(
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResults(ColorScheme scheme, AppLocalizations l10n) {
    final hasLocalResults =
        _matchedRooms.isNotEmpty || _matchedSpaces.isNotEmpty;
    final hasMessageResults = _messageResults.isNotEmpty;
    final hasHomeserverResults = _homeserverResults.isNotEmpty;
    final hasAny = hasLocalResults || hasMessageResults || hasHomeserverResults;

    if (!hasAny && !_isSearchingMessages && !_isSearchingHomeserver) {
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
              l10n.searchNoResults,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        // ── Rooms section ─────────────────────────────────────────
        if (_matchedRooms.isNotEmpty) ...[
          _SectionHeader(icon: LucideIcons.messageCircle, title: l10n.searchRooms),
          ..._matchedRooms.map((room) => _RoomSearchTile(
                room: room,
                onTap: () => _openRoom(room),
              )),
        ],

        // ── Spaces section ────────────────────────────────────────
        if (_matchedSpaces.isNotEmpty) ...[
          _SectionHeader(icon: LucideIcons.layers, title: l10n.searchSpaces),
          ..._matchedSpaces.map((room) => _RoomSearchTile(
                room: room,
                onTap: () => _openRoom(room),
              )),
        ],

        // ── Messages section ──────────────────────────────────────
        if (_isSearchingMessages)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_messageResults.isNotEmpty) ...[
          _SectionHeader(icon: LucideIcons.messageSquare, title: l10n.searchMessages),
          ..._messageResults.map((msg) => _MessageSearchTile(
                result: msg,
                onTap: () => _openMessageEvent(msg),
              )),
        ],

        // ── Homeserver section ────────────────────────────────────
        if (_isSearchingHomeserver)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_homeserverResults.isNotEmpty) ...[
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              l10n.searchHomeserver,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          ..._homeserverResults.map((room) => _HomeserverRoomTile(
                room: room,
                onTap: () => _openHomeserverRoom(room),
              )),
        ],
      ],
    );
  }
}

// ─── Internal data model ──────────────────────────────────────────────────────

class _MessageSearchResult {
  final Event event;
  final Room room;
  final double rank;
  const _MessageSearchResult({
    required this.event,
    required this.room,
    required this.rank,
  });
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  const _SectionHeader({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Room search tile ─────────────────────────────────────────────────────────

class _RoomSearchTile extends StatelessWidget {
  final Room room;
  final VoidCallback onTap;
  const _RoomSearchTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = room.getLocalizedDisplayname();
    final alias = room.canonicalAlias;

    return ListTile(
      leading: AvatarFromUriOrFallbackImage(
        client: room.client,
        avatarUri: room.avatar,
        radius: 16,
      ),
      title: Text(
        displayName.isNotEmpty ? displayName : room.id,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: alias.isNotEmpty
          ? Text(
              alias,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: scheme.onSurfaceVariant,
              ),
            )
          : null,
      trailing: Icon(
        room.isSpace ? LucideIcons.layers : LucideIcons.hash,
        size: 16,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}

// ─── Message search tile ──────────────────────────────────────────────────────

class _MessageSearchTile extends StatelessWidget {
  final _MessageSearchResult result;
  final VoidCallback onTap;
  const _MessageSearchTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final event = result.event;
    final room = result.room;
    final sender = event.senderFromMemoryOrFallback;
    final senderName = sender.displayName ?? sender.id;
    final body = event.body;

    return ListTile(
      leading: AvatarFromUriOrFallbackImage(
        client: room.client,
        avatarUri: room.avatar,
        radius: 16,
      ),
      title: Text(
        body.isNotEmpty ? body : '(no content)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 13),
      ),
      subtitle: Text(
        '$senderName • ${room.getLocalizedDisplayname()}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          color: scheme.onSurfaceVariant,
        ),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}

// ─── Homeserver room tile ─────────────────────────────────────────────────────

class _HomeserverRoomTile extends StatelessWidget {
  final PublishedRoomsChunk room;
  final VoidCallback onTap;
  const _HomeserverRoomTile({required this.room, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final name = room.name ?? room.canonicalAlias ?? room.roomId;
    final alias = room.canonicalAlias;
    final memberCount = room.numJoinedMembers;

    return ListTile(
      leading: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          LucideIcons.globe,
          size: 16,
          color: scheme.onSurfaceVariant,
        ),
      ),
      title: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Row(
        children: [
          if (alias != null) ...[
            Flexible(
              child: Text(
                alias,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Icon(
            LucideIcons.users,
            size: 12,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(width: 2),
          Text(
            '$memberCount',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
      dense: true,
      onTap: onTap,
    );
  }
}
