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
import 'package:logger/logger.dart';
import 'package:moonrelay/src/screens/login_page/sso_token_capture.dart';

void main() {
  group('SsoAttempt', () {
    test('covers the three ways an SSO attempt can end', () {
      // The sealed set is the point: a caller that switches on the result
      // gets a compile error if a fourth outcome is ever added, rather than
      // silently falling through to the manual fallback the way a caught
      // exception did.
      expect(SsoAttempt.token('t'), isA<SsoTokenReceived>());
      expect(SsoAttempt.failed('why'), isA<SsoAutomaticFailed>());
      expect(SsoAttempt.abandoned(), isA<SsoAbandoned>());
    });

    test('a failure carries a reason for the log but no user-facing text', () {
      const attempt = SsoAutomaticFailed('Timed out waiting for redirect');
      expect(attempt.reason, 'Timed out waiting for redirect');
    });
  });

  group('SsoTokenCapture', () {
    // A real Logger writing to the default sink. The constructor under test
    // only needs something to log to, and none of these cases reach a line
    // that logs.
    final log = Logger();

    test('is not capturing before it is asked to', () {
      final capture = SsoTokenCapture(log: log);
      expect(capture.isCapturing, isFalse);
      expect(capture.destination, isNull);
    });

    test('cancel is safe to call when nothing is running', () async {
      // The page can be disposed while a capture is in flight, and the
      // cancel and dispose paths then race to stop the same server. Neither
      // is allowed to throw for being the second one through.
      final capture = SsoTokenCapture(log: log);
      await capture.cancel();
      await capture.cancel();
      capture.dispose();
      expect(capture.isCapturing, isFalse);
    });
  });
}
