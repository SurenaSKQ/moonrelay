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

import 'package:moonrelay/src/widgets/empty_state.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_page.dart';
import 'package:moonrelay/src/screens/room_preview_screen.dart';
import 'package:provider/provider.dart';

/// Turns a room id from the URL into the right surface for it.
///
/// A room id in the URL is a *claim*, not a fact: the room may already be
/// in the sync cache, it may be known but not joined, or it may not have
/// arrived yet because the first sync has not completed. Each of those is a
/// different thing to show the user, so the decision lives here rather than
/// being smeared across route builders.
///
/// This replaces `RoomDelegate`, which did the same job but accepted a
/// nullable id and answered a missing room with an error card. That made
/// `/main/rooms` (the dashboard with no room selected) render
/// "Room not found", because "no room selected" and "bad room id" were the
/// same code path. The absence of a room is now the router's business and
/// it never constructs this widget; a room id here is always a real one.
class RoomResolver extends StatefulWidget {
  const RoomResolver({
    super.key,
    required this.roomId,
    this.threadRootEventId,
    this.focusEventId,
  });

  /// The room to resolve. Never empty for a route that matched `:roomid`.
  final String roomId;

  /// Optional `m.thread` root to wire the composer against, from the
  /// `?threadRoot=` query parameter.
  final String? threadRootEventId;

  /// Optional event to focus once the room is on screen, from the
  /// `?event=` query parameter.  Set by event permalinks
  /// (`matrix.to/#/!room/$event`).  The timeline loads a history window
  /// if the event is older than the local cache.
  final String? focusEventId;

  @override
  State<RoomResolver> createState() => _RoomResolverState();
}

class _RoomResolverState extends State<RoomResolver> {
  /// How long to wait on a room that simply has not arrived before we
  /// stop spinning and offer a retry. Generous on purpose: the first sync
  /// of a large session can take a while, and a premature "not found"
  /// reads as a server problem rather than a slow one.
  static const Duration _retryTimeout = Duration(seconds: 8);

  Timer? _retryTimer;
  bool _showRetry = false;

  SyncPulse? _pulse;
  void Function()? _pulseListener;

  @override
  void initState() {
    super.initState();
    _startRetryTimer();
    // SyncPulse is owned above the router and is not mounted yet during
    // the first frame, so bind on the next one. Absence is fine: the
    // timer simply stops resetting early.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pulse = maybeSyncPulse(context);
      if (pulse == null) return;
      _pulse = pulse;
      _pulseListener = _onSyncTick;
      pulse.addListener(_pulseListener!);
    });
  }

  void _startRetryTimer() {
    _retryTimer?.cancel();
    _showRetry = false;
    _retryTimer = Timer(_retryTimeout, () {
      if (mounted) setState(() => _showRetry = true);
    });
  }

  void _onSyncTick() {
    // Syncs have started arriving, so the room is worth waiting for.
    if (_showRetry) return;
    _startRetryTimer();
  }

  @override
  void dispose() {
    _retryTimer?.cancel();
    if (_pulse != null && _pulseListener != null) {
      _pulse!.removeListener(_pulseListener!);
    }
    _pulse = null;
    _pulseListener = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);

    if (widget.roomId.isEmpty) {
      log.e('RoomResolver: empty room id',
          stackTrace: StackTrace.current, time: DateTime.now());
      return _notFound(context);
    }

    final Room? room = client.getRoomById(widget.roomId);
    if (room != null) {
      return RoomPage(
        room: room,
        threadRootEventId: widget.threadRootEventId,
        focusEventId: widget.focusEventId,
      );
    }

    // Nothing has arrived yet. Distinguish "the sync cache is still empty"
    // from "the server knows about this room but the user has not joined
    // it": only the first case is worth waiting on.
    if (client.rooms.isEmpty) {
      return _buildWaitingUi(context);
    }

    // Known to the server but not joined. Hand off to the preview screen,
    // which can resolve the room and offer a Join button.
    return RoomPreviewScreen(roomId: widget.roomId);
  }

  Widget _notFound(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(child: Text(l10n.roomNotFound));
  }

  Widget _buildWaitingUi(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_showRetry) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.cloud_off,
                size: 48,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.stillWaitingForServer,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(l10n.retry),
                onPressed: () => setState(_startRetryTimer),
              ),
            ],
          ),
        ),
      );
    }
    return PaneLoading(label: AppLocalizations.of(context)!.loading);
  }
}
