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

import 'package:matrix/matrix.dart';

/// Helper utilities for Matrix thread detection and inspection.
class ThreadUtils {
  ThreadUtils._();

  /// Returns `true` when [event] is a thread root: an event whose
  /// relationship type is `m.thread` and whose `event_id` points to itself.
  static bool isThreadRoot(Event event) =>
      event.relationshipType == RelationshipTypes.thread &&
      event.relationshipEventId == event.eventId;

  /// Returns `true` when [event] is a thread reply: an event whose
  /// relationship type is `m.thread` that is NOT the root event.
  static bool isThreadReply(Event event) =>
      event.relationshipType == RelationshipTypes.thread &&
      event.relationshipEventId != null &&
      event.relationshipEventId != event.eventId;

  /// Returns `true` when [event] is a thread root or a thread reply.
  static bool isThreadRelated(Event event) =>
      event.relationshipType == RelationshipTypes.thread;

  /// Returns `true` when the event has at least one thread reply aggregated
  /// in the given [timeline].
  static bool hasThreadReplies(Event event, Timeline timeline) =>
      event.hasAggregatedEvents(timeline, RelationshipTypes.thread);

  /// Returns the number of thread replies for the given event in the
  /// given [timeline].
  static int threadReplyCount(Event event, Timeline timeline) =>
      event.aggregatedEvents(timeline, RelationshipTypes.thread).length;

  /// Returns the thread replies for the given event, sorted oldest-first.
  static List<Event> threadReplies(Event event, Timeline timeline) {
    final replies = event.aggregatedEvents(timeline, RelationshipTypes.thread);
    final sorted = replies.toList()
      ..sort((a, b) => a.originServerTs.compareTo(b.originServerTs));
    return sorted;
  }

  /// Returns `true` when the event should appear as a standalone item in
  /// the main timeline, i.e. it's either a regular event (no relationship)
  /// or a thread root.  Everything else (reactions, edits, thread replies)
  /// is excluded.
  static bool isVisibleInMainTimeline(Event event) {
    if (event.relationshipEventId == null) return true;
    if (isThreadRoot(event)) return true;
    return false;
  }

  /// Builds a map of `eventId -> threadReplyCount` for every event in
  /// [timeline] in a single pass.
  ///
  /// Callers (notably [TimelineView]) used to invoke
  /// [threadReplyCount] / [hasThreadReplies] once per visible event,
  /// each of which internally scans the timeline for matching replies.
  /// For a timeline of N events with M thread replies, that produced
  /// O(N*M) work; a single linear pass here brings that down to O(N+M).
  ///
  /// The returned map only contains entries for events with at least one
  /// reply, so callers can use `map[id] ?? 0` to read the count.
  static Map<String, int> buildThreadReplyCounts(Timeline timeline) {
    final counts = <String, int>{};
    for (final event in timeline.events) {
      final parentId = event.relationshipEventId;
      final type = event.relationshipType;
      if (parentId == null || parentId == event.eventId) continue;
      if (type != RelationshipTypes.thread) continue;
      counts.update(parentId, (v) => v + 1, ifAbsent: () => 1);
    }
    return counts;
  }
}
