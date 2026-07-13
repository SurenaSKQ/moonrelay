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

import 'dart:async';

import 'package:flutter/foundation.dart';

import 'settings_service.dart';

/// Manages space hierarchy preferences: pinning, ordering, grouping,
/// collapsed state, and drag-reorder.
///
/// Extracted from [SettingsController] to keep that class focused on
/// theme, layout, and display preferences.
class SpacePreferences extends ChangeNotifier {
  SpacePreferences(this._settingsService);

  final SettingsService _settingsService;

  Set<String> _pinnedSpaces = {};
  List<String> _spaceOrder = [];
  Set<String> _collapsedGroups = {};
  Map<String, List<String>> _spaceGroups = {};

  Set<String> get pinnedSpaces => Set.unmodifiable(_pinnedSpaces);
  List<String> get spaceOrder => List.unmodifiable(_spaceOrder);
  Set<String> get collapsedGroups => Set.unmodifiable(_collapsedGroups);
  Map<String, List<String>> get spaceGroups =>
      Map.unmodifiable(_spaceGroups);

  /// Pending microtask used to coalesce a tight run of mutations
  /// (e.g. several drag-reorder steps in one frame) into a single
  /// [notifyListeners] call. The auto-grouping path can fire dozens
  /// of merges in a row; without coalescing every merge triggers a
  /// sidebar rebuild.
  bool _notifyScheduled = false;
  bool _disposed = false;
  void _scheduleNotify() {
    if (_notifyScheduled || _disposed) return;
    _notifyScheduled = true;
    scheduleMicrotask(() {
      _notifyScheduled = false;
      if (!_disposed) notifyListeners();
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  // ── Load / persist ──────────────────────────────────────────────────

  /// Load all space preferences from [SettingsService].
  Future<void> load() async {
    final snapshot = await _settingsService.loadAll();
    _pinnedSpaces = snapshot.pinnedSpaces.toSet();
    _spaceOrder = List.of(snapshot.spaceOrder);
    _collapsedGroups = snapshot.collapsedGroups.toSet();
    _spaceGroups = Map<String, List<String>>.from(snapshot.spaceGroups);
    _scheduleNotify();
  }

  Future<void> _save() async {
    await Future.wait([
      _settingsService.updatePinnedSpaces(_pinnedSpaces),
      _settingsService.updateSpaceOrder(_spaceOrder),
      _settingsService.updateCollapsedGroups(_collapsedGroups),
      _settingsService.updateSpaceGroups(_spaceGroups),
    ]);
  }

  // ── Pinning ─────────────────────────────────────────────────────────

  Future<void> togglePinSpace(String spaceId) async {
    if (spaceId.isEmpty) return;
    if (_pinnedSpaces.contains(spaceId)) {
      _pinnedSpaces.remove(spaceId);
    } else {
      _pinnedSpaces.add(spaceId);
    }
    _scheduleNotify();
    await _settingsService.updatePinnedSpaces(_pinnedSpaces);
  }

  bool isSpacePinned(String spaceId) => _pinnedSpaces.contains(spaceId);

  // ── Ordering ────────────────────────────────────────────────────────

  Future<void> updateSpaceOrder(List<String> order) async {
    if (order == _spaceOrder) return;
    _spaceOrder = List.of(order);
    _scheduleNotify();
    await _settingsService.updateSpaceOrder(_spaceOrder);
  }

  Future<void> moveUp(String id) async {
    final idx = _spaceOrder.indexOf(id);
    if (idx > 0) {
      _spaceOrder.removeAt(idx);
      _spaceOrder.insert(idx - 1, id);
      _scheduleNotify();
      await _settingsService.updateSpaceOrder(_spaceOrder);
    }
  }

  Future<void> moveDown(String id) async {
    final idx = _spaceOrder.indexOf(id);
    if (idx >= 0 && idx < _spaceOrder.length - 1) {
      _spaceOrder.removeAt(idx);
      _spaceOrder.insert(idx + 1, id);
      _scheduleNotify();
      await _settingsService.updateSpaceOrder(_spaceOrder);
    }
  }

  // ── Groups ──────────────────────────────────────────────────────────

  /// Merge new groups into the existing space groups map without
  /// overwriting existing entries.
  Future<void> mergeIntoGroups(Map<String, List<String>> groups) async {
    var changed = false;
    for (final entry in groups.entries) {
      if (_spaceGroups.containsKey(entry.key)) continue;
      _spaceGroups[entry.key] = entry.value;
      changed = true;
    }
    if (!changed) return;
    _scheduleNotify();
    await _settingsService.updateSpaceGroups(_spaceGroups);
  }

  /// Creates a group identified by [groupId] containing [ids].
  Future<void> createGroup(String groupId, List<String> ids) async {
    ids = ids.where((id) => !id.startsWith('_grp_')).toList();
    ids = ids.toSet().toList();
    if (ids.isEmpty) return;
    for (final id in ids) {
      _removeFromAllGroups(id);
    }
    _spaceGroups[groupId] = List.of(ids);
    for (final id in ids) {
      _spaceOrder.remove(id);
    }
    _spaceOrder.insert(0, groupId);
    _scheduleNotify();
    await _save();
  }

  /// Adds [spaceId] to an existing group.
  Future<void> addToGroup(String groupId, String spaceId) async {
    if (spaceId.startsWith('_grp_')) return;
    _removeFromAllGroups(spaceId);
    _spaceGroups[groupId] = [..._spaceGroups[groupId] ?? [], spaceId];
    _spaceOrder.remove(spaceId);
    _scheduleNotify();
    await _save();
  }

  /// Removes [spaceId] from every group it belongs to.
  void _removeFromAllGroups(String spaceId) {
    for (final entry in _spaceGroups.entries) {
      entry.value.remove(spaceId);
    }
    _spaceGroups.removeWhere((_, v) => v.isEmpty);
  }

  /// Removes [spaceId] from its group. Deletes the group if empty.
  Future<void> removeFromGroup(String spaceId) async {
    for (final entry in _spaceGroups.entries) {
      if (entry.value.contains(spaceId)) {
        entry.value.remove(spaceId);
        if (entry.value.isEmpty) {
          _spaceGroups.remove(entry.key);
          _spaceOrder.remove(entry.key);
        }
        if (!_spaceOrder.contains(spaceId)) {
          _spaceOrder.add(spaceId);
        }
        break;
      }
    }
    _scheduleNotify();
    await _save();
  }

  /// Removes every space in [ids] from whichever group they belong to.
  Future<void> removeMultipleFromGroups(List<String> ids) async {
    for (final id in ids) {
      for (final entry in _spaceGroups.entries) {
        entry.value.remove(id);
      }
    }
    _spaceGroups.removeWhere((_, v) => v.isEmpty);
    _scheduleNotify();
    await _save();
  }

  /// Runs auto-grouping from the Matrix hierarchy.
  Future<void> sortIntoGroups(Map<String, List<String>> groups) async {
    _spaceGroups = Map.of(groups);
    final toRemove = <String>{};
    for (final children in groups.values) {
      toRemove.addAll(children);
    }
    for (final entry in groups.entries) {
      if (!_spaceOrder.contains(entry.key)) _spaceOrder.add(entry.key);
    }
    final newOrder = <String>[];
    for (final id in _spaceOrder) {
      if (toRemove.contains(id)) continue;
      newOrder.add(id);
      final children = groups[id];
      if (children != null) newOrder.addAll(children);
    }
    _spaceOrder = newOrder;
    _scheduleNotify();
    await _save();
  }

  /// Resets space layout to the natural Matrix hierarchy.
  Future<void> resetSpaceLayout() async {
    _pinnedSpaces = {};
    _spaceOrder = [];
    _collapsedGroups = {};
    _spaceGroups = {};
    _scheduleNotify();
    await _save();
  }

  // ── Collapsed groups ────────────────────────────────────────────────

  Future<void> toggleGroupCollapsed(String spaceId) async {
    if (spaceId.isEmpty) return;
    if (_collapsedGroups.contains(spaceId)) {
      _collapsedGroups.remove(spaceId);
    } else {
      _collapsedGroups.add(spaceId);
    }
    _scheduleNotify();
    await _settingsService.updateCollapsedGroups(_collapsedGroups);
  }

  bool isGroupCollapsed(String spaceId) =>
      _collapsedGroups.contains(spaceId);
}

