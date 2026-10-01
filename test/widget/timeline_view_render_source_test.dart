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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

// The render list is now supplied to
// TimelineView, rather than read out of a Timeline it is handed.
//
// The whole point of this stage is the seam, so these tests are about the
// seam. They assert that the view renders what it was given even when that
// disagrees with the live timeline it was also given, because that
// disagreement is exactly the shape stage 5 produces.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonrelay/src/chat/events/timeline_gap_marker.dart';
import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/settings/display_type.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// A message event stubbed the way `TimelineItem` actually reads one.
/// The banner and the bubble both reach past the obvious fields, and an
/// unstubbed mocktail getter throws rather than returning null.
MockEvent event(String id, MockUser sender, {DateTime? ts}) {
  final event = MockEvent();
  when(() => event.eventId).thenReturn(id);
  when(() => event.hasAggregatedEvents(any(), any())).thenReturn(false);
  when(() => event.aggregatedEvents(any(), any())).thenReturn(<Event>{});
  when(() => event.receipts).thenReturn(<Receipt>[]);
  when(() => event.getDisplayEvent(any())).thenReturn(event);
  when(() => event.redacted).thenReturn(false);
  when(() => event.type).thenReturn(EventTypes.Message);
  when(() => event.messageType).thenReturn(MessageTypes.Text);
  when(() => event.body).thenReturn(id);
  when(() => event.senderId).thenReturn('@alice:dom');
  when(() => event.senderFromMemoryOrFallback).thenReturn(sender);
  when(() => event.originServerTs)
      .thenReturn(ts ?? DateTime(2025, 6, 14, 10, 30));
  when(() => event.content)
      .thenReturn({'body': id, 'msgtype': 'm.text'});
  return event;
}

class _T extends Mock implements Timeline {
  _T(this._events);
  final List<Event> _events;
  @override
  List<Event> get events => _events;
  @override
  TimelineChunk get chunk => TimelineChunk(events: _events);
}

