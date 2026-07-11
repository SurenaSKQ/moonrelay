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

// Generalized search primitives shared by the command palette and any
// other search-aware surface.  Paginates server results wherever the
// Matrix SDK exposes a cursor (messages, homeserver rooms); local
// results (joined rooms/spaces, user directory) are filtered in-place
// from the client's cache and paged locally by index offset so the
// palette can scroll-fetch progressively.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';

/// A logical category of search results.
///
/// Each category may load synchronously (local rooms/spaces) or require
/// an asynchronous network round-trip (server message search, user
/// directory, homeserver public rooms).  Different surfaces can choose
/// to render only a subset — the command palette's `?` mode keeps the
/// full set, while an in-room search would only request messages.
enum SearchCategory {
  rooms,
  spaces,
  messages,
  users,
  homeserver,
}

/// A single page of search results plus an opaque continuation cursor.
///
/// [hasMore] reports whether the server (or local cache) still has
/// results left to fetch.  When [nextBatch] is non-null it should be
/// passed to the next [SearchPageRequest] to resume; when it is null
/// but [hasMore] is true, the local cache has more entries that the
/// caller can paginate by stepping [offset].
class SearchPage<T> {
  const SearchPage({
    required this.items,
    required this.hasMore,
    this.nextBatch,
    this.offset,
  });

  /// Creates an empty page signifying "no more results".
  ///
  /// Implemented as a named constructor (rather than a static
  /// factory) so the [T] generic flows through `const` contexts and
  /// reads naturally at call sites that already pin the type.
  const SearchPage.empty()
      : items = const <Never>[],
        hasMore = false,
        nextBatch = null,
        offset = null;

  /// Results for this page.
  final List<T> items;

  /// True when more results are available beyond this page.
  final bool hasMore;

  /// Server-provided cursor (e.g. search `next_batch`).
  final String? nextBatch;

  /// Local-cache offset, used for client-side pagination of lists that
  /// the SDK has no cursor for (e.g. joined rooms / users).
  final int? offset;
}

/// Coordinates a single, in-flight search page request.
///
/// Callers that want to fetch the next page can pass this request back
/// into [SearchProvider.searchMessagesPage].  For local-cache queries
/// only the [offset] field is meaningful; for messages
/// [nextBatch] is used; user-directory searches and joined-rooms
/// searches have no cursors and are paginated locally via [offset].
class SearchPageRequest {
  const SearchPageRequest({this.query, this.nextBatch, this.offset = 0});
  final String? query;
  final String? nextBatch;
  final int offset;
}

/// Pure search provider.  Wraps the Matrix SDK calls so any UI surface
/// (the command palette, an in-room search panel, a quick-jump modal)
/// can request the same data with one call.
///
/// Lifecycle: created per-search-session, disposed when the call site
/// tears down (typically when the palette closes).  Each request
/// returns a [SearchPage] that the caller can render.
class SearchProvider {
  SearchProvider({required this.client});

  final Client client;

  /// First page of joined room/space matches.  Local searches have no
  /// server cursor — the caller paginates by stepping [offset] using
  /// [nextLocalPage].
  SearchPage<Room> searchRoomsFirstPage(String query, {int limit = 10}) {
    return _paginateLocal(
      _filterLocal(query, includeSpaces: false),
      0,
      limit,
    );
  }

  /// Continuation page for the rooms/joined-rooms query.  Pass the
  /// [SearchPageRequest.offset] returned by the previous page.
  SearchPage<Room> nextRoomsPage(
    SearchPageRequest request, {
    int limit = 10,
  }) {
    return _paginateLocal(
      _filterLocal(request.query ?? '', includeSpaces: false),
      request.offset,
      limit,
    );
  }

  /// First page of joined space matches.
  SearchPage<Room> searchSpacesFirstPage(String query, {int limit = 10}) {
    return _paginateLocal(
      _filterLocal(query, includeSpaces: true),
      0,
      limit,
    );
  }

  /// Continuation page for the spaces query.
  SearchPage<Room> nextSpacesPage(
    SearchPageRequest request, {
    int limit = 10,
  }) {
    return _paginateLocal(
      _filterLocal(request.query ?? '', includeSpaces: true),
      request.offset,
      limit,
    );
  }

  /// Filter `client.rooms` by display-name; synchronous.
  List<Room> _filterLocal(String query, {required bool includeSpaces}) {
    final q = query.toLowerCase();
    final rooms = <Room>[];
    for (final room
        in client.rooms.where((r) => r.membership == Membership.join)) {
      final name = room.getLocalizedDisplayname().toLowerCase();
      if (!name.contains(q)) continue;
      if (room.isSpace == !includeSpaces) {
        rooms.add(room);
      }
    }
    return rooms;
  }

