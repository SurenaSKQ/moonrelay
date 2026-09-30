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

// -----------------------------------------------------------------------------
// Route keys
// -----------------------------------------------------------------------------

/// The hub's stable route keys.
///
/// These are URL path segments, so they are declared here rather than being
/// spelled inline at each use site. Before the hub became a route the keys
/// were only ever compared inside one file, which is why
/// `palette_commands.dart` came to carry its own copy of nine `/hub/...`
/// path strings and one of them (`/hub/settings/network`) named a sub-item
/// that has never existed, rendering an empty page. Now that the hub is
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
  static const String layout = 'layout';
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

  static const List<String> settingsSubItems = <String>[
    appearance,
    layout,
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

  /// True when [key] names a real category.
  static bool isCategory(String? key) =>
      key != null && categories.contains(key);

  /// True when [key] names a real settings sub-item.
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

  const HubNavigationItem({
    this.key,
    required this.label,
    required this.icon,
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
