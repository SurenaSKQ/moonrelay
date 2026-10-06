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
import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// The hub's section list: App Settings, Accounts, About.
///
/// One widget, two presentations, because the hub has two arrangements of
/// the same information rather than two different sets of destinations. On a
/// wide window it is the sidebar beside the content; on a narrow one it is
/// the tail of the index page, below the profile. Same labels, same icons,
/// same routes, same order.
///
/// This replaces a horizontal tab strip that chose its own presentation by
/// counting tabs. That design had one mode for four sections and another
/// for the fourteen that "App Settings" expands to, which is why thirteen
/// settings pages had never been presented as a list: they were tabs, and
/// tabs run out of room long before lists do.
///
/// [expandActive] is the difference between the two arrangements. When the
/// hub has a sidebar beside it, the active section reveals its children
/// inline, so a settings sub-page is one tap from anywhere in the list. When
/// the hub is a stack of full-screen pages, revealing children inline would
/// be a list inside a list; there the sub-item list is itself a page, which
/// is what the index page's "App Settings" row leads to.
class HubNavList extends StatelessWidget {
  const HubNavList({
    super.key,
    required this.selectedCategory,
    this.selectedSubItem,
    this.expandActive = false,
    required this.onSelect,
  });

  /// The category currently showing in the content pane, or null for the
  /// index page (the profile).
  final String? selectedCategory;

  /// The settings sub-item currently showing, if any.
  final String? selectedSubItem;

  /// Whether [selectedCategory] should reveal its children inline.
  final bool expandActive;

  /// Called with the category and, for a settings sub-item, its key.
  final void Function(String category, String? subItem) onSelect;

  /// A stable key for one row.
  ///
  /// The rows are asserted on and tapped by tests, and finding them by label
  /// text is fragile: a section label also appears in the content pane's
  /// header and in the narrow index page's own layout, so a text finder can
  /// resolve to something that is not the row.
  static Key rowKey({required String category, String? subItem}) =>
      ValueKey<String>(
        subItem == null ? 'hubNav:$category' : 'hubNav:$category:$subItem',
      );

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    // The settings children come from [buildSettingsNavigationItems], the same
    // list the overview page and the sub-page titles read. This used to be a
    // hand-written third copy of all thirteen keys, beside the one in
    // `HubRouteKeys` and the one in the overview page, which is how a row came
    // to exist for a sub-item no page rendered: nothing could tell the three
    // apart.
    final List<_NavEntry> entries = [
      _NavEntry(
        category: HubRouteKeys.settings,
        label: l10n.appSettings,
        icon: LucideIcons.settings,
        children: [
          for (final item in buildSettingsNavigationItems(l10n))
            _NavEntry(
              category: HubRouteKeys.settings,
              sub: item.key,
              label: item.label,
            ),
        ],
      ),
      _NavEntry(
        category: HubRouteKeys.accounts,
        label: l10n.accounts,
        icon: LucideIcons.users,
      ),
      _NavEntry(
        category: HubRouteKeys.about,
        label: l10n.about,
        icon: LucideIcons.info,
      ),
    ];

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 4),
      children: [
        for (final _NavEntry entry in entries) ...[
          _NavRow(
            key: rowKey(category: entry.category),
            entry: entry,
            selected: entry.category == selectedCategory && entry.sub == null,
            showChevron: !expandActive && entry.children.isNotEmpty,
            onTap: () => onSelect(entry.category, null),
          ),
          if (expandActive &&
              entry.category == selectedCategory &&
              entry.children.isNotEmpty)
            for (final _NavEntry child in entry.children)
              _NavRow(
                key: rowKey(category: child.category, subItem: child.sub),
                entry: child,
                selected: entry.category == selectedCategory &&
                    child.sub == selectedSubItem,
                indented: true,
                onTap: () => onSelect(child.category, child.sub),
              ),
        ],
      ],
    );
  }
}

class _NavEntry {
  const _NavEntry({
    required this.category,
    required this.label,
    this.sub,
    this.icon,
    this.children = const [],
  });

  final String category;
  final String? sub;
  final String label;
  final IconData? icon;
  final List<_NavEntry> children;
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    super.key,
    required this.entry,
    required this.selected,
    required this.onTap,
    this.indented = false,
    this.showChevron = false,
  });

  final _NavEntry entry;
  final bool selected;
  final VoidCallback onTap;
  final bool indented;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final scheme = theme.colorScheme;
    final t = ext.tokens;
    final layers = ext.layers;

    return Semantics(
      // The previous tab entries had no semantics at all, so the only
      // indication of the active section was an underline. A list row
      // carries `selected` for free, which is the whole reason to move off
      // tabs.
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // The accent wash at 45% was a third use of the accent for
          // "selected", after the container fill and the text colour. Now the
          // row takes a step from the surface ramp like every other selected
          // row in the app, and the accent is left to the icon and the label
          // weight, which is what it is actually good at.
          color: selected ? layers.active : null,
          padding: EdgeInsets.only(
            left: indented ? t.spaceXl : t.spaceSm,
            right: t.spaceSm,
            top: t.spaceSm + 2,
            bottom: t.spaceSm + 2,
          ),
          child: Row(
            children: [
              // The rail's leading-edge indicator, reused so "selected" means
              // the same thing on every list in the app.
              if (selected)
                Container(
                  width: t.borderWidthThick * 2,
                  height: 20,
                  margin: EdgeInsets.only(right: t.spaceSm),
                  decoration: BoxDecoration(
                    color: scheme.primary,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                )
              else
                SizedBox(width: t.borderWidthThick * 2 + t.spaceSm),
              if (entry.icon != null) ...[
                Icon(
                  entry.icon,
                  size: t.iconSizeSmall + 2,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                ),
                SizedBox(width: t.spaceSm),
              ],
              Expanded(
                child: Text(
                  entry.label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    color: selected ? scheme.onSurface : scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (showChevron)
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: scheme.onSurfaceVariant
                      .withValues(alpha: t.opacityDisabled),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
