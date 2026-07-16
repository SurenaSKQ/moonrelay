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
import 'package:moonrelay/src/chat/hover_highlight.dart';
import 'package:moonrelay/src/chat/message_actions.dart';
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
class TimelineItem extends StatefulWidget {
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
    this.itemKey,
  });

  final Event event;
  final Room room;
  final DisplayType displayType;
  final Timeline? timeline;

  /// Stable [GlobalKey] for this item, supplied by [TimelineView].
  /// The inner [HoverItem] registers this key with the shared
  /// [HoverOverlayController] so the overlay can resolve the on-screen
  /// position of the hovered item without scanning the widget tree.
  ///
  /// When `null` (e.g. in widget tests that mount a `TimelineItem`
  /// directly), the item still renders correctly but the hover
  /// toolbar stays disabled.
  final GlobalKey? itemKey;

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

  @override
  State<TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<TimelineItem> {
  /// Convenience getters that call [widget.onAction] with the right action tag.
  VoidCallback? get _onReply => widget.onAction == null
      ? null
      : () => widget.onAction!(TimelineItemAction.reply, widget.event);
  VoidCallback? get _onForward => widget.onAction == null
      ? null
      : () => widget.onAction!(TimelineItemAction.forward, widget.event);
  VoidCallback? get _onThread => widget.onAction == null
      ? null
      : () => widget.onAction!(TimelineItemAction.thread, widget.event);
  void Function(String)? get _onJumpToEvent => widget.onAction == null
      ? null
      : (id) => widget.onAction!(TimelineItemAction.jumpToEvent, widget.event);

  /// Whether the event was redacted (deleted).
  bool get _isRedacted => widget.event.redacted;

  /// Captures the inputs that influence what this widget renders.  Used
  /// by [didUpdateWidget] to skip the rebuild cost during rapid
  /// scrolling when an item's content has not actually changed.
  ///
  /// The matrix SDK mutates [Event.content] and [Event.status] in place,
  /// so identity comparison is not enough: we hash the fields that
  /// affect rendering.  The list is intentionally small (display type,
  /// font size, bubble radius, group-start flags, status, content
  /// length, redaction flag, highlight).  When the cache matches the
  /// previous build we return the cached subtree instead of re-running
  /// every descendant's `build()`.
  late _ItemRenderKey _renderKey;
  Widget? _cachedSubtree;

  @override
  void initState() {
    super.initState();
    _renderKey = _computeKey();
  }

  /// Hashes the rendering-relevant fields of the current widget into a
  /// small comparable record.
  _ItemRenderKey _computeKey() {
    final ev = widget.event;
    final content = ev.content;
    return _ItemRenderKey(
      displayType: widget.displayType,
      fontSize: widget.fontSize,
      bubbleRadius: widget.bubbleRadius,
      isGroupStart: widget.isGroupStart,
      isGroupContinuation: widget.isGroupContinuation,
      threadReplyCount: widget.threadReplyCount,
      highlight: widget.highlightedEventId == ev.eventId,
      redacted: ev.redacted,
      // Some test mocks omit [EventStatus]; coalesce to the synced
      // sentinel so we never throw from a build path.  In real SDK
      // use [EventStatus] is always populated.
      statusName: _safeStatusName(ev),
      // `content` is a mutable Map; hashing it directly is expensive
      // for big bodies.  Instead, we capture identity (length + map
      // identity) -- the SDK reallocates the map when the message is
      // edited, so identity-equality is enough to detect an edit for
      // the common case.  We additionally hash the body string so
      // in-place mutations of the body map (rare but possible) still
      // invalidate the cache.
      contentIdentity: identityHashCode(content),
      bodyLength: (content['body'] as String?)?.length ?? 0,
      senderId: ev.senderId,
      originServerTsMs: ev.originServerTs.millisecondsSinceEpoch,
    );
  }

  /// Reads [EventStatus.name] from the event without throwing when the
  /// underlying value is null (test mocks sometimes leave it unset).
  /// Falling back to the synced sentinel keeps equality stable across
  /// builds so the cache hit rate stays high.
  static String _safeStatusName(Event ev) {
    try {
      final s = ev.status;
      // [EventStatus] is declared non-nullable on [Event]; test mocks
      // sometimes leave it unset, which surfaces as a [TypeError] at
      // the getter.  Catch and fall back to the synced sentinel.
      return s.name;
    } catch (_) {
      return EventStatus.synced.name;
    }
  }

  @override
  void didUpdateWidget(covariant TimelineItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = _computeKey();
    if (newKey != _renderKey) {
      _renderKey = newKey;
      _cachedSubtree = null;
    }
  }

  /// Opens the sender's profile as a centered modal overlay.
  ///
  /// The overlay is decoupled from the room route -- it works even if
  /// the user later leaves the originating room, and it doesn't pop
  /// the current chat off the navigation stack.
  void _openProfile(BuildContext context) {
    final senderId = widget.event.senderFromMemoryOrFallback.id;
    showProfileOverlay(context, userId: senderId, room: widget.room);
  }

  /// Builds the inline hoverbar widget shown inside [HoverHighlight] when
  /// the cursor is over this message.  Returns `null` when no actions are
  /// available (e.g. IRC display mode or missing onAction callback).
  Widget? _buildActions(BuildContext context) {
    if (widget.onAction == null) return null;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: MessageActions(
        event: widget.event,
        room: widget.room,
        timeline: widget.timeline,
        onReply: _onReply ?? () {},
        onForward: _onForward,
        onThread: _onThread,
      ),
    );
  }

  /// Wraps [child] in a `GestureDetector` that opens the context menu on
  /// right-click (desktop) or long-press (touch).
  ///
  /// The reply, forward, thread, and profile callbacks are wired through so
  /// the menu can invoke them. When none of them are available, the gesture
  /// detector is omitted to avoid accidental interactions.
  Widget _wrapWithContextMenu(BuildContext context, Widget child) {
    if (widget.onAction == null) return child;

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapDown: (details) {
        MessageContextMenu.showForEvent(
          context: context,
          position: details.globalPosition,
          event: widget.event,
          room: widget.room,
          timeline: widget.timeline,
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
          event: widget.event,
          room: widget.room,
          timeline: widget.timeline,
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
        event: widget.event,
        isGroupContinuation: widget.isGroupContinuation,
      );
    }

    final isHighlighted = widget.highlightedEventId == widget.event.eventId;
    final hoverActions = _buildActions(context);

    // When nothing rendering-relevant has changed since the previous
    // build, replay the cached subtree verbatim.  This avoids the
    // cost of allocating Padding/Row/Column and re-running every
    // descendant `build()` on each parent rebuild -- the common case
    // during fast scrolling.
    final cached = _cachedSubtree;
    if (cached != null) {
      // [HoverHighlight] needs to react to the highlight toggle, which
      // is captured in [_renderKey.highlight].  We re-wrap the cached
      // subtree so the highlight state stays in sync with the latest
      // widget input.
      return HoverHighlight(
        isHighlighted: isHighlighted,
        actions: hoverActions,
        child: cached,
      );
    }

    Widget content;
    switch (widget.displayType) {
      case DisplayType.modern:
        content = _buildModern(context);
      case DisplayType.bubbles:
        content = _buildBubbles(context);
      case DisplayType.irc:
        content = _buildIrc(context);
    }

    // Cache the rendering subtree (before [HoverHighlight] wrapping so
    // the highlight state isn't snapshotted).  The next build will
    // replay this subtree without re-running any descendants.
    _cachedSubtree = content;

    content = HoverHighlight(
      isHighlighted: isHighlighted,
      actions: hoverActions,
      child: content,
    );

    // Wrapping the full highlight region with the context menu so that
    // right-click / long-press activates anywhere in the highlight area
    // (including the avatar column), not just on the message body.
    content = _wrapWithContextMenu(context, content);

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
    final isOutgoing = widget.event.senderId == widget.room.client.userID;
    final showDelivery =
        isOutgoing && widget.event.status != EventStatus.synced;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        MessageEventHandler(
          event: widget.event,
          timeline: widget.timeline,
          room: widget.room,
          fontSize: widget.fontSize,
          onJumpToEvent: _onJumpToEvent,
        ),
        if (widget.timeline != null)
          ReactionsBar(
            event: widget.event,
            timeline: widget.timeline!,
            room: widget.room,
          ),
        // Read-receipt avatars under every message that someone has seen.
        if (widget.timeline != null)
          ReceiptAvatars(event: widget.event, room: widget.room),
        if (showDelivery)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: DeliveryIndicator(
                status: _deliveryStatusFor(widget.event)),
          ),
        if (widget.threadReplyCount > 0)
          ThreadIndicator(
            replyCount: widget.threadReplyCount,
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
    final showAvatar = widget.isGroupStart && !widget.isGroupContinuation;

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
                      client: widget.room.client,
                      avatarUri: widget.event.senderFromMemoryOrFallback
                          .avatarUrl,
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
                if (widget.isGroupStart)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            widget.event.senderFromMemoryOrFallback
                                .calcDisplayname(),
                            style: TextStyle(
                              fontSize: widget.fontSize,
                              fontWeight: FontWeight.w700,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.event.originServerTs
                              .localizedTimeShort(context),
                          style: TextStyle(
                            fontSize: widget.fontSize * 0.6875,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                  ),
                // No timestamp for continuation messages (time shown on group start)
                _messageContent(context),
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
    final showAvatar = widget.isGroupStart && !widget.isGroupContinuation;

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
                      client: widget.room.client,
                      avatarUri: widget.event.senderFromMemoryOrFallback
                          .avatarUrl,
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
                  if (widget.isGroupStart)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4, left: 4),
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.event.senderFromMemoryOrFallback
                                  .calcDisplayname(),
                              style: TextStyle(
                                fontSize: widget.fontSize,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.event.originServerTs
                                .localizedTimeShort(context),
                            style: TextStyle(
                              fontSize: widget.fontSize * 0.6875,
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
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: _kMaxBubbleWidth,
                      ),
                      child: Container(
                        decoration: BoxDecoration(
                          color:
                              cs.primaryContainer.withValues(alpha: 0.3),
                          borderRadius:
                              BorderRadius.circular(widget.bubbleRadius),
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
          '<${widget.event.senderFromMemoryOrFallback.calcDisplayname()}>',
          style: TextStyle(
            fontSize: widget.fontSize,
            fontWeight: FontWeight.w700,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
        ),
      ),
      timestamp: Text(
        widget.event.originServerTs.localizedTimeShort(context),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          MessageEventHandler(
            event: widget.event,
            timeline: widget.timeline,
            room: widget.room,
            fontSize: widget.fontSize,
            onJumpToEvent: _onJumpToEvent,
          ),
          if (widget.timeline != null)
            ReactionsBar(
              event: widget.event,
              timeline: widget.timeline!,
              room: widget.room,
            ),
        ],
      ),
    );
  }
}

