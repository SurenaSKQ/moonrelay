// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

/// The coarse presence state surfaced by the header status pill.
///
/// Maps the Matrix SDK's [SyncStatus] down to a three-state presence that
/// matches what a user expects to see in a header: a connection either
/// works (online), is actively catching up (away), or has dropped/erred
/// (offline). This is intentionally a coarse signal  real per-contact
/// Matrix presence is a separate concern left for future work.
enum PresenceState {
  /// Connected and the last sync completed cleanly.
  online,

  /// Connected; a sync is currently in flight (waiting, processing,
  /// cleaning up) so the view may be momentarily stale.
  away,

  /// The homeserver connection has errored or is unreachable.
  offline,
}

/// Maps a Matrix sync status to a coarse [PresenceState].
///
/// Kept as a pure function so both the header [SyncStatusPill] and the
/// [ApplicationStatusBar] label resolver consume a single source of truth
/// and cannot drift.
PresenceState syncStatusToPresence(SyncStatus status) {
  switch (status) {
    case SyncStatus.finished:
      return PresenceState.online;
    case SyncStatus.waitingForResponse:
    case SyncStatus.processing:
    case SyncStatus.cleaningUp:
      return PresenceState.away;
    case SyncStatus.error:
      return PresenceState.offline;
  }
}

/// The colour a presence dot should take for a given state.
Color presenceColor(PresenceState state, ColorScheme scheme) {
  switch (state) {
    case PresenceState.online:
      return const Color(0xFF4CAF50);
    case PresenceState.away:
      return const Color(0xFFFFC107);
    case PresenceState.offline:
      return scheme.onErrorContainer;
  }
}

/// The header status pill, reflecting the live sync/presence state.
///
/// Previously this widget hardcoded a green dot and the English text
/// "Online" regardless of connection, which misled users into thinking
/// they were connected when the homeserver had dropped. It now mirrors
/// [ApplicationStatusBar] by subscribing to [Client.onSyncStatus].
///
/// [syncStatusStream] and [initialStatus] are accepted so the widget is
/// testable without depending on the SDK's private [CachedStreamController]
/// export. In production they are left null and resolved from the
/// [Provider] tree.
class SyncStatusPill extends StatefulWidget {
  const SyncStatusPill({
    super.key,
    this.syncStatusStream,
    this.initialStatus,
  });

  /// Optional override for tests: a stream of sync status updates. When
  /// null, the pill reads [Client.onSyncStatus] from the provider tree.
  final Stream<SyncStatusUpdate>? syncStatusStream;

  /// Optional seed status used on first build. Defaults to the client's
  /// cached status when [syncStatusStream] is null.
  final SyncStatusUpdate? initialStatus;

  @override
  State<SyncStatusPill> createState() => _SyncStatusPillState();
}

class _SyncStatusPillState extends State<SyncStatusPill> {
  late PresenceState _presence;
  StreamSubscription<SyncStatusUpdate>? _sub;

  @override
  void initState() {
    super.initState();
    _presence = syncStatusToPresence(_initialSyncStatus() ?? SyncStatus.finished);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-subscribe whenever the provider-backed client changes (account
    // switch) or when no injected stream is supplied.
    _sub?.cancel();
    final stream = widget.syncStatusStream ?? _clientSyncStream();
    if (stream == null) {
      _presence = PresenceState.offline;
      if (mounted) setState(() {});
      return;
    }
    _sub = stream.listen((update) {
      final p = syncStatusToPresence(update.status);
      if (p != _presence && mounted) setState(() => _presence = p);
    });
    // Seed with the cached value if the injected stream has no initial.
    if (widget.initialStatus != null && widget.syncStatusStream == null) {
      _presence = syncStatusToPresence(_clientSyncStatus() ?? widget.initialStatus!.status);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Client? _client() {
    try {
      return Provider.of<Client>(context, listen: false);
    } catch (_) {
      return null;
    }
  }

  SyncStatus? _initialSyncStatus() {
    if (widget.initialStatus != null) return widget.initialStatus!.status;
    try {
      final cached = _client()?.onSyncStatus.value;
      return cached?.status;
    } catch (_) {
      return null;
    }
  }

  SyncStatus? _clientSyncStatus() {
    try {
      final cached = _client()?.onSyncStatus.value;
      return cached?.status;
    } catch (_) {
      return null;
    }
  }

  Stream<SyncStatusUpdate>? _clientSyncStream() {
    try {
      return _client()?.onSyncStatus.stream;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final String label;
    switch (_presence) {
      case PresenceState.online:
        label = l10n.statusOnline;
      case PresenceState.away:
        label = l10n.statusAway;
      case PresenceState.offline:
        label = l10n.statusOffline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: presenceColor(_presence, scheme),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: scheme.primary,
            ),
          ),
        ],
      ),
    );
  }
}
