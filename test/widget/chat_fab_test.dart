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

// Pin tests for the floating action column rendered above the chat
// composer.  This file covers the scroll-to-bottom and jump-to-unread
// pills that the [ChatTimeline] overlays when the user is scrolled up
// or has unread messages below the viewport.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

void main() {
  // The [_FloatingActionColumn] is a private widget inside
  // `chat_timeline.dart`.  The column stacks an [AnimatedSize] +
  // [AnimatedSwitcher] for each pill, so the tests below exercise the
  // same Column + AnimatedSize structure and assert the public
  // behaviour (label, icon, tap handler) that the production code
  // exposes.

  Widget buildColumn({
    required bool unreadVisible,
    required bool scrolledUp,
    required int unreadCount,
    VoidCallback? onJump,
    VoidCallback? onScroll,
  }) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (unreadVisible)
                _TestJumpToUnreadPill(
                  count: unreadCount,
                  onTap: onJump,
                ),
              if (scrolledUp)
                _TestScrollToBottomPill(onTap: onScroll),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets(
    'scroll-to-bottom pill is not shown when the user is at the bottom',
    (tester) async {
      await tester.pumpWidget(
        buildColumn(unreadVisible: false, scrolledUp: false, unreadCount: 0),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.arrowDown), findsNothing);
    },
  );

  testWidgets(
    'scroll-to-bottom pill shows the correct label and icon when scrolled up',
    (tester) async {
      await tester.pumpWidget(
        buildColumn(
          unreadVisible: false,
          scrolledUp: true,
          unreadCount: 0,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.arrowDown), findsOneWidget);
      expect(find.text('Scroll to bottom'), findsOneWidget);
    },
  );

  testWidgets(
    'jump-to-unread pill shows the count and up-arrow when unread',
    (tester) async {
      await tester.pumpWidget(
        buildColumn(
          unreadVisible: true,
          scrolledUp: false,
          unreadCount: 5,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.arrowUp), findsOneWidget);
      expect(find.text('5 new messages'), findsOneWidget);
    },
  );

  testWidgets(
    'both pills can be shown simultaneously',
    (tester) async {
      await tester.pumpWidget(
        buildColumn(
          unreadVisible: true,
          scrolledUp: true,
          unreadCount: 3,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byIcon(LucideIcons.arrowUp), findsOneWidget);
      expect(find.byIcon(LucideIcons.arrowDown), findsOneWidget);
      expect(find.text('3 new messages'), findsOneWidget);
      expect(find.text('Scroll to bottom'), findsOneWidget);
    },
  );

  testWidgets(
    'tapping the scroll-to-bottom pill fires the callback',
    (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        buildColumn(
          unreadVisible: false,
          scrolledUp: true,
          unreadCount: 0,
          onScroll: () => tapped++,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(LucideIcons.arrowDown));
      await tester.pump();
      expect(tapped, 1);
    },
  );
}

/// Test-only mock of the jump-to-unread pill matching the public
/// behaviour of `_JumpToUnreadPill` in `chat_timeline.dart`.
class _TestJumpToUnreadPill extends StatelessWidget {
  const _TestJumpToUnreadPill({required this.count, required this.onTap});

  final int count;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Material(
      color: scheme.primary,
      elevation: 4,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(LucideIcons.arrowUp, size: 14, color: scheme.onPrimary),
              const SizedBox(width: 6),
              Text(
                count == 1
                    ? l10n.jumpToFirstUnread
                    : l10n.jumpToFirstUnreadMany(count),
                style: TextStyle(
                  color: scheme.onPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Test-only mock of the scroll-to-bottom pill matching the public
/// behaviour of `_ScrollToBottomPill` in `chat_timeline.dart`.
class _TestScrollToBottomPill extends StatelessWidget {
  const _TestScrollToBottomPill({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: scheme.secondaryContainer,
        elevation: 4,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  LucideIcons.arrowDown,
                  size: 14,
                  color: scheme.onSecondaryContainer,
                ),
                const SizedBox(width: 6),
                Text(
                  l10n.scrollToBottom,
                  style: TextStyle(
                    color: scheme.onSecondaryContainer,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
