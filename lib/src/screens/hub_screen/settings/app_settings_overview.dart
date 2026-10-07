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

import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

// App Settings overview (when the category itself is selected)

/// The list of settings sections, for when the list is the only way in.
///
/// On the wide shell this page is a second copy of the sidebar beside it. That
/// is deliberate and it is the price of one set of destinations in two
/// arrangements: the sidebar is navigation and this is the thing you land on,
/// and a reader who has just tapped "App Settings" in a list of three should
/// land on a list of twelve rather than on a paragraph.
///
/// It used to draw each section as its own bordered `Card`, twelve boxes
/// stacked flush with no gap between them, using `theme.dividerColor` rather
/// than the app's hairline. Twelve separate boxes is the failure `InfoPanel`
/// exists to fix, and it was fixed everywhere else in the app except here.
/// They are one panel now, at the same measure as every page below it.
class HubAppSettingsOverview extends StatelessWidget {
  final List<HubNavigationItem> items;
  final void Function(int index) onItemTap;

  const HubAppSettingsOverview({
    super.key,
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    return HubPageBody(
      children: [
        InfoPanel(
          children: [
            for (var index = 0; index < items.length; index++)
              InfoPanelRow(
                icon: items[index].icon,
                label: items[index].label,
                onTap: () => onItemTap(index),
              ),
          ],
        ),
      ],
    );
  }
}
