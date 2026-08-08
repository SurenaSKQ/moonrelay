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
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_page.dart';
import 'package:moonrelay/src/screens/room_preview_screen.dart';
import 'package:moonrelay/src/widgets/empty_state.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// Routing delegate that resolves a room ID to a [RoomPage].
///
/// On paper every Matrix room ID starts with `!` and every alias with `#`,
/// but in practice URL-encoded path segments, unusual server deployments,
/// and edge-case IDs can slip past a naive regex.  Instead of format-
/// checking we let the SDK decide: if [Client.getRoomById] returns a
/// [Room], we render it; otherwise we degrade gracefully.
///
/// If the first sync hasn't completed yet (no rooms loaded at all), a
/// loading indicator is shown.  After 8 seconds without rooms a [Retry]
/// button and an explanatory message replace the spinner.  The timer
/// resets whenever a sync populates the room list.
///
/// The optional [threadRootEventId] is forwarded to the [RoomPage] /
/// [ChatBox] so a deep link like `/main/rooms/!r:s?threadRoot=$evt`
/// opens the room with the composer wired to send replies into that
/// thread.
class RoomDelegate extends StatefulWidget {
  const RoomDelegate({
    super.key,
    required this.roomID,
    this.threadRootEventId,
  });
  final String? roomID;
  final String? threadRootEventId;

  @override
  State<RoomDelegate> createState() => _RoomDelegateState();
}

class _RoomDelegateState extends State<RoomDelegate> {
  static const Duration _retryTimeout = Duration(seconds: 8);
  Timer? _retryTimer;
  bool _showRetry = false;

  SyncPulse? _pulse;
  void Function()? _pulseListener;

  @override
  void initState() {
    super.initState();
    _startRetryTimer();
    // Register for sync ticks so the retry timer resets when rooms arrive.
    // We do this in a post-frame callback because SyncPulse may not be
    // available during the first frame (e.g. during login transition).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final pulse = maybeSyncPulse(context);
      if (pulse != null) {
        _pulse = pulse;
        _pulseListener = _onSyncTick;
        pulse.addListener(_pulseListener!);
      }
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
    // Reset the retry timer whenever a sync arrives — the room may
    // appear on the next tick after the sender's server propagates it.
    _retryTimer?.cancel();
    _showRetry = false;
    _retryTimer = Timer(_retryTimeout, () {
      if (mounted) setState(() => _showRetry = true);
    });
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

    // -- Null / empty check --------------------------------------
    if (widget.roomID == null || widget.roomID!.isEmpty) {
      final l10n = AppLocalizations.of(context);
      log.e('RoomDelegate: roomID is null or empty',
          stackTrace: StackTrace.current, time: DateTime.now());
      return EmptyState(
        icon: Icons.error_outline,
        title: l10n?.error ?? 'Error',
        message: l10n?.roomNotFound ?? 'Room not found',
        actionLabel: l10n?.back ?? 'Back',
        onAction: () => GoRouter.of(context).pop(),
      );
    }

    // -- Look up the room via the SDK ----------------------------
    final Room? room = client.getRoomById(widget.roomID!);
    if (room != null) {
      return RoomPage(room: room, threadRootEventId: widget.threadRootEventId);
    }

    // -- Room not found yet ---------------------------------------
    if (client.rooms.isEmpty) {
      return _buildWaitingUi(context);
    }

    // The ID references a room the user has not joined (or has left).
    // Rather than a blank splash, hand off to the existing preview screen
    // which can resolve the room identity and offer a Join button.
    return RoomPreviewScreen(roomId: widget.roomID!);
  }

  Widget _buildWaitingUi(BuildContext context) {
    if (_showRetry) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off,
                  size: 48,
                  color: Theme.of(context).colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                'Still waiting for the server…',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                onPressed: () {
                  setState(() {
                    _showRetry = false;
                    _startRetryTimer();
                  });
                },
              ),
            ],
          ),
        ),
      );
    }

    return const Center(child: CircularProgressIndicator());
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
