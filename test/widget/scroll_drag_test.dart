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

// Reproduction attempt: the user reports that scrolling up in the
// chat timeline rapidly jumps back down, making it impossible to
// scroll up.  The hypothesis is that an FAB overlay widget shown
// when `_isScrolledUp = true` re-creates the Stack on every scroll
// event, and the rebuild somehow invalidates the ListView's scroll
// position.
//
// This test sets up a minimal chat-like layout: a reverse ListView
// with a Positioned overlay that toggles on every scroll event.  We
// simulate a drag up the list (away from the bottom) and check that
// the user's scroll position does NOT snap back to the bottom.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'drag up keeps the FAB visible and the scroll position is preserved',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      // Mirrors `_isScrolledUp` — the FAB visibility flag in
      // production.
      bool isScrolledUp = false;
      // The actual "rebuild" we trigger after `setState` in
      // production.  In a real widget tree, `setState` is called
      // inside the State and a rebuild is scheduled.
      void Function() requestRebuild = () {};

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            requestRebuild = () => setState(() {});
            return MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    Positioned.fill(
                      child: ListView.builder(
                        controller: scrollController,
                        reverse: true,
                        itemCount: 100,
                        itemBuilder: (context, index) => SizedBox(
                          height: 50,
                          child: Center(child: Text('item $index')),
                        ),
                      ),
                    ),
                    if (isScrolledUp)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Container(height: 40, color: Colors.red),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      // The same scroll-listener pattern used in chat_timeline.dart's
      // `_onScroll`: when `pixels > 200`, set `_isScrolledUp = true`.
      scrollController.addListener(() {
        if (scrollController.position.pixels > 200 && !isScrolledUp) {
          isScrolledUp = true;
          requestRebuild();
        }
      });

      // Drag up (toward older messages in a reverse list).
      // Use programmatic scroll to mimic what the user does.
      scrollController.jumpTo(500);
      await tester.pumpAndSettle();

      // After the drag, pixels should be > 0 — the user has scrolled up.
      expect(
        scrollController.position.pixels,
        greaterThan(200),
        reason: 'scroll should have moved pixels past the FAB threshold',
      );

      // After the rebuild, the FAB should be in the tree.
      expect(find.byType(Container), findsOneWidget);
    },
  );
}
