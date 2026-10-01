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

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/chat/chat_timeline_floating_actions.dart';
import 'package:moonrelay/src/chat/chat_unread_utils.dart';
import 'package:moonrelay/src/chat/forward_message_dialog.dart';
import 'package:moonrelay/src/chat/history_pager.dart';
import 'package:moonrelay/src/chat/jump_coordinator.dart';
import 'package:moonrelay/src/chat/pinned_events_list.dart';
import 'package:moonrelay/src/chat/read_marker_tracker.dart';
import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/lifecycle_generation.dart';
import 'package:moonrelay/src/helpers/pinned_events_cache.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Orchestrates the chat timeline lifecycle.
///
/// Creates the [Timeline] via the Matrix SDK, mounts the floating-action
/// column, and composes three narrow collaborators:
///
/// - [HistoryPager]  -- owns scroll-driven pagination and the
///   auto-fill / state-event-drain loops.
/// - [JumpCoordinator]  -- owns the "jump to first unread" affordance.
/// - [ReadMarkerTracker]  -- owns the scroll-debounced read-receipt
///   pipeline.
///
/// The state itself is intentionally thin: lifecycle, keying, and
/// build.  All the imperative plumbing lives in the collaborators.
class ChatTimeline extends StatefulWidget {
  const ChatTimeline({
    super.key,
    required this.room,
    this.onReply,
    this.onThread,
    this.onEdit,
    this.filterEvents,
  });

  final Room room;
  final void Function(Event event)? onReply;
  final void Function(Event event)? onThread;
  final void Function(Event event)? onEdit;
  final bool Function(Event)? filterEvents;

  @override
  State<ChatTimeline> createState() => ChatTimelineState();
}

class ChatTimelineState extends State<ChatTimeline> with LifecycleGeneration {
  /// The resolved Timeline, or null while still initialising.
  Timeline? _timeline;

  /// Event id this timeline is anchored on, when it is a `/context`
  /// history window rather than the live tail.  Null for the live
  /// timeline.  Drives the "back to latest" affordance and suppresses
  /// the unread pill, which is meaningless inside a window that does
  /// not contain the read marker.
  String? _anchoredEventId;

  /// True while a `/context` window is being fetched for a jump.
  bool _loadingContext = false;

  /// Bumped on every SDK `onChange`/`onInsert`/`onRemove`/`onUpdate`
  /// so [TimelineView] knows to invalidate its item-list cache.
  /// Exposed as a [ValueNotifier] so the parent [build] of
  /// [ChatTimeline] is not forced through rebuild on every sync tick
  /// -- the previous `setState(() => _timelineVersion++)` rebuilt the
  /// entire subtree, including [ChatTimelineFloatingActions] and
  /// [ChatTimelineFloatingActions]'s parent [Stack].
  final ValueNotifier<int> _timelineVersion = ValueNotifier<int>(0);

  /// True when [_initTimeline] finished with a permanent error.
  bool _timelineLoadFailed = false;

  /// Events explicitly fetched for the pinned filter (fetched by ID
  /// from the server when they aren't in the local timeline batch).
  List<Event>? _fetchedFilteredEvents;
  bool _isFetchingFilteredEvents = false;

  final ScrollController _scrollController = ScrollController();

  /// Pixel distance from the bottom of the (reverse) list that triggers
  /// the "Scroll to bottom" pill.
  static const double _scrollUpThreshold = 200.0;

  /// Live scroll-up flag surfaced as a [ValueNotifier] so the floating
  /// action column can rebuild via [ValueListenableBuilder] without
  /// forcing the entire chat surface to rebuild on every scroll tick.
  final ValueNotifier<bool> _isScrolledUpNotifier = ValueNotifier<bool>(false);

  /// The user has explicitly dismissed the jump-to-unread pill via its
  /// close icon.  Scoped to the newest event that existed at the moment
  /// of dismissal: if a later sync brings something new, the pill comes
  /// back rather than staying latched off for the rest of the session.
  String? _pillDismissedAtNewestId;

  final GlobalKey<TimelineViewState> _timelineViewKey =
      GlobalKey<TimelineViewState>(debugLabel: 'chat_timeline_view');

  HistoryPager? _historyPager;
  JumpCoordinator? _jumpCoordinator;
  ReadMarkerTracker? _readMarkerTracker;

  // -- Test accessors --------------------------------------------

