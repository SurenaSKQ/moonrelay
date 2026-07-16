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

import 'package:moonrelay/src/chat/animated_history_skeleton.dart';
import 'package:moonrelay/src/chat/events/date_separator.dart';
import 'package:moonrelay/src/chat/history_skeleton_tile.dart';
import 'package:moonrelay/src/chat/item_appearance.dart';
import 'package:moonrelay/src/chat/forward_message_dialog.dart';
import 'package:moonrelay/src/chat/state_event_tile.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/chat/undecryptable_banner.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/helpers/thread_utils.dart';
import 'package:flutter/material.dart';
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
/// thread replies) are excluded from the visible list because they are rendered
/// inline with their parent event.  Thread roots (events whose relationship
/// type is `m.thread` and that reference themselves) are kept visible because
/// they are the start of a thread and appear as regular messages.
class TimelineView extends StatefulWidget {
  const TimelineView({
    super.key,
    required this.timeline,
    required this.room,
    required this.displayType,
    required this.scrollController,
    required this.fontSize,
    this.bubbleRadius = 12.0,
    this.timelineVersion,
    this.onReply,
    this.onThread,
    this.showStateEvents = true,
    this.filterEvents,
    this.isLoadingHistory = false,
    this.highlightedEventId,
  });

  final Timeline timeline;
  final Room room;
  final DisplayType displayType;
  final ScrollController scrollController;

  /// Font size for message text, propagated from [SettingsController]
  /// once at the top level instead of watched inside each item.
  final double fontSize;

  /// Corner radius for the message bubble in bubbles display mode.
  final double bubbleRadius;

  /// Included so the parent can signal data changes without tearing down
  /// the ListView (no [ValueKey] used).
  final int? timelineVersion;

  /// Called when the user replies to a specific event.
  final void Function(Event event)? onReply;

  /// Called when the user wants to open or create a thread for an event.
  final void Function(Event event)? onThread;

  /// Whether to render state events (join/leave/room metadata changes).
  /// When false, state events are hidden from the timeline.
  final bool showStateEvents;

  /// When non-null, overrides the default visibility filter.  The function
  /// receives each event and should return `true` to make it visible.
  /// When null, [ThreadUtils.isVisibleInMainTimeline] is used.
  final bool Function(Event)? filterEvents;

  /// When `true`, the list appends a small block of skeleton placeholders
  /// at the *end* of the item list (which, with `reverse: true`, appears
  /// at the top of the viewport) so the user sees feedback instead of
  /// an abrupt scroll cap while older history is being paginated in.
  final bool isLoadingHistory;

  /// When non-null, the event with this id is rendered with a brief
  /// highlight ring.  The TimelineView's own [jumpToEvent] path also
  /// sets this internally, but the parent can pass it in to highlight
  /// a target the parent selected (e.g. the jump-to-unread action).
  final String? highlightedEventId;

  @override
  State<TimelineView> createState() => TimelineViewState();
}

class TimelineViewState extends State<TimelineView> {
  /// The event ID currently highlighted by a "jump to event" action, or
  /// null if nothing is highlighted.
  String? _highlightedEventId;

  /// Count of currently-visible encrypted events that can't be decrypted,
  /// exposed to the [UndecryptableBanner] via [ValueListenable] so the
  /// banner reflects new arrivals without forcing a full item-list rebuild.
  final ValueNotifier<int> _undecryptableCount = ValueNotifier<int>(0);

  /// Public accessor so [UndecryptableBanner] can listen for count
  /// changes without accessing the private field directly.
  ValueNotifier<int> get undecryptableCountNotifier => _undecryptableCount;

  /// Stable [GlobalKey] per visible event id. Re-built alongside the
  /// cached item list so a `jumpToEvent` can resolve the rendered
  /// [BuildContext] for any event currently on screen.  Without a
  /// real key we'd have to fall back to a fraction-based scroll
  /// estimate (items have variable heights so the fraction is
  /// imprecise, and the user complained the previous behaviour
  /// "doesn't jump enough  but not always").  Storing the keys on
  /// the state object means they survive item-list rebuilds while
  /// the timeline version stays the same, so an existing item keeps
  /// the same key across rebuilds.
  final Map<String, GlobalKey> _eventKeys = <String, GlobalKey>{};

  // ---------------------------------------------------------------------------
  // Cached computed values
  // ---------------------------------------------------------------------------

