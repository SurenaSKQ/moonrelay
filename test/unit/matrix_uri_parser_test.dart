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

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/matrix_uri_parser.dart';

void main() {
  group('MatrixUriParser', () {
    // ── matrix: scheme parsing ─────────────────────────────────
    group('matrix: scheme', () {
      test('parses matrix:r/!roomid:domain', () {
        final result = MatrixUriParser.parse('matrix:r/!roomid:example.org');
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.room);
        expect(result.entityId, '!roomid:example.org');
        expect(result.viaServers, isEmpty);
      });

      test('parses matrix://r/!roomid:domain', () {
        final result = MatrixUriParser.parse('matrix://r/!roomid:example.org');
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.room);
        expect(result.entityId, '!roomid:example.org');
      });

      test('parses matrix:u/@user:domain', () {
        final result = MatrixUriParser.parse('matrix:u/@user:example.org');
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.user);
        expect(result.entityId, '@user:example.org');
      });

      test('parses matrix:roomid/!roomid:domain (legacy)', () {
        final result = MatrixUriParser.parse('matrix:roomid/!roomid:example.org');
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.room);
        expect(result.entityId, '!roomid:example.org');
      });

      test('parses with via servers', () {
        final result = MatrixUriParser.parse(
          'matrix:r/!roomid:example.org?via=server1.org&via=server2.org',
        );
        expect(result, isNotNull);
        expect(result!.entityId, '!roomid:example.org');
        expect(result.viaServers, ['server1.org', 'server2.org']);
      });

      test('rejects malformed matrix: URIs', () {
        expect(MatrixUriParser.parse('matrix:invalid'), isNull);
        expect(MatrixUriParser.parse('matrix:r/'), isNull);
        expect(MatrixUriParser.parse('matrix:u/'), isNull);
      });

      test('rejects matrix:r/ without ! prefix', () {
        final result = MatrixUriParser.parse('matrix:r/roomid:example.org');
        expect(result, isNull);
      });
    });

    // ── matrix.to permalink parsing ────────────────────────────
    group('matrix.to permalink', () {
      test('parses room permalink', () {
        final result = MatrixUriParser.parse(
          'https://matrix.to/#/!roomid:example.org',
        );
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.room);
        expect(result.entityId, '!roomid:example.org');
      });

      test('parses user permalink', () {
        final result = MatrixUriParser.parse(
          'https://matrix.to/#/@user:example.org',
        );
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.user);
        expect(result.entityId, '@user:example.org');
      });

      test('parses room alias permalink', () {
        final result = MatrixUriParser.parse(
          'https://matrix.to/#/#alias:example.org',
        );
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.roomAlias);
        expect(result.entityId, '#alias:example.org');
        expect(result.displayAlias, '#alias:example.org');
      });

      test('parses with via servers', () {
        final result = MatrixUriParser.parse(
          'https://matrix.to/#/!roomid:example.org?via=server1.org',
        );
        expect(result, isNotNull);
        expect(result!.entityId, '!roomid:example.org');
        expect(result.viaServers, ['server1.org']);
      });

      test('handles URL-encoded characters in fragment', () {
        final result = MatrixUriParser.parse(
          'https://matrix.to/#/%23alias%3Aexample.org',
        );
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.roomAlias);
        expect(result.entityId, '#alias:example.org');
      });
    });

    // ── parseAll (scanning text) ────────────────────────────────
    group('parseAll', () {
      test('finds matrix: URIs in plain text', () {
        final results = MatrixUriParser.parseAll(
          'Check out matrix:r/!roomid:example.org for more info',
        );
        expect(results, hasLength(1));
        expect(results.first.entityId, '!roomid:example.org');
      });

      test('finds matrix.to URIs in plain text', () {
        final results = MatrixUriParser.parseAll(
          'Join us at https://matrix.to/#/!room:example.org',
        );
        expect(results, hasLength(1));
        expect(results.first.entityId, '!room:example.org');
      });

      test('finds multiple URIs in the same text', () {
        final results = MatrixUriParser.parseAll(
          'Room: matrix:r/!a:org and user: https://matrix.to/#/@b:org',
        );
        expect(results, hasLength(2));
      });

      test('deduplicates repeated URIs', () {
        final results = MatrixUriParser.parseAll(
          'matrix:r/!room:org and again matrix:r/!room:org',
        );
        expect(results, hasLength(1));
      });

      test('returns empty list for text without matrix URIs', () {
        final results = MatrixUriParser.parseAll('Just a normal message.');
        expect(results, isEmpty);
      });

      test('returns empty list for empty text', () {
        expect(MatrixUriParser.parseAll(''), isEmpty);
      });
    });

    // ── URI builder methods ────────────────────────────────────
    group('buildRoomUri', () {
      test('builds basic room URI', () {
        final uri = MatrixUriParser.buildRoomUri('!roomid:example.org');
        expect(uri, 'matrix:r/!roomid:example.org');
      });

      test('builds room URI with via servers', () {
        final uri = MatrixUriParser.buildRoomUri(
          '!roomid:example.org',
          via: ['server1.org', 'server2.org'],
        );
        expect(uri, 'matrix:r/!roomid:example.org?via=server1.org,server2.org');
      });
    });

    group('buildMatrixToPermalink', () {
      test('builds basic permalink', () {
        final uri = MatrixUriParser.buildMatrixToPermalink('!roomid:example.org');
        expect(uri, 'https://matrix.to/#/!roomid:example.org');
      });

      test('builds permalink with via servers', () {
        final uri = MatrixUriParser.buildMatrixToPermalink(
          '!roomid:example.org',
          via: ['server1.org'],
        );
        expect(uri, 'https://matrix.to/#/!roomid:example.org?via=server1.org');
      });
    });

    // ── Bare Matrix ID parsing ──────────────────────────────────
    group('bare Matrix IDs', () {
      test('parses @user:domain as user', () {
        final result = MatrixUriParser.parse('@user:example.org');
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.user);
        expect(result.entityId, '@user:example.org');
      });

      test('parses !room:domain as room', () {
        final result = MatrixUriParser.parse('!roomid:example.org');
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.room);
        expect(result.entityId, '!roomid:example.org');
      });

      test('parses #alias:domain as room alias', () {
        final result = MatrixUriParser.parse('#alias:example.org');
        expect(result, isNotNull);
        expect(result!.entityType, MatrixUriEntity.roomAlias);
        expect(result.entityId, '#alias:example.org');
        expect(result.displayAlias, '#alias:example.org');
      });

      test('rejects bare ID without colon', () {
        expect(MatrixUriParser.parse('@user'), isNull);
        expect(MatrixUriParser.parse('!room'), isNull);
        expect(MatrixUriParser.parse('#alias'), isNull);
      });

      test('rejects bare ID with only sigil before colon', () {
        expect(MatrixUriParser.parse('@:domain'), isNull);
        expect(MatrixUriParser.parse('!:domain'), isNull);
        expect(MatrixUriParser.parse('#:domain'), isNull);
      });

      test('returns null for non-matrix text', () {
        expect(MatrixUriParser.parse('hello'), isNull);
        expect(MatrixUriParser.parse('email@example.com'), isNull);
      });

      test('strips trailing punctuation', () {
        final result = MatrixUriParser.parse('@user:example.org!');
        expect(result, isNotNull);
        expect(result!.entityId, '@user:example.org');
      });

      test('strips multiple trailing punctuation chars', () {
        final result = MatrixUriParser.parse('!room:example.org,.)');
        expect(result, isNotNull);
        expect(result!.entityId, '!room:example.org');
      });
    });

    group('parseAll with bare IDs', () {
      test('finds bare user ID in plain text', () {
        final results = MatrixUriParser.parseAll(
          'Contact @user:example.org for details',
        );
        expect(results, hasLength(1));
        expect(results.first.entityType, MatrixUriEntity.user);
        expect(results.first.entityId, '@user:example.org');
      });

      test('does not detect bare room IDs in plain text', () {
        // Bare room IDs (starting with `!`) are deliberately excluded from
        // `parseAll` — they are random-looking 26-character strings that
        // collide with normal prose.  Use `matrix:r/!room:domain` instead.
        final results = MatrixUriParser.parseAll(
          'Join !room:example.org for discussion',
        );
        expect(results, isEmpty);
      });

      test('finds bare alias in plain text', () {
        final results = MatrixUriParser.parseAll(
          'Come to #alias:example.org',
        );
        expect(results, hasLength(1));
        expect(results.first.entityType, MatrixUriEntity.roomAlias);
        expect(results.first.entityId, '#alias:example.org');
      });

      test('finds bare IDs alongside matrix URLs', () {
        final results = MatrixUriParser.parseAll(
          'See matrix:r/!a:org and contact @user:domain.org',
        );
        expect(results, hasLength(2));
      });

      test('finds bare user IDs near brackets and quotes', () {
        final results = MatrixUriParser.parseAll(
          'text (@user:example.org) more end',
        );
        expect(results, hasLength(1));
        expect(results.first.entityId, '@user:example.org');
      });

      test('does not match hashtags without domain', () {
        final results = MatrixUriParser.parseAll(
          'This is a #hashtag not a matrix alias',
        );
        expect(results, isEmpty);
      });

      test('does not match email addresses', () {
        final results = MatrixUriParser.parseAll(
          'Send email to user@example.com for info',
        );
        expect(results, isEmpty);
      });

      test('does not match bare hostnames as Matrix aliases', () {
        // Regression: "Visit matrix.org!" used to match `matrix.org` as a
        // bare alias; the trailing `(?<![.,;!?)])` lookbehind now rejects
        // sentence punctuation glued to the identifier.
        final results = MatrixUriParser.parseAll(
          'Visit matrix.org!',
        );
        expect(results, isEmpty);
      });
    });
    group('MatrixUriResult', () {
      test('isRoom returns true for room entities', () {
        const roomResult = MatrixUriResult(
          entityType: MatrixUriEntity.room,
          entityId: '!room:org',
        );
        const aliasResult = MatrixUriResult(
          entityType: MatrixUriEntity.roomAlias,
          entityId: '#alias:org',
        );
        const userResult = MatrixUriResult(
          entityType: MatrixUriEntity.user,
          entityId: '@user:org',
        );
        expect(roomResult.isRoom, isTrue);
        expect(aliasResult.isRoom, isTrue);
        expect(userResult.isRoom, isFalse);
      });

      test('joinId returns displayAlias when present', () {
        const result = MatrixUriResult(
          entityType: MatrixUriEntity.roomAlias,
          entityId: '#alias:org',
          displayAlias: '#alias:org',
        );
        expect(result.joinId, '#alias:org');
      });

      test('joinId returns entityId when no displayAlias', () {
        const result = MatrixUriResult(
          entityType: MatrixUriEntity.room,
          entityId: '!room:org',
        );
        expect(result.joinId, '!room:org');
      });
    });
  });
}
