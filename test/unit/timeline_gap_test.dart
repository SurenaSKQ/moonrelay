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

// Gap markers.
//
// Three separate claims, tested in three places. Contiguity detection is the
// store's, marker placement is the model's, and the read-position stop is the
// view's. The third is the one a user would notice as a bug.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:matrix/src/models/timeline_chunk.dart';
import 'package:mocktail/mocktail.dart';

import '../helpers/mocks.dart';

import 'package:moonrelay/src/chat/timeline_model.dart';
import 'package:moonrelay/src/chat/timeline_store.dart';

class _Ev extends Mock implements Event {
  _Ev(this.id, this.ts);
  final String id;
  final DateTime ts;
  @override
  String get eventId => id;
  @override
  String get type => EventTypes.Message;
  @override
  String get senderId => '@alice:dom';
  @override
  DateTime get originServerTs => ts;
  @override
  String get messageType => MessageTypes.Text;
  @override
  String? get relationshipEventId => null;
  @override
  String? get relationshipType => null;
}

class _T extends Mock implements Timeline {
  _T(this._events);
  final List<Event> _events;
  @override
  List<Event> get events => _events;
  @override
  TimelineChunk get chunk => TimelineChunk(events: _events);
}

DateTime _at(int hour, {int day = 15, int minute = 0}) =>
    DateTime(2025, 6, day, hour, minute);

TimelineStore _store({
  required List<Event> tail,
  List<Event>? window,
  String windowId = 'w',
}) {
  final store = TimelineStore(
    live: TimelineSegment(id: 'live', timeline: _T(tail), isLive: true),
  );
  if (window != null) {
    store.addHistory(TimelineSegment(
      id: windowId,
      timeline: _T(window),
      isLive: false,
      anchorEventId: window.isEmpty ? null : window.first.eventId,
    ));
  }
  return store;
}

