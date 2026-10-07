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

// Contract tests for the floating action column above the chat composer.
//
// These drive the real [ChatTimelineFloatingActions].  The previous version of
// this file rebuilt copies of both pills locally, which is why it passed
// while the production class documented a priority between them that its own
// code did not implement.  A test that exercises a copy of the thing it is
// testing cannot catch the thing's contract changing.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/chat_timeline_floating_actions.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

void main() {
  Future<void> pumpColumn(
    WidgetTester tester, {
    required bool unreadVisible,
    required bool scrolledUp,
    int unreadCount = 3,
    VoidCallback? onJumpToBottom,
    VoidCallback? onDismiss,
    Future<void> Function()? onJumpToUnread,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: ChatTimelineFloatingActions(
              unreadCount: unreadCount,
              isScrolledUp: scrolledUp,
              unreadVisible: unreadVisible,
              isJumping: false,
              onJumpToUnread: onJumpToUnread ?? () async {},
              onJumpToBottom: onJumpToBottom ?? () {},
              onDismissUnread: onDismiss ?? () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder unreadPill() => find.byKey(const ValueKey('jump-to-unread'));
  Finder bottomPill() => find.byKey(const ValueKey('scroll-to-bottom'));

  group('two independent pills', () {
    testWidgets('neither pill when at the bottom with no unreads',
        (tester) async {
      await pumpColumn(tester, unreadVisible: false, scrolledUp: false);
      expect(unreadPill(), findsNothing);
      expect(bottomPill(), findsNothing);
    });

    testWidgets('only the unread pill when at the bottom', (tester) async {
      await pumpColumn(tester, unreadVisible: true, scrolledUp: false);
      expect(unreadPill(), findsOneWidget);
      expect(bottomPill(), findsNothing);
    });

    testWidgets('only the bottom pill when scrolled up', (tester) async {
      await pumpColumn(tester, unreadVisible: false, scrolledUp: true);
      expect(unreadPill(), findsNothing);
      expect(bottomPill(), findsOneWidget);
    });

    testWidgets('BOTH pills when scrolled up with unreads', (tester) async {
      // The claim this file exists for. They answer different questions:
      // "where is the unread" and "where is the new". A room with unreads
      // while the user is scrolled up has both, and the old code rendered
      // only one despite documenting the opposite.
      await pumpColumn(tester, unreadVisible: true, scrolledUp: true);
      expect(unreadPill(), findsOneWidget);
      expect(bottomPill(), findsOneWidget);
    });
  });

  group('jump to bottom', () {
    testWidgets('says scroll to bottom and never "back to latest"',
        (tester) async {
      // There is no longer a separate "back to latest" mode. It existed
      // because the timeline used to be substituted with a history window,
      // so returning to the live head meant rebuilding. With the windows in
      // the same list as the tail it is a scroll like any other.
      await pumpColumn(tester, unreadVisible: false, scrolledUp: true);
      final l10n = AppLocalizations.of(
        tester.element(find.byType(ChatTimelineFloatingActions)),
      )!;
      expect(find.text(l10n.scrollToBottom), findsOneWidget);
      expect(find.text(l10n.backToLatest), findsNothing);
    });

    testWidgets('tapping it fires the callback', (tester) async {
      var taps = 0;
      await pumpColumn(
        tester,
        unreadVisible: false,
        scrolledUp: true,
        onJumpToBottom: () => taps++,
      );
      await tester.tap(bottomPill());
      await tester.pump();
      expect(taps, 1);
    });
  });

  group('jump to unread', () {
    testWidgets('tapping it fires the callback', (tester) async {
      var taps = 0;
      await pumpColumn(
        tester,
        unreadVisible: true,
        scrolledUp: false,
        onJumpToUnread: () async => taps++,
      );
      await tester.tap(find.text('3 new messages'));
      await tester.pump();
      expect(taps, 1);
    });

    testWidgets('the dismiss control fires separately', (tester) async {
      // Dismissing hides the pill but must not count as a jump; conflating
      // them made a dismiss look like the user acted on the unread.
      var jumps = 0;
      var dismissals = 0;
      await pumpColumn(
        tester,
        unreadVisible: true,
        scrolledUp: false,
        onJumpToUnread: () async => jumps++,
        onDismiss: () => dismissals++,
      );
      await tester.tap(find.bySemanticsLabel('Dismiss'));
      await tester.pump();
      expect(dismissals, 1);
      expect(jumps, 0);
    });
  });

  group('loading states', () {
    testWidgets('the context loading pill replaces the unread pill',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: ChatTimelineFloatingActions(
                unreadCount: 3,
                isScrolledUp: true,
                unreadVisible: true,
                isJumping: true,
                loadingContext: true,
                onJumpToUnread: () async {},
                onJumpToBottom: () {},
                onDismissUnread: () {},
              ),
            ),
          ),
        ),
      );
      // Not pumpAndSettle: the spinner animates forever, so the frame
      // scheduler never goes quiet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // A tap has to be acknowledged, or it reads as an unresponsive button.
      expect(
        find.byKey(const ValueKey('context-loading')),
        findsOneWidget,
      );
      // And the bottom pill is unaffected by that.
      expect(bottomPill(), findsOneWidget);
    });
  });
}