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
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/room_search_field.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/encryption_badge.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';
import 'package:moonrelay/src/widgets/sidebar_row.dart';
import 'package:provider/provider.dart';

/// Scoped, per-client thumbnail cache for room avatars.
///
/// Previously this cache was a static field on [RoomsPane], which meant it
/// survived client switches (privacy hazard) and grew unbounded across logins.
/// The cache is now keyed by [Client] and uses the [Client.hashCode] identity
/// for storage; when the owning client is garbage-collected the entries
/// follow.
class _ClientThumbnailCache {
  _ClientThumbnailCache(this.client);

  final Client client;
  final Map<String, Future<Uri?>> _cache = {};
  final List<String> _lruOrder = [];
  static const int _maxEntries = 256;

  Future<Uri?> getOrCompute(String key, Future<Uri?> Function() compute) {
    final cached = _cache[key];
    if (cached != null) {
      // Touch the LRU position.
      _lruOrder.remove(key);
      _lruOrder.add(key);
      return cached;
    }
    final fresh = compute();
    _cache[key] = fresh;
    _lruOrder.add(key);
    while (_lruOrder.length > _maxEntries) {
      final oldest = _lruOrder.removeAt(0);
      _cache.remove(oldest);
    }
    return fresh;
  }

  void clear() {
    _cache.clear();
    _lruOrder.clear();
  }
}

/// The room filters the navigation surfaces select between.
///
/// These live here rather than at each call site because three separate
/// implementations had drifted: the expanded sidebar, the compact sidebar
/// and the single-pane list each rolled their own predicate. They are
/// deliberately *named* rather than inlined, because the difference
/// between them is a correctness question, not a style one. Every one of
/// them excludes spaces, and a space opened through [RoomsPane] resolves
/// to a chat view of a room that is not a room.
bool roomIsDirectChat(Room room) => room.isDirectChat;

/// Every joined room that is a real room, i.e. not a space.
bool roomIsChat(Room room) => !room.isSpace;

/// Only spaces, which are never opened as a chat.
bool roomIsSpace(Room room) => room.isSpace;

/// A scrollable list of rooms, optionally filtered by [roomFilter].
///
/// If [roomFilter] is `null`, every room the user is a member of is shown.
/// Otherwise only rooms for which the predicate returns `true` are shown.
/// Pass one of [roomIsDirectChat], [roomIsChat] or [roomIsSpace] rather
/// than an inline predicate: a `null` filter means "including spaces",
/// which is almost never what a room list wants.
class RoomsPane extends StatefulWidget {
  /// An optional filter predicate. Return `true` to include a room.
  final bool Function(Room room)? roomFilter;

  const RoomsPane({
    super.key,
    this.roomFilter,
  });

  @override
  State<RoomsPane> createState() => _RoomsPaneState();
}

class _RoomsPaneState extends State<RoomsPane> {
  /// Per-client thumbnail caches. Keyed by Client.userID so a logout/cleanup
  /// path can simply drop the matching entry instead of nuking everything.
  static final Map<String, _ClientThumbnailCache> _clientCaches = {};

  /// Holds the latest filtered rooms. Updated via the shared [SyncPulse]
  /// (a single debounced fan-out for the whole app) so multiple panes
  /// don't all subscribe to `client.onSync.stream` and produce 3-5
  /// rebuilds per tick.
  List<Room>? _filteredRooms;
  int _lastFilteredVersion = -1;

  int? _subscribedClientId;

  /// Returns the per-client thumbnail cache for [client].
  static _ClientThumbnailCache _cacheFor(Client client) {
    return _clientCaches.putIfAbsent(
      _clientKey(client),
      () => _ClientThumbnailCache(client),
    );
  }

  /// Stable key for [client]. Uses `userID` when available so a future
  /// re-login of the same account reuses the cache; falls back to the
  /// runtime hash only as a last resort.
  static String _clientKey(Client client) {
    final id = client.userID;
    if (id != null && id.isNotEmpty) return id;
    return 'anon:${identityHashCode(client)}';
  }

