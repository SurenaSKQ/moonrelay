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

// Widget tests for `SyncIndicator`.
//
// The whole design rests on one judgement: a `/sync` long-poll in
// flight is the normal state of a healthy client, not a fault, so the
// indicator must stay silent during it. Every test here is an attempt to
// pin that, because the failure mode is a badge that is on all the time
// and users learn to ignore it, which is worse than no badge.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/sync_indicator.dart';

import '../helpers/mocks.dart';

void main() {
  // Short enough to keep the tests fast, long enough that "the stall
  // timer has not fired yet" is meaningfully distinct from "it has".
  const threshold = Duration(milliseconds: 300);

  late StreamController<SyncStatusUpdate> status;
  late MockClient client;

  setUp(() {
    status = StreamController<SyncStatusUpdate>.broadcast();
    client = MockClient();
    when(() => client.sync()).thenAnswer(
      (_) async => SyncUpdate(nextBatch: 'since-token'),
    );
  });

  tearDown(() => status.close());

  Future<void> pump(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SyncIndicator(
            client: client,
            stallThreshold: threshold,
            // The SDK's CachedStreamController is private, so the widget
            // takes the stream as a parameter rather than reading it off
            // a client the test cannot fully fake.
            statusStream: status.stream,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  void emit(SyncStatus value) =>
      status.add(SyncStatusUpdate(value));

  /// Emits and pumps enough frames for the broadcast event to be
  /// delivered and the rebuild to land.
  ///
  /// One pump is not always enough: the event travels through the stream
  /// before the listener runs, and the listener's setState needs a
  /// following frame to be reflected in the tree.
  Future<void> emitAndSettle(
    WidgetTester tester,
    SyncStatus value,
  ) async {
    emit(value);
    await tester.pump();
    await tester.pump();
  }

  group('silence during normal operation', () {
    testWidgets('shows nothing on a healthy first status', (tester) async {
      await pump(tester);

      emit(SyncStatus.finished);
      await tester.pump();

      expect(find.byType(SyncIndicator), findsOneWidget);
      expect(find.text('Still fetching'), findsNothing);
      expect(find.text('Not syncing'), findsNothing);
    });

    testWidgets('a long-poll in flight is not a stall', (tester) async {
      // This is the case the design exists for. A client between polls
      // sits in waitingForResponse for most of its life; showing
      // anything here is what made the previous indicators noise.
      await pump(tester);
      emit(SyncStatus.finished);
      await tester.pump();

      emit(SyncStatus.waitingForResponse);
      await tester.pump();
      // Comfortably past a real long-poll's fast phase but short of the
      // threshold.
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Still fetching'), findsNothing);
    });

    testWidgets('processing does not count as a stall either',
        (tester) async {
      await pump(tester);
      emit(SyncStatus.finished);
      await tester.pump();

      emit(SyncStatus.processing);
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Still fetching'), findsNothing);
    });

    testWidgets('a cold start does not immediately claim to be slow',
        (tester) async {
      // No finished tick has been seen yet, so there is nothing to
      // measure a stall against. Claiming slowness here would greet
      // every user with a warning on launch.
      await pump(tester);

      emit(SyncStatus.waitingForResponse);
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('Still fetching'), findsNothing);
    });
  });

  group('reporting a stall', () {
    testWidgets('appears once the threshold passes with no sync',
        (tester) async {
      await pump(tester);
      emit(SyncStatus.finished);
      await tester.pump();

      emit(SyncStatus.waitingForResponse);
      await tester.pump();
      await tester.pump(threshold + const Duration(milliseconds: 50));

      expect(find.text('Still fetching'), findsOneWidget);
    });

    testWidgets('the wording reassures rather than alarms',
        (tester) async {
      await pump(tester);
      emit(SyncStatus.finished);
      await tester.pump();
      emit(SyncStatus.waitingForResponse);
      await tester.pump();
      await tester.pump(threshold + const Duration(milliseconds: 50));

      // No error styling, because nothing has failed: Matrix is slow and
      // the client is still trying, which is what the copy says.
      expect(find.text('Not syncing'), findsNothing);
      expect(find.text('Still fetching'), findsOneWidget);
    });

    testWidgets('goes away again on the next completed sync', (tester) async {
      await pump(tester);
      emit(SyncStatus.finished);
      await tester.pump();
      emit(SyncStatus.waitingForResponse);
      await tester.pump();
      await tester.pump(threshold + const Duration(milliseconds: 50));
      expect(find.text('Still fetching'), findsOneWidget);

      emit(SyncStatus.finished);
      await tester.pump();

      expect(find.text('Still fetching'), findsNothing);
    });
  });

  group('reporting a failure', () {
    testWidgets('an error is shown immediately, without waiting',
        (tester) async {
      // Unlike a stall, a failure is unambiguous. Waiting out the
      // threshold would delay news the user wants.
      await pump(tester);
      await emitAndSettle(tester, SyncStatus.finished);

      await emitAndSettle(tester, SyncStatus.error);

      expect(find.text('Not syncing'), findsOneWidget);
      expect(find.text('Still fetching'), findsNothing);
    });

    testWidgets('a failure is tappable and the retry clears it',
        (tester) async {
      await pump(tester);
      await emitAndSettle(tester, SyncStatus.error);
      expect(find.text('Not syncing'), findsOneWidget);

      await tester.tap(find.text('Not syncing'));
      await tester.pump();

      // Retry is optimistic: the message clears and the next real status
      // decides whether it comes back, rather than making the user stare
      // at a spinner while a dead connection times out.
      expect(find.text('Not syncing'), findsNothing);
      verify(() => client.sync()).called(1);
    });

    testWidgets('a later success clears the failure', (tester) async {
      await pump(tester);
      await emitAndSettle(tester, SyncStatus.error);

      await emitAndSettle(tester, SyncStatus.finished);

      expect(find.text('Not syncing'), findsNothing);
    });
  });
}
