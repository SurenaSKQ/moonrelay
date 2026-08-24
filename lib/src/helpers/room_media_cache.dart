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

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Process-wide, per-room, LRU-bounded cache of decrypted media bytes.
///
/// Each visible image / sticker / audio / file widget used to hold
/// its own decrypted [Uint8List] (and a still-resolving
/// `Future<MatrixFile>`) for the full lifetime of the widget. Scrolling
/// through 50 image messages therefore held 50 copies of the raw
/// decoded bytes in memory simultaneously.
///
/// This cache deduplicates the bytes by `(roomId, eventId)` and evicts
/// least-recently-used entries when the byte budget is exceeded. Bytes
/// are kept just long enough for the visible thumbnails to decode:
/// after the host widget is disposed, the next access re-resolves via
/// the network.
///
/// The cache is intentionally a global singleton so multiple State
/// objects for the same event share a single decoded blob. The first
/// one to start downloading the attachment sets the in-flight future;
/// every other widget awaits the same one.
class RoomMediaCache {
  RoomMediaCache._();

  static final RoomMediaCache instance = RoomMediaCache._();

  /// Bounded byte budget for the cache. 64 MB is enough for ~50 typical
  /// 4K images at ~1.3 MB each, but small enough that a tab left open
  /// overnight doesn't bloat into the gigabytes.
  static const int _maxBytes = 64 * 1024 * 1024;

  final Map<String, _Entry> _completed = {};
  final Map<String, Future<MatrixFile>> _inflight = {};
  int _bytes = 0;
  final List<String> _lruOrder = [];

  String _key(String roomId, String eventId) => '$roomId::$eventId';

  /// Returns the cached bytes for `(roomId, eventId)`, or `null` if
  /// the entry has been evicted or has not yet been downloaded.
  Uint8List? get(String roomId, String eventId) {
    final entry = _completed[_key(roomId, eventId)];
    if (entry == null) return null;
    _touch(_key(roomId, eventId));
    return entry.bytes;
  }

  /// Returns the in-flight future, or starts a new download.
  Future<MatrixFile> getOrDownload(
    String roomId,
    String eventId,
    Future<MatrixFile> Function() download,
  ) {
    final key = _key(roomId, eventId);
    final cached = _completed[key];
    if (cached != null) {
      _touch(key);
      return Future.value(cached.matrixFile);
    }
    final inflight = _inflight[key];
    if (inflight != null) return inflight;
    final future = download()
        .then((m) {
          _completed[key] = _Entry(matrixFile: m, bytes: m.bytes);
          _lruOrder.add(key);
          _bytes += m.bytes.length;
          _evictIfNeeded();
          return m;
        })
        // Clear the in-flight entry on failure too; otherwise a single
        // failed download poisons the cache until the app restarts and
        // every retry replays the same error.  The callback must return
        // void: `_inflight.remove` returns the in-flight future itself,
        // and whenComplete would wait on that return value, deadlocking
        // the very future it is finishing.
        .whenComplete(() {
          _inflight.remove(key);
        });
    _inflight[key] = future;
    return future;
  }

  /// Forcibly drops the entry. The next `getOrDownload` will re-fetch.
  void invalidate(String roomId, String eventId) {
    final key = _key(roomId, eventId);
    final entry = _completed.remove(key);
    if (entry != null) {
      _bytes -= entry.bytes.length;
      _lruOrder.remove(key);
    }
    _inflight.remove(key);
  }

  void _touch(String key) {
    final idx = _lruOrder.indexOf(key);
    if (idx < 0) return;
    if (idx == _lruOrder.length - 1) return;
    _lruOrder.removeAt(idx);
    _lruOrder.add(key);
  }

  void _evictIfNeeded() {
    while (_bytes > _maxBytes && _lruOrder.isNotEmpty) {
      final oldest = _lruOrder.removeAt(0);
      final entry = _completed.remove(oldest);
      if (entry != null) _bytes -= entry.bytes.length;
    }
  }

  /// Drop every entry. Useful from a "clear caches" settings action
  /// and from tests.
  void clear() {
    _completed.clear();
    _inflight.clear();
    _lruOrder.clear();
    _bytes = 0;
  }

  /// Diagnostic: total bytes held by the cache.
  int get byteCount => _bytes;
  int get entryCount => _completed.length;
  int get inflightCount => _inflight.length;
}

@immutable
class _Entry {
  const _Entry({required this.matrixFile, required this.bytes});
  final MatrixFile matrixFile;
  final Uint8List bytes;
}
