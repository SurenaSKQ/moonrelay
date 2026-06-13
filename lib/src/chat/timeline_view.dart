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

import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';

/// Renders the list of timeline events with event-type filtering and
/// correct index mapping.
///
/// Events that are relationships (replies, reactions, edits, etc.) are
/// excluded from the visible list since they are rendered inline with
/// their parent event. A mapping between visible list indices and raw
/// timeline event indices prevents index-mismatch crashes.
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
    indices.removeWhere((i) => timeline.events[i].relationshipEventId != null);
    return indices;
  }

  @override
  Widget build(BuildContext context) {
    final visibleIndices = _visibleIndices();
    return Expanded(
      child: ListView.builder(
        controller: scrollController,
        reverse: true,
        itemCount: visibleIndices.length,
        itemBuilder: (context, index) {
          final eventIndex = visibleIndices[index];
          return TimelineItem(
            event: timeline.events[eventIndex],
            previousEvent:
                eventIndex >= 1 ? timeline.events[eventIndex - 1] : null,
            room: room,
            displayType: displayType,
          );
        },
      ),
    );
  }
}
