// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/friend_chats_pane.dart';
import 'package:moonrelay/src/widgets/window_buttons.dart';

void main() {
  group('FriendsChatsPane', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const Scaffold(
            body: FriendsChatsPane(),
          ),
        ),
      );

      expect(find.byType(FriendsChatsPane), findsOneWidget);
    });
  });

  group('WindowButtons', () {
    testWidgets('renders without error', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: WindowButtons(),
          ),
        ),
      );

      expect(find.byType(WindowButtons), findsOneWidget);
    });
  });
}
