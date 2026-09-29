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
import 'package:moonrelay/src/helpers/homeserver_url.dart';

void main() {
  group('parseHomeserverInput', () {
    test('promotes a bare host to HTTPS', () {
      final uri = parseHomeserverInput('matrix.org');
      expect(uri, Uri.parse('https://matrix.org'));
      expect(uri!.scheme, 'https');
    });

    test('keeps an explicit scheme', () {
      expect(
        parseHomeserverInput('http://matrix.example:8008'),
        Uri.parse('http://matrix.example:8008'),
      );
    });

    test('trims surrounding whitespace', () {
      expect(
        parseHomeserverInput('  matrix.org  '),
        Uri.parse('https://matrix.org'),
      );
    });

    test('returns null for empty or whitespace-only input', () {
      expect(parseHomeserverInput(''), isNull);
      expect(parseHomeserverInput('   '), isNull);
    });

    test('returns null rather than throwing on unparseable input', () {
      // The callers put the result in a setState, so a thrown FormatException
      // here would escape as an unhandled error instead of a message telling
      // the user their address is wrong.
      expect(parseHomeserverInput('https://'), isNull);
      expect(parseHomeserverInput('://matrix.org'), isNull);
    });

    test('does not vouch for the address', () {
      // Parsing is not validation: the phishing guard is a separate call, and
      // this test documents that a parseable loopback URL still parses.
      final uri = parseHomeserverInput('http://localhost:8008');
      expect(uri, isNotNull);
      expect(isPlausibleHomeserverUrl(uri!), isFalse);
    });
  });
}
