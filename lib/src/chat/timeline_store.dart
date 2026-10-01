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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';

/// One contiguous run of events, backed by a [Timeline].
///
/// A segment is either the room's live tail or a detached history window
/// built from `/context`. Both are the same thing to everything downstream:
/// a newest-first event list with its own pagination anchors. There is one
/// type rather than a `LiveSegment` and a `HistorySegment` because an `is`
/// branch on segment kind would otherwise have to be written in
/// `HistoryPager`, in `buildTimelineItems`, and in every gap calculation, to
/// buy nothing.
///
/// [isLive] is the only distinction, and it is used in exactly one place:
/// [TimelineStore.collapseHistory] must never drop the live segment.
class TimelineSegment {
  TimelineSegment({
    required this.id,
    required this.timeline,
    required this.isLive,
    this.anchorEventId,
    this.logger,
  });

  /// Stable identity for this segment, used to evict it later.
  ///
  /// Not the anchor event: two windows around the same event, or a window
  /// reopened after eviction, would collide.
  final String id;

  /// The SDK timeline backing this run.
  ///
  /// Only the live segment keeps its subscriptions. A `/context` window
  /// subscribes to `onSync` on construction and the SDK's
  /// `_removeEventsNotInThisSync` deletes every event not present in a
  /// gap-limited sync, so a window must be detached the moment it is
  /// created. See TIMELINE_STORE_PLAN.md 3.1.
  final Timeline timeline;

  /// True for the room's live tail. Exactly one segment per store has it.
  final bool isLive;

  /// The event this window was built around, or `null` for the live tail.
  ///
  /// Replaces `ChatTimeline._anchoredEventId`, which had to be a nullable
  /// `String` on the widget because there was nowhere else to record which
  /// window was displayed.
  final String? anchorEventId;

  /// Optional logger for failed pages.
  final Logger? logger;

  /// Events in this segment, newest first, matching SDK order.
  List<Event> get events => timeline.events;

  /// Releases the SDK subscriptions this segment owns.
  ///
  /// Meaningless for the live segment, which must stay subscribed to
  /// follow sync. Callers evicting segments should go through
  /// [TimelineStore] rather than calling this directly.
  void cancel() {
    if (isLive) return;
    timeline.cancelSubscriptions();
  }

  // -- Paging ----------------------------------------------------

  /// True when [pageOlder] has somewhere to go.
  ///
  /// The rule is `Timeline.canRequestHistory` *or* a non-empty
  /// `chunk.prevBatch`, and both halves are load-bearing:
  ///
  /// - `canRequestHistory` consults `room.prev_batch`, which is the room's
  ///   live sync token and has nothing to do with this segment's own
  ///   pagination. On a fully synced room it is `null`, so a `/context`
  ///   window carrying a perfectly good `start` token reports itself
  ///   exhausted and silently refuses to page.
  /// - `chunk.prevBatch` alone is not sufficient either, because the live
  ///   tail reads its initial page from the database and its chunk anchors
  ///   are empty until the first server page.
  ///
  /// Exhausted is an **empty string**, not `null`: `getRoomEvents` assigns
  /// `chunk.prevBatch = newPrevBatch ?? ''` for `Direction.b`
  /// (timeline.dart:296).
  ///
  /// This is the second time this rule has been needed. `HistoryPager`
  /// carries an identical `_canPageOlder`, and a store is exactly where the
  /// bug would otherwise come back. See TIMELINE_STORE_PLAN.md 3.4.
  bool get canPageOlder {
    if (timeline.canRequestHistory) return true;
    return timeline.chunk.prevBatch.isNotEmpty;
  }

  /// True when [pageNewer] has somewhere to go.
  ///
  /// Always false for the live tail. `canRequestFuture` is `!allowNewEvent`,
  /// permanently false on a live segment, and that asymmetry is the whole
  /// reason the live tail needed substituting in the first place. A live
  /// segment does not page forward; it receives new events from sync.
  ///
  /// For a window, the gate is its own `chunk.nextBatch` and nothing else.
  /// A `/context` window is constructed as a *fragmented* timeline, so the
  /// SDK flips `allowNewEvent` to false when `chunk.nextBatch` is non-empty
  /// (timeline.dart:365-370) and `canRequestFuture` is therefore true from
  /// birth. It also clears that flag itself once a page reaches the end
  /// (timeline.dart:269-275), but leaning on an SDK-internal flag for
  /// exhaustion is how the previous round of this bug happened: the
  /// authoritative signal for a segment is its own pagination anchor, so
  /// that is what is checked. `pageNewer` would otherwise fire a request
  /// with `from: ''`.
  bool get canPageNewer => !isLive && timeline.chunk.nextBatch.isNotEmpty;

