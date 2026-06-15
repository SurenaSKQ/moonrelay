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
/// - [roomID] is non-null and non-empty.
/// - [roomID] looks like a valid Matrix room ID or alias
///   (`!…:domain` or `#…:domain`).
/// - The room exists in the client's room list (the user must have already
///   joined or been invited to it).
///
/// If any check fails, an error state is shown instead of silently
/// displaying an empty placeholder.
class RoomDelegate extends StatelessWidget {
  const RoomDelegate({super.key, required this.roomID});
  final String? roomID;

  /// Valid Matrix room IDs start with `!` and contain a `:` (the server part).
  static final _roomIdPattern = RegExp(r'^(!|#).+:.+');

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context);

    // ── Null / empty check ──────────────────────────────────────
    if (roomID == null || roomID!.isEmpty) {
      _logAndShowError(context, 'RoomDelegate: roomID is null or empty');
      return const EmptySpace();
    }

    // ── Format validation ────────────────────────────────────────
    if (!_roomIdPattern.hasMatch(roomID!)) {
      _logAndShowError(context, 'RoomDelegate: invalid roomID "$roomID"');
      return const EmptySpace();
    }

    // ── Membership check ─────────────────────────────────────────
    final Room? room = client.getRoomById(roomID!);
    if (room == null) {
      _logAndShowError(
          context, 'RoomDelegate: room "$roomID" not found (not joined)');
      return _buildNotJoinedError(context);
    }

    return RoomPage(room: room);
  }

  void _logAndShowError(BuildContext context, String message) {
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
