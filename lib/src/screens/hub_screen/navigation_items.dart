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
