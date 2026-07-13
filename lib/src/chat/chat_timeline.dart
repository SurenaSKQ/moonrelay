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
import 'package:moonrelay/src/chat/forward_message_dialog.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/pinned_events_cache.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/motion.dart';
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
  const ChatTimeline(
      {super.key,
      required this.room,
      this.onReply,
      this.onThread,
      this.filterEvents});

  final Room room;

  /// Called when the user wants to reply to a specific timeline event.
  final void Function(Event event)? onReply;

  /// Called when the user wants to open or create a thread for an event.
  final void Function(Event event)? onThread;

  /// When non-null, passed through to [TimelineView.filterEvents] to
  /// override the default event visibility filter.
  final bool Function(Event)? filterEvents;

  @override
  State<ChatTimeline> createState() => ChatTimelineState();
}

/// Counts the number of unread events in [events], skipping state
/// events so they don't trigger the jump-to-unread FAB.
///
/// The list is expected in newest-first order (matching
/// [Timeline.events]).  An event counts as "unread" when it is
/// positioned newer than [fullyReadEventId] in the cache.  When no
/// marker is set (a fresh account that has never opened the room has
/// nothing to anchor the count against) the entire visible window
/// counts as unread.
///
/// State events (member joins, room renames, topic changes, etc.) are
/// intentionally excluded — they are not messages the user needs to
/// "catch up on" in the same way as regular messages, and including
/// them caused the FAB to surface in rooms where there is genuinely no
/// unread chat content.  The jump target inherits the same rule: when
/// the user invokes it, the destination is the first real message after
/// the marker, not the first state event.
int countUnreadInWindow(List<Event>? events, String fullyReadEventId) {
  if (events == null || events.isEmpty) return 0;
  var count = 0;
  // When the marker is empty we treat every visible event as unread.
  // Still skip state events so a room with only state activity (e.g.
  // membership churn) does not pretend to have unread messages.
  if (fullyReadEventId.isEmpty) {
    for (final ev in events) {
      if (_isMessageLikeEvent(ev)) count++;
    }
    return count;
  }
  for (final ev in events) {
    if (ev.eventId == fullyReadEventId) break;
    if (_isMessageLikeEvent(ev)) count++;
  }
  return count;
}

/// True when [event] should count toward the unread total: regular
/// chat messages, stickers, and any future message-type event.  State
/// events (member changes, topic edits, encryption, etc.) return
/// `false` because they are bookkeeping the SDK manages on the user's
/// behalf and don't warrant a "jump to unread" nudge.
bool _isMessageLikeEvent(Event event) {
  return event.type == EventTypes.Message ||
      event.type == EventTypes.Sticker;
}

class ChatTimelineState extends State<ChatTimeline> {
  /// The resolved Timeline, or null while still initialising.
  Timeline? _timeline;

  final ScrollController _scrollController = ScrollController();

  /// True while a [requestHistory] call is in flight.
  bool _isLoadingHistory = false;

  /// True while the jump-to-unread flow is paginating the timeline in
  /// either direction to locate the first unread event.  When set, the
  /// chat surface shows skeleton placeholders so the user has feedback
  /// that work is in progress instead of staring at a stale viewport.
  bool _isJumpingToUnread = false;

  /// True while the auto-fill loop is running.
  bool _isFillingViewport = false;

  /// True when the user has scrolled to the top of the *currently
  /// loaded* history and the server still has more events to give us
  /// (i.e. [Room.prev_batch] is non-null).  When this flips `true`,
  /// we render skeleton placeholders above the oldest event so the
  /// user sees a smooth "more on the way" indicator instead of
  /// hitting a hard scroll cap and having to wait for the new
  /// events to materialise.
  bool _atLocalEndOfHistory = false;

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

  /// Distance (logical pixels) from the bottom of the list at which we
  /// consider the user "scrolled up" — far enough from the newest
  /// messages that a "Scroll to bottom" button would actually save
  /// them work.  Smaller than [_scrollThreshold] because the user
  /// usually wants to return to the bottom after reading just a few
  /// events above the current view.
  static const double _scrollUpThreshold = 200.0;

  /// True when the user has scrolled away from the bottom of the
  /// timeline.  Used to surface the "Scroll to bottom" floating
  /// button so they can jump back to the newest messages without
  /// having to swipe all the way down by hand.
  bool _isScrolledUp = false;

  /// Public accessor for the scroll controller, exposed so callers
  /// outside this widget (e.g. the in-room search panel) can request
  /// a jump to a specific event after we've already built the timeline.
  ScrollController get scrollController => _scrollController;

  int _timelineVersion = 0;

  /// True when [_initTimeline] finished with a permanent error.
  bool _timelineLoadFailed = false;

  /// Events explicitly fetched for the pinned filter (fetched by ID from
  /// the server when they aren't in the local timeline batch).
  List<Event>? _fetchedFilteredEvents;

  /// True while [fetchFilteredEvents] is in flight.
  bool _isFetchingFilteredEvents = false;

  @override
  void initState() {
    super.initState();
    _initTimeline();
  }

  @override
  void didUpdateWidget(ChatTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The room id can change when the parent rebuilds with a new
    // [Room] instance (e.g. after an account switch).  Drop the
    // end-of-history flag so the previous room's skeleton doesn't
    // linger in the new room.  We also reset the dismissed-pill flag
    // so the user gets a fresh affordance for any unread events in
    // the new room.
    if (oldWidget.room.id != widget.room.id) {
      _atLocalEndOfHistory = false;
      _pillDismissed = false;
    }
    if (widget.filterEvents != null && oldWidget.filterEvents == null) {
      _fetchFilteredEvents();
    } else if (widget.filterEvents == null &&
        oldWidget.filterEvents != null) {
      if (_fetchedFilteredEvents != null) {
        setState(() => _fetchedFilteredEvents = null);
      }
    }
  }

