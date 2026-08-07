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
import 'package:matrix/matrix.dart';

import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/debouncer.dart';

/// State of the scroll-to-load history pipeline, exposed to the parent
/// widget so it can render skeleton placeholders without poking into
/// the pager's internals.
///
/// The four values are deliberately exhaustive: the pager transitions
/// through them in response to scroll events and HTTP responses, and
/// every other state is implicitly `idle`.
enum HistoryFillState {
  /// No history request in flight, viewport is satisfied (or the user
  /// hasn't reached the top yet).
  idle,

  /// A history request is in flight because the user reached the top
  /// of the loaded history.  Skeleton placeholders should appear at the
  /// top of the viewport.
  loadingMore,

  /// A history request is in flight specifically to drain a long
  /// prefix of state events (membership churn, etc.) at the chronological
  /// start of the timeline.  Same visual as [loadingMore].
  drainingStateEvents,

  /// The server has no more history to give us (prev_batch is null).
  /// The pager stays here until the room changes.
  exhausted,
}

/// Owns the scroll-to-load pipeline for a single [Timeline]:
/// single-flight guarding, auto-fill loop, state-event drain, and the
/// 120 ms debounce that prevents "load -> layout -> scroll event -> load"
/// feedback loops after a pagination completes.
///
/// The pager is constructed by the timeline state, fed scroll events
/// via [onScroll], and asked to "ensure the viewport is full" from the
/// post-frame callback after a sync or a room switch via [ensureFilled].
///
/// All callbacks are synchronous so the parent stays in control of
/// setState / rebuild boundaries.
class HistoryPager {
  HistoryPager({
    required this.room,
    required this.scrollController,
    required this.getTimeline,
    required this.onStateChanged,
    required this.logger,
  });

  final Room room;

  final ScrollController scrollController;

  /// Returns the currently-resolved [Timeline], or `null` while the
  /// parent's async init is still pending.
  final Timeline? Function() getTimeline;

  /// Called whenever the pager's fill state changes.  The parent uses
  /// this to drive `setState` so the skeleton overlay appears/disappears.
  final VoidCallback onStateChanged;

  /// Resolved once at construction; used for warning logs.  May be
  /// `null` in tests that don't wire a provider.
  final Logger? logger;

  // -- Constants ------------------------------------------------

  /// Pixel distance from the top of the (reverse) list that triggers a
  /// history fetch.
  static const double _triggerDistance = 150.0;

  /// How long to suppress scroll-driven history fetches after a load
  /// completes.  Long enough to swallow layout-induced scroll events
  /// but short enough that a real user scroll never feels blocked.
  static const Duration _postLoadDebounce = Duration(milliseconds: 120);

  /// Maximum number of auto-fill attempts issued without the viewport
  /// becoming scrollable.
  static const int _maxAutoFillRetries = 5;

  /// Maximum number of state-event drain iterations.
  static const int _maxStateDrainIterations = 50;

  /// Number of trailing events the drain looks at to decide whether the
  /// room is "all state events at the top".  See [_shouldDrainStateEvents].
  static const int _stateDrainWindow = 20;

  // -- Mutable state --------------------------------------------

  HistoryFillState _state = HistoryFillState.idle;

  /// True while a [requestHistory] call is in flight.
  bool _isLoading = false;

  /// How many consecutive auto-fill requests have been issued without
  /// the viewport becoming scrollable.
  int _autoFillRetries = 0;

  /// How many state-event drain iterations have fired.
  int _stateDrainCount = 0;

  final Debouncer _postLoadDebounceTimer = Debouncer(_postLoadDebounce);

  /// True while a [requestHistory] call is in flight.
  bool get isLoading => _isLoading;

  /// Current state -- exposed for the parent widget so it can compute
  /// `isLoadingHistory` to pass to [TimelineView].
  HistoryFillState get state => _state;

  /// True when [TimelineView] should render skeleton placeholders at
  /// the top of the viewport.
  bool get shouldShowSkeleton =>
      _state == HistoryFillState.loadingMore ||
      _state == HistoryFillState.drainingStateEvents;

  // -- Scroll-driven entry -------------------------------------

  /// Called from the parent's scroll listener.  Decides whether the
  /// user is at the top of the loaded history (and a fetch should fire)
  /// and updates [HistoryFillState] accordingly.
  void onScroll() {
    if (!scrollController.hasClients) return;
    if (!scrollController.position.haveDimensions) return;
    if (_isLoading) return;
    if (_postLoadDebounceTimer.isPending) return;

    final pos = scrollController.position;
    final atEnd = pos.pixels >= pos.maxScrollExtent - _triggerDistance;

    if (atEnd) {
      if (room.prev_batch != null) {
        _transition(HistoryFillState.loadingMore);
      }
      _requestMoreHistory();
      return;
    }

    // User scrolled away from the top  drop the skeleton flag if it
    // was showing so the placeholder doesn't linger.
    if (_state != HistoryFillState.idle) {
      _transition(HistoryFillState.idle);
    }
  }

