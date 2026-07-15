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
import 'package:moonrelay/src/chat/events/delivery_indicator.dart';
import 'package:moonrelay/src/chat/hover_actions_wrapper.dart';
import 'package:moonrelay/src/chat/hover_highlight.dart';
import 'package:moonrelay/src/chat/irc_row.dart';
import 'package:moonrelay/src/chat/message_context_menu.dart';
import 'package:moonrelay/src/chat/reactions_bar.dart';
import 'package:moonrelay/src/chat/receipt_avatars.dart';
import 'package:moonrelay/src/chat/redacted_event.dart';
import 'package:moonrelay/src/chat/thread_indicator.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Maximum width for a chat bubble so the bubble hugs its text instead
/// of stretching to fill the chat column.  Width is capped at this
/// constant; chat bubbles that exceed it grow vertically, never
/// horizontally.  Keeps the visual rhythm of a real chat app and stops
/// long messages from looking like enormous banners.
const double _kMaxBubbleWidth = 480;

/// Reserved right margin for every bubble row.  The bubble itself is
/// also left-aligned, so the row ends up with a constant
/// [_kBubbleRightMargin] gutter on the right of the chat column
/// giving bubbles a "floating" feel instead of a full-width slab.
const double _kBubbleRightMargin = 64;

/// Tagged action identifier used by [TimelineItem.onAction].  Folding
/// the four message actions into a single dispatch keeps the closure
/// identities stable across rebuilds so the Flutter element tree can
/// re-use existing children instead of inflating new ones.
enum TimelineItemAction {
  reply,
  forward,
  thread,
  jumpToEvent,
}

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
/// - [DisplayType.modern] and [DisplayType.bubbles]: hover actions (React,
///   Reply, Forward, Delete) appear at the top‑right when hovering anywhere
///   on the message.
/// - [DisplayType.irc]: compact format with no hover actions.
class TimelineItem extends StatelessWidget {
  const TimelineItem({
    super.key,
    required this.event,
    required this.room,
    required this.displayType,
    this.isGroupStart = true,
    this.isGroupContinuation = false,
    this.timeline,
    required this.fontSize,
    this.bubbleRadius = 12.0,
    this.threadReplyCount = 0,
    this.onAction,
    this.highlightedEventId,
  });

  final Event event;
  final Room room;
  final DisplayType displayType;
  final Timeline? timeline;

  /// Font size for message text, passed from the parent to avoid
  /// a per-event [context.watch] on [SettingsController].
  final double fontSize;

  /// Corner radius for the message bubble in bubbles display mode.
  final double bubbleRadius;

  /// Precomputed number of thread replies (0 = no thread).
  final int threadReplyCount;

  /// True when this event is the first in a group from the same sender.
  /// Grouped events from the same sender within ~10 min share a single
  /// avatar/name header.
  final bool isGroupStart;

  /// True when this event is a continuation of a group (same sender, close
  /// in time). In this case the avatar and name header are hidden.
  final bool isGroupContinuation;

  /// Single stable callback used by the message actions (reply, forward,
  /// thread, jump). Passing one callback with a tagged [TimelineItemAction]
  /// means the closures handed to the leaf widgets have stable identity
  /// across rebuilds, so Flutter can re-use the existing [Element]s
  /// instead of inflating new ones on every parent build.
  final void Function(TimelineItemAction action, Event event)? onAction;

  /// When non-null and matching this event's [event.eventId], the event
  /// is rendered with a brief highlight background flash.
  final String? highlightedEventId;

  /// Convenience getters that call [onAction] with the right action tag.
  VoidCallback? get _onReply => onAction == null
      ? null
      : () => onAction!(TimelineItemAction.reply, event);
  VoidCallback? get _onForward => onAction == null
      ? null
      : () => onAction!(TimelineItemAction.forward, event);
  VoidCallback? get _onThread => onAction == null
      ? null
      : () => onAction!(TimelineItemAction.thread, event);
  void Function(String)? get _onJumpToEvent => onAction == null
      ? null
      : (id) => onAction!(TimelineItemAction.jumpToEvent, event);

  /// Whether the event was redacted (deleted).
  bool get _isRedacted => event.redacted;

  /// Opens the sender's profile as a centered modal overlay.
  ///
  /// The overlay is decoupled from the room route -- it works even if
  /// the user later leaves the originating room, and it doesn't pop
  /// the current chat off the navigation stack.
  void _openProfile(BuildContext context) {
    final senderId = event.senderFromMemoryOrFallback.id;
    showProfileOverlay(context, userId: senderId, room: room);
  }