  Future<void> _initTimeline() async {
    final log = context.read<Logger>();

    final result = await withRetry(
      () => widget.room.getTimeline(
        onChange: (_) => _onTimelineUpdate(),
        onInsert: (_) => _onTimelineUpdate(),
        onRemove: (_) => _onTimelineUpdate(),
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
            // Mark the room read as soon as the first batch of events
            // is on screen.  Without this, the user has to manually
            // tap the jump-to-unread pill before the server ever
            // hears that they opened the room.
            _markRoomRead();
          });
        }
      case RetryFailed(:final error):
        {
          log.e('Failed to load timeline for ${widget.room.id}', error: error);
          _timelineLoadFailed = true;
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
    // Release the auto-fill guard so that _ensureContentFillsScreen
    // can re-evaluate whether the viewport is full.
    _isFillingViewport = false;
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
    if (_isFillingViewport) return;
    if (_scrollDebounce) return;

    // Advance the read marker in the background.  _scheduleMarkRoomRead
    // debounces so a fast drag doesn't generate dozens of HTTP calls —
    // a single batched request fires ~250 ms after the last scroll
    // event.
    _scheduleMarkRoomRead();

    final pos = _scrollController.position;
    final atEnd = pos.pixels >= pos.maxScrollExtent - _scrollThreshold;

    // Track whether the user has scrolled away from the bottom of
    // the timeline.  The list is reversed, so `pixels > threshold`
    // means the user is reading older events.  We surface a
    // "Scroll to bottom" button in that state so they can jump back
    // to the newest messages without having to drag their way down.
    final scrolledUp = pos.pixels > _scrollUpThreshold;
    if (scrolledUp != _isScrolledUp) {
      setState(() => _isScrolledUp = scrolledUp);
    }

    // Track whether the user is parked at the top of the loaded
    // history.  We use the flag to render skeleton placeholders
    // *before* the network round-trip completes so the user sees
    // an immediate "loading more" instead of a hard scroll cap.
    if (atEnd) {
      if (!_atLocalEndOfHistory) {
        // Only set when the SDK still owes us history; if the room
        // has been paginated all the way back to the beginning,
        // there's no need to bother the user with a skeleton.
        if (widget.room.prev_batch != null) {
          setState(() => _atLocalEndOfHistory = true);
        }
      }
      if (!_isLoadingHistory) {
        _requestMoreHistory();
      }
      return;
    }

    // Scrolled away from the end — drop the skeleton so it doesn't
    // linger on the screen when the user is no longer waiting.
    if (_atLocalEndOfHistory) {
      setState(() => _atLocalEndOfHistory = false);
    }
  }

  // ---------------------------------------------------------------------------
  // Jump-to-last-seen
  // ---------------------------------------------------------------------------

  /// The event ID the user has last read up to.  Pulled from the SDK
  /// (`m.fully_read` account data) at load time and on every sync.
  String _lastSeenEventId = '';

  /// Highest event ID we have already pushed a read-marker for in this
  /// session.  Used to avoid repeatedly POSTing the same marker (the SDK
  /// also dedupes, but a local guard keeps the network quiet during
  /// bursty scroll events).  Keyed by event id; values are unused.
  final Set<String> _markReadSent = <String>{};

  /// Debounce window for the scroll-driven read-marker update.  A single
  /// drag covers many pixels in a few hundred ms; batching at 250 ms
  /// ensures we only send the marker once the user has stopped scrolling.
  static const Duration _markReadDebounce = Duration(milliseconds: 250);

  /// Pending debounced mark-read future, cancelled and re-scheduled on
  /// every scroll event.
  Timer? _markReadDebounceTimer;

  /// Refreshes [_lastSeenEventId] from room account data. Safe to call
  /// repeatedly — only sets state when the value changed.  When the
  /// server-acknowledged marker advances, the user has genuinely
  /// caught up and the dismissed-pill flag is reset so a *future*
  /// batch of unread events re-surfaces the affordance.
  void _refreshLastSeenMarker() {
    final next = widget.room.fullyRead;
    if (next != _lastSeenEventId) {
      _lastSeenEventId = next;
      // If the user has caught up, the pill is no longer needed.  If
      // new unread events arrive later, [_showUnreadPill] will flip
      // back to true on the next rebuild.
      _pillDismissed = false;
      setState(() {});
    }
  }

  /// Number of events in [Timeline.events] that are newer than
  /// [Room.fullyRead].  Drives the jump-to-unread affordance so the pill
  /// appears only when there is *actually* an unread event in the loaded
  /// window, regardless of what the server-side `notification_count`
  /// currently reports.
  int get _unreadInWindow =>
      countUnreadInWindow(_timeline?.events, _lastSeenEventId);

  /// Set to `true` when the user explicitly dismisses the jump-to-unread
  /// pill with its close button.  The pill stays dismissed for the
  /// remainder of this room's visit; it re-appears on the next visit
  /// when new events arrive.  Reset whenever the user actually engages
  /// with the room (marking read or navigating away).
  bool _pillDismissed = false;

  /// True when the jump-to-unread pill should be shown.
  ///
  /// The pill is shown when there is at least one unread event in the
  /// loaded window AND the user has not explicitly dismissed it.
  /// Crucially, the pill does **not** disappear just because the user
  /// scrolled up — that was the previous behaviour and it confused
  /// users into thinking the badge had cleared when in fact they had
  /// merely moved the viewport.  Dismissing the pill is now a deliberate
  /// user action: tap the close icon on the pill, jump to the unread
  /// event, or have the server-acknowledged marker advance via the
  /// normal read-receipt flow.
  bool get _showUnreadPill =>
      _unreadInWindow > 0 && !_pillDismissed && !_isJumpingToUnread;

