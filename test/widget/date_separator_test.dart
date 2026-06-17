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
import 'package:moonrelay/src/chat/events/date_separator.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

void main() {
  group('DateSeparator', () {
    testWidgets('shows "Today" for current date', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DateSeparator(dateTime: DateTime.now())),
        ),
      );

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('shows "Yesterday" for yesterday', (tester) async {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DateSeparator(dateTime: yesterday)),
        ),
      );

      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('shows formatted date for older dates in the same year',
        (tester) async {
      // Use a date that is in the current year but not today or yesterday.
      final now = DateTime.now();
      final oldDate = DateTime(now.year, 1, 15);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DateSeparator(dateTime: oldDate)),
        ),
      );

      // Should show a date like "January 15"
      expect(find.textContaining('January'), findsOneWidget);
    });

    testWidgets('shows date with year for dates in other years',
        (tester) async {
      final oldDate = DateTime(2023, 6, 14);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DateSeparator(dateTime: oldDate)),
        ),
      );

      // Should include the year for a different calendar year
      expect(find.textContaining('2023'), findsOneWidget);
    });

    testWidgets('renders without errors', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: DateSeparator(dateTime: DateTime.now())),
        ),
      );

      expect(find.byType(Row), findsOneWidget);
    });
  });
}
