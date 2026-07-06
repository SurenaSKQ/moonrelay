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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

/// A scrollable list of rooms, optionally filtered by [roomFilter].
///
/// If [roomFilter] is `null`, every room the user is a member of is shown.
/// Otherwise only rooms for which the predicate returns `true` are shown —
/// this is used by the navigation pane to display direct chats, all rooms,
/// or rooms belonging to a specific space.
class RoomsPane extends StatelessWidget {
  /// An optional filter predicate. Return `true` to include a room.
  final bool Function(Room room)? roomFilter;

  const RoomsPane({
    super.key,
    this.roomFilter,
  });

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final l10n = AppLocalizations.of(context)!;
    return Material(
      child: StreamBuilder(
        stream: client.onSync.stream,
        builder: (context, snapshot) {
          // Determine whether the first sync has arrived yet.
          final bool hasSynced = snapshot.hasData;

          // Re-filter on every sync to pick up new rooms.
          final Iterable<Room> currentRooms = roomFilter != null
              ? client.rooms.where(roomFilter!)
              : client.rooms;

          // ── Loading state: waiting for initial sync ────────────────
          if (!hasSynced && currentRooms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: scheme.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
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

          // ── Empty state: synced but no matching rooms ───────────────
          if (currentRooms.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      LucideIcons.messageCircle,
                      size: 40,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
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
            itemCount: currentRooms.length,
            itemBuilder: (context, index) {
              final Room room = currentRooms.elementAt(index);

              return ListTile(
                leading:
                    _RoomAvatar(room: room, client: client, scheme: scheme),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        room.getLocalizedDisplayname(),
                        style: const TextStyle(
                            fontWeight: FontWeight.w300, fontSize: 18),
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  room.lastEvent?.body ?? l10n.noMessages,
                  maxLines: 1,
                  style: const TextStyle(
                    fontWeight: FontWeight.w300,
                    fontSize: 16,
                  ),
                ),
                onTap: () => _joinRoom(context, room),
              );
            },
          );
        },
      ),
    );
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
          // Unread dot – bottom-right, partially overlaps the avatar edge.
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
    final initials = _initialsForDisplayname(room.getLocalizedDisplayname());
    if (room.avatar == null) {
      return CircleAvatar(
        child: Text(initials),
      );
    }

    return FutureBuilder<Uri?>(
      future: withTimeoutOrFallback(
        () => room.avatar!.getThumbnailUri(
          client,
          method: ThumbnailMethod.scale,
          height: 56,
          width: 56,
        ),
        timeout: kDefaultTimeout,
        fallback: null,
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
  /// (e.g. Persian, CJK) displaynames — a direct `s[0]` would throw
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