  /// Dismisses the jump-to-unread pill.  The pill will re-appear the
  /// next time the user enters a state with unread events — either
  /// when the room is reopened or when new events arrive that aren't
  /// immediately read.
  void dismissUnreadPill() {
    if (!_pillDismissed) {
      setState(() => _pillDismissed = true);
    }
  }

  /// Scrolls the timeline to the first unread event — the chronologically
  /// newest event newer than [Room.fullyRead] in the loaded window.
  ///
  /// State events are skipped during the search: the jump target is
  /// always the first real message after the marker, not the first
  /// state event.  A room with only state activity after the marker
  /// (member churn, topic edits, encryption rollouts, …) has nothing
  /// the user needs to "catch up on", so the FAB shouldn't surface in
  /// the first place — that's enforced by [countUnreadInWindow].
  ///
  /// The implementation is robust to "not yet loaded" targets:
  ///
  /// 1. If the marker (the event the user has read up to) is already in
  ///    the cache, the first unread event is the closest message-like
  ///    event newer than the marker (`events[markerIdx - 1]` or any
  ///    earlier non-state event in the same window).
  /// 2. If the marker is older than the loaded window, the cache
  ///    contains only events newer than the marker — the first unread
  ///    is the oldest message-like event in the cache.  We jump to
  ///    that, and (if the scroll-up affordance is desired) optionally
  ///    paginate older history so the user sees the exact boundary.
  /// 3. If the cache is empty or the marker is still missing after
  ///    pagination, we paginate the timeline in the appropriate
  ///    direction until the marker is found, refreshing the pill with
  ///    a "loading" label and the timeline with skeleton placeholders
  ///    so the user has feedback that work is in progress.
  ///
  /// Bounded to a small number of pagination iterations so a stalled
  /// server doesn't trap the user.
  Future<void> jumpToLastRead() async {
    final timeline = _timeline;
    if (timeline == null) return;

    // Always pull the live marker — `widget.room.fullyRead` is updated
    // by the SDK on every sync, but [_lastSeenEventId] may be one frame
    // behind.
    final markerId = widget.room.fullyRead;

    if (markerId.isEmpty) {
      // No marker at all — the user has never read this room.  Drop
      // them at the bottom so the newest messages are on screen.
      _scrollToBottom();
      _markRoomRead(force: true);
      return;
    }

    // Fast path: the marker is in the cache.  The first unread event
    // is the closest message-like event newer (lower index in
    // newest-first order) than the marker.  If every newer event in
    // the window is a state event, the marker is effectively at index 0
    // and we fall through to the slow path.
    final initialIdx = _findMarkerIndex(timeline.events, markerId);
    if (initialIdx > 0) {
      final unreadIdx =
          _findFirstUnreadMessageIndex(timeline.events, initialIdx - 1);
      if (unreadIdx >= 0) {
        _jumpToUnreadEvent(timeline.events[unreadIdx].eventId);
        return;
      }
    }

    // Slow path: we need to bring the target into the cache before we
    // can scroll to it.  Show a "loading" affordance on the pill and
    // skeleton placeholders on the timeline so the user knows work is
    // in progress.
    if (mounted) {
      setState(() {
        _isJumpingToUnread = true;
        _atLocalEndOfHistory = true;
      });
    }

    // Case A: the marker is older than the loaded window.  Scan the
    // cache for the oldest message-like event — that's the first
    // unread if and only if the marker truly is older than the
    // window.  If only state events are in the cache we still have a
    // useful target (the newest message at the bottom of the cache),
    // but since we already know everything is unread, scrolling to
    // the bottom is the right fallback.
    if (initialIdx == -1 && timeline.events.isNotEmpty) {
      final oldestMessageIdx =
          _findFirstUnreadMessageIndexFromEnd(timeline.events);
      if (oldestMessageIdx >= 0) {
        _jumpToUnreadEvent(timeline.events[oldestMessageIdx].eventId);
      } else {
        // No message in the loaded window — drop the user at the
        // bottom and mark the room read.  This matches the pre-state-
        // event-skip behaviour for empty-message windows.
        _scrollToBottom();
        _markRoomRead(force: true);
      }
      return;
    }

    // Case B: the cache is empty (or the pill was shown spuriously
    // with no events).  We need to paginate the timeline to find *any*
    // event to land on.  Try the older direction first since the
    // marker is virtually always older than the cached window — the
    // default SDK cache window is 20 events, the marker is the most
    // recent read event, and the unread events are even more recent
    // than the cache.
    final loaded = await _paginateUntilMarker(markerId);
    if (!mounted) return;
    if (!loaded) {
      // Server timed out or the marker genuinely doesn't exist on this
      // server.  Fall back to scrolling to the bottom of whatever the
      // cache holds so the user isn't left looking at an empty
      // viewport, and clear the pill.
      if (timeline.events.isNotEmpty) {
        _scrollToBottom();
      }
      _markRoomRead(force: true);
      return;
    }
    _refreshLastSeenMarker();
    final eventsAfter = _timeline?.events ?? const [];
    final markerIdx = _findMarkerIndex(eventsAfter, markerId);
    if (markerIdx > 0) {
      final unreadIdx =
          _findFirstUnreadMessageIndex(eventsAfter, markerIdx - 1);
      if (unreadIdx >= 0) {
        _jumpToUnreadEvent(eventsAfter[unreadIdx].eventId);
        return;
      }
    }
    if (eventsAfter.isNotEmpty) {
      // Marker is at index 0 or still not in the cache; the cache
      // has only events older than the marker (or only state events
      // newer than the marker).  Scroll to the bottom (the newest in
      // the cache) so the user sees the most recent message we have,
      // and clear the pill.
      _scrollToBottom();
    }
  }

