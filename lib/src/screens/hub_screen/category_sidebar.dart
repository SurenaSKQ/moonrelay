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

import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Category Sidebar
// ─────────────────────────────────────────────────────────────────────────────

class HubCategorySidebar extends StatelessWidget {
  final List<HubCategory> categories;
  final int selectedIndex;
  final int selectedSubIndex;
  final Set<int> expanded;
  final void Function(int index) onCategoryTap;
  final void Function(int categoryIndex, int itemIndex) onSubItemTap;
  final void Function(int index) onExpansionToggle;

  const HubCategorySidebar({
    super.key,
    required this.categories,
    required this.selectedIndex,
    required this.selectedSubIndex,
    required this.expanded,
    required this.onCategoryTap,
    required this.onSubItemTap,
    required this.onExpansionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // On compact screens collapse to an icon-only rail; on medium use a
    // slimmer sidebar; otherwise default width.
    final layoutSize = LayoutScope.of(context).size;
    final width = switch (layoutSize) {
      LayoutSize.compact => LayoutBreakpoints.hubNavRailWidth,
      LayoutSize.medium => 200.0,
      _ => LayoutBreakpoints.hubCategorySidebarWidth,
    };
    final showLabels = layoutSize != LayoutSize.compact;
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          if (showLabels)
            Container(
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 10),
              child: Text(
                'Categories',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          if (showLabels) const Divider(height: 1),
          // Scrollable list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryTile(context, theme, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    ThemeData theme,
    int index,
  ) {
    final cat = categories[index];
    final layoutSize = LayoutScope.of(context).size;
    final compact = layoutSize == LayoutSize.compact;
    final bool isSelected =
        selectedIndex == index && (selectedSubIndex < 0 || !cat.isExpandable);
    final bool isExpanded = expanded.contains(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Category header ────────────────────────────────────────
        InkWell(
          onTap: cat.isExpandable
              ? () => onExpansionToggle(index)
              : () => onCategoryTap(index),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 8 : 16,
              vertical: compact ? 12 : 12,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : null,
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  cat.icon,
                  size: compact ? 22 : 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                if (!compact) const SizedBox(width: 12),
                if (!compact)
                  Expanded(
                    child: Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSelected
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (cat.isExpandable && !compact)
                  Icon(
                    isExpanded
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),

        // ── Sub-items (when expanded) ─────────────────────────────
        if (cat.isExpandable && isExpanded && !compact)
          ...List.generate(cat.items.length, (subIndex) {
            final subItem = cat.items[subIndex];
            final bool isSubSelected =
                selectedIndex == index && selectedSubIndex == subIndex;
            return InkWell(
              onTap: () => onSubItemTap(index, subIndex),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 52,
                  right: 16,
                  top: 10,
                  bottom: 10,
                ),
                decoration: BoxDecoration(
                  color: isSubSelected
                      ? theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.3)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      subItem.icon,
                      size: 16,
                      color: isSubSelected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    // Wrap the text in [Expanded] so long labels
                    // (e.g. localised "Notifications") wrap to two
                    // lines instead of overflowing the 132-px-wide
                    // sidebar row.
                    Expanded(
                      child: Text(
                        subItem.label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSubSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSubSelected
                              ? theme.colorScheme.secondary
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