/// Compact equality record used by [_TimelineItemState] to short-circuit
/// rebuilds when no rendering-relevant input has changed.
///
/// Captures identity (content map), length, sender id, timestamp and a
/// handful of structural flags.  An in-place edit of the event body
/// invalidates this key via the [contentIdentity] + [bodyLength] pair;
/// a redaction flips [redacted]; an outgoing send flips [status].
@immutable
class _ItemRenderKey {
  const _ItemRenderKey({
    required this.displayType,
    required this.fontSize,
    required this.bubbleRadius,
    required this.isGroupStart,
    required this.isGroupContinuation,
    required this.threadReplyCount,
    required this.highlight,
    required this.redacted,
    required this.statusName,
    required this.contentIdentity,
    required this.bodyLength,
    required this.senderId,
    required this.originServerTsMs,
  });

  final DisplayType displayType;
  final double fontSize;
  final double bubbleRadius;
  final bool isGroupStart;
  final bool isGroupContinuation;
  final int threadReplyCount;
  final bool highlight;
  final bool redacted;

  /// Captures the [EventStatus.name] (a stable string) rather than the
  /// enum value itself so the equality check tolerates null returns
  /// from test mocks without throwing.
  final String statusName;
  final int contentIdentity;
  final int bodyLength;
  final String senderId;
  final int originServerTsMs;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _ItemRenderKey &&
        other.displayType == displayType &&
        other.fontSize == fontSize &&
        other.bubbleRadius == bubbleRadius &&
        other.isGroupStart == isGroupStart &&
        other.isGroupContinuation == isGroupContinuation &&
        other.threadReplyCount == threadReplyCount &&
        other.highlight == highlight &&
        other.redacted == redacted &&
        other.statusName == statusName &&
        other.contentIdentity == contentIdentity &&
        other.bodyLength == bodyLength &&
        other.senderId == senderId &&
        other.originServerTsMs == originServerTsMs;
  }

  @override
  int get hashCode => Object.hash(
        displayType,
        fontSize,
        bubbleRadius,
        isGroupStart,
        isGroupContinuation,
        threadReplyCount,
        highlight,
        redacted,
        statusName,
        contentIdentity,
        bodyLength,
        senderId,
        originServerTsMs,
      );
}




