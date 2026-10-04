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
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/global_shortcut_listener.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/nav_rail.dart';
import 'package:moonrelay/src/widgets/navigation_sidebar/navigation_sidebar.dart';
import 'package:moonrelay/src/widgets/encryption/incoming_verification_listener.dart';
import 'package:moonrelay/src/widgets/encryption/post_login_setup_checker.dart';

import 'pane_hosts.dart';

// --- Stateless view ---------------------------------------------------------

/// Pure presentation widget for the dashboard layout.
///
/// Receives everything it needs as constructor props so it rebuilds
/// deterministically whenever the controller rebuilds. Drag state is observed
/// via [ListenableBuilder] scoped to the sidebar width so unrelated changes
/// don't propagate.
///
/// There used to be a second widget here, `CompactDashboard`, for the
/// 600-1100px band, with its own sidebar implementation. That made the
/// narrow dashboard a *different product* rather than the same one in less
/// space: it dropped space grouping, drag-to-reorder, the space context
/// menu, auto-grouping and the per-space room tree, and its room rows lost
/// the encryption and mention badges. None of that needs horizontal room, so
/// the split cost features and bought nothing.
///
/// The single composition below is therefore parameterised by one question,
/// *is there room for the detail pane*, which is what the shell already
/// answers. Everything else is the same widget adapting.
class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.child,
    required this.size,
    required this.width,
    required this.detailPaneFits,
    required this.rightWidthNotifier,
    required this.onRightResize,
    required this.onRightResizeEnd,
  });

  final Widget child;
  final LayoutSize size;

  /// Live viewport width. Passed in from the parent so [DashboardView]
  /// does not need to call [MediaQuery.sizeOf] (which would subscribe it
  /// to every media-query change and rebuild on each resize tick).
  final double width;

  /// Whether the resolved shell has room for the detail pane alongside the
  /// navigation pane. False in the compact band, and never reached from
  /// the single-pane shell, which does not mount this widget.
  ///
  /// This is the only thing the shell decides about the dashboard's
  /// composition. The controller applies hysteresis around the boundary so
  /// the flag only flips once the resize has settled, which is what stops
  /// the detail pane being torn down and rebuilt mid-drag.
  final bool detailPaneFits;

  final ValueNotifier<double?> rightWidthNotifier;
  final void Function(double) onRightResize;
  final VoidCallback onRightResizeEnd;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final theme = Theme.of(context);

    // -- One composition, every width -------------------------------
    final showRight = settings.rightSidebarVisible && detailPaneFits;
    // One clamp, one range. The two dashboards used to disagree here
    // (200..360 against 220..360), so a width the user had chosen in one
    // shell was silently rewritten in the other.
    final sidebarWidth = settings.leftSidebarWidth
        .clamp(
          LayoutBreakpoints.minSidebarWidth,
          LayoutBreakpoints.maxSidebarWidth,
        )
        .toDouble();

    // In RTL mode the sidebar order must be reversed so that the
    // "left" sidebar appears on the right side of the window.
    //
    // The rail is a row child for the same reason: in RTL it should sit on
    // the right of the room list, and reversing the whole list is simpler and
    // less error-prone than flipping each pane's internals.
    final paneChildren = <Widget>[
      const SpacesRailHost(),
      SizedBox(
        width: sidebarWidth,
        child: const NavigationSidebar(),
      ),
      Expanded(
        child: GlobalShortcutListener(
          child: PostLoginSetupChecker(
            child: IncomingVerificationListener(
              child: child,
            ),
          ),
        ),
      ),
      if (showRight) ...[
        ResizeHandle(
          onDrag: onRightResize,
          onDragEnd: onRightResizeEnd,
        ),
        RightPaneHost(
          widthNotifier: rightWidthNotifier,
          theme: theme,
        ),
      ],
    ];

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return LayoutScope(
      size: size,
      availableWidth: width,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: isRtl ? paneChildren.reversed.toList() : paneChildren,
      ),
    );
  }
}

