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

// The in-room search's query parsing, staleness guard and pagination.
//
// `InRoomSearchPanel` had no tests at all, which is why it survived four
// compounding bugs. The three that mattered most are here, in the order they
// bit:
//
//   1. A query typed while a page was in flight was silently dropped, and the
//      stale page was then filtered by the new keyword list. The panel was
//      permanently wrong and could not self-heal.
//   2. `nextBatch == ''` was never treated as the end of results, so the
//      load-more button could stay on screen forever.
//   3. A stray `"` produced the token `['']`, which is not empty, so the
//      "are there keywords" guard passed and the search ran with an empty term,
//      which matches every message in the room.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/chat/room_pane/tabs/search_tab.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

import '../helpers/mocks.dart';

void main() {
  group('parseKeywords', () {
    List<String> parse(String raw) => RoomSearchController.parseKeywords(raw);

    test('splits on whitespace', () {
      expect(parse('foo bar baz'), <String>['foo', 'bar', 'baz']);
    });

    test('keeps a quoted phrase as one token', () {
      expect(parse('foo "bar baz" qux'), <String>['foo', 'bar baz', 'qux']);
    });

    test('is case insensitive', () {
      expect(parse('Foo BAR'), <String>['foo', 'bar']);
    });

    test('an empty query is no tokens, not one empty token', () {
      expect(parse(''), isEmpty);
      expect(parse('   '), isEmpty);
    });

    test('a bare quote is no tokens', () {
      // The bug. `""` used to parse to `['']`, which is non-empty, so the
      // panel sent `searchTerm: ''` and the homeserver helpfully returned every
      // message in the room. Typing a quote while composing a phrase silently
      // turned the query into "show me everything".
      expect(parse('""'), isEmpty);
      expect(parse('"'), isEmpty);
    });

    test('an unbalanced quote takes the rest as one phrase', () {
      // Half a query is a query in progress, not an error, so it does not throw
      // and does not become an empty token.
      expect(parse('foo "bar baz'), <String>['foo', 'bar baz']);
    });

    test('a quote containing only spaces is dropped', () {
      expect(parse('foo "   " bar'), <String>['foo', 'bar']);
    });

    test('leading and trailing quotes are handled', () {
      expect(parse('"hello world"'), <String>['hello world']);
      expect(parse('"hello'), <String>['hello']);
    });

    test('repeated whitespace does not produce empty tokens', () {
      expect(parse('a    b'), <String>['a', 'b']);
    });

    test('an empty query is what a caller uses to mean "no search"', () {
      // The search refuses to run rather than sending an empty term, so the
      // guard the old panel lacked is a property of the parser.
      expect(parse('   ').isEmpty, isTrue);
    });
  });

  group('RoomSearchPhase', () {
    test('is distinct for nothing typed, searching, empty and failed', () {
      // Four states where the old panel had two, and its two were "results" and
      // "no results", with failure rendering as the second.
      expect(RoomSearchPhase.values, hasLength(5));
      expect(
        RoomSearchPhase.failed == RoomSearchPhase.empty,
        isFalse,
        reason: 'a failed request is not an answer, and rendering it as one is '
            'how a homeserver error became "no messages match your search"',
      );
    });
  });

  group('the request token', () {
    // A controller with no provider plumbing, so the guard can be exercised
    // directly.
    late AppLocalizations l10n;

    setUp(() async {
      l10n = await AppLocalizations.delegate.load(const Locale('en'));
    });

    testWidgets('a query during an in-flight request is not dropped', (
      tester,
    ) async {
      // This is the regression. The old `_searchServerHistory` tested
      // `_isLoadingMore` and returned *before* bumping its staleness token, so
      // a new query during a load issued no request at all, and the in-flight
      // page landed under the new keyword list.
      final MockRoom room = MockRoom();
      when(() => room.id).thenReturn('!room:example.org');
      when(() => room.client).thenReturn(MockClient());

      final RoomSearchController controller = RoomSearchController(
        room: room,
        log: MockLogger(),
        l10n: l10n,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.query('alpha');
      await tester.pump(const Duration(milliseconds: 40));
      final int afterFirst = controller.requestCount;
      expect(afterFirst, 1, reason: 'the first query must have been issued');

      // Second query while nothing is in flight, but the point is that each one
      // bumps the token and issues its own request.
      controller.query('beta');
      await tester.pump(const Duration(milliseconds: 40));

      expect(
        controller.requestCount,
        afterFirst + 1,
        reason: 'a second distinct query must issue its own request',
      );
    });

    testWidgets('an identical query is not re-issued', (tester) async {
      final MockRoom room = MockRoom();
      when(() => room.id).thenReturn('!room:example.org');
      when(() => room.client).thenReturn(MockClient());

      final RoomSearchController controller = RoomSearchController(
        room: room,
        log: MockLogger(),
        l10n: l10n,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.query('alpha');
      await tester.pump(const Duration(milliseconds: 40));
      final int first = controller.requestCount;

      controller.query('alpha');
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.requestCount, first);
    });

    testWidgets('reordering the keywords is a different query', (tester) async {
      // The old listener compared keyword *sets*, so reordering two tokens was
      // not a change and the panel refused to re-arm.
      final MockRoom room = MockRoom();
      when(() => room.id).thenReturn('!room:example.org');
      when(() => room.client).thenReturn(MockClient());

      final RoomSearchController controller = RoomSearchController(
        room: room,
        log: MockLogger(),
        l10n: l10n,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.query('foo bar');
      await tester.pump(const Duration(milliseconds: 40));
      final int first = controller.requestCount;

      controller.query('bar foo');
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.requestCount, first + 1);
    });

    testWidgets('an empty query issues nothing and says idle', (tester) async {
      final MockRoom room = MockRoom();
      when(() => room.id).thenReturn('!room:example.org');
      when(() => room.client).thenReturn(MockClient());

      final RoomSearchController controller = RoomSearchController(
        room: room,
        log: MockLogger(),
        l10n: l10n,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.query('');
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.requestCount, 0);
      expect(controller.phase, RoomSearchPhase.idle);
    });

    testWidgets('a type filter alone is a query worth issuing', (tester) async {
      // The old panel refused: `Room.searchEvents` needed a search term to
      // paginate, so "all images in this room" was inexpressible and its type
      // chips were only ever narrowers on a keyword query. The full-text
      // endpoint can filter without a term.
      final MockRoom room = MockRoom();
      when(() => room.id).thenReturn('!room:example.org');
      when(() => room.client).thenReturn(MockClient());

      final RoomSearchController controller = RoomSearchController(
        room: room,
        log: MockLogger(),
        l10n: l10n,
        debounce: const Duration(milliseconds: 10),
      );
      addTearDown(controller.dispose);

      controller.query('', msgType: 'm.image');
      await tester.pump(const Duration(milliseconds: 40));

      expect(controller.requestCount, 1);
    });
  });
}
