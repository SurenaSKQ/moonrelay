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

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Manages the list of thread roots for a single room, with progressive
/// loading from the server via [Client.getThreadRoots].
///
/// Shared by [SidebarThreadList] and [FullRoomThreadsList] to avoid
/// duplicated pagination and error-handling logic.
class ThreadsProvider extends ChangeNotifier {
  ThreadsProvider({required this.room});

  final Room room;

  final List<Event> _threadRoots = [];
  List<Event> get threadRoots => _threadRoots;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _hasMore = true;
  bool get hasMore => _hasMore;

  String? _nextBatch;

  static const int batchSize = 30;

  StreamSubscription? _syncSub;
  bool _disposed = false;

  /// Start listening to sync events so the thread list auto-refreshes.
  void listenToSync() {
    _syncSub?.cancel();
    _syncSub = room.client.onSync.stream.listen((_) {
      if (!_disposed) fetch(firstPage: true);
    });
  }

  /// Fetch the next page of thread roots.
  ///
  /// When [firstPage] is true, the existing list is cleared and fetching
  /// starts from the beginning.
  Future<void> fetch({bool firstPage = false}) async {
    if (_isLoading) return;
    if (!firstPage && !_hasMore) return;

    _isLoading = true;
    notifyListeners();

    try {
      final response = await room.client.getThreadRoots(
        room.id,
        include: Include.all,
        limit: batchSize,
        from: firstPage ? null : _nextBatch,
      );

      if (_disposed) return;

      if (firstPage) {
        _threadRoots.clear();
      }
      _threadRoots.addAll(
        response.chunk.map((m) => Event.fromMatrixEvent(m, room)),
      );
      _nextBatch = response.nextBatch;
      _hasMore = response.nextBatch != null;
    } catch (_) {
      // Silently swallow failures  the UI shows existing results.
    }

    if (!_disposed) {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _syncSub?.cancel();
    super.dispose();
  }
}
