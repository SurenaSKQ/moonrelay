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

import 'package:moonrelay/src/chat/history_pager.dart';
import 'package:moonrelay/src/chat/jump_to_unread_pager.dart';
import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/chat/timeline_scroll_target.dart';
import 'package:moonrelay/src/settings/motion.dart';

/// Orchestrates the "jump to first unread" affordance.
///
/// Responsibilities:
/// - Track the in-flight jump so the pill can swap its label to a
///   loading state and skeleton placeholders can appear.
/// - Page the timeline (older + newer in parallel) via [JumpToUnreadPager]
///   when the read marker isn't yet in the local cache.
/// - Scroll to the resolved target event with a brief highlight ring.
///
/// The coordinator is intentionally narrow: it doesn't observe provider
/// state, doesn't manage timers beyond the highlight ring, and doesn't
/// own the read-marker logic (the parent calls into [ReadMarkerTracker]
/// after the jump completes).
class JumpCoordinator {
  JumpCoordinator({
    required this.context,
    required this.getTimeline,
    this.getRenderEvents,
    required this.getFullyReadMarker,
    required this.scrollController,
    required this.timelineViewKey,
    required this.historyPager,
    required this.onStateChanged,
    required this.onAfterJump,
    required this.scrollToBottom,
    this.logger,
    this.paginationBudget = JumpToUnreadPager.defaultBudget,
  });

  /// Owning [BuildContext].  Used to look up [Logger] for warnings;
  /// the coordinator assumes the parent only invokes its methods while
  /// the context is mounted.
  final BuildContext context;

  /// Resolves the currently-tracked [Timeline], or `null` while the
  /// parent's async init is still pending.
  final Timeline? Function() getTimeline;

  /// The events the timeline is showing: the live tail plus every loaded
  /// history window, newest first.
  ///
  /// **Lookups go here; pagination goes through [getTimeline].** The two are
  /// different questions. A read marker or a jump target can be sitting in a
  /// window, and searching only the tail would paginate for something already
  /// on screen and then give up. Paging is the opposite: only the tail can
  /// reach newer events, because a window's forward axis ends where the window
  /// does.
  final List<Event> Function()? getRenderEvents;

  /// The render list, or the tail alone when no store is wired.
  List<Event> _renderEvents() {
    final render = getRenderEvents?.call();
    final timeline = getTimeline();
    if (render != null) return render;
    return timeline?.events ?? const [];
  }

  /// Resolves the read marker for the room currently displayed.
  /// Kept as a separate provider (rather than reading `timeline.room`)
  /// because fake timelines in tests often leave `room` null, and the
  /// marker is always available from the parent widget's room prop.
  final String Function() getFullyReadMarker;

  /// Used to drive the scroll-to-event animation.
  final ScrollController scrollController;

  /// Key into the rendered [TimelineView]; used to delegate pixel-
  /// perfect jumps via [Scrollable.ensureVisible] when the target is
  /// on screen.
  final GlobalKey timelineViewKey;

  /// Used to flip the skeleton flag on while the jump is paginating.
  final HistoryPager historyPager;

  /// Fires whenever the coordinator's [_isJumping] flag changes; the
  /// parent uses it to drive `setState`.
  final VoidCallback onStateChanged;

  /// Fires after a successful jump so the parent can dismiss the
  /// unread pill.
  final VoidCallback onAfterJump;

  /// Scrolls to the bottom of the timeline (used when there's no
  /// marker to land on).  This also settles the read marker, because
  /// the implementation returns the viewport to the newest message and
  /// everything on screen is then read.  There is deliberately no
  /// separate "mark read" seam: two of them meant two POSTs for one
  /// user action.
  final VoidCallback scrollToBottom;

  final Logger? logger;

  /// Wall-clock ceiling the pager gets while searching for the unread
  /// target, passed through to [JumpToUnreadPager].
  ///
  /// A constructor parameter rather than a constant in the pager so that
  /// lowering it is possible from the outside. The constant is still the
  /// default and nothing in the app changes it; the only caller that does is
  /// the test, which is the point.
  final Duration paginationBudget;

  static const Duration _highlightDuration = Duration(seconds: 2);

  /// How long a fallback jump takes to travel to its target.
  ///
  /// Gated through [Motion] at each call site, so a user who has turned
  /// animations off lands on the message instead of gliding to it.
  static const Duration _scrollDuration = Duration(milliseconds: 300);

