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
import 'package:moonrelay/src/helpers/date_time_extension.dart';

void main() {
  group('DateTimeExtension', () {
    final now = DateTime(2025, 6, 14, 10, 30, 0);
    final earlier = DateTime(2025, 6, 14, 10, 20, 0);
    final later = DateTime(2025, 6, 14, 10, 40, 0);

    group('comparison operators', () {
      test('< returns true when left is earlier', () {
        expect(earlier < now, isTrue);
      });

      test('< returns false when left is later', () {
        expect(later < now, isFalse);
      });

      test('> returns true when left is later', () {
        expect(later > now, isTrue);
      });

      test('> returns false when left is earlier', () {
        expect(earlier > now, isFalse);
      });

      test('>= returns true when equal', () {
        expect(now >= now, isTrue);
      });

      test('>= returns true when left is later', () {
        expect(later >= now, isTrue);
      });

      test('<= returns true when equal', () {
        expect(now <= now, isTrue);
      });

      test('<= returns true when left is earlier', () {
        expect(earlier <= now, isTrue);
      });
    });

    group('sameEnvironment', () {
      test('returns true when within 10 minutes', () {
        final a = DateTime(2025, 6, 14, 10, 0, 0);
        final b = DateTime(2025, 6, 14, 10, 9, 59);
        expect(b.sameEnvironment(a), isTrue);
      });

      test('returns false when more than 10 minutes apart', () {
        final a = DateTime(2025, 6, 14, 10, 0, 0);
        final b = DateTime(2025, 6, 14, 10, 11, 0);
        expect(b.sameEnvironment(a), isFalse);
      });

      test('returns false at exactly 10 minute boundary', () {
        final a = DateTime(2025, 6, 14, 10, 0, 0);
        final b = DateTime(2025, 6, 14, 10, 10, 0);
        // The check is `difference < 600000`, exactly 600000 returns false.
        expect(b.sameEnvironment(a), isFalse);
      });

      test('returns true when difference is 0', () {
        final a = DateTime(2025, 6, 14, 10, 0, 0);
        final b = DateTime(2025, 6, 14, 10, 0, 0);
        expect(b.sameEnvironment(a), isTrue);
      });
    });

    group('minutesBetweenEnvironments', () {
      test('constant is 10', () {
        expect(
          DateTimeExtension.minutesBetweenEnvironments,
          10,
        );
      });
    });
  });
}