  /// Cached thumbnail promise for [key], scoped to the active [client].
  static Future<Uri?> cachedThumbnail(
    Client client,
    String key,
    Future<Uri?> Function() compute,
  ) {
    return _cacheFor(client).getOrCompute(key, compute);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final client = Provider.of<Client>(context, listen: false);
    _ensureSubscription(client);
  }

  @override
  void initState() {
    super.initState();
    RoomSearchQuery.query.addListener(_onSearchChanged);
  }

  void _ensureSubscription(Client client) {
    final id = identityHashCode(client);
    if (id == _subscribedClientId) return;
    _subscribedClientId = id;

    // Seed the initial value synchronously so the first frame has data.
    _filteredRooms = _applyFilter(widget.roomFilter, client.rooms);
    _lastFilteredVersion = context.read<SyncPulse>().version;
  }

  /// Called from [build] whenever the sync pulse version changes.
  /// Coalesces rebuilds into one [setState] per debounced pulse.
  void _onPulseChange(int version) {
    if (version == _lastFilteredVersion) return;
    _lastFilteredVersion = version;
    final client = Provider.of<Client>(context, listen: false);
    if (!mounted) return;
    setState(() {
      _filteredRooms = _applyFilter(widget.roomFilter, client.rooms);
    });
  }

  static List<Room> _applyFilter(
    bool Function(Room)? filter,
    List<Room> rooms,
  ) {
    final predicateOnly =
        filter == null ? rooms : rooms.where(filter).toList();

    // The text filter is applied here rather than in the list's builder so
    // the empty and no-match states can tell each other apart. Matching only
    // the name and alias is a deliberate limit: the sidebar shows a name and
    // a topic, and a search that silently ignored the topic the user can see
    // would be worse than one that does not pretend to search messages.
    final query = RoomSearchQuery.query.value.trim().toLowerCase();
    if (query.isEmpty) return List<Room>.unmodifiable(predicateOnly);

    return List<Room>.unmodifiable(
      predicateOnly.where((room) {
        final name = room.getLocalizedDisplayname().toLowerCase();
        if (name.contains(query)) return true;
        final alias = room.canonicalAlias.toLowerCase();
        return alias.contains(query);
      }),
    );
  }

  @override
  void didUpdateWidget(RoomsPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    final client = Provider.of<Client>(context, listen: false);
    // Re-filter synchronously when the predicate changes so we don't have to
    // wait for the next sync tick.
    setState(() {
      _filteredRooms = _applyFilter(widget.roomFilter, client.rooms);
    });
  }

