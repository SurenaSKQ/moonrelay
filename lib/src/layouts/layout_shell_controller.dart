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
import 'package:flutter/widgets.dart';

import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';

/// Owns the dashboard's "compact vs wide vs mobile" shell decision.
///
/// The dashboard needs to react to:
///   * the available window width (LayoutBuilder constraints)
///   * the user's forced layout mode ([SettingsController.layoutMode])
///   * hysteresis around the 1280 px breakpoint so a continuous drag
///     across the boundary doesn't oscillate between shells.
///
/// Previously this state lived inside [_DashboardLayoutState] and
/// the only consumer was the dashboard's own build method.  That
/// meant every time the shell decision changed, the entire dashboard
/// subtree (NavigationPane, RoomsPane, chat, right sidebar) rebuilt
/// just to swap between two layout shells.
///
/// [LayoutShellController] holds the decision in a [ValueListenable]
/// so a shell swap is a single targeted rebuild of the [LayoutBuilder]
/// shell widget, not the whole tree.
class LayoutShellController extends ChangeNotifier {
  LayoutShellController();

  /// Hysteresis: 20 px around the boundary. Crossing requires a net
  /// 20 px move before the shell flips.
  static const double _kShellHysteresisPx = 20.0;

  /// Settle delay: the new width must stay on the other side of the
  /// boundary for this long before the flip is committed.
  static const Duration _kShellSettleDuration = Duration(milliseconds: 220);

  /// Currently committed layout size.
  LayoutSize _size = LayoutSize.expanded;
  LayoutSize get size => _size;

  /// User-forced mode flags. When true the boundary logic must not
  /// override the user; the next call to [update] re-evaluates
  /// based on the new flags.
  bool _userForcedMobile = false;
  bool _userForcedCompact = false;

  /// Pending candidate during a hysteresis settle.
  LayoutSize? _pending;
  Timer? _settleTimer;

  /// Re-evaluates the shell decision against [rawWidth] and the
  /// current user-forced mode.  Returns the shell that should be
  /// rendered *now* (the committed one).  [layoutMode] is the user's
  /// forced mode read from [SettingsController].
  LayoutSize update({required double rawWidth, required LayoutMode layoutMode}) {
    _userForcedMobile = layoutMode == LayoutMode.mobile;
    _userForcedCompact = layoutMode == LayoutMode.compact;

    if (_userForcedMobile) {
      _cancelPending();
      return _setSize(LayoutSize.compact);
    }

    if (_userForcedCompact) {
      _cancelPending();
      return _setSize(LayoutSize.compact);
    }

    final boundary = LayoutBreakpoints.expandedMax;
    final candidateIsCompact = _size == LayoutSize.compact
        ? rawWidth < boundary - _kShellHysteresisPx
        : rawWidth < boundary + _kShellHysteresisPx;
    final candidate = candidateIsCompact ? LayoutSize.compact : LayoutSize.expanded;
    if (candidate == _size) {
      // Width has returned to (or never left) the committed shell's
      // hysteresis band. Cancel any pending commit.
      _cancelPending();
      return _size;
    }
    if (_pending == candidate) {
      // Already waiting to commit this exact decision.
      return _size;
    }
    // New candidate; start (or restart) the settle timer so a
    // continuous drag doesn't oscillate the shell.
    _pending = candidate;
    _settleTimer?.cancel();
    _settleTimer = Timer(_kShellSettleDuration, () {
      _settleTimer = null;
      final pending = _pending;
      _pending = null;
      if (pending == null || pending == _size) return;
      _setSize(pending);
    });
    return _size;
  }

  LayoutSize _setSize(LayoutSize next) {
    if (next == _size) return _size;
    _size = next;
    notifyListeners();
    return _size;
  }

  void _cancelPending() {
    _settleTimer?.cancel();
    _settleTimer = null;
    _pending = null;
  }

  @override
  void dispose() {
    _cancelPending();
    super.dispose();
  }
}
