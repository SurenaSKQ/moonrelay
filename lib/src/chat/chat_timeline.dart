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
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// Orchestrates the chat timeline lifecycle.
///
/// Creates the [Timeline] via the Matrix SDK, manages scroll-to-load-history
/// with auto-fill for short content, and delegates rendering to [TimelineView].
///
/// ## Scroll loading
///
/// With `reverse: true` on the ListView, the scroll position is 0 at the
/// bottom (newest messages) and reaches [maxScrollExtent] at the top (oldest
/// messages).  History is loaded whenever the user scrolls within 150 px of
/// the top.
///
/// ## Auto-fill
///
/// If the initially loaded content does not fill the viewport (no scrollbar),
/// history is fetched repeatedly until the viewport is full or the server
/// returns no more events.  This ensures the user can always scroll up to
/// trigger manual pagination.
///
/// ## Stability
///
/// A shared [scaffold] / debounce mechanism prevents cascading history loads.
/// When a load completes, layout-induced scroll notifications are suppressed
/// for two frames while the list stabilises, stopping the "load → layout
/// change → scroll event → load" feedback loop that would otherwise overflow.
class ChatTimeline extends StatefulWidget {
  const ChatTimeline({super.key, required this.room, this.onReply});

  final Room room;

  /// Called when the user wants to reply to a specific timeline event.
  final void Function(Event event)? onReply;

  @override
  State<ChatTimeline> createState() => _ChatTimelineState();
}

class _ChatTimelineState extends State<ChatTimeline> {
  /// The resolved Timeline, or null while still initialising.
  Timeline? _timeline;

  final ScrollController _scrollController = ScrollController();

  /// True while a [requestHistory] call is in flight.
  bool _isLoadingHistory = false;

  /// True while the auto-fill loop is running.
  bool _isFillingViewport = false;

  /// Temporarily suppresses [_onScroll] after a successful history load so
  /// that layout-induced scroll notifications don't trigger another request
  /// before the user has had a chance to scroll manually.
  bool _scrollDebounce = false;

  /// How many consecutive auto-fill requests have been issued without the
  /// viewport becoming scrollable.  Caps the retry loop when the server
  /// returns no more history.
  int _autoFillRetries = 0;
  static const int _maxAutoFillRetries = 5;

  /// Trigger distance (logical pixels) from the top of the list.
  static const double _scrollThreshold = 150.0;

  int _timelineVersion = 0;

  @override
  void initState() {
    super.initState();
    _initTimeline();
  }

  Future<void> _initTimeline() async {
    final log = context.read<Logger>();

    final result = await withRetry(
      () => widget.room.getTimeline(
        onChange: (_) => setState(() => _timelineVersion++),
        onInsert: (_) => setState(() => _timelineVersion++),
        onRemove: (_) => setState(() => _timelineVersion++),
        onUpdate: () {},
      ),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'getTimeline(${widget.room.id})',
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        {
          setState(() => _timeline = value);
          _scrollController.addListener(_onScroll);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureContentFillsScreen();
          });
        }
      case RetryFailed(:final error):
        {
          log.e('Failed to load timeline for ${widget.room.id}', error: error);
          // Leave _timeline as null so the build method shows the error.
          setState(() {});
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Shared history-loading
  // ---------------------------------------------------------------------------

  /// Requests more history from the server and debounces subsequent
  /// scroll-triggered loads so that layout reflow doesn't create a loop.
  Future<void> _requestMoreHistory() async {
    if (_timeline == null) return;
    final Logger log = context.read<Logger>();
    _isLoadingHistory = true;
    _scrollDebounce = true;

    try {
      await withTimeout(
        () => _timeline!.requestHistory(),
        timeout: kDefaultTimeout,
      );
    } catch (e) {
      log.w('History request failed for ${widget.room.id}', error: e);
    }

    if (!mounted) return;
    _isLoadingHistory = false;
    // Let the list lay out, then release the debounce two frames later
    // to skip any layout-caused scroll events.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _scrollDebounce = false);
      });
    });
    // Also re-check auto-fill after this load finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureContentFillsScreen();
    });
  }

  // ---------------------------------------------------------------------------
  // Scroll-to-load history
  // ---------------------------------------------------------------------------

  /// Called on every scroll event.  Loads more history when the user scrolls
  /// near the top of the timeline (oldest messages).
  ///
  /// The ListView uses `reverse: true`, so:
  /// - `pixels == 0` → bottom of the list (newest messages)
  /// - `pixels >= maxScrollExtent - threshold` → near the top (oldest)
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingHistory) return;
    if (_scrollDebounce) return;
    if (_isFillingViewport) return;

    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _scrollThreshold) {
      _requestMoreHistory();
    }
  }

  // ---------------------------------------------------------------------------
  // Auto-fill viewport
  // ---------------------------------------------------------------------------

  /// If the current content does not overflow the viewport (i.e. no scrollbar
  /// is visible), requests more history until either the viewport is filled or
  /// no more events are available from the server.
  void _ensureContentFillsScreen() {
    if (!mounted) return;
    if (_isFillingViewport) return;
    if (_isLoadingHistory) return;
    if (_timeline == null) return;

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureContentFillsScreen());
      return;
    }

    if (_autoFillRetries >= _maxAutoFillRetries) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    // Still too short -> request more.
    if (maxScroll <= 50.0) {
      _autoFillRetries++;
      _isFillingViewport = true;
      _requestMoreHistory();
    } else {
      _isFillingViewport = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Reset auto-fill counter when content becomes scrollable.
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 50.0) {
      _autoFillRetries = 0;
    }

    return Consumer<SettingsController>(
      builder: (context, settings, _) {
        if (_timeline == null) {
          return _buildError(context);
        }

        return TimelineView(
          timeline: _timeline!,
          room: widget.room,
          displayType: settings.displayType,
          scrollController: _scrollController,
          timelineVersion: _timelineVersion,
          onReply: widget.onReply,
          showStateEvents: settings.showStateEvents,
        );
      },
    );
  }

  Widget _buildError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 48,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.couldNotLoadMessages,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.serverMayBeUnreachable,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Icon(
              LucideIcons.shield,
              size: 24,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.encryptionVerifyDevice,
              style: TextStyle(
                fontSize: 12,
                color: scheme.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }
}
