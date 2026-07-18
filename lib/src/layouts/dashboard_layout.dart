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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';

import 'dashboard_layout/dashboard_view.dart';

/// Controller widget for the multi-pane dashboard layout.
///
/// Owns transient resize state via [ValueNotifier]s (so drag updates don't
/// trigger full-tree rebuilds) and delegates the shell-decision logic to
/// [LayoutShellController] so a shell swap only re-renders the shell
/// widget, not the entire tree.
/// The actual UI is delegated to the stateless [DashboardView] so that
/// the right sidebar receives room changes as direct props with no
/// indirection.
class DashboardLayout extends StatefulWidget {
  /// The main content widget (typically the route's child).
  final Widget child;

  const DashboardLayout({super.key, required this.child});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  // Live drag state; exposed as ValueNotifiers so the layout shell can
  // observe them with [ListenableBuilder] without rebuilding the entire tree
  // on every drag delta.
  final ValueNotifier<double?> _leftWidth = ValueNotifier(null);
  final ValueNotifier<double?> _rightWidth = ValueNotifier(null);

  /// Owns the compact / wide / mobile shell decision. The actual
  /// shell widget rebuilds via `ListenableBuilder` against this
  /// controller, so a shell flip only invalidates the shell subtree
  /// (NavigationPane / RoomsPane / right sidebar) rather than the
  /// whole dashboard tree.
  final LayoutShellController _shell = LayoutShellController();

  @override
  void dispose() {
    _shell.dispose();
    _leftWidth.dispose();
    _rightWidth.dispose();
    super.dispose();
  }

  void _onLeftResize(double delta) {
    final settings = context.read<SettingsController>();
    final current = _leftWidth.value ?? settings.leftSidebarWidth;
    _leftWidth.value = current + delta;
  }

  void _onLeftResizeEnd() {
    final w = _leftWidth.value;
    if (w != null) {
      context.read<SettingsController>().setLeftSidebarWidth(w);
      _leftWidth.value = null;
    }
  }

  void _onRightResize(double delta) {
    final settings = context.read<SettingsController>();
    final current = _rightWidth.value ?? settings.rightSidebarWidth;
    _rightWidth.value = current - delta;
  }

  void _onRightResizeEnd() {
    final w = _rightWidth.value;
    if (w != null) {
      context.read<SettingsController>().setRightSidebarWidth(w);
      _rightWidth.value = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // -- Shell decision with hysteresis ------------------------------
        //
        // The shell decision reads the *outer* viewport width (via
        // [MediaQuery.sizeOf]) instead of the inner [LayoutBuilder]
        // constraints.  The inner constraints shrink and grow when the
        // sidebars mount or unmount  the previous implementation used
        // them as the breakpoint signal and ended up in a feedback
        // loop where toggling the right sidebar could nudge the
        // available width across the 1100 px threshold and flip the
        // shell back to compact on its own.  Anchoring to the window
        // width makes the shell decision independent of which
        // sidebars are currently mounted.
        //
        // Importantly, this builder is pure: it reads precomputed
        // state, calls a controller [update] that *may* schedule a
        // timer / fire [notifyListeners] only asynchronously, and
        // never mutates fields on this state.  Earlier revisions
        // assigned `_layoutSize` and ran `_shell.update()` synchronously
        // here, which under bursty resizes spawned
        // `_RenderLayoutBuilder was mutated in performLayout` because
        // a deferred [notifyListeners] could re-enter the tree mid-
        // layout.  Keeping the body pure eliminates that race.
        final width = MediaQuery.sizeOf(context).width;
        final layoutSize = LayoutBreakpoints.sizeForWidth(width);

        final layoutMode = context.select<SettingsController, LayoutMode>(
          (s) => s.layoutMode,
        );

        // Delegate the hysteresis/settle decision to the
        // [LayoutShellController]. The controller exposes its
        // committed size via a [ValueListenable] (the controller
        // itself is a [ChangeNotifier]) so the shell subtree
        // re-renders only when the size actually flips, not on every
        // resize tick.  Note: [_shell.update] starts / cancels timers
        // and may call [notifyListeners] but only from the Timer's
        // callback (i.e. asynchronously), never synchronously from
        // here.
        final committedSize = _shell.update(
          rawWidth: width,
          layoutMode: layoutMode,
        );
        // The dashboard always renders a compact-or-wider shell
        // here; the dedicated mobile shell is mounted at a higher
        // level by the router when needed.
        final shouldUseCompact = committedSize == LayoutSize.compact;

        return DashboardView(
          size: layoutSize,
          width: width,
          shouldUseCompact: shouldUseCompact,
          leftWidthNotifier: _leftWidth,
          rightWidthNotifier: _rightWidth,
          onLeftResize: _onLeftResize,
          onLeftResizeEnd: _onLeftResizeEnd,
          onRightResize: _onRightResize,
          onRightResizeEnd: _onRightResizeEnd,
          child: widget.child,
        );
      },
    );
  }
}
