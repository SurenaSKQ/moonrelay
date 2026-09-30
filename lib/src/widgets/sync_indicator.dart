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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// A single, deliberately quiet indicator of whether Matrix data is
/// actually arriving.
///
/// ## Why this is not a "syncing" badge
///
/// `/sync` is a long-poll. Between requests the SDK sits in
/// `SyncStatus.waitingForResponse` for up to the server's timeout, which
/// is typically thirty seconds, and that state is the *normal resting
/// state* of a healthy client, not a sign of trouble. An indicator that
/// lights up whenever a sync is in flight is therefore on nearly all the
/// time, which is why the two indicators this replaces were noise: one
/// read "Syncing" in the room header and the other read "Away" next to
/// the user's own name, where it was indistinguishable from that user's
/// presence.
///
/// So the rule here is the opposite. Silence is the default and says
/// nothing bad. Something appears only when the user would otherwise be
/// left guessing:
///
/// - **Slow.** No completed sync for [stallThreshold]. Matrix is
///   genuinely slow and a busy homeserver can take a while, so this is
///   worded as reassurance rather than alarm: we are still trying.
/// - **Failed.** The last sync errored, with a retry affordance.
///
/// Everything in between is reported by saying nothing.
///
/// ## Where it belongs
///
/// Room-scoped, in the room header. It is not a user-presence fact, and
/// it is not a global banner: whether *this* room is receiving data is
/// what the user reading it wants to know.
class SyncIndicator extends StatefulWidget {
  const SyncIndicator({
    super.key,
    required this.client,
    this.stallThreshold = const Duration(seconds: 10),
    this.statusStream,
    this.initialStatus,
  });

  final Client client;

  /// How long without a completed sync before the quiet "still trying"
  /// message appears.
  ///
  /// Well above the long-poll interval, because a poll that has not yet
  /// timed out is not a stall. Anything shorter would make this visible
  /// during ordinary operation, which is the thing it exists to avoid.
  final Duration stallThreshold;

  /// Overrides the stream read from [Client.onSyncStatus].
  ///
  /// The SDK exposes [CachedStreamController], which is private and
  /// cannot be constructed in a test, so the seam is here instead. Left
  /// null in production.
  final Stream<SyncStatusUpdate>? statusStream;

  /// Seed status used on first build, for the same reason as
  /// [statusStream].
  final SyncStatusUpdate? initialStatus;

  @override
  State<SyncIndicator> createState() => _SyncIndicatorState();
}

/// What the indicator currently has to say.
enum SyncIndicatorState {
  /// All well. Renders nothing at all.
  quiet,

  /// No completed sync for longer than the threshold.
  slow,

  /// The last sync errored.
  failed,
}

class _SyncIndicatorState extends State<SyncIndicator> {
  StreamSubscription<SyncStatusUpdate>? _sub;
  Timer? _stallTimer;

  /// When the last completed sync was observed. Null before the first
  /// one, which is treated as "not stalled yet" so a cold start does not
  /// immediately show a message.
  DateTime? _lastFinished;

  SyncIndicatorState _state = SyncIndicatorState.quiet;

  @override
  void initState() {
    super.initState();
    _lastFinished = _seedStatus();
    _sub = _stream()?.listen(_onStatus);
  }

