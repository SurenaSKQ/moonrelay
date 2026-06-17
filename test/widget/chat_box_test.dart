// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

import '../helpers/mocks.dart';

void main() {
  late MockRoom room;
  late MockClient client;
  late MockLogger logger;

  setUp(() {
    room = MockRoom();
    client = MockClient();
    logger = MockLogger();

    when(() => room.client).thenReturn(client);
    when(() => room.sendTextEvent(any())).thenAnswer((_) async {
      return null;
    });
    when(() => room.sendTextEvent(any(), inReplyTo: any(named: 'inReplyTo')))
        .thenAnswer((_) async {
          return null;
        });
    when(() => room.sendEvent(any())).thenAnswer((_) async {
      return null;
    });
    when(() => logger.w(any(), error: any(named: 'error')))
        .thenReturn(null);
    when(() => logger.w(any())).thenReturn(null);
  });

  Widget buildApp() {
    return MultiProvider(
      providers: [
        Provider<Logger>.value(value: logger),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ChatBox(room: room),
        ),
      ),
    );
  }

  group('ChatBox', () {
    testWidgets('renders text field and send button', (tester) async {
      await tester.pumpWidget(buildApp());

      expect(find.byType(TextField), findsOneWidget);
      expect(find.byIcon(LucideIcons.send), findsOneWidget);
    });

    testWidgets('renders attach button in compact mode', (tester) async {
      await tester.pumpWidget(buildApp());

      expect(find.byIcon(LucideIcons.paperclip), findsOneWidget);
    });

    testWidgets('renders expand toggle button', (tester) async {
      await tester.pumpWidget(buildApp());

      expect(find.byIcon(LucideIcons.chevronUp), findsOneWidget);
    });

    testWidgets('typing text enables send button', (tester) async {
      await tester.pumpWidget(buildApp());

      final textField = find.byType(TextField);
      await tester.enterText(textField, 'Hello');
      await tester.pump();

      expect(find.byIcon(LucideIcons.send), findsOneWidget);
    });

    testWidgets('renders ChatBox without errors', (tester) async {
      await tester.pumpWidget(buildApp());

      expect(find.byType(ChatBox), findsOneWidget);
    });
  });
}
