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
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/timeline_item.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/mocks.dart';

class MockEncryptionService extends Mock implements EncryptionService {}

/// Finder that matches a [Text] or [SelectableText] whose plain text [contains] [text].
Finder _findTextContaining(String text) {
  return find.byWidgetPredicate(
    (widget) {
      if (widget is Text && widget.data?.contains(text) == true) return true;
      if (widget is SelectableText &&
          (widget.textSpan?.toPlainText().contains(text) ?? false)) {
        return true;
      }
      return false;
    },
  );
}

void main() {
  group('TimelineItem', () {
    late MockRoom room;
    late MockEvent event;
    late MockUser sender;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      room = MockRoom();
      event = MockEvent();
      sender = MockUser();

      // Stub default event behavior
      when(() => event.redacted).thenReturn(false);
      when(() => event.type).thenReturn(EventTypes.Message);
      when(() => event.messageType).thenReturn(MessageTypes.Text);
      when(() => event.body).thenReturn('');
      when(() => event.eventId).thenReturn('evt_123');
      when(() => event.senderId).thenReturn('@user:matrix.org');
      when(() => event.senderFromMemoryOrFallback).thenReturn(sender);
      when(() => event.originServerTs)
          .thenReturn(DateTime(2025, 6, 14, 10, 30));
      when(() => event.content).thenReturn({'body': '', 'msgtype': 'm.text'});

      when(() => sender.calcDisplayname()).thenReturn('Test User');
      when(() => sender.id).thenReturn('@user:matrix.org');

      when(() => room.client).thenReturn(MockClient());
    });

    testWidgets('displays redacted event as deleted message', (tester) async {
      when(() => event.redacted).thenReturn(true);

      final enc = MockEncryptionService();
      when(() => enc.isUserVerifiedById(any())).thenReturn(false);

      final settingsController = SettingsController(SettingsService());
      await settingsController.loadSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<EncryptionService>.value(value: enc),
            ChangeNotifierProvider<SettingsController>.value(
              value: settingsController,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TimelineItem(
                event: event,
                room: room,
                displayType: DisplayType.modern,
              ),
            ),
          ),
        ),
      );

      expect(find.text('Message deleted'), findsOneWidget);
    });

    testWidgets('displays sender name for group start', (tester) async {
      when(() => event.body).thenReturn('Hello!');
      when(() => event.content).thenReturn({
        'body': 'Hello!',
        'msgtype': 'm.text',
      });

      final enc = MockEncryptionService();
      when(() => enc.isUserVerifiedById(any())).thenReturn(false);

      final settingsController = SettingsController(SettingsService());
      await settingsController.loadSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<EncryptionService>.value(value: enc),
            ChangeNotifierProvider<SettingsController>.value(
              value: settingsController,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TimelineItem(
                event: event,
                room: room,
                displayType: DisplayType.modern,
                isGroupStart: true,
              ),
            ),
          ),
        ),
      );

      expect(find.textContaining('Test User'), findsOneWidget);
    });

    testWidgets('renders message in modern display type', (tester) async {
      when(() => event.body).thenReturn('Modern message');
      when(() => event.content).thenReturn({
        'body': 'Modern message',
        'msgtype': 'm.text',
      });

      final enc = MockEncryptionService();
      when(() => enc.isUserVerifiedById(any())).thenReturn(false);

      final settingsController = SettingsController(SettingsService());
      await settingsController.loadSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<EncryptionService>.value(value: enc),
            ChangeNotifierProvider<SettingsController>.value(
              value: settingsController,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TimelineItem(
                event: event,
                room: room,
                displayType: DisplayType.modern,
                isGroupStart: true,
              ),
            ),
          ),
        ),
      );

      expect(_findTextContaining('Modern message'), findsOneWidget);
    });

    testWidgets('renders message in bubbles display type', (tester) async {
      when(() => event.body).thenReturn('Bubble message');
      when(() => event.content).thenReturn({
        'body': 'Bubble message',
        'msgtype': 'm.text',
      });

      final enc = MockEncryptionService();
      when(() => enc.isUserVerifiedById(any())).thenReturn(false);

      final settingsController = SettingsController(SettingsService());
      await settingsController.loadSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<EncryptionService>.value(value: enc),
            ChangeNotifierProvider<SettingsController>.value(
              value: settingsController,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TimelineItem(
                event: event,
                room: room,
                displayType: DisplayType.bubbles,
                isGroupStart: true,
              ),
            ),
          ),
        ),
      );

      expect(_findTextContaining('Bubble message'), findsOneWidget);
    });

    testWidgets('renders message in IRC display type', (tester) async {
      when(() => event.body).thenReturn('IRC message');
      when(() => event.content).thenReturn({
        'body': 'IRC message',
        'msgtype': 'm.text',
      });

      final enc = MockEncryptionService();
      when(() => enc.isUserVerifiedById(any())).thenReturn(false);

      final settingsController = SettingsController(SettingsService());
      await settingsController.loadSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<EncryptionService>.value(value: enc),
            ChangeNotifierProvider<SettingsController>.value(
              value: settingsController,
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TimelineItem(
                event: event,
                room: room,
                displayType: DisplayType.irc,
                isGroupStart: true,
              ),
            ),
          ),
        ),
      );

      expect(_findTextContaining('IRC message'), findsOneWidget);
    });
  });
}
