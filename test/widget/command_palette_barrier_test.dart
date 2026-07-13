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

// Widget tests for the [BarrierDismissableOverlay] helper and the
// command palette / hub overlay outside-tap dismissal behaviour.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:moonrelay/src/widgets/blur_background.dart';

void main() {
  group('BarrierDismissableOverlay', () {
    testWidgets(
      'tapping outside the content dismisses the route via Navigator.maybePop',
      (tester) async {
        bool popped = false;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [_PopObserver(() => popped = true)],
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      PageRouteBuilder(
                        opaque: false,
                        barrierDismissible: true,
                        barrierColor: Colors.transparent,
                        pageBuilder: (_, __, ___) => Scaffold(
                          backgroundColor: Colors.transparent,
                          body: BarrierDismissableOverlay(
                            child: Center(
                              child: Container(
                                width: 100,
                                height: 100,
                                color: Colors.blue,
                                child: const Center(
                                  child: Text('inside'),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('inside'), findsOneWidget);

        // Tap outside the centered card.
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(popped, isTrue,
            reason: 'tapping outside the overlay should dismiss the route');
      },
    );

    testWidgets(
      'tapping inside the content does NOT dismiss the route',
      (tester) async {
        bool popped = false;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [_PopObserver(() => popped = true)],
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      PageRouteBuilder(
                        opaque: false,
                        barrierDismissible: true,
                        barrierColor: Colors.transparent,
                        pageBuilder: (_, __, ___) => Scaffold(
                          backgroundColor: Colors.transparent,
                          body: BarrierDismissableOverlay(
                            child: Center(
                              child: BarrierDismissBoundary(
                                child: GestureDetector(
                                  onTap: () {},
                                  child: Container(
                                    width: 200,
                                    height: 200,
                                    color: Colors.blue,
                                    child: const Center(
                                      child: Text('inside'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('inside'), findsOneWidget);

        // Tap inside the card.
        await tester.tap(find.text('inside'));
        await tester.pump();
        expect(popped, isFalse,
            reason: 'tapping inside the content should NOT dismiss the route');
        // The overlay is still on the stack.
        expect(find.text('inside'), findsOneWidget);
      },
    );

    testWidgets(
      'tapping empty space inside the card does NOT dismiss the route',
      (tester) async {
        // Verifies the bug fix where the helper used to dismiss on any
        // tap that hit the page but not a widget inside it (e.g. a
        // margin between rows).  Now only true outside-card taps
        // dismiss  the card marks itself with [BarrierDismissBoundary]
        // and the dismiss detector hit-tests that boundary.
        bool popped = false;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [_PopObserver(() => popped = true)],
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      PageRouteBuilder(
                        opaque: false,
                        barrierDismissible: true,
                        barrierColor: Colors.transparent,
                        pageBuilder: (_, __, ___) => Scaffold(
                          backgroundColor: Colors.transparent,
                          body: BarrierDismissableOverlay(
                            child: Center(
                              child: BarrierDismissBoundary(
                                child: SizedBox(
                                  width: 200,
                                  height: 200,
                                  child: ColoredBox(
                                    color: Colors.blue,
                                    child: const Align(
                                      alignment: Alignment.topLeft,
                                      child: Text('inside'),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('inside'), findsOneWidget);

        // Tap in the bottom-right corner of the card — empty space,
        // not on the 'inside' text.  This must not dismiss.
        final cardCenter = tester.getCenter(find.text('inside'));
        final cardSize = tester.getSize(find.text('inside'));
        final insideCard = Offset(
          cardCenter.dx + cardSize.width / 2 + 16,
          cardCenter.dy + 32,
        );
        await tester.tapAt(insideCard);
        await tester.pump();
        expect(popped, isFalse,
            reason:
                'tapping empty space inside the card must NOT dismiss');
        expect(find.text('inside'), findsOneWidget);

        // Tap well outside the card — true outside tap, must dismiss.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
        expect(popped, isTrue,
            reason: 'tapping outside the card should dismiss');
      },
    );

    testWidgets(
      'with enabled=false, tapping outside does NOT dismiss the route',
      (tester) async {
        bool popped = false;
        await tester.pumpWidget(
          MaterialApp(
            navigatorObservers: [_PopObserver(() => popped = true)],
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context, rootNavigator: true).push(
                      PageRouteBuilder(
                        opaque: false,
                        barrierDismissible: true,
                        barrierColor: Colors.transparent,
                        pageBuilder: (_, __, ___) => Scaffold(
                          backgroundColor: Colors.transparent,
                          body: BarrierDismissableOverlay(
                            enabled: false,
                            child: const Center(
                              child: Text('inside'),
                            ),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.text('inside'), findsOneWidget);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        expect(popped, isFalse,
            reason:
                'with enabled=false, outside-tap should not dismiss the route');
        // The overlay is still on the stack.
        expect(find.text('inside'), findsOneWidget);
      },
    );
  });
}

class _PopObserver extends NavigatorObserver {
  _PopObserver(this.onPop);
  final void Function() onPop;
  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    onPop();
    super.didPop(route, previousRoute);
  }
}
