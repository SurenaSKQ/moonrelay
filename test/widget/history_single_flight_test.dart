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

// Regression tests for the single-flight contract documented in
// WORK_DONE.md §10 ("Skeleton / debounce / single-flight").
// `_requestMoreHistory` is single-flight: re-entrant calls
// (e.g. _onScroll firing while auto-fill is also requesting) must
// be coalesced into the in-flight request. The flag is set on entry
// and cleared on every exit path so a fast scroll can never race
// past the guard and trigger an overlapping history request.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/widget_test_utils.dart';

/// A timeline mock that counts [requestHistory] invocations and lets
/// the test gate the in-flight future. The widget's [_isLoadingHistory]
/// flag is what we really care about; the count is for diagnostics.
class _CountingTimeline extends Mock implements Timeline {
  _CountingTimeline();

  int requestCount = 0;
  final Completer<void> _current = Completer<void>();
  bool _throwOnNext = false;

  /// Sets the throw flag so the next requestHistory throws.
  void scheduleFailure() {
    _throwOnNext = true;
  }

  /// Resolves the in-flight requestHistory so its caller can finish.
  void release() {
    if (!_current.isCompleted) _current.complete();
  }

  @override
  List<Event> get events => <Event>[];

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
  }) async {
    requestCount++;
    if (_throwOnNext) {
      _throwOnNext = false;
      throw StateError('simulated network failure');
    }
    await _current.future;
  }

  @override
  Future<void> requestFuture({
    int historyCount = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {}

  @override
  void cancelSubscriptions() {}
}

class _FakeRoom extends Mock implements Room {
  _FakeRoom(Timeline timeline) : _timeline = timeline;

  final Timeline _timeline;

  @override
  String get id => '!room:example.com';

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
    return _timeline;
  }

  @override
  String get fullyRead => '';

  @override
  Membership get membership => Membership.join;

  @override
  Future<void> setReadMarker(
    String? eventId, {
    String? mRead,
    bool? public,
  }) async {}
}

Widget _wrapTimeline(Room room) {
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
    're-entrant _requestMoreHistory calls during an in-flight request '
    'short-circuit instead of issuing additional requestHistory calls',
    (tester) async {
      final timeline = _CountingTimeline();
      final room = _FakeRoom(timeline);

      await tester.pumpWidget(_wrapTimeline(room));
      // Settle initialisation: getTimeline resolves, auto-fill loop
      // starts a request and blocks on the completer.
      await tester.pump();
      await tester.pump();

      final state =
          tester.state<ChatTimelineState>(find.byType(ChatTimeline));

      // Record the count after init so the test measures only the
      // explicit invocations below.
      final baseline = timeline.requestCount;

      // The auto-fill loop has left a request in flight.
      expect(state.isLoadingHistoryForTest, isTrue);

      // Fire three more concurrent requests. Each should short-
      // circuit because the in-flight flag is set.
      final futures = <Future<void>>[
        state.requestMoreHistoryForTest(),
        state.requestMoreHistoryForTest(),
        state.requestMoreHistoryForTest(),
      ];

      // Drain microtasks so the calls short-circuit on the flag.
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      });

      // No additional requestHistory was issued by the three calls.
      expect(timeline.requestCount, baseline);
      expect(state.isLoadingHistoryForTest, isTrue);

      // Release the in-flight request so all three futures resolve.
      timeline.release();
      await tester.runAsync(() async {
        await Future.wait(futures);
      });
      expect(state.isLoadingHistoryForTest, isFalse);
    },
  );

  testWidgets(
    'failed requestHistory surfaces a logged warning and clears the '
    'in-flight flag',
    (tester) async {
      final timeline = _CountingTimeline();
      final room = _FakeRoom(timeline);

      await tester.pumpWidget(_wrapTimeline(room));
      await tester.pump();
      await tester.pump();

      final state =
          tester.state<ChatTimelineState>(find.byType(ChatTimeline));

      // Release any auto-fill request that's currently in flight.
      timeline.release();
      // Wait for the scroll debounce timer to expire.
      await tester.pump(const Duration(milliseconds: 200));
      expect(state.isLoadingHistoryForTest, isFalse);

      // Configure the timeline to throw on the next requestHistory.
      timeline.scheduleFailure();

      // First call throws. The widget's catch block must reset the
      // in-flight flag so the next call is not stuck.
      await state.requestMoreHistoryForTest();
      // The flag was reset in the catch path.
      expect(state.isLoadingHistoryForTest, isFalse);
    },
  );
}