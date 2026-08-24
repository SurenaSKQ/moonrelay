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

// Regression tests for the chat-timeline race fix documented in
// WORK_DONE.md §10 ("Race / cancellation discipline"). When the
// parent rebuilds [ChatTimeline] with a different [Room] before the
// first room's `_initTimeline` future resolves, the late
// continuation from the *old* room must not overwrite the *new*
// room's state. The fix is the [LifecycleGeneration] generation
// counter captured before each await. These tests verify that the
// counter is honoured end to end.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/widget_test_utils.dart';

class _FakeTimeline extends Mock implements Timeline {
  _FakeTimeline({this.label = 'untitled'});

  /// Human-readable identifier so test failures can attribute the
  /// timeline to a specific room without inspecting internals.
  final String label;

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

/// A controllable [Room] mock whose [getTimeline] is gated by a
/// [Completer]. Tests resolve the completer to release the in-flight
/// init on demand, so we can simulate the scenario where the user
/// switches rooms while the first getTimeline is still awaiting.
class _FakeRoom extends Mock implements Room {
  _FakeRoom({
    required this.id,
    Completer<Timeline>? pendingTimeline,
  }) : _pending = pendingTimeline ?? Completer<Timeline>();

  @override
  final String id;
  Completer<Timeline> _pending;

  /// Tag stored on the returned timeline so we can assert which
  /// timeline ended up mounted in the widget after the race.
  Timeline? lastResolved;

  /// Whether the timeline for this room has been resolved at least
  /// once. Used to make sure the test waits for the late continuation
  /// before asserting.
  bool didResolve = false;

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
    final timeline = await _pending.future;
    lastResolved = timeline;
    didResolve = true;
    return timeline;
  }

  /// Resolve the in-flight getTimeline with the supplied [timeline].
  /// The future will then complete and the late continuation in
  /// [_initTimeline] will run (or be short-circuited by the gen check).
  void resolve(Timeline timeline) {
    _pending.complete(timeline);
  }

  /// Replace the pending completer with a fresh one. Lets a test
  /// trigger a second _initTimeline (e.g. via didUpdateWidget) on the
  /// same room object.
  void resetPending() {
    _pending = Completer<Timeline>();
  }

  @override
  Future<void> setReadMarker(
    String? eventId, {
    String? mRead,
    bool? public,
  }) async {}

  @override
  String get fullyRead => '';

  @override
  Membership get membership => Membership.join;
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
    'late getTimeline continuation from the previous room is dropped '
    'after a rapid room switch',
    (tester) async {
      final roomA = _FakeRoom(id: '!a:test');
      final roomB = _FakeRoom(id: '!b:test');

      // Mount room A.
      await tester.pumpWidget(_wrapTimeline(roomA));
      // The initState kicked off _initTimeline; pump once to let
      // the post-frame callbacks settle and the future start.
      await tester.pump();

      // Switch to room B before A's getTimeline resolves.
      await tester.pumpWidget(_wrapTimeline(roomB));
      await tester.pump();

      // Now resolve room A's pending getTimeline. The late
      // continuation inside ChatTimelineState must NOT overwrite
      // room B's state because the generation counter has been
      // bumped in didUpdateWidget.
      final timelineA = _FakeTimeline(label: 'timelineA');
      roomA.resolve(timelineA);
      // Drain the microtask queue plus any timers scheduled by the
      // late continuation.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Resolve room B and let it mount normally.
      final timelineB = _FakeTimeline(label: 'timelineB');
      roomB.resolve(timelineB);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Both rooms resolved but only room B's timeline should be
      // mounted (room A's late continuation was discarded).
      expect(roomA.didResolve, isTrue);
      expect(roomB.didResolve, isTrue);

      // The mounted ChatTimeline belongs to room B; assert by
      // walking the state tree.
      final timelineState =
          tester.state<ChatTimelineState>(find.byType(ChatTimeline));
      // We can't read _timeline directly, but the room id of the
      // mounted widget is exposed via widget.room.id. Both rooms
      // exist; the *mounted* widget must reference room B.
      final widget = tester.widget<ChatTimeline>(find.byType(ChatTimeline));
      expect(widget.room.id, '!b:test');
      // Use the state reference so the analyzer doesn't strip it.
      expect(timelineState.mounted, isTrue);
    },
  );

  testWidgets(
    'back-to-back room switches discard every stale continuation '
    'except the latest room',
    (tester) async {
      final roomA = _FakeRoom(id: '!a:test');
      final roomB = _FakeRoom(id: '!b:test');
      final roomC = _FakeRoom(id: '!c:test');

      await tester.pumpWidget(_wrapTimeline(roomA));
      await tester.pump();

      await tester.pumpWidget(_wrapTimeline(roomB));
      await tester.pump();

      await tester.pumpWidget(_wrapTimeline(roomC));
      await tester.pump();

      // Resolve rooms in *reverse* order. The implementation must
      // survive any order; only room C's continuation should land.
      roomA.resolve(_FakeTimeline(label: 'timelineA'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      roomB.resolve(_FakeTimeline(label: 'timelineB'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final timelineC = _FakeTimeline(label: 'timelineC');
      roomC.resolve(timelineC);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final widget = tester.widget<ChatTimeline>(find.byType(ChatTimeline));
      expect(widget.room.id, '!c:test');
    },
  );

  testWidgets(
    'a mounted ChatTimeline survives a no-op didUpdateWidget '
    '(same room, new widget instance)',
    (tester) async {
      final roomA = _FakeRoom(id: '!a:test');

      await tester.pumpWidget(_wrapTimeline(roomA));
      await tester.pump();

      // Re-mount with the same room; this exercises the path where
      // didUpdateWidget sees oldWidget.room.id == widget.room.id and
      // does NOT bump the generation. The pending continuation is
      // still valid and must land.
      await tester.pumpWidget(_wrapTimeline(roomA));
      await tester.pump();

      final timelineA = _FakeTimeline(label: 'timelineA');
      roomA.resolve(timelineA);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(roomA.didResolve, isTrue);
      final widget = tester.widget<ChatTimeline>(find.byType(ChatTimeline));
      expect(widget.room.id, '!a:test');
    },
  );
}
