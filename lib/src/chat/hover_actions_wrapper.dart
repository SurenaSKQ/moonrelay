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
import 'package:moonrelay/src/chat/message_actions.dart';

/// Wraps [child] with a [MouseRegion] and overlays action buttons at the
/// top-right corner of the message when the user hovers over it.
///
/// Actions include **React**, **Reply**, **Forward**, **Details**, **Edit**,
/// **Delete** (when permitted), and **Moderation** for users with sufficient
/// permissions.
///
/// When [onReply] is `null` the whole mechanism is skipped and [child] is
/// returned as-is.  The [onReply], [onForward], and [onThread] callbacks
/// are passed in from [TimelineItem] and are stable across rebuilds.
class HoverActionsWrapper extends StatefulWidget {
  const HoverActionsWrapper({
    super.key,
    required this.child,
    required this.event,
    required this.room,
    required this.timeline,
    this.onReply,
    this.onForward,
    this.onThread,
  });

  final Widget child;
  final Event event;
  final Room room;
  final Timeline? timeline;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onThread;

  @override
  State<HoverActionsWrapper> createState() => _HoverActionsWrapperState();
}

class _HoverActionsWrapperState extends State<HoverActionsWrapper> {
  /// Hover state held in a [ValueNotifier] so a mouse enter/exit
  /// rebuilds only the overlay leaf, not the whole message body.
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No reply callback means no actions at all - skip the overhead.
    if (widget.onReply == null) return widget.child;

    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: Stack(
        children: [
          widget.child,
          // Only the overlay re-builds on hover toggles; the message
          // body subtree (the `widget.child` above) is unaffected.
          ValueListenableBuilder<bool>(
            valueListenable: _isHovered,
            builder: (context, hovered, _) {
              if (!hovered) return const SizedBox.shrink();
              return Positioned(
                top: -4,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: cs.outlineVariant,
                      width: 0.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: MessageActions(
                    event: widget.event,
                    room: widget.room,
                    timeline: widget.timeline,
                    onReply: widget.onReply!,
                    onForward: widget.onForward,
                    onThread: widget.onThread,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
