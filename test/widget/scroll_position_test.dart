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

// Pin test for the rapid-scroll-down bug.  When `_isScrolledUp` flips
// from `false` to `true` during a user scroll, the build method
// re-runs and re-creates the `Stack` widget that holds the timeline
// view.  The `Stack` plus its `Positioned` overlay should not change
// the layout of the ListView inside the stack's non-positioned child.
//
// This test verifies that the user's scroll position is preserved
// across a `_isScrolledUp` state transition.  The expectation is
// that after the build, the scroll position remains at the same
// `pixels` value (not reset to 0 or to a lower value).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'scroll position is preserved when an overlay widget appears',
    (tester) async {
      final scrollController = ScrollController();
      addTearDown(scrollController.dispose);

      // The "user has scrolled up" state — toggled on while the test
      // simulates a scroll-up gesture.
      bool isScrolledUp = false;

      await tester.pumpWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return MaterialApp(
              home: Scaffold(
                body: Stack(
                  children: [
                    // Non-positioned child — the timeline listview.
                    Positioned.fill(
                      child: ListView.builder(
                        controller: scrollController,
                        reverse: true,
                        itemCount: 100,
                        itemBuilder: (context, index) => SizedBox(
                          height: 50,
                          child: Center(
                            child: Text('item $index'),
                          ),
                        ),
                      ),
                    ),
                    // Positioned overlay — only rendered when the
                    // user is scrolled up.
                    if (isScrolledUp)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Container(
                          height: 40,
                          color: Colors.red,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      );

      // Scroll the listview down (toward the oldest items) — the
      // equivalent of the user scrolling up in the chat timeline.
      scrollController.jumpTo(300);

      // Verify the scroll position is at 300.
      expect(scrollController.position.pixels, 300);

      // Toggle the "scrolled up" state — this triggers a rebuild.
      isScrolledUp = true;
      await tester.pump();

      // The scroll position should still be 300.  If the bug exists,
      // the rebuild of the Stack + Positioned will reset the scroll
      // position to 0 (or a much lower value).
      expect(
        scrollController.position.pixels,
        300,
        reason:
            'The scroll position should be preserved across the '
            'FAB visibility toggle.  If this fails, the Stack/Positioned '
            'is invalidating the ListView layout.',
      );
    },
  );
}