  @override
  void dispose() {
    // A direct subscription rather than `context.select`: the search query is
    // a process-wide `ValueNotifier`, not a provider, and a pane that
    // outlives the shell's provider scope would throw looking one up. The
    // listener is removed here, so the static notifier cannot keep a
    // disposed pane alive.
    RoomSearchQuery.query.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    // The empty states branch on the query, so a keystroke that changes
    // nothing else still has to rebuild. `setState` rather than a targeted
    // notifier because the filter feeds both the list and the empty state.
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // Read the client without subscribing: we already drive our own
    // rebuilds via the shared [SyncPulse] (debounced 350 ms by the
    // app-wide fan-out). Subscribing here would cause every Client
    // notification (every sync tick, every key verification event,
    // every room addition, etc.) to rebuild the entire pane even when
    // the filtered rooms list hasn't changed.
    final Client client;
    try {
      client = Provider.of<Client>(context, listen: false);
    } catch (_) {
      // Client may be absent during the logout transition before the
      // route changes away from the dashboard.  Return a no-op widget
      // for that one frame instead of crashing.
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    // React to the debounced sync pulse without subscribing to the
    // client itself. _onPulseChange compares against the cached
    // version and only setStates when the filtered set might have
    // changed.
    final pulseVersion = context.select<SyncPulse, int>((p) => p.version);
    _onPulseChange(pulseVersion);

    final filtered = _filteredRooms;

    return Material(
      child: Builder(builder: (context) {
        // -- Error state: the last sync failed and there is nothing to show
        //
        // This branch has to come before the loading branch, because a
        // client that can never sync stays "not yet synced" forever and
        // would otherwise spin indefinitely.
        //
        // The signal is the *current* sync status, not `client.syncError`.
        // The SDK sets `syncError` on a failure and never clears it, so it
        // means "a sync failed at some point" rather than "sync is failing
        // now", and using it here would leave one transient blip showing a
        // permanent error to a client that has been syncing fine since.
        //
        // There is no retry button. The SDK's sync loop already retries every
        // few seconds and exposes no way to force one, so a button here would
        // do nothing at all. Saying what is happening is the honest
        // affordance.
        if (filtered != null &&
            filtered.isEmpty &&
            !_hasReceivedSync(client) &&
            _hasSyncError(client)) {
          return EmptyState(
            icon: LucideIcons.cloudOff,
            title: l10n.syncFailedTitle,
            message: l10n.syncFailedDescription,
          );
        }

        // -- Loading state: waiting for initial sync ----------------
        if (filtered == null ||
            (filtered.isEmpty && !_hasReceivedSync(client))) {
          return PaneLoading(label: l10n.loadingRooms);
        }

        // -- Empty state: synced but no matching rooms ---------------
        if (filtered.isEmpty) {
          // Two different empty states, because "you have joined nothing"
          // and "your filter matched nothing" call for opposite reactions.
          // Collapsing them into one message is how a user ends up clearing
          // a filter they did not set.
          final query = RoomSearchQuery.query.value.trim();
          if (query.isNotEmpty) {
            return EmptyState(
              icon: LucideIcons.searchX,
              title: l10n.noRoomsMatch(query),
              message: l10n.noRoomsMatchHint,
              actionLabel: l10n.clearSearch,
              onAction: RoomSearchQuery.clear,
            );
          }
          return Center(
            child: Padding(
              padding: EdgeInsets.all(t.spaceXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.messageCircle,
                    size: 40,
                    color: scheme.onSurfaceVariant.withValues(
                      alpha: t.opacityDisabled,
                    ),
                  ),
                  SizedBox(height: t.spaceMd),
                  Text(
                    l10n.noRoomsYet,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return ListView.builder(
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final Room room = filtered[index];
            final rawName = room.getLocalizedDisplayname().trim();
            final displayname = rawName.isEmpty
                ? AppLocalizations.of(context)!.untitledRoom
                : room.getLocalizedDisplayname();

            return _RoomRow(
              room: room,
              client: client,
              scheme: scheme,
              displayname: displayname,
              onTap: () => _joinRoom(context, room),
            );
          },
        );
      }),
    );
  }

  /// Returns true if the SDK has produced at least one sync tick.
  ///
  /// We don't have a direct flag for this, so we use `client.rooms.isNotEmpty`
  /// and `client.prevBatch` as proxies and fall back to the cached
  /// initial-state assumption.
  ///
  /// A completed sync counts, whichever way the other two fall. Without that,
  /// an account with genuinely no rooms never satisfies either proxy, and the
  /// pane sat on "Loading rooms..." forever instead of showing its empty
  /// state. A finished sync *is* the answer, even when the answer is nothing.
  bool _hasReceivedSync(Client client) {
    if (client.prevBatch != null || client.rooms.isNotEmpty) return true;
    try {
      return client.onSyncStatus.value?.status == SyncStatus.finished;
    } catch (_) {
      // Not in tree, or the client is being torn down. Neither means a sync
      // completed, so the conservative answer is "not yet".
      return false;
    }
  }

  /// Whether the client's most recent sync status was an error.
  ///
  /// Reads the cached status rather than subscribing: [RoomsPane] already
  /// rebuilds on the debounced [SyncPulse], and a room arriving after a
  /// successful sync moves this pane off the error branch anyway.
  ///
  /// The catch is for the logout window, where the client is already gone
  /// and its status stream has nothing left to give.
  static bool _hasSyncError(Client client) {
    try {
      return client.onSyncStatus.value?.status == SyncStatus.error;
    } catch (_) {
      // Not in tree, or the client is being torn down. Neither is an error
      // the user needs told about, and both are indistinguishable here.
      return false;
    }
  }
}

/// Joins the [room] (if not already a member) and navigates to it.
Future<void> _joinRoom(BuildContext context, Room room) async {
  final log = Provider.of<Logger>(context, listen: false);
  try {
    if (room.membership != Membership.join) {
      final result = await withRetry(
        () => room.join(),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'joinRoom',
      );
      if (result is RetryFailed) {
        throw (result).error;
      }
    }
    if (!context.mounted) return;
    openRoom(context, room.id);
  } catch (e) {
    log.f(
      'Failed to join',
      error: e,
      stackTrace: StackTrace.current,
      time: DateTime.now(),
    );
    if (!context.mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final message =
        e is TimeoutException ? l10n.couldNotJoinRoomTimeout : e.toString();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(AppLocalizations.of(context)!.error),
            Text(message),
          ],
        ),
      ),
    );
  }
}

/// A compact room avatar with a small unread dot overlaid at the
/// bottom-right corner when the room has new messages.
///
/// Uses the theme's [ColorScheme.error] for the dot and [ColorScheme.surface]
/// for the border so it integrates cleanly with light and dark themes.
class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({
    required this.room,
    required this.client,
    required this.scheme,
    this.size = 40,
  });

