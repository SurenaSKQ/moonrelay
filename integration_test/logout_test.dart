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

  const String testRoomId = '!logoutroom:matrix.org';
  const String testRoomName = 'General';

  late MockMatrixHttpClient mockHttp;

  /// Configures the mock with login + send + logout handlers.
  void configureBaseHandlers() {
    mockHttp.on(
      RegExp(r'\.well-known/matrix/client'),
      handler: (_) => _jsonResponse(404, {'errcode': 'M_NOT_FOUND'}),
    );
    mockHttp.on(
      RegExp(r'_matrix/client/v3/login$'),
      handler: (req) {
        if (req.method == 'GET') {
          return _jsonResponse(200, {
            'flows': [
              {'type': 'm.login.password'},
            ],
          });
        }
        if (req.method == 'POST') {
          return _jsonResponse(200, {
            'access_token': 'e2e_token_logout_test',
            'device_id': 'E2ELOGOUT',
            'user_id': '@testuser:matrix.org',
            'home_server': 'matrix.org',
          });
        }
        return _jsonResponse(400, {
          'errcode': 'M_UNKNOWN',
          'error': 'Unsupported login type',
        });
      },
    );
    mockHttp.on(
      RegExp(r'_matrix/client/v3/sync'),
      handler: (_) => _jsonResponse(200, mockHttp.buildSyncResponse()),
    );
  }

  setUp(() {
    mockHttp = MockMatrixHttpClient();
    mockHttp.configureSendHandlers();

    mockHttp.addRoom(
      id: testRoomId,
      name: testRoomName,
      topic: 'Discussion',
      timelineEvents: [
        {
          'sender': '@alice:matrix.org',
          'content': {
            'body': 'Hello everyone',
            'msgtype': 'm.text',
          },
          'event_id': r'$hello',
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
          'event_id': r'$member_self',
          'origin_server_ts': 1,
        },
      ],
    );
  });

  // -----------------------------------------------------------------
  // Tests
  // -----------------------------------------------------------------

  group('Logout flow', () {
    testWidgets('logout from dashboard returns to welcome screen',
        (tester) async {
      configureBaseHandlers();
      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Sign in --
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'testuser');
      await tester.pump();
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump();

      await tester.tap(find.text('Sign In').last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Verify we landed on the dashboard with our room visible.
      // Post-login processing (device keys, first sync) takes longer
      // under matrix 9.0.0, so wait for the room to populate instead
      // of asserting on the first frames.
      final roomFinder = find.text(testRoomName);
      for (var i = 0; i < 50 && roomFinder.evaluate().isEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(roomFinder, findsWidgets);

      // -- Tap the profile header to open the hub overlay --
      // The header falls back to the Matrix ID when profile fetch 404s.
      await tester.tap(find.text('@testuser:matrix.org'));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- The hub overlay shows category tabs.  Tap "Accounts". --
      await tester.tap(find.text('Accounts'));
      await tester.pump();
      await tester.pump();

      // -- Tap "Log Out" button --
      await tester.tap(find.text('Log Out'));
      // Flush the async logout chain: overlay dismiss → accountManager.logout()
      // → client.logout() POST → context.go('/')
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Verify we are back on the welcome / startup screen --
      expect(find.text('Sign In'), findsWidgets);
      // Opening the hub and navigating to accounts tab is the primary check.
      // Additional verification: no room list elements visible.
      expect(find.text(testRoomName), findsNothing);
    });
  });
}

/// Helper to create a JSON HTTP response.
http.Response _jsonResponse(int status, Map<String, dynamic> body) {
  return http.Response(jsonEncode(body), status, headers: {
    'content-type': 'application/json',
  });
}
