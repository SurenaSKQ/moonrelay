// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/state_event_tile.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/mocks.dart';

void main() {
  late MockEvent event;
  late MockUser sender;

  setUp(() {
    event = MockEvent();
    sender = MockUser();

    when(() => event.senderFromMemoryOrFallback).thenReturn(sender);
    when(() => event.originServerTs).thenReturn(DateTime(2025, 6, 14, 10, 30));
    when(() => sender.calcDisplayname()).thenReturn('Test User');
  });

  group('StateEventTile', () {
    testWidgets('renders single event as StateEvents', (tester) async {
      when(() => event.type).thenReturn('m.room.member');
      when(() => event.content).thenReturn({'membership': 'join'});

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StateEventTile(events: [event]),
          ),
        ),
      );

      expect(find.textContaining('Test User'), findsOneWidget);
    });

    testWidgets('renders expandable tile for multiple events',
        (tester) async {
      when(() => event.type).thenReturn('m.room.member');
      when(() => event.content).thenReturn({'membership': 'join'});

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StateEventTile(events: [event, event]),
          ),
        ),
      );

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
    });

    testWidgets('expands multi-event tile on tap', (tester) async {
      when(() => event.type).thenReturn('m.room.member');
      when(() => event.content).thenReturn({'membership': 'join'});

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StateEventTile(events: [event, event]),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });
  });
}