  final Room room;
  final Client client;
  final ColorScheme scheme;

  /// Edge length of the square avatar. Scaled down by the row in narrow
  /// panes, where a 40px avatar left too little room for the room name.
  final double size;

  @override
  Widget build(BuildContext context) {
    // The dot scales with the avatar so it does not swallow a small one.
    final double dot = size * 0.3;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // The avatar fills the available area.
          Positioned.fill(child: _buildAvatar()),
          // Unread dot: bottom-right, partially overlaps the avatar edge.
          if (room.hasNewMessages)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: dot,
                height: dot,
                decoration: BoxDecoration(
                  color: scheme.error,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: scheme.surface,
                    width: 2,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    final rawName = room.getLocalizedDisplayname().trim();
    final displayname = rawName.isEmpty ? '?' : rawName;
    final initials = _initialsForDisplayname(displayname);
    if (room.avatar == null) {
      return CircleAvatar(
        child: Text(initials),
      );
    }

    final cacheKey = '${room.id}::${room.avatar!.toString()}::56x56';
    return FutureBuilder<Uri?>(
      future: _RoomsPaneState.cachedThumbnail(
        client,
        cacheKey,
        () => withTimeoutOrFallback(
          () => room.avatar!.getThumbnailUri(
            client,
            method: ThumbnailMethod.scale,
            height: 56,
            width: 56,
          ),
          timeout: kDefaultTimeout,
          fallback: null,
        ),
      ),
      builder: (context, asyncSnapshot) {
        final uri = asyncSnapshot.data;
        if (uri != null) {
          return CircleAvatar(
            backgroundImage: NetworkImage(
              uri.toString(),
              headers: {
                'authorization': 'Bearer ${client.accessToken}',
              },
            ),
            onBackgroundImageError: (_, __) {},
          );
        }
        // Fallback to initials when the thumbnail hasn't loaded yet or failed.
        return CircleAvatar(
          child: Text(initials),
        );
      },
    );
  }

  /// Returns up to two uppercase initials for [displayname].
  ///
  /// Splits on whitespace and takes the first character of the first
  /// two non-empty parts.  `String.characters.firstOrNull` is used so
  /// the function is safe with empty parts and multi-byte Unicode
  /// (e.g. Persian, (CJK) displaynames; a direct `s[0]` would throw
  /// on an empty split or split grapheme boundaries mid-codepoint.
  String _initialsForDisplayname(String displayname) {
    final parts = displayname
        .toUpperCase()
        .split(RegExp(' +'))
        .where((p) => p.isNotEmpty);
    final buf = StringBuffer();
    for (final part in parts) {
      if (buf.length >= 2) break;
      final first = part.characters.firstOrNull;
      if (first != null) buf.write(first);
    }
    return buf.isEmpty ? '?' : buf.toString();
  }
}

/// Renders the unread/mention/highlight badges in the right gutter of
/// a room list row.
///
/// Priority: highlights (user mentioned by name) win over plain
/// mentions (read receipts / replies) and plain mentions win over a
/// silent unread count.  When the room has no notifications the
/// widget collapses to a zero-size placeholder so it never disrupts
/// the row's vertical rhythm.
class _RoomUnreadBadges extends StatelessWidget {
  const _RoomUnreadBadges({
    required this.notificationCount,
    required this.highlightCount,
  });

