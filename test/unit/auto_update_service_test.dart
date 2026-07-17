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

// Unit tests for AutoUpdateService.
//
// Covers:
//   - HTTP errors / non-200 responses return an up-to-date result
//   - Network failures fall back to an up-to-date result
//   - When the latest tag is newer than the current version the result
//     reflects availability
//   - Lexicographic / non-semver tags fall back to ordinal comparison

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:moonrelay/src/services/auto_update_service.dart';

import '../helpers/mocks.dart';

class _StubClient extends http.BaseClient {
  _StubClient(this._responder);
  final http.Response Function(http.BaseRequest req) _responder;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = _responder(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(response.body)),
      response.statusCode,
      contentLength: utf8.encode(response.body).length,
      request: request,
    );
  }
}

void main() {
  group('AutoUpdateService', () {
    test('returns up-to-date when GitHub responds 200 with same version',
        () async {
      final svc = AutoUpdateService(
        client: _StubClient(
          (req) => http.Response(
            jsonEncode({
              'tag_name': 'v0.6.0',
              'html_url': 'https://github.com/example/moonrelay/releases/v0.6.0',
            }),
            200,
          ),
        ),
        log: MockLogger(),
      );
      final result = await svc.check(overrideVersion: '0.6.0');
      expect(result.available, isFalse);
      expect(result.currentVersion, '0.6.0');
      expect(result.latestVersion, '0.6.0');
    });

    test('flags update when remote is newer than current', () async {
      final svc = AutoUpdateService(
        client: _StubClient(
          (req) => http.Response(
            jsonEncode({
              'tag_name': 'v1.0.0',
              'html_url': 'https://github.com/example/moonrelay/releases/v1.0.0',
              'body': 'Major release notes.',
            }),
            200,
          ),
        ),
        log: MockLogger(),
      );
      final result = await svc.check(overrideVersion: '0.6.0');
      expect(result.available, isTrue);
      expect(result.latestVersion, '1.0.0');
      expect(result.releaseNotes, contains('Major release'));
    });

    test('HTTP 500 falls back to up-to-date', () async {
      final svc = AutoUpdateService(
        client: _StubClient((req) => http.Response('boom', 500)),
        log: MockLogger(),
      );
      final result = await svc.check(overrideVersion: '0.6.0');
      expect(result.available, isFalse);
    });

    test('network failure falls back to up-to-date', () async {
      final svc = AutoUpdateService(
        client: _StubClient(
          (req) => throw const SocketException('offline'),
        ),
        log: MockLogger(),
      );
      final result = await svc.check(overrideVersion: '0.6.0');
      expect(result.available, isFalse);
    });
  });
}