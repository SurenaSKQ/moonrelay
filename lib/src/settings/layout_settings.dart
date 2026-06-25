/// Configuration enums for the dynamic dashboard layout.
///
/// These control which panes are visible and how the layout is structured.
library;

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
    }
  }
}
