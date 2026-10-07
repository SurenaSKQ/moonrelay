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

/// Standardised async-cancellation pattern.
///
/// Use this whenever an async operation started by `initState` or a
/// button press might still be in flight by the time the widget
/// updates (room switch, account switch, nav-back). Without a generation
/// counter the late future races the new state and writes stale data.
///
/// Usage:
///
/// ```dart
/// class _FooState extends State<Foo> with LifecycleGeneration {
///   Future<void> _load() async {
///     final gen = beginAsync();          // captures + bumps
///     final result = await someFuture();
///     if (isStale(gen) || !mounted) return;
///     setState(() => _data = result);
///   }
/// }
/// ```
///
/// Bump the generation explicitly on `didUpdateWidget` (or any other
/// update path) by calling [invalidate] so callbacks from the previous
/// configuration short-circuit.
mixin LifecycleGeneration {
  int _generation = 0;

  /// Captures the current generation and increments the counter in a
  /// single call. The returned token must be passed back to [isStale]
  /// (or [isFresh]) before touching state from the captured future's
  /// continuation.
  int beginAsync() => ++_generation;

  /// Bumps the generation without capturing a token. Use this in
  /// `didUpdateWidget` (or similar) to invalidate all in-flight
  /// operations without needing their token at hand.
  void invalidate() {
    _generation++;
  }

  /// True when [token] is no longer the current generation. Callers
  /// should return early without writing state.
  bool isStale(int token) => token != _generation;

  /// Convenience: true when the token is still the current generation.
  /// Equivalent to `!isStale(token)`.
  bool isFresh(int token) => token == _generation;
}
