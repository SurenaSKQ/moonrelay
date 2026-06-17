import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_service.dart';

/// A class that many Widgets can interact with to read user settings, update
/// user settings, or listen to user settings changes.
///
/// Controllers glue Data Services to Flutter Widgets. The SettingsController
/// uses the SettingsService to store and retrieve user settings.
class SettingsController with ChangeNotifier, WindowListener {
  final SettingsService _settingsService;
  late ThemeMode _themeMode;
  late MoonrelayThemeOption _themeOption;
  late DisplayType _displayType;
  // late AccentColor _accentColor;

  // Layout state
  late bool _leftSidebarVisible;
  late double _leftSidebarWidth;
  late LeftPaneChoice _leftPaneChoice;
  late bool _rightSidebarVisible;
  late double _rightSidebarWidth;
  late RightPaneChoice _rightPaneChoice;
  late bool _headerReversed;
  late bool _showStateEvents;
  late bool _showStatusBar;
  late bool _showTrayIcon;
  late bool _closeToTray;
  late bool _minimizeToTray;
  late bool _startMinimized;
  late Set<String> _pinnedSpaces;
  late List<String> _spaceOrder;
  late Set<String> _collapsedGroups;
  late Map<String, List<String>> _spaceGroups;
  late double _fontSize;
  late double _uiScale;
  SettingsController(this._settingsService);

  ThemeMode get themeMode => _themeMode;
  MoonrelayThemeOption get themeOption => _themeOption;
  DisplayType get displayType => _displayType;
  // AccentColor get accentColor => _accentColor;

  // Layout getters
  bool get leftSidebarVisible => _leftSidebarVisible;
  double get leftSidebarWidth => _leftSidebarWidth;
  LeftPaneChoice get leftPaneChoice => _leftPaneChoice;
  bool get rightSidebarVisible => _rightSidebarVisible;
  double get rightSidebarWidth => _rightSidebarWidth;
  RightPaneChoice get rightPaneChoice => _rightPaneChoice;
  bool get headerReversed => _headerReversed;
  bool get showStateEvents => _showStateEvents;
  bool get showStatusBar => _showStatusBar;
  bool get showTrayIcon => _showTrayIcon;
  bool get closeToTray => _closeToTray;
  bool get minimizeToTray => _minimizeToTray;
  bool get startMinimized => _startMinimized;
  Set<String> get pinnedSpaces => _pinnedSpaces;
  List<String> get spaceOrder => _spaceOrder;
  Set<String> get collapsedGroups => _collapsedGroups;
  Map<String, List<String>> get spaceGroups => _spaceGroups;
  double get fontSize => _fontSize;
  double get uiScale => _uiScale;
  Future<void> loadSettings() async {
    _themeMode = await _settingsService.themeMode();
    _themeOption = await _settingsService.themeOption();
    _displayType = await _settingsService.displayType();
    // _accentColor = await _settingsService.accentColor();

    // Layout settings
    _leftSidebarVisible = await _settingsService.leftSidebarVisible();
    _leftSidebarWidth = await _settingsService.leftSidebarWidth();
    _leftPaneChoice = await _settingsService.leftPaneChoice();
    _rightSidebarVisible = await _settingsService.rightSidebarVisible();
    _rightSidebarWidth = await _settingsService.rightSidebarWidth();
    _rightPaneChoice = await _settingsService.rightPaneChoice();
    _headerReversed = await _settingsService.headerReversed();
    _showStateEvents = await _settingsService.showStateEvents();
    _showStatusBar = await _settingsService.showStatusBar();
    _showTrayIcon = await _settingsService.showTrayIcon();
    _closeToTray = await _settingsService.closeToTray();
    _minimizeToTray = await _settingsService.minimizeToTray();
    _startMinimized = await _settingsService.startMinimized();
    _pinnedSpaces = await _settingsService.pinnedSpaces();
    _spaceOrder = await _settingsService.spaceOrder();
    _collapsedGroups = await _settingsService.collapsedGroups();
    _spaceGroups = await _settingsService.spaceGroups();
    _fontSize = await _settingsService.fontSize();
    _uiScale = await _settingsService.uiScale();
    notifyListeners();
  }