  @visibleForTesting
  int get timelineVersionForTest => _timelineVersion.value;

  @visibleForTesting
  bool get isLoadingHistoryForTest => _historyPager?.isLoading ?? false;

  /// Wall-clock ceiling the jump pager is configured with.
  ///
  /// Exposed so a test can pin the shipped default. The pager's own budget
  /// is a constructor parameter precisely so a test can lower it, which
  /// means a future edit could quietly shorten the real one and every test
  /// would still pass; this is the assertion that notices.
  Duration? get paginationBudgetForTest => _jumpCoordinator?.paginationBudget;

  /// Test accessor for the paginate-until-marker primitive, with an
  /// injectable [budget].
  ///
  /// Delegates to [JumpCoordinator.paginateUntilMarkerForTest] rather than
  /// reaching for a pager of its own. It used to call the whole
  /// `jumpToLastRead()` and then re-scan the event list for the marker,
  /// which is a test-only shim standing in for a primitive that now
  /// exists: it could scroll the user, it ignored [budget], and it reported
  /// whatever the cache happened to hold rather than what the pager found.
  @visibleForTesting
  Future<bool> paginateUntilMarkerForTest(
    String markerId, {
    Duration? budget,
  }) {
    final timeline = _timeline;
    final coordinator = _jumpCoordinator;
    if (timeline == null || coordinator == null) return Future.value(false);
    // The coordinator owns the pager, so its own test seam is the one
    // thing allowed to call another. Reaching in here is deliberate: the
    // wrapper exists so the test can ask the widget rather than reaching
    // into its collaborators, and duplicating the null checks here is what
    // that indirection buys.
    // ignore: invalid_use_of_visible_for_testing_member
    return coordinator.paginateUntilMarkerForTest(markerId, budget: budget);
  }

  /// Test accessor matching the prior public API for
  /// `_requestMoreHistory`.  Re-entrant calls during an in-flight
  /// request short-circuit instead of issuing additional
  /// `requestHistory` calls (delegated to [HistoryPager]).
  @visibleForTesting
  Future<void> requestMoreHistoryForTest() async {
    _historyPager?.ensureFilled();
  }

  // -- Lifecycle -------------------------------------------------

