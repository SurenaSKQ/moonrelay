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

import 'package:badges/badges.dart' as badges;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

class SpacesPane extends StatelessWidget {
  const SpacesPane({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context);
    final scheme = Theme.of(context).colorScheme;

    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: StreamBuilder(
            stream: client.onSync.stream,
            builder: (context, snapshot) {
              final bool hasSynced = snapshot.hasData;
              final rooms = client.rooms;

              // Loading state
              if (!hasSynced && rooms.isEmpty) {
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
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // Empty state
              if (rooms.isEmpty) {
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
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                itemCount: rooms.length,
                itemBuilder: (context, index) => ListTile(
                  leading: CircleAvatar(
                    foregroundImage: rooms[index].avatar == null
                        ? null
                        : NetworkImage(
                            rooms[index].avatar.toString(),
                          ),
                  ),
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          rooms[index].getLocalizedDisplayname(),
                        ),
                      ),
                    ],
                  ),
                  subtitle: Text(
                    rooms[index].lastEvent?.body ?? l10n.noMessages,
                    maxLines: 1,
                  ),
                  trailing: (rooms[index].notificationCount > 0)
                      ? badges.Badge(
                          child: Text(
                            rooms[index].notificationCount.toString(),
                          ),
                        )
                      : null,
                  onTap: () => _joinRoom(context, rooms[index]),
                ),
              );
            },
          ),
        ),
      ],
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
        label: 'spacesJoinRoom',
      );
      if (result is RetryFailed) {
        throw (result).error;
      }
    }
    if (!context.mounted) return;
    context.push('/rooms/${room.id}');
  } catch (e) {
    log.f(
      'Failed to join',
      error: e,
      stackTrace: StackTrace.current,
      time: DateTime.now(),
    );
    if (!context.mounted) return;
    final message = e is TimeoutException
        ? AppLocalizations.of(context)!.couldNotJoinRoomTimeout
        : e.toString();
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
