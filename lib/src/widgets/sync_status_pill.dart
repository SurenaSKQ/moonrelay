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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// The coarse connection state surfaced by the header status pill.
///
/// Derived from the SDK's [SyncStatus], and deliberately NOT the
/// account's Matrix presence: `away` here means "a sync is in flight"
/// and `offline` means "the last sync errored", neither of which is what
/// `PresenceType.offline` means to anyone else reading this code. The
/// real presence lives in `PresenceService`, and other people's presence
/// in `PresenceBus`. This used to be called `PresenceState`, which
/// collided with both.
///
/// Kept as a pure function so the pill and its colour helper cannot
/// drift, though note that [ApplicationStatusBar] does NOT use it: the
/// status bar keeps its own switch over [SyncStatus] and its own
/// vocabulary (synced / syncing / waiting / error). Unifying the two
/// surfaces is a separate cosmetic decision about which wording wins.
enum ConnectionIndicator {
  /// Connected and the last sync completed cleanly.
  online,

  /// Connected; a sync is currently in flight (waiting, processing,
  /// cleaning up) so the view may be momentarily stale.
  away,

  /// The homeserver connection has errored or is unreachable.
  offline,
}

/// Maps a Matrix sync status to a coarse [ConnectionIndicator].
ConnectionIndicator syncStatusToIndicator(SyncStatus status) {
  switch (status) {
    case SyncStatus.finished:
      return ConnectionIndicator.online;
    case SyncStatus.waitingForResponse:
    case SyncStatus.processing:
    case SyncStatus.cleaningUp:
      return ConnectionIndicator.away;
    case SyncStatus.error:
      return ConnectionIndicator.offline;
  }
}

/// The colour a presence dot should take for a given state.
Color connectionIndicatorColor(ConnectionIndicator state, ColorScheme scheme) {
  switch (state) {
    case ConnectionIndicator.online:
      return const Color(0xFF4CAF50);
    case ConnectionIndicator.away:
      return const Color(0xFFFFC107);
    case ConnectionIndicator.offline:
      return scheme.onErrorContainer;
  }
}

/// The header status pill, reflecting the live connection state.
///
/// Previously this widget hardcoded a green dot and the English text
/// "Online" regardless of connection, which misled users into thinking
/// they were connected when the homeserver had dropped. It subscribes to
/// [Client.onSyncStatus] and derives a [ConnectionIndicator] from it.
///
/// The doc comment used to claim it mirrors [ApplicationStatusBar]. It
/// does not, and the two have always used different vocabularies for the
/// same underlying state; see [ConnectionIndicator].
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
  late ConnectionIndicator _presence;
  StreamSubscription<SyncStatusUpdate>? _sub;

  @override
  void initState() {
    super.initState();
    _presence = syncStatusToIndicator(_initialSyncStatus() ?? SyncStatus.finished);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-subscribe whenever the provider-backed client changes (account
    // switch) or when no injected stream is supplied.
    _sub?.cancel();
    final stream = widget.syncStatusStream ?? _clientSyncStream();
    if (stream == null) {
      _presence = ConnectionIndicator.offline;
      if (mounted) setState(() {});
      return;
    }
    _sub = stream.listen((update) {
      final p = syncStatusToIndicator(update.status);
      if (p != _presence && mounted) setState(() => _presence = p);
    });
    // Seed with the cached value if the injected stream has no initial.
    if (widget.initialStatus != null && widget.syncStatusStream == null) {
      _presence = syncStatusToIndicator(_clientSyncStatus() ?? widget.initialStatus!.status);
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;

    final String label;
    switch (_presence) {
      case ConnectionIndicator.online:
        label = l10n.statusOnline;
      case ConnectionIndicator.away:
        label = l10n.statusAway;
      case ConnectionIndicator.offline:
        label = l10n.statusOffline;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: t.opacityFocus),
        borderRadius: BorderRadius.circular(t.radiusSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: connectionIndicatorColor(_presence, scheme),
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