  /// Returns the index of the first message-like event at or below
  /// [startIdx] in a newest-first event list, walking back from
  /// [startIdx] toward older events.  Returns `-1` when the entire
  /// tail newer than [startIdx] consists of state events — callers
  /// should then fall back to scrolling-to-bottom or paginating for
  /// older history.
  ///
  /// Used by [jumpToLastRead] so the FAB target lands on the first
  /// real message after the read marker, not on a state event like a
  /// member join or topic change.
  int _findFirstUnreadMessageIndex(List<Event> events, int startIdx) {
    for (var i = startIdx; i >= 0; i--) {
      if (_isMessageLikeEvent(events[i])) return i;
    }
    return -1;
  }

  /// Like [_findFirstUnreadMessageIndex] but walks from the *end* of
  /// the list.  Used when the read marker is older than the loaded
  /// window so we need the newest message-like event in the cache.
  int _findFirstUnreadMessageIndexFromEnd(List<Event> events) {
    for (var i = events.length - 1; i >= 0; i--) {
      if (_isMessageLikeEvent(events[i])) return i;
    }
    return -1;
  }

  /// Returns the index of the event with id [markerId] in [events], or
  /// `-1` if it isn't in the list.  A `for` loop instead of
  /// [List.indexWhere] keeps the helper allocation-free for the
  /// hot-path in [_paginateUntilMarker].
  int _findMarkerIndex(List<Event> events, String markerId) {
    for (var i = 0; i < events.length; i++) {
      if (events[i].eventId == markerId) return i;
    }
    return -1;
  }

  /// Jumps the viewport to the unread event with [eventId] and clears
  /// the loading state.  Centralises the success-path plumbing of
  /// [jumpToLastRead] so the calling code stays readable.
  void _jumpToUnreadEvent(String eventId) {
    if (mounted) {
      setState(() {
        _isJumpingToUnread = false;
        _atLocalEndOfHistory = false;
      });
    }
    _scrollToEvent(eventId);
    _flashHighlight(eventId);
  }

  /// Pages the timeline in the appropriate direction until the event
  /// with id [markerId] is loaded, or until the server stops returning
  /// more history.  Bounded to a small number of iterations so a
  /// stalled server doesn't trap the user.
  ///
  /// The marker is virtually always older than the cached window (the
  /// default cache holds 20 events and the marker is the most recent
  /// read receipt), so we paginate *older* history first.  As a final
  /// fallback we try the *future* direction in case the cache window
  /// is unusually stale.
  ///
  /// Returns `true` if the marker was successfully brought into the
  /// cache; `false` if the server ran out of events in both directions
  /// or the iteration cap was reached.
  Future<bool> _paginateUntilMarker(String markerId) async {
    final timeline = _timeline;
    if (timeline == null) return false;
    final log = context.read<Logger>();
    const maxIterationsPerDirection = 25;

    Future<bool> paginateOlder() async {
      for (var i = 0; i < maxIterationsPerDirection; i++) {
        if (!mounted) return false;
        if (!timeline.canRequestHistory) return false;
        _isLoadingHistory = true;
        try {
          await withTimeout(
            () => timeline.requestHistory(),
            timeout: const Duration(seconds: 10),
          );
        } catch (e) {
          log.w('jumpToLastRead: history request failed', error: e);
          return false;
        } finally {
          _isLoadingHistory = false;
        }
        if (!mounted) return false;
        if (_findMarkerIndex(timeline.events, markerId) >= 0) return true;
        if (!timeline.canRequestHistory) return false;
      }
      return false;
    }

    Future<bool> paginateNewer() async {
      for (var i = 0; i < maxIterationsPerDirection; i++) {
        if (!mounted) return false;
        if (!timeline.canRequestFuture) return false;
        try {
          await withTimeout(
            () => timeline.requestFuture(),
            timeout: const Duration(seconds: 10),
          );
        } catch (e) {
          log.w('jumpToLastRead: future-history request failed', error: e);
          return false;
        }
        if (!mounted) return false;
        if (_findMarkerIndex(timeline.events, markerId) >= 0) return true;
        if (!timeline.canRequestFuture) return false;
      }
      return false;
    }

    // Older first.
    if (await paginateOlder()) return true;
    if (!mounted) return false;
    // Future as a fallback in case the cache is unusually stale.
    if (await paginateNewer()) return true;
    return false;
  }

  /// Scrolls the timeline so the event with [eventId] sits roughly one
  /// third from the top of the viewport, with a brief highlight ring.
  void _scrollToEvent(String eventId) {
    final timeline = _timeline;
    if (timeline == null) return;
    if (!_scrollController.hasClients) return;

    final events = timeline.events;
    if (events.isEmpty) return;
    final idx = events.indexWhere((e) => e.eventId == eventId);
    if (idx < 0) return;

    final position = _scrollController.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    // List is reversed: index 0 is the bottom (offset 0), index n-1 is
    // the top.  A smaller index into `events` corresponds to a smaller
    // scroll offset.
    final fraction = idx / (events.length > 1 ? events.length - 1 : 1);
    final paddedOffset =
        (position.minScrollExtent + range * fraction - position.viewportDimension * 0.33)
            .clamp(position.minScrollExtent, position.maxScrollExtent);
    _scrollController.animateTo(
      paddedOffset,
      duration: motionDuration(300),
      curve: motionCurve(Curves.easeInOut),
    );
  }

