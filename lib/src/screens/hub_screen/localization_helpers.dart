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
import 'package:moonrelay/src/settings/accents.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';

// -- Localization helpers ----------------------------------------------------

String localizedRightPaneChoice(RightPaneChoice choice, AppLocalizations l10n) {
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

String localizedLayoutDensity(LayoutDensity density, AppLocalizations l10n) {
  switch (density) {
    case LayoutDensity.comfortable:
      return l10n.densityComfortable;
    case LayoutDensity.compact:
      return l10n.densityCompact;
  }
}

String localizedAutoDownloadPolicy(
    AutoDownloadPolicy policy, AppLocalizations l10n) {
  switch (policy) {
    case AutoDownloadPolicy.always:
      return l10n.autoDownloadAlways;
    case AutoDownloadPolicy.wifi:
      return l10n.autoDownloadWifi;
    case AutoDownloadPolicy.never:
      return l10n.autoDownloadNever;
  }
}

String localizedSendShortcut(SendShortcut shortcut, AppLocalizations l10n) {
  switch (shortcut) {
    case SendShortcut.enter:
      return l10n.sendShortcutEnter;
    case SendShortcut.cmdEnter:
      return l10n.sendShortcutCmdEnter;
    case SendShortcut.both:
      return l10n.sendShortcutBoth;
  }
}

String localizedTrayClickAction(TrayClickAction action, AppLocalizations l10n) {
  switch (action) {
    case TrayClickAction.toggle:
      return l10n.trayClickToggle;
    case TrayClickAction.show:
      return l10n.trayClickShow;
    case TrayClickAction.openUnread:
      return l10n.trayClickOpenUnread;
  }
}

String localizedLogLevel(LogLevel level, AppLocalizations l10n) {
  switch (level) {
    case LogLevel.all:
      return l10n.logLevelAll;
    case LogLevel.trace:
      return l10n.logLevelTrace;
    case LogLevel.debug:
      return l10n.logLevelDebug;
    case LogLevel.info:
      return l10n.logLevelInfo;
    case LogLevel.warning:
      return l10n.logLevelWarning;
    case LogLevel.error:
      return l10n.logLevelError;
    case LogLevel.fatal:
      return l10n.logLevelFatal;
  }
}

/// Resolves an accent's display name from its ARB key.
///
/// The accents carry a key rather than a string so the registry does not need
/// to import the generated localizations, which keeps it usable from a plain
/// unit test. That trade means something has to do the lookup, and this is it.
///
/// Falls back to the accent's id when the key is missing from a locale, which
/// is better than an empty row and better than a blank settings page. The
/// fallback is why the fallback is the id and not a hardcoded English name:
/// an id is at least stable and recognisable.
String localizedAccent(MoonrelayAccent accent, AppLocalizations l10n) {
  final resolved = switch (accent.labelKey) {
    'accentProcellarum' => l10n.accentProcellarum,
    'accentNubium' => l10n.accentNubium,
    'accentSerenitatis' => l10n.accentSerenitatis,
    'accentFecunditatis' => l10n.accentFecunditatis,
    'accentFrigoris' => l10n.accentFrigoris,
    'accentTycho' => l10n.accentTycho,
    'accentCopernicus' => l10n.accentCopernicus,
    'accentAristarchus' => l10n.accentAristarchus,
    'accentPlato' => l10n.accentPlato,
    final other => other.isEmpty ? accent.id : other,
  };
  return resolved.isEmpty ? accent.id : resolved;
}