// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/reactions_bar.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

void main() {
  group('ReactionEmojiGrid', () {
    testWidgets('displays emoji grid', (tester) async {
      // ignore: unused_local_variable
      String? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReactionEmojiGrid(
              onSelected: (emoji) => selected = emoji,
            ),
          ),
        ),
      );

      expect(find.byType(Wrap), findsOneWidget);
      // Should show at least one emoji
      expect(find.text('\u{1F44D}'), findsOneWidget);
    });
  });

  group('showReactionPicker', () {
    testWidgets('renders emoji grid without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ReactionEmojiGrid(
              onSelected: (_) {},
            ),
          ),
        ),
      );

      expect(find.byType(ReactionEmojiGrid), findsOneWidget);
    });
  });
}
