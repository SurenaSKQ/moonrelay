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

import 'package:moonrelay/src/chat/events/date_separator.dart';
import 'package:moonrelay/src/chat/forward_message_dialog.dart';
import 'package:moonrelay/src/chat/state_event_tile.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/helpers/thread_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
    this.timelineVersion,
    this.onReply,
    this.onThread,
    this.showStateEvents = true,
    this.filterEvents,
  });

  final Timeline timeline;
  final Room room;
  final DisplayType displayType;
  final ScrollController scrollController;

  /// Font size for message text, propagated from [SettingsController]
  /// once at the top level instead of watched inside each item.
  final double fontSize;

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

  @override
  State<TimelineView> createState() => _TimelineViewState();
}

class _TimelineViewState extends State<TimelineView> {
  /// The event ID currently highlighted by a "jump to event" action, or
  /// null if nothing is highlighted.
  String? _highlightedEventId;

  /// Count of currently-visible encrypted events that can't be decrypted,
  /// exposed to the [_UndecryptableBanner] via [ValueListenable] so the
  /// banner reflects new arrivals without forcing a full item-list rebuild.
  final ValueNotifier<int> _undecryptableCount = ValueNotifier<int>(0);

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
  String get _cacheKey =>
      '${widget.timelineVersion}_${widget.fontSize}_${widget.displayType.index}_${widget.showStateEvents}_${widget.filterEvents.hashCode}';

  String _lastCacheKey = '';

  /// Invalidates all cached values so they are recomputed on the next build.
  void _invalidateCache() {
    _cachedItems = null;
    _cachedVisibleIndices = null;
    _cachedEventIdToItemIndex = null;
  }

  /// Counts encrypted events currently visible according to the active
  /// filter / state-event toggle.  Used to drive the
  /// [_UndecryptableBanner] so a new encrypted arrival bumps the badge
  /// without invalidating the full item-list cache.
  int _countUndecryptable() {
    final filter = widget.filterEvents;
    final count = <int, int>{};
    final events = widget.timeline.events;
    for (var idx = 0; idx < events.length; idx++) {
      final ev = events[idx];
      if (filter != null && !filter(ev)) continue;
      if (filter == null && !ThreadUtils.isVisibleInMainTimeline(ev)) continue;
      if (ev.type != EventTypes.Encrypted) continue;
      count[idx] = (count[idx] ?? 0) + 1;
    }
    return count.values.fold<int>(0, (a, b) => a + b);
  }

  @override
  void didUpdateWidget(TimelineView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newKey = _cacheKey;
    if (newKey != _lastCacheKey) {
      _invalidateCache();
    }
    // Recompute the undecryptable count on every prop change. The banner
    // listens to the ValueNotifier so an arriving encrypted event that
    // doesn't touch the cache key still produces a correct count as long
    // as the parent rebuilds this widget (which it does on every sync).
    _undecryptableCount.value = _countUndecryptable();
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
  bool _isContinuation(Event newer, Event older) {
    if (newer.senderId != older.senderId) return false;
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

        // Precompute thread reply data once instead of scanning
        // the timeline per-item on every build.
        final hasThread = ThreadUtils.hasThreadReplies(event, widget.timeline);
        final replyCount = hasThread
            ? ThreadUtils.threadReplyCount(event, widget.timeline)
            : 0;

        items.add(TimelineItem(
          event: event,
          room: widget.room,
          previousEvent:
              eventIndex >= 1 ? widget.timeline.events[eventIndex - 1] : null,
          displayType: widget.displayType,
          isGroupStart: !isContinuation,
          isGroupContinuation: isContinuation,
          timeline: widget.timeline,
          fontSize: widget.fontSize,
          threadReplyCount: replyCount,
          onReply: widget.onReply != null ? () => widget.onReply!(event) : null,
          onThread:
              widget.onThread != null ? () => widget.onThread!(event) : null,
          onForward: () => showForwardDialog(
            context: context,
            event: event,
            sourceRoom: widget.room,
          ),
          onJumpToEvent:
              _jumpToEvent(widget.scrollController, eventIdToItemIndex),
          highlightedEventId: _highlightedEventId,
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
    items.insert(0, const _UndecryptableBanner());

    _cachedItems = items;
    _cachedEventIdToItemIndex = eventIdToItemIndex;
    _lastCacheKey = _cacheKey;

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

    return ListView.builder(
      controller: widget.scrollController,
      reverse: true,
      itemCount: items.length,
      itemBuilder: (context, index) => items[index],
    );
  }

  /// Returns a callback that scrolls to a target event identified by
  /// [eventId].  Uses the [eventIdToItemIndex] map built during
  /// [_buildItemList] to find the item's list position, then animates
  /// the scroll controller to roughly that location.
  ///
  /// Because the ListView uses `reverse: true`, newer items are at the
  /// bottom (scroll offset 0) and older items are at the top (max scroll
  /// extent).  The offset is estimated proportionally, so the target may
  /// not be pixel-perfect, but will be close enough for the user to see it.
  void Function(String eventId) _jumpToEvent(
    ScrollController controller,
    Map<String, int> eventIdToItemIndex,
  ) {
    return (String eventId) {
      // Use the cached map if available (avoids passing the ephemeral
      // map through the closure on every rebuild).
      final map = _cachedEventIdToItemIndex ?? eventIdToItemIndex;
      final targetIdx = map[eventId];
      if (targetIdx == null) return;
      if (!controller.hasClients) return;

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

      final position = controller.position;
      final itemCount = eventIdToItemIndex.length;
      // Estimate position in the list. With reverse: true, item 0 is at
      // scroll offset 0 (bottom), and the last item is at maxScrollExtent.
      final range = position.maxScrollExtent - position.minScrollExtent;
      final fraction = itemCount > 1 ? targetIdx / (itemCount - 1) : 0.0;
      final targetOffset = position.minScrollExtent + range * fraction;

      // If the target is already roughly within viewport, skip scrolling
      // and just show the highlight.
      final distance = (targetOffset - position.pixels).abs();
      final viewportHeight = position.viewportDimension;
      if (distance < viewportHeight * 0.6) return;

      // Scroll so the target sits about one third from the top of the
      // viewport, preventing it from being hidden at the edge.
      final paddedOffset = (targetOffset - viewportHeight * 0.33).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );

      controller.animateTo(
        paddedOffset,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    };
  }
}

/// Banner shown at the bottom of the timeline when one or more messages
/// can't be decrypted (no session key, device not verified, etc.).
///
/// The [TimelineViewState] owns a [ValueNotifier] for the undecryptable
/// count and feeds it into this widget, so the count updates whenever a
/// new encrypted event arrives without a full timeline rebuild.
class _UndecryptableBanner extends StatelessWidget {
  const _UndecryptableBanner();

  @override
  Widget build(BuildContext context) {
    final _TimelineViewState? state =
        context.findAncestorStateOfType<_TimelineViewState>();
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final notifier = state?._undecryptableCount;
    if (notifier == null) return const SizedBox.shrink();

    return ValueListenableBuilder<int>(
      valueListenable: notifier,
      builder: (context, count, _) {
        if (count <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.tertiaryContainer.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: scheme.tertiary.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  LucideIcons.alertTriangle,
                  color: scheme.tertiary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.encryptionDecryptionFailed,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: scheme.onTertiaryContainer,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count == 1
                            ? '$count ${l10n.encryptionUndecryptableMessage}'
                            : '$count ${l10n.encryptionUndecryptableMessages}',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onTertiaryContainer.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