  bool _isJumping = false;
  Timer? _highlightTimer;
  String? _highlightedEventId;

  /// True while the coordinator is paginating to find the unread
  /// target.
  bool get isJumping => _isJumping;

  /// Event id currently highlighted by the "jump to unread" affordance,
  /// or `null` if nothing is highlighted.
  String? get highlightedEventId => _highlightedEventId;

  /// Called by the parent's [setState] when it wants to re-read the
  /// pill visibility.  Provided for test access.
  @visibleForTesting
  bool get isJumpingForTest => _isJumping;

  /// Paginate until [markerId] is in the cache, with an injectable
  /// [budget].
  ///
  /// This is the primitive [jumpToLastRead] is built from, exposed because
  /// the budget is only observable here and a test asserting the real
  /// thirty-second cap has to wait thirty seconds, and then assert an upper
  /// bound that a loaded machine can miss. With [budget] supplied the test
  /// waits milliseconds and asserts the exact ceiling.
  @visibleForTesting
  Future<bool> paginateUntilMarkerForTest(
    String markerId, {
    Duration? budget,
  }) {
    final timeline = getTimeline();
    if (timeline == null) return Future.value(false);
    return _paginateUntilMarker(
      markerId,
      timeline,
      budget: budget ?? paginationBudget,
    );
  }

  /// Scrolls the timeline to the first unread event after the read
  /// marker.  Robust to "not yet loaded" targets: when the marker
  /// isn't in the cache, paginates older + newer history in parallel
  /// until it surfaces.
  ///
  /// No-op when no timeline is available.  Callers should ensure the
  /// context is mounted before invoking.
  Future<void> jumpToLastRead() async {
    final timeline = getTimeline();
    if (timeline == null) return;

    // Always pull the live marker -- `Room.fullyRead` is updated by the
    // SDK on every sync, but the cached last-seen may be one frame
    // behind.
    final markerId = getFullyReadMarker();
    if (markerId.isEmpty) {
      // No marker at all -- the user has never read this room.  Drop
      // them at the bottom so the newest messages are on screen.
      // scrollToBottom settles the read marker with it.
      scrollToBottom();
      return;
    }

    // The whole render list, because the marker can be sitting in a
    // loaded window. Searching only the tail would miss it, fall into
    // the paginating branch, and burn the budget looking for something
    // already on screen.
    final events = _renderEvents();

    // Fast path: the marker is in the render list.  The first unread event
    // is the closest message-like event newer than the marker.
    final initialIdx = JumpToUnreadPager.findMarkerIndex(
      events,
      markerId,
    );
    // `initialIdx == 0` means the marker is the newest event on screen, so
    // the room is fully read and there is nothing to jump to.  Treat
    // that as a successful no-op: entering the paginating branch here
    // used to burn the whole 30s budget discovering what we already
    // knew, which is what made the pill feel broken.
    if (initialIdx == 0) {
      scrollToBottom();
      return;
    }
    if (initialIdx > 0) {
      final unreadIdx = JumpToUnreadPager.findFirstUnreadMessageIndex(
        events,
        initialIdx - 1,
      );
      if (unreadIdx >= 0) {
        _landOn(events[unreadIdx].eventId);
        return;
      }
    }

    // Slow path: paginate until the marker surfaces.  Set the loading
    // state so the pill swaps its label and the timeline shows
    // skeletons.
    _enterLoading();

    // Paginate until the marker is found or both directions are
    // exhausted.  Unlike the old code path, we do not short-circuit
    // to "oldest message in cache" when the marker isn't found
    // (Case A) -- the aggressive-loading contract requires that we
    // actually surface the marker or prove it unreachable.
    final loaded = await _paginateUntilMarker(markerId, timeline);
    final fresh = getTimeline();
    if (fresh == null) return;
    // Re-read the render list, not the tail: pagination may have extended a
    // segment other than the live one, and the marker can be in either.
    final eventsAfter = _renderEvents();
    if (!loaded) {
      if (eventsAfter.isNotEmpty) scrollToBottom();
      _exitLoading();
      return;
    }
    final markerIdx = JumpToUnreadPager.findMarkerIndex(
      eventsAfter,
      markerId,
    );
    if (markerIdx > 0) {
      final unreadIdx = JumpToUnreadPager.findFirstUnreadMessageIndex(
        eventsAfter,
        markerIdx - 1,
      );
      if (unreadIdx >= 0) {
        _landOn(eventsAfter[unreadIdx].eventId);
        return;
      }
    }
    if (eventsAfter.isNotEmpty) scrollToBottom();
    _exitLoading();
  }

