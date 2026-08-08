// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/sync_status_pill.dart';
import '../helpers/mocks.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  group('syncStatusToPresence', () {
    test('finished maps to online', () {
      expect(syncStatusToPresence(SyncStatus.finished), PresenceState.online);
    });
    test('waiting/processing/cleaning map to away', () {
      expect(syncStatusToPresence(SyncStatus.waitingForResponse), PresenceState.away);
      expect(syncStatusToPresence(SyncStatus.processing), PresenceState.away);
      expect(syncStatusToPresence(SyncStatus.cleaningUp), PresenceState.away);
    });
    test('error maps to offline', () {
      expect(syncStatusToPresence(SyncStatus.error), PresenceState.offline);
    });
  });

  group('SyncStatusPill', () {
    testWidgets('shows Online when sync finished', (tester) async {
      await tester.pumpWidget(
        _wrap(SyncStatusPill(
          initialStatus: MockSyncStatusUpdate(status: SyncStatus.finished),
          syncStatusStream: const Stream.empty(),
        )),
      );
      expect(find.text('Online'), findsOneWidget);
    });

    testWidgets('shows Offline when sync errors', (tester) async {
      await tester.pumpWidget(
        _wrap(SyncStatusPill(
          initialStatus: MockSyncStatusUpdate(status: SyncStatus.error),
          syncStatusStream: const Stream.empty(),
        )),
      );
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('shows Away while a sync is in flight', (tester) async {
      await tester.pumpWidget(
        _wrap(SyncStatusPill(
          initialStatus: MockSyncStatusUpdate(status: SyncStatus.waitingForResponse),
          syncStatusStream: const Stream.empty(),
        )),
      );
      expect(find.text('Away'), findsOneWidget);
    });

    testWidgets('flips to Offline when an error is emitted on the stream',
        (tester) async {
      final controller = StreamController<SyncStatusUpdate>();
      await tester.pumpWidget(
        _wrap(SyncStatusPill(
          initialStatus: MockSyncStatusUpdate(status: SyncStatus.finished),
          syncStatusStream: controller.stream,
        )),
      );
      expect(find.text('Online'), findsOneWidget);

      controller.add(MockSyncStatusUpdate(status: SyncStatus.error));
      await tester.pump();
      expect(find.text('Offline'), findsOneWidget);
      await controller.close();
    });
  });
}
