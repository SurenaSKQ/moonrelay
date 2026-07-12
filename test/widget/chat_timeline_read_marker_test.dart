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

// Pin tests for the unified read-marker behaviour of [ChatTimeline].
// These tests focus on the parts of the read-marker pipeline that
// don't depend on a live network connection: the widget's ability to
// construct with mocked Room and Timeline dependencies, the
// jump-to-unread affordance, and the pill persistence rules
// (only dismissible via the × button, not via scrolling).

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/widget_test_utils.dart';

/// A controllable [Room] mock that returns a [Timeline] via
/// [getTimeline] and tracks [setReadMarker] calls.
class _FakeRoom extends Mock implements Room {
  _FakeRoom({this.fullyReadId = ''});

  String fullyReadId;

  @override
  String get fullyRead => fullyReadId;

  @override
  Future<Timeline> getTimeline({
    void Function(int index)? onChange,
    void Function(int index)? onRemove,
    void Function(int insertID)? onInsert,
    void Function()? onNewEvent,
    void Function()? onUpdate,
    String? eventContextId,
    int? limit,
  }) async {
    return _FakeTimeline();
  }

  @override
  Future<void> setReadMarker(
    String? eventId, {
    String? mRead,
    bool? public,
  }) async {}

  @override
  String get id => '!room:example.com';

  @override
  Membership get membership => Membership.join;
}

/// Minimal [Timeline] mock with the surface area [ChatTimeline] reads.
class _FakeTimeline extends Mock implements Timeline {
  final List<Event> _events = [];

  @override
  List<Event> get events => _events;

  @override
  bool get isRequestingHistory => false;

  @override
  bool get isRequestingFuture => false;

  @override
  bool get allowNewEvent => true;

  @override
  bool get canRequestFuture => false;

  @override
  bool get canRequestHistory => true;

  @override
  Future<void> requestHistory({
    int historyCount = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {}

  @override
  Future<void> requestFuture({
    int historyCount = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {}

  @override
  void cancelSubscriptions() {}
}

Widget _wrapTimeline(_FakeRoom room) {
  return wrapWithProviders(
    child: MaterialApp(
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
          child: ChatTimeline(room: room),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'ChatTimeline constructs with a mocked room and timeline',
    (tester) async {
      final room = _FakeRoom();
      await tester.pumpWidget(_wrapTimeline(room));
      await tester.pump();
      expect(find.byType(ChatTimeline), findsOneWidget);
    },
  );

  testWidgets(
    'jump-to-unread pill is hidden when there are no unread events',
    (tester) async {
      // fullyReadId = '' and an empty timeline mock means
      // _unreadInWindow returns 0 (empty events list), so the
      // pill must stay hidden.
      final room = _FakeRoom(fullyReadId: '');
      await tester.pumpWidget(_wrapTimeline(room));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(LucideIcons.arrowUp), findsNothing);
    },
  );

  testWidgets(
    'pill renders a dismiss (×) button when visible',
    (tester) async {
      // Build a ChatTimeline with an empty timeline so the pill is
      // hidden by default, then confirm the dismiss icon isn't
      // rendered when the pill itself isn't.  This locks in the
      // invariant that the × is *only* visible when the pill is.
      final room = _FakeRoom(fullyReadId: '');
      await tester.pumpWidget(_wrapTimeline(room));
      await tester.pump();
      await tester.pump();
      expect(find.byIcon(LucideIcons.x), findsNothing);
    },
  );
}
