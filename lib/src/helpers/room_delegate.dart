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
import 'package:logger/logger.dart';
import 'package:moonrelay/src/layouts/empty_space.dart';
import 'package:moonrelay/src/screens/room_page.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// Routing delegate that resolves a room ID to a [RoomPage].
///
/// On paper every Matrix room ID starts with `!` and every alias with `#`,
/// but in practice URL-encoded path segments, unusual server deployments,
/// and edge-case IDs can slip past a naïve regex.  Instead of format-
/// checking we let the SDK decide: if [Client.getRoomById] returns a
/// [Room], we render it; otherwise we degrade gracefully.
///
/// If the first sync hasn't completed yet (no rooms loaded at all), a
/// loading indicator is shown instead of a failure state.
///
/// The optional [threadRootEventId] is forwarded to the [RoomPage] /
/// [ChatBox] so a deep link like `/main/rooms/!r:s?threadRoot=$evt`
/// opens the room with the composer wired to send replies into that
/// thread.
class RoomDelegate extends StatelessWidget {
  const RoomDelegate({
    super.key,
    required this.roomID,
    this.threadRootEventId,
  });
  final String? roomID;
  final String? threadRootEventId;

  @override
  Widget build(BuildContext context) {
    // `listen: false`: this delegate only consults
    // [Client.getRoomById] / [Client.rooms] once per build, so listening
    // would force the entire [RoomDelegate] (and therefore the timeline,
    // chat box, and right sidebar) to rebuild on every sync tick
    // which the Matrix SDK fires many times per second.
    final Client client = Provider.of<Client>(context, listen: false);

    // ── Null / empty check ──────────────────────────────────────
    if (roomID == null || roomID!.isEmpty) {
      _log(context, 'RoomDelegate: roomID is null or empty');
      return const EmptySpace();
    }

    // ── Look up the room via the SDK ────────────────────────────
    final Room? room = client.getRoomById(roomID!);
    if (room != null) {
      return RoomPage(room: room, threadRootEventId: threadRootEventId);
    }

    // ── Room not found yet ───────────────────────────────────────
    // If the client has *no* rooms at all the first sync hasn't
    // delivered the room list yet — show a spinner, not an error.
    if (client.rooms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // Room is genuinely not in our joined-list.  This can happen
    // when the URL references a room the user never joined, or when
    // a stale room ID is bookmarked after the user left.  Log it
    // and show an empty space.
    _log(
        context,
        'RoomDelegate: room "$roomID" not found among '
        '${client.rooms.length} joined rooms');
    return const EmptySpace();
  }

  void _log(BuildContext context, String message) {
    final Logger log = Provider.of<Logger>(context, listen: false);
    log.t(message);
  }
}

/// Extension on [RoomDelegate] that reads the optional `threadRoot`
/// query parameter from the route and forwards it to the delegate.
extension RoomDelegateWithThread on RoomDelegate {
  static Widget fromState(BuildContext context) {
    final state = GoRouterState.of(context);
    return RoomDelegate(
      roomID: state.pathParameters['roomid'],
      threadRootEventId: state.uri.queryParameters['threadRoot'],
    );
  }
}