  // Future<void> updateAccentColor(AccentColor newAccentColor) async {
  //   if (newAccentColor != _accentColor) {
  //     _accentColor = newAccentColor;
  //     notifyListeners();
  //     await _settingsService.updateAccentColor(newAccentColor);
  //   }
  // }

  Future<void> updateThemeMode(ThemeMode newThemeMode) async {
    if (newThemeMode != _themeMode) {
      _themeMode = newThemeMode;
      notifyListeners();
      await _settingsService.updateThemeMode(newThemeMode);
    }
  }

  Future<void> updateThemeOption(MoonrelayThemeOption option) async {
    if (option != _themeOption) {
      _themeOption = option;
      notifyListeners();
      await _settingsService.updateThemeOption(option);
    }
  }

  Future<void> updateDisplayType(DisplayType newDisplayType) async {
    if (newDisplayType != _displayType) {
      _displayType = newDisplayType;
      notifyListeners();
      await _settingsService.updateDisplayType(newDisplayType);
    }
  }

  // ── Layout mutators ──────────────────────────────────────────────────

  Future<void> setLeftSidebarVisible(bool visible) async {
    if (visible != _leftSidebarVisible) {
      _leftSidebarVisible = visible;
      notifyListeners();
      await _settingsService.updateLeftSidebarVisible(visible);
    }
  }

  Future<void> setLeftSidebarWidth(double width) async {
    width = width.clamp(200.0, 600.0);
    if (width != _leftSidebarWidth) {
      _leftSidebarWidth = width;
      notifyListeners();
      await _settingsService.updateLeftSidebarWidth(width);
    }
  }

  Future<void> setLeftPaneChoice(LeftPaneChoice choice) async {
    if (choice != _leftPaneChoice) {
      _leftPaneChoice = choice;
      // Show the sidebar automatically if a non-none pane is selected
      if (choice != LeftPaneChoice.none && !_leftSidebarVisible) {
        _leftSidebarVisible = true;
        await _settingsService.updateLeftSidebarVisible(true);
      }
      if (choice == LeftPaneChoice.none && _leftSidebarVisible) {
        _leftSidebarVisible = false;
        await _settingsService.updateLeftSidebarVisible(false);
      }
      notifyListeners();
      await _settingsService.updateLeftPaneChoice(choice);
    }
  }

  Future<void> toggleLeftSidebar() async {
    await setLeftSidebarVisible(!_leftSidebarVisible);
  }

  Future<void> setRightSidebarVisible(bool visible) async {
    if (visible != _rightSidebarVisible) {
      _rightSidebarVisible = visible;
      notifyListeners();
      await _settingsService.updateRightSidebarVisible(visible);
    }
  }

  Future<void> setRightSidebarWidth(double width) async {
    width = width.clamp(200.0, 500.0);
    if (width != _rightSidebarWidth) {
      _rightSidebarWidth = width;
      notifyListeners();
      await _settingsService.updateRightSidebarWidth(width);
    }
  }

  Future<void> setRightPaneChoice(RightPaneChoice choice) async {
    if (choice != _rightPaneChoice) {
      _rightPaneChoice = choice;
      if (choice != RightPaneChoice.none && !_rightSidebarVisible) {
        _rightSidebarVisible = true;
        await _settingsService.updateRightSidebarVisible(true);
      }
      if (choice == RightPaneChoice.none && _rightSidebarVisible) {
        _rightSidebarVisible = false;
        await _settingsService.updateRightSidebarVisible(false);
      }
      notifyListeners();
      await _settingsService.updateRightPaneChoice(choice);
    }
  }

  Future<void> toggleRightSidebar() async {
    await setRightSidebarVisible(!_rightSidebarVisible);
  }

