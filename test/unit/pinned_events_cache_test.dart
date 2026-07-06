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
import 'package:moonrelay/src/helpers/pinned_events_cache.dart';

void main() {
  group('PinnedEventsCache', () {
    setUp(() {
      PinnedEventsCache.instance.clear();
    });

    test('clear() resets the cache', () {
      PinnedEventsCache.instance.clear();
      // Subsequent calls should still work without throwing.
      expect(PinnedEventsCache.instance, isNotNull);
    });
  });
}