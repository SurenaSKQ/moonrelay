// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:integration_test/integration_test.dart';

import 'helpers/mock_matrix_http_client.dart';
import 'helpers/test_app_boot.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  // Shared test room data
  const String testRoomId = '!testroom:matrix.org';
  const String testRoomName = 'General';
  const String testRoomTopic = 'General discussion';

  late MockMatrixHttpClient mockHttp;

  /// Configures the mock HTTP client with the minimal set of handlers
  /// needed for the login flow: well-known, login flows, login POST, sync.
  void configureLoginHandlers() {
    // -- Well-known discovery (return 404 so SDK uses direct URL) --
    mockHttp.on(
      RegExp(r'\.well-known/matrix/client'),
      handler: (_) {
        return _jsonResponse(404, {'errcode': 'M_NOT_FOUND'});
      },
    );

    // -- Login flows (password supported) --
    mockHttp.on(
      RegExp(r'_matrix/client/v3/login\$'),
      handler: (req) {
        if (req.method == 'GET') {
          return _jsonResponse(200, {
            'flows': [
              {'type': 'm.login.password'},
            ],
          });
        }
        // POST  actual login
        if (req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          if (body['type'] == 'm.login.password') {
            return _jsonResponse(200, {
              'access_token': 'e2e_test_token_123',
              'device_id': 'E2ETEST',
              'user_id': '@testuser:matrix.org',
              'home_server': 'matrix.org',
            });
          }
        }
        return _jsonResponse(400, {
          'errcode': 'M_UNKNOWN',
          'error': 'Unsupported login type',
        });
      },
    );

    // -- Sync (returns rooms after login) --
    mockHttp.on(
      RegExp(r'_matrix/client/v3/sync'),
      handler: (_) {
        return _jsonResponse(200, mockHttp.buildSyncResponse());
      },
    );
  }

  setUp(() {
    mockHttp = MockMatrixHttpClient();

    // Pre-populate a room so sync responses include it
    mockHttp.addRoom(
      id: testRoomId,
      name: testRoomName,
      topic: testRoomTopic,
      timelineEvents: [
        {
          'type': 'm.room.message',
          'sender': '@user1:matrix.org',
          'content': {
            'body': 'Welcome to the room!',
            'msgtype': 'm.text',
          },
          'event_id': '\$welcomemsg',
          'origin_server_ts': 1700000000000,
        },
      ],
      stateEvents: [
        {
          'type': 'm.room.member',
          'state_key': '@testuser:matrix.org',
          'content': {
            'membership': 'join',
            'displayname': 'Test User',
          },
          'sender': '@testuser:matrix.org',
          'event_id': '\$member_event',
          'origin_server_ts': 1699000000000,
        },
      ],
    );
  });

  // ---------------------------------------------------------------------
  // Login flow
  // ---------------------------------------------------------------------

  group('Login flow', () {
    testWidgets('renders welcome screen when not logged in', (tester) async {
      configureLoginHandlers();
      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      // Initial render: splash/redirect
      await tester.pump();
      // Process the GoRouter redirect chain
      await tester.pump();
      await tester.pump();

      // The app redirects to /welcome (not logged in)
      // The Moonrelay branding should be visible
      expect(find.text('Moonrelay'), findsWidgets);
      // The "Sign In" button from the action card should be present
      expect(find.text('Sign In'), findsWidgets);
    });

    testWidgets('navigates to login page and shows form', (tester) async {
      configureLoginHandlers();
      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Tap Sign In button on startup screen --
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();

      // Now on login page  verify form fields
      expect(find.text('Homeserver'), findsOneWidget);
      expect(find.text('Username or email'), findsOneWidget);
      expect(find.text('Password'), findsOneWidget);
    });

    testWidgets('completes login and navigates to room list', (tester) async {
      configureLoginHandlers();
      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Step 1: Navigate to login page --
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();

      // -- Step 2: Fill login form --
      // TextFields: [homeserver(matrix.org), username, password]
      final fields = find.byType(TextField);
      // Username (2nd field)
      await tester.enterText(fields.at(1), 'testuser');
      await tester.pump();
      // Password (3rd field)
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump();

      // -- Step 3: Tap Sign In button on login form --
      await tester.tap(find.text('Sign in'));
      // Flush the async login chain: checkHomeserver → login POST →
      // client.init → sync request → sync response → navigate
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Step 4: Check room list / dashboard --
      // The room name should appear somewhere after successful login
      // (in the sidebar room list or as the current room header)
      expect(find.text(testRoomName), findsWidgets);
    });
  });
}

/// Helper to create a JSON HTTP response.
http.Response _jsonResponse(int status, Map<String, dynamic> body) {
  return http.Response(jsonEncode(body), status, headers: {
    'content-type': 'application/json',
  });
}
