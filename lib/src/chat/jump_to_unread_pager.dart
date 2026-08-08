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
import 'package:moonrelay/src/chat/chat_unread_utils.dart';

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

  /// Shared timeout across both pagination directions.  Increased from 8s
  /// to 30s so large rooms with sparse sync intervals don't leave the user
  /// on the loading pill unnecessarily.
  static const Duration _globalTimeout = Duration(seconds: 30);

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
    final winner = Completer<bool>();
    bool budgetExceeded() => stopwatch.elapsed >= _globalTimeout;

    Future<bool> paginateOlder() async {
      while (context.canRun() && !budgetExceeded()) {
        if (winner.isCompleted) return false;
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
        if (!context.canRun() || budgetExceeded() || winner.isCompleted) {
          return false;
        }
        if (findMarkerIndex(timeline.events, markerId) >= 0) return true;
        // Continue until history is exhausted.
      }
      return false;
    }

    Future<bool> paginateNewer() async {
      while (context.canRun() && !budgetExceeded()) {
        if (winner.isCompleted) return false;
        if (!timeline.canRequestFuture) return false;
        try {
          await context.runWithTimeout(() => timeline.requestFuture());
        } catch (e) {
          context.onFutureError(e);
          return false;
        }
        if (!context.canRun() || budgetExceeded() || winner.isCompleted) {
          return false;
        }
        if (findMarkerIndex(timeline.events, markerId) >= 0) return true;
        // Continue until future is exhausted.
      }
      return false;
    }

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
  /// [startIdx] toward newer events.  Returns `-1` when the entire
  /// tail newer than [startIdx] consists of state events or
  /// non-addressable relationship events (edits, thread replies).
  static int findFirstUnreadMessageIndex(
    List<Event> events,
    int startIdx,
  ) {
    for (var i = startIdx; i >= 0; i--) {
      if (isAddressableUnreadEvent(events[i])) return i;
    }
    return -1;
  }

  /// Like [findFirstUnreadMessageIndex] but walks from the *end* of
  /// the list.  Used when the read marker is older than the loaded
  /// window so we need the newest message-like event in the cache.
  static int findFirstUnreadMessageIndexFromEnd(List<Event> events) {
    for (var i = events.length - 1; i >= 0; i--) {
      if (isAddressableUnreadEvent(events[i])) return i;
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
