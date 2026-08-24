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
import 'package:moonrelay/src/helpers/sync_pulse.dart';

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

  /// Debounced sync listener wired via [bind]. We attach to the shared
  /// [SyncPulse] rather than subscribing to `client.onSync.stream`
  /// directly so the room doesn't accumulate its own raw-sync
  /// subscription (see WORK_DONE.md, "Sync listener
  /// consolidation").
  SyncPulse? _pulse;
  VoidCallback? _pulseListener;
  int _lastPulseVersion = -1;

  bool _disposed = false;

  /// Wire the provider to the shared [SyncPulse]. The provider
  /// refreshes the first page whenever the pulse ticks. Idempotent
  /// so the caller doesn't have to track bind state.
  void bind(SyncPulse pulse) {
    if (identical(_pulse, pulse)) return;
    unbind();
    _pulse = pulse;
    _lastPulseVersion = pulse.version;
    _pulseListener = _onPulse;
    pulse.addListener(_pulseListener!);
  }

  void unbind() {
    if (_pulse != null && _pulseListener != null) {
      _pulse!.removeListener(_pulseListener!);
    }
    _pulse = null;
    _pulseListener = null;
  }

  void _onPulse() {
    if (_disposed) return;
    final pulse = _pulse;
    if (pulse == null) return;
    if (pulse.version == _lastPulseVersion) return;
    _lastPulseVersion = pulse.version;
    fetch(firstPage: true);
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
      // Silently swallow failures; the UI shows existing results.
    }

    if (!_disposed) {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    unbind();
    super.dispose();
  }
}
