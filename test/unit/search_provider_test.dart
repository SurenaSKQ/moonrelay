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

// Pin tests for the generalized SearchProvider.
//
// Every search-aware UI surface (the command palette and any future
// surface) delegates to this single class; pinning a few invariants
// makes sure the pagination contract stays consistent across call
// sites.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';

class _MockClient extends Mock implements Client {}

void main() {
  late _MockClient client;
  late SearchProvider provider;

  setUp(() {
    client = _MockClient();
    provider = SearchProvider(client: client);
  });

  test('empty query returns no rooms or spaces', () {
    when(() => client.rooms).thenReturn(<Room>[]);
    final roomsPage = provider.searchRoomsFirstPage('');
    final spacesPage = provider.searchSpacesFirstPage('');
    expect(roomsPage.items, isEmpty);
    expect(roomsPage.hasMore, isFalse);
    expect(spacesPage.items, isEmpty);
    expect(spacesPage.hasMore, isFalse);
  });

  test('server-side helpers return empty pages for empty query', () async {
    final msgs = await provider.searchMessagesFirstPage('');
    final homeserver = await provider.searchHomeserverFirstPage('');
    final users = provider.searchUsersFirstPage('');
    expect(msgs.items, isEmpty);
    expect(msgs.hasMore, isFalse);
    expect(homeserver.items, isEmpty);
    expect(homeserver.hasMore, isFalse);
    expect(users.items, isEmpty);
    expect(users.hasMore, isFalse);
  });

  test('SearchPage.empty reports "no more results"', () {
    // Pin T with a helper function because Dart's inference loses the
    // generic context on type-prefixed static factory calls.
    SearchPage<int> makeEmpty() => SearchPage<int>.empty();
    final page = makeEmpty();
    expect(page.items, isEmpty);
    expect(page.hasMore, isFalse);
    expect(page.nextBatch, isNull);
    expect(page.offset, isNull);
  });

  test('SearchPageRequest carries query, next-batch and offset', () {
    const req = SearchPageRequest(query: 'hi', nextBatch: 'tok', offset: 24);
    expect(req.query, 'hi');
    expect(req.nextBatch, 'tok');
    expect(req.offset, 24);
  });
}
