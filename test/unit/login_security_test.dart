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

/// Regression tests for the SSO homeserver phishing guard.
///
/// The user types a homeserver into the login page freeform, so a typo
/// or pasted phishing link can otherwise end up in `launchUrl(...)`.
/// `isPlausibleHomeserverUrl` is the gate; these tests pin its rules
/// so a future refactor can't silently turn a phishing URL into a
/// accepted one.
void main() {
  group('isPlausibleHomeserverUrl accepts canonical homeservers', () {
    test('accepts canonical https hosts', () {
      expect(isPlausibleHomeserverUrl(Uri.parse('https://matrix.example')),
          isTrue);
      expect(isPlausibleHomeserverUrl(Uri.parse('https://chat.example.org')),
          isTrue);
    });

    test('accepts http scheme for testing setups', () {
      expect(
          isPlausibleHomeserverUrl(Uri.parse('http://homeserver.local')),
          isTrue);
    });

    test('accepts hosts with port or path', () {
      expect(
        isPlausibleHomeserverUrl(Uri.parse('https://matrix.example:8448/')),
        isTrue,
      );
      expect(
        isPlausibleHomeserverUrl(Uri.parse('https://matrix.example/sub')),
        isTrue,
      );
    });
  });

  group('isPlausibleHomeserverUrl rejects phishing targets', () {
    test('rejects non-http(s) schemes', () {
      expect(isPlausibleHomeserverUrl(Uri.parse('file:///etc/passwd')),
          isFalse);
      expect(
          isPlausibleHomeserverUrl(Uri.parse('data:text/plain,x')), isFalse);
      expect(isPlausibleHomeserverUrl(Uri.parse('intent://foo')), isFalse);
      expect(isPlausibleHomeserverUrl(Uri.parse('javascript:alert(1)')),
          isFalse);
    });

    test('rejects loopback hosts', () {
      expect(isPlausibleHomeserverUrl(Uri.parse('https://localhost')),
          isFalse);
      expect(
          isPlausibleHomeserverUrl(Uri.parse('https://127.0.0.1:8448')),
          isFalse);
      expect(isPlausibleHomeserverUrl(Uri.parse('http://0.0.0.0/')), isFalse);
      expect(isPlausibleHomeserverUrl(Uri.parse('http://[::1]/')), isFalse);
    });

    test('rejects URLs with userinfo credentials', () {
      expect(
        isPlausibleHomeserverUrl(
          Uri.parse('https://attacker:password@evil.example/'),
        ),
        isFalse,
      );
    });

    test('rejects URLs with empty host', () {
      expect(isPlausibleHomeserverUrl(Uri.parse('https:///path-only')),
          isFalse);
    });
  });
}
