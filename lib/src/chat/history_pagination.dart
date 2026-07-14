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

import 'package:flutter/widgets.dart';
import 'package:matrix/matrix.dart';

/// Owns the history-pagination algorithm previously inlined in
/// [ChatTimeline].
///
/// Responsibilities:
///  * Single-flight guard: re-entrant calls during an in-flight
///    `timeline.requestHistory()` are coalesced.
///  * Debounce window: layout-driven scroll notifications that fire
///    immediately after the request returns don't trigger another.
///  * Auto-fill loop: keep requesting more history until the viewport
///    is scrollable or the server runs out.
///  * State-event drain: keep paging through rooms whose first loaded
///    events are all state events (large spaces).
class HistoryPagination {
  HistoryPagination({
    required this.timelineSnapshot,
    required this.canRequest,
    required this.isMounted,
    required this.scrollHasClients,
    required this.maxScrollExtent,
    required this.isNearTop,
    required this.hasMoreHistory,
    required this.runRequest,
    required this.onHistoryError,
    required this.onScrollDebounceEnd,
  });

  /// Latest [Timeline] reference, or null while loading.
  final Timeline? timelineSnapshot;

  /// True when the timeline has loaded and we can make a request.
  final bool Function() canRequest;
  final bool Function() isMounted;
  final bool Function() scrollHasClients;
  final double Function() maxScrollExtent;
  final bool Function() isNearTop;
  final bool Function() hasMoreHistory;

  /// Wraps the request in a per-call timeout.  The implementation
  /// should typically use [withTimeout].
  final Future<void> Function(Future<void> Function() body) runRequest;

  final void Function(Object error) onHistoryError;
  final void Function() onScrollDebounceEnd;

  final Duration _scrollDebounceDelay = const Duration(milliseconds: 120);

  /// Single-flight guard.
  bool _isLoadingHistory = false;

  /// True while auto-fill loop is running.
  bool _isFillingViewport = false;

  /// True when scroll-driven debounce is in effect.
  bool _scrollDebounce = false;
  Timer? _scrollDebounceTimer;

  /// Number of auto-fill requests issued without the viewport becoming
  /// scrollable.  Caps the retry loop when the server returns no more history.
  int _autoFillRetries = 0;
  static const int _maxAutoFillRetries = 5;

  /// Number of consecutive state-event drain loops.
  int _stateDrainCount = 0;
  static const int _maxStateDrainIterations = 50;

  /// Number of trailing events inspected by the state-drain heuristic.
  static const int _stateDrainWindow = 20;

  /// Public, read-only, for tests.
  bool get isLoadingHistory => _isLoadingHistory;

  /// True when the scroll-driven debounce is currently suppressing
  /// further `_requestMoreHistory` calls.
  bool get scrollDebounced => _scrollDebounce;

  /// True while the autofill loop is running.
  bool get fillingViewport => _isFillingViewport;

  /// Requests more history from the server and debounces subsequent
  /// calls so layout reflow doesn't create a loop.
  Future<void> requestMoreHistory() async {
    if (!canRequest()) return;
    if (_isLoadingHistory) return;
    _isLoadingHistory = true;
    _scrollDebounce = true;
    _isFillingViewport = true;

    final timeline = timelineSnapshot;
    if (timeline == null) {
      _isLoadingHistory = false;
      _isFillingViewport = false;
      return;
    }

    try {
      await runRequest(() => timeline.requestHistory());
    } catch (e) {
      onHistoryError(e);
    }

    if (!isMounted()) {
      _isLoadingHistory = false;
      return;
    }
    _isLoadingHistory = false;
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = Timer(_scrollDebounceDelay, () {
      _scrollDebounceTimer = null;
      if (!isMounted()) return;
      _scrollDebounce = false;
      onScrollDebounceEnd();
    });
    _isFillingViewport = false;
    // Also re-check auto-fill after this load finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!isMounted()) return;
      ensureContentFillsScreen();
    });
  }

  /// If the current content does not overflow the viewport, requests
  /// more history until either the viewport is filled or no more events
  /// are available.
  void ensureContentFillsScreen() {
    if (!isMounted()) return;
    if (!canRequest()) return;
    if (_isFillingViewport) return;
    if (_isLoadingHistory) return;
    if (!scrollHasClients()) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => ensureContentFillsScreen());
      return;
    }

    if (_autoFillRetries >= _maxAutoFillRetries) {
      if (!_shouldDrainStateEvents()) return;
      _drainStateEventsAtEndOfTimeline();
      return;
    }

    final maxScroll = maxScrollExtent();
    if (maxScroll <= 50.0) {
      _autoFillRetries++;
      _isFillingViewport = true;
      requestMoreHistory();
    } else {
      _isFillingViewport = false;
      if (_shouldDrainStateEvents()) {
        _drainStateEventsAtEndOfTimeline();
      }
    }
  }

  /// Reset the auto-fill counter when the viewport becomes scrollable.
  void resetAutoFillCountersIfScrollable({required double maxScrollExtent}) {
    if (maxScrollExtent > 50.0) {
      _autoFillRetries = 0;
      _stateDrainCount = 0;
    }
  }

  /// True when the trailing [_stateDrainWindow] most-recently loaded
  /// events are *all* state events AND the server still has more history.
  bool _shouldDrainStateEvents() {
    final timeline = timelineSnapshot;
    if (timeline == null) return false;
    if (!hasMoreHistory()) return false;
    final events = timeline.events;
    if (events.isEmpty) return false;
    final start = events.length > _stateDrainWindow
        ? events.length - _stateDrainWindow
        : 0;
    for (var i = start; i < events.length; i++) {
      final type = events[i].type;
      if (type == EventTypes.Message || type == EventTypes.Sticker) {
        return false;
      }
    }
    return true;
  }

  /// Drains consecutive state events at the chronological start of
  /// the timeline by requesting more history until either:
  ///  - a non-state event is encountered ([_shouldDrainStateEvents] turns
  ///    `false`), or
  ///  - the room has been paginated to its beginning
  ///    (`room.prev_batch == null`), or
  ///  - the [_maxStateDrainIterations] safety cap is hit.
  void _drainStateEventsAtEndOfTimeline() {
    if (_isFillingViewport) return;
    if (_isLoadingHistory) return;
    if (!isMounted()) return;
    if (!_shouldDrainStateEvents()) return;
    if (_stateDrainCount >= _maxStateDrainIterations) return;
    _stateDrainCount++;
    _isFillingViewport = true;
    requestMoreHistory();
  }

  /// Forget the per-load debounce.  Called by the scroll listener when
  /// the user moves the viewport, the new position is no longer at the
  /// top of the loaded history.
  void clearScrollDebounce() {
    if (_scrollDebounce) _scrollDebounce = false;
  }

  void dispose() {
    _scrollDebounceTimer?.cancel();
    _scrollDebounceTimer = null;
  }
}
