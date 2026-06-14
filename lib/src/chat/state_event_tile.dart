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
import 'package:moonrelay/src/chat/events/matrix_events/State/state_events.dart';

/// Groups one or more consecutive state events into a single timeline tile.
///
/// * A single event is rendered as a centred [StateEvents] text entry.
/// * Multiple events are shown in an expandable container.  When collapsed
///   only a summary header is visible; when expanded every event is rendered
///   as its own [StateEvents] entry.
class StateEventTile extends StatelessWidget {
  const StateEventTile({
    super.key,
    required this.events,
  });

  /// Consecutive state events in **newest-first** (SDK) order.
  final List<Event> events;

  @override
  Widget build(BuildContext context) {
    if (events.length == 1) {
      return StateEvents(event: events.first, showTimestamp: true);
    }
    return _MultiStateEventTile(events: events);
  }
}

/// The expandable variant shown when [StateEventTile] has more than one event.
class _MultiStateEventTile extends StatefulWidget {
  const _MultiStateEventTile({required this.events});

  final List<Event> events;

  @override
  State<_MultiStateEventTile> createState() => _MultiStateEventTileState();
}

class _MultiStateEventTileState extends State<_MultiStateEventTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final mutedColor =
        Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Clickable header row
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Row(
              children: [
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 16,
                  color: mutedColor,
                ),
                const SizedBox(width: 4),
                Text(
                  '${widget.events.length} state events',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: mutedColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Expanded event list
        if (_expanded)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Column(
              children: widget.events
                  .map((e) => Padding(
                        padding: const EdgeInsets.only(left: 24),
                        child: StateEvents(event: e, showTimestamp: true),
                      ))
                  .toList(),
            ),
          ),
      ],
    );
  }
}
