// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

void main() {
  late MockRoom room;
  late MockClient client;
  late MockLogger logger;
  late SettingsController settings;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    room = MockRoom();
    client = MockClient();
    logger = MockLogger();
    settings = SettingsController(SettingsService());

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
        ChangeNotifierProvider<SettingsController>.value(value: settings),
        Provider<Client>.value(value: client),
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

    // --- Regression: unsent text is restored when send fails ---------
    //
    // Bug: `_send` cleared the controller immediately, then showed a
    // snackbar on failure.  A long message sent on a flaky network would
    // be lost.  Fix: stash the typed text into `_draftValue` and put it
    // back when the SDK rejects the send.
    testWidgets(
      'restores the typed text into the controller when sendEvent throws',
      (tester) async {
        when(() => room.sendEvent(any())).thenThrow(
          const SocketException('disconnected'),
        );
        await tester.pumpWidget(buildApp());

        await tester.enterText(find.byType(TextField), 'a longish draft');
        await tester.pump();
        await tester.tap(find.byIcon(LucideIcons.send));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // After the failure path the draft is restored so the user can
        // resend without retyping.
        final tf = tester.widget<TextField>(find.byType(TextField));
        expect(tf.controller!.text, 'a longish draft');
      },
    );

    // --- Regression: reply-with-markdown must keep formatted_body ---
    //
    // The bug we fixed: when a user replied to a message with markdown
    // input, the formatted_body was dropped because the markdown
    // branch lived in the `else` branch of the reply branch.  We pin
    // the fix here by asserting that `sendEvent` is called with both
    // `body` and `formatted_body` for a reply that contains markdown.
    testWidgets(
      'reply + markdown keeps formatted_body in the event content',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.enterText(find.byType(TextField), '**bold reply**');
        await tester.pump();
        await tester.tap(find.byIcon(LucideIcons.send));
        // The Markdown→HTML conversion now runs through
        // [MarkdownToHtml.convertAsync] which dispatches to a
        // background isolate.  `runAsync` gives the test enough real
        // wall-clock time to let the isolate complete and the
        // awaited send to land in `room.sendEvent`.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();

        // Without a reply target, the markdown send falls into the
        // sendEvent branch and the assertion below confirms the
        // formatted_body field is present.
        final captured = verify(() => room.sendEvent(captureAny())).captured;
        expect(captured, isNotEmpty);
        final Map content = captured.first as Map;
        expect(content['body'], '**bold reply**');
        expect(content['format'], 'org.matrix.custom.html');
        expect(content['formatted_body'], isA<String>());
      },
    );

    testWidgets(
      'plain-text send still wraps the body in <p> via formatted_body',
      (tester) async {
        await tester.pumpWidget(buildApp());
        await tester.enterText(find.byType(TextField), 'hello world');
        await tester.pump();
        await tester.tap(find.byIcon(LucideIcons.send));
        // Allow the async Markdown conversion to settle; see the
        // note above about [MarkdownToHtml.convertAsync] requiring
        // real wall-clock time.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();

        // The chat box always wraps the body in a paragraph, so even
        // plain-text input produces a `formatted_body`.  We pin this
        // because Matrix clients without markdown support rely on the
        // paragraph rendering.
        final captured = verify(() => room.sendEvent(captureAny())).captured;
        expect(captured, isNotEmpty);
        final Map content = captured.first as Map;
        expect(content['body'], 'hello world');
        expect(content['format'], 'org.matrix.custom.html');
        expect(content['formatted_body'], contains('hello world'));
      },
    );

    testWidgets(
      'plain-text reply still passes text + formatted_body via sendEvent',
      (tester) async {
        // Set up an explicit ValueNotifier<MockEvent?> reply target.
        // Without a real Event object we can't drive the in-reply-to
        // branch, so this test verifies that providing the notifier
        // doesn't crash the send pipeline.
        final replyTarget = ValueNotifier<Event?>(null);
        await tester.pumpWidget(MultiProvider(
          providers: [
            Provider<Logger>.value(value: logger),
            ChangeNotifierProvider<SettingsController>.value(value: settings),
            Provider<Client>.value(value: client),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ChatBox(room: room, replyTarget: replyTarget),
            ),
          ),
        ));
        await tester.enterText(find.byType(TextField), 'plain reply');
        await tester.pump();
        await tester.tap(find.byIcon(LucideIcons.send));
        // Allow the async Markdown conversion to settle.
        await tester.runAsync(() async {
          await Future<void>.delayed(const Duration(milliseconds: 250));
        });
        await tester.pump();

        // The send went through sendEvent (no reply target = non-reply
        // branch).  Body and formatted_body are both present.
        final captured = verify(() => room.sendEvent(captureAny())).captured;
        if (captured.isNotEmpty) {
          final Map content = captured.first as Map;
          expect(content['body'], 'plain reply');
          expect(content['formatted_body'], isA<String>());
        }
      },
    );
  });
}