  /// Cached result of [_buildItemList], invalidated when the timeline version
  /// or any display-affecting prop changes.  This prevents O(n) rebuilds of
  /// the entire visible item list on every sync tick.
  List<Widget>? _cachedItems;

  /// Cached result of [_visibleIndices].
  List<int>? _cachedVisibleIndices;

  /// Cached event-id-to-item-index map for jump-to-event.
  Map<String, int>? _cachedEventIdToItemIndex;

  /// The [widget.timelineVersion] when the cache was last built.  Also
  /// embeds other display-affecting props so the cache is invalidated
  /// when font size, display type, or state-event visibility changes.
  ///
  /// `highlightedEventId` is intentionally NOT part of the key: the
  /// highlight is applied per-item via [HoverHighlight] and a
  /// highlight toggle doesn't require rebuilding the entire item
  /// list.
  String get _cacheKey =>
      '${widget.timelineVersion}_${widget.fontSize}_${widget.displayType.index}_${widget.showStateEvents}_${widget.filterEvents.hashCode}_${widget.isLoadingHistory}';

  String _lastCacheKey = '';

  /// Invalidates all cached values so they are recomputed on the next build.
  void _invalidateCache() {
    _cachedItems = null;
    _cachedVisibleIndices = null;
    _cachedEventIdToItemIndex = null;
    // The key map is rebuilt alongside the items  we don't drop it
    // here so any keys that map to events still present on the next
    // build can be reused; new events get fresh keys below.
  }

  /// Counts encrypted events currently visible according to the active
  /// filter / state-event toggle.  Used to drive the
  /// [_UndecryptableBanner] so a new encrypted arrival bumps the badge
  /// without invalidating the full item-list cache.
  int _countUndecryptable() {
    final filter = widget.filterEvents;
    final events = widget.timeline.events;
    var count = 0;
    for (var idx = 0; idx < events.length; idx++) {
      final ev = events[idx];
      if (filter != null) {
        if (!filter(ev)) continue;
      } else {
        if (!ThreadUtils.isVisibleInMainTimeline(ev)) continue;
      }
      if (ev.type != EventTypes.Encrypted) continue;
      count++;
    }
    return count;
  }

  @override
  void didUpdateWidget(TimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = _cacheKey;
    if (newKey != _lastCacheKey) {
      _invalidateCache();
    }
    // Only recompute the undecryptable count when the underlying
    // timeline content changes (timelineVersion bumped).  Other prop
    // changes (font size, display type, highlight toggle, filter
    // changes that don't touch the event set) don't change the count
    // so we skip the O(n) scan to keep rapid scrolling cheap.  The
    // banner listens to the ValueNotifier so an arriving encrypted
    // event that doesn't touch the cache key still produces a correct
    // count as long as the parent rebuilds this widget (which it does
    // on every sync via [TimelineView.timelineVersion]).
    if (oldWidget.timelineVersion != widget.timelineVersion) {
      _undecryptableCount.value = _countUndecryptable();
    }
  }

