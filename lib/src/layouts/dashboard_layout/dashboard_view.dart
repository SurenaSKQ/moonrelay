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
import 'package:moonrelay/src/widgets/compact_sidebar.dart';
import 'package:moonrelay/src/widgets/global_shortcut_listener.dart';
import 'package:moonrelay/src/widgets/status_bar.dart';
import 'package:moonrelay/src/widgets/encryption/incoming_verification_listener.dart';
import 'package:moonrelay/src/widgets/encryption/post_login_setup_checker.dart';

import 'pane_hosts.dart';

// ─── Stateless view ─────────────────────────────────────────────────────────

/// Pure presentation widget for the dashboard layout.
///
/// Receives everything it needs as constructor props so it rebuilds
/// deterministically whenever the controller rebuilds. Drag state is observed
/// via [ListenableBuilder] scoped to the sidebar width so unrelated changes
/// don't propagate.
class DashboardView extends StatelessWidget {
  const DashboardView({
    super.key,
    required this.child,
    required this.size,
    required this.width,
    required this.shouldUseCompact,
    required this.leftWidthNotifier,
    required this.rightWidthNotifier,
    required this.onLeftResize,
    required this.onLeftResizeEnd,
    required this.onRightResize,
    required this.onRightResizeEnd,
  });

  final Widget child;
  final LayoutSize size;

  /// Live viewport width. Passed in from the parent so [DashboardView]
  /// does not need to call [MediaQuery.sizeOf] (which would subscribe it
  /// to every media-query change and rebuild on each resize tick).
  final double width;

  /// Pre-resolved compact-vs-wide decision. The controller applies
  /// hysteresis around the 1280 px boundary so this flag only flips when
  /// the resize has settled.
  final bool shouldUseCompact;
  final ValueNotifier<double?> leftWidthNotifier;
  final ValueNotifier<double?> rightWidthNotifier;
  final void Function(double) onLeftResize;
  final VoidCallback onLeftResizeEnd;
  final void Function(double) onRightResize;
  final VoidCallback onRightResizeEnd;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final theme = Theme.of(context);

    // The compact shell is selected by the controller with hysteresis so
    // we never tear down / mount the right sidebar mid-resize. Width is
    // also passed in from the controller so we don't need to read it
    // from MediaQuery again.
    if (shouldUseCompact) {
      return CompactDashboard(width: width, child: child);
    }

    // ── Wide shells  full multi-pane layout ───────────────────────
    // The compact shell handles everything 600-1279 wide.  Above
    // 1280px the full multi-pane layout (right sidebar visible) is
    // shown; otherwise we fall back to the compact shell again so
    // there is no "medium" gap where the sidebar disappears.
    //
    // The right sidebar's mount state is anchored to [shouldUseCompact]
    // (passed in from the controller) rather than recomputed against
    // [MediaQuery.sizeOf]. The controller applies hysteresis around the
    // 1280 px boundary so we never tear down the right sidebar mid-drag.
    final showLeft = settings.leftSidebarVisible;
    final showRight = settings.rightSidebarVisible && !shouldUseCompact;

    // In RTL mode the sidebar order must be reversed so that the
    // "left" sidebar appears on the right side of the window.
    final paneChildren = <Widget>[
      if (showLeft && !shouldUseCompact)
        LeftPaneHost(
          widthNotifier: leftWidthNotifier,
          onResize: onLeftResize,
          onResizeEnd: onLeftResizeEnd,
          theme: theme,
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
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: isRtl ? paneChildren.reversed.toList() : paneChildren,
            ),
          ),
          if (settings.showStatusBar) const ApplicationStatusBar(),
        ],
      ),
    );
  }
}

// ─── Compact layout shell ──────────────────────────────────────────────────

/// Layout used when the window is too narrow to keep both side panes pinned,
/// or when the user has explicitly opted into compact mode.
///
/// Replaces the old "navigation rail + main content" layout, which left
/// the user staring at a spaces/rooms picker with no room list.  The new
/// [CompactSidebar] combines the navigation rail, the left pane, and a
/// segmented filter so the user can pick a destination and immediately
/// see something useful.
class CompactDashboard extends StatelessWidget {
  const CompactDashboard({
    super.key,
    required this.child,
    required this.width,
  });

  final Widget child;

  /// Viewport width passed in from the controller so [CompactDashboard]
  /// does not have to call [MediaQuery.sizeOf] (which would subscribe the
  /// sidebar to every media-query change and rebuild on every resize tick).
  final double width;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();

    // Clamp the sidebar width exactly once per build and reuse the result
    // for both the [SizedBox] wrapper and the [CompactSidebar]'s explicit
    // width. Previously the clamp was duplicated in two places which made
    // the layout very slightly inconsistent during animated width changes.
    final sidebarWidth =
        settings.leftSidebarWidth.clamp(220.0, 360.0).toDouble();

    // In RTL mode the sidebar order must be reversed.
    final compactChildren = <Widget>[
      if (settings.leftSidebarVisible)
        SizedBox(
          width: sidebarWidth,
          child: CompactSidebar(width: sidebarWidth),
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
    ];

    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return LayoutScope(
      size: LayoutSize.compact,
      availableWidth: width,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children:
                  isRtl ? compactChildren.reversed.toList() : compactChildren,
            ),
          ),
          if (settings.showStatusBar) const ApplicationStatusBar(),
        ],
      ),
    );
  }
}