  /// Marks [eventId] as the highlighted event for ~2 seconds so the
  /// user can see where the jump landed.
  void _flashHighlight(String eventId) {
    _highlightedEventId = eventId;
    setState(() {});
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_highlightedEventId == eventId) {
        setState(() => _highlightedEventId = null);
      }
    });
  }

  /// Plain bottom-scroll helper used when we don't have a marker to
  /// jump to.  Useful for tests and as a catch-all fallback.
  ///
  /// Made public so the floating "Scroll to bottom" button can call
  /// it from inside the build method.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Public entry point for the floating "Scroll to bottom" button.
  /// Animate-scrolls the timeline so the newest message sits at the
  /// bottom of the viewport.  Resets the [_isScrolledUp] flag so
  /// the button itself disappears once the scroll completes.
  void scrollToBottom() {
    if (!_isScrolledUp) return;
    setState(() => _isScrolledUp = false);
    _scrollToBottom();
    // The user is reaching the bottom of the timeline.  Push a mark-read
    // in the background — the scroll listener would do this anyway, but
    // `animateTo` only fires scroll events along the path so the final
    // 250 ms debounce window may outlive the animation.  Forcing it here
    // keeps the badge clear on the same frame the user lands at the
    // bottom.
    _scheduleMarkRoomRead();
  }

  /// Event ID currently highlighted by the "Jump to unread" affordance.
  /// Mirrors the value the timeline view uses for in-room search jumps.
  String? _highlightedEventId;

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

  /// Fetches events that pass the active filter by their event IDs.
  ///
  /// When the pinned-only filter is active, the regular timeline may not
  /// contain the pinned events (they may be outside the loaded window).
  /// This method reads the pinned event IDs from room state and fetches
  /// each event via [PinnedEventsCache], which dedupes concurrent requests
  /// and avoids round-trips for events already known to the cache.
  Future<void> _fetchFilteredEvents() async {
    if (_isFetchingFilteredEvents) return;
    _isFetchingFilteredEvents = true;

    if (!mounted) return;
    setState(() => _fetchedFilteredEvents = null);

    try {
      final state = widget.room.getState('m.room.pinned_events');
      final pinnedList = state?.content['pinned'];
      final pinnedIds =
          pinnedList is List ? pinnedList.cast<String>() : <String>[];

      if (pinnedIds.isEmpty) {
        _isFetchingFilteredEvents = false;
        if (mounted) setState(() => _fetchedFilteredEvents = []);
        return;
      }

      // Fetch via the shared cache. Concurrent calls for the same event ID
      // share a single in-flight future, and already-cached events return
      // immediately — so 50 pinned IDs in a fresh room are fetched in
      // parallel rather than 50 sequential awaits.
      final events = await Future.wait(
        pinnedIds.map(
          (id) => PinnedEventsCache.instance.getEvent(widget.room, id),
        ),
      );
      final resolved = events.whereType<Event>().toList();

      // Sort oldest-first so the reversed ListView places the newest at
      // the bottom.
      resolved.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));

      if (!mounted) return;
      setState(() => _fetchedFilteredEvents = resolved);
    } finally {
      _isFetchingFilteredEvents = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reset auto-fill counter when content becomes scrollable.
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 50.0) {
      _autoFillRetries = 0;
    }

    // Keep the fully-read marker fresh — the SDK updates
    // `Room.fullyRead` on every sync, so we just sample it on
    // rebuild.  We schedule the refresh on the next frame so that
    // any `setState` it triggers runs *outside* this build, which
    // would otherwise trip a "setState() during build" error and
    // create a noisy rebuild loop during scroll events.
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _refreshLastSeenMarker());

    return Consumer<SettingsController>(
      builder: (context, settings, _) {
        if (_timeline == null) {
          if (_timelineLoadFailed) {
            return _buildError(context);
          }
          // Still loading – sync indicator in ChatRoomHeader handles the
          // visual feedback, so we just show an empty container.
          return const SizedBox.shrink();
        }

        final child = _buildTimelineContent(context, settings);

        // Always wrap in a Stack so the timeline [ListView] is never
        // unmounted/remounted when FAB pills appear/disappear.  A
        // remount would destroy the [ScrollPosition] and reset the
        // scroll offset to 0 (bottom), causing the "jitter / refuses
        // to scroll up" bug.
        //
        // The floating action column sits above the chat composer
        // when either:
        //   * there are unread messages below the current viewport
        //     (jump-to-unread), or
        //   * the user has scrolled away from the bottom
        //     (scroll-to-bottom).
        // The two pills can stack: when the user has unread AND
        // has scrolled up, the unread pill takes visual priority
        // (it sits on top) and the scroll-to-bottom button sits
        // below it.
        return Stack(
          children: [
            child,
            if (_showUnreadPill || _isScrolledUp)
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: _FloatingActionColumn(
                      unreadCount: _unreadInWindow,
                      isScrolledUp: _isScrolledUp,
                      unreadVisible: _showUnreadPill,
                      isJumping: _isJumpingToUnread,
                      onJumpToUnread: () async {
                        await jumpToLastRead();
                        if (!mounted) return;
                        // jumpToLastRead already advances the read
                        // marker if it lands on the latest unread
                        // event.  The explicit _markRoomRead(force:)
                        // call here covers the "I want to clear the
                        // badge right now" path when the user reaches
                        // for the pill as a mark-read shortcut.
                        _markRoomRead(force: true);
                        if (mounted) dismissUnreadPill();
                      },
                      onScrollToBottom: scrollToBottom,
                      onDismissUnread: dismissUnreadPill,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineContent(
    BuildContext context,
    SettingsController settings,
  ) {
    // When a filter is active and we've explicitly fetched the matching
    // events, render those instead of the regular timeline view (which
    // would show nothing if the target events aren't in the loaded batch).
    if (widget.filterEvents != null) {
      if (_fetchedFilteredEvents != null) {
        if (_fetchedFilteredEvents!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.push_pin_outlined,
                  size: 40,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.noPinnedMessages,
                  style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return _PinnedEventsList(
          events: _fetchedFilteredEvents!,
          room: widget.room,
          displayType: settings.displayType,
          fontSize: settings.fontSize,
          bubbleRadius: settings.bubbleRadius,
          scrollController: _scrollController,
          onReply: widget.onReply,
          onThread: widget.onThread,
          onForward: (event) => showForwardDialog(
            context: context,
            event: event,
            sourceRoom: widget.room,
          ),
        );
      }

      // Still fetching...
      return const Center(child: CircularProgressIndicator());
    }

    return TimelineView(
      timeline: _timeline!,
      room: widget.room,
      displayType: settings.displayType,
      fontSize: settings.fontSize,
      bubbleRadius: settings.bubbleRadius,
      scrollController: _scrollController,
      timelineVersion: _timelineVersion,
      onReply: widget.onReply,
      onThread: widget.onThread,
      showStateEvents: settings.showStateEvents,
      filterEvents: widget.filterEvents,
      // Render skeleton placeholders at the top of the viewport
      // *only* when the user has scrolled all the way to the end of
      // the loaded history and the server still owes us more events.
      // The flag is updated by [_onScroll] as the user reaches /
      // leaves the top, so the placeholder never flashes at the
      // bottom of the chat window during the initial load.
      isLoadingHistory: _atLocalEndOfHistory,
      highlightedEventId: _highlightedEventId,
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
  // Read marker
  // ---------------------------------------------------------------------------

  /// Scrolls the rendered timeline to the event with [eventId].
  ///
  /// The estimate is intentionally approximate (item index in the
  /// visible list × viewport-fraction); the user can see the target and
  /// scroll if it lands off by a few items.
  ///
  /// No-ops when [eventId] is null, no client is attached, or the
  /// scroll controller isn't ready yet.
  void jumpToEvent(String? eventId) {
    final timeline = _timeline;
    if (timeline == null || eventId == null) return;
    if (!_scrollController.hasClients) return;

    final events = timeline.events;
    if (events.isEmpty) return;
    final idx = events.indexWhere((e) => e.eventId == eventId);
    if (idx < 0) return;

    final position = _scrollController.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    final fraction = idx / (events.length - 1);
    final targetOffset = position.minScrollExtent + range * fraction;
    final paddedOffset =
        (targetOffset - position.viewportDimension * 0.33).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _scrollController.animateTo(
      paddedOffset,
      duration: motionDuration(300),
      curve: motionCurve(Curves.easeInOut),
    );
  }

  /// Smoothly-jumping scroll mappings resolved against the user's
  /// animation preferences.  Both helpers fall through to the standard
  /// curve / duration pair when motion is enabled and collapse to a
  /// "do it instantly" no-op when the user has disabled animations
  /// (the scroll controller still respects [duration] though, so even
  /// with a zero duration we get the same result without jank).
  Duration motionDuration(int millis) =>
      Motion.of(context).duration(Duration(milliseconds: millis));

  Curve motionCurve([Curve fallback = Curves.easeInOut]) =>
      Motion.of(context).curve(fallback);

  /// Sends a read receipt for the newest *synced* event in the timeline
  /// so the server and other clients know the user has seen the latest
  /// messages.
  ///
  /// Honours the [SettingsController.sendReadReceipts] toggle — when the
  /// user opts out we still record the marker locally but never tell the
  /// homeserver.
  ///
  /// [force] bypasses the local "already sent" cache and posts the
  /// marker unconditionally; used by the "Jump to first unread" pill
  /// when it lands on a state where the cache thinks the marker is
  /// already current.
  void _markRoomRead({bool force = false}) {
    if (_timeline == null) return;
    final events = _timeline!.events;
    if (events.isEmpty) return;
    // The newest *synced* event in the cache.  Pending local sends
    // (status == sending / sent) are excluded so we don't try to
    // acknowledge a message the homeserver hasn't yet echoed back.
    String? latestId;
    for (final ev in events) {
      if (ev.status == EventStatus.synced) {
        latestId = ev.eventId;
        break;
      }
    }
    latestId ??= events.first.eventId;
    if (latestId.isEmpty) return;
    final sendReceipts =
        context.read<SettingsController>().sendReadReceipts;
    final alreadySent = !force && _markReadSent.contains(latestId);
    if (!alreadySent) {
      _markReadSent.add(latestId);
      // Bound the cache so it doesn't grow without limit on busy rooms.
      if (_markReadSent.length > 512) {
        // Drop the oldest half; Set preserves insertion order.
        final drop = _markReadSent.length ~/ 2;
        final it = _markReadSent.iterator;
        for (var i = 0; i < drop && it.moveNext(); i++) {
          _markReadSent.remove(it.current);
        }
      }
      // Mirror the new marker into the notification service's local
      // bookkeeping so a sync tick right after we marked read doesn't
      // re-emit a stale summary for a room we just caught up on.
      // We do this regardless of [sendReceipts] — the user visibly
      // reached the latest message and we shouldn't nag them about it.
      // The notification service is optional in the provider tree
      // (desktop-only) so guard with a try/read.
      final notif = _maybeNotificationService();
      notif?.onRoomReadByTimeline(widget.room.id, latestId);
    }
    if (!sendReceipts) return;
    if (alreadySent) return;
    // ignore: discarded_futures
    widget.room.setReadMarker(latestId, mRead: latestId);
  }

  /// Returns the notification service if it has been provided in this
  /// widget tree, or `null` on platforms (or in tests) where it isn't
  /// available.  NotificationService is a desktop-only dependency so the
  /// provider is conditionally added in main.dart.
  NotificationService? _maybeNotificationService() {
    try {
      return context.read<NotificationService>();
    } catch (_) {
      return null;
    }
  }

  /// Scroll-driven read-marker update.  Called on every scroll event;
  /// debounced so a single drag only sends one network request once
  /// the user has stopped scrolling.
  void _scheduleMarkRoomRead() {
    if (_timeline == null) return;
    if (!_scrollController.hasClients) return;
    if (_scrollDebounce) return;
    _markReadDebounceTimer?.cancel();
    _markReadDebounceTimer = Timer(_markReadDebounce, () {
      if (!mounted) return;
      _markRoomRead();
    });
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void _onTimelineUpdate() {
    if (!mounted) return;
    // When new history arrives, the SDK clears `Room.prev_batch` once
    // we reach the beginning of the room.  Drop the skeleton state
    // in that case so the user is not left looking at placeholder
    // tiles that no longer represent pending work.
    if (_atLocalEndOfHistory && widget.room.prev_batch == null) {
      _atLocalEndOfHistory = false;
    }
    setState(() => _timelineVersion++);
  }

  @override
  void dispose() {
    _markReadDebounceTimer?.cancel();
    _markReadDebounceTimer = null;
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _timeline?.cancelSubscriptions();
    super.dispose();
  }
}

/// Vertical column of floating action buttons anchored above the chat
/// composer.  Hides the entire column when the user is parked at the
/// bottom of the timeline *and* the room has no unread messages.
///
/// Two pills are supported:
///   1. Jump-to-unread — shown when the room has unread messages
///      below the current viewport.  Takes visual priority when both
///      pills are visible.
///   2. Scroll-to-bottom — shown when the user has scrolled up away
///      from the newest messages.  Lets them jump back without
///      dragging all the way down.
///
/// Each pill animates in and out independently so a single state
/// change does not cause the whole column to pop.
class _FloatingActionColumn extends StatelessWidget {
  const _FloatingActionColumn({
    required this.unreadCount,
    required this.isScrolledUp,
    required this.unreadVisible,
    required this.onJumpToUnread,
    required this.onScrollToBottom,
    required this.onDismissUnread,
    required this.isJumping,
  });

  final int unreadCount;
  final bool isScrolledUp;
  final bool unreadVisible;
  final Future<void> Function() onJumpToUnread;
  final VoidCallback onScrollToBottom;

  /// Tapping the close icon on the jump-to-unread pill invokes this.
  /// The pill is dismissed but the unread events themselves remain —
  /// the user can still scroll up to see them, and a fresh pill will
  /// re-appear the next time the room has unread state.
  final VoidCallback onDismissUnread;

  /// True while the timeline is paginating to bring the first unread
  /// event into the cache.  The pill switches to a "loading" label so
  /// the user has feedback that the tap was registered.
  final bool isJumping;

  @override
  Widget build(BuildContext context) {
    final motion = Motion.of(context);
    final animDuration = motion.duration(const Duration(milliseconds: 180));
    final animCurve = motion.curve();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedSize(
          duration: animDuration,
          curve: animCurve,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: animDuration,
            switchInCurve: animCurve,
            switchOutCurve: animCurve,
            child: unreadVisible
                ? _JumpToUnreadPill(
                    key: const ValueKey('jump-to-unread'),
                    count: unreadCount,
                    isLoading: isJumping,
                    onTap: onJumpToUnread,
                    onDismiss: onDismissUnread,
                  )
                : const SizedBox.shrink(key: ValueKey('jump-to-unread-empty')),
          ),
        ),
        AnimatedSize(
          duration: animDuration,
          curve: animCurve,
          alignment: Alignment.bottomCenter,
          child: AnimatedSwitcher(
            duration: animDuration,
            switchInCurve: animCurve,
            switchOutCurve: animCurve,
            child: isScrolledUp
                ? _ScrollToBottomPill(
                    key: const ValueKey('scroll-to-bottom'),
                    onTap: onScrollToBottom,
                  )
                : const SizedBox.shrink(key: ValueKey('scroll-to-bottom-empty')),
          ),
        ),
      ],
    );
  }
}

/// "Scroll to bottom" floating action button.  Shown when the user
/// has scrolled away from the bottom of the timeline.  Tapping
/// animates the scroll back to the newest message.
class _ScrollToBottomPill extends StatelessWidget {
  const _ScrollToBottomPill({required this.onTap, super.key});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.secondaryContainer,
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.arrowDown,
                  size: 14,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.scrollToBottom,
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Floating "Jump to first unread" pill rendered above the chat composer
/// when the room has unread messages below the current viewport.
///
/// The pill is intentionally lightweight: it shows the unread count, an
/// up-arrow to hint at the action, and a small dismiss (×) button so the
/// user can close it without engaging.  Tapping the pill body scrolls the
/// timeline to the first event newer than the fully-read marker and sends
/// a read receipt so the badge clears.  Tapping the close icon only hides
/// the pill — the unread state itself is unchanged and the pill will
/// re-appear if the user navigates away and back into the room while
/// there is still unread content.
class _JumpToUnreadPill extends StatelessWidget {
  const _JumpToUnreadPill({
    required this.count,
    required this.isLoading,
    required this.onTap,
    required this.onDismiss,
    super.key,
  });

  final int count;

  /// When `true`, the pill swaps its label to a "loading" message and
  /// shows a small progress indicator.  Tap handling is disabled so the
  /// user can't queue up multiple paginate requests.
  final bool isLoading;

  final Future<void> Function() onTap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final label = isLoading
        ? l10n.jumpToUnreadLoading
        : (count == 1
            ? l10n.jumpToFirstUnread
            : l10n.jumpToFirstUnreadMany(count));

    // Two tap targets: the pill body (jump) and a small × button on the
    // trailing edge (dismiss).  Using a single [Material] + a [Row] of
    // two [InkWell]s keeps the rounded-pill silhouette without
    // splitting the visual into two separate chips.
    return Material(
      color: scheme.primary,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              onTap: isLoading
                  ? null
                  : () {
                      // Fire and forget — the pill hides itself on the
                      // next rebuild once the read marker is updated
                      // and the unread count drops to zero.
                      // ignore: discarded_futures
                      onTap();
                    },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isLoading)
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.6,
                          valueColor: AlwaysStoppedAnimation(scheme.onPrimary),
                        ),
                      )
                    else
                      Icon(
                        LucideIcons.arrowUp,
                        size: 14,
                        color: scheme.onPrimary,
                      ),
                    const SizedBox(width: 6),
                    Text(
                      label,
                      style: TextStyle(
                        color: scheme.onPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 4),
            _DismissButton(
              tooltip: l10n.unreadPillDismissTooltip,
              onTap: isLoading ? () {} : onDismiss,
              color: scheme.onPrimary,
            ),
          ],
        ),
      ),
    );
  }
}

