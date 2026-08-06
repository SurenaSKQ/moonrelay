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

  // -- Shared test data ----------------------------------------------
  const String testRoomId = '!devteam:matrix.org';
  const String testRoomName = 'Dev Team';
  const String testRoomTopic = 'Development discussion';

  late MockMatrixHttpClient mockHttp;

  /// Configures the mock with the login flow handlers.
  void configureLoginHandlers() {
    mockHttp.on(
      RegExp(r'\.well-known/matrix/client'),
      handler: (_) => _jsonResponse(404, {'errcode': 'M_NOT_FOUND'}),
    );
    mockHttp.on(
      RegExp(r'_matrix/client/v3/login$'),
      handler: (req) {
        if (req.method == 'GET') {
          return _jsonResponse(200, {
            'flows': [{'type': 'm.login.password'}],
          });
        }
        if (req.method == 'POST') {
          return _jsonResponse(200, {
            'access_token': 'e2e_token_room_test',
            'device_id': 'E2EROOM',
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

    // One room with a few messages in the timeline
    mockHttp.addRoom(
      id: testRoomId,
      name: testRoomName,
      topic: testRoomTopic,
      timelineEvents: [
        {
          'sender': '@alice:matrix.org',
          'content': {
            'body': 'Hey team, check the new PR',
            'msgtype': 'm.text',
          },
          'event_id': r'$msg1',
          'origin_server_ts': 1700100000000,
        },
        {
          'sender': '@bob:matrix.org',
          'content': {
            'body': 'On it!',
            'msgtype': 'm.text',
          },
          'event_id': r'$msg2',
          'origin_server_ts': 1700100010000,
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
          'event_id': r'$member1',
          'origin_server_ts': 1,
        },
      ],
      joinedMembers: 3,
    );
  });

  // -----------------------------------------------------------------
  // Tests
  // -----------------------------------------------------------------

  group('Room interaction flow', () {
    testWidgets('shows room list after login', (tester) async {
      configureLoginHandlers();
      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Login --
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'testuser');
      await tester.pump();
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump();

      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Verify room is visible --
      expect(find.text(testRoomName), findsWidgets);
      // The topic might also be visible in the sidebar or header
      expect(find.text(testRoomTopic), findsWidgets);
    });

    testWidgets('tapping a room shows its messages', (tester) async {
      configureLoginHandlers();
      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Login --
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'testuser');
      await tester.pump();
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump();

      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Tap on the room in the sidebar --
      await tester.tap(find.text(testRoomName).last);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Check that timeline messages appear --
      // The messages pre-populated in sync should be visible
      expect(find.text('Hey team, check the new PR'), findsWidgets);
      expect(find.text('On it!'), findsWidgets);
    });

    testWidgets('sending a message shows it in the timeline', (tester) async {
      configureLoginHandlers();
      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Login --
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();

      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'testuser');
      await tester.pump();
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump();

      await tester.tap(find.text('Sign in'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- Tap on the room in the sidebar --
      await tester.tap(find.text(testRoomName).last);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // -- ChatBox should now be visible with a send button --
      final sendButton = find.bySemanticsLabel('Send');
      expect(sendButton, findsOneWidget);

      // -- Type a message into the ChatBox text field --
      const message = 'Hello from the integration test!';
      final chatField = find.byType(TextField).last;
      await tester.enterText(chatField, message);
      await tester.pump();

      // -- Tap the send button --
      await tester.tap(sendButton);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();

      // -- Verify the sent message appears in the timeline (local echo) --
      expect(find.text(message), findsWidgets);

      // -- Verify the mock HTTP client captured the request --
      expect(mockHttp.sentMessages.length, greaterThan(0));
      expect(
        mockHttp.sentMessages.first['body'],
        message,
      );
    });
  });
}

/// Helper to create a JSON HTTP response.
http.Response _jsonResponse(int status, Map<String, dynamic> body) {
  return http.Response(jsonEncode(body), status, headers: {
    'content-type': 'application/json',
  });
}
