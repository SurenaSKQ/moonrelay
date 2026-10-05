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
import 'package:moonrelay/src/chat/events/timeline_gap_marker.dart';
import 'package:moonrelay/src/chat/history_skeleton_tile.dart';
import 'package:moonrelay/src/chat/item_appearance.dart';
import 'package:moonrelay/src/chat/forward_message_dialog.dart';
import 'package:moonrelay/src/chat/state_event_tile.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/chat/timeline_model.dart';
import 'package:moonrelay/src/chat/timeline_scroll_target.dart';
import 'package:moonrelay/src/chat/undecryptable_banner.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/helpers/thread_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';

/// How long the jumped-to message stays ringed.
const Duration _kHighlightDuration = Duration(seconds: 2);

/// How long a jump travels when the target widget is already built.
const Duration _kJumpDuration = Duration(milliseconds: 280);

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
    required this.events,
    this.eventGroups,
    this.gapBoundaries,
    this.segmentTimelines,
    this.onGapApproach,
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

  /// The events to render, newest first, in SDK order.
  ///
  /// A plain list rather than a [Timeline], because the render list is
  /// decoupled from where the events come from. Today the parent passes
  /// `timeline.events`; with a `TimelineStore` in place it will pass
  /// `store.flatten()`, which spans the live tail and any number of detached
  /// history windows in one list. Nothing else in this widget needs to change
  /// when that swap happens, which is the whole point of the seam.
  ///
  /// Must be the same list identity across rebuilds when the contents have
  /// not changed, because [TimelineViewState._cacheKey] hashes it. The SDK
  /// mutates `chunk.events` in place rather than replacing it, so
  /// `timeline.events` satisfies that; `TimelineStore.flatten()` does not,
  /// which is why stage 5 pairs it with `store.version` instead.
  final List<Event> events;

  /// The live timeline, handed down to each [TimelineItem] for aggregation
  /// lookups (reactions, polls, thread membership).
  ///
  /// Deliberately *not* the render source. Those lookups are scoped to the
  /// live tail's `aggregatedEvents` map, and a detached history window has
  /// none of its own, so an item in a window falls back to the tail for
  /// aggregate data rather than showing nothing.
  final Timeline timeline;

  /// The events split by segment, newest group first, when the render list
  /// comes from more than one place.
  ///
  /// Optional because [events] remains the source of truth for what is
  /// rendered; this only adds the boundary information the model needs to
  /// place gap markers. When null the whole list is treated as one
  /// contiguous group, which is the live-tail-only case.
  final List<List<Event>>? eventGroups;

  /// Group indices after which a gap marker belongs.
  ///
  /// Only meaningful alongside [eventGroups], and supplied by whoever
  /// produced them: `TimelineStore.gapBoundaries()`. The view deliberately
  /// does not compute contiguity itself, because only the store knows which
  /// events came from which segment and why.
  final Set<int>? gapBoundaries;

  /// The timeline behind each group in [eventGroups].
  ///
  /// Each item is handed the timeline of the group it came from. Reactions,
  /// edits and reply resolution read `timeline.aggregatedEvents`, which is
  /// per-timeline, so handing a history-window item the live tail means it
  /// finds no aggregates for any event in the window and renders a message
  /// with no reactions and no edit history.
  ///
  /// Null falls back to the live [timeline] for every item, which is the
  /// single-segment case and the one direct widget tests exercise.
  final List<Timeline>? segmentTimelines;

  /// Called when the nearest gap comes within [gapPrefetchDistance] of the
  /// viewport, with the group index it follows and whether the viewer is on
  /// the newer side of that boundary.
  ///
  /// The timeline answers it by paging whichever of the two sides is towards
  /// the user, which is the only thing that fills the hole between a window
  /// and its neighbour. Nothing else loads into that space, so without this a
  /// drawn gap is permanent. Both directions are reachable: a viewer below the
  /// marker pages the newer side older, a viewer above it pages the older side
  /// newer, and the latter is what makes a jump to an old event, such as a
  /// search result, able to walk back down to the live tail.
  final void Function(int groupIndex, bool viewerOnNewerSide)? onGapApproach;

  /// How far above the fold a gap must come before [onGapApproach] fires.
  ///
  /// Roughly two messages. Close enough that the fetch has landed by the time
  /// the user scrolls into it, far enough that it does not fire the moment a
  /// window is added.
  static const double gapPrefetchDistance = 240;

  final Room room;
  final DisplayType displayType;
  final ScrollController scrollController;

  /// Font size for message text, propagated from [SettingsController]
  /// once at the top level instead of watched inside each item.
  final double fontSize;

  /// Corner radius for the message bubble in bubbles display mode.
  final double bubbleRadius;

  /// A [ValueListenable] that the parent bumps on every SDK sync callback
  /// (onChange/onInsert/onRemove/onUpdate) and on every history-window
  /// mutation.  When non-null, [TimelineView] rebuilds only the list
  /// subtree via [ValueListenableBuilder] instead of waiting for the
  /// parent to rebuild the entire chat surface.
  ///
  /// A merged notifier is accepted, which is what `ChatTimeline` passes:
  /// live sync bumps and store mutations are separate signals and either one
  /// changes what is rendered.
  ///
  /// When null (e.g. in widget tests that mount [TimelineView] directly),
  /// the list is built once per [build] call with no external listener.
  final Listenable? timelineVersion;

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

  /// One focus node per message row, so [_handleTimelineKey] can aim at them.
  ///
  /// Created lazily and disposed with the timeline, because a long-lived
  /// timeline holds as many of these as it has ever rendered.
  final Map<String, FocusNode> _rowFocusNodes = <String, FocusNode>{};

  /// Event ids in list order: index 0 is the newest, because the list is
  /// rendered under `reverse: true`.
  List<String> _orderedEventIds = const <String>[];

  /// The row the keyboard cursor last landed on, so a second arrow press
  /// continues from there rather than restarting.
  String? _lastFocusedEventId;

  /// Key on the scrollable itself, used to find the viewport's
  /// [RenderBox] when resolving the read position.  The per-event keys
  /// above only exist for *built* children, so something that covers
  /// the whole viewport is needed as the coordinate space.
  final GlobalKey _listKey = GlobalKey(debugLabel: 'chat_timeline_list');

  // ---------------------------------------------------------------------------
  // Cached computed values
  // ---------------------------------------------------------------------------

  /// Cached result of [_buildItemList], invalidated when the timeline version
  /// or any display-affecting prop changes.  This prevents O(n) rebuilds of
  /// the entire visible item list on every sync tick.
  List<Widget>? _cachedItems;

  /// Event id per index of [_cachedItems], or null for items that are
  /// not events (date separators, state batches, the undecryptable
  /// banner, gap markers).  Kept in step with [_cachedItems] so the
  /// read-position walk can map a rendered index back to an event without
  /// re-running the model.
  List<String?>? _cachedItemEventIds;

  /// Indices of [_cachedItems] holding a gap marker.
  ///
  /// The read-position walk treats these as a hard stop rather than
  /// skipping them. That is a deliberate difference from every other
  /// null-id entry: a separator or a state batch has events behind it on
  /// screen, whereas a gap means the messages above are *not* contiguous
  /// with the ones below. Continuing across would name an event the user
  /// has not scrolled past and retire messages they never saw, which is
  /// the failure the whole read-position work exists to prevent.
  final Set<int> _cachedGapIndices = <int>{};

  /// Gap entries by their index in [_cachedItems].
  ///
  /// Paired with [_cachedGapIndices] because the index says *where* the
  /// marker is and the entry says which group boundary it stands for.
  final Map<int, TimelineItemEntry> _cachedGapEntries =
      <int, TimelineItemEntry>{};

  /// Global keys for gap markers, by the group they follow.
  ///
  /// Keyed by group rather than by item index because the index shifts as
  /// either side of the boundary grows, and a key that changes when nothing
  /// about the marker has changed rebuilds it for nothing. A GlobalKey is
  /// required rather than a ValueKey because [nearestGap] needs to reach
  /// the marker's RenderBox to measure it, and only a GlobalKey can go
  /// from a key to a live context.
  final Map<int, GlobalKey> _gapKeys = <int, GlobalKey>{};

  /// Cached event-id-to-item-index map for jump-to-event.
  Map<String, int>? _cachedEventIdToItemIndex;

  /// The cache key computed from display-affecting props.  Embedding
  /// the *current* version value (read from the [ValueNotifier]) means
  /// the cache is invalidated when the parent bumps the version, and
  /// again when font size, display type, state-event visibility, or filter
  /// changes.
  ///
  /// The room and event-list identities are part of the key.  Both
  /// [ChatTimeline] and this widget hold stable `GlobalKey`s, so neither
  /// `State` dies on a room switch, and `_timelineVersion` is only ever
  /// incremented.  Without the identity components a new room could
  /// render the previous room's cached events until its first sync
  /// callback landed.  Identity rather than `room.id` because the question
  /// is "is this the same room object", and `identityHashCode` is the
  /// signal `chat_event.dart` already uses for its subtree cache.
  ///
  /// The event list, not the timeline, is what identifies the *contents*
  /// now.  They differ in a way that matters: the live tail keeps the same
  /// `Timeline` object across a history jump, so hashing it would miss a
  /// swap of the render list. `chunk.events` is mutated in place by the SDK
  /// rather than replaced, so hashing the list is stable while the contents
  /// are unchanged and changes when they are not.
  ///
  /// `highlightedEventId` is intentionally NOT part of the key: the
  /// highlight is applied per-item via [TimelineItem.highlightedEventId]
  /// and a highlight toggle doesn't require rebuilding the entire item
  /// list.
  String get _cacheKey {
    final version = _cacheVersion;
    return '${identityHashCode(widget.room)}'
        '_${identityHashCode(widget.events)}'
        '_$version'
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
    _cachedItemEventIds = null;
    _cachedGapIndices.clear();
    _cachedGapEntries.clear();
    _cachedEventIdToItemIndex = null;
  }

  /// Monotonic counter used in [_cacheKey] so a change in the parent
  /// notifier always invalidates, even though `timelineVersion` is a plain
  /// [Listenable] with no readable value.
  int _cacheVersion = 0;

  @override
  void initState() {
    super.initState();
    _lastCacheKey = _cacheKey;
    widget.timelineVersion?.addListener(_onVersionChanged);
    _undecryptableCount.value =
        countUndecryptable(widget.events, widget.filterEvents);
  }

  void _onVersionChanged() {
    _cacheVersion++;
    setState(_invalidateCache);
  }

  /// Reports a gap that has come close enough to the fold to be worth
  /// fetching. Called from [ChatTimeline]'s scroll handler rather than from
  /// here, so the fetch is owned by the timeline and the store, not the view.
  ///
  /// Fires at most once per gap identity so a long scroll does not queue one
  /// request per frame while the marker sits near the fold.
  void reportGapApproach() {
    final handler = widget.onGapApproach;
    if (handler == null) return;
    final gap = nearestGap;
    if (gap == null) return;
    if (gap.distance > TimelineView.gapPrefetchDistance) return;
    final token =
        '${gap.groupIndex}:${gap.distance.round()}:${gap.viewerOnNewerSide}';
    if (_reportedGaps.contains(token)) return;
    _reportedGaps.add(token);
    handler(gap.groupIndex, gap.viewerOnNewerSide);
  }

  final Set<String> _reportedGaps = <String>{};

  @override
  void didUpdateWidget(TimelineView oldWidget) {
    if (oldWidget.gapBoundaries != widget.gapBoundaries) {
      // The boundaries themselves changed, so a gap already reported for may
      // be gone. Clearing lets a genuinely new one fire.
      _reportedGaps.clear();
    }
    super.didUpdateWidget(oldWidget);
    if (oldWidget.timelineVersion != widget.timelineVersion) {
      oldWidget.timelineVersion?.removeListener(_onVersionChanged);
      widget.timelineVersion?.addListener(_onVersionChanged);
    }
    final newKey = _cacheKey;
    if (newKey != _lastCacheKey) {
      _invalidateCache();
    }
  }

  @override
