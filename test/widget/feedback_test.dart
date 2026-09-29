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
import 'package:moonrelay/src/helpers/feedback.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

void main() {
  Future<void> pumpScaffold(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(body: SizedBox.shrink()),
      ),
    );
  }

  BuildContext ctxOf(WidgetTester tester) =>
      tester.element(find.byType(Scaffold));

  group('showMessage', () {
    testWidgets('shows the text in a snackbar', (tester) async {
      await pumpScaffold(tester);
      ctxOf(tester).showMessage('hello');
      await tester.pump();
      expect(find.text('hello'), findsOneWidget);
    });

    testWidgets('docks by default and floats on request', (tester) async {
      await pumpScaffold(tester);
      final messenger = ScaffoldMessenger.of(ctxOf(tester));
      ctxOf(tester).showMessage('docked');
      await tester.pump();
      final docked = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(docked.behavior, SnackBarBehavior.fixed);
      expect(docked.duration, kDefaultFeedbackDuration);

      messenger.clearSnackBars();
      await tester.pump();
      ctxOf(tester).showMessage('floating', floating: true);
      await tester.pump();
      final floating = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(floating.behavior, SnackBarBehavior.floating);
    });

    testWidgets('marks errors with the error colours', (tester) async {
      await pumpScaffold(tester);
      final context = ctxOf(tester);
      final scheme = Theme.of(context).colorScheme;
      context.showMessage('nope', isError: true);
      await tester.pump();
      final bar = tester.widget<SnackBar>(find.byType(SnackBar));
      expect(bar.backgroundColor, scheme.errorContainer);
    });
  });

  group('showActionResult', () {
    testWidgets('reports success and returns true', (tester) async {
      await pumpScaffold(tester);
      var ran = false;
      final ok = await ctxOf(tester).showActionResult(
        action: () async => ran = true,
        successMessage: 'done',
      );
      await tester.pump();
      expect(ok, isTrue);
      expect(ran, isTrue);
      expect(find.text('done'), findsOneWidget);
    });

    testWidgets('stays silent on success when successMessage is null',
        (tester) async {
      await pumpScaffold(tester);
      final ok = await ctxOf(tester).showActionResult(
        action: () async {},
        successMessage: null,
      );
      await tester.pump();
      expect(ok, isTrue);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('reports the failure and returns false', (tester) async {
      await pumpScaffold(tester);
      final ok = await ctxOf(tester).showActionResult(
        action: () async => throw StateError('boom'),
        successMessage: 'done',
      );
      await tester.pump();
      expect(ok, isFalse);
      expect(find.textContaining('boom'), findsOneWidget);
      expect(find.text('done'), findsNothing);
    });

    testWidgets('formatError overrides the default error wording',
        (tester) async {
      await pumpScaffold(tester);
      await ctxOf(tester).showActionResult(
        action: () async => throw StateError('boom'),
        successMessage: null,
        formatError: (e) => 'custom: $e',
      );
      await tester.pump();
      expect(find.textContaining('custom:'), findsOneWidget);
    });
  });

  group('confirmDestructive', () {
    testWidgets('returns true only on an explicit confirm', (tester) async {
      await pumpScaffold(tester);
      final context = ctxOf(tester);
      final pending = context.confirmDestructive(
        title: 'Delete message',
        message: 'Sure?',
        confirmLabel: 'Yes, delete',
      );
      await tester.pumpAndSettle();
      expect(find.text('Sure?'), findsOneWidget);
      await tester.tap(find.text('Yes, delete'));
      await tester.pumpAndSettle();
      expect(await pending, isTrue);
    });

    testWidgets('returns false on cancel', (tester) async {
      await pumpScaffold(tester);
      final context = ctxOf(tester);
      final pending = context.confirmDestructive(
        title: 'Delete message',
        message: 'Sure?',
        confirmLabel: 'Yes, delete',
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await pending, isFalse);
    });
  });
}
