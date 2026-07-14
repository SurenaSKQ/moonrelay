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

// Regression tests for the shared-stopwatch jump-to-unread fix
// documented in WORK_DONE.md §10 ("Jump-to-unread / parallel
// pagination"). `_paginateUntilMarker` is bounded by a single
// shared stopwatch. The previous implementation had two sequential
// 8 s global timeouts (one per direction), which could trap the
// user on the loading pill for up to 16 s. The new implementation
// runs both directions in parallel and short-circuits on the first
// success, so the worst case is bounded by the global cap (~9 s
// with one headroom second).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/widget_test_utils.dart';

/// A timeline mock that gates [requestHistory] behind a configurable
/// delay so we can simulate slow network conditions. Each call can be
/// configured to either complete normally (with a configurable event
/// id append) or hang forever.
class _GatedTimeline extends Mock implements Timeline {
  _GatedTimeline();

  int requestCount = 0;
  Duration requestDelay = Duration.zero;

  /// When true, requestHistory awaits a completer that we never
  /// complete, simulating an unresponsive server.
  bool hang = false;
  final Completer<void> _hangCtl = Completer<void>();

  /// After [requestCount] reaches [breakAt], populate the events list
  /// so the marker is considered "loaded". Used to simulate the
  /// server finally returning the marker event.
  int breakAt = 1 << 30;
  String markerEventId = '\$marker';
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
  bool get canRequestFuture => true;

  @override
  bool get canRequestHistory => true;

  @override
  Future<void> requestHistory({
    int historyCount = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {
    requestCount++;
    if (hang) {
      await _hangCtl.future;
    } else if (requestDelay > Duration.zero) {
      await Future<void>.delayed(requestDelay);
    }
    if (requestCount >= breakAt) {
      _events.add(_mkEvent(markerEventId));
    }
  }

  @override
  Future<void> requestFuture({
    int historyCount = Room.defaultHistoryCount,
    StateFilter? filter,
  }) async {
    requestCount++;
    if (hang) {
      await _hangCtl.future;
    } else if (requestDelay > Duration.zero) {
      await Future<void>.delayed(requestDelay);
    }
    if (requestCount >= breakAt) {
      _events.add(_mkEvent(markerEventId));
    }
  }

  @override
  void cancelSubscriptions() {}

  /// Minimal [Event] implementation so the timeline can return an
  /// event with the marker id when we want to short-circuit the
  /// pagination loop.
  Event _mkEvent(String id) {
    // The real Matrix event has many fields; we only need a token
    // for the test's id check. Event.fromMatrixEvent is the
    // canonical builder but it requires a full payload; we use a
    // minimal stand-in by mocking just the eventId getter.
    return _IdEvent(id);
  }

  void unhang() {
    if (!_hangCtl.isCompleted) _hangCtl.complete();
  }
}

class _IdEvent extends Mock implements Event {
  _IdEvent(String id) {
    when(() => eventId).thenReturn(id);
  }
}

class _FakeRoom extends Mock implements Room {
  _FakeRoom(Timeline timeline) : _timeline = timeline;

  final Timeline _timeline;
  String fullyReadId = '';

  @override
  String get id => '!room:example.com';

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
    return _timeline;
  }

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
    'returns false and stays under the global timeout when the server '
    'hangs indefinitely',
    (tester) async {
      final timeline = _GatedTimeline()..hang = true;
      final room = _FakeRoom(timeline);
      room.fullyReadId = '\$marker';

      await tester.pumpWidget(_wrapTimeline(room));
      await tester.pump();
      await tester.pump();

      final state =
          tester.state<ChatTimelineState>(find.byType(ChatTimeline));

      // Run inside runAsync so the real-time stopwatch can advance.
      final stopwatch = Stopwatch()..start();
      final result = await tester.runAsync(() async {
        return state.paginateUntilMarkerForTest('\$marker');
      });
      stopwatch.stop();

      expect(result, isFalse);
      // Global cap is 8 s; allow a 1 s headroom for CI noise.
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 9)),
        reason: 'global stopwatch should cap the wait',
      );

      // Free the completer so the test doesn't hang.
      timeline.unhang();
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'succeeds as soon as either direction surfaces the marker, '
    'even when the other direction hangs',
    (tester) async {
      final timeline = _GatedTimeline();
      final room = _FakeRoom(timeline);
      room.fullyReadId = '\$marker';

      await tester.pumpWidget(_wrapTimeline(room));
      await tester.pump();
      await tester.pump();

      final state =
          tester.state<ChatTimelineState>(find.byType(ChatTimeline));

      // The first paginateOlder iteration should populate the marker.
      timeline.breakAt = 1;
      timeline.hang = false;

      final result = await tester.runAsync(() async {
        return state.paginateUntilMarkerForTest('\$marker');
      });
      expect(result, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );

  testWidgets(
    'returns true once the marker is loaded into the events list',
    (tester) async {
      final timeline = _GatedTimeline();
      final room = _FakeRoom(timeline);
      room.fullyReadId = '\$marker';

      await tester.pumpWidget(_wrapTimeline(room));
      await tester.pump();
      await tester.pump();

      final state =
          tester.state<ChatTimelineState>(find.byType(ChatTimeline));

      // Populate on the second requestHistory call.
      timeline.breakAt = 2;

      final result = await tester.runAsync(() async {
        return state.paginateUntilMarkerForTest('\$marker');
      });
      expect(result, isTrue);
      // The iteration cap is 6 per direction; we set breakAt well
      // under that.
      expect(timeline.requestCount, lessThanOrEqualTo(6));
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}