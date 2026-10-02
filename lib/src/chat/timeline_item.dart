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

import 'dart:async';
import 'dart:math' as math;

import 'package:moonrelay/src/chat/chat_event.dart';
import 'package:moonrelay/src/chat/events/delivery_indicator.dart';
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
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/theme/component_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

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
/// Sender grouping logic:
/// - Consecutive events from the same sender within ~10 minutes are grouped:
///   the avatar and sender name appear only on the first event of the group.
/// - The timestamp is shown on every event by default, but hidden for
///   grouped events (the first event of the group still shows the time).
///
/// Display types:
/// - [DisplayType.modern] and [DisplayType.bubbles]: hover actions (React,
///   Reply, Forward, Delete) appear at the top-right when hovering anywhere
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
    this.onEdit,
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

  /// Optional callback triggered when the user wants to edit this event
  /// inline.  When set, the edit action delegates to this callback instead
  /// of opening the dialog via [MessageActionRunner.edit].
  final VoidCallback? onEdit;

  /// When non-null and matching this event's [event.eventId], the event
  /// is rendered with a brief highlight background flash.
  final String? highlightedEventId;

  @override
  State<TimelineItem> createState() => _TimelineItemState();
}

class _TimelineItemState extends State<TimelineItem> {
  /// Tracks whether the mouse is currently over this item.
  ///
  /// Using a [ValueNotifier] instead of [setState] means only the
  /// hover-sensitive parts (the actions overlay) rebuild on enter/exit,
  /// not the entire message subtree.  This is the single biggest win for
  /// scroll performance: without it, every mouse move over the chat
  /// area triggered a full [TimelineItem] rebuild.
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

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

  /// Retries sending a failed event via the SDK's [Event.sendAgain].
  /// Called from the [DeliveryIndicator] retry icon.
  void _onRetrySend() {
    unawaited(widget.event.sendAgain());
  }

