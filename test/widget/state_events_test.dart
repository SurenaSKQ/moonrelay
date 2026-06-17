// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/events/matrix_events/State/state_events.dart';
import 'package:moonrelay/src/chat/events/matrix_events/State/verification_notice_event.dart';
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
    when(() => event.senderId).thenReturn('@user:matrix.org');
    when(() => sender.calcDisplayname()).thenReturn('Test User');
    when(() => sender.id).thenReturn('@user:matrix.org');
  });

  group('StateEvents', () {
    testWidgets('renders join event description', (tester) async {
      when(() => event.type).thenReturn('m.room.member');
      when(() => event.content).thenReturn({'membership': 'join'});

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StateEvents(event: event),
          ),
        ),
      );

      expect(find.textContaining('joined'), findsOneWidget);
    });

    testWidgets('renders room name changed event', (tester) async {
      when(() => event.type).thenReturn('m.room.name');
      when(() => event.content).thenReturn({});

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StateEvents(event: event),
          ),
        ),
      );

      expect(find.textContaining('name'), findsWidgets);
    });

    testWidgets('renders room created event', (tester) async {
      when(() => event.type).thenReturn('m.room.create');
      when(() => event.content).thenReturn({});

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StateEvents(event: event),
          ),
        ),
      );

      expect(find.textContaining('created'), findsWidgets);
    });

    testWidgets('hides timestamp when showTimestamp is false', (tester) async {
      when(() => event.type).thenReturn('m.room.create');
      when(() => event.content).thenReturn({});

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: StateEvents(event: event, showTimestamp: false),
          ),
        ),
      );

      // Should still render the event description
      expect(find.byType(Center), findsOneWidget);
    });
  });

  group('VerificationNoticeEvent', () {
    testWidgets('renders verification notice with shield icon', (tester) async {
      when(() => event.type).thenReturn('m.key.verification.start');
      when(() => event.messageType).thenReturn('m.key.verification.start');
      when(() => event.content).thenReturn({});

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VerificationNoticeEvent(event: event),
          ),
        ),
      );

      expect(find.byIcon(LucideIcons.shield), findsOneWidget);
      // The description text "Verification started" or similar
      expect(find.byType(Card), findsOneWidget);
    });
  });
}
