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
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';

import 'dashboard_layout/dashboard_view.dart';

/// Controller widget for the multi-pane dashboard layout.
///
/// Owns transient resize state via [ValueNotifier]s (so drag updates don't
/// trigger full-tree rebuilds). The shell decision (compact vs full) is
/// delegated to the shared, app-level [LayoutShellController] so the
/// dashboard, the router, and the route page builders all agree on the
/// same layout and a shell swap only re-renders the shell widget, not
/// the entire tree.
/// The actual UI is delegated to the stateless [DashboardView] so that
/// 
/// indirection.
class DashboardLayout extends StatefulWidget {
  /// The main content widget (typically the route's child).
  final Widget child;

  const DashboardLayout({super.key, required this.child});

  @override
  State<DashboardLayout> createState() => _DashboardLayoutState();
}

class _DashboardLayoutState extends State<DashboardLayout> {
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // -- Shell decision -----------------------------------------------
        //
        // The shell decision is made by the router's `_AdaptiveMainLayout`
        // during its own build, which happens before this widget (it is a
        // descendant). So this only *reads* the resolved shell. It used to
        // be a second writer, calling `LayoutShellController.update` from
        // here as well; with the controller no longer notifying, two
        // writers would race on the same sticky state with no way for the
        // loser to find out.
        //
        // The width is read for the pane sizing below, not to re-derive the
        // shell: the inner [LayoutBuilder] constraints shrink and grow when
        // the sidebars mount or unmount, and using them as the breakpoint
        // signal previously created a feedback loop where toggling the
        // opening a pane nudged the available width across the threshold and
        // flipped the shell on its own. Anchoring to the window keeps the
        // decision independent of what is mounted.
        final width = MediaQuery.sizeOf(context).width;
        final layoutSize = LayoutBreakpoints.sizeForWidth(width);

        final shell = context.read<LayoutShellController>();

        // The dashboard used to ask the shell whether the detail pane fitted
        // alongside the navigation pane, and to own the pane's drag width.
        // Neither is its business now: the pane belongs to `RoomPage`, which
        // knows its own room and its own width. What is left here is the rail
        // and the room list, and they are the same widget at every width.
        assert(
          shell.fitsTwoPanes || shell.isMobile,
          'DashboardView should only be mounted in a shell that has a rail',
        );
        return DashboardView(
          size: layoutSize,
          width: width,
          child: widget.child,
        );
      },
    );
  }
}
