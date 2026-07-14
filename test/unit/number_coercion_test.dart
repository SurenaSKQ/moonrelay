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
import 'package:moonrelay/src/helpers/number_coercion.dart';

void main() {
  group('coerceJsonInt', () {
    test('returns the value when it is already an int', () {
      expect(coerceJsonInt(1024), 1024);
      expect(coerceJsonInt(0), 0);
    });

    test('coerces a double to int (truncating)', () {
      expect(coerceJsonInt(1024.0), 1024);
      expect(coerceJsonInt(1.7), 1);
    });

    test('accepts a num of unknown exact type', () {
      // matrix SDK can hand back a `num` whose runtime type is
      // neither int nor double in some cache round-trips; the
      // helper should still coerce rather than throw.
      final num n = 42;
      expect(coerceJsonInt(n), 42);
    });

    test('returns null on null', () {
      expect(coerceJsonInt(null), isNull);
    });

    test('returns null on a non-numeric value', () {
      expect(coerceJsonInt('1024'), isNull);
      expect(coerceJsonInt(<String, int>{}), isNull);
      expect(coerceJsonInt(true), isNull);
    });
  });
}
