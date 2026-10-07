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

// Jumping to an event that is not in the local cache.  The live
// timeline is anchored to the tail of the room and
// cannot page forward, so the old code simply returned and the jump did
// nothing.  These pin the replacement: build a `/context` window around
// the event, show it, and offer a way back to the live tail.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/chat/timeline_store.dart';

import '../helpers/renderable_timeline.dart';

/// Sets up a room whose live timeline holds [liveCount] messages, and a
/// separate `/context` window holding [contextCount] messages around
/// `$target`.
({RenderableRoom room, List<Event> context, String target}) _setup({
  int liveCount = 20,
  int contextCount = 30,
}) {
  final live = RenderableTimeline();
  final room = RenderableRoom(live);
  seedTimeline(room, live, count: liveCount);
  room.fullyReadId = 'read-marker-below-everything';

  // The target is in the middle of the window, not at either edge. It has
  // to actually be one of the window's events: the test asserts that a
  // second jump to an already-loaded point does not refetch, and that only
  // holds if the target is findable in the store.
  final targetId = 'ancient${(contextCount ~/ 2)}';
  final context = <Event>[
    for (var i = contextCount; i >= 1; i--)
      makeMessageEvent(room, 'ancient$i', 500000 + i),
  ];
  room.contextEvents = context;
  room.contextPrevBatch = 'tok';
  room.contextNextBatch = 'tok';
  return (room: room, context: context, target: '\$$targetId');
}

ChatTimelineState _state(WidgetTester tester) =>
    tester.state<ChatTimelineState>(find.byType(ChatTimeline));

/// The store, for asserting on accumulated segments directly.
///
/// A count of context *requests* does not prove windows accumulate: a jump
/// that collapsed the previous window and refetched would make the same
/// number of requests. The store is what holds the windows.
TimelineStore? _store(WidgetTester tester) =>
    _state(tester).storeForTest;

