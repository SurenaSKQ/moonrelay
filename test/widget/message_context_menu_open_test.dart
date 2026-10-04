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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/message_context_menu.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/menu_row.dart';
import 'package:provider/provider.dart';

import '../helpers/mocks.dart';
import '../helpers/widget_test_utils.dart';

/// Tests that open the message menu the way a user does.
///
/// The suite that existed before this one covered `buildEntries` and
/// `handleSelection` in isolation and never once opened a menu. That is how a
/// menu whose every row overflowed by 12 pixels survived: both halves it did
/// test were pure functions, and the overflow lives in the widget tree that
/// only exists between `showForEvent` and the tap.
void main() {
  late MockEvent event;
  late MockRoom room;
  late MockClient client;
  late MockUser sender;
  late MockLogger logger;
  final List<String> clipboardCalls = <String>[];

  void stubBase() {
    when(() => event.eventId).thenReturn(r'$evt_abc');
    when(() => event.body).thenReturn('hello world');
    when(() => event.canRedact).thenReturn(false);
    when(() => event.senderId).thenReturn('@other:matrix.org');
    when(() => event.type).thenReturn(EventTypes.Message);
    when(() => event.messageType).thenReturn(MessageTypes.Text);
    when(() => event.redacted).thenReturn(false);
    when(() => event.content).thenReturn({
      'body': 'hello world',
      'msgtype': 'm.text',
    });
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
  }

  setUp(() {
    event = MockEvent();
    room = MockRoom();
    client = MockClient();
    sender = MockUser();
    logger = MockLogger();
    stubBase();

    clipboardCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData' && call.arguments is Map) {
        clipboardCalls.add((call.arguments as Map)['text']?.toString() ?? '');
      }
      return null;
    });
  });

  /// Mounts a bare app and returns a context inside it, plus a teardown for
  /// the menu so a failing test cannot leave an open route behind.
  Future<BuildContext> host(WidgetTester tester) async {
    late BuildContext ctx;
    await tester.pumpWidget(
      Provider<Logger>.value(
        value: logger,
        child: MaterialApp(
          theme: testMoonrelayTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (c) {
              ctx = c;
              return const Scaffold(body: SizedBox.expand());
            },
          ),
        ),
      ),
    );
    return ctx;
  }

  /// Opens the menu the way a right-click does.
  ///
  /// Deliberately not awaited: `showMenu` returns a Future that completes only
  /// when the user picks something, so awaiting it in a gesture handler (which
  /// is what an agent will try first, every time) hangs the whole test.
  Future<void> openMenu(
    WidgetTester tester,
    BuildContext context, {
    Offset at = const Offset(40, 40),
  }) async {
    unawaited(
      MessageContextMenu.showForEvent(
        context: context,
        position: at,
        event: event,
        room: room,
        onReply: () {},
      ),
    );
    await tester.pumpAndSettle();
  }

  /// The values of the menu currently on screen, in the order they appear.
  List<MessageContextAction> visibleActions(WidgetTester tester) => tester
      .widgetList<MoonrelayMenuItem<MessageContextAction>>(
        find.byType(MoonrelayMenuItem<MessageContextAction>),
      )
      .map((i) => i.value!)
      .toList();

  group('the menu opens and lays out', () {
    testWidgets('no row overflows the menu width', (tester) async {
      final context = await host(tester);
      await openMenu(tester, context);

      // The regression this whole file exists for. `showMenu` clamps itself
      // to `maxWidth: 280`, the rows used to be
      // `Row(Icon, SizedBox, Text)` with a rigid Text, and the longest labels
      // ("Copy message link", "Open sender's profile") are wider than that,
      // so every open painted a 12px overflow stripe. Asserting "the widget
      // did not throw" is what catches it: Flutter reports a RenderFlex
      // overflow as a caught exception, which fails the test.
      expect(tester.takeException(), isNull);

      // And the labels really are long enough to have caused one, otherwise
      // this test passes for the wrong reason.
      final l10n = AppLocalizations.of(context)!;
      expect(find.text(l10n.copyMessageLink), findsOneWidget);
    });

    testWidgets('the same holds on a deliberately narrow surface',
        (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 400));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final context = await host(tester);
      await openMenu(tester, context, at: const Offset(10, 10));

      expect(tester.takeException(), isNull);
    });

    testWidgets('every action is reachable by tapping it', (tester) async {
      final context = await host(tester);
      when(() => room.canChangeStateEvent('m.room.pinned_events'))
          .thenReturn(true);

      await openMenu(tester, context);
      final actions = visibleActions(tester);
      expect(actions, isNotEmpty);
      // Dismiss before the loop, otherwise the next `openMenu` stacks a second
      // menu on the first and every finder is ambiguous.
      await tester.tapAt(const Offset(500, 500));
      await tester.pumpAndSettle();

      for (final action in actions) {
        // Only the clipboard actions are safe to tap without a server behind
        // them; the rest would open a dialog or hit the network.
        if (action != MessageContextAction.copy &&
            action != MessageContextAction.copyEventId &&
            action != MessageContextAction.copyLink &&
            action != MessageContextAction.copyRawJson) {
          continue;
        }
        clipboardCalls.clear();
        await openMenu(tester, context);
        await tester.tap(find.byWidgetPredicate(
          (w) =>
              w is MoonrelayMenuItem<MessageContextAction> && w.value == action,
        ));
        await tester.pumpAndSettle();
        expect(clipboardCalls, hasLength(1),
            reason: '$action should have written to the clipboard');
      }
    });
  });

  group('permissions decide what is offered', () {
    testWidgets('an unprivileged user is offered report', (tester) async {
      final context = await host(tester);
      // No power at all: not the room, not the user.
      when(() => sender.canKick).thenReturn(false);
      when(() => sender.canBan).thenReturn(false);

      await openMenu(tester, context);
      final actions = visibleActions(tester);

      // Reporting is a report to your own homeserver, not a room action, so
      // it needs no power level. It used to be gated behind
      // `canKick || canBan`, which hid it from exactly the people who report
      // abuse.
      expect(actions, contains(MessageContextAction.report));
      expect(actions, isNot(contains(MessageContextAction.kick)));
      expect(actions, isNot(contains(MessageContextAction.ban)));
    });

    testWidgets('an unprivileged user is not offered kick or ban',
        (tester) async {
      final context = await host(tester);
      await openMenu(tester, context);

      final actions = visibleActions(tester);
      expect(actions, isNot(contains(MessageContextAction.kick)));
      expect(actions, isNot(contains(MessageContextAction.ban)));
    });

    testWidgets('a moderator is offered kick and ban', (tester) async {
      final context = await host(tester);
      when(() => sender.canKick).thenReturn(true);
      when(() => sender.canBan).thenReturn(true);

      await openMenu(tester, context);
      final actions = visibleActions(tester);
      expect(actions, contains(MessageContextAction.kick));
      expect(actions, contains(MessageContextAction.ban));
      expect(actions, contains(MessageContextAction.report));
    });

    testWidgets('a moderator is not offered kick for their own message',
        (tester) async {
      final context = await host(tester);
      when(() => event.senderId).thenReturn('@me:matrix.org');
      when(() => sender.canKick).thenReturn(true);
      when(() => sender.canBan).thenReturn(true);

      await openMenu(tester, context);
      final actions = visibleActions(tester);
      expect(actions, isNot(contains(MessageContextAction.kick)));
      expect(actions, isNot(contains(MessageContextAction.report)));
    });
  });

  group('the menu is ordered and grouped, not a flat list', () {
    testWidgets('no two dividers are ever adjacent', (tester) async {
      // Each of the four shapes below used to be able to produce a pair of
      // rules with nothing between them, because the sender group opened with
      // an unconditional divider regardless of whether it had anything to
      // show.
      final shapes = <String, void Function()>{
        'bare': () {},
        'own + editable + pinnable': () {
          when(() => event.senderId).thenReturn('@me:matrix.org');
          when(() => room.canChangeStateEvent('m.room.pinned_events'))
              .thenReturn(true);
        },
        'failed send': () {
          when(() => event.status).thenReturn(EventStatus.error);
        },
        'moderator': () {
          when(() => sender.canKick).thenReturn(true);
          when(() => sender.canBan).thenReturn(true);
        },
      };

      for (final entry in shapes.entries) {
        event = MockEvent();
        room = MockRoom();
        sender = MockUser();
        client = MockClient();
        stubBase();
        entry.value();

        final context = await host(tester);
        await openMenu(tester, context);

        final types = tester
            .widgetList<PopupMenuEntry<dynamic>>(
              find.byType(PopupMenuEntry<Object?>),
            )
            .toList();
        for (var i = 1; i < types.length; i++) {
          expect(
            types[i] is MoonrelayMenuDivider &&
                types[i - 1] is MoonrelayMenuDivider,
            isFalse,
            reason: 'two dividers in a row with "${entry.key}"',
          );
        }
        expect(tester.takeException(), isNull, reason: entry.key);
      }
    });

    testWidgets('copy actions are not ranked above reply', (tester) async {
      final context = await host(tester);
      await openMenu(tester, context);
      final actions = visibleActions(tester);

      // The four copy variants used to be prepended above everything, which
      // put react and reply four rows down. Three of the four are reference
      // material: an event id and a JSON blob are what you reach for when
      // something is already wrong.
      expect(actions.indexOf(MessageContextAction.react),
          lessThan(actions.indexOf(MessageContextAction.copy)));
      expect(actions.indexOf(MessageContextAction.reply),
          lessThan(actions.indexOf(MessageContextAction.copy)));
    });

    testWidgets('a failed send leads with its own recovery actions',
        (tester) async {
      final context = await host(tester);
      when(() => event.status).thenReturn(EventStatus.error);

      await openMenu(tester, context);
      final actions = visibleActions(tester);

      expect(actions.first, MessageContextAction.retry);
      expect(actions, contains(MessageContextAction.cancelSend));
      // A stuck local echo has a transaction id the homeserver has never
      // seen, so offering a plain redact alongside "retry" offers an action
      // that cannot work.
      expect(actions, isNot(contains(MessageContextAction.delete)));
    });

    testWidgets('a healthy message is not offered retry or cancel',
        (tester) async {
      final context = await host(tester);
      await openMenu(tester, context);
      final actions = visibleActions(tester);

      expect(actions, isNot(contains(MessageContextAction.retry)));
      expect(actions, isNot(contains(MessageContextAction.cancelSend)));
    });
  });

  group('dismissing', () {
    testWidgets('tapping outside closes without running anything',
        (tester) async {
      final context = await host(tester);
      await openMenu(tester, context);
      expect(
          find.byType(MoonrelayMenuItem<MessageContextAction>), findsWidgets);

      // A right-click menu that swallows the click it opens on, or leaves the
      // barrier up, is the other half of "unreliable".
      await tester.tapAt(const Offset(400, 400));
      await tester.pumpAndSettle();

      expect(
          find.byType(MoonrelayMenuItem<MessageContextAction>), findsNothing);
      expect(clipboardCalls, isEmpty);
    });
  });
}