void dispose() {
      widget.timelineVersion?.removeListener(_onVersionChanged);
      _undecryptableCount.dispose();
      // One node per message this timeline ever rendered. Long-lived rooms
      // make that thousands, and a `FocusNode` holds a listener closure that
      // references the row, so leaving them to the garbage collector means
      // leaking the row's state along with them.
      for (final node in _rowFocusNodes.values) {
        node.dispose();
      }
      _rowFocusNodes.clear();
      super.dispose();
    }

  // ---------------------------------------------------------------------------
  // Index helpers
  // ---------------------------------------------------------------------------

  /// The timeline for items from [groupIndex], falling back to the live tail.
  ///
  /// Null when there is only one segment, which is every direct widget test
  /// and the live-tail-only case.
  Timeline _timelineForGroup(int? groupIndex) {
    final segments = widget.segmentTimelines;
    if (segments == null || groupIndex == null) return widget.timeline;
    if (groupIndex < 0 || groupIndex >= segments.length) return widget.timeline;
    return segments[groupIndex];
  }

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
  // Read position
  // ---------------------------------------------------------------------------

  /// The id of the oldest event that is still at least partly visible in
  /// the viewport, or null when nothing measurable is on screen.
  ///
  /// This is the read position.  A read receipt has to name the event
  /// the user has actually reached, not the newest event in the cache:
  /// the previous implementation always sent the newest cached event,
  /// so opening a room or flicking upwards through history marked
  /// everything read (see WORK_NEEDED.md 8.2).
  ///
  /// Item heights are variable, so the position cannot be derived from
  /// the scroll offset arithmetically.  Instead this walks the built
  /// children in list order, which under `reverse: true` runs from the
  /// bottom of the screen upwards, and keeps the last entry that still
  /// intersects the viewport.
  String? get oldestVisibleEventId {
    final items = _cachedItems;
    final ids = _cachedItemEventIds;
    if (items == null || ids == null || items.isEmpty) return null;

    final listContext = _listKey.currentContext;
    if (listContext == null) return null;
    final viewportBox = listContext.findRenderObject();
    if (viewportBox is! RenderBox || !viewportBox.hasSize) return null;

    final limit = viewportBox.size.height;
    String? oldest;

    for (var i = 0; i < items.length && i < ids.length; i++) {
      // A gap stops the walk. Everything above it is non-contiguous with
      // what is below, so the user has not reached it by scrolling and
      // naming an event there would retire messages they never saw.
      if (_cachedGapIndices.contains(i)) break;

      final id = ids[i];
      if (id == null) continue;
      final key = items[i].key;
      if (key is! GlobalKey) continue;
      // Only *built* children have a context; unbuilt ones are off
      // screen in either direction, so skipping them is correct.
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;

      final top = box.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      if (top >= limit) {
        // Entirely below the fold.  Index order runs from the bottom of
        // the screen upward, so nothing further along can be visible.
        break;
      }
      final bottom = box
          .localToGlobal(Offset(0, box.size.height), ancestor: viewportBox)
          .dy;
      if (bottom <= 0) break; // Scrolled past the top.
      oldest = id;
    }

    return oldest;
  }

  /// The gap marker nearest the viewport, and the group boundary it stands for.
  ///
  /// Reported so the timeline can close the hole by paging that group's
  /// segment older. `distance` is how far outside the viewport the marker
  /// sits, and `0` when it is on screen, so a caller can prefetch before the
  /// user scrolls into it.
  ///
  /// Distance is absolute rather than signed because either side is
  /// reachable. The first version measured only upwards, on the reasoning
  /// that `reverse: true` puts older events higher up, which is true and
  /// irrelevant: a gap sitting just above the live edge is the one a user is
  /// closest to, and it was the case being missed.
  ///
  /// [viewerOnNewerSide] says which side of the marker the viewport centre
  /// sits on, so the caller can grow the segment the user is actually
  /// looking at. `reverse: true` means higher indices sit higher on screen,
  /// so content above the marker is the older group. A marker above the
  /// centre therefore leaves the reader sitting in the newer group below it,
  /// and a marker below the centre leaves them in the older group.
  ///
  /// The centre, not the nearest edge, because the viewport is usually
  /// mostly window after a jump to an old event and barely any tail; asking
  /// which side is *closest* would answer "window" for a reader who is in
  /// fact parked at the live edge.
  ({int groupIndex, double distance, bool viewerOnNewerSide})? get nearestGap {
    final items = _cachedItems;
    if (items == null || items.isEmpty) return null;
    final listContext = _listKey.currentContext;
    if (listContext == null) return null;
    final viewportBox = listContext.findRenderObject();
    if (viewportBox is! RenderBox || !viewportBox.hasSize) return null;

    ({int groupIndex, double distance, bool viewerOnNewerSide})? best;
    for (final index in _cachedGapIndices) {
      final groupIndex = _cachedGapEntries[index]?.afterGroup;
      if (groupIndex == null) continue;
      if (index >= items.length) continue;
      final key = _gapKeys[groupIndex];
      final box = key?.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
      final limit = viewportBox.size.height;
      final distance = top < 0 ? -top : (top > limit ? top - limit : 0.0);
      final candidate = (
        groupIndex: groupIndex,
        distance: distance,
        viewerOnNewerSide: top < limit / 2,
      );
      if (best == null || candidate.distance < best.distance) {
        best = candidate;
      }
    }
    return best;
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

    final result = buildTimelineItemsFromGroups(
      widget.eventGroups ?? [widget.events],
      gapsAfter: widget.gapBoundaries ?? const {},
      showStateEvents: widget.showStateEvents,
      filterEvents: widget.filterEvents,
    );

    final items = <Widget>[];
    final itemEventIds = <String?>[];
    final liveIds = <String>{};

    for (var indexOf = 0; indexOf < result.items.length; indexOf++) {
      final entry = result.items[indexOf];
      switch (entry.kind) {
        case TimelineItemKind.event:
          final ev = entry.event!;
          liveIds.add(ev.eventId);
          itemEventIds.add(ev.eventId);
          items.add(RepaintBoundary(
            key: _keyFor(ev.eventId),
            child: TimelineItem(
              event: ev,
              room: widget.room,
              displayType: widget.displayType,
              isGroupStart: entry.isGroupStart,
              isGroupContinuation: entry.isGroupContinuation,
              fontSize: widget.fontSize,
              bubbleRadius: widget.bubbleRadius,
              threadReplyCount: entry.replyCount,
              itemKey: _eventKeys[ev.eventId],
              focusNode: _rowFocusNodeFor(ev.eventId),
              // The group this event came from, so aggregate lookups hit
              // the timeline that actually holds them.
              timeline: _timelineForGroup(entry.groupIndex),
              onAction: (action, e) => _handleItemAction(action, e),
              onEdit: widget.onEdit != null ? () => widget.onEdit!(ev) : null,
              highlightedEventId:
                  widget.highlightedEventId ?? _highlightedEventId,
            ),
          ));

        case TimelineItemKind.dateSeparator:
          itemEventIds.add(null);
          items.add(DateSeparator(dateTime: entry.date!));

        case TimelineItemKind.stateEventBatch:
          itemEventIds.add(null);
          items.add(StateEventTile(events: entry.stateEvents!));

        case TimelineItemKind.undecryptableBanner:
          itemEventIds.add(null);
          items.add(const UndecryptableBanner());

        case TimelineItemKind.gap:
          itemEventIds.add(null);
          _cachedGapIndices.add(items.length);
          // Keep the entry, not just the index: the group it follows is
          // what a caller pages to close the hole, and it is not
          // recoverable from a rendered index.
          _cachedGapEntries[items.length] = entry;
          // Keyed by the group it follows, so [nearestGap] can reach a
          // RenderBox and measure the marker. An unkeyed child has nowhere
          // to hang a GlobalKey, and measuring the marker's distance to the
          // viewport is the whole point of it.
          final afterGroup = entry.afterGroup;
          items.add(
            TimelineGapMarker(
              key: afterGroup == null
                  ? null
                  : _gapKeys.putIfAbsent(
                      afterGroup,
                      () => GlobalKey(debugLabel: 'tl_gap_$afterGroup'),
                    ),
            ),
          );
      }
    }

    _cachedGapEntries.removeWhere(
      (index, _) => !_cachedGapIndices.contains(index),
    );
    _gapKeys.removeWhere(
      (group, _) => !_cachedGapEntries.values.any((e) => e.afterGroup == group),
    );

    _cachedItems = items;
    _cachedItemEventIds = itemEventIds;
    _cachedEventIdToItemIndex = result.eventIdToItemIndex;
    _lastCacheKey = _cacheKey;

    _undecryptableCount.value = result.undecryptableCount;
    _pruneStaleKeys(liveIds);

    // Recorded here rather than read from `_cachedItemEventIds` in the key
    // handler because that list is `List<String?>` (it carries a null per
    // non-message row) and the handler wants plain ids to look up in
    // `_rowFocusNodes`.
    _orderedEventIds = <String>[
      for (final id in itemEventIds)
        if (id != null) id,
    ];

    return items;
  }

  /// The row focus node for [eventId], created on first use.
  FocusNode _rowFocusNodeFor(String eventId) {
    return _rowFocusNodes.putIfAbsent(eventId, () {
      final node = FocusNode(debugLabel: 'row_$eventId', skipTraversal: true);
      // Remember where the keyboard cursor is, so the timeline can keep
      // walking from here and can decide which row a Tab arriving from the
      // composer should land on.
      node.addListener(() {
        if (node.hasFocus) _lastFocusedEventId = eventId;
      });
      return node;
    });
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
      list = AnimatedBuilder(
        animation: versionNotifier,
        builder: (context, _) => _buildListView(context),
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

    return Focus(
      // One focusable entry point for the whole timeline, rather than a Tab
      // stop per message. A viewport holds a couple of hundred messages, and
      // a `Focus` on each would put Tab's travel almost entirely inside the
      // conversation with no way out.
      autofocus: false,
      onKeyEvent: _handleTimelineKey,
      child: ListView.custom(
        key: _listKey,
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
      ),
    );
  }

  /// Moves the keyboard cursor between message rows.
  ///
  /// Only arrow keys are handled, and only once the cursor has been parked on
  /// a row, because Up and Down belong to whatever has focus otherwise: the
  /// composer, a scrollable, the command palette. Starting from
  /// [_lastFocusedEventId] rather than from "whatever is focused" is what
  /// lets a Tab that lands here go straight to the newest message instead of
  /// nowhere.
  ///
  /// Under `reverse: true` the newest item is index 0 and higher indices sit
  /// higher on screen, so "down" is towards the newer message and therefore
  /// towards the lower index.
  KeyEventResult _handleTimelineKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    if (!_isArrow(event.logicalKey)) return KeyEventResult.ignored;

    final ids = _orderedEventIds;
    if (ids.isEmpty) return KeyEventResult.ignored;

    final current = _lastFocusedEventId;
    final currentIndex = current == null ? -1 : ids.indexOf(current);
    // From nothing, ArrowDown goes to the newest message and ArrowUp to the
    // oldest currently built one, which is the opposite of what falling out
    // of the composer should do: you are reading the newest thing.
    final step = event.logicalKey == LogicalKeyboardKey.arrowDown ? 1 : -1;
    final nextIndex = currentIndex < 0
        ? (step > 0 ? 0 : ids.length - 1)
        : (currentIndex + step).clamp(0, ids.length - 1);
    if (nextIndex == currentIndex) return KeyEventResult.handled;

    final target = _rowFocusNodes[ids[nextIndex]];
    if (target == null) return KeyEventResult.ignored;
    if (target.context == null) {
      // The row for that id is not currently mounted. `_orderedEventIds` is
      // built from the model, which can be ahead of the viewport, so this is
      // reachable rather than theoretical.
      return KeyEventResult.ignored;
    }
    target.requestFocus();
    return KeyEventResult.handled;
  }

  static bool _isArrow(LogicalKeyboardKey key) =>
      key == LogicalKeyboardKey.arrowDown || key == LogicalKeyboardKey.arrowUp;

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

  /// True when [eventId] is present in the render list even though the item
  /// cache may not have caught up yet.
  bool _targetInLiveTimeline(String eventId) =>
      widget.events.any((e) => e.eventId == eventId);

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
    // The model's index map counts every rendered entry, the banner at
    // index 0 included, so [targetIdx] is already the item index and
    // [_cachedItems.length] is already the item count.
    //
    // This used to re-derive both by scanning [_cachedItems] for the
    // event's key, because the map was off by one whenever a banner was
    // present and omitted separators and state batches.  Two sources of
    // truth that disagreed by one; the model is now the only one.
    final idx = targetIdx;
    final itemCount = _cachedItems?.length ?? (idx + 1);
    final motion = Motion.of(context);

    // Skip the flash entirely when animations are off.  A highlight that
    // pulses is the definition of motion the user opted out of, and a jump
    // here can land thirty messages away.
    if (motion.enableAnimations) {
      setState(() => _highlightedEventId = eventId);
      Future.delayed(_kHighlightDuration, () {
        if (mounted) {
          setState(() {
            if (_highlightedEventId == eventId) {
              _highlightedEventId = null;
            }
          });
        }
      });
    }

    final globalKey = _eventKeys[eventId];
    final ctx = globalKey?.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.33,
        duration: motion.duration(_kJumpDuration),
        curve: motion.curve(Curves.easeInOutCubic),
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
      duration: motion.duration(_kJumpDuration),
      curve: motion.curve(Curves.easeInOutCubic),
    );
  }

  /// Single dispatch for every [TimelineItemAction].  Centralises the
  /// routing so each [TimelineItem] can hand the view a single stable
  /// callback closure (keeping the Element tree reusable across rebuilds).
  ///
  /// This used to take the model's index map and never read it. Every
  /// action routes off the [Event] it was handed, so the parameter was a
  /// reminder that the map existed at a call site that did not need it.
  void _handleItemAction(
    TimelineItemAction action,
    Event event,
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
