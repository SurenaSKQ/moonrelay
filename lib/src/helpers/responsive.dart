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

import 'package:flutter/widgets.dart';

/// Discrete size buckets used across the app for adaptive layout decisions.
///
/// Breakpoints are intentionally conservative to match a desktop-first client:
/// - [compact]:  narrow windows where secondary panes must collapse to overlays.
/// - [medium]:   single-sidebar windows (e.g. 1366x768 with the right pane open).
/// - [expanded]: typical desktop windows with two sidebars visible.
/// - [wide]:     large displays where extra padding and roomy panes feel right.
enum LayoutSize {
  compact,
  medium,
  expanded,
  wide,
}

extension LayoutSizeX on LayoutSize {
  /// Returns true when the layout has enough room for secondary panes.
  bool get hasTwoSidebars =>
      this == LayoutSize.expanded || this == LayoutSize.wide;

  /// Returns true when the layout can keep a single (left or right) pane
  /// pinned alongside the main content.
  bool get hasOneSidebar =>
      hasTwoSidebars || this == LayoutSize.medium;

  /// Returns true when secondary content should be promoted to a drawer / modal
  /// instead of a pinned column.
  bool get isCompact => this == LayoutSize.compact;
}

/// Breakpoint widths in logical pixels.
///
/// These are kept as named constants so call sites can document their intent
/// and so the test suite can pin behaviour against changes.
class LayoutBreakpoints {
  const LayoutBreakpoints._();

  /// Below this width we treat the window as compact (single-pane dashboard
  /// shell with a unified sidebar); anything narrower switches to the
  /// dedicated mobile layout via [LayoutBreakpoints.mobileMax].
  ///
  /// Historical note: this used to be 600, then 1280.  We now treat the
  /// entire 600-1100 range as compact because the old "medium" shell only
  /// rendered a left sidebar with no room list, which was useless on a
  /// 768px monitor.  We deliberately leave the 1100-1280 band for the
  /// full multi-pane layout because a 1100px window can still fit the
  /// navigation rail (80px) + left pane (~280px) + chat + right pane
  /// (~240px) without either sidebar dropping below its 200px minimum,
  /// whereas 1280px is exactly the line where the right pane begins to
  /// crowd the chat.  1100 gives the user a few extra pixels of headroom
  /// so the multi-pane shell doesn't immediately collapse as soon as the
  /// window is dragged in by a pixel.
  static const double compactMax = 1100;

  /// Below this width we render the dedicated [MobileLayout] instead of
  /// the dashboard, even when the user has not opted into mobile mode
  /// explicitly.  Below 600px the dashboard is unusable.
  static const double mobileMax = 600;

  /// Below this width we treat the window as medium (single sidebar).
  /// Retained for back-compat with code that still inspects
  /// [LayoutSize.medium]: the new dashboard treats medium and compact
  /// the same way.
  static const double mediumMax = 900;

  /// Below this width we treat the window as expanded (two sidebars).
  static const double expandedMax = 1100;

  /// Minimum width allowed for any pinned pane.
  static const double minSidebarWidth = 200;

  /// Default width of the left sidebar.
  static const double defaultLeftSidebarWidth = 320;

  /// Default width of the right sidebar.
  static const double defaultRightSidebarWidth = 280;

  /// Maximum width allowed for any pinned pane.
  static const double maxSidebarWidth = 600;

  /// Width of the in-room search panel overlay.
  static const double searchPanelWidth = 320;

  /// Width of the hub category sidebar.
  static const double hubCategorySidebarWidth = 280;

  /// Width of a compact hub navigation rail.
  static const double hubNavRailWidth = 72;

  /// Computes the [LayoutSize] for the given width.
  ///
  /// Note: the dashboard no longer renders a distinct "medium" shell.
  /// Anything in the 600-1100 range is now [LayoutSize.compact] so the
  /// unified sidebar stays visible.  Callers that need the historical
  /// medium bucket can compare against [mediumMax] directly.
  ///
  /// The values returned here are kept stable for callers that still
  /// inspect [LayoutSize.medium] / [LayoutSize.expanded] (e.g. the
  /// dashboard's wide-mode shell), but the actual layout decision now
  /// flows through [shouldUseCompact] / [shouldUseMobile] to avoid
  /// ambiguity at the 900-1100 boundary.
  static LayoutSize sizeForWidth(double width) {
    if (width < mobileMax) return LayoutSize.compact;
    if (width < mediumMax) return LayoutSize.medium;
    if (width < expandedMax) return LayoutSize.compact;
    return LayoutSize.wide;
  }

  /// Returns true when the dashboard should be replaced by the mobile
  /// layout at the given viewport width.
  ///
  /// The dashboard assumes both side panes and a chat surface can fit
  /// side-by-side; below [mobileMax] it cannot.  This helper is the
  /// single source of truth for the switch: the router and the
  /// dashboard both consult it.
  static bool shouldUseMobile(double width) => width < mobileMax;

  /// Returns true when the dashboard should use the unified
  /// [CompactSidebar] rather than the full multi-pane layout at the
  /// given viewport width.
  ///
  /// The compact shell kicks in at [compactMax] and stays in use all
  /// the way down to [mobileMax] (where the dashboard itself is no
  /// longer usable and [shouldUseMobile] takes over).
  static bool shouldUseCompact(double width) =>
      width < compactMax && !shouldUseMobile(width);

  /// Clamps a sidebar's requested [requestedWidth] against the given [viewportWidth],
/// the [mainMinWidth] that must remain visible, and the [otherPanesWidth] consumed
/// by sibling panes (e.g. the right sidebar on the far right).
///
/// The result is always between [minSidebarWidth] and [maxSidebarWidth].
/// When the viewport cannot accommodate everything, the function returns
/// the largest sidebar width that still satisfies the minimum main column.
static double clampSidebarWidth({
  required double requestedWidth,
  required double viewportWidth,
  required double mainMinWidth,
  required double otherPanesWidth,
}) {
  final available =
      (viewportWidth - mainMinWidth - otherPanesWidth).clamp(
    minSidebarWidth,
    maxSidebarWidth,
  );
  return requestedWidth.clamp(minSidebarWidth, available);
}
}

/// Convenience extension on [BoxConstraints] so widgets can ask for their
/// size bucket without re-implementing the breakpoint math.
extension BoxConstraintsLayoutSize on BoxConstraints {
  LayoutSize get layoutSize => LayoutBreakpoints.sizeForWidth(maxWidth);
}

/// Inherited widget that exposes the current [LayoutSize] and available
/// width down the widget tree without forcing every widget to wrap itself in
/// a [LayoutBuilder]. Subtrees that need to react to size changes can read
/// [LayoutScope.of] inside a [LayoutBuilder] or via a [Listenable] on
/// [LayoutScope.controller].
class LayoutScope extends InheritedWidget {
  const LayoutScope({
    super.key,
    required this.size,
    required this.availableWidth,
    required super.child,
  });

  final LayoutSize size;
  final double availableWidth;

  static LayoutScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LayoutScope>();
    return scope ?? _RootLayoutScope();
  }

  @override
  bool updateShouldNotify(covariant LayoutScope oldWidget) =>
      size != oldWidget.size ||
      availableWidth != oldWidget.availableWidth;
}

/// Default scope used at the root of the app before any [LayoutBuilder] has
/// run. Defers to the breakpoints for a sensible default rather than always
/// reporting [LayoutSize.expanded].
class _RootLayoutScope extends LayoutScope {
  _RootLayoutScope()
      : super(
          size: LayoutSize.expanded,
          availableWidth: double.infinity,
          child: SizedBox.shrink(),
        );
}