  @override
  void initState() {
    super.initState();
    _initCollaborators();
    _initTimeline();
    _scrollController.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ChatTimeline oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.room.id != widget.room.id) {
      invalidate();
      _historyPager?.resetForRoom();
      _jumpCoordinator?.resetForRoom();
      _readMarkerTracker?.resetForRoom();
      _pillDismissedAtNewestId = null;
      _timeline = null;
      _fetchedFilteredEvents = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _bindRoom();
        _initTimeline();
      });
    }
    if (widget.filterEvents != null && oldWidget.filterEvents == null) {
      _fetchFilteredEvents();
    } else if (widget.filterEvents == null && oldWidget.filterEvents != null) {
      if (_fetchedFilteredEvents != null) {
        setState(() => _fetchedFilteredEvents = null);
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _historyPager?.dispose();
    _jumpCoordinator?.dispose();
    _readMarkerTracker?.dispose();
    _scrollController.dispose();
    _timeline?.cancelSubscriptions();
    _isScrolledUpNotifier.dispose();
    _timelineVersion.dispose();
    super.dispose();
  }

  // -- Init ------------------------------------------------------

  void _initCollaborators() {
    _historyPager = HistoryPager(
      room: widget.room,
      scrollController: _scrollController,
      getTimeline: () => _timeline,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      logger: _tryReadLogger(),
    );
    _jumpCoordinator = JumpCoordinator(
      context: context,
      getTimeline: () => _timeline,
      getFullyReadMarker: () => widget.room.fullyRead,
      scrollController: _scrollController,
      timelineViewKey: _timelineViewKey,
      historyPager: _historyPager!,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onAfterJump: () {},
      scrollToBottom: _goLive,
      logger: _tryReadLogger(),
    );
    _readMarkerTracker = ReadMarkerTracker(
      room: widget.room,
      sendReceipts: _readSendReceipts(),
      notificationService: _tryReadNotificationMirror(),
      onLastSeenChanged: (_) {},
      logger: _tryReadLogger(),
    );
  }

  void _bindRoom() {
    _historyPager = HistoryPager(
      room: widget.room,
      scrollController: _scrollController,
      getTimeline: () => _timeline,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      logger: _tryReadLogger(),
    );
    _jumpCoordinator = JumpCoordinator(
      context: context,
      getTimeline: () => _timeline,
      getFullyReadMarker: () => widget.room.fullyRead,
      scrollController: _scrollController,
      timelineViewKey: _timelineViewKey,
      historyPager: _historyPager!,
      onStateChanged: () {
        if (mounted) setState(() {});
      },
      onAfterJump: () {},
      scrollToBottom: _goLive,
      logger: _tryReadLogger(),
    );
    _readMarkerTracker?.bindRoom(widget.room);
  }

  Future<void> _initTimeline({String? eventContextId}) async {
    final log = _tryReadLogger();
    final gen = beginAsync();

    final result = await withRetry(
      () => widget.room.getTimeline(
        onChange: (_) => _onTimelineUpdate(),
        onInsert: (_) => _onTimelineUpdate(),
        onRemove: (_) => _onTimelineUpdate(),
        onUpdate: () => _onTimelineUpdate(),
        eventContextId: eventContextId,
      ),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'getTimeline(${widget.room.id}'
          '${eventContextId == null ? '' : ', context $eventContextId'})',
    );

    if (isStale(gen) || !mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        setState(() {
          _timeline = value;
          _anchoredEventId = eventContextId;
        });
        _readMarkerTracker?.bindRoom(widget.room);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (isStale(gen) || !mounted) return;
          _historyPager?.ensureFilled();
          if (eventContextId != null) {
            // Centre the requested event once the window has laid out.
            _timelineViewKey.currentState?.scrollToEventId(eventContextId);
          } else {
            // Claim only what the user can actually see.  Posting the
            // newest cached event here retired every unread message
            // above the fold on each room open (WORK_NEEDED.md 8.2).
            _settleReadPosition();
          }
        });
      case RetryFailed(:final error):
        log?.e(
          'Failed to load timeline for ${widget.room.id}'
          '${eventContextId == null ? '' : ' around $eventContextId'}',
          error: error,
        );
        // A failed context load should not replace a working live view
        // with an error card, so only surface the error state when there
        // is nothing to fall back to.
        if (eventContextId != null && _timeline != null) {
          log?.w('Keeping the live timeline after a failed context load');
          return;
        }
        _timelineLoadFailed = true;
        setState(() {});
    }
  }

  /// Loads a `/context` window centred on [eventId] and scrolls to it.
  ///
  /// The live timeline is anchored to the tail of the room and cannot
  /// page forward (`canRequestFuture` is permanently false on it, see
  /// WORK_NEEDED.md 8.1), so an event outside the local cache used to be
  /// an unreachable target.  `room.getTimeline(eventContextId:)` builds
  /// a different kind of timeline around the event, which is the only
  /// primitive this SDK offers for the job.
  Future<void> _loadEventContext(String eventId) async {
    final log = _tryReadLogger();
    // Detach the outgoing timeline before replacing it.  A
    // `/context` window is still a `Timeline`, so it subscribes to
    // `onSync`; the SDK's `_removeEventsNotInThisSync` would delete
    // every event in the window on the next gap-limited sync.
    final previous = _timeline;
    if (previous != null) previous.cancelSubscriptions();

    await _initTimeline(eventContextId: eventId);
    if (!mounted) return;
    if (_anchoredEventId == eventId) return;
    // `_initTimeline` already logged the failure and kept the previous
    // timeline; nothing left to do but make the miss visible.
    log?.w('Event context for $eventId did not resolve; '
        'keeping the previous view');
    _reportUnreachableEvent();
  }

  /// Surfaces "that message is gone" to the user.  A jump that silently
  /// does nothing is indistinguishable from a broken button, which is
  /// how the old cache-only path read.
  void _reportUnreachableEvent() {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.eventNotFound)),
    );
  }

  // -- Scroll listener ------------------------------------------

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final pos = _scrollController.position;
    final scrolledUp = pos.pixels > _scrollUpThreshold;
    if (scrolledUp != _isScrolledUpNotifier.value) {
      _isScrolledUpNotifier.value = scrolledUp;
    }

    // Ask the view where the user's eye actually is, rather than
    // assuming they have read everything in the cache.  Posting the
    // newest cached event on every scroll tick is what made the
    // timeline mark itself read (WORK_NEEDED.md 8.2).
    final events = _timeline?.events;
    final readId = _timelineViewKey.currentState?.oldestVisibleEventId;
    if (events != null && readId != null) {
      _readMarkerTracker?.scheduleOnScroll(
        TimelineSnapshot.atReadPosition(events, readId: readId),
      );
    }

    _historyPager?.onScroll();
  }

  void _onTimelineUpdate() {
    if (!mounted) return;
    _historyPager?.onTimelineUpdated();
    _timelineVersion.value++;
  }

  // -- Helpers --------------------------------------------------

  /// Number of events in the cached timeline that are newer than
  /// [Room.fullyRead].  Drives the unread pill.
  int get _unreadInWindow {
    final timeline = _timeline;
    if (timeline == null) return 0;
    // Read the fullyRead marker from the room (always present via the
    // owning widget) rather than the timeline's room reference, which
    // can be null in test fakes.
    return countUnreadInWindow(timeline.events, widget.room.fullyRead);
  }

  /// Newest event id in the cache, used to scope pill dismissal.
  String? get _newestEventId {
    final events = _timeline?.events;
    if (events == null || events.isEmpty) return null;
    return events.first.eventId;
  }

  bool get _pillDismissed =>
      _pillDismissedAtNewestId != null &&
      _pillDismissedAtNewestId == _newestEventId;

  bool get _showUnreadPill =>
      _unreadInWindow > 0 &&
      !_pillDismissed &&
      !(_jumpCoordinator?.isJumping ?? false);

  void _dismissUnreadPill() {
    if (_pillDismissed) return;
    setState(() => _pillDismissedAtNewestId = _newestEventId ?? '');
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    final t = MoonrelayThemeExtension.of(context).tokens;
    _scrollController.animateTo(
      0,
      duration: t.durationFast,
      curve: Curves.easeOut,
    );
  }

  /// Public entry point for the floating "Scroll to bottom" button.
  void scrollToBottom() {
    if (!_isScrolledUpNotifier.value) return;
    _goLive();
  }

  /// Returns the viewport to the newest message.  Also clears the
  /// scrolled-up flag, so a caller that lands on the live edge does not
  /// leave a stale "scroll to bottom" pill behind.
  ///
  /// No read receipt is posted here.  Landing at the newest message
  /// means the user has read the *oldest* event on screen, not the
  /// newest event in the room, and the animation's own scroll
  /// notifications drive [_settleReadPosition] to the right answer.
  void _goLive() {
    if (!_scrollController.hasClients) return;
    _isScrolledUpNotifier.value = false;
    _scrollToBottom();
  }

  /// Posts a read receipt naming the oldest event currently on screen,
  /// and retries across a few frames while the list is still settling.
  ///
  /// The read position is always "the oldest thing the user can see",
  /// never "the newest event in the cache".  Collapsing the two is what
  /// made the timeline retire unread it had not shown yet
  /// (WORK_NEEDED.md 8.2).
  void _settleReadPosition({int attemptsLeft = 3}) {
    final events = _timeline?.events;
    final readId = _timelineViewKey.currentState?.oldestVisibleEventId;
    if (events == null || readId == null) {
      // The view has not built its items yet, or nothing measurable is
      // on screen.  A few frames is enough for the first layout and for
      // HistoryPager's own deferred auto-fill.
      if (attemptsLeft <= 0) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _settleReadPosition(attemptsLeft: attemptsLeft - 1);
      });
      return;
    }
    _readMarkerTracker?.markRoomReadFromSnapshot(
      TimelineSnapshot.atReadPosition(events, readId: readId),
    );
  }

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

      final events = await Future.wait(
        pinnedIds.map(
          (id) => PinnedEventsCache.instance.getEvent(widget.room, id),
        ),
      );
      final resolved = events.whereType<Event>().toList();
      resolved.sort((a, b) => a.originServerTs.compareTo(b.originServerTs));

      if (!mounted) return;
      setState(() => _fetchedFilteredEvents = resolved);
    } finally {
      _isFetchingFilteredEvents = false;
    }
  }

  // -- Provider lookups (tolerant when missing) -----------------

  Logger? _tryReadLogger() {
    if (!mounted) return null;
    try {
      return context.read<Logger>();
    } catch (_) {
      return null;
    }
  }

  bool _readSendReceipts() {
    try {
      return context.read<SettingsController>().sendReadReceipts;
    } catch (_) {
      return true;
    }
  }

  NotificationMirror _tryReadNotificationMirror() {
    try {
      final service = context.read<NotificationService>();
      return _ServiceNotificationMirror(service);
    } catch (_) {
      return const NoopNotificationMirror();
    }
  }

  // -- Build ----------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Reset retry / drain counters once the viewport is scrollable.
    if (_scrollController.hasClients &&
        _scrollController.position.haveDimensions &&
        _scrollController.position.maxScrollExtent > 50.0) {
      _historyPager?.resetCounters();
    }

    // Sample the SDK's fullyRead marker on every build; the
    // debouncer inside [ReadMarkerTracker] coalesces rapid rebuilds
    // (window resize, sidebar drag) into one mutation.
    _readMarkerTracker?.scheduleLastSeenRefresh(widget.room.fullyRead);

    return Selector<SettingsController, _TimelineSettings>(
      selector: (_, settings) => _TimelineSettings(
        displayType: settings.displayType,
        fontSize: settings.fontSize,
        bubbleRadius: settings.bubbleRadius,
        showStateEvents: settings.showStateEvents,
      ),
      shouldRebuild: (a, b) => a != b,
      builder: (context, settings, _) {
        final t = MoonrelayThemeExtension.of(context).tokens;
        if (_timeline == null) {
          if (_timelineLoadFailed) return _buildError(context);
          return const SizedBox.shrink();
        }

        final child = _buildTimelineContent(context, settings);

        return Stack(
          children: [
            child,
            ListenableBuilder(
              listenable:
                  Listenable.merge([_isScrolledUpNotifier, _timelineVersion]),
              builder: (context, _) {
                final isScrolledUp = _isScrolledUpNotifier.value;
                final isJumping = _jumpCoordinator?.isJumping ?? false;
                final inHistoryWindow = _anchoredEventId != null;
                // The jump-to-unread pill stays visible regardless of scroll
                // position once it has appeared -- it only disappears when
                // explicitly dismissed or when the room is marked read (which
                // zeros the unread count).  The scroll-to-bottom pill, by
                // contrast, only appears when the user has scrolled away from
                // the newest messages.
                //
                // Inside a `/context` window the unread pill is suppressed:
                // the window does not contain the read marker, so every
                // event in it counts as unread and the pill would offer to
                // jump somewhere the window cannot reach.  The bottom pill
                // becomes the way back to the live tail instead.
                final unreadVisible =
                    !inHistoryWindow && (_showUnreadPill || isJumping);
                final showColumn = isScrolledUp || unreadVisible ||
                    inHistoryWindow || _loadingContext;
                if (!showColumn) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: t.spaceMd,
                  child: SafeArea(
                    top: false,
                    child: Center(
                      child: ChatTimelineFloatingActions(
                        unreadCount: _unreadInWindow,
                        isScrolledUp: isScrolledUp,
                        unreadVisible: unreadVisible,
                        isJumping: isJumping,
                        loadingContext: _loadingContext,
                        onBackToLive: inHistoryWindow ? backToLive : null,
                        onJumpToUnread: () async {
                          await _jumpCoordinator?.jumpToLastRead();
                          if (!mounted) return;
                          // Deliberately no mark-read and no dismiss
                          // here.  The jump lands the first unread
                          // message near the top of the viewport, so
                          // the read position is roughly there and not
                          // at the newest event; forcing a receipt for
                          // the newest event is what made the pill
                          // reappear and then vanish on every attempt.
                          // The scroll listener settles the real
                          // position once the animation finishes.
                        },
                        onScrollToBottom: scrollToBottom,
                        onDismissUnread: _dismissUnreadPill,
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildTimelineContent(
    BuildContext context,
    _TimelineSettings settings,
  ) {
    final t = MoonrelayThemeExtension.of(context).tokens;
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
                      .withValues(alpha: t.opacityMuted),
                ),
                SizedBox(height: t.spaceMd),
                Text(
                  AppLocalizations.of(context)!.noPinnedMessages,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        return PinnedEventsList(
          events: _fetchedFilteredEvents!,
          room: widget.room,
          displayType: settings.displayType,
          fontSize: settings.fontSize,
          bubbleRadius: settings.bubbleRadius,
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

      return const Center(child: CircularProgressIndicator());
    }

    return TimelineView(
      key: _timelineViewKey,
      timeline: _timeline!,
      room: widget.room,
      displayType: settings.displayType,
      fontSize: settings.fontSize,
      bubbleRadius: settings.bubbleRadius,
      scrollController: _scrollController,
      timelineVersion: _timelineVersion,
      onReply: widget.onReply,
      onThread: widget.onThread,
      onEdit: widget.onEdit,
      showStateEvents: settings.showStateEvents,
      filterEvents: widget.filterEvents,
      isLoadingHistory: _historyPager?.shouldShowSkeleton ?? false,
      highlightedEventId: _jumpCoordinator?.highlightedEventId,
    );
  }

  Widget _buildError(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle,
                size: t.minTapTarget, color: scheme.error),
            SizedBox(height: t.spaceLg),
            Text(
              AppLocalizations.of(context)!.couldNotLoadMessages,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            SizedBox(height: t.spaceSm),
            Text(
              AppLocalizations.of(context)!.serverMayBeUnreachable,
              style: TextStyle(
                fontSize: 13,
                color:
                    scheme.onSurfaceVariant.withValues(alpha: t.opacitySubtle),
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.spaceLg),
            Icon(
              LucideIcons.shield,
              size: t.iconSizeLarge,
              color: scheme.onSurfaceVariant.withValues(alpha: t.opacitySubtle),
            ),
            SizedBox(height: t.spaceSm),
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

  // -- Public API for callers outside the widget -----------------

  /// Public accessor for the scroll controller, exposed so callers
  /// outside this widget (e.g. the in-room search panel) can request
  /// a jump to a specific event.
  ScrollController get scrollController => _scrollController;

  /// Dismisses the jump-to-unread pill.  No-op if already dismissed.
  void dismissUnreadPill() => _dismissUnreadPill();

  /// Brings [eventId] into view.
  ///
  /// Three cases, in order of cost:
  ///  1. The event is already rendered, or at least cached: scroll.
  ///  2. It is not cached: fetch a `/context` window around it and
  ///     show that instead (see [_loadEventContext]).
  ///  3. The server cannot return it: leave the current view alone and
  ///     report the failure, rather than blanking the room.
  Future<void> jumpToEvent(String? eventId) async {
    if (eventId == null || eventId.isEmpty) return;

    final cached = _timeline?.events.any((e) => e.eventId == eventId) ?? false;
    if (cached) {
      _jumpCoordinator?.jumpToEvent(eventId);
      return;
    }

    if (_loadingContext) return;
    setState(() => _loadingContext = true);
    try {
      await _loadEventContext(eventId);
    } finally {
      if (mounted) setState(() => _loadingContext = false);
    }
  }

  /// Abandons a `/context` window and returns to the live tail.
  Future<void> backToLive() async {
    if (_anchoredEventId == null) return;
    _timeline?.cancelSubscriptions();
    await _initTimeline();
  }

  /// True while the timeline shows a history window instead of the live
  /// tail, so the bottom pill offers a way back.
  bool get isViewingHistoryWindow => _anchoredEventId != null;

  /// True while a jump is fetching a history window.
  bool get isLoadingContext => _loadingContext;
}

class _ServiceNotificationMirror implements NotificationMirror {
  _ServiceNotificationMirror(this._service);
  final NotificationService _service;

  @override
  void onRoomRead(String roomId, String eventId) =>
      _service.onRoomReadByTimeline(roomId, eventId);
}

/// Subset of [SettingsController] fields that influence what the
/// chat timeline renders.  Used by a [Selector] so an unrelated
/// settings change (e.g. theme, notification preferences) does not
/// force a full timeline rebuild.
///
/// Captured as an immutable record so equality is cheap and the
/// selector can short-circuit re-renders during rapid scrolling.
@immutable
class _TimelineSettings {
  const _TimelineSettings({
    required this.displayType,
    required this.fontSize,
    required this.bubbleRadius,
    required this.showStateEvents,
  });

  final DisplayType displayType;
  final double fontSize;
  final double bubbleRadius;
  final bool showStateEvents;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is _TimelineSettings &&
        other.displayType == displayType &&
        other.fontSize == fontSize &&
        other.bubbleRadius == bubbleRadius &&
        other.showStateEvents == showStateEvents;
  }

  @override
  int get hashCode => Object.hash(
        displayType,
        fontSize,
        bubbleRadius,
        showStateEvents,
      );
}
