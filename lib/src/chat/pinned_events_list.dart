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

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/settings/display_type.dart';

/// Renders a list of events fetched by ID for the pinned-only filter.
///
/// These events are not necessarily present in the room's [Timeline.events]
/// list, so they cannot be rendered by [TimelineView]'s filter mechanism.
/// Instead, this widget takes the pre-fetched events and renders each one
/// with a [TimelineItem], computing sender grouping from their timestamps.
class PinnedEventsList extends StatelessWidget {
  const PinnedEventsList({
    super.key,
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

  /// Two events fall within the same "sender group" if they're from the
  /// same sender and their timestamps are within [_groupingThresholdMinutes]
  /// of each other. Exposed publicly so tests and other surfaces can use
  /// the same definition.
  static const int _groupingThresholdMinutes = 10;

  @override
  Widget build(BuildContext context) {
    // Events are already sorted oldest-first.  Compute sender grouping:
    // each event is a continuation of the *newer* event below it
    // (which appears later in the list).  Since the ListView is reversed,
    // index 0 appears at the bottom (newest message) of the viewport.
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

        return TimelineItem(
          event: event,
          room: room,
          displayType: displayType,
          isGroupStart: !isContinuation,
          isGroupContinuation: isContinuation,
          fontSize: fontSize,
          bubbleRadius: bubbleRadius,
          onAction: (action, e) {
            switch (action) {
              case TimelineItemAction.reply:
                onReply?.call(e);
                break;
              case TimelineItemAction.thread:
                onThread?.call(e);
                break;
              case TimelineItemAction.forward:
                onForward?.call(e);
                break;
              case TimelineItemAction.jumpToEvent:
                // The pinned-events list does its own jump; the reply
                // preview inside the bubble handles inline jumps to
                // replied-to events. No global scroll needed here.
                break;
            }
          },
        );
      },
    );
  }

  /// True when [newer] and [older] are from the same sender within
  /// [_groupingThresholdMinutes].
  static bool _isSameSenderAndCloseInTime(Event newer, Event older) {
    if (newer.senderId != older.senderId) return false;
    return _sameEnvironment(newer.originServerTs, older.originServerTs);
  }

  /// True when two timestamps fall within [_groupingThresholdMinutes]
  /// of each other.
  static bool _sameEnvironment(DateTime a, DateTime b) {
    final diff = a.difference(b).inMinutes.abs();
    return diff <= _groupingThresholdMinutes;
  }
}
