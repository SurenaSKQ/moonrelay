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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/global_shortcut_listener.dart';
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
    final showLeft = settings.leftSidebarVisible;
    final showRight = settings.rightSidebarVisible && detailPaneFits;
    // One clamp, one range. The two dashboards used to disagree here
    // (200..360 against 220..360), so a width the user had chosen in one
    // shell was silently rewritten in the other.
    final sidebarWidth =
        settings.leftSidebarWidth.clamp(200.0, 360.0).toDouble();

    // In RTL mode the sidebar order must be reversed so that the
    // "left" sidebar appears on the right side of the window.  The
    // collapse/expand gutters are row children too, so they land on
    // the same side as the sidebar they belong to.
    final paneChildren = <Widget>[
      if (showLeft) ...[
        SizedBox(
          width: sidebarWidth,
          child: NavigationSidebar(),
        ),
        SidebarCollapseGutter(
          onCollapse: () => settings.setLeftSidebarVisible(false),
        ),
      ] else
        SidebarExpandGutter(
          onExpand: () => settings.setLeftSidebarVisible(true),
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

// --- Sidebar collapse / expand gutters --------------------------------------

/// Thin strip between the navigation sidebar and the main content.
///
/// On hover it reveals a button that collapses the sidebar; the strip
/// is a row child so it stays on the same side as the sidebar in RTL
/// windows.
class SidebarCollapseGutter extends StatefulWidget {
  const SidebarCollapseGutter({super.key, required this.onCollapse});

  final VoidCallback onCollapse;

  @override
  State<SidebarCollapseGutter> createState() => _SidebarCollapseGutterState();
}

class _SidebarCollapseGutterState extends State<SidebarCollapseGutter> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: Container(
        width: 18,
        color: Colors.transparent,
        alignment: Alignment.center,
        child: AnimatedOpacity(
          opacity: _hover ? 1.0 : 0.3,
          duration: const Duration(milliseconds: 120),
          child: IconButton(
            icon: Icon(
              isRtl ? LucideIcons.chevronsRight : LucideIcons.chevronsLeft,
              size: 14,
            ),
            tooltip: l10n.collapseSidebar,
            onPressed: widget.onCollapse,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(
              width: 22,
              height: 22,
            ),
            style: IconButton.styleFrom(
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin strip shown at the side of the screen while the navigation
/// sidebar is collapsed, offering the expand button.
class SidebarExpandGutter extends StatelessWidget {
  const SidebarExpandGutter({super.key, required this.onExpand});

  final VoidCallback onExpand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final isRtl = Directionality.of(context) == TextDirection.rtl;

    return Container(
      width: 18,
      color: Colors.transparent,
      alignment: Alignment.center,
      child: IconButton(
        icon: Icon(
          isRtl ? LucideIcons.chevronsLeft : LucideIcons.chevronsRight,
          size: 14,
        ),
        tooltip: l10n.expandSidebar,
        onPressed: onExpand,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 22, height: 22),
        style: IconButton.styleFrom(
          backgroundColor: scheme.surfaceContainerHighest,
        ),
      ),
    );
  }
}