  Future<void> updateHeaderReversed(bool reversed) async {
    if (reversed != _headerReversed) {
      _headerReversed = reversed;
      notifyListeners();
      await _settingsService.updateHeaderReversed(reversed);
    }
  }

  Future<void> updateShowStateEvents(bool value) async {
    if (value != _showStateEvents) {
      _showStateEvents = value;
      notifyListeners();
      await _settingsService.updateShowStateEvents(value);
    }
  }

  Future<void> updateShowTrayIcon(bool value) async {
    if (value != _showTrayIcon) {
      _showTrayIcon = value;
      notifyListeners();
      await _settingsService.updateShowTrayIcon(value);
    }
  }

  Future<void> updateCloseToTray(bool value) async {
    if (value != _closeToTray) {
      _closeToTray = value;
      notifyListeners();
      await _settingsService.updateCloseToTray(value);
    }
  }

  Future<void> updateMinimizeToTray(bool value) async {
    if (value != _minimizeToTray) {
      _minimizeToTray = value;
      notifyListeners();
      await _settingsService.updateMinimizeToTray(value);
    }
  }

  Future<void> updateStartMinimized(bool value) async {
    if (value != _startMinimized) {
      _startMinimized = value;
      notifyListeners();
      await _settingsService.updateStartMinimized(value);
    }
  }

  Future<void> updateShowStatusBar(bool value) async {
    if (value != _showStatusBar) {
      _showStatusBar = value;
      notifyListeners();
      await _settingsService.updateShowStatusBar(value);
    }
  }

  // ── Pinned spaces ──────────────────────────────────────────────────

  /// Toggle whether [spaceId] is pinned in the navigation pane.
  Future<void> togglePinSpace(String spaceId) async {
    if (_pinnedSpaces.contains(spaceId)) {
      _pinnedSpaces.remove(spaceId);
    } else {
      _pinnedSpaces.add(spaceId);
    }
    notifyListeners();
    await _settingsService.updatePinnedSpaces(_pinnedSpaces);
  }

  /// Returns `true` if [spaceId] is pinned.
  bool isSpacePinned(String spaceId) => _pinnedSpaces.contains(spaceId);

  // ── Space order ──────────────────────────────────────────────────

  Future<void> setSpaceOrder(List<String> order) async {
    _spaceOrder = List.of(order);
    notifyListeners();
    await _settingsService.updateSpaceOrder(_spaceOrder);
  }

  // ── Collapsed groups ──────────────────────────────────────────────

  Future<void> toggleGroupCollapsed(String spaceId) async {
    if (_collapsedGroups.contains(spaceId)) {
      _collapsedGroups.remove(spaceId);
    } else {
      _collapsedGroups.add(spaceId);
    }
    notifyListeners();
    await _settingsService.updateCollapsedGroups(_collapsedGroups);
  }

  bool isGroupCollapsed(String spaceId) => _collapsedGroups.contains(spaceId);

  /// Creates a group identified by [groupId] containing [ids].
  Future<void> createGroup(String groupId, List<String> ids) async {
    // Prevent nesting: a group's children must not be other groups.
    ids = ids.where((id) => !id.startsWith('_grp_')).toList();
    // Deduplicate in case the same id was passed twice.
    ids = ids.toSet().toList();
    if (ids.isEmpty) return;
    // Remove each id from any existing group first.
    for (final id in ids) {
      _removeFromAllGroups(id);
    }
    _spaceGroups[groupId] = List.of(ids);
    for (final id in ids) {
      _spaceOrder.remove(id);
    }
    _spaceOrder.insert(0, groupId);
    notifyListeners();
    await _settingsService.updateSpaceGroups(_spaceGroups);
    await _settingsService.updateSpaceOrder(_spaceOrder);
  }

