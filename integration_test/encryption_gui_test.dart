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

/// End-to-end smoke tests for the encryption flow.
///
/// These tests drive the real app through:
///   - a logged-in dashboard
///   - the encryption service init pipeline
/// and verify that the SDK bootstrapped encryption state correctly.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const String testRoomId = '!encryptedroom:matrix.org';
  const String testRoomName = 'Encrypted Room';

  late MockMatrixHttpClient mockHttp;

  /// Login + sync handlers that get the user to the room list.
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
            'access_token': 'e2e_enc_token',
            'device_id': mockHttp.currentDeviceId,
            'user_id': '@testuser:matrix.org',
            'home_server': 'matrix.org',
          });
        }
        return _jsonResponse(400, {'errcode': 'M_UNKNOWN'});
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
      topic: 'Encrypted discussion',
      timelineEvents: [
        {
          'sender': '@alice:matrix.org',
          'content': {
            'body': 'hello',
            'msgtype': 'm.text',
          },
          'event_id': r'$hello',
          'origin_server_ts': 1700000000000,
        }
      ],
      stateEvents: [
        {
          'type': 'm.room.encryption',
          'state_key': '',
          'content': {
            'algorithm': 'm.megolm.v1.aes-sha2',
          },
          'sender': '@alice:matrix.org',
          'event_id': r'$enc_state',
          'origin_server_ts': 1,
        },
        {
          'type': 'm.room.member',
          'state_key': '@testuser:matrix.org',
          'content': {'membership': 'join'},
          'sender': '@testuser:matrix.org',
          'event_id': r'$member_self',
          'origin_server_ts': 1,
        }
      ],
    );
  });

  group('Encryption GUI', () {
    testWidgets('login + encryption init does not crash the app',
        (tester) async {
      configureBaseHandlers();
      mockHttp.configureEncryptionHandlers();

      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Sign in.
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'testuser');
      await tester.pump();
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump();
      await tester.tap(find.text('Sign in'));

      // Flush the async login + encryption init chain.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();

      // The room we set up should be visible on the dashboard.
      expect(find.text(testRoomName), findsWidgets);
    });

    testWidgets('encryption device GET handler fires after login',
        (tester) async {
      configureBaseHandlers();
      mockHttp.configureEncryptionHandlers();

      // Override the /devices handler to capture the request.
      final captured = <Map<String, dynamic>>[];
      mockHttp.on(
        RegExp(r'_matrix/client/v3/devices$'),
        handler: (req) {
          captured.add({'method': req.method, 'path': req.url.path});
          return _jsonResponse(200, {
            'devices': mockHttp.whenDevicesRequested(),
          });
        },
      );

      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Sign in.
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'testuser');
      await tester.pump();
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump();
      await tester.tap(find.text('Sign in'));

      // Flush login + encryption init chain.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();

      // The encryption service's _refreshMyDevices() should have caused
      // a GET /devices call.
      expect(captured.length, greaterThan(0));
      expect(captured.first['method'], 'GET');
    });

    testWidgets('encrypted room can be opened and shows messages',
        (tester) async {
      configureBaseHandlers();
      mockHttp.configureEncryptionHandlers();

      await tester.pumpWidget(await buildTestApp(mockHttp: mockHttp));
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Sign in.
      await tester.tap(find.text('Sign In'));
      await tester.pump();
      await tester.pump();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(1), 'testuser');
      await tester.pump();
      await tester.enterText(fields.at(2), 'password123');
      await tester.pump();
      await tester.tap(find.text('Sign in'));

      // Flush login + sync.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump();
      await tester.pump();

      // Room should be visible in the list.
      expect(find.text(testRoomName), findsWidgets);

      // Tap the room.
      await tester.tap(find.text(testRoomName).last);
      await tester.pump();
      await tester.pump();
      await tester.pump();

      // Message from Alice should be visible.
      expect(find.text('hello'), findsWidgets);

      // ChatBox send button should be present.
      final sendButton = find.bySemanticsLabel('Send');
      expect(sendButton, findsOneWidget);
    });
  });
}

/// Local helper to build a JSON HTTP response with default headers.
http.Response _jsonResponse(int status, Map<String, dynamic> body) {
  return http.Response(jsonEncode(body), status, headers: {
    'content-type': 'application/json',
  });
}
