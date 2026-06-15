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
import 'package:logger/logger.dart';
import 'package:moonrelay/src/layouts/empty_space.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_page.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// Routing delegate that resolves a room ID to a [RoomPage].
///
/// Validates that:
/// - [roomID] is non-null, non-empty, and matches a Matrix room ID/alias
///   pattern (`!…:domain` or `#…:domain`).
/// - The room exists in the client's room list (joined or invited).
///
/// If the first sync hasn't completed yet (no rooms loaded at all), a
/// loading indicator is shown instead of an error — the room typically
/// appears moments later when the sync delivers the room list.
class RoomDelegate extends StatelessWidget {
  const RoomDelegate({super.key, required this.roomID});
  final String? roomID;

  /// Valid Matrix room IDs start with `!` or `#` and contain a `:`.
  static final _roomIdPattern = RegExp(r'^(!|#)[^:]+:.+');

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context);

    // ── Null / empty check ──────────────────────────────────────
    if (roomID == null || roomID!.isEmpty) {
      _log(context, 'RoomDelegate: roomID is null or empty');
      return const EmptySpace();
    }

    // ── Format validation ────────────────────────────────────────
    if (!_roomIdPattern.hasMatch(roomID!)) {
      _log(context, 'RoomDelegate: invalid roomID "$roomID"');
      return const EmptySpace();
    }

    // ── Look up the room ─────────────────────────────────────────
    final Room? room = client.getRoomById(roomID!);
    if (room != null) {
      return RoomPage(room: room);
    }

    // ── Room not found yet ───────────────────────────────────────
    // If the client has *no* rooms at all the first sync hasn't
    // delivered the room list yet — show a spinner, not an error.
    if (client.rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    return _buildNotJoinedError(context);
  }

  void _log(BuildContext context, String message) {
    final Logger log = Provider.of<Logger>(context, listen: false);
    log.w(message);
  }

  Widget _buildNotJoinedError(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 48, color: scheme.outline),
              const SizedBox(height: 16),
              Text(
                l10n.roomNotFound,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.roomNotFoundHint,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
