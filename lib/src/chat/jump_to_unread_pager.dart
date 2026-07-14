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

import 'package:matrix/matrix.dart';

/// Pagination for the jump-to-unread affordance.  Extracted from
/// [ChatTimeline] so the orchestration logic can live next to its
/// supporting helpers, and so the parent [State] doesn't need to
/// recreate the algorithm inline.
///
/// The pager takes a narrow [context] object supplied by the state so
/// it doesn't read private fields directly.  It uses [requestFuture]/
/// [requestHistory] on the [Timeline] and races both directions to
/// find a target event ID.
class JumpToUnreadPager {
  JumpToUnreadPager({
    required this.timeline,
    required this.context,
  });

  final Timeline timeline;

  /// The callbacks the parent state supplies.  Kept narrow on purpose:
  /// nothing in here mutates the parent state directly.
  final JumpToUnreadContext context;

  static const Duration _globalTimeout = Duration(seconds: 8);
  static const int _maxIterationsPerDirection = 6;

  /// Pages the timeline in the appropriate direction until the event
  /// with id [markerId] is loaded, or until the server stops returning
  /// more history.  Bounded by a small per-direction iteration cap
  /// *and* a single shared stopwatch so a stalled server can't trap
  /// the user on the "loading" pill for the combined runtime of both
  /// directions.
  ///
  /// Both directions run in **parallel**; the first to surface the
  /// marker wins.
  ///
  /// Returns `true` if the marker was successfully brought into the
  /// cache; `false` if the server ran out of events in both directions
  /// or the iteration/timeout cap was reached.
  Future<bool> paginateUntilMarker(String markerId) async {
    if (!context.canRun()) return false;

    final stopwatch = Stopwatch()..start();
    bool budgetExceeded() => stopwatch.elapsed >= _globalTimeout;

    Future<bool> paginateOlder() async {
      for (var i = 0; i < _maxIterationsPerDirection; i++) {
        if (!context.canRun() || budgetExceeded()) return false;
        if (!timeline.canRequestHistory) return false;
        context.onHistoryAttempt();
        try {
          await context.runWithTimeout(() => timeline.requestHistory());
        } catch (e) {
          context.onHistoryError(e);
          return false;
        } finally {
          context.onHistoryAttemptEnd();
        }
        if (!context.canRun() || budgetExceeded()) return false;
        if (findMarkerIndex(timeline.events, markerId) >= 0) return true;
        if (!timeline.canRequestHistory) return false;
      }
      return false;
    }

    Future<bool> paginateNewer() async {
      for (var i = 0; i < _maxIterationsPerDirection; i++) {
        if (!context.canRun() || budgetExceeded()) return false;
        if (!timeline.canRequestFuture) return false;
        try {
          await context.runWithTimeout(() => timeline.requestFuture());
        } catch (e) {
          context.onFutureError(e);
          return false;
        }
        if (!context.canRun() || budgetExceeded()) return false;
        if (findMarkerIndex(timeline.events, markerId) >= 0) return true;
        if (!timeline.canRequestFuture) return false;
      }
      return false;
    }

    final winner = Completer<bool>();
    Future<void> raceOne(Future<bool> Function() direction) async {
      if (winner.isCompleted) return;
      try {
        final ok = await direction();
        if (!winner.isCompleted && (ok || budgetExceeded())) {
          winner.complete(ok);
        }
      } catch (e, st) {
        if (!winner.isCompleted) winner.completeError(e, st);
      }
    }

    unawaited(raceOne(paginateOlder));
    unawaited(raceOne(paginateNewer));

    final outerTimer = Timer(_globalTimeout, () {
      if (!winner.isCompleted) winner.complete(false);
    });
    try {
      return await winner.future;
    } finally {
      outerTimer.cancel();
      stopwatch.stop();
    }
  }

  /// Returns the index of the first message-like event at or below
  /// [startIdx] in a newest-first [events] list, walking back from
  /// [startIdx] toward older events.  Returns `-1` when the entire
  /// tail newer than [startIdx] consists of state events.
  static int findFirstUnreadMessageIndex(
    List<Event> events,
    int startIdx,
  ) {
    for (var i = startIdx; i >= 0; i--) {
      if (_isMessageLikeEvent(events[i])) return i;
    }
    return -1;
  }

  /// Like [findFirstUnreadMessageIndex] but walks from the *end* of
  /// the list.  Used when the read marker is older than the loaded
  /// window so we need the newest message-like event in the cache.
  static int findFirstUnreadMessageIndexFromEnd(List<Event> events) {
    for (var i = events.length - 1; i >= 0; i--) {
      if (_isMessageLikeEvent(events[i])) return i;
    }
    return -1;
  }

  /// Returns the index of the event with id [markerId] in [events],
  /// or `-1` if it isn't in the list.  Implemented as a `for` loop
  /// to keep the hot path allocation-free.
  static int findMarkerIndex(List<Event> events, String markerId) {
    for (var i = 0; i < events.length; i++) {
      if (events[i].eventId == markerId) return i;
    }
    return -1;
  }

  /// True when [event] should count toward the unread total: regular
  /// chat messages, stickers, and any future message-type event.
  /// State events are intentionally excluded.
  static bool _isMessageLikeEvent(Event event) {
    return event.type == EventTypes.Message ||
        event.type == EventTypes.Sticker;
  }
}

/// Counts unread events in a newest-first timeline window, skipping
/// state events so they don't nudge the "jump to first unread" pill.
///
/// When the user's [Room.fullyRead] marker is non-empty, counts events
/// *newer* than the marker (those the user hasn't yet read).  When no
/// marker has been set (e.g. a brand-new room), counts the entire window
/// but still skips state events.
int countUnreadInWindow(List<Event>? events, String fullyReadEventId) {
  if (events == null || events.isEmpty) return 0;
  var count = 0;
  if (fullyReadEventId.isEmpty) {
    for (final ev in events) {
      if (_isMessageLike(ev)) count++;
    }
    return count;
  }
  for (final ev in events) {
    if (ev.eventId == fullyReadEventId) break;
    if (_isMessageLike(ev)) count++;
  }
  return count;
}

bool _isMessageLike(Event event) {
  return event.type == EventTypes.Message ||
      event.type == EventTypes.Sticker;
}

/// Narrow context the [JumpToUnreadPager] uses to read state from the
/// enclosing widget without coupling to private fields.
class JumpToUnreadContext {
  const JumpToUnreadContext({
    required this.canRun,
    required this.runWithTimeout,
    required this.onHistoryAttempt,
    required this.onHistoryAttemptEnd,
    required this.onHistoryError,
    required this.onFutureError,
  });

  /// True while the parent state is still alive and accepting work.
  final bool Function() canRun;

  /// Wraps a request with a per-iteration timeout.  Capped at the
  /// remaining budget or 4 s, whichever is smaller.
  final Future<void> Function(Future<void> Function() body) runWithTimeout;

  final void Function() onHistoryAttempt;
  final void Function() onHistoryAttemptEnd;
  final void Function(Object error) onHistoryError;
  final void Function(Object error) onFutureError;
}
