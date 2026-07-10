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

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/chat/forward_message_dialog.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/pinned_events_cache.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// Orchestrates the chat timeline lifecycle.
///
/// Creates the [Timeline] via the Matrix SDK, manages scroll-to-load-history
/// with auto-fill for short content, and delegates rendering to [TimelineView].
///
/// ## Scroll loading
///
/// With `reverse: true` on the ListView, the scroll position is 0 at the
/// bottom (newest messages) and reaches [maxScrollExtent] at the top (oldest
/// messages).  History is loaded whenever the user scrolls within 150 px of
/// the top.
///
/// ## Auto-fill
///
/// If the initially loaded content does not fill the viewport (no scrollbar),
/// history is fetched repeatedly until the viewport is full or the server
/// returns no more events.  This ensures the user can always scroll up to
/// trigger manual pagination.
///
/// ## Stability
///
/// A shared [scaffold] / debounce mechanism prevents cascading history loads.
/// When a load completes, layout-induced scroll notifications are suppressed
/// for two frames while the list stabilises, stopping the "load → layout
/// change → scroll event → load" feedback loop that would otherwise overflow.
class ChatTimeline extends StatefulWidget {
  const ChatTimeline(
      {super.key,
      required this.room,
      this.onReply,
      this.onThread,
      this.filterEvents});

  final Room room;

  /// Called when the user wants to reply to a specific timeline event.
  final void Function(Event event)? onReply;

  /// Called when the user wants to open or create a thread for an event.
  final void Function(Event event)? onThread;

  /// When non-null, passed through to [TimelineView.filterEvents] to
  /// override the default event visibility filter.
  final bool Function(Event)? filterEvents;

  @override
  State<ChatTimeline> createState() => ChatTimelineState();
}

class ChatTimelineState extends State<ChatTimeline> {
  /// The resolved Timeline, or null while still initialising.
  Timeline? _timeline;

  final ScrollController _scrollController = ScrollController();

  /// True while a [requestHistory] call is in flight.
  bool _isLoadingHistory = false;

  /// True while the auto-fill loop is running.
  bool _isFillingViewport = false;

  /// Temporarily suppresses [_onScroll] after a successful history load so
  /// that layout-induced scroll notifications don't trigger another request
  /// before the user has had a chance to scroll manually.
  bool _scrollDebounce = false;

  /// How many consecutive auto-fill requests have been issued without the
  /// viewport becoming scrollable.  Caps the retry loop when the server
  /// returns no more history.
  int _autoFillRetries = 0;
  static const int _maxAutoFillRetries = 5;

  /// Trigger distance (logical pixels) from the top of the list.
  static const double _scrollThreshold = 150.0;

  /// Public accessor for the scroll controller, exposed so callers
  /// outside this widget (e.g. the in-room search panel) can request
  /// a jump to a specific event after we've already built the timeline.
  ScrollController get scrollController => _scrollController;

  int _timelineVersion = 0;

  /// True when [_initTimeline] finished with a permanent error.
  bool _timelineLoadFailed = false;

  /// Events explicitly fetched for the pinned filter (fetched by ID from
  /// the server when they aren't in the local timeline batch).
  List<Event>? _fetchedFilteredEvents;

  /// True while [fetchFilteredEvents] is in flight.
  bool _isFetchingFilteredEvents = false;

  @override
  void initState() {
    super.initState();
    _initTimeline();
  }

