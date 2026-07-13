/// Configuration enums for the dynamic dashboard layout.
///
/// These control which panes are visible and how the layout is structured.
library;

/// How the main chat surface is laid out.
///
/// The default [auto] mode picks a layout based on the current window
/// width  the full multi-pane [DashboardLayout] when there is room for
/// the sidebars, a compact sidebar that merges navigation, rooms, and
/// spaces when the window is narrow, and a dedicated [MobileLayout] for
/// very small windows that do not benefit from a side-by-side view.
///
/// Users can override the responsive behaviour by choosing [compact] or
/// [mobile] explicitly  useful on a desktop user who prefers a single
/// chat at a time, or when the auto mode gets it wrong on a particular
/// monitor.
enum LayoutMode {
  /// Pick a layout automatically based on the window width.
  auto,

  /// Always use the compact dashboard sidebar (one column, no right pane).
  compact,

  /// Always use the single-pane mobile layout (route-driven pages).
  mobile,
}

extension LayoutModeExtension on LayoutMode {
  String get label {
    switch (this) {
      case LayoutMode.auto:
        return 'Auto';
      case LayoutMode.compact:
        return 'Compact';
      case LayoutMode.mobile:
        return 'Mobile';
    }
  }
}

/// Choices for the left sidebar pane.
enum LeftPaneChoice {
  rooms,
  spaces,
  friends,
  none,
}

extension LeftPaneChoiceExtension on LeftPaneChoice {
  String get label {
    switch (this) {
      case LeftPaneChoice.rooms:
        return 'Rooms';
      case LeftPaneChoice.spaces:
        return 'Spaces';
      case LeftPaneChoice.friends:
        return 'Friends';
      case LeftPaneChoice.none:
        return 'Hidden';
    }
  }
}

/// Choices for the right sidebar pane.
enum RightPaneChoice {
  none,
  roomInfo,
  members,
  threads,
  pinned,
}

extension RightPaneChoiceExtension on RightPaneChoice {
  String get label {
    switch (this) {
      case RightPaneChoice.none:
        return 'None';
      case RightPaneChoice.roomInfo:
        return 'Room Info';
      case RightPaneChoice.members:
        return 'Members';
      case RightPaneChoice.threads:
        return 'Threads';
      case RightPaneChoice.pinned:
        return 'Pinned';
    }
  }
}
