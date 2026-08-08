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

// Contract tests for [TimelineScrollTarget], the shared scroll-to-index
// helper.  The jump-to-unread path relies on these semantics: user-
// invoked jumps must always move the view, so callers that want a
// guaranteed scroll pass `skipIfClose: false` rather than relying on
// the default suppression heuristic.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/timeline_scroll_target.dart';

void main() {
  // 20 items of 100px in a 600px viewport -> maxScrollExtent 1400.
  Widget buildHarness(ScrollController controller) {
    return MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 600,
          child: ListView.builder(
            controller: controller,
            itemCount: 20,
            itemBuilder: (_, __) => const SizedBox(height: 100),
          ),
        ),
      ),
    );
  }

  testWidgets(
    'skipIfClose:false scrolls to a target the default would suppress',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(buildHarness(controller));

      // Target idx 4: estimated offset = 4/19 * 1400 ~= 295px, inside
      // the 60% (360px) suppression window.  With the default
      // `skipIfClose` this call would be a no-op.
      TimelineScrollTarget.scrollToFraction(
        controller,
        4,
        20,
        skipIfClose: false,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // 295 - 0.33 * 600 = 97 (one-third-from-top padding).
      expect(controller.offset, closeTo(97, 5));
    },
  );

  testWidgets('default skipIfClose suppresses a close target', (tester) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(buildHarness(controller));

    TimelineScrollTarget.scrollToFraction(controller, 4, 20);
    await tester.pump(const Duration(milliseconds: 400));

    expect(controller.offset, 0);
  });
}
