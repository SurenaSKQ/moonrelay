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

// Unit tests for the [SearchProvider] user-directory caching contract
// that the command palette relies on.  When the user types `?query` we
// expect users to be searched alongside rooms/spaces/messages/homeserver,
// and the `?` (search) mode pagination should reuse the cached user
// results without re-querying the homeserver.

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:mocktail/mocktail.dart';
import 'package:moonrelay/src/widgets/search_provider.dart';

import '../helpers/mocks.dart';

void main() {
  group('SearchProvider user-directory cache', () {
    late MockClient client;

    setUp(() {
      client = MockClient();
    });

    test(
      'searchUsersFirstPage returns empty for an empty query',
      () {
        final provider = SearchProvider(client: client);
        final page = provider.searchUsersFirstPage('', limit: 10);
        expect(page.items, isEmpty);
        expect(page.hasMore, isFalse);
      },
    );

    test(
      'nextUsersPage returns empty when the cache is cold',
      () {
        final provider = SearchProvider(client: client);
        final page = provider.nextUsersPage(
          SearchPageRequest(query: 'someone', offset: 0),
          limit: 10,
        );
        expect(page.items, isEmpty,
            reason: 'no fetchUsersPage call yet → empty page');
      },
    );

    test(
      'nextUsersPage returns a sub-page from the cached results',
      () async {
        // Stub the user-directory search to return 25 mock profiles
        // (so we can paginate past the default 10).
        final response = _StubUserSearchResponse(
          results: List<Profile>.generate(25, (i) => _StubProfile('@u$i:hs')),
        );
        when(() => client.searchUserDirectory(any(), limit: any(named: 'limit')))
            .thenAnswer((_) async => response);

        final provider = SearchProvider(client: client);
        // First fetch populates the cache.
        final firstPage = await provider.fetchUsersPage('hello', limit: 10);
        expect(firstPage.items.length, 10);
        expect(firstPage.hasMore, isTrue);

        // Now continue paging from the cache.
        final nextPage = provider.nextUsersPage(
          SearchPageRequest(query: 'hello', offset: 10),
          limit: 10,
        );
        expect(nextPage.items.length, 10);
        expect(nextPage.hasMore, isTrue);

        final lastPage = provider.nextUsersPage(
          SearchPageRequest(query: 'hello', offset: 20),
          limit: 10,
        );
        expect(lastPage.items.length, 5);
        expect(lastPage.hasMore, isFalse);
      },
    );

    test(
      'changing the query invalidates the user cache',
      () async {
        final firstResponse = _StubUserSearchResponse(
          results: [_StubProfile('@a:hs')],
        );
        final secondResponse = _StubUserSearchResponse(
          results: [_StubProfile('@b:hs')],
        );
        var lastQuery = '';
        when(() => client.searchUserDirectory(any(), limit: any(named: 'limit')))
            .thenAnswer((invocation) async {
          lastQuery = invocation.positionalArguments[0] as String;
          return lastQuery == 'alpha' ? firstResponse : secondResponse;
        });

        final provider = SearchProvider(client: client);
        await provider.fetchUsersPage('alpha', limit: 10);
        expect(
          (await provider.fetchUsersPage('alpha', limit: 10))
              .items
              .first
              .userId,
          '@a:hs',
        );

        // New query — the cache should be replaced.
        final newPage = await provider.fetchUsersPage('beta', limit: 10);
        expect(newPage.items.first.userId, '@b:hs');
        expect(lastQuery, 'beta');
      },
    );
  });
}

// ── Test stubs ───────────────────────────────────────────────────────

class _StubUserSearchResponse extends Mock
    implements SearchUserDirectoryResponse {
  _StubUserSearchResponse({required this.results});
  @override
  final List<Profile> results;
  @override
  bool get limited => false;
}

class _StubProfile extends Mock implements Profile {
  _StubProfile(this.userId);
  @override
  final String userId;
  @override
  String toString() => userId;
}
