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

// Regression test for the jump-to-unread scroll path.  The FAB routes
// through [TimelineView.scrollToEventId] -> `_doScrollToEvent`, which
// used to fall back to [TimelineScrollTarget.scrollToFraction] with the
// default `skipIfClose: true`.  When the target item is just past the
// built window (so there is no GlobalKey for `ensureVisible`) but the
// fraction estimate still lands within 60% of the viewport, that default
// silently dropped the scroll: the pill dismissed and the room was marked
// read while the view never moved.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/settings/display_type.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

void main() {
  late MockTimeline timeline;
  late MockRoom room;
  late MockClient client;
  late MockUser sender;
  late MockEncryptionService encryption;

  setUpAll(() {
    registerFallbackValue(MockTimeline());
    registerFallbackValue(RelationshipTypes.edit);
  });

  setUp(() {
    timeline = MockTimeline();
    room = MockRoom();
    client = MockClient();
    sender = MockUser();
    encryption = MockEncryptionService();

    when(() => room.client).thenReturn(client);
    when(() => room.canChangeStateEvent(any())).thenReturn(false);

    when(() => sender.calcDisplayname()).thenReturn('Alice');
    when(() => sender.id).thenReturn('@alice:dom');

    when(() => encryption.isUserVerifiedById(any())).thenReturn(false);

    // 48 short text messages, all from the same sender on the same day,
    // newest first (index 0 = newest).  Same-sender grouping keeps every
    // message a compact continuation bubble (~25px each), so the list is
    // tall enough to scroll but the newest item stays out of the
    // ListView's built window once the view is scrolled into history.
    final events = <MockEvent>[];
    for (var i = 0; i < 48; i++) {
      final event = MockEvent();
      when(() => event.eventId).thenReturn('evt_$i');
      when(() => event.hasAggregatedEvents(any(), any())).thenReturn(false);
      when(() => event.aggregatedEvents(any(), any())).thenReturn(<Event>{});
      when(() => event.receipts).thenReturn(<Receipt>[]);
      when(() => event.getDisplayEvent(any())).thenReturn(event);
      when(() => event.redacted).thenReturn(false);
      when(() => event.type).thenReturn(EventTypes.Message);
      when(() => event.messageType).thenReturn(MessageTypes.Text);
      when(() => event.body).thenReturn('hi');
      when(() => event.senderId).thenReturn('@alice:dom');
      when(() => event.senderFromMemoryOrFallback).thenReturn(sender);
      when(() => event.originServerTs)
          .thenReturn(DateTime(2025, 6, 14, 10, 30));
      when(() => event.content).thenReturn(const {'body': 'hi', 'msgtype': 'm.text'});
      events.add(event);
    }
    when(() => timeline.events).thenReturn(events);
  });

  Widget buildApp(ScrollController controller) {
    return wrapWithProviders(
      encryptionService: encryption,
      child: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: TimelineView(
            timeline: timeline,
            room: room,
            displayType: DisplayType.modern,
            scrollController: controller,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'jump to the newest event scrolls even when the estimate is "close"',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);

      await tester.pumpWidget(buildApp(controller));
      await tester.pump();

      expect(controller.position.haveDimensions, isTrue);

      // Scroll up into history so the newest message sits just past the
      // built window but its fraction estimate is within 60% of the
      // viewport (offset 345 < 360).  This used to suppress the scroll.
      final maxExtent = controller.position.maxScrollExtent;
      controller.jumpTo(maxExtent.clamp(0, 345));
      await tester.pump();
      final before = controller.offset;

      final view = tester.state<TimelineViewState>(find.byType(TimelineView));
      view.scrollToEventId('evt_0');

      // Let the 300ms animateTo finish, then drain the 2s highlight
      // timer so the test doesn't end with a pending timer.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pump(const Duration(seconds: 2));

      expect(controller.offset, lessThan(60));
      expect(controller.offset, lessThan(before));
    },
  );
}