void main() {
  group('gapBoundaries', () {
    test('no history means no boundaries', () {
      final store = _store(tail: [_Ev('a', _at(10)), _Ev('b', _at(9))]);
      expect(store.gapBoundaries(), isEmpty);
    });

    test('an adjacent window produces no boundary', () {
      // The window's newest event is one minute behind the tail's oldest:
      // contiguous, nothing missing. (An hour apart would be a gap, which is
      // why the minutes here are not the hours.)
      final store = _store(
        tail: [_Ev('t1', _at(10)), _Ev('t2', _at(10))],
        window: [_Ev('w1', _at(10, minute: -1)), _Ev('w2', _at(10))],
      );
      expect(store.gapBoundaries(), isEmpty);
    });

    test('a distant window produces one boundary', () {
      final store = _store(
        tail: [_Ev('t1', _at(10))],
        window: [_Ev('w1', _at(6, day: 14))],
      );
      expect(store.gapBoundaries().length, 1);
    });

    test('the boundary index is the last event of the newer group', () {
      final store = _store(
        tail: [_Ev('t1', _at(10)), _Ev('t2', _at(10)), _Ev('t3', _at(10))],
        window: [_Ev('w1', _at(6, day: 14))],
      );
      // The live tail is group 0, so the boundary is after its last event,
      // at flatten index 2.
      expect(store.gapBoundaries(), {2});
    });

    test('an overlapping window is not a gap', () {
      // The window's newest event is NEWER than the tail's oldest, so the
      // ranges overlap and nothing is missing. This is the normal shape
      // when a window overlaps the tail it was built from.
      final store = _store(
        tail: [_Ev('t1', _at(10))],
        window: [_Ev('w1', _at(11))],
      );
      expect(store.gapBoundaries(), isEmpty);
    });

    test('two windows can each contribute a boundary', () {
      // Added oldest first, because `addHistory` treats the most recently
      // added window as the newest one. A store with the newer window added
      // last would order them backwards and quietly report one boundary
      // instead of two.
      final store = _store(
        tail: [_Ev('t1', _at(20))],
        window: [_Ev('w1', _at(6, day: 12))],
        windowId: 'w1',
      );
      store.addHistory(TimelineSegment(
        id: 'w2',
        timeline: _T([_Ev('w2a', _at(6, day: 14)), _Ev('w2b', _at(6, day: 14))]),
        isLive: false,
      ));
      // Render order: [tail, w2, w1].
      expect(store.gapBoundaries(), {0, 2});
    });

    test('an empty window contributes no boundary', () {
      final store = _store(tail: [_Ev('t1', _at(10))], window: []);
      expect(store.gapBoundaries(), isEmpty);
    });

    test('events sharing a timestamp never gap', () {
      // Adjacent events routinely share originServerTs inside one send
      // burst. Zero apart must never be treated as a hole.
      final ts = _at(10);
      final store = _store(
        tail: [_Ev('t1', ts), _Ev('t2', ts)],
        window: [_Ev('w1', ts), _Ev('w2', ts)],
      );
      expect(store.gapBoundaries(), isEmpty);
    });
  });

  group('buildTimelineItemsFromGroups gap placement', () {
    test('no gaps named means no gap entries', () {
      final result = buildTimelineItemsFromGroups([
        [_Ev('a', _at(10))],
        [_Ev('b', _at(9))],
      ]);
      expect(
        result.items.map((e) => e.kind),
        isNot(contains(TimelineItemKind.gap)),
      );
    });

    test('a gap lands between the two groups', () {
      final result = buildTimelineItemsFromGroups(
        [
          [_Ev('a', _at(10))],
          [_Ev('b', _at(9))],
        ],
        gapsAfter: {0},
      );
      // banner, a, gap, b
      expect(result.items.length, 4);
      expect(result.items[0].kind, TimelineItemKind.undecryptableBanner);
      expect(result.items[1].event!.eventId, 'a');
      expect(result.items[2].kind, TimelineItemKind.gap);
      expect(result.items[3].event!.eventId, 'b');
    });

    test('a gap is not a jump target', () {
      // It has no event id, so it must not appear in the index map.
      final result = buildTimelineItemsFromGroups(
        [
          [_Ev('a', _at(10))],
          [_Ev('b', _at(9))],
        ],
        gapsAfter: {0},
      );
      expect(result.eventIdToItemIndex.keys, ['a', 'b']);
      expect(result.eventIdToItemIndex['b'], 3);
    });

    test('indices after a gap are still exact', () {
      // The gap shifts everything below it, which is the same hazard as the
      // banner at index 0. Asserted by walking the map against the list.
      final result = buildTimelineItemsFromGroups(
        [
          [_Ev('a', _at(10))],
          [_Ev('b', _at(9))],
          [_Ev('c', _at(8))],
        ],
        gapsAfter: {0, 1},
      );
      for (final entry in result.eventIdToItemIndex.entries) {
        expect(result.items[entry.value].event?.eventId, entry.key,
            reason: entry.key);
      }
    });

    test('a gap after the last group is not drawn', () {
      // A boundary only exists between two groups. Naming the final group
      // would put a marker at the top of the list for nothing.
      final result = buildTimelineItemsFromGroups([
        [_Ev('a', _at(10))],
        [_Ev('b', _at(9))],
      ], gapsAfter: {1});
      expect(
        result.items.map((e) => e.kind),
        isNot(contains(TimelineItemKind.gap)),
      );
    });

    test('a gap survives a filter that hides the groups tail', () {
      // The reason gapsAfter is group-relative rather than index-relative.
      // A reaction at the end of a window is hidden from the main
      // timeline, so an index-based marker keyed on that event would be
      // dropped along with it and the hole would silently close.
      final reaction = MockEvent();
      when(() => reaction.eventId).thenReturn('reaction');
      when(() => reaction.relationshipEventId).thenReturn('a');
      when(() => reaction.relationshipType).thenReturn(RelationshipTypes.reaction);
      when(() => reaction.type).thenReturn(EventTypes.Reaction);
      when(() => reaction.originServerTs).thenReturn(_at(9));
      when(() => reaction.senderId).thenReturn('@bob:dom');

      final result = buildTimelineItemsFromGroups(
        [
          [_Ev('a', _at(10)), reaction],
          [_Ev('b', _at(9))],
        ],
        gapsAfter: {0},
      );
      expect(
        result.items.map((e) => e.kind),
        contains(TimelineItemKind.gap),
      );
    });

    test('a group boundary does not break sender grouping', () {
      // A window continuing the conversation should look like one
      // conversation with an interruption, not like a new one. Asserted as
      // "exactly one group start", because which of the two carries the
      // avatar is the model's existing decision and not this stage's.
      final result = buildTimelineItemsFromGroups(
        [
          [_Ev('a', _at(10))],
          [_Ev('b', _at(10, minute: 59))],
        ],
        gapsAfter: {0},
      );
      final events =
          result.items.where((e) => e.kind == TimelineItemKind.event).toList();
      expect(events.length, 2);
      expect(events.where((e) => e.isGroupStart).length, 1,
          reason: 'the boundary must not restart the sender group');
    });

    test('a group boundary still emits a day separator', () {
      final result = buildTimelineItemsFromGroups(
        [
          [_Ev('a', _at(10))],
          [_Ev('b', _at(10, day: 14))],
        ],
        gapsAfter: {0},
      );
      expect(
        result.items.map((e) => e.kind),
        contains(TimelineItemKind.dateSeparator),
      );
    });

    test('showStateEvents false does not swallow the gap', () {
      final result = buildTimelineItemsFromGroups(
        [
          [_Ev('a', _at(10))],
          [_Ev('b', _at(6, day: 14))],
        ],
        gapsAfter: {0},
        showStateEvents: false,
      );
      expect(
        result.items.map((e) => e.kind),
        contains(TimelineItemKind.gap),
      );
    });
  });

  group('store to model wiring', () {
    test('a store with a distant window yields a gap in the item list', () {
      // The end-to-end shape the view uses: store boundaries into the
      // model, so the marker appears without the view knowing why.
      final store = _store(
        tail: [_Ev('t1', _at(20))],
        window: [_Ev('w1', _at(6, day: 10))],
      );
      final result = buildTimelineItemsFromGroups(
        store.eventGroups(),
        gapsAfter: store.gapBoundaries(),
      );
      expect(
        result.items.map((e) => e.kind),
        contains(TimelineItemKind.gap),
      );
    });

    test('a store with an adjacent window yields none', () {
      final store = _store(
        tail: [_Ev('t1', _at(20))],
        window: [_Ev('w1', _at(20, minute: 59))],
      );
      final result = buildTimelineItemsFromGroups(
        store.eventGroups(),
        gapsAfter: store.gapBoundaries(),
      );
      expect(
        result.items.map((e) => e.kind),
        isNot(contains(TimelineItemKind.gap)),
      );
    });
  });
}