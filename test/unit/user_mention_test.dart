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

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/chat/events/user_mention.dart';

void main() {
  group('findUserMentions', () {
    test('finds a bare id', () {
      expect(findUserMentions('@ada:example.org'), hasLength(1));
      expect(findUserMentions('@ada:example.org').first.userId, '@ada:example.org');
    });

    test('finds an id inside a sentence, and reports where it was', () {
      final text = 'hey @ada:example.org, look at this';
      final found = findUserMentions(text);
      expect(found, hasLength(1));
      expect(text.substring(found.first.start, found.first.end), '@ada:example.org');
    });

    test('a trailing full stop is not part of the id', () {
      // The single most common shape: a mention that ends a sentence.
      final found = findUserMentions('thanks @ada:example.org.');
      expect(found, hasLength(1));
      expect(found.first.userId, '@ada:example.org');
      expect(found.first.end, 'thanks @ada:example.org.'.length - 1);
    });

    test('the trailing-punctuation guard covers the whole usual set', () {
      for (final punctuation in const ['.', ',', ';', '!', '?']) {
        final found = findUserMentions('@ada:example.org$punctuation');
        expect(
          found.first.userId,
          '@ada:example.org',
          reason: 'a trailing $punctuation must not become part of the domain',
        );
      }
    });

    test('accepts the legal localpart characters', () {
      // Matrix allows [a-z0-9._=/+-] in a localpart, and real ids use all of
      // them: bot ids with an equals, historical `-bot`, dotted addrs.
      for (final id in const [
        '@a.b:example.org',
        '@some-bot:example.org',
        '@under_score:example.org',
        '@x=1:example.org',
        '@a+b:example.org',
      ]) {
        final found = findUserMentions(id);
        expect(found, hasLength(1), reason: '$id should be a mention');
        expect(found.first.userId, id);
      }
    });

    test('accepts a port in the domain', () {
      final found = findUserMentions('@ada:example.org:8448');
      expect(found, hasLength(1));
      expect(found.first.userId, '@ada:example.org:8448');
    });

    test('does not fire on an email address', () {
      // The single most important negative: `@example.org` inside
      // `bob@example.org` is an email, and turning it into a mention pill
      // would hand a stranger's address a profile screen.
      expect(findUserMentions('write to bob@example.org'), isEmpty);
      expect(findUserMentions('bob.smith@example.org'), isEmpty);
      expect(findUserMentions('_x@example.org'), isEmpty);
    });

    test('does not fire without a domain', () {
      expect(findUserMentions('@ada'), isEmpty);
      expect(findUserMentions('@ada:'), isEmpty);
    });

    test('finds every mention in a message', () {
      final found = findUserMentions('@ada:example.org and @bob:example.org');
      expect(found.map((m) => m.userId), <String>[
        '@ada:example.org',
        '@bob:example.org',
      ]);
      // Ordered by position, which is what the renderer needs to lay them out.
      expect(found.first.start, lessThan(found.last.start));
    });

    test('handles an id at the very start and the very end of the text', () {
      expect(findUserMentions('@ada:example.org'), hasLength(1));
      expect(findUserMentions('ping @ada:example.org'), hasLength(1));
    });

    test('stops at whitespace', () {
      // Without a delimiter the domain class would eat the rest of the line.
      final found = findUserMentions('@ada:example.org and more words');
      expect(found.first.userId, '@ada:example.org');
    });

    test('empty and plain text is empty', () {
      expect(findUserMentions(''), isEmpty);
      expect(findUserMentions('nothing here'), isEmpty);
    });
  });

  group('isUserPermalink', () {
    // The regression. `_hrefUserPattern` (the thing that decides which anchors
    // become pills) accepts `http://matrix.to/...` as well as https, while
    // this function and `userIdFromHref` only recognised the https spelling.
    // An http permalink therefore rendered a mention pill *and* the redundant
    // MatrixUrlBanner that this predicate exists to suppress, which is the
    // exact duplication the check was written to prevent.
    test('a matrix.to user permalink is a user permalink over http too', () {
      expect(isUserPermalink('https://matrix.to/#/@ada:example.org'), isTrue);
      expect(isUserPermalink('http://matrix.to/#/@ada:example.org'), isTrue);
    });

    test('a matrix:u href is a user permalink', () {
      expect(isUserPermalink('matrix:u/@ada:example.org'), isTrue);
      expect(isUserPermalink('MATRIX:U/@ada:example.org'), isTrue);
    });

    test('a matrix.to room permalink is not a user permalink', () {
      expect(isUserPermalink('https://matrix.to/#/!room:example.org'), isFalse);
      expect(isUserPermalink('https://matrix.to/#/#room:example.org'), isFalse);
    });

    test('an unrelated link is not a user permalink', () {
      expect(isUserPermalink('https://example.org/@ada:example.org'), isFalse);
      expect(isUserPermalink('https://matrix.to/'), isFalse);
      expect(isUserPermalink(''), isFalse);
    });
  });

  group('userIdFromHref', () {
    test('resolves the matrix.to form', () {
      expect(
        userIdFromHref('https://matrix.to/#/@ada:example.org'),
        '@ada:example.org',
      );
    });

    test('resolves the matrix:u form', () {
      expect(userIdFromHref('matrix:u/@ada:example.org'), '@ada:example.org');
    });

    // The spec's `matrix:u/` path is percent-encoded, because a userid can
    // legally contain a `/` in the domain. Handing the encoded form to the
    // profile screen asks it for a user that does not exist.
    test('percent-encodes are decoded in the matrix:u form', () {
      expect(
        userIdFromHref('matrix:u/%40ada%3Aexample.org'),
        '@ada:example.org',
      );
      expect(
        userIdFromHref('matrix:u/@ada%3Aexample.org'),
        '@ada:example.org',
      );
    });

    test('resolves the http spelling of matrix.to', () {
      expect(
        userIdFromHref('http://matrix.to/#/@ada:example.org'),
        '@ada:example.org',
      );
    });

    test('a room permalink resolves to the room id, and the caller checks',
        () {
      // Not a bug on its own: the function resolves whatever is there, and
      // `isUserPermalink` is what distinguishes the two. Pinned so the
      // pairing stays deliberate.
      expect(isUserPermalink('https://matrix.to/#/!room:example.org'), isFalse);
      expect(
        userIdFromHref('https://matrix.to/#/!room:example.org'),
        '!room:example.org',
      );
    });

    test('an unrelated link resolves to nothing', () {
      expect(userIdFromHref('https://example.org/@ada'), isNull);
      expect(userIdFromHref(''), isNull);
    });
  });
}