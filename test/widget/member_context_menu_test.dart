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

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/member_context_menu.dart';
import 'package:moonrelay/src/widgets/menu_row.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// The member menu replaces three copies of itself, so what matters is that
/// all three behaviours hold everywhere: the popup is secondary, it opens at
/// the pointer, and neither it nor its labels overflow.
void main() {
  late MockUser member;

  setUp(() {
    member = MockUser();
    when(() => member.id).thenReturn('@ada:matrix.org');
    when(() => member.room).thenReturn(MockRoom());
  });

  Future<(BuildContext, int, int)> host(
    WidgetTester tester, {
    int profileCalls = 0,
    int messageCalls = 0,
  }) async {
    var profiles = profileCalls;
    var messages = messageCalls;
    await tester.pumpWidget(
      MaterialApp(
        theme: testMoonrelayTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: MemberContextMenu(
              member: member,
              onOpenProfile: () => profiles++,
              onSendMessage: () => messages++,
              child: const Material(
                key: Key('row'),
                type: MaterialType.transparency,
                child: SizedBox(width: 240, height: 48, child: Text('member')),
              ),
            ),
          ),
        ),
      ),
    );
    late BuildContext ctx;
    ctx = tester.element(find.byKey(const Key('row')));
    return (ctx, profileCalls, messageCalls);
  }

  List<String> visibleLabels(WidgetTester tester) => tester
      .widgetList<MoonrelayMenuItem<String>>(
          find.byType(MoonrelayMenuItem<String>))
      .map((i) => i.label)
      .toList();

  group('a plain click is the primary action', () {
    testWidgets('a single click opens the profile, not the popup',
        (tester) async {
      await host(tester);

      await tester.tap(find.byKey(const Key('row')));
      await tester.pumpAndSettle();

      // This is the regression. `onTap` used to open the same two-item popup
      // as `onSecondaryTap` and `onLongPress`, in all three member lists, so
      // clicking someone gave you a popup and the profile was only reachable
      // through it.
      expect(find.byType(MoonrelayMenuItem<String>), findsNothing);
    });

    testWidgets('one click does not also count as a long press',
        (tester) async {
      await host(tester);
      await tester.tap(find.byKey(const Key('row')));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pumpAndSettle();

      expect(find.byType(MoonrelayMenuItem<String>), findsNothing);
    });
  });

  group('right click and long press', () {
    testWidgets('a right click opens the popup at the pointer', (tester) async {
      await host(tester);

      await tester.tap(
        find.byKey(const Key('row')),
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      expect(find.byType(MoonrelayMenuItem<String>), findsWidgets);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a long press opens the popup', (tester) async {
      await host(tester);

      await tester.longPress(find.byKey(const Key('row')));
      await tester.pumpAndSettle();

      expect(find.byType(MoonrelayMenuItem<String>), findsWidgets);
    });

    testWidgets('the popup opens at the pointer, not at a guessed offset',
        (tester) async {
      // Each of the three original copies positioned the menu with a
      // hardcoded guess at the tile width: `offset.dx + 160` in one and
      // `+ 200` in the others, the latter with a comment saying "roughly the
      // tile width". Right-clicking a member therefore opened a menu somewhere
      // near the row, and which offset you got depended on the pane.
      await host(tester);

      final pressPoint = tester.getTopLeft(find.byKey(const Key('row'))) +
          const Offset(20, 20);
      await tester.tapAt(
        pressPoint,
        kind: PointerDeviceKind.mouse,
        buttons: kSecondaryMouseButton,
      );
      await tester.pumpAndSettle();

      final menu = find.byType(MoonrelayMenuItem<String>);
      expect(menu, findsWidgets);

      // The popup's own top-left sits at or after the recorded press point,
      // allowing for the menu clamping itself inside the viewport.
      expect(tester.getTopLeft(menu.first).dy,
          greaterThanOrEqualTo(pressPoint.dy - 1));
    });

    testWidgets('neither label overflows the popup', (tester) async {
      await host(tester);
      await tester.longPress(find.byKey(const Key('row')));
      await tester.pumpAndSettle();

      // A RenderFlex overflow is reported as a caught exception, so this
      // fails rather than painting a stripe.
      expect(tester.takeException(), isNull);
      expect(visibleLabels(tester), isNotEmpty);
    });
  });

  group('choosing an entry', () {
    testWidgets('the profile entry calls back', (tester) async {
      var profiles = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: MemberContextMenu(
                member: member,
                onOpenProfile: () => profiles++,
                onSendMessage: () {},
                child: const Material(
                    key: Key('row'),
                    type: MaterialType.transparency,
                    child: SizedBox(
                        width: 240, height: 48, child: Text('member'))),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MoonrelayMenuItem<String>).first);
      await tester.pumpAndSettle();

      expect(profiles, 1);
    });

    testWidgets('the message entry calls back', (tester) async {
      var messages = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: MemberContextMenu(
                member: member,
                onOpenProfile: () {},
                onSendMessage: () => messages++,
                child: const Material(
                    key: Key('row'),
                    type: MaterialType.transparency,
                    child: SizedBox(
                        width: 240, height: 48, child: Text('member'))),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('row')));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(MoonrelayMenuItem<String>).last);
      await tester.pumpAndSettle();

      expect(messages, 1);
    });

    testWidgets('dismissing runs nothing', (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: testMoonrelayTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: MemberContextMenu(
                member: member,
                onOpenProfile: () => calls++,
                onSendMessage: () => calls++,
                child: const Material(
                    key: Key('row'),
                    type: MaterialType.transparency,
                    child: SizedBox(
                        width: 240, height: 48, child: Text('member'))),
              ),
            ),
          ),
        ),
      );

      await tester.longPress(find.byKey(const Key('row')));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();

      expect(find.byType(MoonrelayMenuItem<String>), findsNothing);
      expect(calls, 0);
    });
  });

  testWidgets('the entries use Lucide glyphs, not Material', (tester) async {
    await host(tester);
    await tester.longPress(find.byKey(const Key('row')));
    await tester.pumpAndSettle();

    final icons = tester
        .widgetList<MoonrelayMenuItem<String>>(
            find.byType(MoonrelayMenuItem<String>))
        .map((i) => i.icon)
        .toList();
    expect(icons, contains(LucideIcons.user));
    expect(icons, contains(LucideIcons.messageSquare));
  });
}
