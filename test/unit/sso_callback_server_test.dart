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

// Regression tests for the SSO local callback HTTP server.
//
// The server binds to a random loopback port, listens for a single
// `GET /callback?loginToken=…&state=…` request, and resolves a
// future with the token (or an error) once the request is processed.
//
// The lifecycle test is intentionally narrow:
//   - port assignment is non-zero after start
//   - state is included in the redirect URI
//   - restart swaps the state
//   - stop clears the port and is idempotent
//
// End-to-end "fire a GET and read the token future" tests are flaky in
// a single Dart VM because the server calls `stop()` *during* request
// processing, which closes the underlying socket before the client's
// HTTP parser has finished reading the response headers  see
// `lib/src/services/sso_server.dart` `_handleRequest` line ~185.
// The real flow is exercised end-to-end in `integration_test/`.

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/services/sso_server.dart';

void main() {
  group('SsoCallbackServer', () {
    late SsoCallbackServer server;

    setUp(() {
      server = SsoCallbackServer();
    });

    tearDown(() async {
      await server.stop();
    });

    test('start assigns a non-zero port and includes state in redirect URI',
        () async {
      final redirect = await server.start();
      expect(server.port, greaterThan(0));
      expect(redirect.scheme, 'http');
      // The redirect must use the loopback address the server is bound
      // to; "localhost" can resolve to IPv6 (::1) first and the server
      // only listens on 127.0.0.1.
      expect(redirect.host, '127.0.0.1');
      expect(redirect.path, '/callback');
      expect(redirect.queryParameters['state'], isNotNull);
      expect(redirect.queryParameters['state']!.length, greaterThan(20));
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('restarting swaps the expected state', () async {
      final uri1 = await server.start();
      final s1 = uri1.queryParameters['state'];
      await server.stop();
      final uri2 = await server.start();
      final s2 = uri2.queryParameters['state'];
      expect(s1, isNotNull);
      expect(s2, isNotNull);
      expect(s1, isNot(equals(s2)));
    }, timeout: const Timeout(Duration(seconds: 5)));

    test('stop clears port and is idempotent', () async {
      await server.start();
      final p = server.port;
      expect(p, greaterThan(0));
      await server.stop();
      expect(server.port, 0);
      await server.stop(); // second call must not throw
    }, timeout: const Timeout(Duration(seconds: 5)));
  });
}
