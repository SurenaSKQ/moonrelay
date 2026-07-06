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

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/theme.dart';

// ── Localization helpers ────────────────────────────────────────────────────

String localizedThemeOption(
    MoonrelayThemeOption option, AppLocalizations l10n) {
  switch (option) {
    case MoonrelayThemeOption.indigo:
      return l10n.themeDefault;
    case MoonrelayThemeOption.oceanBlue:
      return l10n.themeOceanBlue;
    case MoonrelayThemeOption.midnightSlate:
      return l10n.themeMidnightSlate;
    case MoonrelayThemeOption.crimson:
      return l10n.themeCrimson;
    case MoonrelayThemeOption.amber:
      return l10n.themeAmber;
    case MoonrelayThemeOption.steel:
      return l10n.themeSteel;
    case MoonrelayThemeOption.sky:
      return l10n.themeSky;
  }
}

String localizedLeftPaneChoice(LeftPaneChoice choice, AppLocalizations l10n) {
  switch (choice) {
    case LeftPaneChoice.rooms:
      return l10n.paneRooms;
    case LeftPaneChoice.spaces:
      return l10n.paneSpaces;
    case LeftPaneChoice.friends:
      return l10n.paneFriends;
    case LeftPaneChoice.none:
      return l10n.paneHidden;
  }
}

String localizedRightPaneChoice(
    RightPaneChoice choice, AppLocalizations l10n) {
  switch (choice) {
    case RightPaneChoice.none:
      return l10n.paneNone;
    case RightPaneChoice.roomInfo:
      return l10n.paneRoomInfo;
    case RightPaneChoice.members:
      return l10n.paneMembers;
    case RightPaneChoice.threads:
      return l10n.thread;
    case RightPaneChoice.pinned:
      return l10n.pinnedMessages;
  }
}
