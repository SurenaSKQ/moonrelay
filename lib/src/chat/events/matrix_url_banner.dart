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
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/matrix_uri_parser.dart';

/// A banner shown below a chat message that contains a Matrix URL (room,
/// user, or alias).
///
/// If the referenced room is already joined, the banner shows its display
/// name, avatar, and a "Go to Room" button.  For unjoined rooms or
/// aliases, a "Preview Room" button is shown instead.  For user links,
/// an "Open Profile" button is displayed.
class MatrixUrlBanner extends StatelessWidget {
  const MatrixUrlBanner({
    super.key,
    required this.result,
    required this.client,
  });

  /// The parsed matrix URI result.
  final MatrixUriResult result;

  /// The current Matrix [Client] used to look up rooms.
  final Client client;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (result.entityType == MatrixUriEntity.user) {
      return _buildUserBanner(context, theme);
    }

    return _buildRoomBanner(context, theme);
  }

  /// Banner for user entity URIs.
  Widget _buildUserBanner(BuildContext context, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primaryContainer,
                child: Icon(
                  LucideIcons.user,
                  size: 16,
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Matrix User',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      result.entityId,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _openUser(context),
                icon: const Icon(LucideIcons.externalLink, size: 16),
                label: const Text('Open Profile'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Banner for room / room-alias entity URIs.
  Widget _buildRoomBanner(BuildContext context, ThemeData theme) {
    // Check if the user has already joined this room.
    final room = client.getRoomById(result.entityId) ??
        _findRoomByAlias(result.entityId);
    final isJoined = room != null;

    final roomName = isJoined
        ? (room.name.isNotEmpty ? room.name : room.id)
        : (result.displayAlias ?? result.entityId);

    final avatarUri = isJoined ? room.avatar : null;

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withAlpha(100),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outlineVariant.withAlpha(80),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              _buildRoomAvatar(context, theme, avatarUri, isJoined),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      isJoined ? 'Room' : 'Room Preview',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      roomName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (!isJoined && result.entityId != roomName) ...[
                      const SizedBox(height: 2),
                      Text(
                        result.entityId,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontFamily: 'monospace',
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _openRoom(context, isJoined ? room : null),
                icon: Icon(
                  isJoined ? LucideIcons.messageSquare : LucideIcons.eye,
                  size: 16,
                ),
                label: Text(isJoined ? 'Go to Room' : 'Preview Room'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the room avatar  either a loaded avatar or a generic icon.
  Widget _buildRoomAvatar(
    BuildContext context,
    ThemeData theme,
    Uri? avatarUri,
    bool isJoined,
  ) {
    if (isJoined && avatarUri != null) {
      return CircleAvatar(
        radius: 16,
        backgroundImage: NetworkImage(
          avatarUri.toString(),
          headers: {
            'authorization': 'Bearer ${client.accessToken}',
          },
        ),
        backgroundColor: theme.colorScheme.primaryContainer,
        onBackgroundImageError: (_, __) {},
      );
    }
    return CircleAvatar(
      radius: 16,
      backgroundColor: theme.colorScheme.primaryContainer,
      child: Icon(
        isJoined ? LucideIcons.messageSquare : LucideIcons.hash,
        size: 16,
        color: theme.colorScheme.onPrimaryContainer,
      ),
    );
  }

  /// Navigates to a joined room or opens the preview screen.
  ///
  /// When [room] is non-null the joined-room route is used; otherwise the
  /// preview route is used so unjoined homeserver rooms still resolve to a
  /// useful page.  Navigation errors surface a snackbar so a mis-routed URI
  /// no longer silently does nothing.
  void _openRoom(BuildContext context, Room? room) {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (room != null) {
        // Navigate by resolved room ID (not alias) so RoomDelegate can
        // find it via getRoomById().
        context.push('/main/rooms/${Uri.encodeComponent(room.id)}');
      } else {
        context.push(
          '/main/room_preview/${Uri.encodeComponent(result.entityId)}',
        );
      }
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to open room: $e')),
      );
    }
  }

  /// Navigates to a user profile via the top-level profile route.
  ///
  /// Validation and error recovery:
  /// - Validates the userid matches the Matrix ID shape (`@localpart:domain`)
  ///   before opening; otherwise surfaces a snackbar and aborts.
  /// - Uses `context.go` against `/profile/:userid` so the navigation
  ///   decouples from any room route the banner is currently sitting
  ///   under -- previously this pushed to `/main/rooms/<userid>` which
  ///   silently failed because `RoomDelegate` couldn't resolve a userid
  ///   as a room id.
  void _openUser(BuildContext context) {
    final userId = result.entityId;
    if (!RegExp(r'^@.+:.+$').hasMatch(userId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Invalid Matrix user id: $userId')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    try {
      context.go('/profile/${Uri.encodeComponent(userId)}');
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text('Failed to open profile: $e')),
      );
    }
  }

  /// Searches joined rooms by canonical alias to find a matching room.
  Room? _findRoomByAlias(String aliasOrId) {
    for (final room in client.rooms) {
      if (room.canonicalAlias == aliasOrId) return room;
    }
    return null;
  }
}
