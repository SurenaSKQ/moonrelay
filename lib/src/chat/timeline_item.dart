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
import 'package:moonrelay/src/chat/message_actions.dart';
import 'package:moonrelay/src/chat/message_context_menu.dart';
import 'package:moonrelay/src/chat/reactions_bar.dart';
import 'package:moonrelay/src/chat/receipt_avatars.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
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
/// - [DisplayType.modern] and [DisplayType.bubbles]: hover actions (React,
///   Reply, Forward, Delete) appear at the top‑right when hovering anywhere
///   on the message.
/// - [DisplayType.irc]: compact format with no hover actions.
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
    required this.fontSize,
    this.threadReplyCount = 0,
    this.onReply,
    this.onForward,
    this.onThread,
    this.onJumpToEvent,
    this.highlightedEventId,
  });

  final Event event;
  final Event? previousEvent;
  final Room room;
  final DisplayType displayType;
  final Timeline? timeline;

  /// Font size for message text, passed from the parent to avoid
  /// a per-event [context.watch] on [SettingsController].
  final double fontSize;

  /// Precomputed number of thread replies (0 = no thread).
  final int threadReplyCount;

  /// True when this event is the first in a group from the same sender.
  /// Grouped events from the same sender within ~10 min share a single
  /// avatar/name header.
  final bool isGroupStart;

  /// True when this event is a continuation of a group (same sender, close
  /// in time). In this case the avatar and name header are hidden.
  final bool isGroupContinuation;

  /// Called when the user wants to reply to this event.
  final VoidCallback? onReply;

  /// Called when the user wants to forward this event to another room.
  final VoidCallback? onForward;

  /// Called when the user wants to view the thread for this event.
  final VoidCallback? onThread;

  /// Called when the user taps a reply preview to jump to the replied-to
  /// event.  Receives the event ID of the target event.
  final void Function(String eventId)? onJumpToEvent;

  /// When non-null and matching this event's [event.eventId], the event
  /// is rendered with a brief highlight background flash.
  final String? highlightedEventId;

  /// Whether the event was redacted (deleted).
  bool get _isRedacted => event.redacted;

  /// Navigates to the sender's profile page.
  void _openProfile(BuildContext context) {
    context.push(
      '${GoRouterState.of(context).uri}/profile/${event.senderFromMemoryOrFallback.id}',
    );
  }

  /// Wraps [child] in a `GestureDetector` that opens the context menu on
  /// right-click (desktop) or long-press (touch).
  ///
  /// The reply, forward, thread, and profile callbacks are wired through so
  /// the menu can invoke them. When none of them are available, the gesture
  /// detector is omitted to avoid accidental interactions.
  Widget _wrapWithContextMenu(BuildContext context, Widget child) {
    final hasAny =
        onReply != null || onForward != null || onThread != null;
    if (!hasAny) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) {
        MessageContextMenu.showForEvent(
          context: context,
          position: details.globalPosition,
          event: event,
          room: room,
          timeline: timeline,
          onReply: onReply ?? () {},
          onForward: onForward,
          onThread: onThread,
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
          onReply: onReply ?? () {},
          onForward: onForward,
          onThread: onThread,
          onOpenProfile: () => _openProfile(context),
        );
      },
      child: child,
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

    content = _HoverHighlight(
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
          onJumpToEvent: onJumpToEvent,
        ),
        if (timeline != null)
          ReactionsBar(
            event: event,
            timeline: timeline!,
            room: room,
          ),
        // Read-receipt avatars under every message that someone has seen.
        if (timeline != null)
          ReceiptAvatars(event: event, room: room),
        if (showDelivery)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DeliveryIndicator(status: _deliveryStatusFor(event)),
          ),
        if (threadReplyCount > 0)
          _ThreadIndicator(
            replyCount: threadReplyCount,
            onTap: onThread,
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
                _HoverActionsWrapper(
                  event: event,
                  room: room,
                  timeline: timeline,
                  onReply: onReply,
                  onForward: onForward,
                  onThread: onThread,
                  child: _wrapWithContextMenu(context, _messageContent(context)),
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
                // Hover actions + bubble
                _HoverActionsWrapper(
                  event: event,
                  room: room,
                  timeline: timeline,
                  onReply: onReply,
                  onForward: onForward,
                  onThread: onThread,
                  child: _wrapWithContextMenu(
                    context,
                    Container(
                      decoration: BoxDecoration(
                        color: cs.primaryContainer.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(8),
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
              ],
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
    return _IRCRow(
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
              onJumpToEvent: onJumpToEvent,
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

// ---------------------------------------------------------------------------
// Hover actions wrapper (Modern & Bubbles only)
// ---------------------------------------------------------------------------

/// Wraps [child] with a [MouseRegion] and overlays action buttons at the
/// top‑right corner of the message when the user hovers over it.
///
/// Actions include **React**, **Reply**, **Forward**, **Details**, **Edit**,
/// **Delete** (when permitted), and **Moderation** for users with sufficient
/// permissions.
///
/// When [onReply] is `null` the whole mechanism is skipped and [child] is
/// returned as-is.
class _HoverActionsWrapper extends StatefulWidget {
  const _HoverActionsWrapper({
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
  State<_HoverActionsWrapper> createState() => _HoverActionsWrapperState();
}

class _HoverActionsWrapperState extends State<_HoverActionsWrapper> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    // No reply callback means no actions at all – skip the overhead.
    if (widget.onReply == null) return widget.child;

    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Stack(
        children: [
          widget.child,
          if (_isHovered)
            Positioned(
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
            AppLocalizations.of(context)!.messageDeleted,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Thread indicator ──────────────────────────────────────────────────────────

/// A clickable indicator shown below a message when it has thread replies.
/// Shows the reply count and navigates to the thread view on tap.
class _ThreadIndicator extends StatelessWidget {
  const _ThreadIndicator({
    required this.replyCount,
    this.onTap,
  });

  final int replyCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: scheme.primary.withValues(alpha: 0.3),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.forum_rounded,
                size: 14,
                color: scheme.primary,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.threadReplies(replyCount),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 14,
                color: scheme.primary.withValues(alpha: 0.6),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hover highlight & reply-jump flash
// ---------------------------------------------------------------------------

/// Wraps a chat item and applies a subtle background tint when the mouse
/// hovers over it, plus a stronger flash when [isHighlighted] is true
/// (triggered by a reply jump-to).
///
/// Uses [ColorScheme.surfaceContainerHighest] tones that adapt cleanly
/// to both light and dark themes.
class _HoverHighlight extends StatefulWidget {
  const _HoverHighlight({
    required this.isHighlighted,
    required this.child,
  });

  final bool isHighlighted;
  final Widget child;

  @override
  State<_HoverHighlight> createState() => _HoverHighlightState();
}

class _HoverHighlightState extends State<_HoverHighlight> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    Color bgColor;
    if (widget.isHighlighted) {
      bgColor = cs.primary.withValues(alpha: 0.15);
    } else if (_isHovered) {
      bgColor = cs.surfaceContainerHighest.withValues(alpha: 0.5);
    } else {
      bgColor = Colors.transparent;
    }

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: bgColor,
        ),
        child: widget.child,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// IRC row layout
// ---------------------------------------------------------------------------

/// Renders a single IRC-style message row with the sender always visible and
/// the timestamp shown only on hover at the end of the row.
class _IRCRow extends StatefulWidget {
  const _IRCRow({
    required this.sender,
    required this.timestamp,
    required this.body,
  });

  final Widget sender;
  final Widget timestamp;
  final Widget body;

  @override
  State<_IRCRow> createState() => _IRCRowState();
}

class _IRCRowState extends State<_IRCRow> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Stack(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                widget.sender,
                const SizedBox(width: 8),
                Expanded(child: widget.body),
              ],
            ),
            if (_isHovered)
              Positioned(
                top: 0,
                right: 0,
                child: widget.timestamp,
              ),
          ],
        ),
      ),
    );
  }
}