  /// Slice [source] starting at [offset], returning a page of [limit]
  /// items and the cursor information needed for the next request.
  SearchPage<T> _paginateLocal<T>(List<T> source, int offset, int limit) {
    if (source.isEmpty) return SearchPage<T>.empty();
    final end = (offset + limit).clamp(0, source.length);
    final slice = source.sublist(offset, end);
    final hasMore = end < source.length;
    return SearchPage<T>(
      items: slice,
      hasMore: hasMore,
      offset: offset,
    );
  }

  /// Server-side full-text message search — first page.
  Future<SearchPage<MessageSearchResult>> searchMessagesFirstPage(
    String query, {
    int limit = 20,
  }) async {
    return _searchMessages(query, limit: limit);
  }

  /// Continuation page for the messages query.  Pass the
  /// [SearchPageRequest.nextBatch] returned by the previous page back as
  /// the `since` token.
  Future<SearchPage<MessageSearchResult>> searchMessagesNextPage(
    SearchPageRequest request, {
    int limit = 20,
  }) async {
    return _searchMessages(
      request.query ?? '',
      limit: limit,
      nextBatch: request.nextBatch,
    );
  }

  Future<SearchPage<MessageSearchResult>> _searchMessages(
    String query, {
    required int limit,
    String? nextBatch,
  }) async {
    if (query.isEmpty) return SearchPage<MessageSearchResult>.empty();
    try {
      final results = await client.search(
        Categories(
          roomEvents: RoomEventsCriteria(
            searchTerm: query,
            filter: SearchFilter(limit: limit),
          ),
        ),
        nextBatch: nextBatch,
      );
      final roomEvents = results.searchCategories.roomEvents;
      final list = roomEvents?.results ?? [];
      final rooms = client.rooms;
      final messages = <MessageSearchResult>[];
      for (final result in list) {
        final event = result.result;
        if (event == null) continue;
        final roomId = event.roomId;
        final room = rooms.firstWhere(
          (r) => r.id == roomId,
          orElse: () => rooms.first,
        );
        messages.add(MessageSearchResult(
          event: Event.fromMatrixEvent(event, room),
          room: room,
          rank: result.rank ?? 0,
        ));
      }
      final returnedNext = roomEvents?.nextBatch;
      return SearchPage<MessageSearchResult>(
        items: messages,
        hasMore: (returnedNext ?? '').isNotEmpty,
        nextBatch: returnedNext,
      );
    } catch (_) {
      return SearchPage<MessageSearchResult>.empty();
    }
  }

  /// Public homeserver room directory search — first page.
  Future<SearchPage<PublishedRoomsChunk>> searchHomeserverFirstPage(
    String query, {
    int limit = 10,
  }) =>
      _searchHomeserver(query, limit: limit, since: null);

  /// Public homeserver room directory search — continuation.
  Future<SearchPage<PublishedRoomsChunk>> searchHomeserverNextPage(
    SearchPageRequest request, {
    int limit = 10,
  }) =>
      _searchHomeserver(request.query ?? '', limit: limit, since: request.nextBatch);

  Future<SearchPage<PublishedRoomsChunk>> _searchHomeserver(
    String query, {
    required int limit,
    String? since,
  }) async {
    if (query.isEmpty) return SearchPage<PublishedRoomsChunk>.empty();
    try {
      final response = await client.queryPublicRooms(
        filter: PublicRoomQueryFilter(genericSearchTerm: query),
        limit: limit,
        since: since,
      );
      return SearchPage<PublishedRoomsChunk>(
        items: response.chunk,
        hasMore: (response.nextBatch ?? '').isNotEmpty,
        nextBatch: response.nextBatch,
      );
    } catch (_) {
      return SearchPage<PublishedRoomsChunk>.empty();
    }
  }

  /// User-directory search — paginated locally because the Matrix
  /// endpoint doesn't return a cursor.
  SearchPage<Profile> searchUsersFirstPage(String query, {int limit = 10}) {
    if (query.isEmpty) return SearchPage<Profile>.empty();
    return _paginateLocal(_lastUserResults(query), 0, limit);
  }

  SearchPage<Profile> nextUsersPage(
    SearchPageRequest request, {
    int limit = 10,
  }) {
    if ((request.query ?? '').isEmpty) return SearchPage<Profile>.empty();
    return _paginateLocal(
      _lastUserResults(request.query!),
      request.offset,
      limit,
    );
  }

  /// Cache the most recent user-directory fetch so we don't re-query
  /// on every scroll-fetch.  The first call to [searchUsersFirstPage]
  /// invalidates the cache by refreshing; subsequent [nextUsersPage]
  /// calls read from it.
  String? _userResultsQuery;
  List<Profile> _userResults = const [];