  @override
  void didUpdateWidget(ChatTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterEvents != null && oldWidget.filterEvents == null) {
      _fetchFilteredEvents();
    } else if (widget.filterEvents == null &&
        oldWidget.filterEvents != null) {
      if (_fetchedFilteredEvents != null) {
        setState(() => _fetchedFilteredEvents = null);
      }
    }
  }

  Future<void> _initTimeline() async {
    final log = context.read<Logger>();

    final result = await withRetry(
      () => widget.room.getTimeline(
        onChange: (_) => _onTimelineUpdate(),
        onInsert: (_) => _onTimelineUpdate(),
        onRemove: (_) => _onTimelineUpdate(),
        onUpdate: () {},
      ),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'getTimeline(${widget.room.id})',
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        {
          setState(() => _timeline = value);
          _scrollController.addListener(_onScroll);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _ensureContentFillsScreen();
          });
          // Mark the latest event as read.
          _markRoomRead();
        }
      case RetryFailed(:final error):
        {
          log.e('Failed to load timeline for ${widget.room.id}', error: error);
          _timelineLoadFailed = true;
          setState(() {});
        }
    }
  }

  // ---------------------------------------------------------------------------
  // Shared history-loading
  // ---------------------------------------------------------------------------

  /// Requests more history from the server and debounces subsequent
  /// scroll-triggered loads so that layout reflow doesn't create a loop.
  Future<void> _requestMoreHistory() async {
    if (_timeline == null) return;
    final Logger log = context.read<Logger>();
    _isLoadingHistory = true;
    _scrollDebounce = true;

    try {
      await withTimeout(
        () => _timeline!.requestHistory(),
        timeout: kDefaultTimeout,
      );
    } catch (e) {
      log.w('History request failed for ${widget.room.id}', error: e);
    }

    if (!mounted) return;
    _isLoadingHistory = false;
    // Let the list lay out, then release the debounce two frames later
    // to skip any layout-caused scroll events.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _scrollDebounce = false);
      });
    });
    // Release the auto-fill guard so that _ensureContentFillsScreen
    // can re-evaluate whether the viewport is full.
    _isFillingViewport = false;
    // Also re-check auto-fill after this load finishes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _ensureContentFillsScreen();
    });
  }

  // ---------------------------------------------------------------------------
  // Scroll-to-load history
  // ---------------------------------------------------------------------------

  /// Called on every scroll event.  Loads more history when the user scrolls
  /// near the top of the timeline (oldest messages).
  ///
  /// The ListView uses `reverse: true`, so:
  /// - `pixels == 0` → bottom of the list (newest messages)
  /// - `pixels >= maxScrollExtent - threshold` → near the top (oldest)
  void _onScroll() {
    if (!_scrollController.hasClients) return;
    if (_isLoadingHistory) return;
    if (_scrollDebounce) return;
    if (_isFillingViewport) return;

    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - _scrollThreshold) {
      _requestMoreHistory();
    }
  }

  // ---------------------------------------------------------------------------
  // Jump-to-last-seen
  // ---------------------------------------------------------------------------

  /// True when the user has unread messages in this room that are
  /// below the current viewport bottom.  Used to surface a "Jump to
  /// first unread" pill at the bottom of the chat area.
  bool get _hasUnreadBelow =>
      _lastSeenEventId.isNotEmpty && widget.room.notificationCount > 0;

  /// The event ID the user has last read up to.  Pulled from the SDK
  /// (`m.fully_read` account data) at load time and on every sync.
  String _lastSeenEventId = '';

  /// Refreshes [_lastSeenEventId] from room account data. Safe to call
  /// repeatedly — only sets state when the value changed.
  void _refreshLastSeenMarker() {
    final next = widget.room.fullyRead;
    if (next != _lastSeenEventId) {
      setState(() => _lastSeenEventId = next);
    }
  }

  /// Scrolls the timeline to the first unread event.  If the unread
  /// event isn't yet loaded from the server the timeline is mass-
  /// paginated forward in 20-event chunks until it appears, then the
  /// scroll lands on it.
  ///
  /// When all unread events are already in the local cache we jump
  /// straight to the oldest one above [Room.fullyRead] and briefly
  /// highlight it.  This keeps the user oriented in long-running rooms
  /// without forcing them to scroll past thousands of events they
  /// have already seen.
  Future<void> jumpToLastRead() async {
    final timeline = _timeline;
    if (timeline == null) return;

    // Pull the live marker — `widget.room.fullyRead` is updated by the
    // SDK whenever sync delivers new account data, but the cached
    // value in [_lastSeenEventId] may lag a sync.
    final targetId = widget.room.fullyRead;
    if (targetId.isEmpty) {
      _scrollToBottom();
      return;
    }

    // The fully-read marker is *exclusive* of unread: the user has
    // read up to it, so the first unread event is the one immediately
    // **after** it in the timeline (newest-first order).
    final events = timeline.events;
    var foundIndex = -1;
    for (var i = 0; i < events.length; i++) {
      if (events[i].eventId == targetId) {
        foundIndex = i + 1;
        break;
      }
    }

    if (foundIndex == -1 || foundIndex >= events.length) {
      // Marker is older than the loaded window, OR the next event
      // hasn't loaded yet — paginate forward until we find something
      // unread we can land on, or until the server says we're done.
      await _paginateUntilUnread(targetId);
      _refreshLastSeenMarker();
      _scrollToFirstUnreadHighlight(targetId);
      return;
    }

    _scrollToFirstUnreadHighlight(targetId);
  }

  /// Pages the timeline forward in 20-event chunks until an event
  /// newer than [fullyReadEventId] is loaded, or until the server
  /// stops returning more history.  Bounded to a small number of
  /// iterations so a stalled server doesn't trap the user.
  Future<void> _paginateUntilUnread(String fullyReadEventId) async {
    final timeline = _timeline;
    if (timeline == null) return;
    final log = context.read<Logger>();
    const maxIterations = 50;
    for (var i = 0; i < maxIterations; i++) {
      if (!mounted) return;
      final before = timeline.events.length;
      // We page *backward* (older history) because newer events are at
      // index 0; the unread events we want are at the *top* of the
      // list once we reach `fullyReadEventId`.
      try {
        await withTimeout(
          () => timeline.requestHistory(),
          timeout: const Duration(seconds: 10),
        );
      } catch (e) {
        log.w('jumpToLastRead: history request failed', error: e);
        return;
      }
      if (!mounted) return;
      final after = timeline.events.length;
      // Found the marker — we're done.
      if (timeline.events.any((e) => e.eventId == fullyReadEventId)) {
        return;
      }
      // Server returned no new events.
      if (after == before) return;
    }
  }

  /// Scrolls the timeline so the first unread event (the one right
  /// after [fullyReadEventId] in newest-first order) sits roughly
  /// one third from the top of the viewport, with a brief highlight
  /// ring.
  void _scrollToFirstUnreadHighlight(String fullyReadEventId) {
    final timeline = _timeline;
    if (timeline == null) return;
    if (!_scrollController.hasClients) return;

    final events = timeline.events;
    var foundIdx = 0;
    for (var i = 0; i < events.length; i++) {
      if (events[i].eventId == fullyReadEventId) {
        foundIdx = (i - 1).clamp(0, events.length - 1);
        break;
      }
    }
    final targetEvent = events[foundIdx];
    final targetId = targetEvent.eventId;

    // Mark so the timeline item can render its highlight ring.
    _highlightedEventId = targetId;
    setState(() {});
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;
      if (_highlightedEventId == targetId) {
        setState(() => _highlightedEventId = null);
      }
    });

    // Estimate the item's position from the scrollable's visible area.
    final pos = _scrollController.position;
    final range = pos.maxScrollExtent - pos.minScrollExtent;
    // Newest items live at the bottom (offset 0) in this reversed list,
    // so a smaller index into `events` corresponds to a smaller scroll
    // offset.  We just animate to the top — the unread events are
    // typically the *oldest* unread ones in the loaded window.
    final fraction = foundIdx == 0
        ? 0.0
        : 1.0 - (foundIdx / (events.length > 1 ? events.length - 1 : 1));
    final targetOffset =
        (pos.minScrollExtent + range * fraction)
            .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    final distance = (targetOffset - pos.pixels).abs();
    if (distance < pos.viewportDimension * 0.6) return;
    _scrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Plain bottom-scroll helper used when we don't have a marker to
  /// jump to.  Useful for tests and as a catch-all fallback.
  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  /// Event ID currently highlighted by the "Jump to unread" affordance.
  /// Mirrors the value the timeline view uses for in-room search jumps.
  String? _highlightedEventId;

  // ---------------------------------------------------------------------------
  // Auto-fill viewport
  // ---------------------------------------------------------------------------

  /// If the current content does not overflow the viewport (i.e. no scrollbar
  /// is visible), requests more history until either the viewport is filled or
  /// no more events are available from the server.
  void _ensureContentFillsScreen() {
    if (!mounted) return;
    if (_isFillingViewport) return;
    if (_isLoadingHistory) return;
    if (_timeline == null) return;

    if (!_scrollController.hasClients) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _ensureContentFillsScreen());
      return;
    }

    if (_autoFillRetries >= _maxAutoFillRetries) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    // Still too short -> request more.
    if (maxScroll <= 50.0) {
      _autoFillRetries++;
      _isFillingViewport = true;
      _requestMoreHistory();
    } else {
      _isFillingViewport = false;
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  /// Fetches events that pass the active filter by their event IDs.
  ///
  /// When the pinned-only filter is active, the regular timeline may not
  /// contain the pinned events (they may be outside the loaded window).
  /// This method reads the pinned event IDs from room state and fetches
  /// each event via [PinnedEventsCache], which dedupes concurrent requests
  /// and avoids round-trips for events already known to the cache.
  Future<void> _fetchFilteredEvents() async {
    if (_isFetchingFilteredEvents) return;
    _isFetchingFilteredEvents = true;

    if (!mounted) return;
    setState(() => _fetchedFilteredEvents = null);

    try {
      final state = widget.room.getState('m.room.pinned_events');
      final pinnedList = state?.content['pinned'];
      final pinnedIds =
          pinnedList is List ? pinnedList.cast<String>() : <String>[];

      if (pinnedIds.isEmpty) {
        _isFetchingFilteredEvents = false;
        if (mounted) setState(() => _fetchedFilteredEvents = []);
        return;
      }

      // Fetch via the shared cache. Concurrent calls for the same event ID
      // share a single in-flight future, and already-cached events return
      // immediately — so 50 pinned IDs in a fresh room are fetched in
      // parallel rather than 50 sequential awaits.
      final events = await Future.wait(
        pinnedIds.map(
          (id) => PinnedEventsCache.instance.getEvent(widget.room, id),
        ),
      );
      final resolved = events.whereType<Event>().toList();

      // Sort oldest-first so the reversed ListView places the newest at
      // the bottom.
      resolved.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));

      if (!mounted) return;
      setState(() => _fetchedFilteredEvents = resolved);
    } finally {
      _isFetchingFilteredEvents = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Reset auto-fill counter when content becomes scrollable.
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 50.0) {
      _autoFillRetries = 0;
    }

    // Keep the fully-read marker fresh — the SDK updates
    // `Room.fullyRead` on every sync, so we just sample it on rebuild.
    _refreshLastSeenMarker();

    return Consumer<SettingsController>(
      builder: (context, settings, _) {
        if (_timeline == null) {
          if (_timelineLoadFailed) {
            return _buildError(context);
          }
          // Still loading – sync indicator in ChatRoomHeader handles the
          // visual feedback, so we just show an empty container.
          return const SizedBox.shrink();
        }

        final child = _buildTimelineContent(context, settings);

        // When there are unread events below the current viewport,
        // overlay a "Jump to first unread" pill so the user can
        // quickly catch up after returning to the app.
        if (_hasUnreadBelow) {
          return Stack(
            children: [
              child,
              Positioned(
                left: 0,
                right: 0,
                bottom: 12,
                child: SafeArea(
                  top: false,
                  child: Center(
                    child: _JumpToUnreadPill(
                      count: widget.room.notificationCount,
                      onTap: () async {
                        await jumpToLastRead();
                        if (!mounted) return;
                        // `_markRoomRead` returns void; the SDK call
                        // inside is fire-and-forget.  We still await
                        // `jumpToLastRead` so the scroll lands before
                        // the user notices the badge clearing.
                        _markRoomRead();
                      },
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        return child;
      },
    );
  }

  Widget _buildTimelineContent(
    BuildContext context,
    SettingsController settings,
  ) {
    // When a filter is active and we've explicitly fetched the matching
    // events, render those instead of the regular timeline view (which
    // would show nothing if the target events aren't in the loaded batch).
    if (widget.filterEvents != null) {
      if (_fetchedFilteredEvents != null) {
        if (_fetchedFilteredEvents!.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.push_pin_outlined,
                  size: 40,
                  color: Theme.of(context)
                      .colorScheme
                      .onSurfaceVariant
                      .withValues(alpha: 0.4),
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.noPinnedMessages,
                  style: TextStyle(
                    color:
                        Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return _PinnedEventsList(
          events: _fetchedFilteredEvents!,
          room: widget.room,
          displayType: settings.displayType,
          fontSize: settings.fontSize,
          scrollController: _scrollController,
          onReply: widget.onReply,
          onThread: widget.onThread,
          onForward: (event) => showForwardDialog(
            context: context,
            event: event,
            sourceRoom: widget.room,
          ),
        );
      }

      // Still fetching...
      return const Center(child: CircularProgressIndicator());
    }

    return TimelineView(
      timeline: _timeline!,
      room: widget.room,
      displayType: settings.displayType,
      fontSize: settings.fontSize,
      scrollController: _scrollController,
      timelineVersion: _timelineVersion,
      onReply: widget.onReply,
      onThread: widget.onThread,
      showStateEvents: settings.showStateEvents,
      filterEvents: widget.filterEvents,
      // Show skeleton placeholders at the top of the viewport while
      // the user is scrolling up and the SDK is paginating older
      // history.  This avoids the abrupt "scroll hits a wall" feel
      // and tells the user more messages are on the way.
      isLoadingHistory: _isLoadingHistory || _isFillingViewport,
    );
  }

  Widget _buildError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.alertCircle,
              size: 48,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.couldNotLoadMessages,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.serverMayBeUnreachable,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Icon(
              LucideIcons.shield,
              size: 24,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.encryptionVerifyDevice,
              style: TextStyle(
                fontSize: 12,
                color: scheme.primary.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Read marker
  // ---------------------------------------------------------------------------

  /// Scrolls the rendered timeline to the event with [eventId].
  ///
  /// The estimate is intentionally approximate (item index in the
  /// visible list × viewport-fraction); the user can see the target and
  /// scroll if it lands off by a few items.
  ///
  /// No-ops when [eventId] is null, no client is attached, or the
  /// scroll controller isn't ready yet.
  void jumpToEvent(String? eventId) {
    final timeline = _timeline;
    if (timeline == null || eventId == null) return;
    if (!_scrollController.hasClients) return;

    final events = timeline.events;
    if (events.isEmpty) return;
    final idx = events.indexWhere((e) => e.eventId == eventId);
    if (idx < 0) return;

    final position = _scrollController.position;
    final range = position.maxScrollExtent - position.minScrollExtent;
    final fraction = idx / (events.length - 1);
    final targetOffset = position.minScrollExtent + range * fraction;
    final paddedOffset =
        (targetOffset - position.viewportDimension * 0.33).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );

    _scrollController.animateTo(
      paddedOffset,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  /// Sends a read receipt for the newest event in the timeline so the server
  /// and other clients know that the user has seen the latest messages.
  void _markRoomRead() {
    if (_timeline == null) return;
    final events = _timeline!.events;
    if (events.isEmpty) return;
    // events are newest-first, so index 0 is the most recent.
    final latestId = events.first.eventId;
    widget.room.setReadMarker(latestId, mRead: latestId);
  }

  // ---------------------------------------------------------------------------
  // Dispose
  // ---------------------------------------------------------------------------

  void _onTimelineUpdate() {
    if (!mounted) return;
    setState(() => _timelineVersion++);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _timeline?.cancelSubscriptions();
    super.dispose();
  }
}

/// Floating "Jump to first unread" pill rendered above the chat composer
/// when the room has unread messages below the current viewport.
///
/// The pill is intentionally lightweight: it shows the unread count and a
/// small chevron so the user can see at a glance how much they have missed
/// without cluttering the chat surface. Tapping it scrolls the timeline
/// to the first event newer than the fully-read marker and sends a read
/// receipt so the badge clears.
class _JumpToUnreadPill extends StatelessWidget {
  const _JumpToUnreadPill({required this.count, required this.onTap});

  final int count;
  final Future<void> Function() onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final label = count == 1
        ? l10n.jumpToFirstUnread
        : l10n.jumpToFirstUnreadMany(count);

    return Material(
      color: scheme.primary,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          // Fire and forget — the pill hides itself on the next rebuild
          // once the read marker is updated and the unread count drops
          // to zero.
          // ignore: discarded_futures
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.arrowUp, size: 14, color: scheme.onPrimary),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders a list of events fetched by ID for the pinned-only filter.
///
/// These events are not necessarily present in the room's [Timeline.events]
/// list, so they cannot be rendered by [TimelineView]'s filter mechanism.
/// Instead, this widget takes the pre-fetched events and renders each one
/// with a [TimelineItem], computing sender grouping from their timestamps.
class _PinnedEventsList extends StatelessWidget {
  const _PinnedEventsList({
    required this.events,
    required this.room,
    required this.displayType,
    required this.fontSize,
    required this.scrollController,
    this.onReply,
    this.onThread,
    this.onForward,
  });

  final List<Event> events;
  final Room room;
  final DisplayType displayType;
  final double fontSize;
  final ScrollController scrollController;
  final void Function(Event event)? onReply;
  final void Function(Event event)? onThread;
  final void Function(Event event)? onForward;

  @override
  Widget build(BuildContext context) {
    // Events are already sorted oldest-first.  Compute sender grouping:
    // each event is a continuation of the *newer* event below it
    // (which appears later in the list).  Since the ListView is reversed,
    // index 0 appears at the bottom (newest message) of the viewport.
    final Map<String, int> eventIdToItemIndex = {};
    final itemCount = events.length;

    return ListView.builder(
      controller: scrollController,
      reverse: true,
      itemCount: itemCount,
      itemBuilder: (context, index) {
        // index 0 = last in list (newest), index n-1 = first (oldest)
        final event = events[itemCount - 1 - index];

        // Determine if this event is a continuation of the older event
        // above it in the list (the *next* newer event in reversed order).
        final isContinuation = index + 1 < itemCount &&
            _isSameSenderAndCloseInTime(
              events[itemCount - 1 - index],
              events[itemCount - 2 - index],
            );

        eventIdToItemIndex[event.eventId] = index;

        return TimelineItem(
          event: event,
          room: room,
          displayType: displayType,
          isGroupStart: !isContinuation,
          isGroupContinuation: isContinuation,
          fontSize: fontSize,
          onReply: onReply != null ? () => onReply!(event) : null,
          onThread: onThread != null ? () => onThread!(event) : null,
          onForward:
              onForward != null ? () => onForward!(event) : null,
          onJumpToEvent: (String eventId) {
            final targetIdx = eventIdToItemIndex[eventId];
            if (targetIdx == null) return;
            if (!scrollController.hasClients) return;
            final position = scrollController.position;
            final range =
                position.maxScrollExtent - position.minScrollExtent;
            final fraction =
                itemCount > 1 ? targetIdx / (itemCount - 1) : 0.0;
            final targetOffset =
                position.minScrollExtent + range * fraction;
            scrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          },
        );
      },
    );
  }

  /// True when [newer] and [older] are from the same sender within ~10 min.
  bool _isSameSenderAndCloseInTime(Event newer, Event older) {
    if (newer.senderId != older.senderId) return false;
    return _sameEnvironment(newer.originServerTs, older.originServerTs);
  }

  /// True when two timestamps fall within 10 minutes of each other.
  bool _sameEnvironment(DateTime a, DateTime b) {
    final diff = a.difference(b).inMinutes.abs();
    return diff <= 10;
  }
}
