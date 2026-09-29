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
import 'package:moonrelay/src/screens/login_page/login_mode.dart';

void main() {
  group('LoginMode', () {
    test('only the password mode shows the credential fields', () {
      expect(LoginMode.password.showsCredentialFields, isTrue);
      expect(LoginMode.sso.showsCredentialFields, isFalse);
      expect(LoginMode.token.showsCredentialFields, isFalse);
    });

    test('has exactly the three modes the form switches between', () {
      // The two booleans this replaced could both be true at once. That
      // state rendered the password button with the fields hidden, so the
      // assertion is the guard against the enum growing a fourth value
      // that the build does not handle.
      expect(LoginMode.values, hasLength(3));
    });
  });

  group('SsoStep', () {
    test('only awaitingCallback suppresses the mode switcher', () {
      expect(SsoStep.idle.isAwaitingCallback, isFalse);
      expect(SsoStep.automaticFailed.isAwaitingCallback, isFalse);
      expect(SsoStep.manualTokenEntry.isAwaitingCallback, isFalse);
      expect(SsoStep.awaitingCallback.isAwaitingCallback, isTrue);
    });

    test('the failure notice and the paste field are separate states', () {
      // They are not allowed to be true simultaneously. A single value for
      // the sub-flow is what makes "failed but still showing the paste
      // field" unrepresentable, so the two predicates must partition.
      for (final step in SsoStep.values) {
        expect(
          step.showsFailureNotice && step.showsManualTokenEntry,
          isFalse,
          reason: '$step cannot show the failure notice and the paste field',
        );
      }
    });

    test('idle shows neither the notice nor the paste field', () {
      expect(SsoStep.idle.showsFailureNotice, isFalse);
      expect(SsoStep.idle.showsManualTokenEntry, isFalse);
    });
  });
}
