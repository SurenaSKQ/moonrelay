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
  /// created.
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

  /// Builds a history window from a `/context` response, or returns null if
  /// the window is not usable.
  ///
  /// A `/context` window is only worth showing if it can reach the rest of the
  /// room. `room.getEventContext` takes the window's `prevBatch` from the
  /// response's `start` token (`room.dart:1726-1730`); when that token is
  /// empty the window holds a handful of events and pages in neither
  /// direction, so it renders as a dead end.
  ///
  /// A dead end is worse than a failure. It looks like the room, it is not the
  /// room, and the only symptom is that scrolling does nothing. Reporting the
  /// failure instead lets the existing "that message is no longer available"
  /// path say so, which is more useful than a view that lies quietly.
  ///
  /// Whether the SDK re-anchors correctly for an event older than the live tail
  /// was never confirmed against a real server, so
  /// this is treated as possible rather than impossible. It costs one check.
  static TimelineSegment? fromEventContext({
    required String id,
    required Timeline timeline,
    required String anchorEventId,
    Logger? logger,
  }) {
    final segment = TimelineSegment(
      id: id,
      timeline: timeline,
      isLive: false,
      anchorEventId: anchorEventId,
      logger: logger,
    );
    if (segment.events.isEmpty) {
      logger?.w('Event context for $anchorEventId came back empty');
      return null;
    }
    if (!segment.canPageOlder && !segment.canPageNewer) {
      logger?.w(
        'Event context for $anchorEventId is anchored to nothing '
        '(prevBatch empty, nextBatch empty); refusing to show a dead-end window',
      );
      return null;
    }
    return segment;
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
  /// bug would otherwise come back.
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
  List<Event> flatten() => [for (final group in _dedupedGroups()) ...group];

  /// Each segment's surviving events, in render order, deduplicated across
  /// segments by [flatten]'s rule.
  ///
  /// The store rather than the model knows where the segment boundaries are,
  /// so this is the only place that has to answer it. The model receives
  /// flat groups and decides where a gap belongs between them.
  List<List<Event>> eventGroups() => _dedupedGroups();

  /// Indices in [flatten] *after* which a gap marker belongs.
  ///
  /// A boundary is treated as a hole when the older segment's newest event
  /// is far enough behind the newer segment's oldest event. That is a
  /// heuristic and there is no exact signal available: Matrix events carry
  /// no stream ordering token that survives being put in a `/context`
  /// window, and two adjacent events routinely share an
  /// `originServerTs`. So this compares time and tolerates a gap of
  /// [kGapTolerance] before calling it.
  ///
  /// The alternative, showing nothing, was rejected for a reason worth
  /// recording: two adjacent windows render as one continuous conversation
  /// with a silent hole in the middle, and the user reads the part below the
  /// hole as if it directly follows the part above it. They then send a
  /// message that looks like a reply to something it is not.
  ///
  /// Overlaps are not gaps. When the older segment's newest event is newer
  /// than or equal to the newer segment's oldest event, the two ranges
  /// touch or overlap and nothing is missing; that is the normal shape when
  /// a window overlaps the tail it was built from.
  Set<int> gapBoundaries() {
    final groups = _dedupedGroups();
    final boundaries = <int>{};
    var seen = 0;
    for (var i = 0; i < groups.length - 1; i++) {
      final newer = groups[i];
      final older = groups[i + 1];
      if (newer.isEmpty || older.isEmpty) continue;
      seen += newer.length;
      final newerOldest = newer.last.originServerTs;
      final olderNewest = older.first.originServerTs;
      if (newerOldest.difference(olderNewest) > kGapTolerance) {
        boundaries.add(seen - 1);
      }
    }
    return boundaries;
  }

  /// How far apart two events on either side of a segment boundary may be
  /// before the boundary is drawn as a gap.
  ///
  /// Ten minutes is a judgement call. It is long enough that a busy room
  /// paging in one screenful of messages does not produce a marker, and
  /// short enough that an afternoon's silence produces one. Events sharing a
  /// timestamp, which is common inside one send burst, are zero apart and
  /// never gap.
  static const Duration kGapTolerance = Duration(minutes: 10);

  /// Segment groups after the cross-segment dedupe, render order.
  ///
  /// Later segments win an overlap. The live tail is walked first, so on a
  /// shared event it is the tail's instance that survives, which is the one
  /// the app keeps updating as sync brings in reactions and edits. A window's
  /// copy is a snapshot from `/context` and does not.
  List<List<Event>> _dedupedGroups() {
    final seen = <String>{};
    final groups = <List<Event>>[];
    for (final segment in _segmentsNewestFirst) {
      final group = <Event>[];
      for (final event in segment.events) {
        if (seen.add(event.eventId)) group.add(event);
      }
      if (group.isNotEmpty) groups.add(group);
    }
    return groups;
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

  /// The segment the scroll-to-load path should extend.
  ///
  /// The oldest one, because that is the end of the render list a scroll
  /// reaches by dragging up. When no windows are loaded this is the live
  /// tail, which is the pre-store behaviour.
  TimelineSegment get oldestSegment =>
      _history.isEmpty ? live : _history.last;

  /// The segment id for each group index produced by [eventGroups].
  ///
  /// The model places gap markers by group index, so this is how a gap on
  /// screen is turned back into the segment that can close it. Groups skip
  /// empty segments, so the indices line up with [eventGroups] and not with
  /// [history].
  List<String> groupSegmentIds() => [
        for (final segment in _segmentsNewestFirst)
          if (segment.events.isNotEmpty) segment.id,
      ];

  /// The timeline behind each group, aligned with [eventGroups].
  ///
  /// The renderer hands each item the timeline of the group it came from, not
  /// the live tail. Reactions, edits and reply resolution all read
  /// `timeline.aggregatedEvents`, which is per-timeline, so an item from a
  /// history window handed the tail finds no aggregates for any event in it.
  List<Timeline> segmentTimelines() => [
        for (final segment in _segmentsNewestFirst)
          if (segment.events.isNotEmpty) segment.timeline,
      ];

  /// Pages the oldest segment one step older.
  Future<int> pageOldest({int count = Room.defaultHistoryCount}) =>
      pageOlder(oldestSegment.id, count: count);

  /// Pages the segment that ends group [groupIndex] one step older, which is
  /// how a gap closes.
  ///
  /// Group *i* holds the newer side of the boundary and the gap follows its
  /// last event, so the events that close the hole are *older* than that
  /// event. Paging the group forward is the opposite direction and would
  /// never meet group *i+1*.
  ///
  /// This is also the only direction the live tail can take: it is anchored
  /// at the newest event in the room and its `chunk.nextBatch` is empty, so
  /// `pageNewer` on it is permanently impossible. Paging it older is exactly
  /// what the scroll-to-load path already does.
  Future<int> closeGapAfterGroup(
    int groupIndex, {
    int count = Room.defaultHistoryCount,
  }) {
    final ids = groupSegmentIds();
    if (groupIndex < 0 || groupIndex >= ids.length) return Future.value(0);
    return pageOlder(ids[groupIndex], count: count);
  }

  /// Every segment in display order: the live tail first, then history
  /// windows newest first.
  ///
  /// The live tail is the *newest* run, so it leads. Index 0 of the render
  /// list is the newest event, because `reverse: true` puts index 0 at the
  /// bottom of the scroll view. Putting history first would render the
  /// oldest messages at the bottom and the newest at the top, which is
  /// upside down; it was wrong in the first cut of this class and the gap
  /// work is what exposed it.
  List<TimelineSegment> get _segmentsNewestFirst => [live, ..._history];

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