  /// Fetch the directory and cache it.  Used by the palette in the
  /// `?` and `@` modes.
  Future<SearchPage<Profile>> fetchUsersPage(
    String query, {
    int limit = 30,
  }) async {
    if (query.isEmpty) return SearchPage<Profile>.empty();
    if (_userResultsQuery == query) {
      return _paginateLocal(_userResults, 0, limit);
    }
    try {
      final response = await client.searchUserDirectory(query, limit: limit);
      _userResultsQuery = query;
      _userResults = response.results;
      // The Matrix endpoint trims to its default limit (10) and has no
      // cursor; we honour [limit] for the first page and clamp the
      // remainder to no more entries.
      return _paginateLocal(_userResults, 0, limit);
    } catch (_) {
      return SearchPage<Profile>.empty();
    }
  }

  List<Profile> _lastUserResults(String query) {
    if (_userResultsQuery != query) return const [];
    return _userResults;
  }
}

/// A single ranked message result that pairs a Matrix event with the
/// room it lives in.  Reused by every search-aware UI surface.
class MessageSearchResult {
  const MessageSearchResult({
    required this.event,
    required this.room,
    required this.rank,
  });
  final Event event;
  final Room room;
  final double rank;
}

// ─── Tiles ────────────────────────────────────────────────────────────────────

/// Tile widgets for each search category.  Kept here so the palette
/// and any future search surface render identical rows without
/// duplicating markup.

/// Row for a joined room or space match.
class SearchRoomTile extends StatelessWidget {
  const SearchRoomTile({super.key, required this.room, this.onTap});
  final Room room;
  final VoidCallback? onTap;

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

/// Row for a server-side message match.
class SearchMessageTile extends StatelessWidget {
  const SearchMessageTile({super.key, required this.result, this.onTap});
  final MessageSearchResult result;
  final VoidCallback? onTap;

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

/// Row for a homeserver-public-room match.
class SearchHomeserverTile extends StatelessWidget {
  const SearchHomeserverTile({super.key, required this.room, this.onTap});
  final PublishedRoomsChunk room;
  final VoidCallback? onTap;

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

/// Row for a user-directory match.
class SearchUserTile extends StatelessWidget {
  const SearchUserTile({super.key, required this.user, this.onTap});
  final Profile user;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final displayName = user.displayName ?? user.userId;
    return ListTile(
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: scheme.primaryContainer,
        backgroundImage: user.avatarUrl != null
            ? NetworkImage(user.avatarUrl.toString())
            : null,
        child: user.avatarUrl == null
            ? Icon(
                LucideIcons.user,
                size: 16,
                color: scheme.onPrimaryContainer,
              )
            : null,
      ),
      title: Text(
        displayName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      subtitle: Text(
        user.userId,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 12,
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Icon(
        LucideIcons.externalLink,
        size: 14,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
      ),
      dense: true,
      onTap: onTap,
    );
  }
}

// ─── Section header ──────────────────────────────────────────────────────────

/// Reusable section header used by every search-aware UI surface.
class SearchSectionHeader extends StatelessWidget {
  const SearchSectionHeader({super.key, required this.icon, required this.title});
  final IconData icon;
  final String title;

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

// ─── Navigation helpers ──────────────────────────────────────────────────────

/// Navigates to a [Room] for search results.
void navigateToRoom(BuildContext context, Room room) {
  context.pop();
  context.go('/main/rooms/${room.id}');
}

void navigateToMessageRoom(BuildContext context, MessageSearchResult msg) {
  context.pop();
  context.go('/main/rooms/${msg.room.id}');
}

void navigateToHomeserverRoom(BuildContext context, PublishedRoomsChunk room) {
  final alias = room.canonicalAlias ?? room.roomId;
  context.pop();
  context.go('/main/rooms/$alias');
}

void navigateToUser(BuildContext context, Profile user) {
  context.pop();
  context.push('/main/myprofile?user=${user.userId}');
}

// ─── Recent items persistence ────────────────────────────────────────────────

/// In-memory recent-rooms / recent-actions store.  The palette reads
/// from this so the recents list stays in sync without re-mounting.
class RecentActivity extends ChangeNotifier {
  RecentActivity._();
  static final RecentActivity instance = RecentActivity._();

  final List<String> _rooms = <String>[];
  final List<String> _actions = <String>[];
  static const int _maxRecents = 6;

  /// Read-only view, newest-first.
  List<String> get rooms => List.unmodifiable(_rooms);

  List<String> get actions => List.unmodifiable(_actions);

  void recordRoom(String roomId) {
    _rooms.remove(roomId);
    _rooms.insert(0, roomId);
    if (_rooms.length > _maxRecents) {
      _rooms.removeRange(_maxRecents, _rooms.length);
    }
    notifyListeners();
  }

  void recordAction(String actionKey) {
    _actions.remove(actionKey);
    _actions.insert(0, actionKey);
    if (_actions.length > _maxRecents) {
      _actions.removeRange(_maxRecents, _actions.length);
    }
    notifyListeners();
  }
}