  /// Public entry point used by the in-room search panel to jump to
  /// an arbitrary event id without owning the per-event GlobalKey map.
  /// Delegates to [TimelineView.scrollToEventId] when the view is
  /// mounted and falls back to a fraction estimate otherwise.
  void jumpToEvent(String? eventId) {
    if (getTimeline() == null || eventId == null) return;
    if (!scrollController.hasClients) return;
    if (!scrollController.position.haveDimensions) return;
    // The render list: the target may be in a loaded window, and this used
    // to search the tail alone and give up on anything else.
    final events = _renderEvents();
    if (events.isEmpty) return;
    if (!events.any((e) => e.eventId == eventId)) return;

    final view = timelineViewKey.currentState;
    if (view != null && view is TimelineViewState) {
      view.scrollToEventId(eventId);
      return;
    }

    final idx = events.indexWhere((e) => e.eventId == eventId);
    TimelineScrollTarget.scrollToFraction(
      scrollController,
      idx,
      events.length,
      skipIfClose: false,
      duration: Motion.of(context).duration(_scrollDuration),
    );
  }

  /// Resets in-flight state.  Called when the room id changes so the
  /// new room doesn't inherit the previous room's loading skeleton or
  /// highlighted event.
  void resetForRoom() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
    _highlightedEventId = null;
    _isJumping = false;
  }

  /// Releases timers.  Called from the owning [State]'s `dispose()`.
  void dispose() {
    _highlightTimer?.cancel();
    _highlightTimer = null;
  }

  // -- Internals ------------------------------------------------

  /// Calls into [JumpToUnreadPager] with a narrow callback surface
  /// pulled from the parent's state.  Returns `true` if the marker
  /// surfaced.
  Future<bool> _paginateUntilMarker(
    String markerId,
    Timeline timeline, {
    Duration? budget,
  }) {
    return JumpToUnreadPager(
      timeline: timeline,
      budget: budget ?? paginationBudget,
      context: JumpToUnreadContext(
        canRun: () => true,
        runWithTimeout: (body) => body(),
        onHistoryAttempt: () {},
        onHistoryAttemptEnd: () {},
        onHistoryError: (e) =>
            logger?.w('jumpToLastRead: history request failed', error: e),
        onFutureError: (e) => logger
            ?.w('jumpToLastRead: future-history request failed', error: e),
      ),
    ).paginateUntilMarker(markerId);
  }

  void _enterLoading() {
    if (_isJumping) return;
    _isJumping = true;
    onStateChanged();
  }

  void _exitLoading() {
    if (!_isJumping) return;
    _isJumping = false;
    onStateChanged();
  }

  void _landOn(String eventId) {
    _exitLoading();
    _scrollToEvent(eventId);
    _flashHighlight(eventId);
    onAfterJump();
  }

  void _scrollToEvent(String eventId) {
    if (getTimeline() == null) return;
    if (!scrollController.hasClients) return;

    final events = _renderEvents();
    if (events.isEmpty) return;
    if (!events.any((e) => e.eventId == eventId)) return;

    final view = timelineViewKey.currentState;
    if (view != null && view is TimelineViewState) {
      view.scrollToEventId(eventId);
      return;
    }

    final idx = events.indexWhere((e) => e.eventId == eventId);
    TimelineScrollTarget.scrollToFraction(
      scrollController,
      idx,
      events.length,
      skipIfClose: false,
      duration: Motion.of(context).duration(_scrollDuration),
    );
  }

  void _flashHighlight(String eventId) {
    _highlightTimer?.cancel();
    // A flashing highlight is exactly what "reduce motion" is asking us not
    // to do, and this is the most noticeable motion in the timeline: a jump
    // can land thirty messages away. With animations off the user gets the
    // scroll and nothing else; they asked for the destination, not for it to
    // be pointed at afterwards.
    if (!Motion.of(context).enableAnimations) {
      _highlightedEventId = null;
      return;
    }
    _highlightedEventId = eventId;
    _highlightTimer = Timer(_highlightDuration, () {
      if (_highlightedEventId == eventId) {
        _highlightedEventId = null;
        onStateChanged();
      }
    });
    onStateChanged();
  }
}