void main() {
  late MockUser sender;
  late MockEncryptionService encryption;
  late MockClient client;
  late MockRoom room;

  setUpAll(() {
    registerFallbackValue(MockTimeline());
    registerFallbackValue(RelationshipTypes.edit);
  });

  setUp(() {
    sender = MockUser();
    encryption = MockEncryptionService();
    client = MockClient();
    room = MockRoom();
    when(() => room.client).thenReturn(client);
    when(() => room.canChangeStateEvent(any())).thenReturn(false);
    when(() => room.id).thenReturn('!r:dom');
    when(() => room.encrypted).thenReturn(false);
    when(() => room.membership).thenReturn(Membership.join);
    when(() => sender.calcDisplayname()).thenReturn('Alice');
    when(() => sender.id).thenReturn('@alice:dom');
    when(() => encryption.isUserVerifiedById(any())).thenReturn(false);
  });

  Future<void> pumpView(
    WidgetTester tester, {
    required List<Event> events,
    required Timeline timeline,
    ValueNotifier<int>? version,
    ScrollController? controller,
    List<List<Event>>? groups,
    Set<int> gapsAfter = const {},
    void Function(int groupIndex)? onGapApproach,
  }) async {
    await tester.pumpWidget(
      wrapWithProviders(
        encryptionService: encryption,
        child: Scaffold(
          body: SizedBox(
            width: 400,
            height: 600,
            child: TimelineView(
              events: events,
              eventGroups: groups,
              gapBoundaries: gapsAfter,
              onGapApproach: onGapApproach,
              timeline: timeline,
              room: room,
              displayType: DisplayType.modern,
              scrollController: controller ?? ScrollController(),
              fontSize: 14,
              timelineVersion: version,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  group('the render list is the source', () {
    testWidgets('renders the events it is given', (tester) async {
      final events = [event('a', sender), event('b', sender)];
      await pumpView(tester, events: events, timeline: _T(events));
      expect(find.text('a'), findsOneWidget);
      expect(find.text('b'), findsOneWidget);
    });

    testWidgets('renders the given list, not timeline.events',
        (tester) async {
      // THE claim of this stage. Once a TimelineStore is wired in, the
      // render list spans the live tail plus history windows while
      // `timeline` stays the live tail alone. Anything in this view that
      // still reached for `timeline.events` would silently drop the
      // window's events, and nothing would look wrong.
      final windowed = [event('from_window', sender), event('tail', sender)];
      final liveOnly = [event('tail', sender)];
      await pumpView(tester, events: windowed, timeline: _T(liveOnly));

      expect(find.text('from_window'), findsOneWidget);
      expect(find.text('tail'), findsOneWidget);
    });

    testWidgets('a timeline with more events does not leak extras',
        (tester) async {
      await pumpView(
        tester,
        events: [event('rendered', sender)],
        timeline: _T([event('rendered', sender), event('hidden', sender)]),
      );
      expect(find.text('hidden'), findsNothing);
    });

    testWidgets('an empty render list renders nothing', (tester) async {
      await pumpView(tester, events: const [], timeline: _T([event('tail', sender)]));
      expect(find.text('tail'), findsNothing);
    });
  });

  group('cache identity', () {
    testWidgets('a mutated list with a bumped version re-renders',
        (tester) async {
      // The list identity in the cache key does NOT drive invalidation,
      // and it is worth being explicit about that, because the first draft
      // of this test asserted the opposite and failed. `chunk.events` is
      // mutated in place, so its identity never changes when the contents
      // do; if the key alone drove the rebuild it would serve stale items
      // for as long as the version notifier was silent.
      //
      // The notifier is the invalidation signal. That is why `events` and
      // `timelineVersion` are a pair rather than either being redundant.
      final events = [event('a', sender)];
      final version = ValueNotifier<int>(0);
      await pumpView(
        tester,
        events: events,
        timeline: _T(events),
        version: version,
      );
      expect(find.text('a'), findsOneWidget);

      events.add(event('b', sender));
      version.value++;
      await tester.pump();

      expect(find.text('b'), findsOneWidget);
      expect(find.text('a'), findsOneWidget);
    });

    testWidgets('a mutated list with a silent version serves the cache',
        (tester) async {
      // The other half, and it is the reason the previous test needed its
      // comment. Without a bump the cache is intentionally kept, so this is
      // not a bug being enshrined: it is the contract that makes the
      // notifier the single invalidation signal.
      final events = [event('a', sender)];
      final version = ValueNotifier<int>(0);
      await pumpView(
        tester,
        events: events,
        timeline: _T(events),
        version: version,
      );
      expect(find.text('a'), findsOneWidget);

      events.add(event('b', sender));
      await tester.pump();

      expect(find.text('b'), findsNothing);
      addTearDown(version.dispose);
    });

    testWidgets('a replaced list renders the new contents', (tester) async {
      final first = [event('first', sender)];
      final timeline = _T(first);
      await pumpView(tester, events: first, timeline: timeline);
      expect(find.text('first'), findsOneWidget);

      // A new list object, which is what TimelineStore.flatten() produces
      // on every call. Stage 5 pairs this with store.version; the point
      // here is only that a different list is not served from cache.
      await pumpView(tester, events: [event('second', sender)], timeline: timeline);
      expect(find.text('second'), findsOneWidget);
      expect(find.text('first'), findsNothing);
    });
  });
group('gaps', () {
    // A short live tail and a long window, so the boundary sits inside the
    // viewport. A tail long enough to fill the screen would put the marker
    // off it, and `find.byType` only ever sees built children, so the
    // assertion would pass for the wrong reason.
    List<Event> tailOf(int n) => [
          for (var i = 0; i < n; i++)
            event('evt_$i', sender, ts: DateTime(2025, 6, 15, 20, i)),
        ];

    List<Event> windowOf(int n) => [
          for (var i = 0; i < n; i++)
            event('old_$i', sender, ts: DateTime(2025, 6, 10, 9, i)),
        ];

    testWidgets('a gap marker renders between the groups', (tester) async {
      final tail = tailOf(4);
      final window = windowOf(40);
      await pumpView(
        tester,
        events: [...tail, ...window],
        timeline: _T(tail),
        groups: [tail, window],
        gapsAfter: const {0},
      );
      expect(find.byType(TimelineGapMarker), findsOneWidget);
    });

    testWidgets('no gaps named means no marker', (tester) async {
      final events = [event('a', sender)];
      await pumpView(
        tester,
        events: events,
        timeline: _T(events),
        groups: [events],
      );
      expect(find.byType(TimelineGapMarker), findsNothing);
    });

    testWidgets('a gap within reach reports the group to grow', (tester) async {
      // The only thing that makes a drawn gap temporary. Without this the
      // marker is permanent and the two windows never meet.
      final reported = <int>[];
      final tail = tailOf(4);
      final window = windowOf(40);
      final version = ValueNotifier<int>(0);
      addTearDown(version.dispose);

      await pumpView(
        tester,
        events: [...tail, ...window],
        timeline: _T(tail),
        groups: [tail, window],
        gapsAfter: const {0},
        version: version,
        onGapApproach: reported.add,
      );

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      view.reportGapApproach();

      expect(reported, [0],
          reason: 'group 0 is the newer side, and the one to grow');
    });

    testWidgets('no gap within reach reports nothing', (tester) async {
      final reported = <int>[];
      final tail = tailOf(4);
      final window = windowOf(40);
      final version = ValueNotifier<int>(0);
      addTearDown(version.dispose);

      await pumpView(
        tester,
        events: [...tail, ...window],
        timeline: _T(tail),
        groups: [tail, window],
        version: version,
        onGapApproach: reported.add,
      );

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      view.reportGapApproach();
      expect(reported, isEmpty);
    });

    testWidgets('the same gap is not reported twice', (tester) async {
      // A scroll fires this on many consecutive frames while the marker sits
      // near the fold. One report per gap, not one per frame.
      final reported = <int>[];
      final tail = tailOf(4);
      final window = windowOf(40);
      final version = ValueNotifier<int>(0);
      addTearDown(version.dispose);

      await pumpView(
        tester,
        events: [...tail, ...window],
        timeline: _T(tail),
        groups: [tail, window],
        gapsAfter: const {0},
        version: version,
        onGapApproach: reported.add,
      );

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      view.reportGapApproach();
      view.reportGapApproach();
      view.reportGapApproach();

      expect(reported, [0]);
    });

    testWidgets('a gap outside the built range is left alone', (tester) async {
      // The prefetch can only see markers that are built. A long tail pushes
      // the boundary above the cache extent, so there is nothing to measure
      // and nothing to report. (The threshold itself is bounded by the two
      // assertions at the bottom; a behavioural test for it cannot work,
      // because a marker far enough to be out of range is never built in the
      // first place.)
      final reported = <int>[];
      final tail = tailOf(200);
      final window = windowOf(40);
      final version = ValueNotifier<int>(0);
      addTearDown(version.dispose);

      await pumpView(
        tester,
        events: [...tail, ...window],
        timeline: _T(tail),
        groups: [tail, window],
        gapsAfter: const {0},
        version: version,
        onGapApproach: reported.add,
      );

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      view.reportGapApproach();
      expect(reported, isEmpty);

      // A real bound rather than a comment. Zero would mean never
      // prefetching, since the marker is off screen by definition when it
      // matters; the upper bound keeps it from firing for a hole the user
      // has no intention of reaching.
      expect(TimelineView.gapPrefetchDistance, greaterThan(0));
      expect(TimelineView.gapPrefetchDistance, lessThan(600));
    });

    testWidgets('the read position stops at the gap', (tester) async {
      // The decision: a gap means the messages above are not contiguous with
      // the ones below, so the user has not reached them by scrolling.
      // Continuing across would name an event they have not scrolled past and
      // retire messages they never saw.
      //
      // The window is on the old end and is below the fold, so a walk that
      // continued across the gap would report one of its events. A walk that
      // stops cannot, because nothing above the gap is on screen.
      final tail = tailOf(4);
      final window = windowOf(40);
      final version = ValueNotifier<int>(0);
      addTearDown(version.dispose);

      await pumpView(
        tester,
        events: [...tail, ...window],
        timeline: _T(tail),
        groups: [tail, window],
        gapsAfter: const {0},
        version: version,
      );

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      final readId = view.oldestVisibleEventId;

      expect(readId, isNotNull, reason: 'the tail is on screen');
      expect(
        readId,
        isNot(startsWith('old_')),
        reason: 'a gap must stop the walk, so nothing above it is read',
      );
    });

    testWidgets('without a gap the walk does reach the older events',
        (tester) async {
      // The control for the test above. Same layout, no marker: proves the
      // stop is caused by the gap and not by the older events simply being
      // off screen for an unrelated reason.
      final tail = tailOf(4);
      final window = windowOf(40);
      final version = ValueNotifier<int>(0);
      addTearDown(version.dispose);

      await pumpView(
        tester,
        events: [...tail, ...window],
        timeline: _T(tail),
        groups: [tail, window],
        version: version,
      );

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      expect(view.oldestVisibleEventId, isNotNull);
      // Without the stop, the walk continues into the window, because those
      // events are on screen here. That is what makes the gap test above a
      // real discriminator.
      expect(view.oldestVisibleEventId, startsWith('old_'));
    });
  });

  group('jump targets', () {
    testWidgets('a jump to an event only in the render list still scrolls',
        (tester) async {
      // The stale-cache path. `_targetInLiveTimeline` decides whether a
      // target missing from the index map is worth refreshing the cache
      // for, and if it consulted `timeline.events` then an event that lives
      // only in the render list would be reported absent and the jump would
      // silently give up. That is exactly the event stage 5 introduces:
      // a window's events are in the render list and not in the live tail.
      // The window's events sit at the *old* end of the list, which under
      // `reverse: true` is the top of the scroll view, so reaching them
      // requires an actual scroll. A window-only event parked at index 0
      // would be under the cursor already and the assertion would pass
      // without testing anything.
      final events = [
        for (var i = 0; i < 40; i++)
          event('evt_$i', sender, ts: DateTime(2025, 6, 14, 10, i)),
      ];
      final windowOnly = [
        event('window_only', sender, ts: DateTime(2025, 6, 13, 9, 0)),
      ];
      final renderList = [...events, ...windowOnly];
      final version = ValueNotifier<int>(0);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(version.dispose);

      await pumpView(
        tester,
        events: renderList,
        timeline: _T(events),
        version: version,
        controller: controller,
      );
      expect(controller.offset, 0);

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      view.scrollToEventId('window_only');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      // The target was resolved through the render list, not the tail: the
      // event is not in `timeline.events` at all, so a jump that consulted
      // the tail for its index would have found nothing and not moved.
      expect(controller.offset, isNot(0),
          reason: 'a window-only event must be reachable by jump');
      await tester.pump(const Duration(seconds: 2));
    });

    testWidgets('the read position is taken from the render list',
        (tester) async {
      // The walk maps a rendered index back to an event through the item
      // list, so a window's events must be readable by it. This asserts
      // the walk produces *some* position over a list that is mostly not in
      // the tail, which it could not do if the ids came from the timeline.
      final events = [
        for (var i = 0; i < 30; i++)
          event('evt_$i', sender, ts: DateTime(2025, 6, 14, 10, i)),
      ];
      final version = ValueNotifier<int>(0);
      addTearDown(version.dispose);

      await pumpView(
        tester,
        events: [...events, event('window_only', sender)],
        timeline: _T(events),
        version: version,
      );

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      expect(view.oldestVisibleEventId, isNotNull);
      expect(view.oldestVisibleEventId, isNot('window_only'),
          reason: 'the window event is off screen above the fold');
    });

    testWidgets('a jump to a just-arrived window event refreshes the cache',
        (tester) async {
      // The stale-cache path, and the only state in which it is reachable.
      // The SDK mutates `chunk.events` in place, so a newly paginated event
      // is in `events` the instant the request lands while the index map is
      // still one build behind. That is the window
      // `_refreshJumpCacheAndScroll` exists for.
      //
      // If `_targetInLiveTimeline` consulted `timeline.events` it would
      // report the new event absent and the jump would silently give up,
      // which for a window-only event is the whole feature.
      final tail = [
        for (var i = 0; i < 40; i++)
          event('evt_$i', sender, ts: DateTime(2025, 6, 14, 10, i)),
      ];
      // Same object identity as what the view was built with, mutated.
      final renderList = [...tail];
      final version = ValueNotifier<int>(0);
      final controller = ScrollController();
      addTearDown(controller.dispose);
      addTearDown(version.dispose);

      await pumpView(
        tester,
        events: renderList,
        timeline: _T(tail),
        version: version,
        controller: controller,
      );
      expect(controller.offset, 0);

      // Arrives without a rebuild, exactly as an SDK pagination does. It
      // goes at the *old* end so that resolving it requires scrolling to
      // the top; an event landing at index 0 is already under the cursor
      // and the assertion would not distinguish a refresh from a no-op.
      renderList.add(
        event('window_only', sender, ts: DateTime(2025, 6, 13, 9, 0)),
      );

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      view.scrollToEventId('window_only');

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);

      // The refresh happened and the view moved to the new event.
      expect(controller.offset, isNot(0),
          reason: 'a just-arrived window event must still be reachable');
      await tester.pump(const Duration(seconds: 2));
    });
  });
}