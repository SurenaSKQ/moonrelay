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

import 'package:moonrelay/src/chat/chat_event.dart';
import 'package:moonrelay/src/chat/message_actions.dart';
import 'package:moonrelay/src/chat/reactions_bar.dart';
import 'package:moonrelay/src/helpers/color_palette.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';

/// Renders a single event in the chat timeline with proper sender grouping,
/// avatar placement, and display-type-specific styling.
///
/// **Sender grouping logic:**
/// - Consecutive events from the same sender within ~10 minutes are grouped:
///   the avatar and sender name appear only on the first event of the group.
/// - The timestamp is shown on every event by default, but hidden for
///   grouped events (the first event of the group still shows the time).
///
/// **Display types:**
/// - [DisplayType.modern]: avatar left, sender name above, content indented
///   for grouped messages.
/// - [DisplayType.bubbles]: bubble container with avatar, content inside.
/// - [DisplayType.irc]: compact format with sender prefix on each line.
class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.event,
    required this.room,
    this.previousEvent,
    required this.displayType,
    this.isGroupStart = true,
    this.isGroupContinuation = false,
    this.timeline,
    this.onReply,
  });

  final Event event;
  final Event? previousEvent;
  final Room room;
  final DisplayType displayType;
  final Timeline? timeline;

  /// True when this event is the first in a group from the same sender.
  /// Grouped events from the same sender within ~10 min share a single
  /// avatar/name header.
  final bool isGroupStart;

  /// True when this event is a continuation of a group (same sender, close
  /// in time). In this case the avatar and name header are hidden.
  final bool isGroupContinuation;

  /// Called when the user wants to reply to this event.
  final VoidCallback? onReply;

  /// Whether the event was redacted (deleted).
  bool get _isRedacted => event.redacted;

  /// Navigates to the sender's profile page.
  void _openProfile(BuildContext context) {
    context.push(
      '${GoRouterState.of(context).uri}/profile/${event.senderFromMemoryOrFallback.id}',
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRedacted) {
      return _RedactedEvent(
        event: event,
        isGroupContinuation: isGroupContinuation,
      );
    }

    switch (displayType) {
      case DisplayType.modern:
        return _buildModern(context);
      case DisplayType.bubbles:
        return _buildBubbles(context);
      case DisplayType.irc:
        return _buildIrc(context);
    }
  }

  /// Common content wrapper: message body + reactions bar.
  Widget _messageContent(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MessageEventHandler(event: event),
        if (timeline != null)
          ReactionsBar(
            event: event,
            timeline: timeline!,
            room: room,
          ),
      ],
    );
  }

  /// Wraps the content area with a hover-revealed actions row.
  Widget _withActions(Widget content) {
    if (onReply == null) return content;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        content,
        Positioned(
          top: -4,
          right: 0,
          child: MessageActions(
            event: event,
            room: room,
            onReply: onReply!,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Modern display
  // ---------------------------------------------------------------------------

  Widget _buildModern(BuildContext context) {
    final theme = Theme.of(context);
    final showAvatar = isGroupStart && !isGroupContinuation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar column
          SizedBox(
            width: 48,
            child: showAvatar
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AvatarFromUriOrFallbackImage(
                      client: room.client,
                      avatarUri: event.senderFromMemoryOrFallback.avatarUrl,
                      onTap: () => _openProfile(context),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          // Content column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender name + timestamp (only for group-start)
                if (isGroupStart)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            event.senderFromMemoryOrFallback.calcDisplayname(),
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Rubik',
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          event.originServerTs.localizedTimeShort(context),
                          style: TextStyle(
                            fontSize: 11,
                            fontFamily: 'Rubik',
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Timestamp-only for continuation
                if (isGroupContinuation)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: SizedBox(
                      height: 14,
                      child: Row(
                        children: [
                          Text(
                            event.originServerTs.localizedTimeShort(context),
                            style: TextStyle(
                              fontSize: 11,
                              fontFamily: 'Rubik',
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Message body with reactions and hover actions
                _withActions(_messageContent(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Bubbles display
  // ---------------------------------------------------------------------------

  Widget _buildBubbles(BuildContext context) {
    final showAvatar = isGroupStart && !isGroupContinuation;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar column
          SizedBox(
            width: 48,
            child: showAvatar
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: AvatarFromUriOrFallbackImage(
                      client: room.client,
                      avatarUri: event.senderFromMemoryOrFallback.avatarUrl,
                      onTap: () => _openProfile(context),
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 8),
          // Bubble content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isGroupStart)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4, left: 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            event.senderFromMemoryOrFallback.calcDisplayname(),
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              fontFamily: 'Rubik',
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          event.originServerTs.localizedTimeShort(context),
                          style: const TextStyle(
                            fontSize: 11,
                            fontFamily: 'Rubik',
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                _withActions(
                  Container(
                    decoration: BoxDecoration(
                      color: MoonrelayColorPalette.cpgDarker,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: MoonrelayColorPalette.britishRacingGreen,
                        width: 0.7,
                      ),
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _messageContent(context),
                        if (isGroupContinuation)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              event.originServerTs.localizedTimeShort(context),
                              style: const TextStyle(
                                fontSize: 11,
                                fontFamily: 'Rubik',
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // IRC display
  // ---------------------------------------------------------------------------

  Widget _buildIrc(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sender prefix
          SizedBox(
            width: 120,
            child: Text(
              isGroupStart
                  ? '<${event.senderFromMemoryOrFallback.calcDisplayname()}>'
                  : '',
              style: const TextStyle(
                fontSize: 14,
                fontFamily: 'Rubik',
                fontWeight: FontWeight.w700,
              ),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // Timestamp
          Text(
            event.originServerTs.localizedTimeShort(context),
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Rubik',
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          // Message body with actions and reactions
          Expanded(
            child: _withActions(
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  MessageEventHandler(event: event),
                  if (timeline != null)
                    ReactionsBar(
                      event: event,
                      timeline: timeline!,
                      room: room,
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Redacted event indicator
// ---------------------------------------------------------------------------

/// Renders a compact placeholder for redacted (deleted) messages.
class _RedactedEvent extends StatelessWidget {
  const _RedactedEvent({
    required this.event,
    required this.isGroupContinuation,
  });

  final Event event;
  final bool isGroupContinuation;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 72, vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.delete,
            size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 6),
          Text(
            'Message deleted',
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              fontFamily: 'Rubik',
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}