  final int notificationCount;
  final int highlightCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (highlightCount > 0) {
      // Highlights (direct @-mentions) get the highest visual weight:
      // a filled accent circle with the count, so the user can spot
      // a mention even at a glance.
      return _Badge(
        count: highlightCount,
        background: scheme.primary,
        foreground: scheme.onPrimary,
      );
    }
    if (notificationCount > 0) {
      // Plain unread (no 22mention): softer accent so it doesn't
      // compete with highlights when both could be present.
      return _Badge(
        count: notificationCount,
        background: scheme.primaryContainer,
        foreground: scheme.onPrimaryContainer,
      );
    }
    return const SizedBox.shrink();
  }
}

/// Single rounded pill showing a notification count.
class _Badge extends StatelessWidget {
  const _Badge({
    required this.count,
    required this.background,
    required this.foreground,
  });

  final int count;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 7),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(11),
      ),
      child: Text(
        count > 99 ? '99+' : '$count',
        style: TextStyle(
          color: foreground,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Lightweight custom replacement for [ListTile] in the room list.
///
/// [ListTile] is heavier than a hand-rolled [Row] + [InkWell] for the
/// simple "avatar + name + subtitle + badges" layout we use here. With
/// 200 rooms in a sidebar this swap measurably reduces paint time
/// during scroll.
///
/// The row scales its type and avatar to the width it is actually given,
/// not to the window. It is used in the navigation pane, where 200px is
/// the floor, and as the single-pane list's whole surface, where it gets
/// the full width; the 18/16px pair was chosen for the latter and
/// overflowed the former's name column into the badges. There used to be
/// a second, denser row widget for the narrow case, but it was a
/// regression rather than an adaptation: it dropped the encryption and
/// mention badges, so the honest fix was to make one row adapt.
class _RoomRow extends StatelessWidget {
  const _RoomRow({
    required this.room,
    required this.client,
    required this.scheme,
    required this.displayname,
    required this.onTap,
  });

  final Room room;
  final Client client;
  final ColorScheme scheme;
  final String displayname;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Subscribe to the *id* of the open room rather than the notifier, so a
    // room switch rebuilds exactly the two rows whose selected state flipped
    // instead of the whole pane. Every other row stays subscribed but is not
    // rebuilt, which matters at 200 rooms where this is the list's only
    // per-item work.
    final activeRoomId = context.select<CurrentRoom, String?>(
      (current) => current.room?.id,
    );
    return SidebarRow(
      title: displayname,
      subtitle: room.lastEvent?.body ?? l10n.noMessages,
      onTap: onTap,
      selected: activeRoomId == room.id,
      titleSuffix: RoomEncryptionBadge(room: room),
      leading: _RoomAvatar(
        room: room,
        client: client,
        scheme: scheme,
        size: sidebarMetricsFor(context).leadingSize,
      ),
      trailing: _RoomUnreadBadges(
        notificationCount: room.notificationCount,
        highlightCount: room.highlightCount,
      ),
    );
  }
}
