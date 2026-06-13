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

import 'package:moonrelay/src/chat/events/date_separator.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';

/// Renders the list of timeline events with event-type filtering, sender
/// grouping, and date separators.
///
/// ## Event filtering
///
/// Events that have a [relationshipEventId] (replies, reactions, edits,
/// threads, etc.) are excluded from the visible list because they are
/// rendered inline with their parent event rather than as separate entries.
///
/// ## Sender grouping
///
/// Consecutive events from the same sender within ~10 minutes are visually
/// grouped: the avatar and sender name header appear only on the first event
/// of the group.
///
/// ## Date separators
///
/// A [DateSeparator] is inserted between events that fall on different days.
///
/// This widget is rebuilt from scratch whenever [ChatTimeline] increments
/// its version counter, keeping the view in sync with the underlying
/// [Timeline] data without the complexity of incremental index tracking.
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.timeline,
    required this.room,
    required this.displayType,
    required this.scrollController,
  });

  final Timeline timeline;
  final Room room;
  final DisplayType displayType;
  final ScrollController scrollController;

  /// Returns the raw-event-list indices of events that should appear as
  /// standalone items in the timeline.
  ///
  /// Events with a [relationshipEventId] (replies, reactions, edits,
  /// threads, etc.) are excluded because they are rendered inline with
  /// their parent event rather than as separate entries.
  List<int> _visibleIndices() {
    final indices = List<int>.generate(timeline.events.length, (i) => i);
    indices.removeWhere((i) {
      final event = timeline.events[i];
      // Exclude events that are relationships (replies, reactions, edits)
      return event.relationshipEventId != null;
    });
    return indices;
  }

  /// Returns true if [current] and [previous] are from the same sender
  /// and fall within the same ~10-minute time window, meaning they should
  /// share a visual group (single avatar/name header).
  bool _isContinuation(Event current, Event previous) {
    if (current.senderId != previous.senderId) return false;
    // Same environment = within ~10 minutes
    return current.originServerTs.sameEnvironment(previous.originServerTs);
  }

  /// Returns true when [current] and [previous] are on different calendar
  /// days, meaning a [DateSeparator] should be inserted between them.
  bool _isDifferentDay(Event current, Event previous) {
    final c = current.originServerTs;
    final p = previous.originServerTs;
    return c.year != p.year || c.month != p.month || c.day != p.day;
  }

  /// Produces the flat list of widgets to render, interleaving
  /// [DateSeparator] widgets between day boundaries.
  ///
  /// The list is built in chronological order (oldest first) and displayed
  /// in reverse by [ListView.builder].
  List<Widget> _buildItemList(BuildContext context) {
    final visibleIndices = _visibleIndices();
    final items = <Widget>[];
    Event? previousVisible;

    for (int i = 0; i < visibleIndices.length; i++) {
      final eventIndex = visibleIndices[i];
      final event = timeline.events[eventIndex];

      // Date separator
      if (previousVisible != null && _isDifferentDay(event, previousVisible)) {
        items.add(DateSeparator(dateTime: event.originServerTs));
      }

      // Determine grouping
      final isContinuation =
          previousVisible != null && _isContinuation(event, previousVisible);

      items.add(TimelineItem(
        event: event,
        room: room,
        previousEvent: eventIndex >= 1 ? timeline.events[eventIndex - 1] : null,
        displayType: displayType,
        isGroupStart: !isContinuation,
        isGroupContinuation: isContinuation,
      ));

      previousVisible = event;
    }

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final items = _buildItemList(context);

    // Reverse the list so the most recent item scrolls into view at the
    // bottom of the viewport, matching the reversed ListView.
    final reversedItems = items.reversed.toList();

    return Expanded(
      child: ListView.builder(
        controller: scrollController,
        reverse: true,
        itemCount: reversedItems.length,
        itemBuilder: (context, index) => reversedItems[index],
      ),
    );
  }
}
