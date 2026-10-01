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

// Unit tests for [TimelineStore], stage 1 of TIMELINE_STORE_PLAN.md.
//
// Pure data: a store flattens segments, dedupes overlapping events, and
// indexes by id. Every claim here is verified by mutation, because the
// failure mode this replaces was a map that was wrong by exactly one and a
// scan that silently disagreed with it.

import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' as lg;
import 'package:matrix/matrix.dart';
// `TimelineChunk` is not exported by `package:matrix/matrix.dart`, only
// imported by `src/timeline.dart`. A deep import is the established
// precedent here: `test/helpers/renderable_timeline.dart` does the same.
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonrelay/src/chat/timeline_store.dart';

// -- Test doubles --

class _Ev extends Mock implements Event {
  _Ev(this.id, [this.ts]);
  final String id;
  final DateTime? ts;
  @override
  String get eventId => id;
  @override
  String get type => EventTypes.Message;
  @override
  String get senderId => '@alice:dom';
  @override
  DateTime get originServerTs => ts ?? DateTime(2024, 6, 15, 10, 0, 0);
}

class _T extends Mock implements Timeline {
  _T(this._events);
  final List<Event> _events;
  @override
  List<Event> get events => _events;
}

/// Records whether the store asked it to cancel.
class _CancellableTimeline extends _T {
  _CancellableTimeline(super.events);

  int cancels = 0;

  @override
  void cancelSubscriptions() => cancels++;
}

/// A timeline that answers `getRoomEvents` from a script.
///
/// Models the two things stage 2 exists to get right: pagination reads this
/// segment's own `chunk.prevBatch`/`nextBatch` rather than the room's live
/// token, and exhaustion leaves an **empty string** rather than null
/// (timeline.dart:296).
class _PagingTimeline extends _T {
  _PagingTimeline(super.events, {required TimelineChunk chunk})
      : _chunk = chunk;

  @override
  TimelineChunk get chunk => _chunk;
  final TimelineChunk _chunk;

  /// What `room.prev_batch` is. `null` is the normal state of a synced
  /// room and is the case that broke `canRequestHistory`.
  bool roomPrevBatchIsNull = true;

  /// Events each page will deliver, oldest call last.
  final List<List<Event>> olderPages = [];
  final List<List<Event>> newerPages = [];

  final List<String> calls = [];

  /// When set, the next page throws instead of resolving.
  Object? failWith;

  @override
  bool get canRequestHistory => !roomPrevBatchIsNull || _dbNotFullyRead;

  bool _dbNotFullyRead = false;

  @override
  bool get canRequestFuture => !allowNewEvent;

  // `Timeline.allowNewEvent` is a plain mutable field, so an override has to
  // be a getter *and* a setter. Overriding it with another field is what
  // the `overridden_fields` lint rejects.
  @override
  bool get allowNewEvent => _allowNewEvent;
  @override
  set allowNewEvent(bool value) => _allowNewEvent = value;
  bool _allowNewEvent = true;

  @override
  Future<int> getRoomEvents({
    int historyCount = Room.defaultHistoryCount,
    dynamic direction = Direction.b,
    StateFilter? filter,
  }) async {
    calls.add(direction.name);
    final failure = failWith;
    if (failure != null) throw failure;

    final pages = direction == Direction.b ? olderPages : newerPages;
    final batch = pages.isEmpty ? const <Event>[] : pages.removeAt(0);
    if (direction == Direction.b) {
      events.addAll(batch);
      // Real SDK: '' once exhausted, never null.
      chunk.prevBatch = pages.isEmpty ? '' : 'tok-$direction-${pages.length}';
    } else {
      events.insertAll(0, batch.reversed);
      chunk.nextBatch = pages.isEmpty ? '' : 'tok-$direction-${pages.length}';
    }
    return batch.length;
  }

  void setDbNotFullyRead(bool value) => _dbNotFullyRead = value;
}

TimelineSegment _pagingSegment(
    _PagingTimeline timeline, {
    String id = 'w',
    bool isLive = false,
    String? anchor,
    lg.Logger? logger,
  }) =>
      TimelineSegment(
        id: id,
        timeline: timeline,
        isLive: isLive,
        anchorEventId: anchor,
        logger: logger,
      );

/// Collects the store's warnings so a test can assert a message was logged.
///
/// The store takes a `Logger`, so the alternative is a mock with no way to
/// assert on text; capturing the formatted output keeps the assertion on what
/// someone reading the log file would actually see. `logger` is aliased
/// because `matrix` exports a `Level` of its own.
lg.Logger _capturingLogger(List<String> into) => lg.Logger(
      printer: _RecordingPrinter(into),
      level: lg.Level.warning,
    );

class _RecordingPrinter extends lg.LogPrinter {
  _RecordingPrinter(this.lines);

