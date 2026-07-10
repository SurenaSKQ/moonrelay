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

// Pin tests for the history-loading skeleton block used at the top of
// the chat timeline while the SDK is paginating older events.
//
// The widget is private to [TimelineView] so we exercise it through
// the public TimelineView surface, where [TimelineView.isLoadingHistory]
// controls whether the block is shown.

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
    'shows no skeleton when isLoadingHistory is false',
    (tester) async {
      await tester.pumpWidget(buildApp(isLoadingHistory: false));
      await tester.pump();
      // No `_HistorySkeletonTile` placeholder is rendered.  We
      // approximate "no skeleton" by checking that no fully-sized
      // skeleton container was built.
      expect(find.byType(TimelineView), findsOneWidget);
      // The animated block is a ClipRect + SizeTransition + Column;
      // when collapsed the column has zero children.
      final findColumns = find.descendant(
        of: find.byType(Column),
        matching: find.byType(Container),
      );
      expect(findColumns, findsNothing);
    },
  );

  testWidgets(
    'renders skeleton placeholders when isLoadingHistory is true',
    (tester) async {
      await tester.pumpWidget(buildApp(isLoadingHistory: true));
      // Drive the animation through to its end so the column is fully
      // visible.
      await tester.pumpAndSettle();
      // Three skeleton tiles are rendered (one per the constant list
      // returned by `_buildHistoryLoadingSkeletons`).
      final skeletonTiles = find.descendant(
        of: find.byType(TimelineView),
        matching: find.byType(Container),
      );
      // The exact count is internal; we just assert that *some*
      // skeleton containers were created (avatar circles + body
      // bars = many per tile).  Six containers per tile is a
      // reasonable lower bound.
      expect(skeletonTiles.evaluate().length, greaterThanOrEqualTo(6));
    },
  );
}
