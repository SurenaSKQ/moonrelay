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

import 'package:moonrelay/src/localization/app_localizations.dart';

// -----------------------------------------------------------------------------
// Route keys
// -----------------------------------------------------------------------------

/// The hub's stable route keys.
///
/// These are URL path segments, so they are declared here rather than being
/// spelled inline at each use site. Before the hub became a route the keys
/// were only ever compared inside one file, which is why the command palette
/// came to carry its own copy of nine `/hub/...` path strings and one of them
/// (`/hub/settings/network`) named a sub-item that has never existed, which
/// rendered an empty page. Now that the hub is
/// reachable by URL, a key that is only known in two places is a bug
/// waiting to happen, and the router needs the same list the screen uses in
/// order to reject a bad deep link rather than render an empty pane.
class HubRouteKeys {
  const HubRouteKeys._();

  static const String accounts = 'accounts';
  static const String settings = 'settings';
  static const String about = 'about';

  /// Every navigable section, in the order the hub presents them.
  ///
  /// The profile is deliberately absent: it is the hub's *index*, not a
  /// section beside the others, so it has no key of its own. It used to be a
  /// fourth category, which meant `/hub` and `/hub/profile` both rendered
  /// the same editor and the narrow index page had to choose between showing
  /// the profile and listing it.
  static const List<String> categories = <String>[
    accounts,
    settings,
    about,
  ];

  // Settings sub-items, in presentation order.
  static const String appearance = 'appearance';
  static const String security = 'security';
  static const String chat = 'chat';
  static const String keybinds = 'keybinds';
  static const String logs = 'logs';
  static const String background = 'background';
  static const String notifications = 'notifications';
  static const String privacy = 'privacy';
  static const String storage = 'storage';
  static const String advanced = 'advanced';
  static const String blocked = 'blocked';
  static const String updates = 'updates';

  /// The retired layout key.
  ///
  /// Kept as a literal rather than deleted so `/hub/settings/layout` can be
  /// answered. Appearance and layout were two pages deciding where the same
  /// user would put "how big is the room pane" and "what colour is the app",
  /// and both answers were a scroll. They are one page now.
  ///
  /// It is *not* in [settingsSubItems], which is the live list: a retired key
  /// that stayed in the list would keep a row in the nav and an entry in the
  /// settings overview pointing at a page that no longer exists, which is the
  /// exact failure this class was written to prevent.
  static const String retiredLayout = 'layout';

  static const List<String> settingsSubItems = <String>[
    appearance,
    security,
    chat,
    keybinds,
    logs,
    background,
    notifications,
    privacy,
    storage,
    advanced,
    blocked,
    updates,
  ];

  /// Keys that were real sub-items and now live somewhere else, mapped to
  /// where they went.
  ///
  /// The router redirects through this rather than falling back to the section
  /// overview, because the default answer to an unknown sub-item is "the list
  /// of things you could have meant". For a key that is merely retired the
  /// answer is the page it became, and a bookmark to it should land on the
  /// settings the reader was looking for rather than on a page of links.
  static const Map<String, String> retiredSubItems = <String, String>{
    retiredLayout: appearance,
  };

  /// The live key a retired key now resolves to, or null if [key] is not
  /// retired.
  static String? replacementFor(String key) => retiredSubItems[key];

  /// True when [key] names a real category.
  static bool isCategory(String? key) =>
      key != null && categories.contains(key);

  /// True when [key] names a real settings sub-item.
  ///
  /// Retired keys are false here on purpose, so the router checks
  /// [replacementFor] before it rejects one.
  static bool isSettingsSubItem(String? key) =>
      key != null && settingsSubItems.contains(key);
}

// -----------------------------------------------------------------------------
// Data models for hub navigation items
// -----------------------------------------------------------------------------

/// A single selectable entry in the hub's category sidebar.
class HubNavigationItem {
  final String? key;
  final String label;
  final IconData icon;

  /// Optional one-liner about the destination, shown in a sub-page's strip.
  /// Null for destinations that have nothing to add to their own name.
  final String? subtitle;

  const HubNavigationItem({
    this.key,
    required this.label,
    required this.icon,
    this.subtitle,
  });
}

/// A category group that can contain sub-items (e.g. App Settings > Appearance).
class HubCategory {
  final String? key;
  final String label;
  final IconData icon;
  final List<HubNavigationItem> items;
  final bool isExpandable;

