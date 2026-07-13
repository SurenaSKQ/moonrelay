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

/// A single, debounced ChangeNotifier that fans out Matrix sync ticks
/// to the UI.
///
/// Before this existed, every sidebar / pane subscribed to
/// `client.onSync.stream` directly, each running its own debounce
/// timer and producing 3–5 `setState` rebuilds per sync tick. The
/// fan-out here coalesces those into one notification per debounce
/// window, and consumers read the pulse via `context.select` so they
/// only rebuild when the version actually changes.
///
/// The pulse is bound to the active [Client]; the boot pipeline wires
/// a fresh instance on every account switch and disposes the old one.
class SyncPulse extends ChangeNotifier {
  SyncPulse({
    Duration debounce = const Duration(milliseconds: 350),
  }) : _debounce = debounce;

  /// Monotonically increasing version, bumped on every (debounced) sync.
  int _version = 0;
  int get version => _version;

  /// Wall-clock time of the last emitted pulse. Useful for "x seconds
  /// since last sync" labels without forcing a re-render.
  DateTime get lastTick => _lastTick;
  DateTime _lastTick = DateTime.fromMillisecondsSinceEpoch(0);

  /// True when the SDK has produced at least one tick since bind.
  bool _hasTicked = false;
  bool get hasTicked => _hasTicked;

  final Duration _debounce;
  Client? _client;
  StreamSubscription<SyncUpdate>? _sub;
  Timer? _debounceTimer;
  bool _disposed = false;

  /// Bind the pulse to [client]. Cancels any prior subscription so the
  /// pulse is safe to re-bind on account switch.
  void bind(Client client) {
    if (identical(_client, client)) return;
    _sub?.cancel();
    _sub = null;
    _client = client;
    _hasTicked = false;
    _version = 0;
    _sub = client.onSync.stream.listen(_onSync, onError: (_) {});
  }

  /// Manually trigger a pulse, e.g. after a programmatic state change
  /// that the SDK didn't see (drafting, local edits).
  void poke() {
    if (_disposed) return;
    if (!_hasTicked) {
      // First poke delivers immediately so a manual trigger right
      // after construction isn't delayed by the debounce.
      _hasTicked = true;
      _version++;
      _lastTick = DateTime.now();
      notifyListeners();
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _version++;
      _lastTick = DateTime.now();
      notifyListeners();
    });
  }

  void _onSync(SyncUpdate _) {
    // First tick is emitted immediately so initial-data subscribers
    // (e.g. "show loading until first sync") don't see a 350 ms gap.
    if (!_hasTicked) {
      _hasTicked = true;
      _version++;
      _lastTick = DateTime.now();
      notifyListeners();
      return;
    }
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounce, () {
      _version++;
      _lastTick = DateTime.now();
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    _debounceTimer?.cancel();
    _sub = null;
    _debounceTimer = null;
    _client = null;
    super.dispose();
  }
}
