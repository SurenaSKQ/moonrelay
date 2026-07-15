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

/// A reusable trailing-edge debouncer.
///
/// `call(body)` cancels any pending invocation and schedules [body] to
/// run after [delay]. Successive calls within the window collapse to a
/// single execution -- the body only fires once the user has been quiet
/// for at least [delay].
///
/// The owning object is responsible for calling [cancel] from its
/// `dispose()` so a late timer cannot fire into a torn-down owner.
/// [Debouncer] itself doesn't capture the owner; the body's lifecycle
/// check (e.g. `mounted`) keeps that concern with the caller.
class Debouncer {
  Debouncer(this.delay);

  /// How long to wait after the last `call` before invoking [body].
  final Duration delay;

  Timer? _timer;

  /// Cancels any pending [body] and schedules a fresh one.
  void call(void Function() body) {
    _timer?.cancel();
    _timer = Timer(delay, body);
  }

  /// True when a [body] is queued but hasn't run yet.  Useful for
  /// tests and for guards that want to short-circuit extra work while
  /// the debounce window is still open.
  bool get isPending => _timer?.isActive ?? false;

  /// Drops the pending body without firing it.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}