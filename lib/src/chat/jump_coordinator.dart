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
// Hides the duplicate `countUnreadInWindow` from jump_to_unread_pager
// in favour of the canonical implementation in chat_unread_utils.
import 'package:moonrelay/src/chat/chat_unread_utils.dart' as unread;

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
    required this.getFullyReadMarker,
    required this.scrollController,
    required this.timelineViewKey,
    required this.historyPager,
    required this.onStateChanged,
    required this.onAfterJump,
    required this.scrollToBottom,
    required this.markRoomReadForce,
    this.logger,
  });

  /// Owning [BuildContext].  Used to look up [Logger] for warnings;
  /// the coordinator assumes the parent only invokes its methods while
  /// the context is mounted.
  final BuildContext context;

  /// Resolves the currently-tracked [Timeline], or `null` while the
  /// parent's async init is still pending.
  final Timeline? Function() getTimeline;

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
  /// marker to land on).
  final VoidCallback scrollToBottom;

  /// Marks the room read unconditionally (used as a fallback when the
  /// marker is missing or out of reach).
  final void Function() markRoomReadForce;

  final Logger? logger;

  static const Duration _highlightDuration = Duration(seconds: 2);

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
      scrollToBottom();
      markRoomReadForce();
      return;
    }

    // Fast path: the marker is in the cache.  The first unread event
    // is the closest message-like event newer than the marker.
    final initialIdx = JumpToUnreadPager.findMarkerIndex(
      timeline.events,
      markerId,
    );
    if (initialIdx > 0) {
      final unreadIdx = JumpToUnreadPager.findFirstUnreadMessageIndex(
        timeline.events,
        initialIdx - 1,
      );
      if (unreadIdx >= 0) {
        _landOn(timeline.events[unreadIdx].eventId);
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
    final eventsAfter = fresh.events;
    if (!loaded) {
      if (eventsAfter.isNotEmpty) scrollToBottom();
      markRoomReadForce();
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
    final timeline = getTimeline();
    if (timeline == null || eventId == null) return;
    if (!scrollController.hasClients) return;
    if (timeline.events.isEmpty) return;
    if (!timeline.events.any((e) => e.eventId == eventId)) return;

    final view = timelineViewKey.currentState;
    if (view != null && view is TimelineViewState) {
      view.scrollToEventId(eventId);
      return;
    }

    final events = timeline.events;
    final idx = events.indexWhere((e) => e.eventId == eventId);
    final position = scrollController.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    final fraction = idx / (events.length > 1 ? events.length - 1 : 1);
    final paddedOffset = (position.minScrollExtent +
            range * fraction -
            position.viewportDimension * 0.33)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    scrollController.animateTo(
      paddedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
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
  Future<bool> _paginateUntilMarker(String markerId, Timeline timeline) {
    return JumpToUnreadPager(
      timeline: timeline,
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
    final timeline = getTimeline();
    if (timeline == null) return;
    if (!scrollController.hasClients) return;

    final events = timeline.events;
    if (events.isEmpty) return;
    if (!events.any((e) => e.eventId == eventId)) return;

    // Try the precise path first -- if the TimelineView has the
    // event rendered, [Scrollable.ensureVisible] lands the target
    // exactly one third from the top of the viewport regardless of
    // variable-height items above it.
    final view = timelineViewKey.currentState;
    if (view != null && view is TimelineViewState) {
      view.scrollToEventId(eventId);
      return;
    }

    // Fallback fraction path -- used only until the TimelineView has
    // been built and keyed.
    final idx = events.indexWhere((e) => e.eventId == eventId);
    final position = scrollController.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    final fraction = idx / (events.length > 1 ? events.length - 1 : 1);
    final paddedOffset = (position.minScrollExtent +
            range * fraction -
            position.viewportDimension * 0.33)
        .clamp(position.minScrollExtent, position.maxScrollExtent);
    scrollController.animateTo(
      paddedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _flashHighlight(String eventId) {
    _highlightTimer?.cancel();
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

/// Re-exported so the coordinator and the parent can read the unread
/// count without an extra import line.  Kept here to make the
/// coordinator's dependency surface obvious: everything it needs to
/// decide "should I show the pill?" lives next to it.
int unreadInWindow(Timeline? timeline, String fullyReadMarker) {
  if (timeline == null) return 0;
  return unread.countUnreadInWindow(timeline.events, fullyReadMarker);
}
