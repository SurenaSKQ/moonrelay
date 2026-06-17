// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/events/formatted_text_widget.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/mocks.dart';

void main() {
  late MockEvent event;

  setUp(() {
    event = MockEvent();
    when(() => event.body).thenReturn('Hello, world!');
    when(() => event.content).thenReturn({
      'body': 'Hello, world!',
      'msgtype': 'm.text',
    });
  });

  group('FormattedTextWidget', () {
    testWidgets('renders plain text when no formatted body', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FormattedTextWidget(event: event),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('renders HTML formatted body', (tester) async {
      when(() => event.content).thenReturn({
        'body': 'Hello **world**',
        'msgtype': 'm.text',
        'format': 'org.matrix.custom.html',
        'formatted_body': 'Hello <strong>world</strong>',
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FormattedTextWidget(event: event),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('renders with custom base font size', (tester) async {
      when(() => event.content).thenReturn({
        'body': 'Big text',
        'msgtype': 'm.text',
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FormattedTextWidget(event: event, baseFontSize: 20),
          ),
        ),
      );

      expect(find.byType(SelectableText), findsOneWidget);
    });

    testWidgets('renders without error', (tester) async {
      when(() => event.body).thenReturn('Check https://example.com');
      when(() => event.content).thenReturn({
        'body': 'Check https://example.com',
        'msgtype': 'm.text',
      });

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FormattedTextWidget(event: event),
          ),
        ),
      );

      expect(find.byType(FormattedTextWidget), findsOneWidget);
    });
  });
}