  /// Requests one page of older events into this segment.
  ///
  /// Returns the number of events the server sent, which is `0` when the
  /// segment is exhausted or the request failed.
  ///
  /// Uses `getRoomEvents` rather than `requestHistory`. This is not a
  /// preference: `requestHistory` routes through `room.prev_batch` via
  /// `Room.requestHistory`, while `getRoomEvents` pages off this segment's
  /// own `chunk.prevBatch`/`chunk.nextBatch` (timeline.dart:231-237). Only
  /// the latter is correct for a detached window.
  Future<int> pageOlder({
    int count = Room.defaultHistoryCount,
    StateFilter? filter,
    Duration timeout = kSegmentPageTimeout,
  }) =>
      _page(Direction.b, count: count, filter: filter, timeout: timeout);

  /// Requests one page of newer events into this segment.
  ///
  /// Only meaningful for a detached window, which is the only kind that can
  /// page forward. See [canPageNewer].
  Future<int> pageNewer({
    int count = Room.defaultHistoryCount,
    StateFilter? filter,
    Duration timeout = kSegmentPageTimeout,
  }) =>
      _page(Direction.f, count: count, filter: filter, timeout: timeout);

  /// Default per-request ceiling for [pageOlder] and [pageNewer].
  static const Duration kSegmentPageTimeout = Duration(seconds: 20);

  Future<int> _page(
    Direction direction, {
    required int count,
    StateFilter? filter,
    required Duration timeout,
  }) async {
    // Checked here rather than trusted to the caller: a page fired at an
    // exhausted segment wastes a round trip and, on the live tail,
    // `requestHistory` would consult the room's own token and page the
    // wrong segment entirely.
    final canPage =
        direction == Direction.b ? canPageOlder : canPageNewer;
    if (!canPage) return 0;

    try {
      return await timeline
          .getRoomEvents(
            historyCount: count,
            direction: direction,
            filter: filter,
          )
          .timeout(timeout);
    } catch (e) {
      // A failed page must not propagate: paging is a background fill, and
      // the caller wants "nothing new" rather than an exception it would
      // have to catch identically at four call sites.
      logger?.w('Segment $id failed to page ${direction.name}', error: e);
      return 0;
    }
  }
}

/// The ordered set of segments backing one room's timeline.
///
/// This exists to stop asking a single [Timeline] to be both the room's live
/// tail and an arbitrary history window. It is pure data: no SDK calls, no
/// Flutter, no widget. Paging lives on [TimelineSegment] in the next stage and
/// the view renders [flatten] in the one after.
///
/// See TIMELINE_STORE_PLAN.md for the design and the SDK constraints that
/// shape it.
class TimelineStore {
  TimelineStore({required this.live});

  /// The room's live tail. Always present, never evicted, never duplicated
  /// into [history].
  final TimelineSegment live;

  /// Detached history windows, newest first.
  ///
  /// Newest first matches the display order, so the segment nearest the top
  /// of the scroll view is the most recently added one.
  final List<TimelineSegment> _history = [];

  /// Bumped on every mutation, and on nothing else.
  ///
  /// This is what the view's cache key reads instead of
  /// `identityHashCode(timeline)`. A store survives a jump, so its version
  /// does not change when a history segment is added; today every jump
  /// discards the timeline object and invalidates the whole item cache.
  int _version = 0;

  int get version => _version;

  List<TimelineSegment> get history => List.unmodifiable(_history);

  /// True when any history window is loaded.
  ///
  /// The replacement for `_anchoredEventId != null`. It is false for a
  /// live-only store, and it does not depend on a window happening to have
  /// been opened around a specific event.
  bool get isViewingHistory => _history.isNotEmpty;

  /// Every event across every segment, newest first, deduplicated.
  ///
  /// This is the render list. Order is newest segment first, and within a
  /// segment newest event first, which is the order the `reverse: true`
  /// `ListView` expects.
  ///
  /// Deduplicated on `eventId`, and this is not a theoretical concern: a
  /// `/context` window routinely overlaps the live tail, because both are
  /// drawn from the same room and the window is built around an event that
  /// may well be inside the tail. Without the dedupe the same message
  /// renders twice in one list, once as part of the tail and once as part of
  /// the window, and the reply context menu on either copy acts on the
  /// same event.
  ///
  /// Later segments win. The live segment is flattened first, so a history
  /// window's copy of an overlapping event is the one that survives, which
  /// matters because a window's events are decrypted in a context that may
  /// be richer than what is in the tail's cache.
  List<Event> flatten() {
    final seen = <String>{};
    final out = <Event>[];
    for (final segment in _segmentsNewestFirst) {
      for (final event in segment.events) {
        if (seen.add(event.eventId)) out.add(event);
      }
    }
    return out;
  }