  /// Adds [spaceId] to an existing group.
  Future<void> addToGroup(String groupId, String spaceId) async {
    // Prevent nesting: refuse to add another group as a child.
    if (spaceId.startsWith('_grp_')) return;
    // Remove space from any existing group first (no multi-group).
    _removeFromAllGroups(spaceId);
    _spaceGroups[groupId] = [..._spaceGroups[groupId] ?? [], spaceId];
    _spaceOrder.remove(spaceId);
    notifyListeners();
    await _settingsService.updateSpaceGroups(_spaceGroups);
    await _settingsService.updateSpaceOrder(_spaceOrder);
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
    notifyListeners();
    await _settingsService.updateSpaceGroups(_spaceGroups);
    await _settingsService.updateSpaceOrder(_spaceOrder);
  }

  /// Moves [spaceId] up one position in the order.
  Future<void> moveUp(String spaceId) async {
    final idx = _spaceOrder.indexOf(spaceId);
    if (idx > 0) {
      _spaceOrder.removeAt(idx);
      _spaceOrder.insert(idx - 1, spaceId);
      notifyListeners();
      await _settingsService.updateSpaceOrder(_spaceOrder);
    }
  }

  /// Moves [spaceId] down one position in the order.
  Future<void> moveDown(String spaceId) async {
    final idx = _spaceOrder.indexOf(spaceId);
    if (idx >= 0 && idx < _spaceOrder.length - 1) {
      _spaceOrder.removeAt(idx);
      _spaceOrder.insert(idx + 1, spaceId);
      notifyListeners();
      await _settingsService.updateSpaceOrder(_spaceOrder);
    }
  }

  /// Runs auto‑grouping from the Matrix hierarchy.
  Future<void> sortIntoGroups(Map<String, List<String>> groups) async {
    _spaceGroups = Map.of(groups);
    final toRemove = <String>{};
    for (final children in groups.values) {
      toRemove.addAll(children);
    }
    for (final entry in groups.entries) {
      if (!_spaceOrder.contains(entry.key)) _spaceOrder.add(entry.key);
    }
    // Put group children after their group in the order
    final newOrder = <String>[];
    for (final id in _spaceOrder) {
      if (toRemove.contains(id)) continue;
      newOrder.add(id);
      // If this is a group, insert its children after it
      final children = groups[id];
      if (children != null) newOrder.addAll(children);
    }
    _spaceOrder = newOrder;
    notifyListeners();
    await _settingsService.updateSpaceGroups(_spaceGroups);
    await _settingsService.updateSpaceOrder(_spaceOrder);
  }

  /// Merges [groups] into existing groups without replacing them.
  Future<void> mergeIntoGroups(Map<String, List<String>> groups) async {
    bool changed = false;
    for (final e in groups.entries) {
      if (!_spaceGroups.containsKey(e.key)) {
        _spaceGroups[e.key] = List.of(e.value);
        if (!_spaceOrder.contains(e.key)) _spaceOrder.add(e.key);
        for (final cid in e.value) {
          _spaceOrder.removeWhere((id) => id == cid);
        }
        // Insert children right after the group in the order.
        final idx = _spaceOrder.indexOf(e.key);
        _spaceOrder.insertAll(idx + 1, e.value);
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
      await _settingsService.updateSpaceGroups(_spaceGroups);
      await _settingsService.updateSpaceOrder(_spaceOrder);
    }
  }

  Future<void> updateFontSize(double size) async {
    size = size.clamp(10.0, 28.0);
    if (size != _fontSize) {
      _fontSize = size;
      notifyListeners();
      await _settingsService.updateFontSize(size);
    }
  }

  Future<void> updateUiScale(double scale) async {
    scale = scale.clamp(0.7, 2.0);
    if (scale != _uiScale) {
      _uiScale = scale;
      notifyListeners();
      await _settingsService.updateUiScale(scale);
    }
  }

  /// Removes all groups and ordering, restoring the default flat layout.
  Future<void> resetSpaceLayout() async {
    _spaceGroups = {};
    _collapsedGroups = {};
    _spaceOrder = [];
    notifyListeners();
    await _settingsService.updateSpaceGroups(_spaceGroups);
    await _settingsService.updateCollapsedGroups(_collapsedGroups);
    await _settingsService.updateSpaceOrder(_spaceOrder);
  }
}