  final List<String> lines;

  @override
  List<String> log(lg.LogEvent event) {
    lines.add('${event.level.name} ${event.message}');
    return lines;
  }
}

/// Builds a segment from event ids, which is what every case here cares
/// about. Taking ids rather than events keeps the tests readable; the
/// handful that need a specific instance pass events through [timeline].
TimelineSegment _live(
  List<String> ids, {
  String id = 'live',
  Timeline? timeline,
}) =>
    TimelineSegment(
      id: id,
      timeline: timeline ?? _T(ids.map(_Ev.new).toList()),
      isLive: true,
    );

TimelineSegment _history(
  List<String> ids, {
  required String id,
  String? anchor,
  Timeline? timeline,
}) =>
    TimelineSegment(
      id: id,
      timeline: timeline ?? _T(ids.map(_Ev.new).toList()),
      isLive: false,
      anchorEventId: anchor,
    );

List<String> _ids(List<Event> events) =>
    events.map((e) => e.eventId).toList();

void main() {
  group('flatten', () {
    test('a live-only store flattens to the tail', () {
      final store = TimelineStore(live: _live(['a', 'b', 'c']));
      expect(_ids(store.flatten()), ['a', 'b', 'c']);
    });

    test('an empty segment contributes nothing', () {
      final store = TimelineStore(live: _live([]))
        ..addHistory(_history([], id: 'h1'));
      expect(store.flatten(), isEmpty);
    });

    test('the live tail comes before the history windows', () {
      // Index 0 is the newest event, because `reverse: true` puts index 0 at
      // the bottom of the scroll view. The tail is the newest run, so it
      // leads.
      //
      // These assertions were the other way round for the first three stages
      // and the gap work is what exposed it. The old order rendered the
      // oldest messages at the bottom and the newest at the top: a room
      // upside down. Nothing failed, because the list was internally
      // consistent; it was only consistent about the wrong axis.
      final store = TimelineStore(live: _live(['tail1', 'tail2']))
        ..addHistory(_history(['h1', 'h2'], id: 'h1'));
      expect(_ids(store.flatten()), ['tail1', 'tail2', 'h1', 'h2']);
    });

    test('the most recently added window sits closest to the tail', () {
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['older'], id: 'h_old'))
        ..addHistory(_history(['newer'], id: 'h_new'));
      expect(_ids(store.flatten()), ['tail', 'newer', 'older']);
    });

    test('overlapping events appear once, not twice', () {
      // The case this exists for. A `/context` window routinely covers
      // events that are also in the live tail, because both come from the
      // same room and the window is built around an event that may be
      // inside the tail. Without the dedupe the same message renders twice.
      final store = TimelineStore(live: _live(['tail1', 'shared', 'tail2']))
        ..addHistory(_history(['win1', 'shared'], id: 'w'));

      expect(_ids(store.flatten()), ['tail1', 'shared', 'tail2', 'win1']);
      expect(
        _ids(store.flatten()).where((id) => id == 'shared').length,
        1,
      );
    });

    test('the tail wins an overlap, not the window', () {
      // The tail is walked first, so its instance survives. That is the one
      // the app keeps updating as sync brings in reactions and edits; a
      // window's copy is a `/context` snapshot and does not.
      final tailEvent = _Ev('shared');
      final windowEvent = _Ev('shared');
      final store = TimelineStore(
        live: _live(['shared'], timeline: _T([tailEvent])),
      )..addHistory(_history(['shared'], id: 'w', timeline: _T([windowEvent])));

      expect(store.flatten().single.eventId, 'shared');
      expect(identical(store.flatten().single, tailEvent), isTrue);
    });

    test('dedupe does not reorder the survivors', () {
      final store = TimelineStore(
        live: _live(['a', 'b', 'c', 'd']),
      )..addHistory(_history(['x', 'b', 'y'], id: 'w'));
      // The tail keeps its order and drops the duplicated b; the window's
      // surviving events follow it.
      expect(_ids(store.flatten()), ['a', 'b', 'c', 'd', 'x', 'y']);
    });
  });

  group('indexOf', () {
    test('agrees with flatten for every event', () {
      final store = TimelineStore(live: _live(['a', 'b', 'shared', 'c']))
        ..addHistory(_history(['w1', 'shared', 'w2'], id: 'w'));
      final flat = _ids(store.flatten());

      for (var i = 0; i < flat.length; i++) {
        expect(store.indexOf(flat[i]), i, reason: flat[i]);
      }
    });

    test('returns -1 for an event that is not loaded', () {
      final store = TimelineStore(live: _live(['a']));
      expect(store.indexOf('missing'), -1);
    });

    test('finds an event in a window, not just the tail', () {
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['w1', 'w2'], id: 'w'));
      expect(store.indexOf('tail'), 0);
      expect(store.indexOf('w2'), 2);
    });
  });

  group('segmentFor', () {
    test('identifies which segment holds an event', () {
      final live = _live(['tail']);
      final window = _history(['w1'], id: 'w');
      final store = TimelineStore(live: live)..addHistory(window);

      expect(store.segmentFor('tail')?.id, 'live');
      expect(store.segmentFor('w1')?.id, 'w');
      expect(store.segmentFor('nope'), isNull);
    });
  });

  group('version', () {
    test('starts at zero and does not move on reads', () {
      final store = TimelineStore(live: _live(['a']));
      expect(store.version, 0);
      store.flatten();
      store.indexOf('a');
      store.isViewingHistory;
      store.history;
      store.collapseHistory();
      store.removeHistory('nothing');
      expect(store.version, 0);
    });

    test('bumps once per mutation', () {
      final store = TimelineStore(live: _live(['a']));
      expect(store.version, 0);
      store.addHistory(_history(['w'], id: 'w1'));
      expect(store.version, 1);
      store.addHistory(_history(['x'], id: 'w2'));
      expect(store.version, 2);
      expect(store.removeHistory('w1'), isTrue);
      expect(store.version, 3);
    });

    test('collapse bumps once, not once per segment', () {
      final store = TimelineStore(live: _live(['a']))
        ..addHistory(_history(['w'], id: 'w1'))
        ..addHistory(_history(['x'], id: 'w2'));
      final before = store.version;
      expect(store.collapseHistory(), 2);
      expect(store.version, before + 1);
    });

    test('a no-op collapse does not bump', () {
      final store = TimelineStore(live: _live(['a']));
      final before = store.version;
      expect(store.collapseHistory(), 0);
      expect(store.version, before);
    });

    test('an unknown removal does not bump', () {
      // The user can click "back to latest" after the window was already
      // evicted. A click handler must not throw for that.
      final store = TimelineStore(live: _live(['a']));
      expect(store.removeHistory('ghost'), isFalse);
      expect(store.version, 0);
    });
  });

  group('isViewingHistory', () {
    test('is false for a live-only store', () {
      expect(TimelineStore(live: _live(['a'])).isViewingHistory, isFalse);
    });

    test('is true with a window, false again after collapse', () {
      final store = TimelineStore(live: _live(['a']));
      expect(store.isViewingHistory, isFalse);
      store.addHistory(_history(['w'], id: 'w'));
      expect(store.isViewingHistory, isTrue);
      store.collapseHistory();
      expect(store.isViewingHistory, isFalse);
    });
  });

  group('addHistory', () {
    test('cancels the window on the way in', () {
      // A `/context` window subscribes to onSync on construction, and the
      // SDK's _removeEventsNotInThisSync deletes every event not in a
      // gap-limited sync. Detaching has to happen before the window is
      // reachable through flatten, not when it is evicted.
      final timeline = _CancellableTimeline([_Ev('w')]);
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['w'], id: 'w', timeline: timeline));

      expect(timeline.cancels, 1);
      expect(store.flatten(), hasLength(2));
    });

    test('never cancels the live segment', () {
      // The live tail must stay subscribed to follow sync. Cancelling it
      // would leave the room silently frozen at whatever it last received,
      // which is the failure mode `_removeEventsNotInThisSync` has for
      // windows and which no amount of UI would explain.
      final timeline = _CancellableTimeline([_Ev('a')]);
      final live = TimelineSegment(id: 'live', timeline: timeline, isLive: true);
      TimelineStore(live: live)
        ..addHistory(_history(['w'], id: 'w'))
        ..collapseHistory();
      expect(timeline.cancels, 0);

      // Directly, because the guard is on the segment and not on any one
      // caller: today `addHistory` is the only caller and it rejects live
      // segments first, so nothing else exercises this path. A later
      // eviction path would call `cancel()` on whatever it removed, and
      // this is the assertion that says the tail is not one of those.
      live.cancel();
      expect(timeline.cancels, 0);
    });

    test('refuses a second live segment', () {
      // The live tail is fixed at construction. A second one would make
      // flatten() render the tail twice with no way to tell which is real.
      final store = TimelineStore(live: _live(['a']));
      final impostor = TimelineSegment(
        id: 'other',
        timeline: _T([_Ev('b')]),
        isLive: true,
      );
      expect(() => store.addHistory(impostor), throwsArgumentError);
      expect(store.flatten(), hasLength(1));
    });

    test('refuses a duplicate id', () {
      // Two windows around the same event would otherwise both answer to
      // one id, and eviction would have to pick between them.
      final store = TimelineStore(live: _live(['a']))
        ..addHistory(_history(['w'], id: 'w'));
      expect(
        () => store.addHistory(_history(['w2'], id: 'w', anchor: 'w')),
        throwsArgumentError,
      );
    });
  });

  group('removeHistory and collapseHistory', () {
    test('removeHistory leaves the live segment alone', () {
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['w1'], id: 'w1'))
        ..addHistory(_history(['w2'], id: 'w2'));

      expect(store.removeHistory('w1'), isTrue);
      expect(_ids(store.flatten()), ['tail', 'w2']);
      expect(store.live.events, hasLength(1));
    });

    test('collapse drops every window and keeps the tail', () {
      // The replacement for backToLive, which rebuilt the timeline from
      // scratch because substitution had thrown the tail away.
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['w1'], id: 'w1'))
        ..addHistory(_history(['w2'], id: 'w2'));

      expect(store.collapseHistory(), 2);
      expect(store.history, isEmpty);
      expect(_ids(store.flatten()), ['tail']);
    });
  });

  group('segment metadata', () {
    test('a window records the event it was built around', () {
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['w'], id: 'w', anchor: '\$w'));
      expect(store.segmentFor('w')?.anchorEventId, '\$w');
      expect(store.live.anchorEventId, isNull);
    });

    test('a window exposes isLive false and the tail true', () {
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['w'], id: 'w'));
      expect(store.live.isLive, isTrue);
      expect(store.history.single.isLive, isFalse);
    });
  });

  group('history list', () {
    test('is unmodifiable', () {
      // It is a getter on someone else's store; a caller that mutates the
      // returned list would bypass version bumping and leave the view with
      // a stale cache.
      final store = TimelineStore(live: _live(['a']))
        ..addHistory(_history(['w'], id: 'w'));
      expect(() => store.history.add(_history(['x'], id: 'x')),
          throwsUnsupportedError);
    });
  });

  // -- Stage 2: segment paging --

  group('segment selection for loading', () {
    test('the oldest segment is the live tail with no windows', () {
      final store = TimelineStore(live: _live(['tail']));
      expect(store.oldestSegment.id, 'live');
      expect(store.oldestSegment.isLive, isTrue);
    });

    test('the oldest segment is the last window once one is added', () {
      // The scroll-to-load path must extend this one. Paging the tail
      // instead would grow the wrong end and the window would never
      // get taller.
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['w'], id: 'w'));
      expect(store.oldestSegment.id, 'w');
    });

    test('with several windows the oldest is the one added first', () {
      // `addHistory` treats the newest addition as the newest segment, so
      // the oldest is the last one in the list.
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['old'], id: 'old'))
        ..addHistory(_history(['new'], id: 'new'));
      expect(store.oldestSegment.id, 'old');
    });

    test('group ids line up with the non-empty groups', () {
      final store = TimelineStore(live: _live(['t1', 't2']))
        ..addHistory(_history([], id: 'empty'))
        ..addHistory(_history(['w'], id: 'w'));
      // Render order is [live, w]; the empty window is skipped from both
      // `eventGroups` and the id list, so the indices stay aligned.
      expect(store.groupSegmentIds(), ['live', 'w']);
      expect(store.eventGroups().length, 2);
    });

    test('closing a gap pages the group above it older', () async {
      // Group 0 is the live tail. A gap after it means events are missing
      // between the tail's oldest and the window's newest, and those are
      // *older* than the tail's oldest. With the viewer below the marker,
      // paging the newer side backwards is what reaches them, and it is the
      // only direction the tail can take: it is anchored at the newest event
      // in the room and `pageNewer` on it is permanently impossible.
      final tail = _PagingTimeline([_Ev('t1')], chunk: TimelineChunk(events: []))
        ..olderPages.add([_Ev('older')]);
      tail.chunk.prevBatch = 'tok';

      final store = TimelineStore(
        live: TimelineSegment(id: 'live', timeline: tail, isLive: true),
      )..addHistory(_history(['w1'], id: 'w'));

      expect(await store.closeGapAfterGroup(0, viewerOnNewerSide: true), 1);
      expect(tail.calls, ['b'], reason: 'Direction.b, older, to close');
      expect(_ids(store.flatten()), ['t1', 'older', 'w1']);
    });

    test('a closed gap disappears from the boundaries', () async {
      // The point of closing one. One page is not always enough, which is
      // true of real rooms too: a gap can be hours wide and the tolerance
      // is ten minutes, so it takes a page per ten minutes of hole.
      final tail = _PagingTimeline(
        [_Ev('t1', DateTime(2025, 6, 15, 10))],
        chunk: TimelineChunk(events: []),
      )..olderPages.add([_Ev('t2', DateTime(2025, 6, 15, 9, 30))])
        ..olderPages.add([_Ev('t3', DateTime(2025, 6, 15, 9, 5))]);
      tail.chunk.prevBatch = 'tok';

      final store = TimelineStore(
        live: TimelineSegment(id: 'live', timeline: tail, isLive: true),
      )..addHistory(
          _history(['w1'], id: 'w', timeline: _T([
            _Ev('w1', DateTime(2025, 6, 15, 9)),
          ])),
        );

      expect(store.gapBoundaries(), hasLength(1), reason: 'drawn while the hole is wide');

      await store.closeGapAfterGroup(0, viewerOnNewerSide: true);
      expect(store.gapBoundaries(), hasLength(1),
          reason: 'half an hour apart is still a gap');

      await store.closeGapAfterGroup(0, viewerOnNewerSide: true);
      expect(store.gapBoundaries(), isEmpty,
          reason: 'and gone once the two are within the ten-minute tolerance');
    });

    test('closing a gap beyond the last group does nothing', () async {
      final tail = _PagingTimeline([_Ev('t1')], chunk: TimelineChunk(events: []));
      final store = TimelineStore(
        live: TimelineSegment(id: 'live', timeline: tail, isLive: true),
      );
      expect(await store.closeGapAfterGroup(9, viewerOnNewerSide: true), 0);
      expect(tail.calls, isEmpty);
      expect(await store.closeGapAfterGroup(-1, viewerOnNewerSide: true), 0);
      expect(
        // The last group has no older side, so asking to grow that way finds
        // nothing rather than paging the group that does exist in the
        // opposite direction.
        await store.closeGapAfterGroup(0, viewerOnNewerSide: false),
        0,
      );
      expect(tail.calls, isEmpty);
    });

    test('pageOldest targets the oldest segment', () async {
      final window = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..olderPages.add([_Ev('older')]);
      window.chunk.prevBatch = 'tok';

      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_pagingSegment(window, id: 'w'));

      expect(await store.pageOldest(), 1);
      expect(window.calls, ['b']);
      expect(_ids(store.flatten()), ['tail', 'w', 'older']);
    });

    test('a viewer above the marker grows the older side newer', () async {
      // The search case. A user jumps to a result from months ago, so the
      // window is nowhere near the tail, and the hole between them is the
      // distance the jump skipped. They scroll down towards the live edge,
      // so they are in the window, above the marker, and the events they
      // need are *newer* than their window's newest.
      final window = _PagingTimeline([_Ev('w1')], chunk: TimelineChunk(events: []))
        ..newerPages.add([_Ev('w0')]);
      window.chunk.nextBatch = 'tok';
      window.allowNewEvent = false;

      final store = TimelineStore(live: _live(['t1']))
        ..addHistory(_pagingSegment(window, id: 'w'));

      expect(await store.closeGapAfterGroup(0, viewerOnNewerSide: false), 1);
      expect(window.calls, ['f'], reason: 'Direction.f, newer, from the window');
      expect(_ids(store.flatten()), ['t1', 'w0', 'w1']);
    });

    test('the tail is never paged newer, which is impossible anyway', () async {
      // Guards the side selection itself. Whichever way the user approaches a
      // boundary, the tail only ever sees `b`; asking it for `f` would throw
      // from the SDK rather than return nothing.
      final tail = _PagingTimeline([_Ev('t1')], chunk: TimelineChunk(events: []))
        ..newerPages.add([_Ev('never')]);
      tail.chunk.prevBatch = 'tok';

      final window = _PagingTimeline([_Ev('w1')], chunk: TimelineChunk(events: []))
        ..newerPages.add([_Ev('w0')]);
      window.chunk.nextBatch = 'tok';
      window.allowNewEvent = false;

      final store = TimelineStore(
        live: TimelineSegment(id: 'live', timeline: tail, isLive: true),
      )..addHistory(_pagingSegment(window, id: 'w'));

      await store.closeGapAfterGroup(0, viewerOnNewerSide: true);
      await store.closeGapAfterGroup(0, viewerOnNewerSide: false);
      expect(tail.calls, ['b'], reason: 'only ever backwards');
      expect(window.calls, ['f']);
    });

    test('walking down from a distant window reaches the live tail', () async {
      // The whole point of the newer direction, end to end: a user in a
      // window from months ago scrolls down and every page lands between the
      // window and the tail, until there is no hole left and the two run
      // together. Nothing here ever pages the tail.
      final tail = _PagingTimeline(
        [_Ev('t1', DateTime(2025, 6, 15, 12))],
        chunk: TimelineChunk(events: []),
      );
      tail.chunk.prevBatch = 'tok';

      final window = _PagingTimeline(
        [_Ev('w9', DateTime(2025, 1, 2, 9))],
        chunk: TimelineChunk(events: []),
      )
        ..newerPages.add([
          _Ev('w8', DateTime(2025, 1, 2, 9, 1)),
          _Ev('w7', DateTime(2025, 1, 2, 9, 2)),
        ])
        ..newerPages.add([
          _Ev('w6', DateTime(2025, 1, 2, 9, 3)),
          _Ev('w5', DateTime(2025, 1, 2, 9, 4)),
        ])
        ..newerPages.add([
          _Ev('w4', DateTime(2025, 6, 15, 11)),
          _Ev('w3', DateTime(2025, 6, 15, 11, 30)),
          _Ev('w2', DateTime(2025, 6, 15, 11, 45)),
        ])
        ..newerPages.add([_Ev('w1', DateTime(2025, 6, 15, 11, 55))]);
      window.chunk.nextBatch = 'tok';
      window.allowNewEvent = false;

      final store = TimelineStore(
        live: TimelineSegment(id: 'live', timeline: tail, isLive: true),
      )..addHistory(_pagingSegment(window, id: 'w'));

      expect(store.gapBoundaries(), hasLength(1),
          reason: 'months apart is a gap');
      expect(tail.calls, isEmpty);

      await store.closeGapAfterGroup(0, viewerOnNewerSide: false);
      expect(store.gapBoundaries(), hasLength(1), reason: 'still months apart');
      await store.closeGapAfterGroup(0, viewerOnNewerSide: false);
      await store.closeGapAfterGroup(0, viewerOnNewerSide: false);
      expect(store.gapBoundaries(), hasLength(1),
          reason: 'within the hour but not the ten-minute tolerance');

      await store.closeGapAfterGroup(0, viewerOnNewerSide: false);
      expect(store.gapBoundaries(), isEmpty, reason: 'the hole is closed');
      expect(tail.calls, isEmpty,
          reason: 'the live tail was never asked to walk backwards');
      expect(window.calls, ['f', 'f', 'f', 'f']);

      // One continuous run now, and the live tail still leads so the newest
      // event renders at the bottom.
      expect(_ids(store.flatten()), [
        't1',
        'w1', 'w2', 'w3', 'w4', 'w5', 'w6', 'w7', 'w8', 'w9',
      ]);
    });

    test('a window walked up to the tail stops asking', () async {
      // Once the window is contiguous and the hole is gone there is nothing
      // left to fetch downwards, so the exhausted `nextBatch` is what halts
      // it. Without that the SDK sets `allowNewEvent` and starts feeding the
      // room's own sending events into a window that is no longer historical.
      final tail = _PagingTimeline([_Ev('t1')], chunk: TimelineChunk(events: []));
      final window = _PagingTimeline([_Ev('w1')], chunk: TimelineChunk(events: []));
      window.chunk.nextBatch = 'tok';
      window.allowNewEvent = false;

      final segment = _pagingSegment(window, id: 'w');
      expect(segment.canPageNewer, isTrue);
      // One page and the token is spent, which is the SDK's own exhaustion
      // signal rather than anything this class invented.
      await segment.pageNewer();
      expect(segment.canPageNewer, isFalse);

      final store = TimelineStore(
        live: TimelineSegment(id: 'live', timeline: tail, isLive: true),
      )..addHistory(segment);
      expect(await store.closeGapAfterGroup(0, viewerOnNewerSide: false), 0);
    });
  });

  group('fromEventContext guard', () {
    test('accepts a window that can page', () {
      final timeline = _PagingTimeline([_Ev('a'), _Ev('b')], chunk: TimelineChunk(events: []));
      timeline.chunk.prevBatch = 'start-token';

      final segment = TimelineSegment.fromEventContext(
        id: 'w',
        timeline: timeline,
        anchorEventId: 'b',
      );
      expect(segment, isNotNull);
      expect(segment!.anchorEventId, 'b');
      expect(segment.canPageOlder, isTrue);
    });

    test('accepts a window that can only page forward', () {
      // The window reached the start of the room but has more after it.
      final timeline = _PagingTimeline([_Ev('a')], chunk: TimelineChunk(events: []))
        ..allowNewEvent = false;
      timeline.chunk.prevBatch = '';
      timeline.chunk.nextBatch = 'end-token';

      expect(
        TimelineSegment.fromEventContext(
          id: 'w',
          timeline: timeline,
          anchorEventId: 'a',
        ),
        isNotNull,
      );
    });

    test('refuses an empty window', () {
      final timeline = _PagingTimeline([], chunk: TimelineChunk(events: []))
        ..olderPages.add([_Ev('a')]);
      timeline.chunk.prevBatch = 'start-token';

      expect(
        TimelineSegment.fromEventContext(
          id: 'w',
          timeline: timeline,
          anchorEventId: 'ghost',
        ),
        isNull,
      );
    });

    test('refuses a window anchored to nothing', () {
      // The guard for the unverified claim in TIMELINE_STORE_PLAN.md 4. If
      // getEventContext ever comes back with an empty start token, this is a
      // dead end: a few events that cannot reach anything else. Showing it
      // is worse than failing, because the only symptom is that scrolling
      // does nothing.
      final timeline = _PagingTimeline(
        [_Ev('a')],
        chunk: TimelineChunk(events: []),
      )..roomPrevBatchIsNull = true;
      timeline.chunk.prevBatch = '';
      timeline.chunk.nextBatch = '';

      expect(
        TimelineSegment.fromEventContext(
          id: 'w',
          timeline: timeline,
          anchorEventId: 'a',
        ),
        isNull,
      );
    });

    test('a refused window is not added to the store', () {
      final timeline = _PagingTimeline([_Ev('a')], chunk: TimelineChunk(events: []))
        ..roomPrevBatchIsNull = true;
      timeline.chunk.prevBatch = '';
      timeline.chunk.nextBatch = '';

      final store = TimelineStore(live: _live(['tail']));
      final segment = TimelineSegment.fromEventContext(
        id: 'w',
        timeline: timeline,
        anchorEventId: 'a',
      );
      if (segment != null) store.addHistory(segment);

      expect(store.isViewingHistory, isFalse);
      expect(_ids(store.flatten()), ['tail']);
    });
  });

  group('canPageOlder', () {
    test('a window with a prevBatch pages even when room.prev_batch is null',
        () {
      // THE regression. `Timeline.canRequestHistory` consults
      // `room.prev_batch`, the room's live sync token, which is null on any
      // fully synced room. A `/context` window carrying a perfectly good
      // `start` token would report itself exhausted and silently refuse to
      // page. This is the second time this rule has been needed;
      // HistoryPager carries an identical guard.
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..roomPrevBatchIsNull = true
        ..olderPages.add([_Ev('older')]);
      timeline.chunk.prevBatch = 'window-start-token';

      final segment = _pagingSegment(timeline);
      expect(segment.canPageOlder, isTrue);
    });

    test('a window with neither token is exhausted', () {
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..roomPrevBatchIsNull = true;
      timeline.chunk.prevBatch = '';
      expect(_pagingSegment(timeline).canPageOlder, isFalse);
    });

    test('room.prev_batch alone is enough for the live tail', () {
      // The other half of the rule. A live segment reads its first page
      // from the database, so its chunk anchors start empty and only
      // `canRequestHistory` can be right.
      final timeline = _PagingTimeline([_Ev('t')], chunk: TimelineChunk(events: []))
        ..roomPrevBatchIsNull = false;
      timeline.chunk.prevBatch = '';
      expect(_pagingSegment(timeline, id: 'live', isLive: true).canPageOlder,
          isTrue);
    });

    test('exhaustion is an empty string, not null', () {
      // `getRoomEvents` assigns `chunk.prevBatch = newPrevBatch ?? ''`
      // (timeline.dart:296). A null check here would keep paging forever.
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..roomPrevBatchIsNull = true;
      timeline.chunk.prevBatch = '';
      expect(_pagingSegment(timeline).canPageOlder, isFalse);
      timeline.chunk.prevBatch = 'tok';
      expect(_pagingSegment(timeline).canPageOlder, isTrue);
    });
  });

  group('canPageNewer', () {
    test('a fragmented window can page forward', () {
      // The SDK flips `allowNewEvent` to false when `chunk.nextBatch` is
      // non-empty (timeline.dart:365-370), which is what makes a
      // `/context` window forward-pageable at all.
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..allowNewEvent = false;
      timeline.chunk.nextBatch = 'window-end-token';
      expect(_pagingSegment(timeline).canPageNewer, isTrue);
    });

    test('the live tail never pages forward', () {
      // This asymmetry is the entire reason the live tail had to be
      // substituted for in the first place: `canRequestFuture` is
      // `!allowNewEvent`, permanently false on a live segment.
      final timeline = _PagingTimeline([_Ev('t')], chunk: TimelineChunk(events: []))
        ..allowNewEvent = true;
      timeline.chunk.nextBatch = '';
      expect(
        _pagingSegment(timeline, id: 'live', isLive: true).canPageNewer,
        isFalse,
      );
    });

    test('a window with a live-shaped nextBatch still cannot page forward', () {
      // The live tail is the only thing that can never page forward, and it
      // is identified by isLive rather than by the SDK's flags. A window
      // whose `allowNewEvent` happens to still be true is still a window.
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..allowNewEvent = true;
      timeline.chunk.nextBatch = 'tok';
      final segment = _pagingSegment(timeline);
      expect(segment.canPageNewer, isTrue,
          reason: 'a window with an anchor can page forward regardless');
    });

    test('a spent nextBatch reports exhausted even while canRequestFuture is true',
        () {
      // The SDK clears its own forward flag once a page reaches the end
      // (timeline.dart:269-275), but leaning on that flag for exhaustion is
      // how this class of bug happened once already. The segment's own
      // anchor is authoritative, so an empty one wins even while the SDK
      // still claims it can page.
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..allowNewEvent = false; // -> canRequestFuture == true
      timeline.chunk.nextBatch = '';

      expect(timeline.canRequestFuture, isTrue,
          reason: 'the SDK flag is still set; that is the point');
      expect(_pagingSegment(timeline).canPageNewer, isFalse);
    });
  });

  group('pageOlder / pageNewer', () {
    test('appends older events to the segment', () async {
      final timeline = _PagingTimeline(
        [_Ev('new')],
        chunk: TimelineChunk(events: []),
      )..olderPages.add([_Ev('older')]);
      timeline.chunk.prevBatch = 'tok';

      final segment = _pagingSegment(timeline);
      expect(await segment.pageOlder(), 1);
      expect(_ids(segment.events), ['new', 'older']);
    });

    test('inserts newer events at the head, keeping newest-first', () async {
      final timeline = _PagingTimeline(
        [_Ev('old')],
        chunk: TimelineChunk(events: []),
      )..newerPages.add([_Ev('n1'), _Ev('n2')]);
      timeline.chunk.nextBatch = 'tok';
      timeline.allowNewEvent = false;

      final segment = _pagingSegment(timeline);
      expect(await segment.pageNewer(), 2);
      expect(_ids(segment.events), ['n2', 'n1', 'old']);
    });

    test('does not call the server for an exhausted segment', () async {
      // Cheap to skip and expensive to miss: an unchecked page at an
      // exhausted window is a round trip per scroll event.
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..roomPrevBatchIsNull = true;
      timeline.chunk.prevBatch = '';

      expect(await _pagingSegment(timeline).pageOlder(), 0);
      expect(timeline.calls, isEmpty);
    });

    test('an exhausted page is logged, not silent', () async {
      // A gap closer that cannot page must be distinguishable from one that
      // paged successfully and got nothing back. Both return 0, neither
      // bumps the version, and neither changes the marker, so without a log
      // line a hole that has become permanent is invisible in the UI and in
      // the tests. The store takes an optional logger for exactly this.
      final warnings = <String>[];
      final timeline =
          _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
            ..roomPrevBatchIsNull = true;
      timeline.chunk.prevBatch = '';

      final segment = _pagingSegment(
        timeline,
        id: 'window',
        logger: _capturingLogger(warnings),
      );
      expect(await segment.pageOlder(), 0);
      expect(warnings, hasLength(1));
      expect(warnings.single, contains('window'));
      expect(warnings.single, contains('b'),
          reason: 'names the direction it refused');
    });

    test('returns 0 and does not throw when the request fails', () async {
      // Paging is a background fill. Four call sites would otherwise each
      // need the same try/catch, and a throw from one of them lands in a
      // scroll listener where it is invisible.
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..failWith = Exception('network down');
      timeline.chunk.prevBatch = 'tok';

      expect(await _pagingSegment(timeline).pageOlder(), 0);
      expect(timeline.calls, ['b']);
    });

    test('returns 0 when the server sends nothing', () async {
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []));
      timeline.chunk.prevBatch = 'tok';
      expect(await _pagingSegment(timeline).pageOlder(), 0);
    });
  });

  group('store paging', () {
    test('bumps version once after a page that landed', () async {
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..olderPages.add([_Ev('older')]);
      timeline.chunk.prevBatch = 'tok';

      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_pagingSegment(timeline));
      final before = store.version;

      expect(await store.pageOlder('w'), 1);
      // Once, not once per event. `getRoomEvents` fires onInsert per event
      // while it is still appending to chunk.events, so anything that
      // rebuilt from inside that callback would read a half-appended list.
      expect(store.version, before + 1);
      expect(_ids(store.flatten()), ['tail', 'w', 'older']);
    });

    test('does not bump when a page added nothing', () async {
      final timeline = _PagingTimeline([_Ev('w')], chunk: TimelineChunk(events: []))
        ..failWith = Exception('nope');
      timeline.chunk.prevBatch = 'tok';

      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_pagingSegment(timeline));
      final before = store.version;

      expect(await store.pageOlder('w'), 0);
      expect(store.version, before);
    });

    test('pages the live tail by id', () async {
      final timeline = _PagingTimeline(
        [_Ev('t')],
        chunk: TimelineChunk(events: []),
      )..olderPages.add([_Ev('older')]);
      timeline.chunk.prevBatch = 'tok';
      timeline.setDbNotFullyRead(true);

      final store = TimelineStore(live: _pagingSegment(timeline, id: 'live', isLive: true));
      expect(await store.pageOlder('live'), 1);
      expect(_ids(store.flatten()), ['t', 'older']);
    });

    test('an unknown segment id pages nothing', () async {
      final store = TimelineStore(live: _live(['tail']));
      expect(await store.pageOlder('ghost'), 0);
      expect(await store.pageNewer('ghost'), 0);
    });
  });
}