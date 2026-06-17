// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/bubble_message_item.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/i_r_c_message_item.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/modern_message_item.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/message_event_base.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

void main() {
  late MockEvent event;
  late MockRoom room;
  late MockClient client;
  late MockUser sender;
  late SettingsController settingsController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    event = MockEvent();
    room = MockRoom();
    client = MockClient();
    sender = MockUser();

    when(() => event.senderFromMemoryOrFallback).thenReturn(sender);
    when(() => event.originServerTs).thenReturn(DateTime(2025, 6, 14, 10, 30));
    when(() => event.eventId).thenReturn('evt_123');
    when(() => event.senderId).thenReturn('@user:matrix.org');
    when(() => event.body).thenReturn('Hello!');
    when(() => event.type).thenReturn(EventTypes.Message);
    when(() => event.messageType).thenReturn(MessageTypes.Text);
    when(() => event.content).thenReturn({
      'body': 'Hello!',
      'msgtype': 'm.text',
    });
    when(() => event.redacted).thenReturn(false);

    when(() => sender.calcDisplayname()).thenReturn('Test User');
    when(() => sender.id).thenReturn('@user:matrix.org');
    when(() => sender.avatarUrl).thenReturn(null);

    when(() => room.client).thenReturn(client);

    settingsController = SettingsController(SettingsService());
    await settingsController.loadSettings();
  });

  group('MessageItemBase interface', () {
    test('BubbleMessageItem implements MessageItemBase', () {
      final item = BubbleMessageItem(event: event, room: room);
      expect(item, isA<MessageItemBase>());
      expect(item.event, equals(event));
      expect(item.room, equals(room));
    });

    test('ModernMessageItem implements MessageItemBase', () {
      final item = ModernMessageItem(event: event, room: room);
      expect(item, isA<MessageItemBase>());
    });

    test('IRCMessageItem implements MessageItemBase', () {
      final item = IRCMessageItem(event: event, room: room);
      expect(item, isA<MessageItemBase>());
    });
  });

  group('BubbleMessageItem', () {
    testWidgets('buildSubtitle shows message body', (tester) async {
      final item = BubbleMessageItem(event: event, room: room);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => item.buildSubtitle(context),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hello!'), findsOneWidget);
    });
  });

  group('ModernMessageItem', () {
    testWidgets('buildSubtitle shows message body for text events',
        (tester) async {
      final item = ModernMessageItem(event: event, room: room);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => item.buildSubtitle(context),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hello!'), findsOneWidget);
    });
  });

  group('IRCMessageItem', () {
    testWidgets('buildSubtitle shows message body', (tester) async {
      final item = IRCMessageItem(event: event, room: room);

      await tester.pumpWidget(
        ChangeNotifierProvider<SettingsController>.value(
          value: settingsController,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => item.buildSubtitle(context),
              ),
            ),
          ),
        ),
      );

      expect(find.text('Hello!'), findsOneWidget);
    });
  });
}
