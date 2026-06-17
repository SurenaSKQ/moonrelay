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


import 'package:matrix/matrix.dart';

/// A model for the navigation pane's space list.
///
/// - `NavSpaceLeaf` is a single stand‑alone space icon.
/// - `NavSpaceGroup` is a user‑created group of spaces.
///
/// Groups are purely visual; the Matrix space‑child hierarchy is only
/// consulted when the user chooses "Sort into groups".

sealed class NavSpaceItem {
  NavSpaceItem(this.id);
  final String id;
}

class NavSpaceLeaf extends NavSpaceItem {
  NavSpaceLeaf({required this.space}) : super(space.id);
  final Room space;
}

class NavSpaceGroup extends NavSpaceItem {
  NavSpaceGroup({
    required this.groupId,
    required this.children,
    required this.isExpanded,
  }) : super(groupId);

  final String groupId;
  final List<NavSpaceLeaf> children;
  final bool isExpanded;
}

/// Builds the ordered list of [NavSpaceItem]s for the navigation pane.
///
/// All spaces appear as standalone leaves by default.  If [spaceGroups]
/// contains entries, they are rendered as groups containing the listed
/// spaces.  Spaces that belong to a group are removed from the flat list.
///
/// [order] controls the visual ordering (user‑defined).
/// [collapsedGroupIds] controls which groups are collapsed.
/// [knownSpaceIds] is used to detect newly‑joined spaces for auto‑grouping.
List<NavSpaceItem> buildNavItems(
  Iterable<Room> allRooms, {
  required Set<String> collapsedGroupIds,
  Map<String, List<String>> spaceGroups = const {},
  List<String> order = const [],
}) {
  final allSpaces = allRooms.where((r) => r.isSpace).toList();

  // Collect space IDs that are children of any group.
  final groupedIds = <String>{};
  for (final children in spaceGroups.values) {
    groupedIds.addAll(children);
  }

  final items = <NavSpaceItem>[];

  // 1. Add groups from user‑defined spaceGroups.
  for (final entry in spaceGroups.entries) {
    final groupId = entry.key;
    final childIds = entry.value;
    final children = childIds
        .map((cid) => allSpaces.where((s) => s.id == cid).firstOrNull)
        .nonNulls
        .map((r) => NavSpaceLeaf(space: r))
        .toList();
    if (children.isNotEmpty) {
      items.add(NavSpaceGroup(
        groupId: groupId,
        children: children,
        isExpanded: !collapsedGroupIds.contains(groupId),
      ));
    }
  }

  // 2. Add remaining spaces that aren't part of any group.
  for (final space in allSpaces) {
    if (!groupedIds.contains(space.id) && !spaceGroups.containsKey(space.id)) {
      items.add(NavSpaceLeaf(space: space));
    }
  }

  // 3. Sort by user order (order list contains both space IDs and group IDs).
  if (order.isNotEmpty) {
    final rank = <String, int>{};
    for (int i = 0; i < order.length; i++) {
      rank[order[i]] = i;
    }
    items.sort((a, b) => (rank[a.id] ?? 9999).compareTo(rank[b.id] ?? 9999));
  }

  return items;
}

/// Creates the auto‑grouping map for "Sort into groups".
///
/// For every root space (no joined parent) that has subspaces, a group entry
/// is created.  Subspaces are collected one level deep.
Map<String, List<String>> computeAutoGroups(Iterable<Room> allRooms) {
  final allSpaces = allRooms.where((r) => r.isSpace).toList();
  final joinedIds = allSpaces.map((s) => s.id).toSet();

  final result = <String, List<String>>{};

  for (final space in allSpaces) {
    if (!_isRoot(space, joinedIds)) continue;
    final children = _walkSubspaces(space, allSpaces);
    if (children.isNotEmpty) {
      result['_grp_${space.id}'] = children.map((s) => s.id).toList();
    }
  }

  return result;
}

List<Room> _walkSubspaces(Room space, List<Room> allSpaces) {
  final result = <Room>[];
  final seen = <String>{};
  void walk(Room parent) {
    for (final child in parent.spaceChildren) {
      final cid = child.roomId;
      if (cid == null || seen.contains(cid)) continue;
      seen.add(cid);
      final cr = allSpaces.where((s) => s.id == cid).firstOrNull;
      if (cr == null) continue;
      if (cr.isSpace) result.add(cr);
    }
  }

  walk(space);
  return result;
}

bool _isRoot(Room space, Set<String> joinedIds) {
  if (!space.isSpace) return false;
  for (final parent in space.spaceParents) {
    final pid = parent.roomId;
    if (pid != null && joinedIds.contains(pid)) return false;
  }
  return true;
}
