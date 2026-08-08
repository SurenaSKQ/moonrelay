// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:matrix/matrix.dart';

import 'package:moonrelay/src/helpers/thread_utils.dart';

// -- State event detection --

/// Number of minutes within which two events from the same sender are
/// considered part of the same visual "environment" for grouping purposes.
const int kMinutesBetweenEnvironments = 10;

/// True when [event] is a Matrix state event (room metadata, membership,
/// etc.) as opposed to a content event that should be rendered as a
/// standalone message row.
///
/// Uses an explicit **whitelist** of content event types so that
/// `m.room.encrypted` events are never misclassified as state events.
/// The previous implementation (`event.type != Message && event.type != Sticker`)
/// treated anything that wasn't a message or sticker as a state event, which
/// caused encrypted messages to be collapsed into [StateEventTile] batches
/// instead of rendering as individual chat bubbles with their own avatar and
/// timestamp.
bool isStateEvent(Event event) {
  const contentEventTypes = <String>{
    EventTypes.Message,
    EventTypes.Sticker,
    EventTypes.Encrypted,
  };
  return !contentEventTypes.contains(event.type);
}

/// True when [event] is a content event that renders as a regular message
/// row (message, sticker, or encrypted body).  Inverse of [isStateEvent].
///
/// Mirrors [isMessageLikeEvent] from `chat_unread_utils.dart` but also
/// includes encrypted events, which are content rows that the unread-count
/// logic also needs to see.
bool isContentEvent(Event event) => !isStateEvent(event);

// -- Helper predicates --

/// True when [newer] and [older] belong to the same sender and fall within
/// the same ~10-minute environment, i.e. they should share a visual group.
///
/// [newer] is the chronologically newer event (displayed lower in the
/// timeline) and [older] is the earlier event.  When they form a group,
/// the **older** event acts as the group start (shows avatar/name) and the
/// newer event is a continuation (no avatar).
///
/// Stickers never group with adjacent messages -- they are short,
/// visually-distinct and conventionally shown as standalone rows with
/// their own sender label.
bool isContinuation(Event newer, Event older) {
  if (newer.senderId != older.senderId) return false;
  if (newer.messageType == MessageTypes.Sticker ||
      older.messageType == MessageTypes.Sticker) {
    return false;
  }
  return newer.originServerTs.millisecondsSinceEpoch -
      older.originServerTs.millisecondsSinceEpoch <
      1000 * 60 * kMinutesBetweenEnvironments;
}

/// True when [newer] and [older] fall on different calendar days.
bool isDifferentDay(Event newer, Event older) {
  final n = newer.originServerTs;
  final o = older.originServerTs;
  return n.year != o.year || n.month != o.month || n.day != o.day;
}

/// Returns the next visible (non-state) event after index [currentI] in
/// [visibleIndices], or null if none exists.
///
/// Walks past hidden state events so they don't incorrectly absorb the
/// sender info for grouping purposes.
Event? nextVisibleMessage(
  List<int> visibleIndices,
  List<Event> events,
  int currentI,
) {
  int j = currentI + 1;
  while (j < visibleIndices.length) {
    final ev = events[visibleIndices[j]];
    if (!isStateEvent(ev)) {
      return ev;
    }
    j++;
  }
  return null;
}

// -- Visible indices --

/// Indices (into `events`) of events that should appear as standalone
/// items in the main timeline.
///
/// Events are in SDK order (newest -> oldest).  Thread roots are kept
/// visible; all other related events (reactions, edits, thread replies)
/// are excluded because they render inline with their parent.
List<int> visibleIndices(List<Event> events, bool Function(Event)? filter) {
  final indices = List<int>.generate(events.length, (i) => i);
  indices.removeWhere((i) {
    final event = events[i];
    if (filter != null) return !filter(event);
    return !ThreadUtils.isVisibleInMainTimeline(event);
  });
  return indices;
}

// -- Undecryptable counter --

