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

// End-to-end pins for the read-position fix.  These build a real
// rendered timeline because the bug lived in the seam between the
// scroll position and the receipt, and a mock of either side would
// not have caught it.
//
// The two behaviours under test:
//  1. Opening a room posts a receipt for the oldest message on screen,
//     never the newest message in the cache.  Retiring the whole unread
//     tail on open is what made the jump-to-unread pill useless.
//  2. Dismissing the pill is scoped to the newest event that existed at
//     the time, so a later sync brings the affordance back instead of
//     latching it off for the session.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../helpers/renderable_timeline.dart';

void main() {
  testWidgets(
    'opening a room posts a receipt for the oldest message on screen, '
    'not the newest in the cache',
    (tester) async {
      final live = RenderableTimeline();
      final room = RenderableRoom(live);
      final seeded = seedTimeline(room, live);
      room.fullyReadId = 'read-marker-below-everything';

      await tester.pumpWidget(wrapChatTimeline(room));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(room.posted, isNotEmpty,
          reason: 'a receipt should be posted for what is on screen');

      final newest = '\$${seeded.ids.first}';
      expect(
        room.posted,
        isNot(contains(newest)),
        reason: 'the newest message sits below the fold at open time, so '
            'marking it read retires the entire unread tail above it',
      );
    },
  );

  testWidgets(
    'the jump-to-unread pill is visible when the room opens with unread',
    (tester) async {
      final live = RenderableTimeline();
      final room = RenderableRoom(live);
      seedTimeline(room, live);
      room.fullyReadId = 'read-marker-below-everything';

      await tester.pumpWidget(wrapChatTimeline(room));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey(kUnreadPillKey)), findsOneWidget);
    },
  );

  testWidgets(
    'dismissing the pill hides it, and a later message brings it back',
    (tester) async {
      final live = RenderableTimeline();
      final room = RenderableRoom(live);
      seedTimeline(room, live);
      room.fullyReadId = 'read-marker-below-everything';

      await tester.pumpWidget(wrapChatTimeline(room));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey(kUnreadPillKey)), findsOneWidget);

      // The pill carries a dismiss affordance; tapping it is the only
      // thing that should hide it.
      final dismiss = find.descendant(
        of: find.byKey(const ValueKey(kUnreadPillKey)),
        matching: find.byIcon(LucideIcons.x),
      );
      expect(dismiss, findsOneWidget);
      await tester.tap(dismiss);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey(kUnreadPillKey)), findsNothing);

      // A new message arrives by sync.  The dismissal was scoped to the
      // event that existed when the user closed it, so the pill owes
      // them another look.
      room.deliverNewEvent(makeMessageEvent(room, 'fresh', 999000));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byKey(const ValueKey(kUnreadPillKey)), findsOneWidget);
    },
  );
}
