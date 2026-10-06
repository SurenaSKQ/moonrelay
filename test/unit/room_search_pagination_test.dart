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

// In-room search pagination.
//
// The parser and the staleness guard have their own file. This one is about the
// cursor, and every case here is a way the old panel went wrong.
//
// The old panel inferred "no more results" from `_nextBatch != null`. That is
// not the same as there being more, because the spec lets a homeserver echo the
// token you sent back, and plenty do. The button stayed on screen forever with
// nothing behind it. `hasMore` is explicit here and an empty page ends the list
// whatever the cursor says.
//
// There was also no dedupe. An overlapping page produced duplicate rows with no
// way for the user to tell, because two identical tiles look like a rendering
// bug rather than two hits.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/room_pane/tabs/search_tab.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';

import '../helpers/mocks.dart';

/// A `Result` carrying a matrix event with [eventId].
Result _result(String eventId) => Result(
      rank: 1,
      result: MatrixEvent(
        eventId: eventId,
        // The provider drops any hit whose room is not the one it asked about,
        // so the fake has to carry one. Without it every row is filtered away
        // and the tests pass for the wrong reason.
        roomId: '!r:example.org',
        senderId: '@alice:example.org',
        originServerTs: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        type: 'm.room.message',
        content: <String, Object?>{'msgtype': 'm.text', 'body': 'hello'},
      ),
    );

/// A `SearchResults` for one page of message hits.
SearchResults _page(
  List<String> eventIds, {
  String? nextBatch,
}) =>
    SearchResults(
      searchCategories: ResultCategories(
        roomEvents: ResultRoomEvents(
          results: eventIds.map(_result).toList(growable: false),
          nextBatch: nextBatch,
        ),
      ),
    );

/// Stands in for `SearchProvider` from the outside: a room whose client answers
/// `search` with pages the test dictates, and remembers the cursors it was
/// given.
class _FakeClient extends Mock implements Client {
  static final Client _owner = MockClient();
  final List<String?> askedForBatch = <String?>[];
  final List<SearchResults> responses = <SearchResults>[];

  /// Thrown instead of answered when set, so a page can fail on demand.
  Object? failWith;

  /// When set, the next request parks on a [Completer] the test completes by
  /// hand, and that call is pushed onto [gates].
  ///
  /// This is what makes a *late* answer possible at all. [responses] is a queue
  /// that always resolves at once, so two requests issued in order always
  /// complete in order. A staleness test written against a queue like that
  /// cannot distinguish "the guard worked" from "the answers happened to land
  /// in a harmless order".
  bool holdNext = false;
  final List<Completer<SearchResults>> gates = <Completer<SearchResults>>[];

  @override
  Room? getRoomById(String roomId) => _room;

  @override
  List<Room> get rooms => <Room>[_room];

  // Stubbed rather than bare: Event.fromMatrixEvent reads the room it is
  // given, and an unstubbed mocktail getter returns null where a getter
  // expects a String, which surfaces as a TypeError from inside the SDK.
  final Room _room = _stubbedRoom();

  static Room _stubbedRoom() {
    final MockRoom room = MockRoom();
    when(() => room.id).thenReturn('!r:example.org');
    when(() => room.getLocalizedDisplayname()).thenReturn('Test Room');
    when(() => room.client).thenReturn(_FakeClient._owner);
    return room;
  }

  @override
  Future<SearchResults> search(
    Categories categories, {
    String? nextBatch,
  }) async {
    askedForBatch.add(nextBatch);
    final Object? failure = failWith;
    if (failure != null) throw failure;
    if (holdNext) {
      holdNext = false;
      final Completer<SearchResults> gate = Completer<SearchResults>();
      gates.add(gate);
      return gate.future;
    }
    return responses.isEmpty ? _page(<String>[]) : responses.removeAt(0);
  }
}