  const HubCategory({
    this.key,
    required this.label,
    required this.icon,
    this.items = const [],
    this.isExpandable = false,
  });
}

// -----------------------------------------------------------------------------
// The settings sub-item list, built once
// -----------------------------------------------------------------------------

/// The label for each settings sub-item, or null if [key] names no sub-item.
///
/// A switch rather than a map, so a key added to
/// [HubRouteKeys.settingsSubItems] without a label here is a compile error
/// rather than a row that silently renders its own URL segment as a title.
String? settingsSubItemLabel(String key, AppLocalizations l10n) =>
    switch (key) {
      HubRouteKeys.appearance => l10n.appearanceAndLayout,
      HubRouteKeys.security => l10n.encryptionAndSecurity,
      HubRouteKeys.chat => l10n.chatSettings,
      HubRouteKeys.keybinds => l10n.keybinds,
      HubRouteKeys.logs => l10n.logs,
      HubRouteKeys.background => l10n.backgroundAndTray,
      HubRouteKeys.notifications => l10n.notifications,
      HubRouteKeys.privacy => l10n.privacy,
      HubRouteKeys.storage => l10n.storage,
      HubRouteKeys.advanced => l10n.advanced,
      HubRouteKeys.blocked => l10n.blockedUsers,
      HubRouteKeys.updates => l10n.updates,
      _ => null,
    };

/// One line describing what a settings sub-item is for, or null if it has
/// none.
///
/// This is the page's subtitle in its strip, and it is here rather than in
/// the pages so that a page which gains a subtitle cannot also gain a second
/// title. Most keys return null: a page that says nothing about itself is not
/// one that is missing a description, it is one whose controls are the
/// description. The ones that had a sentence before keep it.
String? settingsSubItemSubtitle(String key, AppLocalizations l10n) =>
    switch (key) {
      HubRouteKeys.appearance => l10n.appearanceAndLayoutDescription,
      HubRouteKeys.keybinds => l10n.keybindsDescription,
      HubRouteKeys.background => l10n.backgroundAndTrayDescription,
      HubRouteKeys.notifications => l10n.notificationsDescription,
      HubRouteKeys.blocked => l10n.blockedUsersDescription,
      _ => null,
    };

/// The icon for each settings sub-item.
///
/// Every row used to carry `LucideIcons.settings`, which made the hub's
/// thirteen-item overview a column of identical gears. The icon is what tells
/// you which row is Storage before you read it, and it is also the first thing
/// the command palette shows next to a settings hit, so it has to distinguish
/// them on its own.
IconData settingsSubItemIcon(String key) => switch (key) {
      HubRouteKeys.appearance => LucideIcons.palette,
      HubRouteKeys.security => LucideIcons.shield,
      HubRouteKeys.chat => LucideIcons.messageSquare,
      HubRouteKeys.keybinds => LucideIcons.keyboard,
      HubRouteKeys.logs => LucideIcons.fileText,
      HubRouteKeys.background => LucideIcons.minimize2,
      HubRouteKeys.notifications => LucideIcons.bell,
      HubRouteKeys.privacy => LucideIcons.eyeOff,
      HubRouteKeys.storage => LucideIcons.hardDrive,
      HubRouteKeys.advanced => LucideIcons.slidersHorizontal,
      HubRouteKeys.blocked => LucideIcons.ban,
      HubRouteKeys.updates => LucideIcons.download,
      _ => LucideIcons.settings,
    };

/// Every settings sub-item, in presentation order, labelled and iconed.
///
/// This used to live as a private method on the hub's state, which meant the
/// command palette could not read it and kept its own hand-written list of
/// eight paths. Eight of thirteen, so five settings pages were unreachable
/// from the palette, and the list named a ninth (`network`) that has never
/// existed and rendered an empty page. Both are why it lives here now: one
/// builder, two readers, and a key with no label is a compile error.
List<HubNavigationItem> buildSettingsNavigationItems(AppLocalizations l10n) {
  return [
    for (final String key in HubRouteKeys.settingsSubItems)
      if (settingsSubItemLabel(key, l10n) case final String label)
        HubNavigationItem(
          key: key,
          label: label,
          icon: settingsSubItemIcon(key),
          subtitle: settingsSubItemSubtitle(key, l10n),
        ),
  ];
}
