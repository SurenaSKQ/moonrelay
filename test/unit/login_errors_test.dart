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

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/helpers/login_errors.dart';

/// A stand-in for the SDK's HTTP exception, whose `toString()` includes the
/// request body. The test would pass for the wrong reason if this type did
/// not actually carry the secret, so the fake keeps the leak explicit.
class _FakeHttpException implements Exception {
  _FakeHttpException(this.requestBody);

  final String requestBody;

  @override
  String toString() =>
      'HttpException: status 403, body: {"password":"$requestBody"}';
}

void main() {
  group('safeErrorMessage', () {
    test('never returns the request body of an HTTP-style exception', () {
      const secret = 'hunter2-correct-horse';
      final message = safeErrorMessage(_FakeHttpException(secret));

      expect(message, isNot(contains(secret)));
      expect(message, isNot(contains('password')));
      // Falls back to the type name, which carries no payload.
      expect(message, '_FakeHttpException');
    });

    test('recognises a timeout', () {
      expect(
        safeErrorMessage(TimeoutException('took too long')),
        'request timed out',
      );
    });

    test('falls back to the runtime type for an unknown error', () {
      expect(safeErrorMessage(StateError('nope')), 'StateError');
    });
  });
}