void main() {
  late AppLocalizations l10n;

  setUp(() async {
    l10n = await AppLocalizations.delegate.load(const Locale('en'));
  });

  RoomSearchController controllerWith(
    _FakeClient client, {
    Duration debounce = const Duration(milliseconds: 10),
  }) {
    final MockRoom room = MockRoom();
    when(() => room.id).thenReturn('!r:example.org');
    when(() => room.getLocalizedDisplayname()).thenReturn('Test Room');
    when(() => room.client).thenReturn(client);
    return RoomSearchController(
      room: room,
      log: MockLogger(),
      l10n: l10n,
      debounce: debounce,
    );
  }

  List<String> idsOf(RoomSearchController c) =>
      c.results.map((MessageSearchResult r) => r.event.eventId).toList();

  group('the cursor', () {
    testWidgets('first page asks with no cursor', (tester) async {
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA'], nextBatch: 'p2'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));

      expect(client.askedForBatch, <String?>[null]);
      expect(c.hasMore, isTrue);
    });

    testWidgets('the next page sends the cursor it was given', (tester) async {
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA'], nextBatch: 'p2'))
        ..responses.add(_page(<String>['evtB'], nextBatch: 'p3'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));
      await c.loadMore();

      expect(client.askedForBatch, <String?>[null, 'p2']);
      expect(idsOf(c), <String>['evtA', 'evtB']);
    });

    testWidgets('an empty nextBatch ends the list', (tester) async {
      // The specific case the old panel got wrong. `''` is a legal and common
      // end-of-results answer, and `nextBatch != null` is true for it, so the
      // button stayed and clicking it returned nothing, forever.
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA'], nextBatch: ''));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));

      expect(c.hasMore, isFalse);
      expect(idsOf(c), <String>['evtA']);
    });

    testWidgets('an echoed cursor ends the list too', (tester) async {
      // A homeserver that sends the token you gave it back means there is
      // nothing more. It is permitted by the spec and common in practice, and
      // it is indistinguishable from progress unless an empty page also ends
      // the list.
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA'], nextBatch: 'p2'))
        ..responses.add(_page(<String>['evtB'], nextBatch: 'p2'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));
      await c.loadMore();

      expect(c.hasMore, isFalse);
    });

    testWidgets('an empty page ends the list whatever the cursor says',
        (tester) async {
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA'], nextBatch: 'p2'))
        ..responses.add(_page(<String>[], nextBatch: 'p3'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));
      await c.loadMore();

      expect(c.hasMore, isFalse);
      expect(idsOf(c), <String>['evtA'], reason: 'nothing was lost');
    });

    testWidgets('a new query resets the cursor', (tester) async {
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA'], nextBatch: 'p2'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));
      expect(c.hasMore, isTrue);

      client.responses.add(_page(<String>['evtZ']));
      c.query('other');
      await tester.pump(const Duration(milliseconds: 40));

      expect(idsOf(c), <String>['evtZ']);
      expect(c.hasMore, isFalse);
    });
  });

  group('overlapping pages', () {
    testWidgets('an event already shown is not shown twice', (tester) async {
      // No dedupe existed. Two identical tiles read as a rendering bug, and
      // there was no way for the user to tell it from one.
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA', 'evtB'], nextBatch: 'p2'))
        ..responses.add(_page(<String>['evtB', 'evtC'], nextBatch: 'p3'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));
      await c.loadMore();

      expect(idsOf(c), <String>['evtA', 'evtB', 'evtC']);
    });

    testWidgets('a page that is entirely duplicates still ends the list',
        (tester) async {
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA'], nextBatch: 'p2'))
        ..responses.add(_page(<String>['evtA'], nextBatch: 'p3'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));
      await c.loadMore();

      expect(idsOf(c), <String>['evtA']);
      expect(
        c.hasMore,
        isTrue,
        reason: 'the page was not empty, so the cursor is still live; the next '
            'load must be what stops it',
      );

      client.responses.add(_page(<String>[], nextBatch: 'p4'));
      await c.loadMore();
      expect(c.hasMore, isFalse);
    });
  });

  group('a page that arrives after the query moved on', () {
    testWidgets('cannot land', (tester) async {
      // The bug this whole file is downstream of. The old panel bumped its
      // staleness token *after* the in-flight check, so a query typed during a
      // load issued no request and the in-flight page was then filtered by the
      // new keyword list and appended to the old results.
      final _FakeClient client = _FakeClient()..holdNext = true;

      final RoomSearchController c = controllerWith(
        client,
        debounce: const Duration(milliseconds: 60),
      );
      addTearDown(c.dispose);

      c.query('old');
      // The first request goes out and parks on the gate.
      await tester.pump(const Duration(milliseconds: 80));
      expect(client.gates, hasLength(1),
          reason: 'the first query is in flight');

      // The second query answers immediately, so it overtakes the first.
      client.responses.add(_page(<String>['evtNew']));
      c.query('new');
      await tester.pump(const Duration(milliseconds: 80));
      expect(idsOf(c), <String>['evtNew']);

      // Only now does the stale answer land.
      client.gates.first.complete(_page(<String>['evtStale'], nextBatch: 'p9'));
      await tester.pump();

      expect(
        idsOf(c),
        <String>['evtNew'],
        reason: 'a page for a query that has been superseded must not append',
      );
      // And it must not leave the next page asking the stale query's cursor.
      expect(c.hasMore, isFalse);
    });

    testWidgets('the count reflects only the live query', (tester) async {
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtOld1', 'evtOld2'], nextBatch: 'p2'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('old');
      await tester.pump(const Duration(milliseconds: 40));
      expect(idsOf(c), hasLength(2));

      client.responses.add(_page(<String>['evtNew']));
      c.query('new');
      await tester.pump(const Duration(milliseconds: 40));

      // One request, one result set. If the old page had leaked in there would
      // be three rows for a query that matched one.
      expect(c.requestCount, 2);
      expect(idsOf(c), <String>['evtNew']);
    });
  });

  group('paging does not disturb the query', () {
    testWidgets('loadMore does not bump the request token', (tester) async {
      // The palette documents why this matters: paginating asks the same
      // question again, and invalidating it would drop the user's scroll
      // position on every page.
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA'], nextBatch: 'p2'))
        ..responses.add(_page(<String>['evtB'], nextBatch: 'p3'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));
      await c.loadMore();

      // The token is unchanged, so a page arriving late from the *first*
      // request would still be accepted. That is the same property, seen from
      // the other side: paging did not invalidate anything.
      expect(idsOf(c), <String>['evtA', 'evtB']);
      expect(client.askedForBatch, <String?>[null, 'p2']);
      // `requestCount` counts queries, and that is the assertion: a page is
      // not a new question, so paging must leave the count at one. Bumping it
      // would also invalidate the token this test is about.
      expect(c.requestCount, 1);
    });

    testWidgets('a load while a page is already loading is refused',
        (tester) async {
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA'], nextBatch: 'p2'))
        ..responses.add(_page(<String>['evtB'], nextBatch: 'p3'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));

      final Future<void> first = c.loadMore();
      await c.loadMore(); // second call while the first is in flight
      await first;
      await tester.pump();

      expect(client.askedForBatch, <String?>[null, 'p2']);
      expect(idsOf(c), <String>['evtA', 'evtB']);
    });
  });

  group('a failed page', () {
    testWidgets('stops paging and keeps the rows already on screen',
        (tester) async {
      // A failed page is not a failed search. Throwing away real results to say
      // "could not load more" would be strictly worse than leaving them.
      final _FakeClient client = _FakeClient()
        ..responses.add(_page(<String>['evtA', 'evtB'], nextBatch: 'p2'));
      final RoomSearchController c = controllerWith(client);
      addTearDown(c.dispose);

      c.query('hello');
      await tester.pump(const Duration(milliseconds: 40));

      client.failWith = Exception('M_UNKNOWN');
      await c.loadMore();
      await tester.pump();

      expect(idsOf(c), <String>['evtA', 'evtB']);
      expect(c.hasMore, isFalse);
      expect(c.phase, RoomSearchPhase.results, reason: 'not a failed search');
    });
  });
}
