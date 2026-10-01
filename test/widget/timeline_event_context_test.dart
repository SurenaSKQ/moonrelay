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

// Jumping to an event that is not in the local cache (WORK_NEEDED.md
// 8.4).  The live timeline is anchored to the tail of the room and
// cannot page forward, so the old code simply returned and the jump did
// nothing.  These pin the replacement: build a `/context` window around
// the event, show it, and offer a way back to the live tail.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';

import '../helpers/renderable_timeline.dart';

/// Sets up a room whose live timeline holds [liveCount] messages, and a
/// separate `/context` window holding [contextCount] messages around
/// `$target`.
({RenderableRoom room, RenderableTimeline context, String target}) _setup({
  int liveCount = 20,
  int contextCount = 30,
}) {
  final live = RenderableTimeline();
  final room = RenderableRoom(live);
  seedTimeline(room, live, count: liveCount);
  room.fullyReadId = 'read-marker-below-everything';

  // A `/context` window: the SDK marks these fragmented, so the SDK's
  // own `canRequestHistory` is false while the window still carries a
  // usable `prevBatch`.
  final context = RenderableTimeline(canPageOlder: false, prevToken: 'tok');
  const target = '\$ancient';
  context.setAll([
    for (var i = contextCount; i >= 1; i--)
      makeMessageEvent(room, 'ancient$i', 500000 + i),
  ]);
  // The target is the middle of the window, so it is not at either edge.
  room.context = context;
  return (room: room, context: context, target: target);
}

ChatTimelineState _state(WidgetTester tester) =>
    tester.state<ChatTimelineState>(find.byType(ChatTimeline));

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

      expect(
        s.room.contextRequests,
        [s.target],
        reason: 'the event is not in the live cache, so a /context window '
            'is the only way to reach it',
      );
    },
  );

  testWidgets(
    'the previous timeline is detached before the window is shown',
    (tester) async {
      // A `/context` window is still a `Timeline` and subscribes to
      // onSync.  Left subscribed, the SDK deletes every event in the
      // window on the next gap-limited sync.
      final s = _setup();

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump();

      expect(s.room.live.subscriptionsCancelled, isTrue);
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

      expect(_state(tester).isViewingHistoryWindow, isTrue);
    },
  );

  testWidgets(
    'the unread pill is suppressed inside a context window',
    (tester) async {
      // The window does not contain the read marker, so every event in
      // it counts as unread.  Offering "jump to first unread" there
      // points at a target the window cannot reach.
      final s = _setup();

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.byKey(const ValueKey(kUnreadPillKey)), findsOneWidget);

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey(kUnreadPillKey)), findsNothing);
    },
  );

  testWidgets(
    'back to latest returns to the live tail',
    (tester) async {
      final s = _setup();

      await tester.pumpWidget(wrapChatTimeline(s.room));
      await tester.pump();
      await tester.pump();

      await _state(tester).jumpToEvent(s.target);
      await tester.pump();
      await tester.pump();
      expect(_state(tester).isViewingHistoryWindow, isTrue);

      await _state(tester).backToLive();
      await tester.pump();
      await tester.pump();

      expect(_state(tester).isViewingHistoryWindow, isFalse);
      // The window is detached on the way out, for the same reason it
      // was detached on the way in.
      expect(s.context.subscriptionsCancelled, isTrue);
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
}
