// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/timeline_item_sender_name_and_timestamp.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

void main() {
  late MockEvent event;
  late MockUser sender;
  late SettingsController settingsController;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});

    event = MockEvent();
    sender = MockUser();

    when(() => event.senderFromMemoryOrFallback).thenReturn(sender);
    when(() => event.originServerTs).thenReturn(DateTime(2025, 6, 14, 10, 30));
    when(() => sender.calcDisplayname()).thenReturn('Test User');
    when(() => sender.id).thenReturn('@user:matrix.org');

    settingsController = SettingsController(SettingsService());
    await settingsController.loadSettings();
  });

  Widget buildApp({required bool omitSender}) {
    return ChangeNotifierProvider<SettingsController>.value(
      value: settingsController,
      child: MaterialApp(
        home: Scaffold(
          body: TimelineItemSenderNameAndTimestamp(
            event: event,
            omitSender: omitSender,
          ),
        ),
      ),
    );
  }

  group('TimelineItemSenderNameAndTimestamp', () {
    testWidgets('renders without error with sender name', (tester) async {
      await tester.pumpWidget(buildApp(omitSender: false));

      expect(find.byType(TimelineItemSenderNameAndTimestamp), findsOneWidget);
    });

    testWidgets('renders without error when omitSender is true',
        (tester) async {
      await tester.pumpWidget(buildApp(omitSender: true));

      expect(find.byType(TimelineItemSenderNameAndTimestamp), findsOneWidget);
    });
  });
}
