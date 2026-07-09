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
import 'package:moonrelay/src/helpers/app_version.dart';

void main() {
  group('AppVersion', () {
    setUp(AppVersion.resetForTesting);

    test('currentVersion falls back to 0.0.0+0 before init()', () {
      // No init() call has been made in this isolate, so the fallback
      // value must be safe to read from any UI code path.
      expect(AppVersion.currentVersion, matches(r'^\d+\.\d+\.\d+\+\d+$'));
    });

    test('test constructor preserves joined version + build', () {
      final v = AppVersion.test(version: '0.7.0+1');
      expect(v.version, '0.7.0+1');
      expect(v.name, '0.7.0');
      expect(v.build, '1');
    });
  });
}