void main() {
  testWidgets(
    'jumping to an uncached event asks the room for a context window',
    (tester) async {
      final s = _setup();

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(
        s.room.contextRequests,
        [s.target],
        reason: 'the event is not in the live cache, so a /context window '
            'is the only way to reach it',
      );
    },
  );

  testWidgets(
    'the window is detached from sync, and the live tail is not',
    (tester) async {
      // A `/context` window is still a `Timeline` and subscribes to onSync.
      // Left subscribed, the SDK deletes every event in it on the next
      // gap-limited sync. The live tail is the one segment that must stay
      // subscribed, because it is what follows sync.
      final s = _setup();

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // The old code detached the live tail because it was being replaced.
      // With windows alongside it, detaching the tail would freeze the room.
      expect(s.room.live.subscriptionsCancelled, isFalse);
    },
  );

  testWidgets(
    'a context window is flagged so the UI can offer a way back',
    (tester) async {
      final s = _setup();

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();
      expect(_state(tester).isViewingHistoryWindow, isFalse);

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(_state(tester).isViewingHistoryWindow, isTrue);
    },
  );

  testWidgets(
    'the unread pill survives a jump into a context window',
    (tester) async {
      // It used to be suppressed inside a window, because a substituted
      // window held no read marker and so counted every event as unread.
      // With the window in the same list as the live tail the marker is
      // present, so the count is the real one and the pill is honest.
      final s = _setup();

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey(kUnreadPillKey)), findsOneWidget);

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pump(const Duration(seconds: 2));

      expect(find.byKey(const ValueKey(kUnreadPillKey)), findsOneWidget);
    },
  );

  testWidgets(
    'a jump adds a window and keeps the ones already loaded',
    (tester) async {
      // Windows accumulate. Collapsing them on every jump would discard
      // the live tail too, which is the state a room opens in, and would
      // make a second jump into nearby history refetch what is already
      // on screen.
      final s = _setup();

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      expect(_state(tester).isViewingHistoryWindow, isTrue);
      final afterFirst = s.room.contextRequests.length;

      // A second jump to a *different* uncached point. If windows were being
      // substituted or collapsed, this would either refetch the tail or
      // discard the first window.
      const second = '\$older-still';
      s.room.contextsByTarget[second] = [
        for (var i = 10; i >= 1; i--)
          makeMessageEvent(s.room, 'older$i', 100000 + i),
      ];
      s.room.contextPrevBatch = 'tok2';
      s.room.contextNextBatch = 'tok2';

      await _state(tester).jumpToEvent(second);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(s.room.contextRequests.length, afterFirst + 1);
      // Both windows are held, not just the newest. This is the assertion
      // that separates accumulation from substitution.
      expect(_store(tester)?.history.length, 2);
      expect(_state(tester).isViewingHistoryWindow, isTrue);
      // The live tail is still attached, because it is the segment that
      // follows sync.
      expect(s.room.live.subscriptionsCancelled, isFalse);
    },
  );

    // The coordinator resolved the read marker against the tail. A marker in
    // a loaded window missed the fast path, entered the paginating branch,
    // and spent its budget paging for something already on screen.
    testWidgets(
      'jump-to-unread finds a marker sitting in a window',
      (tester) async {
        final s = _setup();
        await tester.pumpWidget(wrapChatTimeline(s.room));
        await tester.pump();
        await tester.pump();

        await _state(tester).jumpToEvent(s.target);
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 3));

        // Put the marker partway through the window, so it is nowhere in
        // the tail and has unread events above it inside the window.
        final windowIds = s.context.map((e) => e.eventId).toList();
        s.room.fullyReadId = windowIds[windowIds.length ~/ 2];
        expect(
          s.room.live.events.any((e) => e.eventId == s.room.fullyReadId),
          isFalse,
          reason: 'precondition: the marker is not in the tail',
        );

        final pagesBefore = s.room.live.historyRequests;
        await tester.tap(find.byKey(const ValueKey(kUnreadPillKey)));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(seconds: 3));

        expect(tester.takeException(), isNull);
        expect(
          s.room.live.historyRequests,
          pagesBefore,
          reason: 'a marker already on screen must not send the pager '
              'looking for it',
        );
      },
    );

  testWidgets(
    'a jump into an already-loaded window is a scroll, not a fetch',
    (tester) async {
      // The window's event, not the tail's. A lookup that consults only
      // `timeline.events` would not find it here, refetch, and then hit the
      // duplicate-id guard, which is a crash rather than a refetch. This is
      // what makes jumping between two places the user has already been
      // cheap instead of a round trip each time.
      final s = _setup();

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));
      final afterFirst = s.room.contextRequests.length;

      // Same target again: it is already in the store, so this is a scroll.
      final store = _store(tester)!;
      final before = store.history.length;

      // A point inside the window we already loaded. The store lookup finds
      // it; a tail-only lookup does not, and refetches instead.
      final insideWindow = s.context[5].eventId;
      await _state(tester).jumpToEvent(insideWindow);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(s.room.contextRequests.length, afterFirst,
          reason: 'a point already in the store must not be refetched');
      expect(store.history.length, before,
          reason: 'and must not add a window');
    },
  );

  testWidgets(
    'a jump to an event already in the cache does not refetch',
    (tester) async {
      final s = _setup();
      final cached = '\$ev1';

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(cached);
      await tester.pump();
      await tester.pump();

      expect(
        s.room.contextRequests,
        isEmpty,
        reason: 'the cheap path must stay cheap; a /context round trip '
            'for an event already in memory is a regression',
      );

      // A successful jump arms a 2s highlight timer; let it clear so
      // the test does not end with a pending timer.
      await tester.pump(const Duration(seconds: 3));
    },
  );

  testWidgets(
    'a failed context load keeps the live view and says so',
    (tester) async {
      // A silent no-op is indistinguishable from a broken button, which
      // is exactly how the old cache-only path read.
      final s = _setup()..room.failContextRequests = true;

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        _state(tester).isViewingHistoryWindow,
        isFalse,
        reason: 'the live tail must survive a failed jump',
      );
      expect(find.textContaining('no longer available'), findsOneWidget);
    },
  );

  group('read paths span every loaded window', () {
    testWidgets('the unread count includes events in a window', (tester) async {
      // The pill counted the live tail alone. Everything in the tail is
      // newer than a window, so with the marker *inside* the window the
      // events between the marker and the tail's start are unread and
      // visible, and a tail-only count misses every one of them: it stops at
      // the marker, which is not in the tail at all, so it counts the whole
      // tail and nothing else.
      final s = _setup();
      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Put the marker partway through the window.
      final windowIds = s.context.map((e) => e.eventId).toList();
      s.room.fullyReadId = windowIds[windowIds.length ~/ 2];

      final store = _store(tester)!;
      expect(
        store.live.events.any((e) => e.eventId == s.room.fullyReadId),
        isFalse,
        reason: 'precondition: the marker is not in the tail',
      );
      // The window's own events sit between the marker and the tail.
      final markerAt = s.context.indexWhere((e) => e.eventId == s.room.fullyReadId);
      expect(markerAt, greaterThan(0),
          reason: 'precondition: newer window events exist to be missed');

      // The count itself is the claim, not the pill's presence: a tail-only
      // walk never finds the marker, so it counts the entire tail and reports
      // a number that happens to be non-zero anyway. Asserting "a pill is
      // visible" passes under both implementations.
      // The window is OLDER than the tail, so the render list runs newest-first:
      // tail first, then the window. Everything is newer than a marker that
      // sits inside the window, so the count is the whole render list. The
      // tail-only walk never finds that marker and counts the whole tail, so
      // the two differ by the window's size.
      final tailLength = store.live.events.length;
      final windowLength = s.context.length;
      expect(store.flatten().length, tailLength + windowLength,
          reason: 'precondition: no overlap between the two segments');
      final expected = tailLength + windowLength;

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // The label is the assertion. A tail-only walk reports a non-zero
      // number too, so asserting "a pill is visible" passes under both
      // implementations and proves nothing.
      expect(find.text('$expected new messages'), findsOneWidget,
          reason: 'every event on screen is newer than a marker inside the '
              'window');
    });

    testWidgets('a marker inside a window is found without refetching',
        (tester) async {
      // The coordinator searched the tail for the read marker. A marker in a
      // window missed the fast path, entered the paginating branch, and
      // spent the budget looking for something already on screen.
      final s = _setup();
      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      // Put the marker on an event that only the window holds.
      final windowIds = s.context.map((e) => e.eventId).toSet();
      s.room.fullyReadId = windowIds.elementAt(windowIds.length ~/ 2);
      expect(_store(tester)!.live.events.any(
            (e) => e.eventId == s.room.fullyReadId,
          ), isFalse,
          reason: 'precondition: the marker is not in the tail');

      final before = s.room.contextRequests.length;
      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump(const Duration(seconds: 2));

      expect(tester.takeException(), isNull);
      expect(s.room.contextRequests.length, before,
          reason: 'a jump already satisfied by the cache must not refetch');
    });
  });
}