/// Counts encrypted events visible under the active filter / state-event
/// toggle.  Used to drive the undecryptable banner so a new encrypted
/// arrival updates the badge without invalidating the full item cache.
int countUndecryptable(List<Event> events, bool Function(Event)? filter) {
  var count = 0;
  for (final ev in events) {
    if (filter != null) {
      if (!filter(ev)) continue;
    } else {
      if (!ThreadUtils.isVisibleInMainTimeline(ev)) continue;
    }
    if (ev.type != EventTypes.Encrypted) continue;
    count++;
  }
  return count;
}

// -- Item model --

/// Kind of entry in the visible timeline list.
enum TimelineItemKind {
  /// A regular message, sticker, or encrypted event.
  event,

  /// A date-boundary separator between two events on different calendar days.
  dateSeparator,

  /// A collapsed batch of consecutive state events.
  stateEventBatch,

  /// The undecryptable-encrypted banner (always at index 0 of the item list).
  undecryptableBanner,
}

/// A single visible entry produced by [buildTimelineItems].
///
/// The [TimelineView] widget maps each entry to a concrete [Widget]
/// ([TimelineItem], [DateSeparator], [StateEventTile], [UndecryptableBanner]).
/// Keeping the entry as plain data lets the grouping, ordering, and
/// continuation logic be unit-tested without a Flutter dependency.
class TimelineItemEntry {
  const TimelineItemEntry({
    required this.kind,
    this.event,
    this.stateEvents,
    this.isGroupStart = true,
    this.isGroupContinuation = false,
    this.replyCount = 0,
    this.date,
    this.undecryptableCount = 0,
  });

  /// Which kind of entry this is (see [TimelineItemKind]).
  final TimelineItemKind kind;

  /// The Matrix event, for [TimelineItemKind.event].
  final Event? event;

  /// The batch of state events, for [TimelineItemKind.stateEventBatch].
  final List<Event>? stateEvents;

  /// True when this event is the first in a sender group.
  final bool isGroupStart;

  /// True when this event continues a sender group (same sender, same
  /// environment).
  final bool isGroupContinuation;

  /// Precomputed thread-reply count for this event.
  final int replyCount;

  /// The date for [TimelineItemKind.dateSeparator].
  final DateTime? date;

  /// Number of undecryptable encrypted events, for
  /// [TimelineItemKind.undecryptableBanner].
  final int undecryptableCount;

  /// Convenience constructor for regular message events.
  static TimelineItemEntry forEvent({
    required Event event,
    bool isGroupStart = true,
    bool isGroupContinuation = false,
    int replyCount = 0,
  }) =>
      TimelineItemEntry(
        kind: TimelineItemKind.event,
        event: event,
        isGroupStart: isGroupStart,
        isGroupContinuation: isGroupContinuation,
        replyCount: replyCount,
      );

  /// Convenience constructor for date separators.
  static TimelineItemEntry forDateSeparator(DateTime date) =>
      TimelineItemEntry(
        kind: TimelineItemKind.dateSeparator,
        date: date,
      );

  /// Convenience constructor for state-event batches.
  static TimelineItemEntry forStateBatch(List<Event> stateEvents) =>
      TimelineItemEntry(
        kind: TimelineItemKind.stateEventBatch,
        stateEvents: stateEvents,
      );

  /// Convenience constructor for the undecryptable banner.
  static TimelineItemEntry forUndecryptable(int count) => TimelineItemEntry(
        kind: TimelineItemKind.undecryptableBanner,
        undecryptableCount: count,
      );
}

/// Result bundle returned by [buildTimelineItems].
class TimelineItemsResult {
  const TimelineItemsResult({
    required this.items,
    required this.eventIdToItemIndex,
    required this.undecryptableCount,
  });

  /// The flat list of visible items in **newest-first** order
  /// (index 0 is nearmost the banner sentinel, then newest event first,
  /// matching [Timeline.events] order).
  final List<TimelineItemEntry> items;

