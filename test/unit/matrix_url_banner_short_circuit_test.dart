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
import 'package:moonrelay/src/chat/events/matrix_url_banner_wrapper.dart';

void main() {
  group('MatrixUrlBannerWrapper.couldContainMatrixReference', () {
    test('returns false for an empty body', () {
      expect(MatrixUrlBannerWrapper.couldContainMatrixReference(''), isFalse);
    });

    test('returns false for plain text without tokens', () {
      expect(
        MatrixUrlBannerWrapper.couldContainMatrixReference(
          'Hey everyone, see you at standup.',
        ),
        isFalse,
      );
    });

    test('returns true for matrix: scheme URIs', () {
      expect(
        MatrixUrlBannerWrapper.couldContainMatrixReference(
          'Join matrix:r/!roomid:example.org',
        ),
        isTrue,
      );
    });

    test('returns true for matrix.to permalinks', () {
      expect(
        MatrixUrlBannerWrapper.couldContainMatrixReference(
          'See https://matrix.to/#/#alias:example.org',
        ),
        isTrue,
      );
    });

    test('returns true for bare @user:domain mentions', () {
      expect(
        MatrixUrlBannerWrapper.couldContainMatrixReference(
          'ping @alice:example.org when you can',
        ),
        isTrue,
      );
    });

    test('returns true for bare #alias:domain mentions', () {
      expect(
        MatrixUrlBannerWrapper.couldContainMatrixReference(
          'Discussion moved to #general:example.org',
        ),
        isTrue,
      );
    });

    test('returns true for plain text containing a stray @ (false positive '
        'is acceptable -- the regex filters downstream)', () {
      expect(
        MatrixUrlBannerWrapper.couldContainMatrixReference(
          'I emailed you at foo@bar.com',
        ),
        isTrue,
      );
    });
  });
}
