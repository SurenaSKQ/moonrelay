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

// Regression tests for the onUpdate cache-invalidation fix
// documented in WORK_DONE.md §10 ("Jump-to-unread / parallel
// pagination"). The `onUpdate` callback in
// `Room.getTimeline` previously was a no-op
// (`onUpdate: () {}`). Newly-decrypted events and aggregation
// updates touch event content without inserting/removing anything,
// so without a bump of `_timelineVersion` the [TimelineView] cache
// served stale bodies. The fix wires `onUpdate` to call
// `_onTimelineUpdate`, which bumps the version and invalidates the
// cache.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/widget_test_utils.dart';

class _FakeTimeline extends Mock implements Timeline {
  _FakeTimeline();

  /// Captured so we can fire synthetic onUpdate events from the
  /// test after the widget is mounted.
  void Function()? onUpdateCb;
  // Intentionally empty so the timeline doesn't try to render any
  // items (TimelineItem pulls a lot of fields off Event and Room
  // that this test doesn't care about).
  final List<Event> _events = <Event>[];

  @override
  List<Event> get events => List.unmodifiable(_events);

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



class _FakeRoom extends Mock implements Room {
  _FakeRoom(this._timeline);

  final _FakeTimeline _timeline;

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
    // Capture the callbacks so the test can fire them.
    _onUpdate = onUpdate;
    _onInsert = onInsert;
    _onChange = onChange;
    return _timeline;
  }

  void Function()? _onUpdate;
  void Function(int)? _onInsert;
  void Function(int)? _onChange;

  /// Fires the captured onUpdate callback so the widget bumps its
  /// timeline version.
  void fireUpdate() => _onUpdate?.call();

  /// Fires the captured onInsert callback (for the broader test that
  /// exercises the cache invalidation contract).
  void fireInsert(int i) => _onInsert?.call(i);

  /// Fires the captured onChange callback.
  void fireChange(int i) => _onChange?.call(i);

  @override
  String get fullyRead => '';

  // The SDK exposes prev_batch with snake_case; mirroring the casing
  // here keeps the override aligned with the Room superclass.
  @override
  // ignore: non_constant_identifier_names
  String? get prev_batch => null;

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
    'firing onUpdate bumps _timelineVersion',
    (tester) async {
      final timeline = _FakeTimeline();
      final room = _FakeRoom(timeline);

      await tester.pumpWidget(_wrapTimeline(room));
      await tester.pump();
      await tester.pump();

      final state =
          tester.state<ChatTimelineState>(find.byType(ChatTimeline));

      final baseline = state.timelineVersionForTest;
      expect(baseline, 0);

      room.fireUpdate();
      await tester.pump();

      expect(state.timelineVersionForTest, baseline + 1);

      // A second onUpdate fires another bump.
      room.fireUpdate();
      await tester.pump();

      expect(state.timelineVersionForTest, baseline + 2);
    },
  );

  testWidgets(
    'onUpdate calls go through the same _onTimelineUpdate path as '
    'onChange and onInsert (all bump _timelineVersion)',
    (tester) async {
      final timeline = _FakeTimeline();
      final room = _FakeRoom(timeline);

      await tester.pumpWidget(_wrapTimeline(room));
      await tester.pump();
      await tester.pump();

      final state =
          tester.state<ChatTimelineState>(find.byType(ChatTimeline));

      // After init, _timelineVersion has been bumped at least once
      // by _ensureContentFillsScreen's post-frame rebuild. Capture
      // the post-init baseline.
      final baseline = state.timelineVersionForTest;

      // onUpdate path.
      room.fireUpdate();
      await tester.pump();
      final afterUpdate = state.timelineVersionForTest;
      expect(afterUpdate, greaterThan(baseline));

      // onInsert path.
      room.fireInsert(0);
      await tester.pump();
      expect(state.timelineVersionForTest, greaterThan(afterUpdate));

      // onChange path.
      room.fireChange(0);
      await tester.pump();
      expect(
        state.timelineVersionForTest,
        greaterThan(afterUpdate + 1),
      );
    },
  );
}