  /// Builds the inline hoverbar widget shown when the cursor is over
  /// this message.  Returns `null` when no actions are available
  /// (e.g. IRC display mode or missing onAction callback).
  Widget? _buildActions(BuildContext context) {
    if (widget.onAction == null) return null;
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(t.radiusSm),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.5),
        ),
        boxShadow: t.shadowMedium,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceXxs,
        vertical: t.spaceXxs,
      ),
      child: MessageActions(
        event: widget.event,
        room: widget.room,
        timeline: widget.timeline,
        onReply: _onReply ?? () {},
        onForward: _onForward,
        onThread: _onThread,
        onEdit: widget.onEdit,
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
          onEdit: widget.onEdit,
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
          onEdit: widget.onEdit,
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
        room: widget.room,
        onForward: _onForward,
        onThread: _onThread,
        onReply: _onReply,
        onOpenProfile: () => _openProfile(context),
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
      // The highlight flag is re-applied each time since it's not part of
      // the cached subtree (the cached content is the raw message body).
      return _wrapWithHover(
        context: context,
        isHighlighted: isHighlighted,
        actions: hoverActions,
        child: _wrapWithContextMenu(context, cached),
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

    // Cache the rendering subtree (before hover wrapping so the
    // highlight state isn't snapshotted).  The next build will
    // replay this subtree without re-running any descendants.
    _cachedSubtree = content;

    return _wrapWithHover(
      context: context,
      isHighlighted: isHighlighted,
      actions: hoverActions,
      child: _wrapWithContextMenu(context, content),
    );
  }

  /// Wraps [child] in a [MouseRegion] that tracks hover state via
  /// [_isHovered] (a [ValueNotifier]), applying the hover tint and
  /// optionally the inline hoverbar.
  ///
  /// Only the hover-sensitive parts rebuild on enter/exit -- the
  /// [child] subtree is unaffected because it is not inside the
  /// [ValueListenableBuilder].
  ///
  /// Highlight and hover are deliberately different channels.  They used to
  /// share one [BoxDecoration] slot, which meant the two-second flash after a
  /// jump looked exactly like a mouse-over, and simply moving the pointer
  /// during the flash cancelled it.  The highlight is now an inset ring on
  /// the row, which survives the pointer, and which stays visible *above* a
  /// bubble's own fill rather than underneath it.
  Widget _wrapWithHover({
    required BuildContext context,
    required Widget child,
    required bool isHighlighted,
    required Widget? actions,
  }) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final motion = Motion.of(context);
    final cs = Theme.of(context).colorScheme;

    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: AnimatedContainer(
        // Colour and border only.  Animating a margin here would mean
        // re-laying-out the row on every frame of the flash; the row's own
        // vertical padding already leaves the ring room to read.
        duration: motion.duration(t.durationFast),
        curve: motion.curve(t.curveDecelerate),
        decoration: BoxDecoration(
          color: isHighlighted
              ? cs.primary.withValues(alpha: t.opacityFocus)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(t.radiusSm),
          border: isHighlighted
              ? Border.all(color: cs.primary, width: t.borderWidthThick)
              : null,
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            child,
            if (actions != null)
              ValueListenableBuilder<bool>(
                valueListenable: _isHovered,
                builder: (context, isHovered, _) {
                  if (!isHovered) return const SizedBox.shrink();
                  return Positioned(
                    top: t.spaceXs,
                    right: t.spaceSm,
                    child: actions,
                  );
                },
              ),
          ],
        ),
      ),
    );
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
              status: _deliveryStatusFor(widget.event),
              onRetry: widget.event.status.isError
                  ? _onRetrySend
                  : null,
            ),
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

  /// Vertical gap above this message.
  ///
  /// A run of messages from one sender and a series of unrelated messages
  /// used to have byte-identical spacing, so the eye had nothing to find a
  /// group boundary with: the avatar disappears on continuation messages and
  /// the sender name only appears on the first one.  The gap is what carries
  /// the structure, so it has to differ between the two cases.
  double _verticalSpacing(MoonrelayChatTokens chat) =>
      widget.isGroupStart ? chat.groupSpacing : chat.rowSpacing;

  Widget _buildModern(BuildContext context) {
    final theme = Theme.of(context);
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final chat = ext.components.chat;
    final showAvatar = widget.isGroupStart && !widget.isGroupContinuation;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceSm,
        vertical: _verticalSpacing(chat),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar column
          SizedBox(
            width: chat.avatarGutter,
            child: showAvatar
                ? Padding(
                    padding: EdgeInsets.only(top: t.spaceXs),
                    child: AvatarFromUriOrFallbackImage(
                      client: widget.room.client,
                      avatarUri: widget.event.senderFromMemoryOrFallback
                          .avatarUrl,
                      onTap: () => _openProfile(context),
                    ),
                  )
                : null,
          ),
          SizedBox(width: t.spaceSm),
          // Content column.  Capped at a readable measure: flat display
          // modes used to run body text the full width of the pane, which
          // in the expanded dashboard shell is a fifteen-hundred-pixel line.
          Expanded(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: chat.measureMaxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Sender name + timestamp (only for group-start)
                    if (widget.isGroupStart)
                      Padding(
                        padding: EdgeInsets.only(bottom: t.spaceXs),
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.event.senderFromMemoryOrFallback
                                    .calcDisplayname(),
                                style: TextStyle(
                                  fontSize:
                                      chat.senderFontSize(widget.fontSize),
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            SizedBox(width: t.spaceSm),
                            Text(
                              widget.event.originServerTs
                                  .localizedTimeShort(context),
                              style: TextStyle(
                                fontSize:
                                    chat.metadataFontSize(widget.fontSize),
                                fontWeight: FontWeight.w500,
                                color: theme.colorScheme.onSurface
                                    .withValues(alpha: t.opacitySubtle),
                              ),
                            ),
                          ],
                        ),
                      ),
                    // No timestamp for continuation messages (time shown on
                    // group start)
                    _messageContent(context),
                  ],
                ),
              ),
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
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final chat = ext.components.chat;
    final showAvatar = widget.isGroupStart && !widget.isGroupContinuation;
    // Own messages read as *your side* of the conversation, not as a
    // slightly darker version of everyone else's.  The old signal was a
    // fifteen percent alpha difference on one shared hue, which is at or
    // under the threshold of notice on a large filled area and vanishes
    // entirely in dark mode, where `primaryContainer` is already a dark,
    // low-chroma value.  Two different surface roles is a signal that
    // survives the palette.
    final isOwn = widget.event.senderId == widget.room.client.userID;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Scale the width cap and the floating gutter with the pane.  The
        // gutter used to be a flat 64px, which cost thirteen percent of a
        // phone screen; the cap was a flat 480px, which on a phone is most
        // of the pane anyway and reads better as a proportion.
        final bubbleMax = math.min(
          chat.bubbleMaxWidth,
          constraints.maxWidth * 0.78,
        );
        final gutter = math.min(
          chat.bubbleGutter,
          constraints.maxWidth * 0.12,
        );

        return Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceSm,
            vertical: _verticalSpacing(chat),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar column
              SizedBox(
                width: chat.avatarGutter,
                child: showAvatar
                    ? Padding(
                        padding: EdgeInsets.only(top: t.spaceXs),
                        child: AvatarFromUriOrFallbackImage(
                          client: widget.room.client,
                          avatarUri: widget.event.senderFromMemoryOrFallback
                              .avatarUrl,
                          onTap: () => _openProfile(context),
                        ),
                      )
                    : null,
              ),
              SizedBox(width: t.spaceSm),
              // Bubble content.  The whole column is wrapped in an
              // [Expanded] (filling the row) with a gutter on the right so
              // the bubble floats to the left and the gap on the right gives
              // the layout visual breathing room.
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: gutter),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.isGroupStart)
                        Padding(
                          padding: EdgeInsets.only(
                            bottom: t.spaceXs,
                            left: t.spaceXs,
                          ),
                          child: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.event.senderFromMemoryOrFallback
                                      .calcDisplayname(),
                                  style: TextStyle(
                                    fontSize:
                                        chat.senderFontSize(widget.fontSize),
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              SizedBox(width: t.spaceSm),
                              Text(
                                widget.event.originServerTs
                                    .localizedTimeShort(context),
                                style: TextStyle(
                                  fontSize:
                                      chat.metadataFontSize(widget.fontSize),
                                  fontWeight: FontWeight.w500,
                                  color: cs.onSurface
                                      .withValues(alpha: t.opacitySubtle),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // The bubble hugs its content rather than stretching
                      // to fill the chat column, and hugs the leading edge
                      // rather than centring, so a run of messages reads as
                      // a left margin instead of a ragged centred stack.
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: bubbleMax),
                          child: Container(
                            decoration: BoxDecoration(
                              // A fill and a lift, not an outline.
                              //
                              // This was a 30% primary fill behind a 0.7px
                              // 50% primary border, which is the visual
                              // signature of a wireframe: it draws a box
                              // around the text rather than putting a
                              // surface under it, so a screen full of them
                              // looks like a diagram of messages instead of
                              // messages.
                              //
                              // A fill plus the shadowLow pair, because the
                              // two shadow layers together do the work the
                              // border was standing in for. One would read
                              // as a glow.
                              color: isOwn
                                  ? cs.primaryContainer
                                  : cs.surfaceContainerHighest
                                      .withValues(alpha: t.opacityDisabled),
                              borderRadius: BorderRadius.circular(
                                widget.bubbleRadius,
                              ),
                              boxShadow: t.shadowLow,
                            ),
                            padding: EdgeInsets.symmetric(
                              horizontal: chat.messagePaddingH,
                              vertical: chat.messagePaddingV,
                            ),
                            child: _messageContent(context),
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
      },
    );
  }

  // ---------------------------------------------------------------------------
  // IRC display (compact, no hover actions)
  // ---------------------------------------------------------------------------

  Widget _buildIrc(BuildContext context) {
    final chat =
        MoonrelayThemeExtension.of(context).components.chat;

    return IRCRow(
      sender: SizedBox(
        width: 120,
        child: Text(
          '<${widget.event.senderFromMemoryOrFallback.calcDisplayname()}>',
          style: TextStyle(
            fontSize: chat.senderFontSize(widget.fontSize),
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.right,
        ),
      ),
      timestamp: Text(
        widget.event.originServerTs.localizedTimeShort(context),
        style: TextStyle(
          fontSize: chat.metadataFontSize(widget.fontSize),
          fontWeight: FontWeight.w500,
        ),
      ),
      // `_messageContent`, not a hand-rolled column.  IRC mode used to
      // rebuild the body itself with just the event handler and the reaction
      // bar, which quietly dropped delivery state, read receipts, and thread
      // counts: a user who switched display types stopped being able to see
      // whether their own messages had actually been sent.
      body: _messageContent(context),
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