  @override
  void dispose() {
    _undecryptableCount.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Index helpers
  // ---------------------------------------------------------------------------

  /// Indices (into `timeline.events`) of events that should appear as
  /// standalone items.  Events are in SDK order (newest -> oldest).
  ///
  /// Thread roots (self-referencing `m.thread` events) are kept visible;
  /// all other related events (reactions, edits, thread replies) are hidden.
  List<int> _visibleIndices() {
    if (_cachedVisibleIndices != null) return _cachedVisibleIndices!;
    final indices = List<int>.generate(widget.timeline.events.length, (i) => i);
    final filter = widget.filterEvents;
    indices.removeWhere((i) {
      final event = widget.timeline.events[i];
      if (filter != null) return !filter(event);
      return !ThreadUtils.isVisibleInMainTimeline(event);
    });
    _cachedVisibleIndices = indices;
    return indices;
  }

  /// True when [event] is a state event (not a regular message or sticker).
  bool _isStateEvent(Event event) =>
      event.type != EventTypes.Message && event.type != EventTypes.Sticker;

  /// True when [newer] and [older] belong to the same sender and fall within
  /// the same ~10‑minute environment, i.e. they should share a visual group.
  ///
  /// [newer] is the chronologically newer event (displayed lower in the
  /// timeline) and [older] is the earlier event (displayed higher up).
  /// When they form a group, the **older** event acts as the group start
  /// (shows avatar/name) and the newer event is a continuation (no avatar).
  ///
  /// Stickers never group with adjacent messages  they are short,
  /// visually-distinct and conventionally shown as standalone rows
  /// with their own sender label.
  bool _isContinuation(Event newer, Event older) {
    if (newer.senderId != older.senderId) return false;
    if (newer.messageType == MessageTypes.Sticker ||
        older.messageType == MessageTypes.Sticker) {
      return false;
    }
    return newer.originServerTs.sameEnvironment(older.originServerTs);
  }

  /// Returns the next non-state-event event that would be visible
  /// as a regular message, skipping past state events that may be
  /// hidden (when [showStateEvents] is false).
  /// Returns null if no visible message event follows.
  Event? _nextVisibleMessage(
      List<int> visibleIndices, List<Event> events, int currentI) {
    int j = currentI + 1;
    while (j < visibleIndices.length) {
      final idx = visibleIndices[j];
      final ev = events[idx];
      if (!_isStateEvent(ev)) {
        return ev;
      }
      j++;
    }
    return null;
  }

  /// Returns (and lazily creates) the stable [GlobalKey] for [eventId].
  ///
  /// Keys are kept on [_eventKeys] so a single event keeps the same
  /// [GlobalKey] across rebuilds.  When the cached item list is
  /// invalidated (e.g. the timeline version advances) keys for events
  /// that are no longer present are pruned by [_pruneStaleKeys] which
  /// the item builder calls after the new key map is assembled.
  GlobalKey _keyFor(String eventId) {
    return _eventKeys.putIfAbsent(eventId, () => GlobalKey(debugLabel: 'tl_$eventId'));
  }

  /// Drops entries from [_eventKeys] whose events are no longer
  /// referenced by the freshly-built cache.  Keeps the map bounded
  /// over long-lived views.
  void _pruneStaleKeys(Set<String> liveIds) {
    _eventKeys.removeWhere((id, _) => !liveIds.contains(id));
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
  /// calendar day.  Consecutive state events are grouped into a single
  /// [StateEventTile] widget when [widget.showStateEvents] is true, or filtered out
  /// when it is false.
  ///
  /// If any visible events are undecryptable (type == `m.room.encrypted`), an
  /// info banner is prepended to alert the user that some messages can't be
  /// read and suggest verification or key request.
  ///
  /// Results are cached in [_cachedItems] and [_cachedEventIdToItemIndex] so
  /// that the same timeline version produces the same widget list without
  /// re-scanning every event.  The cache is invalidated when [widget.timelineVersion]
  /// or any display-affecting prop changes.
  List<Widget> _buildItemList(BuildContext context) {
    if (_cachedItems != null) return _cachedItems!;

    final visibleIndices = _visibleIndices(); // newest -> oldest
    final threadReplyCounts =
        ThreadUtils.buildThreadReplyCounts(widget.timeline);
    final items = <Widget>[];
    // Map of eventId -> item index in [items], built as we go.
    final eventIdToItemIndex = <String, int>{};
    Event? previousVisible; // the *newer* neighbour (non-state events only)
    int undecryptableCount = 0;
    int i = 0;

    while (i < visibleIndices.length) {
      final eventIndex = visibleIndices[i];
      final event = widget.timeline.events[eventIndex];

      // Count undecryptable encrypted events
      if (event.type == EventTypes.Encrypted) {
        undecryptableCount++;
      }

      if (_isStateEvent(event)) {
        if (widget.showStateEvents) {
          // Collect a run of consecutive state events.
          final batch = <Event>[event];
          i++;
          while (i < visibleIndices.length &&
              _isStateEvent(widget.timeline.events[visibleIndices[i]])) {
            batch.add(widget.timeline.events[visibleIndices[i]]);
            i++;
          }

          // Insert a date boundary before the batch if needed (using the
          // oldest event in the batch for the comparison).
          if (previousVisible != null &&
              _isDifferentDay(previousVisible, batch.last)) {
            items.add(DateSeparator(dateTime: batch.last.originServerTs));
          }

          items.add(StateEventTile(events: batch));
          // Do NOT update previousVisible -- state events don't participate
          // in regular message grouping/continuation.
        } else {
          // Skip state events entirely.
          i++;
        }
      } else {
        // Regular message event.
        if (previousVisible != null &&
            _isDifferentDay(previousVisible, event)) {
          items.add(DateSeparator(dateTime: event.originServerTs));
        }

        // An event is a continuation of the **older** event above it
        // (next in newest-first iteration). This ensures the oldest
        // (uppermost) message in a group is the one that shows the
        // sender avatar and name.
        // Walk past hidden state events so they don't incorrectly
        // absorb the sender info. A skipped state event can't
        // serve as the group-start avatar.
        final effectiveNextEvent =
            _nextVisibleMessage(visibleIndices, widget.timeline.events, i);
        final isContinuation = effectiveNextEvent != null &&
            _isContinuation(event, effectiveNextEvent);

        // Look up the reply count from the precomputed map instead of
        // scanning the timeline for each event.
        final replyCount = threadReplyCounts[event.eventId] ?? 0;

        items.add(RepaintBoundary(
          // Each item gets its own layer so a single dirty item
          // (hover, highlight, optimistic outgoing) only invalidates
          // its own paint, not the entire viewport. This is the
          // single biggest win for rapid scrolling: scroll-induced
          // builds stay cheap because Flutter composites pre-painted
          // layers instead of repainting every visible message.
          key: _keyFor(event.eventId),
          child: TimelineItem(
            event: event,
            room: widget.room,
            displayType: widget.displayType,
            isGroupStart: !isContinuation,
            isGroupContinuation: isContinuation,
            timeline: widget.timeline,
            fontSize: widget.fontSize,
            bubbleRadius: widget.bubbleRadius,
            threadReplyCount: replyCount,
            // Per-item GlobalKey reused by the [HoverTarget] inside
            // the item to register its hit region with the shared
            // hover controller.  Same key as the [RepaintBoundary]
            // above, so the overlay's positioning logic finds the
            // item's render box via the same anchor the sliver uses.
            itemKey: _eventKeys[event.eventId],
            // Single stable callback for every action: keeps the leaf
            // closures' identity stable across rebuilds so Flutter can
            // re-use the existing Element tree instead of inflating new
            // TimelineItem nodes on every parent build.
            onAction: (action, e) =>
                _handleItemAction(action, e, eventIdToItemIndex),
            highlightedEventId:
                widget.highlightedEventId ?? _highlightedEventId,
          ),
        ));

        eventIdToItemIndex[event.eventId] = items.length - 1;
        previousVisible = event;
        i++;
      }
    }

    // Always insert the undecryptable banner at index 0 (it self-hides
    // when the count is zero).  Sourcing the count from a [ValueNotifier]
    // means new encrypted events refresh the badge without invalidating
    // the item-list cache or rebuilding every [TimelineItem].
    _undecryptableCount.value = undecryptableCount;
    items.insert(0, const UndecryptableBanner());

    _cachedItems = items;
    _cachedEventIdToItemIndex = eventIdToItemIndex;
    _lastCacheKey = _cacheKey;

    // Drop key-map entries for events that no longer exist in the
    // rendered item list.  Doing this after the items + index map are
    // cached keeps the lookup hot path stable across calls  the
    // pruning is a single pass over [_eventKeys].
    _pruneStaleKeys(eventIdToItemIndex.keys.toSet());

    return items;
  }

  @override
  void initState() {
    super.initState();
    _lastCacheKey = _cacheKey;
    _undecryptableCount.value = _countUndecryptable();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Items are already newest-first; `reverse: true` puts index 0 at the
    // bottom so the newest event appears at the bottom of the viewport.
    final items = _buildItemList(context);

    // When the user has scrolled to the top of the loaded history and
    // the server still owes us more events, render skeleton message
    // tiles *after* the cached items.  Because the list is reversed,
    // the new items sit at the top of the viewport  directly above
    // the oldest known event  and are smoothly swapped out for
    // real events as the SDK paginates them in.
    final hasMore = widget.isLoadingHistory;
    final extra = hasMore ? _buildHistoryLoadingSkeletons() : <Widget>[];

    // `findChildIndexCallback` needs a Key -> index map so a caller
    // can resolve a [GlobalKey] back to a sliver index in O(1).  Each
    // item's [Widget.key] is the same [GlobalKey] we hand out from
    // [_keyFor]; we walk the list once here so the delegate's
    // callback stays O(1).
    final Map<Key, int> keyToIndex = <Key, int>{
      for (var i = 0; i < items.length; i++)
        if (items[i].key != null) items[i].key!: i,
    };
    // The skeleton entry sits at the last sliver index.  We use a
    // constant key so [_scrollToEventId] can recognise it if it ever
    // needs to scroll to "the loading-more indicator".
    const skeletonKey = ValueKey<String>('tl_skeleton');

    final list = ListView.custom(
      controller: widget.scrollController,
      reverse: true,
      childrenDelegate: SliverChildBuilderDelegate(
        _buildItemAt(items, hasMore, extra),
        childCount: items.length + 1,
        // Bidirectional Key <-> index map.  Lets
        // [ScrollPosition.ensureVisible] (and any other call site)
        // resolve an event id to its exact sliver index in O(1),
        // dropping the old fraction-based fallback for off-screen
        // jumps.
        findChildIndexCallback: (Key key) {
          if (key == skeletonKey) return items.length;
          return keyToIndex[key];
        },
        addRepaintBoundaries: false,
        // Each item already wraps itself in a [RepaintBoundary]; we
        // disable the delegate's automatic per-item layers so we don't
        // pay for two of them.  We also opt out of the automatic
        // keep-alive wrapper: chat items are pure functions of their
        // event plus display inputs, so we don't need to keep
        // off-screen state alive across scrolls.
        addAutomaticKeepAlives: false,
      ),
    );

    // Wrap the list in a [HoverScope] so [HoverItem]s inside each
    // row can register their hit regions with the shared
    // controller.  A single global [MouseRegion] covers the list
    // viewport and drives [HoverOverlayController.hitTest] on
    // every pointer move: items don't host their own [MouseRegion]
    // anymore, which avoids the brief "exit-no-enter" gap that
    // produced the toolbar flash.
    //
    // [HoverOverlay] lives alongside so it can find
    // [Overlay.of(context)] for its toolbar entry.  It returns a
    // zero-size widget; the toolbar is inserted into the route's
    // overlay.
    return list;
  }



  /// Builds the per-index builder used by [ListView.custom].
  ///
  /// Pulled into a method so the closure captured by the sliver delegate
  /// stays small (just `items`, `hasMore`, `extra`) and the actual
  /// branching can be unit tested in isolation.
  Widget Function(BuildContext, int) _buildItemAt(
    List<Widget> items,
    bool hasMore,
    List<Widget> extra,
  ) {
    return (BuildContext context, int index) {
      if (index == items.length) {
        return AnimatedHistorySkeleton(
          show: hasMore,
          children: extra,
        );
      }
      // Animate items that just got paginated in: the oldest end of
      // the timeline (top of the viewport when `reverse: true`).
      final isNewestHistory = hasMore && index <= 4;
      if (isNewestHistory) {
        return ItemAppearance(
          key: ValueKey('${items.length}_$index'),
          child: items[index],
        );
      }
      return items[index];
    };
  }

  /// Returns skeleton message placeholders shown at the top of the
  /// viewport while older history is being paginated in.
  ///
  /// A single tile is shown  the timeline re-renders incrementally as
  /// paginated events arrive, with each newly-arrived event fading in
  /// from its top edge instead of being snapped into place.  Keeping
  /// the placeholder count small avoids the prior "stacked skeleton"
  /// gap that snapped out of view once any real event arrived.
  List<Widget> _buildHistoryLoadingSkeletons() {
    return const <Widget>[
      HistorySkeletonTile(barFraction: 0.65),
    ];
  }

  /// Returns a callback that scrolls to a target event identified by
  /// [eventId].  Uses the [eventIdToItemIndex] map built during
  /// [_buildItemList] to find the item's list position, then animates
  /// the scroll controller to roughly that location.
  ///
  /// Because the ListView uses `reverse: true`, newer items are at the
  /// bottom (scroll offset 0) and older items are at the top (max scroll
  /// extent).  The offset is computed against the rendered item itself
  /// (via its [GlobalKey]) rather than a linear fraction of item
  /// indices.  Items have variable heights  a 5-line image message is
  /// several times taller than a single-line text reply  so a fraction
  /// estimate routinely landed the user a few items away from the
  /// target.  Using the actual [BuildContext] of the on-screen item
  /// makes the jump pixel-accurate: when the item is visible, we ask
  /// [Scrollable.ensureVisible] for the exact pixel offset; when it
  /// isn't, we fall back to the previous fraction-based heuristic so
  /// paginated-off-screen targets still scroll in the right direction.
  ///
  /// [ListView.custom]'s [SliverChildBuilderDelegate.findChildIndexCallback]
  /// lets external callers (notably [ChatTimelineState.jumpToEvent])
  /// resolve an event id to its sliver index in O(1), bypassing this
  /// callback entirely when the target has been built.  This method
  /// remains the in-state entry point for jump-to-reply / jump-to-thread.
  void _scrollToEventId(String eventId) {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;

    final map = _cachedEventIdToItemIndex;
    final itemCount = map?.length ?? 0;
    final targetIdx = map?[eventId];
    if (targetIdx == null) return;

    // Highlight the target event briefly.
    setState(() => _highlightedEventId = eventId);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          if (_highlightedEventId == eventId) {
            _highlightedEventId = null;
          }
        });
      }
    });

    // Prefer [Scrollable.ensureVisible] when the item is currently
    // mounted on screen: it computes the exact pixel offset of the
    // rendered widget, so the target lands one-third from the top
    // regardless of variable-height items above it.
    final globalKey = _eventKeys[eventId];
    final ctx = globalKey?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.33,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOut,
      );
      return;
    }

    // Fallback: the target is virtualised out of the rendered window.
    // Use the fraction estimate so we at least scroll in the right
    // direction  the parent paginates enough history so this case is
    // rare.
    final position = controller.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    final fraction = itemCount > 1 ? targetIdx / (itemCount - 1) : 0.0;
    final targetOffset = position.minScrollExtent + range * fraction;

    final distancePx = (targetOffset - position.pixels).abs();
    final viewportHeight = position.viewportDimension;
    if (distancePx < viewportHeight * 0.6) return;

    final paddedOffset = (targetOffset - viewportHeight * 0.33).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    controller.animateTo(
      paddedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Single dispatch for every [TimelineItemAction].  Centralises the
  /// routing so each [TimelineItem] can hand the view a single stable
  /// callback closure (keeping the Element tree reusable across rebuilds).
  ///
  /// [eventIdToItemIndex] is captured for backwards compatibility with
  /// callers that supplied it; the implementation reads the cached
  /// [_cachedEventIdToItemIndex] instead so the map identity stays
  /// consistent.
  void _handleItemAction(
    TimelineItemAction action,
    Event event,
    Map<String, int> eventIdToItemIndex,
  ) {
    switch (action) {
      case TimelineItemAction.reply:
        widget.onReply?.call(event);
        break;
      case TimelineItemAction.thread:
        widget.onThread?.call(event);
        break;
      case TimelineItemAction.forward:
        showForwardDialog(
          context: context,
          event: event,
          sourceRoom: widget.room,
        );
        break;
      case TimelineItemAction.jumpToEvent:
        _scrollToEventId(event.eventId);
        break;
    }
  }

  /// Public entry point used by [ChatTimeline] to jump to an arbitrary
  /// event id without owning the [GlobalKey] map directly.  Delegates
  /// to [_scrollToEventId] which already uses
  /// [Scrollable.ensureVisible] for on-screen targets and the
  /// fraction-based fallback otherwise.
  void scrollToEventId(String eventId) => _scrollToEventId(eventId);
}

