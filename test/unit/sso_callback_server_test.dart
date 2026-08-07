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
// One end-to-end callback test is included: it drives a real GET whose
// Host header matches the redirect host (127.0.0.1) and asserts the
// token future resolves. Asserting on the future, not the HTTP response
// body, sidesteps the socket race that made broader E2E coverage flaky
// (the server calls `stop()` during request processing, closing the
// listening socket before the client's parser finishes reading the
// response). The real flow is also exercised in `integration_test/`.

import 'dart:io';

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

    test('accepts a callback whose Host is the loopback redirect host',
        () async {
      // Regression: the redirect URI uses 127.0.0.1 (never "localhost",
      // which can resolve to ::1 first) but the Host-header check used to
      // only accept "localhost:$port", so every real callback was
      // rejected with "bad host header" and SSO never completed.
      final redirect = await server.start();
      final state = redirect.queryParameters['state']!;
      expect(redirect.host, '127.0.0.1');

      final tokenFuture = server.token;
      final socket = await Socket.connect('127.0.0.1', server.port);
      socket.write(
        'GET /callback?state=$state&loginToken=abc123 HTTP/1.1\r\n'
        'Host: ${redirect.host}:${server.port}\r\n'
        'Connection: close\r\n\r\n',
      );
      await socket.flush();
      await socket.close();

      expect(await tokenFuture.timeout(const Duration(seconds: 5)), 'abc123');
    }, timeout: const Timeout(Duration(seconds: 15)));
  });
}
