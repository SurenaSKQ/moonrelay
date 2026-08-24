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
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/encryption_badge.dart';
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

/// A scrollable list of rooms, optionally filtered by [roomFilter].
///
/// If [roomFilter] is `null`, every room the user is a member of is shown.
/// Otherwise only rooms for which the predicate returns `true` are shown
/// this is used by the navigation pane to display direct chats, all rooms,
/// or rooms belonging to a specific space.
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
      bool Function(Room)? filter, List<Room> rooms) {
    if (filter == null) return List<Room>.unmodifiable(rooms);
    return List<Room>.unmodifiable(rooms.where(filter));
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
    super.dispose();
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
        // -- Loading state: waiting for initial sync ----------------
        if (filtered == null ||
            (filtered.isEmpty && !_hasReceivedSync(client))) {
          return Center(
            child: Padding(
              padding: EdgeInsets.all(t.spaceXl),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: t.spaceXl,
                    height: t.spaceXl,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: scheme.primary,
                    ),
                  ),
                  SizedBox(height: t.spaceLg),
                  Text(
                    l10n.loadingRooms,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        // -- Empty state: synced but no matching rooms ---------------
        if (filtered.isEmpty) {
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
  /// as a proxy and fall back to the cached initial-state assumption.
  bool _hasReceivedSync(Client client) =>
      client.prevBatch != null || client.rooms.isNotEmpty;
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
    context.pushReplacement('/main/rooms/${room.id}');
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
  });

  final Room room;
  final Client client;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 40,
      height: 40,
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
                width: 12,
                height: 12,
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.spaceMd,
          vertical: t.spaceSm,
        ),
        child: Row(
          children: [
            _RoomAvatar(room: room, client: client, scheme: scheme),
            SizedBox(width: t.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          displayname,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w300,
                            fontSize: 18,
                          ),
                        ),
                      ),
                      RoomEncryptionBadge(room: room),
                    ],
                  ),
                  SizedBox(height: t.spaceXxs),
                  Text(
                    room.lastEvent?.body ?? l10n.noMessages,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w300,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: t.spaceSm),
            _RoomUnreadBadges(
              notificationCount: room.notificationCount,
              highlightCount: room.highlightCount,
            ),
          ],
        ),
      ),
    );
  }
}
