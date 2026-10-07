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

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/message_context_menu.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/menu_row.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// The message menu had no keyboard route at all: right-click and long-press
/// were the only ways in, on every row, in every build of the app.
///
/// The interesting constraint is not the key binding, it is Tab order. The
/// obvious implementation, a [Focus] per row as a normal traversal stop, would
/// put two or three hundred Tab stops inside the conversation, so the rows are
/// focusable but skipped by traversal and the timeline aims at them.
class MockEncryptionService extends Mock implements EncryptionService {}

void main() {
  late MockEvent event;
  late MockRoom room;
  late MockClient client;
  late MockUser sender;
  late MockEncryptionService enc;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    event = MockEvent();
    room = MockRoom();
    client = MockClient();
    sender = MockUser();
    enc = MockEncryptionService();
    when(() => enc.isUserVerifiedById(any())).thenReturn(false);

    when(() => event.eventId).thenReturn(r'$evt_abc');
    when(() => event.body).thenReturn('hello world');
    when(() => event.canRedact).thenReturn(false);
    when(() => event.senderId).thenReturn('@other:matrix.org');
    when(() => event.type).thenReturn(EventTypes.Message);
    when(() => event.messageType).thenReturn(MessageTypes.Text);
    when(() => event.redacted).thenReturn(false);
    when(() => event.originServerTs)
        .thenReturn(DateTime.fromMillisecondsSinceEpoch(1700000000000));
    when(() => event.content)
        .thenReturn({'body': 'hello world', 'msgtype': 'm.text'});
    when(() => event.relationshipEventId).thenReturn(null);
    when(() => event.senderFromMemoryOrFallback).thenReturn(sender);
    when(() => event.status).thenReturn(EventStatus.synced);
    when(() => sender.calcDisplayname()).thenReturn('Other User');
    when(() => sender.id).thenReturn('@other:matrix.org');
    when(() => sender.canKick).thenReturn(false);
    when(() => sender.canBan).thenReturn(false);
    when(() => room.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:matrix.org');
    when(() => room.id).thenReturn('!room:matrix.org');
    when(() => room.unsafeGetUserFromMemoryOrFallback(any()))
        .thenAnswer((_) => sender);
    when(() => room.canChangeStateEvent('m.room.pinned_events'))
        .thenReturn(false);
    when(() => room.getState('m.room.pinned_events')).thenReturn(null);
  });

  Future<FocusNode> mountRow(
    WidgetTester tester, {
    FocusNode? node,
    GlobalKey? itemKey,
  }) async {
    final focusNode = node ?? FocusNode(debugLabel: 'row', skipTraversal: true);
    addTearDown(focusNode.dispose);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<Logger>.value(value: MockLogger()),
          ChangeNotifierProvider<EncryptionService>.value(value: enc),
          ChangeNotifierProvider<SettingsController>(
            create: (_) => createTestSettingsController(),
          ),
        ],
        child: MaterialApp(
          theme: testMoonrelayTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TimelineItem(
              event: event,
              room: room,
              displayType: DisplayType.modern,
              fontSize: 14,
              focusNode: focusNode,
              itemKey: itemKey,
              onAction: (_, __) {},
            ),
          ),
        ),
      ),
    );
    return focusNode;
  }

  group('a row can be given the keyboard cursor', () {
    testWidgets('a row with a focus node takes focus', (tester) async {
      final node = await mountRow(tester);
      expect(node.hasFocus, isFalse);

      node.requestFocus();
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
    });

    testWidgets('a row is not a Tab stop', (tester) async {
      // This is the whole reason the timeline owns one focusable entry point
      // instead of letting each row be one: a viewport holds a couple of
      // hundred messages, and Tab would never get out of the conversation.
      final node = await mountRow(tester);
      expect(node.skipTraversal, isTrue);
    });

    testWidgets('clicking a row parks the cursor on it', (tester) async {
      final node = await mountRow(tester);

      // `onTapDown` rather than `onTap`, so clicking a link inside a message
      // still counts. A test cannot click a link, but it can assert the node
      // is focusable at all, which is what was broken.
      await tester.tap(find.byType(TimelineItem));
      await tester.pumpAndSettle();
      expect(node.hasFocus, isTrue);
    });
  });

  group('Shift+F10 opens the menu', () {
    testWidgets('the menu opens when the row has focus', (tester) async {
      final node = await mountRow(tester);
      node.requestFocus();
      await tester.pumpAndSettle();

      // Shift has to be physically down for isShiftPressed, which is what
      // the binding reads; sendKeyEvent(f10) alone does not set it.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();

      expect(
          find.byType(MoonrelayMenuItem<MessageContextAction>), findsWidgets);
    });

    testWidgets('the dedicated Menu key opens it too', (tester) async {
      final node = await mountRow(tester);
      node.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      expect(
          find.byType(MoonrelayMenuItem<MessageContextAction>), findsWidgets);
    });

    testWidgets('the menu is anchored to the row, not the screen corner',
        (tester) async {
      final key = GlobalKey(debugLabel: 'rowbox');
      final node = await mountRow(tester, itemKey: key);
      node.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      final menu = find.byType(MoonrelayMenuItem<MessageContextAction>);
      expect(menu, findsWidgets);

      // There is no pointer, so anchoring to `Offset.zero` would put the menu
      // in the top-left corner, which reads as the menu having nothing to do
      // with the row that opened it.
      final menuTop = tester.getTopLeft(menu.first);
      final rowTop = tester.getTopLeft(find.byType(TimelineItem));
      expect(menuTop.dy, greaterThanOrEqualTo(rowTop.dy - 1));
    });

    testWidgets('an unrelated key does not open it', (tester) async {
      final node = await mountRow(tester);
      node.requestFocus();
      await tester.pumpAndSettle();

      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.pumpAndSettle();

      expect(
          find.byType(MoonrelayMenuItem<MessageContextAction>), findsNothing);
    });
  });

  group('without a focus node', () {
    testWidgets('an item mounted without one is not keyboard reachable',
        (tester) async {
      // `TimelineItem` is mounted directly by several widget tests and, in
      // production, by the pinned-events list. Those must not gain a
      // half-working keyboard path.
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            Provider<Logger>.value(value: MockLogger()),
            ChangeNotifierProvider<EncryptionService>.value(value: enc),
            ChangeNotifierProvider<SettingsController>(
              create: (_) => createTestSettingsController(),
            ),
          ],
          child: MaterialApp(
            theme: testMoonrelayTheme(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TimelineItem(
                event: event,
                room: room,
                displayType: DisplayType.modern,
                fontSize: 14,
                onAction: (_, __) {},
              ),
            ),
          ),
        ),
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.contextMenu);
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(
          find.byType(MoonrelayMenuItem<MessageContextAction>), findsNothing);
    });
  });
}