  /// Maps each event id to its position in [items].
  ///
  /// Used by jump-to-event and context-menu lookups.  Only regular
  /// message events appear here -- state-event batches and separators
  /// are not individually addressable.
  final Map<String, int> eventIdToItemIndex;

  /// Number of undecryptable encrypted events in the visible list.
  final int undecryptableCount;
}

// -- Builder --

/// Produces the list of [TimelineItemEntry] objects for [timeline] in
/// **newest-first** order so that the `reverse: true` ListView places
/// the newest item at the bottom.
///
/// [DateSeparator] entries are interleaved before events that start a
/// new calendar day.  Consecutive state events are grouped into a single
/// [TimelineItemEntry] of kind [TimelineItemKind.stateEventBatch] when
/// [showStateEvents] is true, or filtered out when it is false.
///
/// If any visible events are undecryptable (type == `m.room.encrypted`),
/// an [TimelineItemKind.undecryptableBanner] entry is prepended to alert
/// the user.
///
/// This is the pure-Dart core of the former `TimelineViewState._buildItemList`.
/// Extracting it here lets the grouping, continuation, and state-event
/// classification logic be tested without a Flutter widget tester.
TimelineItemsResult buildTimelineItems(
  Timeline timeline, {
  bool showStateEvents = true,
  bool Function(Event)? filterEvents,
}) {
  final events = timeline.events;
  final indices = visibleIndices(events, filterEvents);
  final threadReplyCounts = ThreadUtils.buildThreadReplyCounts(timeline);

  final items = <TimelineItemEntry>[];
  final eventIdToItemIndex = <String, int>{};
  Event? previousVisible;
  int undecryptableCount = 0;
  int i = 0;

  while (i < indices.length) {
    final eventIndex = indices[i];
    final event = events[eventIndex];

    if (event.type == EventTypes.Encrypted) {
      undecryptableCount++;
    }

    if (isStateEvent(event)) {
      if (showStateEvents) {
        // Collect a run of consecutive state events.
        final batch = <Event>[event];
        i++;
        while (i < indices.length &&
            isStateEvent(events[indices[i]])) {
          batch.add(events[indices[i]]);
          i++;
        }

        // Insert a date boundary before the batch if needed (using the
        // oldest event in the batch for the comparison).
        if (previousVisible != null &&
            isDifferentDay(previousVisible, batch.last)) {
          items.add(TimelineItemEntry.forDateSeparator(
            batch.last.originServerTs,
          ));
        }

        items.add(TimelineItemEntry.forStateBatch(batch));
        // State events do not participate in message grouping.
      } else {
        // Skip state events entirely.
        i++;
      }
    } else {
      // Regular message event.
      if (previousVisible != null &&
          isDifferentDay(previousVisible, event)) {
        items.add(TimelineItemEntry.forDateSeparator(event.originServerTs));
      }

      // An event is a continuation of the **older** event above it
      // (next in newest-first iteration). Walk past hidden state events
      // so they don't incorrectly absorb the sender info.
      final effectiveNextEvent =
          nextVisibleMessage(indices, events, i);
      final isContinuationFlag = effectiveNextEvent != null &&
          isContinuation(event, effectiveNextEvent);

      final replyCount = threadReplyCounts[event.eventId] ?? 0;

      items.add(TimelineItemEntry.forEvent(
        event: event,
        isGroupStart: !isContinuationFlag,
        isGroupContinuation: isContinuationFlag,
        replyCount: replyCount,
      ));

      eventIdToItemIndex[event.eventId] = items.length - 1;
      previousVisible = event;
      i++;
    }
  }

  // Always insert the undecryptable banner at index 0.
  items.insert(0, TimelineItemEntry.forUndecryptable(undecryptableCount));

  return TimelineItemsResult(
    items: items,
    eventIdToItemIndex: eventIdToItemIndex,
    undecryptableCount: undecryptableCount,
  );
}