  /// Wraps [child] in a `GestureDetector` that opens the context menu on
  /// right-click (desktop) or long-press (touch).
  ///
  /// The reply, forward, thread, and profile callbacks are wired through so
  /// the menu can invoke them. When none of them are available, the gesture
  /// detector is omitted to avoid accidental interactions.
  Widget _wrapWithContextMenu(BuildContext context, Widget child) {
    if (onAction == null) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) {
        MessageContextMenu.showForEvent(
          context: context,
          position: details.globalPosition,
          event: event,
          room: room,
          timeline: timeline,
          onReply: _onReply ?? () {},
          onForward: _onForward,
          onThread: _onThread,
          onOpenProfile: () => _openProfile(context),
        );
      },
      onLongPressStart: (details) {
        MessageContextMenu.showForEvent(
          context: context,
          position: details.globalPosition,
          event: event,
          room: room,
          timeline: timeline,
          onReply: _onReply ?? () {},
          onForward: _onForward,
          onThread: _onThread,
          onOpenProfile: () => _openProfile(context),
        );
      },
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isRedacted) {
      return RedactedEvent(
        event: event,
        isGroupContinuation: isGroupContinuation,
      );
    }

    final isHighlighted = highlightedEventId == event.eventId;

    Widget content;
    switch (displayType) {
      case DisplayType.modern:
        content = _buildModern(context);
      case DisplayType.bubbles:
        content = _buildBubbles(context);
      case DisplayType.irc:
        content = _buildIrc(context);
    }

    content = HoverHighlight(
      isHighlighted: isHighlighted,
      child: content,
    );

    return content;
  }

  /// Message body + reactions bar (shared between all display modes).
  ///
  /// Uses the precomputed [threadReplyCount] and passed [fontSize] instead
  /// of scanning the timeline or watching [SettingsController] on every build.
  Widget _messageContent(BuildContext context) {
    // The delivery indicator only matters for outgoing messages that
    // haven't yet been confirmed by sync.  Events that arrived via
    // sync (`EventStatus.synced`) are already in their final state and
    // don't need a spinner / check / retry icon next to them.
    final isOutgoing = event.senderId == room.client.userID;
    final showDelivery = isOutgoing && event.status != EventStatus.synced;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MessageEventHandler(
          event: event,
          timeline: timeline,
          room: room,
          fontSize: fontSize,
          onJumpToEvent: _onJumpToEvent,
        ),
        if (timeline != null)
          ReactionsBar(
            event: event,
            timeline: timeline!,
            room: room,
          ),
        // Read-receipt avatars under every message that someone has seen.
        if (timeline != null) ReceiptAvatars(event: event, room: room),
        if (showDelivery)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DeliveryIndicator(status: _deliveryStatusFor(event)),
          ),
        if (threadReplyCount > 0)
          ThreadIndicator(
            replyCount: threadReplyCount,
            onTap: _onThread,
          ),
      ],
    );
  }

  /// Maps the SDK's [EventStatus] to the smaller set of states the
  /// [DeliveryIndicator] knows how to render.
  DeliveryStatus _deliveryStatusFor(Event ev) {
    switch (ev.status) {
      case EventStatus.sending:
        return DeliveryStatus.sending;
      case EventStatus.sent:
      case EventStatus.synced:
        return DeliveryStatus.sent;
      case EventStatus.error:
        return DeliveryStatus.failed;
    }
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
                              fontSize: fontSize,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          event.originServerTs.localizedTimeShort(context),
                          style: TextStyle(
                            fontSize: fontSize * 0.6875,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                // No timestamp for continuation messages (time shown on group start)
                // Hover actions (right-aligned -- away from sender info)
                HoverActionsWrapper(
                  event: event,
                  room: room,
                  timeline: timeline,
                  onReply: _onReply,
                  onForward: _onForward,
                  onThread: _onThread,
                  child:
                      _wrapWithContextMenu(context, _messageContent(context)),
                ),
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
    final cs = Theme.of(context).colorScheme;
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
          // Bubble content.  The whole column is wrapped in an
          // [Expanded] (filling the row) with a fixed right margin so
          // the bubble never hugs the right edge of the chat column
          // the bubble visibly floats to the left and the gap on the
          // right gives the layout visual breathing room.
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: _kBubbleRightMargin),
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
                              event.senderFromMemoryOrFallback
                                  .calcDisplayname(),
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            event.originServerTs.localizedTimeShort(context),
                            style: TextStyle(
                              fontSize: fontSize * 0.6875,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  // Hover actions + bubble.  The bubble's max-width is
                  // capped so it hugs its content; an [Align] keeps
                  // the bubble at the left edge of the row, leaving
                  // empty space on the right to look like a real
                  // chat conversation rather than a single full-width
                  // panel.
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: HoverActionsWrapper(
                      event: event,
                      room: room,
                      timeline: timeline,
                      onReply: _onReply,
                      onForward: _onForward,
                      onThread: _onThread,
                      child: _wrapWithContextMenu(
                        context,
                        ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _kMaxBubbleWidth,
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              color: cs.primaryContainer.withValues(alpha: 0.3),
                              borderRadius: BorderRadius.circular(bubbleRadius),
                              border: Border.all(
                                color: cs.primary.withValues(alpha: 0.5),
                                width: 0.7,
                              ),
                            ),
                            padding: const EdgeInsets.all(10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _messageContent(context),
                                // No timestamp for continuation messages
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // IRC display (compact, no hover actions)
  // ---------------------------------------------------------------------------

  Widget _buildIrc(BuildContext context) {
    return IRCRow(
      sender: SizedBox(
        width: 120,
        child: Text(
          '<${event.senderFromMemoryOrFallback.calcDisplayname()}>',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
        ),
      ),
      timestamp: Text(
        event.originServerTs.localizedTimeShort(context),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      body: _wrapWithContextMenu(
        context,
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MessageEventHandler(
              event: event,
              timeline: timeline,
              room: room,
              fontSize: fontSize,
              onJumpToEvent: _onJumpToEvent,
            ),
            if (timeline != null)
              ReactionsBar(
                event: event,
                timeline: timeline!,
                room: room,
              ),
          ],
        ),
      ),
    );
  }
}