  /// Position of [eventId] in [flatten], or `-1` when it is not loaded.
  ///
  /// Exact, and the answer a jump needs: the view uses it to index the
  /// render list directly. See WORK_DONE.md section 55 for why the previous
  /// map could not be trusted.
  ///
  /// The traversal has to apply the same dedupe as [flatten], or it counts
  /// the events [flatten] dropped and answers with an index that is too
  /// high by however many duplicates preceded the target. That is the same
  /// class of bug as the model map that was off by one: two traversals of
  /// one list that disagree about what the list contains.
  int indexOf(String eventId) {
    final seen = <String>{};
    var index = 0;
    for (final segment in _segmentsNewestFirst) {
      for (final event in segment.events) {
        if (!seen.add(event.eventId)) continue;
        if (event.eventId == eventId) return index;
        index++;
      }
    }
    return -1;
  }

  /// The segment holding [eventId], or `null` when it is not loaded.
  TimelineSegment? segmentFor(String eventId) {
    for (final segment in _segmentsNewestFirst) {
      for (final event in segment.events) {
        if (event.eventId == eventId) return segment;
      }
    }
    return null;
  }

  /// Every segment in display order: history windows newest first, then the
  /// live tail.
  List<TimelineSegment> get _segmentsNewestFirst => [..._history, live];

  /// Pages [segmentId] one step older and bumps [version] if it landed.
  ///
  /// The store owns the version bump rather than the segment, because
  /// `getRoomEvents` fires `onInsert` once per event *while* it is
  /// appending to `chunk.events` (timeline.dart:302-304). A listener that
  /// rebuilt from inside that callback would read a half-appended list. The
  /// page therefore returns before anything here runs, and the bump happens
  /// once, after the list is whole.
  ///
  /// Returns the number of events loaded, `0` when nothing was added.
  Future<int> pageOlder(
    String segmentId, {
    int count = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {
    final segment = _segmentById(segmentId);
    if (segment == null) return 0;
    final added = await segment.pageOlder(count: count, filter: filter);
    if (added > 0) _version++;
    return added;
  }

  /// Pages [segmentId] one step newer. See [pageOlder] for why the bump
  /// belongs here.
  Future<int> pageNewer(
    String segmentId, {
    int count = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {
    final segment = _segmentById(segmentId);
    if (segment == null) return 0;
    final added = await segment.pageNewer(count: count, filter: filter);
    if (added > 0) _version++;
    return added;
  }

  /// The segment with [segmentId], live tail included, or `null`.
  TimelineSegment? _segmentById(String segmentId) {
    if (live.id == segmentId) return live;
    for (final segment in _history) {
      if (segment.id == segmentId) return segment;
    }
    return null;
  }

  /// Adds a history window.
  ///
  /// The segment's subscriptions are cancelled here, not at construction,
  /// because this is the first point at which the store is certain the
  /// window will be kept rather than discarded. A window that reached
  /// [flatten] while still subscribed would have its events deleted by the
  /// SDK on the next gap-limited sync.
  void addHistory(TimelineSegment segment) {
    if (segment.isLive) {
      throw ArgumentError.value(
        segment.id,
        'segment',
        'the live segment is fixed at construction; use TimelineStore.live',
      );
    }
    if (_history.any((s) => s.id == segment.id)) {
      throw ArgumentError.value(
        segment.id,
        'segment',
        'a segment with this id is already loaded',
      );
    }
    segment.cancel();
    _history.insert(0, segment);
    _version++;
  }

  /// Drops one history window and releases it.
  ///
  /// Returns true when a segment was removed. Unknown ids are ignored: the
  /// user can collapse a window by clicking "back to latest" after the
  /// window has already been evicted by a room switch, and throwing in a
  /// click handler for that is worse than doing nothing.
  bool removeHistory(String segmentId) {
    final before = _history.length;
    _history.removeWhere((s) => s.id == segmentId);
    if (_history.length == before) return false;
    _version++;
    return true;
  }

  /// Drops every history window, returning the view to the live tail.
  ///
  /// The replacement for `ChatTimeline.backToLive`. That rebuilt the
  /// timeline from scratch, discarding the live tail and re-fetching it,
  /// because the tail had been thrown away when the window replaced it.
  /// Here the tail was never discarded, so collapsing is just a list
  /// mutation.
  ///
  /// Returns the number of segments dropped.
  int collapseHistory() {
    final dropped = _history.length;
    if (dropped == 0) return 0;
    _history.clear();
    _version++;
    return dropped;
  }
}