/// Smoothly-fading block of [SkeletonTile]s shown at the top of the
/// timeline when the user has reached the end of the loaded history
/// and the SDK is paginating more events in.
///
/// The transition is driven by an internal [AnimationController] so
/// the block grows from zero height when the user first scrolls to
/// the end, and collapses back to zero when the SDK clears
/// [Room.prev_batch].  The contained [FadeTransition] makes the
/// placeholders softly appear / disappear instead of snapping.
class _AnimatedHistorySkeleton extends StatefulWidget {
  const _AnimatedHistorySkeleton({
    required this.show,
    required this.children,
  });

  /// When `true`, the block expands to show the [children].  When
  /// `false`, the block collapses to zero height and the children
  /// are removed from the widget tree once the animation finishes.
  final bool show;
  final List<Widget> children;

  @override
  State<_AnimatedHistorySkeleton> createState() =>
      _AnimatedHistorySkeletonState();
}

class _AnimatedHistorySkeletonState extends State<_AnimatedHistorySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late Motion _motion;

  @override
  void initState() {
    super.initState();
    _motion = Motion.of(context);
    _controller = AnimationController(
      vsync: this,
      duration: _motion.duration(MotionDurations.slow),
      value: widget.show ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: _motion.curve(),
    );
  }

  @override
  void didUpdateWidget(covariant _AnimatedHistorySkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show != widget.show) {
      if (widget.show) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ClipRect keeps the skeleton tiles from peeking out as the
    // block's height animates from zero.  FadeTransition + SizeTransition
    // give us both opacity and height transitions from a single
    // animation value.
    return ClipRect(
      child: SizeTransition(
        axis: Axis.vertical,
        sizeFactor: _animation,
        alignment: const Alignment(-1.0, -1.0),
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}

/// Per-item appearance transition.
///
/// Used to fade newly-paginated history into view at the top of the
/// timeline (the oldest end with `reverse: true`).  When the
/// animations setting is off, the wrapper reduces to its child so the
/// frame budget stays free of unnecessary transitions.
class _ItemAppearance extends StatefulWidget {
  const _ItemAppearance({required this.child});
  final Widget child;

  @override
  State<_ItemAppearance> createState() => _ItemAppearanceState();
}

class _ItemAppearanceState extends State<_ItemAppearance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late Motion _motion;

  @override
  void initState() {
    super.initState();
    _motion = Motion.of(context);
    _controller = AnimationController(
      vsync: this,
      duration: _motion.duration(MotionDurations.medium),
      value: 0.0,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: _motion.curve());
    // The new event is appended at the *top* of the list (which sits
    // at the top of the viewport with `reverse: true`).  We want it
    // to slide *down* into the viewport, so the slide begins from a
    // small negative-Y offset (offscreen-above) and settles at zero.
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(_opacity);
    // Defer the forward() call by one frame so the new widget first
    // paints in its from-state; without this Flutter optimises the
    // starting frame out and the transition is invisible.
    if (_motion.enableAnimations) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // The widget may have been disposed before the next frame was
        // drawn (e.g. when paginated history is removed immediately
        // after insertion); guard with `mounted` to avoid calling
        // forward() on a disposed controller.
        if (mounted) _controller.forward();
      });
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_motion.enableAnimations) return widget.child;
    return ClipRect(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}

