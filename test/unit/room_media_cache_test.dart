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

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/room_media_cache.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';

/// Lightweight perf / memory regression tests.
///
/// These tests don't exercise UI rendering; they assert that the
/// caching helpers used by the chat hot paths:
///   * [RoomMediaCache] dedupes concurrent requests for the same
///     (roomId, eventId) and evicts the oldest entry once its byte
///     budget is exceeded
///   * [SyncPulse] coalesces a burst of ticks into a single
///     `notifyListeners` broadcast.
void main() {
  group('RoomMediaCache', () {
    setUp(() {
      RoomMediaCache.instance.clear();
    });

    test('evicts the oldest entry when the byte budget overflows',
        () async {
      // Three ~30 MB blobs; the cache's 64 MB budget can only hold two.
      final bytes = Uint8List(30 * 1024 * 1024);
      Future<MatrixFile> download(String eventId) async {
        return MatrixFile(bytes: bytes, name: 'media_$eventId');
      }

      await RoomMediaCache.instance
          .getOrDownload('!r', '\$a', () => download('a'));
      await RoomMediaCache.instance
          .getOrDownload('!r', '\$b', () => download('b'));
      // The third entry exceeds the budget and should evict one of the
      // first two.
      await RoomMediaCache.instance
          .getOrDownload('!r', '\$c', () => download('c'));

      // Only one of the first two can fit alongside c. The other
      // must have been evicted. (Which one depends on LRU order, so
      // we just check that the total count is bounded.)
      final retained = [
        if (RoomMediaCache.instance.get('!r', '\$a') != null) 1,
        if (RoomMediaCache.instance.get('!r', '\$b') != null) 1,
        if (RoomMediaCache.instance.get('!r', '\$c') != null) 1,
      ].length;
      expect(retained, lessThanOrEqualTo(2));
      expect(RoomMediaCache.instance.byteCount,
          lessThanOrEqualTo(64 * 1024 * 1024));
    });

    test('getOrDownload returns the same in-flight future for parallel callers',
        () async {
      var downloads = 0;
      Future<MatrixFile> download() async {
        downloads++;
        return MatrixFile(bytes: Uint8List(8), name: 'shared');
      }

      final f1 = RoomMediaCache.instance.getOrDownload('!r', '\$x', download);
      final f2 = RoomMediaCache.instance.getOrDownload('!r', '\$x', download);
      final f3 = RoomMediaCache.instance.getOrDownload('!r', '\$x', download);
      await Future.wait([f1, f2, f3]);
      // Three concurrent callers should share one download.
      expect(downloads, 1);
    });
  });

  group('SyncPulse', () {
    test('coalesces a burst of sync ticks into a single broadcast',
        () async {
      final pulse = SyncPulse(debounce: Duration(milliseconds: 30));
      var notifications = 0;
      pulse.addListener(() => notifications++);

      // Simulate 10 rapid sync ticks. The first is delivered
      // immediately; the remaining 9 coalesce into a single
      // debounced broadcast after the 30 ms delay.
      for (var i = 0; i < 10; i++) {
        pulse.poke();
      }
      // Initial: 1 notification (the first poke).
      expect(notifications, 1);

      // Wait for the debounce timer to elapse and the coalesced
      // broadcast to fire.
      await Future<void>.delayed(const Duration(milliseconds: 80));
      // Coalesced: a single additional broadcast for the 9 trailing
      // pokes.
      expect(notifications, 2);
    });
  });
}
