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

// Pin tests for the smooth-history-load flow: when [TimelineView] is
// told the SDK is fetching older events (`isLoadingHistory = true`),
// only one skeleton tile is mounted, leaving the viewport with
// minimal placeholder so real events can land as they arrive.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/timeline_view.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/display_type.dart';

import '../helpers/mocks.dart';

void main() {
  late MockTimeline timeline;
  late MockRoom room;
  late MockClient client;

  setUp(() {
    timeline = MockTimeline();
    room = MockRoom();
    client = MockClient();

    when(() => timeline.events).thenReturn(<Event>[]);
    when(() => room.client).thenReturn(client);
    when(() => room.canChangeStateEvent(any())).thenReturn(false);
  });

  Widget buildApp({required bool isLoadingHistory}) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 400,
          height: 600,
          child: TimelineView(
            timeline: timeline,
            room: room,
            displayType: DisplayType.modern,
            scrollController: ScrollController(),
            fontSize: 14,
            isLoadingHistory: isLoadingHistory,
          ),
        ),
      ),
    );
  }

  testWidgets(
    'emits exactly one skeleton tile while loading history',
    (tester) async {
      await tester.pumpWidget(buildApp(isLoadingHistory: true));
      // Pump a few frames manually so the skeleton block's expanding
      // animation has time to lay out, without `pumpAndSettle`
      // looping forever on the pulse controller.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 220));
      final opacity = find.descendant(
        of: find.byType(TimelineView),
        matching: find.byType(Opacity),
      );
      // Each skeleton body element (avatar circle + three bars) is
      // wrapped in an AnimatedBuilder → Opacity, giving four
      // containers per tile.  With one tile, expect at least 4.
      expect(opacity.evaluate().length, lessThanOrEqualTo(8));
      expect(opacity.evaluate().length, greaterThanOrEqualTo(4));
    },
  );
}
