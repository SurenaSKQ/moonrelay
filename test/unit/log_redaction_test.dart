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
import 'package:moonrelay/src/helpers/log_service.dart';

/// Regression tests for the log-redaction filter.
///
/// These tests pin the redaction ruleset so a future refactor of
/// `_RedactingLogOutput` cannot silently drop a class of secrets from
/// the on-disk log stream.  Every rule gets at least one positive case
/// (sensitive value present → sanitised) and at least one negative case
/// (plaintext preserved).
void main() {
  group('redactString', () {
    // ─── Matrix access tokens ─────────────────────────────────────────
    test('redacts syt_ tokens', () {
      const line = 'Authorization: syt_AbCdEf1234567890';
      expect(redactString(line), 'Authorization: syt_[REDACTED]');
    });

    test('redacts MDA… long tokens', () {
      // 100+ alphanumerics  synthesised rather than a real token.
      const token =
          'MDAabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abcdefghijklmnopqrstuvwxyz0123456789ABCDEFG';
      expect(
        redactString('token=$token'),
        contains('MDA[REDACTED]'),
      );
      expect(redactString('token=$token'), isNot(contains(token)));
    });

    test('preserves unrelated identifiers that look similar', () {
      // Short alphanumeric strings should NOT be confused for tokens.
      const line = 'device=abc123';
      expect(redactString(line), line);
    });

    // ─── Bearer tokens ────────────────────────────────────────────────
    test('redacts Bearer tokens (case-insensitive)', () {
      const line = 'Authorization: Bearer abcdefghijklmnop_123';
      // Replacement is `$1[REDACTED]` so the captured `Authorization:
      // Bearer` prefix is preserved.  Only the token is removed.
      expect(redactString(line), 'Authorization: Bearer [REDACTED]');

      const upper = 'Authorization: BEARER abcdefghijklmnop_123';
      expect(redactString(upper), 'Authorization: BEARER [REDACTED]');
    });

    test('bare "Bearer …" without Authorization prefix is still redacted', () {
      const line = 'Bearer abcdefghijklmnop_123';
      expect(redactString(line), 'Bearer [REDACTED]');
    });

    test('leaves the word "Bearer" alone when not followed by a token', () {
      expect(redactString('Bearer of this message'), 'Bearer of this message');
    });

    // ─── Login tokens ────────────────────────────────────────────────
    test('redacts loginToken query parameter', () {
      const url =
          'https://app.example.com/callback?loginToken=ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789abc';
      expect(redactString(url), contains('loginToken=[REDACTED]'));
      expect(redactString(url), isNot(contains('loginToken=ABCDEF')));
    });

    // ─── Device / session IDs ─────────────────────────────────────────
    test('redacts device_id with equals and quoted values', () {
      expect(
        redactString('device_id=abcdefghij1234'),
        contains('device_id=[REDACTED]'),
      );
      expect(
        redactString('"device_id":"abcdefghij1234"'),
        contains('device_id=[REDACTED]'),
      );
    });

    test('redacts session_id', () {
      expect(
        redactString('session_id=abcdefghij1234'),
        contains('session_id=[REDACTED]'),
      );
    });

    // ─── Passwords ────────────────────────────────────────────────────
    test('redacts form-style password=value', () {
      const line = 'POST /login body: username=alice&password=Sec3retP@ss';
      expect(redactString(line), contains('password=[REDACTED]'));
      expect(redactString(line), isNot(contains('Sec3retP@ss')));
    });

    test('redacts JSON-style "password":"value"', () {
      const line =
          '{"type":"m.login.password","identifier":{"user":"alice"},"password":"Sec3retP@ss"}';
      expect(redactString(line), contains('password=[REDACTED]'));
      expect(redactString(line), isNot(contains('Sec3retP@ss')));
    });

    test('redacts colon-style "password: value"', () {
      const line = 'request body password: hunter2 other=ok';
      expect(redactString(line), isNot(contains('hunter2')));
    });

    // ─── Stability / false-positives ────────────────────────────────
    test('preserves logs that contain no secrets', () {
      const line = 'GET /_matrix/client/v3/sync 200 in 320ms';
      expect(redactString(line), line);
    });

    test('redaction rules apply in order without throwing', () {
      // Stress: a single line containing every class of secret at once.
      // Note: Bearer tokens must be ≥16 chars to satisfy the redaction
      // pattern's length floor (otherwise we hit the false-positive guard).
      const chaos =
          'line: syt_a1B2 password=hunter2 device_id=ABCDEFGHIJKLMNOP '
          'session_id=ABCDEFGHIJKLMNOP Bearer abcdefghijklmnop_1234 '
          'loginToken=0123456789abcdef0123456789abcdef';
      final out = redactString(chaos);
      expect(out, contains('syt_[REDACTED]'));
      expect(out, contains('password=[REDACTED]'));
      expect(out, contains('device_id=[REDACTED]'));
      expect(out, contains('session_id=[REDACTED]'));
      expect(out, contains('Bearer [REDACTED]'));
      expect(out, contains('loginToken=[REDACTED]'));
    });
  });
}
