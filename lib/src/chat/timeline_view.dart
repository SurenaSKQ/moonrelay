// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:moonrelay/src/chat/animated_history_skeleton.dart';
import 'package:moonrelay/src/chat/events/date_separator.dart';
import 'package:moonrelay/src/chat/history_skeleton_tile.dart';
import 'package:moonrelay/src/chat/item_appearance.dart';
import 'package:moonrelay/src/chat/forward_message_dialog.dart';
import 'package:moonrelay/src/chat/state_event_tile.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/chat/timeline_model.dart';
import 'package:moonrelay/src/chat/timeline_scroll_target.dart';
import 'package:moonrelay/src/chat/undecryptable_banner.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/helpers/thread_utils.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

/// Renders the list of timeline events with event-type filtering, sender
/// grouping, and date separators.
///
/// The Matrix SDK stores [Timeline.events] in newest-first order
/// (`events[0]` is the most recent).  We render them with
/// `ListView.builder(reverse: true)` so that the newest event sits at the
/// bottom of the viewport and older events are reached by scrolling up.
///
/// ## Event filtering
///
/// Events with a non-null [relationshipEventId] (replies, reactions, edits,
/// thread replies) are excluded from the visible list because they are rendered
/// inline with their parent event.  Thread roots (events whose relationship
/// type is `m.thread` and that reference themselves) are kept visible because
/// they are the start of a thread and appear as regular messages.
///
/// ## Rebuild efficiency
///
/// The parent ([ChatTimeline]) passes a [ValueNotifier<int>] via
/// [timelineVersion] that is bumped on every SDK sync callback.
/// [TimelineView] listens to that notifier with a [ValueListenableBuilder]
/// so only the list subtree rebuilds on data changes -- unrelated parent
/// rebuilds (settings, theme, floating-action column) do not invalidate
/// the cached item list.
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
    this.onEdit,
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

  /// A [ValueNotifier] that the parent bumps on every SDK sync callback
  /// (onChange/onInsert/onRemove/onUpdate).  When non-null, [TimelineView]
  /// rebuilds only the list subtree via [ValueListenableBuilder] instead
  /// of waiting for the parent to rebuild the entire chat surface.
  ///
  /// When null (e.g. in widget tests that mount [TimelineView] directly),
  /// the list is built once per [build] call with no external listener.
  final ValueNotifier<int>? timelineVersion;

  /// Called when the user replies to a specific event.
  final void Function(Event event)? onReply;

  /// Called when the user wants to open or create a thread for an event.
  final void Function(Event event)? onThread;

  /// Called when the user wants to edit a specific event inline.
  final void Function(Event event)? onEdit;

  /// Whether to render state events (join/leave/room metadata changes).
  /// When false, state events are hidden from the timeline.
  final bool showStateEvents;

  /// When non-null, overrides the default visibility filter.  The function
  /// receives each event and should return `true` to make it visible.
  /// When null, [ThreadUtils.isVisibleInMainTimeline] is used.
  final bool Function(Event)? filterEvents;

  /// When `true`, the list appends a small block of skeleton placeholders
  /// at the *top* of the item list (which, with `reverse: true`, appears
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
  /// [BuildContext] for any event currently on screen.
  final Map<String, GlobalKey> _eventKeys = <String, GlobalKey>{};

  // ---------------------------------------------------------------------------
  // Cached computed values
  // ---------------------------------------------------------------------------

  /// Cached result of [_buildItemList], invalidated when the timeline version
  /// or any display-affecting prop changes.  This prevents O(n) rebuilds of
  /// the entire visible item list on every sync tick.
  List<Widget>? _cachedItems;

  /// Cached event-id-to-item-index map for jump-to-event.
  Map<String, int>? _cachedEventIdToItemIndex;

  /// The cache key computed from display-affecting props.  Embedding
  /// the *current* version value (read from the [ValueNotifier]) means
  /// the cache is invalidated when the parent bumps the version, and
  /// again when font size, display type, state-event visibility, or filter
  /// changes.
  ///
  /// `highlightedEventId` is intentionally NOT part of the key: the
  /// highlight is applied per-item via [TimelineItem.highlightedEventId]
  /// and a highlight toggle doesn't require rebuilding the entire item
  /// list.
  String get _cacheKey {
    final version = widget.timelineVersion?.value ?? 0;
    return '$version'
        '_${widget.fontSize}'
        '_${widget.displayType.index}'
        '_${widget.showStateEvents}'
        '_${widget.filterEvents.hashCode}'
        '_${widget.isLoadingHistory}';
  }

  String _lastCacheKey = '';

  /// Invalidates all cached values so they are recomputed on the next build.
  void _invalidateCache() {
    _cachedItems = null;
    _cachedEventIdToItemIndex = null;
  }

  @override
  void initState() {
    super.initState();
    _lastCacheKey = _cacheKey;
    _undecryptableCount.value =
        countUndecryptable(widget.timeline.events, widget.filterEvents);
  }

  @override
  void didUpdateWidget(TimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = _cacheKey;
    if (newKey != _lastCacheKey) {
      _invalidateCache();
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

  /// Returns (and lazily creates) the stable [GlobalKey] for [eventId].
  GlobalKey _keyFor(String eventId) {
    return _eventKeys.putIfAbsent(
        eventId, () => GlobalKey(debugLabel: 'tl_$eventId'));
  }

  /// Drops entries from [_eventKeys] whose events are no longer
  /// referenced by the freshly-built cache.  Keeps the map bounded
  /// over long-lived views.
  void _pruneStaleKeys(Set<String> liveIds) {
    _eventKeys.removeWhere((id, _) => !liveIds.contains(id));
  }

  // ---------------------------------------------------------------------------
  // Build the flat item list (delegates ordering/logic to the model)
  // ---------------------------------------------------------------------------

  /// Produces the list of widgets in newest-first order so that the
  /// `reverse: true` ListView places the newest item at the bottom.
  ///
  /// Delegates grouping, ordering, and state-event classification to
  /// [buildTimelineItems] in `timeline_model.dart`, then maps each
  /// [TimelineItemEntry] to a concrete widget ([TimelineItem],
  /// [DateSeparator], [StateEventTile], [UndecryptableBanner]).
  List<Widget> _buildItemList(BuildContext context) {
    final key = _cacheKey;
    if (key != _lastCacheKey) {
      _invalidateCache();
      _lastCacheKey = key;
    }
    if (_cachedItems != null) return _cachedItems!;

    final result = buildTimelineItems(
      widget.timeline,
      showStateEvents: widget.showStateEvents,
      filterEvents: widget.filterEvents,
    );

    final items = <Widget>[];
    final liveIds = <String>{};

    for (final entry in result.items) {
      switch (entry.kind) {
        case TimelineItemKind.event:
          final ev = entry.event!;
          liveIds.add(ev.eventId);
          items.add(RepaintBoundary(
            key: _keyFor(ev.eventId),
            child: TimelineItem(
              event: ev,
              room: widget.room,
              displayType: widget.displayType,
              isGroupStart: entry.isGroupStart,
              isGroupContinuation: entry.isGroupContinuation,
              timeline: widget.timeline,
              fontSize: widget.fontSize,
              bubbleRadius: widget.bubbleRadius,
              threadReplyCount: entry.replyCount,
              itemKey: _eventKeys[ev.eventId],
              onAction: (action, e) =>
                  _handleItemAction(action, e, result.eventIdToItemIndex),
              onEdit: widget.onEdit != null
                  ? () => widget.onEdit!(ev)
                  : null,
              highlightedEventId:
                  widget.highlightedEventId ?? _highlightedEventId,
            ),
          ));

        case TimelineItemKind.dateSeparator:
          items.add(DateSeparator(dateTime: entry.date!));

        case TimelineItemKind.stateEventBatch:
          items.add(StateEventTile(events: entry.stateEvents!));

        case TimelineItemKind.undecryptableBanner:
          items.add(const UndecryptableBanner());
      }
    }

    _cachedItems = items;
    _cachedEventIdToItemIndex = result.eventIdToItemIndex;
    _lastCacheKey = _cacheKey;

    _undecryptableCount.value = result.undecryptableCount;
    _pruneStaleKeys(liveIds);

    return items;
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final versionNotifier = widget.timelineVersion;

    // When the parent provides a [ValueNotifier] for timeline updates,
    // wrap the list in a [ValueListenableBuilder] so only the list
    // subtree rebuilds on data-change, not the entire chat surface.
    // When null (direct widget tests), build directly.
    Widget list;
    if (versionNotifier == null) {
      list = _buildListView(context);
    } else {
      list = ValueListenableBuilder<int>(
        valueListenable: versionNotifier,
        builder: (context, _, __) => _buildListView(context),
      );
    }
    return list;
  }

  Widget _buildListView(BuildContext context) {
    final items = _buildItemList(context);

    final hasMore = widget.isLoadingHistory;
    final extra = hasMore ? _buildHistoryLoadingSkeletons() : <Widget>[];

    // `findChildIndexCallback` needs a Key -> index map so a caller
    // can resolve a [GlobalKey] back to a sliver index in O(1).
    final Map<Key, int> keyToIndex = <Key, int>{
      for (var i = 0; i < items.length; i++)
        if (items[i].key != null) items[i].key!: i,
    };
    const skeletonKey = ValueKey<String>('tl_skeleton');

    return ListView.custom(
      controller: widget.scrollController,
      reverse: true,
      childrenDelegate: SliverChildBuilderDelegate(
        _buildItemAt(items, hasMore, extra),
        childCount: items.length + 1,
        findChildIndexCallback: (Key key) {
          if (key == skeletonKey) return items.length;
          return keyToIndex[key];
        },
        addRepaintBoundaries: false,
        addAutomaticKeepAlives: false,
      ),
    );
  }



  /// Builds the per-index builder used by [ListView.custom].
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
      // Animate items that just got paginated in.  The item list is
      // newest-first, so freshly-fetched history lands at the *tail*
      // (highest indices, top of the viewport under `reverse: true`).
      final isNewestHistory = hasMore && index >= items.length - 4;
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
  /// indices.  Items have variable heights, so a fraction estimate
  /// routinely landed the user a few items away from the target.  Using
  /// the actual [BuildContext] of the on-screen item makes the jump
  /// pixel-accurate: when the item is visible, we ask
  /// [Scrollable.ensureVisible] for the exact pixel offset; when it
  /// isn't, we fall back to the fraction-based heuristic so
  /// paginated-off-screen targets still scroll in the right direction.
  ///
  /// [ListView.custom]'s [SliverChildBuilderDelegate.findChildIndexCallback]
  /// lets external callers resolve an event id to its sliver index in O(1),
  /// bypassing this callback entirely when the target has been built.
  void _scrollToEventId(String eventId) {
    final controller = widget.scrollController;
    if (!controller.hasClients) return;
    if (!controller.position.haveDimensions) return;

    final cached = _cachedEventIdToItemIndex;
    final targetIdx = cached?[eventId];
    if (targetIdx == null && _targetInLiveTimeline(eventId)) {
      // The item cache predates a pagination that just surfaced the
      // target: the jump-to-unread coordinator scrolls in the same
      // microtask turn that `requestHistory` lands, one frame before
      // `_timelineVersion` triggers this view's rebuild.  Force the
      // cache to rebuild now and resume the scroll on the next frame,
      // so both the index map and the scroll extents are fresh.
      _refreshJumpCacheAndScroll(eventId);
      return;
    }
    if (targetIdx == null) return;

    _doScrollToEvent(eventId, controller, targetIdx);
  }

  /// True when [eventId] is present in the live timeline even though
  /// the item cache may not have caught up yet.
  bool _targetInLiveTimeline(String eventId) =>
      widget.timeline.events.any((e) => e.eventId == eventId);

  /// True while a stale-cache scroll refresh is in flight.  Guards the
  /// post-frame retry so a target that legitimately isn't rendered
  /// (e.g. a relationship event in a filtered view) doesn't loop.
  bool _refreshingJumpCache = false;

  void _refreshJumpCacheAndScroll(String eventId) {
    if (_refreshingJumpCache) return;
    _refreshingJumpCache = true;
    setState(() => _invalidateCache());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshingJumpCache = false;
      if (mounted) _scrollToEventId(eventId);
    });
  }

  void _doScrollToEvent(
    String eventId,
    ScrollController controller,
    int targetIdx,
  ) {
    // The model's index map is built before the undecryptable banner is
    // prepended and counts only message events, so its indices can be off
    // by one and it omits date separators and state batches.  Re-derive
    // the rendered item index and total item count so the fallback
    // fraction below lands accurately.
    var idx = targetIdx;
    final items = _cachedItems;
    final key = _eventKeys[eventId];
    if (items != null && items.isNotEmpty && key != null) {
      final renderedIdx = items.indexWhere((w) => w.key == key);
      if (renderedIdx >= 0) idx = renderedIdx;
    }
    final itemCount = items?.length ?? (idx + 1);

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

    // A user-invoked jump must always move the view.  The fraction
    // estimate is only a rough guide when the target item isn't built
    // yet, so `skipIfClose` (which silently drops the scroll when the
    // estimate lands within 60% of the viewport) left the view
    // motionless while the pill dismissed and the room was marked read.
    TimelineScrollTarget.scrollToFraction(
      controller,
      idx,
      itemCount,
      skipIfClose: false,
    );
  }

  /// Single dispatch for every [TimelineItemAction].  Centralises the
  /// routing so each [TimelineItem] can hand the view a single stable
  /// callback closure (keeping the Element tree reusable across rebuilds).
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
  /// event id without owning the [GlobalKey] map directly.
  void scrollToEventId(String eventId) => _scrollToEventId(eventId);
}