  // -- Auto-fill ------------------------------------------------

  /// Called from `build` / after a sync / after a room switch.  If the
  /// viewport isn't scrollable, repeatedly requests more history until
  /// it is, the server runs out of events, or the retry / drain budgets
  /// are exhausted.
  void ensureFilled() {
    final timeline = getTimeline();
    if (timeline == null) return;
    if (!scrollController.hasClients) {
      // The scroll controller hasn't laid out yet; defer to the next
      // frame so we have a real [maxScrollExtent] to read.
      WidgetsBinding.instance.addPostFrameCallback((_) => ensureFilled());
      return;
    }
    if (!scrollController.position.haveDimensions) {
      // The scroll controller has a client but the viewport hasn't
      // computed content dimensions yet; defer to the next frame.
      WidgetsBinding.instance.addPostFrameCallback((_) => ensureFilled());
      return;
    }
    if (_isLoading) return;

    if (_autoFillRetries >= _maxAutoFillRetries) {
      if (!_shouldDrainStateEvents(timeline)) return;
      _drainStateEventsAtEndOfTimeline(timeline);
      return;
    }

    if (scrollController.position.maxScrollExtent <= 50.0) {
      _autoFillRetries++;
      _transition(HistoryFillState.loadingMore);
      _requestMoreHistory();
    } else {
      _autoFillRetries = 0;
      if (_shouldDrainStateEvents(timeline)) {
        _drainStateEventsAtEndOfTimeline(timeline);
      }
    }
  }

  /// Resets the retry / drain counters.  Called from the parent's build
  /// when the viewport is already scrollable; also when the room id
  /// changes (so the new room starts fresh).
  void resetCounters() {
    _autoFillRetries = 0;
    _stateDrainCount = 0;
  }

  /// Called when the room id changes: drop the end-of-history flag,
  /// reset counters, cancel any in-flight load debounce.
  void resetForRoom() {
    _transition(HistoryFillState.idle);
    resetCounters();
    _postLoadDebounceTimer.cancel();
  }

  /// Called when a timeline update bumps the version: the SDK may have
  /// cleared `prev_batch` (room paginated to the beginning).  Drop the
  /// skeleton flag in that case.
  void onTimelineUpdated() {
    if (_state != HistoryFillState.idle && room.prev_batch == null) {
      _transition(HistoryFillState.idle);
    }
  }

  // -- Internals ------------------------------------------------

  Future<void> _requestMoreHistory() async {
    final timeline = getTimeline();
    if (timeline == null) return;
    if (_isLoading) return;
    _isLoading = true;
    _postLoadDebounceTimer(() {
      // Release the debounce *without* firing it -- this branch is the
      // "post-load" timer we deliberately set to suppress scroll events.
    });

    var succeeded = false;
    try {
      await withTimeout(
        () => timeline.requestHistory(),
        timeout: kDefaultTimeout,
      );
      succeeded = true;
    } catch (e) {
      logger?.w('History request failed for ${room.id}', error: e);
      if (_state != HistoryFillState.idle) {
        _transition(HistoryFillState.idle);
      }
    }

    _isLoading = false;
    _postLoadDebounceTimer.call(() {
      // The actual debounce release window.  See [_postLoadDebounce].
      if (_state != HistoryFillState.idle) {
        _transition(HistoryFillState.idle);
      }
    });

    // Re-check auto-fill only after a *successful* load.  Re-arming after
    // a failure makes the fill loop retry immediately in a tight spin
    // (the retry budget can be reset by concurrent rebuilds, keeping the
    // spin alive), hammering the network and starving the frame pipeline
    // when pagination keeps failing.  The next sync tick or a manual
    // scroll is the right moment to try again.
    if (succeeded) {
      WidgetsBinding.instance.addPostFrameCallback((_) => ensureFilled());
    }
  }

  /// True when the trailing [stateDrainWindow] events are all state
  /// events AND the server still has more history to give us.
  bool _shouldDrainStateEvents(Timeline timeline) {
    if (room.prev_batch == null) return false;
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

  void _drainStateEventsAtEndOfTimeline(Timeline timeline) {
    if (_isLoading) return;
    if (!_shouldDrainStateEvents(timeline)) return;
    if (_stateDrainCount >= _maxStateDrainIterations) return;
    _stateDrainCount++;
    _transition(HistoryFillState.drainingStateEvents);
    _requestMoreHistory();
  }

  void _transition(HistoryFillState next) {
    if (_state == next) return;
    _state = next;
    onStateChanged();
  }

  /// Releases any pending timers.  The owning [State] calls this from
  /// its `dispose()`.
  void dispose() {
    _postLoadDebounceTimer.cancel();
  }
}
