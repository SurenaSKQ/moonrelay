// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi


import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/image/image_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/audio/audio_message_type.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/file/file_attached_message.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/video/video_message_type.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

void main() {
  late MockEvent event;

  setUp(() {
    event = MockEvent();
    when(() => event.eventId).thenReturn('evt_123');
    when(() => event.hasAttachment).thenReturn(false);
    when(() => event.hasThumbnail).thenReturn(false);
    when(() => event.content).thenReturn({});
  });

  group('ImageMessageType', () {
    testWidgets('renders placeholder when no attachment', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ImageMessageType(event: event),
          ),
        ),
      );

      expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    });

    testWidgets('renders without error with basic event data', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ImageMessageType(event: event),
          ),
        ),
      );

      expect(find.byType(ImageMessageType), findsOneWidget);
    });
  });

  group('AudioMessageType', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AudioMessageType(event: event),
          ),
        ),
      );

      expect(find.byType(AudioMessageType), findsOneWidget);
    });
  });

  group('FileAttachedMessage', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FileAttachedMessage(event: event),
          ),
        ),
      );

      expect(find.byType(FileAttachedMessage), findsOneWidget);
    });
  });

  group('VideoMessageType', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoMessageType(event: event),
          ),
        ),
      );

      expect(find.byType(VideoMessageType), findsOneWidget);
    });
  });
}
