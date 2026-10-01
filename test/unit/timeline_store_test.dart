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

// Unit tests for [TimelineStore].
//
// Pure data: a store flattens segments, dedupes overlapping events, and
// indexes by id. Every claim here is verified by mutation, because the
// failure mode this replaces was a map that was wrong by exactly one and a
// scan that silently disagreed with it.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';

import 'package:moonrelay/src/chat/timeline_store.dart';

// -- Test doubles --

class _Ev extends Mock implements Event {
  _Ev(this.id);
  final String id;
  @override
  String get eventId => id;
  @override
  String get type => EventTypes.Message;
  @override
  String get senderId => '@alice:dom';
  @override
  DateTime get originServerTs => DateTime(2024, 6, 15, 10, 0, 0);
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

    test('history comes before the live tail', () {
      // Newest-first, matching the order the `reverse: true` ListView
      // expects. The window is older than the tail, so its events have
      // higher indices and render above.
      final store = TimelineStore(live: _live(['tail1', 'tail2']))
        ..addHistory(_history(['h1', 'h2'], id: 'h1'));
      expect(_ids(store.flatten()), ['h1', 'h2', 'tail1', 'tail2']);
    });

    test('the most recently added window is flattened first', () {
      final store = TimelineStore(live: _live(['tail']))
        ..addHistory(_history(['older'], id: 'h_old'))
        ..addHistory(_history(['newer'], id: 'h_new'));
      // Newer window first, so newest-first order survives two windows.
      expect(_ids(store.flatten()), ['newer', 'older', 'tail']);
    });

    test('overlapping events appear once, not twice', () {
      // The case this exists for. A `/context` window routinely covers
      // events that are also in the live tail, because both come from the
      // same room and the window is built around an event that may be
      // inside the tail. Without the dedupe the same message renders twice.
      final store = TimelineStore(live: _live(['shared', 'tail1', 'tail2']))
        ..addHistory(_history(['win1', 'shared'], id: 'w'));

      expect(_ids(store.flatten()), ['win1', 'shared', 'tail1', 'tail2']);
      expect(
        _ids(store.flatten()).where((id) => id == 'shared').length,
        1,
      );
    });

    test('the window wins an overlap, not the tail', () {
      // Later segments overwrite earlier ones in the dedupe, and the
      // history segments are flattened first, so a window's copy of an
      // overlapping event survives. A window's events are decrypted in a
      // context that can be richer than the tail's cache.
      final tailEvent = _Ev('shared');
      final windowEvent = _Ev('shared');
      final store = TimelineStore(
        live: _live(['shared'], timeline: _T([tailEvent])),
      )..addHistory(_history(['shared'], id: 'w', timeline: _T([windowEvent])));

      expect(store.flatten().single.eventId, 'shared');
      expect(identical(store.flatten().single, windowEvent), isTrue);
    });

    test('dedupe does not reorder the survivors', () {
      final store = TimelineStore(
        live: _live(['a', 'b', 'c', 'd']),
      )..addHistory(_history(['x', 'b', 'y'], id: 'w'));
      // b keeps its window position, and the tail's copy is dropped rather
      // than shifting the tail's other events.
      expect(_ids(store.flatten()), ['x', 'b', 'y', 'a', 'c', 'd']);
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
      expect(store.indexOf('w2'), 1);
      expect(store.indexOf('tail'), 2);
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
      expect(_ids(store.flatten()), ['w2', 'tail']);
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
}