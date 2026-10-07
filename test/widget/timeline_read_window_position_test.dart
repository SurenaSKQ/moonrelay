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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

// The read paths have to look at the whole render list, not the live tail.
//
// With history windows loaded alongside the tail, the read position is chosen
// by a walk over the rendered list, so it can name an event from a window.
// Every read path was still reading `_timeline.events`, which degrades
// quietly rather than throwing:
//
//   - the unread count stops at the marker, and a marker inside a window is
//     not in the tail at all, so the count is wrong by the whole window;
//   - `TimelineSnapshot.atReadPosition` looks the read timestamp up in the
//     list it is given, and misses, so `readTs` comes back 0 and the
//     tracker's monotonic guard falls back to remembering ids.
//
// The second one is the reason this file exists. A missing timestamp does not
// stop the receipt, so nothing observable at the room boundary changes; what
// it loses is the tracker's ability to *order* a position against the one
// before it. So the assertion here is about ordering, not about a POST.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/chat/read_marker_tracker.dart';

import '../helpers/renderable_timeline.dart';

/// A room that records the receipts the tracker sends it.
class _RecordingRoom extends Mock implements Room {
  _RecordingRoom(this.posted);

  final List<String?> posted;

  @override
  String get id => '!room:example.com';

  @override
  Future<void> setReadMarker(
    String? eventId, {
    String? mRead,
    bool? public,
  }) async {
    posted.add(eventId);
  }
}

void main() {
  testWidgets(
    'a read position inside a loaded window resolves its timestamp',
    (tester) async {
      final live = RenderableTimeline();
      final room = RenderableRoom(live);
      seedTimeline(room, live, count: 6);
      room.fullyReadId = 'read-marker-below-everything';

      await tester.pumpWidget(wrapChatTimeline(room));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      // A window contiguous with the tail, so the read-position walk can
      // reach into it rather than stopping at a gap.
      final window = RenderableTimeline(canPageOlder: false, prevToken: 'tok');
      window.setAll([
        for (var i = 12; i >= 7; i--)
          makeMessageEvent(room, 'ancient$i', 900000 + i),
      ]);
      room.contextEvents = window.events;
      room.contextPrevBatch = 'tok';
      room.contextNextBatch = 'tok';

      final state =
          tester.state<ChatTimelineState>(find.byType(ChatTimeline));
      await state.jumpToEvent(r'$ancient9');
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await tester.pump(const Duration(seconds: 3));

      final view = state.debugTimelineViewForTest!;
      final readId = view.oldestVisibleEventId;
      expect(readId, isNotNull, reason: 'the walk found a position');
      expect(
        readId,
        startsWith(r'$ancient'),
        reason: 'and it must be a window event, or this test says nothing. '
            'Got $readId',
      );
      final id = readId!;

      // The same construction the widget makes, over each list.
      final overRender =
          TimelineSnapshot.atReadPosition(state.storeForTest!.flatten(),
              readId: id);
      final overTail =
          TimelineSnapshot.atReadPosition(live.events, readId: id);

      expect(overRender.readTs, greaterThan(0),
          reason: 'a window event has a timestamp in the render list');
      expect(overTail.readTs, 0,
          reason: 'and none in the tail alone, which is the whole bug');

      // The seam the widget actually reads from. Asserting on the two
      // snapshots above only proves what `TimelineSnapshot` does with the
      // list it is handed; this proves the widget hands it the right one.
      expect(
        state.renderEventsForTest.length,
        live.events.length + window.events.length,
        reason: 'the read paths must see the tail and the window together',
      );
      expect(
        state.renderEventsForTest.any((e) => e.eventId == id),
        isTrue,
        reason: 'including the event the read position names',
      );

      // Both snapshots post the same id, so the room cannot tell them apart.
      final withCalls = <String?>[];
      ReadMarkerTracker(
        room: _RecordingRoom(withCalls),
        sendReceipts: true,
        notificationService: null,
        onLastSeenChanged: (_) {},
      ).markRoomReadFromSnapshot(overRender);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      final withoutCalls = <String?>[];
      ReadMarkerTracker(
        room: _RecordingRoom(withoutCalls),
        sendReceipts: true,
        notificationService: null,
        onLastSeenChanged: (_) {},
      ).markRoomReadFromSnapshot(overTail);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));

      expect(withCalls, [id]);
      expect(withoutCalls, [id],
          reason: 'the receipt itself is unaffected; only the guard is');

      // What the timestamp buys. The tracker guards on `readTs` when it has
      // one and falls back to remembering ids when it does not, so the
      // fallback only suppresses a position it has already posted. Give each
      // tracker a newer tail position first, then send the older window
      // position.
      //
      // With a timestamp the window position is ordered against that floor
      // and dropped. Without one there is nothing to compare, and the id is
      // new to the tracker, so the receipt goes out for something the user
      // has already scrolled past. That is a read marker moving backwards.
      Future<int> postWindowAfterFloor(
        WidgetTester tester,
        TimelineSnapshot windowSnapshot,
      ) async {
        final calls = <String?>[];
        final tracker = ReadMarkerTracker(
          room: _RecordingRoom(calls),
          sendReceipts: true,
          notificationService: null,
          onLastSeenChanged: (_) {},
        );
        // The floor: the newest tail event, newer than anything in the
        // window.
        tracker.markRoomReadFromSnapshot(
          TimelineSnapshot.atReadPosition(live.events, readId: r'$ev1'),
          force: true,
        );
        calls.clear();
        tracker.markRoomReadFromSnapshot(windowSnapshot);
        // `runAsync` because the receipt is `unawaited` and the delay has to
        // run on the real clock; a bare `delayed` never resolves inside a
        // widget test and the test hangs instead of failing. The pump after it
        // drains the highlight timer, which `runAsync` re-arms on a fresh
        // fake-async zone that no later pump would otherwise advance.
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await tester.pump(const Duration(seconds: 3));
        return calls.length;
      }

      final rePostedWithTs = await postWindowAfterFloor(tester, overRender);
      final rePostedWithoutTs = await postWindowAfterFloor(tester, overTail);

      expect(
        rePostedWithTs,
        0,
        reason: 'a timestamped position is ordered, so returning to one the '
            'user has scrolled past posts nothing',
      );
      expect(
        rePostedWithoutTs,
        greaterThan(0),
        reason: 'and without a timestamp the read marker moves backwards, '
            'retiring messages above the position',
      );
    },
  );
}