/// Single skeleton message tile used to fill the viewport while older
/// history is being paginated in.
///
/// Mirrors the visual rhythm of a real [TimelineItem] (avatar circle
/// + a body block) but renders as muted rounded rectangles so the
/// user sees feedback without misreading the placeholders for actual
/// messages.  A subtle pulse animation cycles the bar opacity to
/// communicate that loading is in progress; it is disabled when the
/// user has turned off app animations in settings.
class _HistorySkeletonTile extends StatefulWidget {
  const _HistorySkeletonTile({required this.barFraction});

  /// Width of the bottom "body" bar as a fraction of the available
  /// width.  Per-tile variance makes the stack look like a real
  /// group of mixed-length messages instead of a regular grid.
  final double barFraction;

  @override
  State<_HistorySkeletonTile> createState() => _HistorySkeletonTileState();
}

class _HistorySkeletonTileState extends State<_HistorySkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    final motion = Motion.of(context);
    // Use a slow pulse  the user is waiting for new events so the
    // animation needs to convey "working" without flickering.
    _controller = AnimationController(
      vsync: this,
      duration: motion.duration(const Duration(milliseconds: 1200)),
    );
    _opacity = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: motion.curve()));
    if (motion.enableAnimations) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _pulse(
                child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: base,
                shape: BoxShape.circle,
              ),
            )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pulse(
                    child: _skeletonBar(
                  width: width * 0.32,
                  height: 13,
                  color: base,
                )),
                const SizedBox(height: 6),
                _pulse(
                    child: _skeletonBar(
                  width: double.infinity,
                  height: 12,
                  color: base,
                )),
                const SizedBox(height: 4),
                _pulse(
                    child: _skeletonBar(
                  width: width * widget.barFraction,
                  height: 12,
                  color: base,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulse({required Widget child}) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, c) => Opacity(opacity: _opacity.value, child: c),
      child: child,
    );
  }

  Widget _skeletonBar({
    required double width,
    required double height,
    required Color color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}


