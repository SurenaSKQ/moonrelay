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

  /// Below this width we treat the window as compact.
  static const double compactMax = 600;

  /// Below this width we treat the window as medium (single sidebar).
  static const double mediumMax = 900;

  /// Below this width we treat the window as expanded (two sidebars).
  static const double expandedMax = 1280;

  /// Minimum width allowed for any pinned pane.
  static const double minSidebarWidth = 200;

  /// Default width of the left sidebar.
  static const double defaultLeftSidebarWidth = 320;

  /// Default width of the right sidebar.
  static const double defaultRightSidebarWidth = 280;

  /// Maximum width allowed for any pinned pane.
  static const double maxSidebarWidth = 600;

  /// Width of the fixed navigation column on the far left.
  static const double navigationPaneWidth = 80;

  /// Width of the in-room search panel overlay.
  static const double searchPanelWidth = 320;

  /// Width of the hub category sidebar.
  static const double hubCategorySidebarWidth = 280;

  /// Width of a compact hub navigation rail.
  static const double hubNavRailWidth = 72;

  /// Computes the [LayoutSize] for the given width.
  static LayoutSize sizeForWidth(double width) {
    if (width < compactMax) return LayoutSize.compact;
    if (width < mediumMax) return LayoutSize.medium;
    if (width < expandedMax) return LayoutSize.expanded;
    return LayoutSize.wide;
  }

  /// Clamps a sidebar's requested [requestedWidth] against the given [viewportWidth],
/// the [mainMinWidth] that must remain visible, and the [otherPanesWidth] consumed
/// by sibling panes (e.g. the navigation rail on the far left).
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