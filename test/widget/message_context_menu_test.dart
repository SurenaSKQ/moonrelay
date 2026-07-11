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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

import '../helpers/mocks.dart';

void main() {
  late MockEvent event;
  late MockRoom room;
  late MockClient client;
  late MockUser sender;
  late MockLogger logger;

  void stubBase() {
    when(() => event.eventId).thenReturn('\$evt_abc');
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
    when(() => sender.calcDisplayname()).thenReturn('Other User');
    when(() => sender.id).thenReturn('@other:matrix.org');

    when(() => room.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:matrix.org');
    when(() => room.id).thenReturn('!room:matrix.org');
    when(() => room.unsafeGetUserFromMemoryOrFallback(any()))
        .thenAnswer((_) => sender);
    when(() => room.canChangeStateEvent('m.room.pinned_events'))
        .thenReturn(false);
    when(() => room.getState('m.room.pinned_events')).thenReturn(null);
    when(() => room.sendReaction(any(), any())).thenAnswer((_) async => null);
  }

  /// Records every text written to the clipboard via `Clipboard.setData`,
  /// populated by the mock platform channel handler in [setUp].
  final List<String> clipboardCalls = <String>[];

  setUp(() {
    event = MockEvent();
    room = MockRoom();
    client = MockClient();
    sender = MockUser();
    logger = MockLogger();
    stubBase();

    // Mock the clipboard platform channel so `Clipboard.setData` /
    // `Clipboard.getData` resolve synchronously in tests.
    clipboardCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        clipboardCalls.add(
          call.arguments is Map
              ? (call.arguments as Map)['text']?.toString() ?? ''
              : '',
        );
        return null;
      }
      if (call.method == 'Clipboard.getData') {
        return <String, dynamic>{'text': clipboardCalls.lastOrNull ?? ''};
      }
      return null;
    });
  });

  Future<List<MessageContextAction>> captureEntries(
    WidgetTester tester, {
    bool hasOnReply = false,
    bool hasOnForward = false,
    bool hasOnThread = false,
  }) async {
    late List<MessageContextAction> values;
    await tester.pumpWidget(
      Provider<Logger>.value(
        value: logger,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              values = MessageContextMenu.buildEntries(
                context: context,
                event: event,
                room: room,
                timeline: null,
                hasOnReply: hasOnReply,
                hasOnForward: hasOnForward,
                hasOnThread: hasOnThread,
              )
                  .whereType<PopupMenuItem<MessageContextAction>>()
                  .map((e) => e.value!)
                  .toList();
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return values;
  }

  Future<void> dispatchSelection(
    WidgetTester tester, {
    required MessageContextAction action,
    VoidCallback? onReply,
    VoidCallback? onForward,
    VoidCallback? onThread,
    VoidCallback? onOpenProfile,
    Timeline? timeline,
  }) async {
    await tester.pumpWidget(
      Provider<Logger>.value(
        value: logger,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    );
    final element = tester.element(find.byType(Scaffold));
    await MessageContextMenu.handleSelection(
      context: element,
      action: action,
      event: event,
      room: room,
      timeline: timeline,
      onReply: onReply ?? () {},
      onForward: onForward,
      onThread: onThread,
      onOpenProfile: onOpenProfile,
    );
    await tester.pump();
  }

  group('MessageContextMenu.buildEntries', () {
    testWidgets('excludes reply/forward/thread when callbacks are absent',
        (tester) async {
      final values = await captureEntries(tester);
      expect(values, isNot(contains(MessageContextAction.reply)));
      expect(values, isNot(contains(MessageContextAction.forward)));
      expect(values, isNot(contains(MessageContextAction.thread)));
      expect(values, contains(MessageContextAction.react));
      expect(values, contains(MessageContextAction.copy));
      expect(values, contains(MessageContextAction.copyEventId));
      expect(values, contains(MessageContextAction.copyLink));
      expect(values, contains(MessageContextAction.copyRawJson));
      expect(values, contains(MessageContextAction.details));
      expect(values, contains(MessageContextAction.openProfile));
    });

    testWidgets('includes reply/forward/thread when callbacks provided',
        (tester) async {
      final values = await captureEntries(
        tester,
        hasOnReply: true,
        hasOnForward: true,
        hasOnThread: true,
      );
      expect(values, contains(MessageContextAction.reply));
      expect(values, contains(MessageContextAction.forward));
      expect(values, contains(MessageContextAction.thread));
    });

    testWidgets('shows edit only for own text messages', (tester) async {
      when(() => event.senderId).thenReturn('@me:matrix.org');
      when(() => event.canRedact).thenReturn(true);
      final values = await captureEntries(tester, hasOnReply: true);
      expect(values, contains(MessageContextAction.edit));
    });

    testWidgets('hides edit for redacted messages', (tester) async {
      when(() => event.senderId).thenReturn('@me:matrix.org');
      when(() => event.redacted).thenReturn(true);
      when(() => event.canRedact).thenReturn(true);
      final values = await captureEntries(tester, hasOnReply: true);
      expect(values, isNot(contains(MessageContextAction.edit)));
    });

    testWidgets('shows delete only when canRedact is true', (tester) async {
      when(() => event.canRedact).thenReturn(true);
      final values = await captureEntries(tester);
      expect(values, contains(MessageContextAction.delete));
    });

    testWidgets('shows pin only when user can change state event',
        (tester) async {
      when(() => room.canChangeStateEvent('m.room.pinned_events'))
          .thenReturn(true);
      final values = await captureEntries(tester);
      expect(values, contains(MessageContextAction.pin));
      expect(values, isNot(contains(MessageContextAction.unpin)));
    });

    testWidgets('shows unpin when event is in pinned list', (tester) async {
      when(() => room.canChangeStateEvent('m.room.pinned_events'))
          .thenReturn(true);
      when(() => room.getState('m.room.pinned_events')).thenReturn(
        MockStrippedStateEvent(content: {
          'pinned': <String>['\$evt_abc'],
        }),
      );
      final values = await captureEntries(tester);
      expect(values, contains(MessageContextAction.unpin));
      expect(values, isNot(contains(MessageContextAction.pin)));
    });

    testWidgets('shows moderation actions for other users with permissions',
        (tester) async {
      when(() => sender.canKick).thenReturn(true);
      when(() => sender.canBan).thenReturn(true);
      final values = await captureEntries(tester);
      expect(values, contains(MessageContextAction.kick));
      expect(values, contains(MessageContextAction.ban));
      expect(values, contains(MessageContextAction.report));
    });

    testWidgets('hides moderation for own messages', (tester) async {
      when(() => event.senderId).thenReturn('@me:matrix.org');
      when(() => sender.canKick).thenReturn(true);
      when(() => sender.canBan).thenReturn(true);
      final values = await captureEntries(tester);
      expect(values, isNot(contains(MessageContextAction.kick)));
      expect(values, isNot(contains(MessageContextAction.ban)));
      expect(values, isNot(contains(MessageContextAction.report)));
    });
  });

  group('MessageContextMenu.handleSelection', () {
    testWidgets('reply invokes callback', (tester) async {
      var replyCalls = 0;
      await dispatchSelection(
        tester,
        action: MessageContextAction.reply,
        onReply: () => replyCalls++,
      );
      expect(replyCalls, 1);
    });

    testWidgets('copy writes body to clipboard', (tester) async {
      await dispatchSelection(
        tester,
        action: MessageContextAction.copy,
      );
      expect(clipboardCalls, isNotEmpty);
      expect(clipboardCalls.last, 'hello world');
    });

    testWidgets('copy event ID writes event id to clipboard', (tester) async {
      await dispatchSelection(
        tester,
        action: MessageContextAction.copyEventId,
      );
      expect(clipboardCalls.last, '\$evt_abc');
    });

    testWidgets('copy message link writes matrix.to permalink',
        (tester) async {
      await dispatchSelection(
        tester,
        action: MessageContextAction.copyLink,
      );
      expect(clipboardCalls.last, 'https://matrix.to/#/!room:matrix.org/\$evt_abc');
    });

    testWidgets('copy raw JSON writes event content to clipboard',
        (tester) async {
      await dispatchSelection(
        tester,
        action: MessageContextAction.copyRawJson,
      );
      expect(clipboardCalls.last, contains('"msgtype"'));
      expect(clipboardCalls.last, contains('"m.text"'));
    });

    testWidgets('open profile invokes callback', (tester) async {
      var profileCalls = 0;
      await dispatchSelection(
        tester,
        action: MessageContextAction.openProfile,
        onOpenProfile: () => profileCalls++,
      );
      expect(profileCalls, 1);
    });

    testWidgets('forward invokes callback', (tester) async {
      var forwardCalls = 0;
      await dispatchSelection(
        tester,
        action: MessageContextAction.forward,
        onForward: () => forwardCalls++,
      );
      expect(forwardCalls, 1);
    });

    testWidgets('thread invokes callback', (tester) async {
      var threadCalls = 0;
      await dispatchSelection(
        tester,
        action: MessageContextAction.thread,
        onThread: () => threadCalls++,
      );
      expect(threadCalls, 1);
    });
  });
}

class MockStrippedStateEvent extends Mock implements StrippedStateEvent {
  MockStrippedStateEvent({required this.content});

  @override
  final Map<String, dynamic> content;
}