/// Tiny close icon used as the dismiss affordance on [_JumpToUnreadPill].
/// Rendered as a separate widget so its hit-test region is its own
/// (24×24 logical pixels) and the larger pill body underneath stays
/// responsive to the "jump" action.
class _DismissButton extends StatelessWidget {
  const _DismissButton({
    required this.tooltip,
    required this.onTap,
    required this.color,
  });

  final String tooltip;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onTap,
        radius: 14,
        // Slightly darker overlay so the dismiss button reads as a
        // separate affordance from the pill body.
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(
            LucideIcons.x,
            size: 12,
            color: color,
          ),
        ),
      ),
    );
  }
}

/// Renders a list of events fetched by ID for the pinned-only filter.
///
/// These events are not necessarily present in the room's [Timeline.events]
/// list, so they cannot be rendered by [TimelineView]'s filter mechanism.
/// Instead, this widget takes the pre-fetched events and renders each one
/// with a [TimelineItem], computing sender grouping from their timestamps.
class _PinnedEventsList extends StatelessWidget {
  const _PinnedEventsList({
    required this.events,
    required this.room,
    required this.displayType,
    required this.fontSize,
    required this.bubbleRadius,
    required this.scrollController,
    this.onReply,
    this.onThread,
    this.onForward,
  });