  @override
  void didUpdateWidget(covariant SyncIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.client, widget.client) &&
        identical(oldWidget.statusStream, widget.statusStream)) {
      return;
    }
    // An account switch is a new stream and a new cache; without this
    // the indicator would keep reporting the previous account's state.
    _sub?.cancel();
    _stallTimer?.cancel();
    _stallTimer = null;
    _state = SyncIndicatorState.quiet;
    _lastFinished = _seedStatus();
    _sub = _stream()?.listen(_onStatus);
  }

  @override
  void dispose() {
    _sub?.cancel();
    _stallTimer?.cancel();
    super.dispose();
  }

  Stream<SyncStatusUpdate>? _stream() =>
      widget.statusStream ?? widget.client.onSyncStatus.stream;

  /// Picks up the status the client already knows about, so a room
  /// opened mid-stall does not sit silent until the next tick.
  ///
  /// A completed sync here is recorded as the last one, which is what
  /// stops a room opened during a long poll from greeting the user with
  /// a stall warning.
  DateTime? _seedStatus() {
    final cached = widget.initialStatus ??
        (() {
          try {
            return widget.client.onSyncStatus.value;
          } catch (_) {
            return null;
          }
        })();
    if (cached == null) return null;
    if (cached.status == SyncStatus.finished) return DateTime.now();
    if (cached.status == SyncStatus.error) {
      _state = SyncIndicatorState.failed;
    }
    return null;
  }

  void _onStatus(SyncStatusUpdate update) {
    if (!mounted) return;
    switch (update.status) {
      case SyncStatus.finished:
        _lastFinished = DateTime.now();
        _stallTimer?.cancel();
        _stallTimer = null;
        _setState(SyncIndicatorState.quiet);
      case SyncStatus.error:
        _stallTimer?.cancel();
        _stallTimer = null;
        _setState(SyncIndicatorState.failed);
      case SyncStatus.waitingForResponse:
      case SyncStatus.processing:
      case SyncStatus.cleaningUp:
        // Only a stall if we have not *completed* a sync recently. A poll
        // in flight is not a stall, so this arm deliberately does
        // nothing except make sure the timer is armed.
        _armStallTimer();
    }
  }

  void _armStallTimer() {
    if (_stallTimer != null) return;
    final last = _lastFinished;
    if (last == null) {
      // No completed sync observed yet. A cold start is not a stall, and
      // the first finished tick will arm this if it needs to.
      return;
    }
    final elapsed = DateTime.now().difference(last);
    if (elapsed >= widget.stallThreshold) {
      _setState(SyncIndicatorState.slow);
      return;
    }
    _stallTimer = Timer(widget.stallThreshold - elapsed, () {
      _stallTimer = null;
      if (mounted) _setState(SyncIndicatorState.slow);
    });
  }

  void _setState(SyncIndicatorState next) {
    if (_state == next) return;
    setState(() => _state = next);
  }

  /// Retries immediately by asking the client to start a new sync.
  ///
  /// Uses the project's own timeout wrapper rather than a bare await, so
  /// a homeserver that accepts the request and never answers cannot hang
  /// the button.
  Future<void> _retry() async {
    setState(() => _state = SyncIndicatorState.quiet);
    _lastFinished = DateTime.now();
    final client = widget.client;
    await withTimeoutOrFallback(
      client.sync,
      fallback: null,
      label: 'sync retry',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_state == SyncIndicatorState.quiet) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    final failed = _state == SyncIndicatorState.failed;
    // Muted rather than a primary container: this is ambient reassurance,
    // and an error state that shouts is as wrong as one that never
    // appears. The icon carries the severity, the colour only supports it.
    final foreground = failed ? scheme.error : scheme.onSurfaceVariant;

    final message = failed ? l10n.syncConnectionFailed : l10n.syncStillFetching;
    final description = failed
        ? l10n.syncConnectionFailedDescription
        : l10n.syncStillFetchingDescription;

    return Semantics(
      liveRegion: true,
      label: message,
      child: Tooltip(
        message: description,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: t.spaceXs),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (failed)
                // An error deserves an explicit control: the user asked
                // for data, the server refused, and they may want to
                // prove it is still broken.
                TextButton.icon(
                  onPressed: _retry,
                  icon: Icon(LucideIcons.refreshCw, size: 13, color: foreground),
                  label: Text(
                    message,
                    style: TextStyle(fontSize: 11, color: foreground),
                  ),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.symmetric(horizontal: t.spaceXs),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: const TextStyle(fontSize: 11),
                  ),
                )
              else ...[
                // A slow poll needs no control, so this is a label and
                // a mark rather than a button. A tiny indeterminate dot
                // is enough to say "we are still here, still trying".
                SizedBox(
                  width: 8,
                  height: 8,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.2,
                    color: foreground.withValues(alpha: 0.6),
                  ),
                ),
                SizedBox(width: t.spaceXs),
                Text(
                  message,
                  style: TextStyle(fontSize: 11, color: foreground),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
