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