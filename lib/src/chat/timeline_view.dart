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
/// The Matrix SDK stores [Timeline.events] in **newest-first** order
/// (`events[0]` is the most recent).  We render them with
/// `ListView.builder(reverse: true)` so that the newest event sits at the
/// bottom of the viewport and older events are reached by scrolling **up**.
///
/// ## Event filtering
///
/// Events with a non-null [relationshipEventId] (replies, reactions, edits,
/// threads) are excluded from the visible list because they are rendered
/// inline with their parent event.
class TimelineView extends StatelessWidget {
  const TimelineView({
    super.key,
    required this.timeline,
    required this.room,
    required this.displayType,
    required this.scrollController,
    this.timelineVersion,
  });

  final Timeline timeline;
  final Room room;
  final DisplayType displayType;
  final ScrollController scrollController;

  /// Included so the parent can signal data changes without tearing down
  /// the ListView (no [ValueKey] used).
  final int? timelineVersion;

  // ---------------------------------------------------------------------------
  // Index helpers
  // ---------------------------------------------------------------------------

  /// Indices (into `timeline.events`) of events that should appear as
  /// standalone items.  Events are in SDK order (newest → oldest).
  List<int> _visibleIndices() {
    final indices = List<int>.generate(timeline.events.length, (i) => i);
    indices.removeWhere((i) => timeline.events[i].relationshipEventId != null);
    return indices;
  }

  /// True when [newer] and [older] belong to the same sender and fall within
  /// the same ~10‑minute environment, i.e. they should share a visual group.
  bool _isContinuation(Event newer, Event older) {
    if (newer.senderId != older.senderId) return false;
    return newer.originServerTs.sameEnvironment(older.originServerTs);
  }

  /// True when [newer] and [older] fall on different calendar days.
  bool _isDifferentDay(Event newer, Event older) {
    final n = newer.originServerTs;
    final o = older.originServerTs;
    return n.year != o.year || n.month != o.month || n.day != o.day;
  }

  // ---------------------------------------------------------------------------
  // Build the flat item list
  // ---------------------------------------------------------------------------

  /// Produces the list of widgets in **newest-first** order so that the
  /// `reverse: true` ListView places the newest item at the bottom.
  ///
  /// [DateSeparator] widgets are interleaved before events that start a new
  /// calendar day.
  List<Widget> _buildItemList(BuildContext context) {
    final visibleIndices = _visibleIndices(); // newest → oldest
    final items = <Widget>[];
    Event? previousVisible; // the *newer* neighbour

    for (int i = 0; i < visibleIndices.length; i++) {
      final eventIndex = visibleIndices[i];
      final event = timeline.events[eventIndex]; // newest first

      // Insert separator when stepping from one day to an older day.
      if (previousVisible != null && _isDifferentDay(previousVisible, event)) {
        items.add(DateSeparator(dateTime: event.originServerTs));
      }

      final isContinuation =
          previousVisible != null && _isContinuation(previousVisible, event);

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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Items are already newest-first; `reverse: true` puts index 0 at the
    // bottom so the newest event appears at the bottom of the viewport.
    final items = _buildItemList(context);

    return Expanded(
      child: ListView.builder(
        controller: scrollController,
        reverse: true,
        itemCount: items.length,
        itemBuilder: (context, index) => items[index],
      ),
    );
  }
}