  final List<Event> events;
  final Room room;
  final DisplayType displayType;
  final double fontSize;
  final double bubbleRadius;
  final ScrollController scrollController;
  final void Function(Event event)? onReply;
  final void Function(Event event)? onThread;
  final void Function(Event event)? onForward;

  @override
  Widget build(BuildContext context) {
    // Events are already sorted oldest-first.  Compute sender grouping:
    // each event is a continuation of the *newer* event below it
    // (which appears later in the list).  Since the ListView is reversed,
    // index 0 appears at the bottom (newest message) of the viewport.
    final Map<String, int> eventIdToItemIndex = {};
    final itemCount = events.length;

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // index 0 = last in list (newest), index n-1 = first (oldest)
        final event = events[itemCount - 1 - index];

        // Determine if this event is a continuation of the older event
        // above it in the list (the *next* newer event in reversed order).
        final isContinuation = index + 1 < itemCount &&
            _isSameSenderAndCloseInTime(
              events[itemCount - 1 - index],
              events[itemCount - 2 - index],
            );

        eventIdToItemIndex[event.eventId] = index;

        return TimelineItem(
          event: event,
          room: room,
          displayType: displayType,
          isGroupStart: !isContinuation,
          isGroupContinuation: isContinuation,
          fontSize: fontSize,
          bubbleRadius: bubbleRadius,
          onReply: onReply != null ? () => onReply!(event) : null,
          onThread: onThread != null ? () => onThread!(event) : null,
          onForward:
              onForward != null ? () => onForward!(event) : null,
          onJumpToEvent: (String eventId) {
            final targetIdx = eventIdToItemIndex[eventId];
            if (targetIdx == null) return;
            if (!scrollController.hasClients) return;
            final position = scrollController.position;
            final range =
                position.maxScrollExtent - position.minScrollExtent;
            final fraction =
                itemCount > 1 ? targetIdx / (itemCount - 1) : 0.0;
            final targetOffset =
                position.minScrollExtent + range * fraction;
            scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        );
      },
    );
  }

  /// True when [newer] and [older] are from the same sender within ~10 min.
  bool _isSameSenderAndCloseInTime(Event newer, Event older) {
    if (newer.senderId != older.senderId) return false;
    return _sameEnvironment(newer.originServerTs, older.originServerTs);
  }

  /// True when two timestamps fall within 10 minutes of each other.
  bool _sameEnvironment(DateTime a, DateTime b) {
    final diff = a.difference(b).inMinutes.abs();
    return diff <= 10;
  }
}
