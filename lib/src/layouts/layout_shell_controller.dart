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
import 'package:flutter/scheduler.dart';

import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';

/// The concrete shell currently committed for the main chat surface.
///
/// The shell is the *frame* around the route content, not the content
/// itself:
///   * [mobile]: single-pane [MobileLayout], used below
///     [LayoutBreakpoints.mobileMax] or when the user opts in to mobile
///     mode.
///   * [compact]: dashboard with the unified [CompactSidebar] and no
///     right pane, used below [LayoutBreakpoints.compactMax].
///   * [expanded]: full multi-pane dashboard (navigation sidebar, right
///     context sidebar), used when the window has room for everything.
enum LayoutShell {
  mobile,
  compact,
  expanded,
}

/// Owns the "mobile vs compact vs expanded" shell decision for the main
/// chat surface.
///
/// This controller is the single source of truth for the shell.  Every
/// consumer (the router's page builders, [_AdaptiveMainLayout], and
/// [DashboardLayout]) reads the committed [shell] from here instead of
/// re-deriving it from the window width, so all of them agree on the
/// same layout in the same frame.  It lives at the app level (above the
/// [GoRouter] tree) so the decision survives shell switches: previously
/// the dashboard owned its own controller, so every mobile ↔ dashboard
/// flip created a fresh controller that started in the "expanded" state
/// and took hundreds of milliseconds to settle back to the correct
/// shell, which is what made the app appear to hover between layouts.
///
/// The decision is a *sticky state machine*:
///   * A shell, once committed, is kept until the width has crossed a
///     breakpoint far enough to clearly warrant a change.  A dead band
///     of [_kHysteresisPx] is anchored to the shell we are currently
///     in, so a window parked near a boundary stays in whichever shell
///     it entered, and a drag across the boundary commits once instead
///     of flapping.
///   * The very first evaluation commits immediately, so a freshly
///     opened window never flashes the wrong shell while the user waits
///     for a settle timer.
///   * A user-forced [LayoutMode] overrides the width logic entirely
///     and sticks until the mode changes back to [LayoutMode.auto].
///
/// There is deliberately no debounce timer and no "pending" state.
/// The dead band alone prevents oscillation across a boundary, and a
/// committed decision renders immediately instead of after a settle
/// delay.  This replaces the previous timer-based implementation,
/// whose 400 ms settle window plus a second, independent hysteresis
/// pass in the router could leave the app switching between the full
/// and compact layouts.
class LayoutShellController extends ChangeNotifier {
  LayoutShellController();

  /// Dead band applied around each breakpoint, anchored to the shell
  /// we are currently in.  Crossing requires a net move of this many
  /// pixels past the boundary before the shell flips.  Wide enough
  /// that a window parked near a boundary stays put; narrow enough
  /// that an honest resize commits without the user noticing lag.
  static const double _kHysteresisPx = 60.0;

  LayoutShell _shell = LayoutShell.expanded;
  LayoutShell get shell => _shell;

  /// Whether the shell currently renders the single-pane [MobileLayout].
  bool get isMobile => _shell == LayoutShell.mobile;

  /// Whether the shell currently renders the compact dashboard sidebar.
  bool get isCompact => _shell == LayoutShell.compact;

  /// Whether the shell currently renders the full multi-pane dashboard.
  bool get isExpanded => _shell == LayoutShell.expanded;

  /// True once [update] has committed a width-driven decision.  The
  /// first evaluation must commit unconditionally because there is no
  /// prior shell to protect from flapping; afterwards the dead band
  /// applies.
  bool _hasCommittedOnce = false;

  /// Re-evaluates the shell decision against [rawWidth] and the user's
  /// forced [layoutMode], returning the shell that should be rendered
  /// *now* (the committed one).
  ///
  /// Safe to call from build methods: it only ever mutates the
  /// committed shell (deferring [notifyListeners] to the end of the
  /// frame) and never schedules timers.
  LayoutShell update({
    required double rawWidth,
    required LayoutMode layoutMode,
  }) {
    final target = _targetFor(rawWidth, layoutMode);

    // A forced mode and the very first width evaluation both commit
    // directly: the user asked for it, or there is no previous shell
    // to hold onto.
    if (layoutMode != LayoutMode.auto || !_hasCommittedOnce) {
      return _commit(target);
    }

    if (_shouldSwitch(rawWidth, target)) {
      return _commit(target);
    }
    return _shell;
  }

  /// Maps a window width and the user's [LayoutMode] to the shell the
  /// width alone would suggest, ignoring the current committed shell.
  LayoutShell _targetFor(double width, LayoutMode mode) {
    switch (mode) {
      case LayoutMode.mobile:
        return LayoutShell.mobile;
      case LayoutMode.compact:
        return LayoutShell.compact;
      case LayoutMode.auto:
        break;
    }
    if (width < LayoutBreakpoints.mobileMax) return LayoutShell.mobile;
    if (width < LayoutBreakpoints.compactMax) return LayoutShell.compact;
    return LayoutShell.expanded;
  }

  /// True when [width] has moved far enough past a breakpoint, relative
  /// to the shell we are currently in, to commit a switch to [target].
  ///
  /// The dead band is asymmetric on purpose: leaving a shell requires
  /// crossing the *outer* edge of the band, so the boundary cannot
  /// flap.  For example, once expanded is committed, the window must
  /// shrink below `compactMax - 60` before compact takes over, and
  /// once compact is committed it must grow past `compactMax + 60`
  /// before expanded returns.
  bool _shouldSwitch(double width, LayoutShell target) {
    if (target == _shell) return false;
    final d = _kHysteresisPx;
    switch (_shell) {
      case LayoutShell.mobile:
        return width >= LayoutBreakpoints.mobileMax + d;
      case LayoutShell.compact:
        return target == LayoutShell.mobile
            ? width < LayoutBreakpoints.mobileMax - d
            : width >= LayoutBreakpoints.compactMax + d;
      case LayoutShell.expanded:
        return width < LayoutBreakpoints.compactMax - d;
    }
  }

  LayoutShell _commit(LayoutShell next) {
    _hasCommittedOnce = true;
    if (next == _shell) return _shell;
    _shell = next;
    // Defer the notification until after the current frame: this
    // controller is typically read from inside a [LayoutBuilder] or a
    // GoRouter page builder during build.  Calling [notifyListeners]
    // synchronously from there would re-enter the framework mid-layout,
    // producing `_RenderLayoutBuilder was mutated in performLayout` and
    // the `_elements.contains(element)` assertion failure when the
    // listener schedules a rebuild before the current layout pass
    // finishes.  Posting the notification to the end of the frame
    // avoids the cycle entirely.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_shell == next) notifyListeners();
    }, debugLabel: 'LayoutShellController._commit');
    return _shell;
  }

  /// Clears the sticky memory so the next [update] commits the
  /// width-appropriate shell unconditionally.
  ///
  /// Called when the main chat surface (re)mounts, e.g. after a fresh
  /// login: the window may have been resized while the dashboard was
  /// unmounted, so it should be re-evaluated from the current width
  /// instead of inheriting a stale committed shell.
  void reset() {
    _hasCommittedOnce = false;
  }
}
