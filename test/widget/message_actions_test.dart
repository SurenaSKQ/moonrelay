// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/message_actions.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/mocks.dart';

void main() {
  late MockEvent event;
  late MockRoom room;
  late MockClient client;

  setUp(() {
    event = MockEvent();
    room = MockRoom();
    client = MockClient();

    when(() => event.eventId).thenReturn('evt_123');
    when(() => event.body).thenReturn('Test message body');
    when(() => event.canRedact).thenReturn(false);
    when(() => event.senderId).thenReturn('@user2:matrix.org');
    when(() => event.type).thenReturn(EventTypes.Message);
    when(() => event.messageType).thenReturn(MessageTypes.Text);
    when(() => event.redacted).thenReturn(false);
    when(() => event.content).thenReturn({
      'body': 'Test message body',
      'msgtype': 'm.text',
    });
    when(() => room.sendReaction(any(), any())).thenAnswer((_) async {
      return null;
    });
    when(() => room.client).thenReturn(client);
    when(() => client.userID).thenReturn('@me:matrix.org');
    // Return a mock user that has no moderation permissions to avoid
    // showing the moderation button in unrelated tests.
    when(() => room.unsafeGetUserFromMemoryOrFallback(any()))
        .thenAnswer((_) {
      final user = MockUser();
      when(() => user.canKick).thenReturn(false);
      when(() => user.canBan).thenReturn(false);
      return user;
    });
    // Prevent the pin button from appearing in baseline tests.
    when(() => room.canChangeStateEvent('m.room.pinned_events'))
        .thenReturn(false);
    when(() => room.getState('m.room.pinned_events')).thenReturn(null);
  });

  group('MessageActions', () {
    testWidgets('renders action buttons', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageActions(
              event: event,
              room: room,
              onReply: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.add_reaction_rounded), findsOneWidget);
      expect(find.byIcon(Icons.reply_rounded), findsOneWidget);
      expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
    });

    testWidgets('renders forward button when onForward provided',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageActions(
              event: event,
              room: room,
              onReply: () {},
              onForward: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.shortcut_rounded), findsOneWidget);
    });

    testWidgets('renders delete button when canRedact is true',
        (tester) async {
      when(() => event.canRedact).thenReturn(true);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageActions(
              event: event,
              room: room,
              onReply: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
    });

    testWidgets('calls onReply when reply button tapped', (tester) async {
      bool replied = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MessageActions(
              event: event,
              room: room,
              onReply: () => replied = true,
            ),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.reply_rounded));
      expect(replied, isTrue);
    });
  });
}
