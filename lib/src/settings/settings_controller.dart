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

import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/theme_spec.dart';
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
  ThemeMode _themeMode = ThemeMode.system;
  String _selectedThemeId = MoonrelayThemes.defaultThemeId;
  String _selectedAccentId = MoonrelayAccents.defaultAccentId;
  DisplayType _displayType = DisplayType.modern;

  // Layout state
  LayoutMode _layoutMode = LayoutMode.auto;
  bool _leftSidebarVisible = true;
  double _leftSidebarWidth = 320.0;
  bool _rightSidebarVisible = true;
  double _rightSidebarWidth = 280.0;
  RightPaneChoice _rightPaneChoice = RightPaneChoice.roomInfo;

  /// Ids of the navigation sidebar sections the user has collapsed
  /// (e.g. `spaces`, `rooms`).  Replaced (never mutated) so the same
  /// instance is returned until it actually changes, which keeps
  /// `context.select` rebuilds scoped to the sections state.
  Set<String> _collapsedSidebarSections = {};

  /// When true the OS provides the window title bar and caption buttons;
  /// when false Moonrelay renders its own slim header bar instead.
  bool _useOsTitleBar = true;
  bool _showStateEvents = true;
  bool _showStatusBar = true;
  bool _showTrayIcon = true;
  bool _closeToTray = false;
  bool _minimizeToTray = false;
  bool _startMinimized = false;
  double _fontSize = 16.0;
  double _uiScale = 1.0;
  bool _notificationsEnabled = true;
  bool _enableAnimations = true;

  // Appearance extras
  LayoutDensity _density = LayoutDensity.comfortable;
  double _bubbleRadius = 12.0;
  String _fontFamily = 'Rubik';
  String _monoFontFamily = 'FiraCode';
  double _windowMinWidth = 500.0;
  double _windowMinHeight = 600.0;

  // Chat behaviour
  bool _sendReadReceipts = true;
  bool _sendTypingNotifications = true;
  bool _showTypingIndicator = true;
  bool _showReadReceipts = true;
  bool _linkPreviewsEnabled = true;
  int _replyPreviewThreshold = 90;
  int _imageThumbnailMaxPx = 360;
  int _stickerMaxPx = 180;
  int _videoMaxPx = 360;
  int _audioMaxPx = 340;
  int _fileMaxPx = 360;
  int _locationMaxPx = 340;
  int _attachmentClickThresholdMb = 20;
  AutoDownloadPolicy _autoDownloadImages = AutoDownloadPolicy.wifi;
  AutoDownloadPolicy _autoDownloadFiles = AutoDownloadPolicy.never;
  AutoDownloadPolicy _autoDownloadVideos = AutoDownloadPolicy.never;
  SendShortcut _sendShortcut = SendShortcut.cmdEnter;
  bool _draftsEnabled = true;
  int _draftRetentionDays = 30;

  // Notifications (extended)
  bool _notifyDmsOnly = false;
  bool _notifyWhenFocused = true;
  bool _notificationSoundEnabled = true;
  int _notificationDedupeCacheSize = 256;

  // Privacy / deep links / data
  bool _deepLinkAutoJoin = false;
  bool _dbWipeRequiresPrompt = false;
  int _dbBackupKeepCount = 1;
  int _avatarCacheTtlDays = 7;
  bool _autoLockEnabled = false;
  int _autoLockMinutes = 0;
  bool _wipeLogsOnLogout = true;

  // Advanced / debounces
  int _syncDebounceMs = 350;
  int _searchDebounceMs = 300;
  int _draftAutosaveMs = 500;
  int _notificationPersistMs = 750;
  int _deepLinkDedupMs = 500;
  int _firstSyncTimeoutS = 8;
  int _encryptionRefreshDebounceMs = 750;
  int _searchPageSize = 100;

  // Logging
  int _logMaxFileSizeMb = 32;
  int _logMaxFiles = 0;
  int _logFlushDelayS = 120;
  LogLevel _logLevel = LogLevel.warning;
  bool _logVerboseRelease = false;

  // Tray
  TrayClickAction _trayLeftClick = TrayClickAction.toggle;

  // Updates
  bool _checkForUpdates = true;

  // Locale
  String? _locale;

  SettingsController(this._settingsService);

  ThemeMode get themeMode => _themeMode;

  /// The id of the active look theme. Use [selectedTheme] to resolve it back
  /// to a [MoonrelayThemeSpec].
  String get selectedThemeId => _selectedThemeId;

  /// The active look theme, resolved through the [MoonrelayThemes] registry
  /// (never null: an unknown id falls back to the default theme).
  MoonrelayThemeSpec get selectedTheme =>
      MoonrelayThemes.fromId(_selectedThemeId);

  /// The id of the active accent colour. Use [selectedAccent] to resolve it
  /// back to a [MoonrelayAccent].
  String get selectedAccentId => _selectedAccentId;

  /// The active accent, resolved through the [MoonrelayAccents] registry
  /// (never null: an unknown id falls back to the default accent).
  MoonrelayAccent get selectedAccent =>
      MoonrelayAccents.fromId(_selectedAccentId);
  DisplayType get displayType => _displayType;

  // Layout getters
  LayoutMode get layoutMode => _layoutMode;
  bool get leftSidebarVisible => _leftSidebarVisible;
  double get leftSidebarWidth => _leftSidebarWidth;
  bool get rightSidebarVisible => _rightSidebarVisible;
  double get rightSidebarWidth => _rightSidebarWidth;
  RightPaneChoice get rightPaneChoice => _rightPaneChoice;
  Set<String> get collapsedSidebarSections => _collapsedSidebarSections;
  bool get useOsTitleBar => _useOsTitleBar;
  bool get showStateEvents => _showStateEvents;
  bool get showStatusBar => _showStatusBar;
  bool get showTrayIcon => _showTrayIcon;
  bool get closeToTray => _closeToTray;
  bool get minimizeToTray => _minimizeToTray;
  bool get startMinimized => _startMinimized;
  double get fontSize => _fontSize;
  double get uiScale => _uiScale;
  bool get notificationsEnabled => _notificationsEnabled;
  bool get enableAnimations => _enableAnimations;

  // Appearance extras
  LayoutDensity get density => _density;
  double get bubbleRadius => _bubbleRadius;
  String get fontFamily => _fontFamily;
  String get monoFontFamily => _monoFontFamily;
  double get windowMinWidth => _windowMinWidth;
  double get windowMinHeight => _windowMinHeight;

  // Chat behaviour
  bool get sendReadReceipts => _sendReadReceipts;
  bool get sendTypingNotifications => _sendTypingNotifications;
  bool get showTypingIndicator => _showTypingIndicator;
  bool get showReadReceipts => _showReadReceipts;
  bool get linkPreviewsEnabled => _linkPreviewsEnabled;
  int get replyPreviewThreshold => _replyPreviewThreshold;
  int get imageThumbnailMaxPx => _imageThumbnailMaxPx;
  int get stickerMaxPx => _stickerMaxPx;
  int get videoMaxPx => _videoMaxPx;
  int get audioMaxPx => _audioMaxPx;
  int get fileMaxPx => _fileMaxPx;
  int get locationMaxPx => _locationMaxPx;
  int get attachmentClickThresholdMb => _attachmentClickThresholdMb;
  AutoDownloadPolicy get autoDownloadImages => _autoDownloadImages;
  AutoDownloadPolicy get autoDownloadFiles => _autoDownloadFiles;
  AutoDownloadPolicy get autoDownloadVideos => _autoDownloadVideos;
  SendShortcut get sendShortcut => _sendShortcut;
  bool get draftsEnabled => _draftsEnabled;
  int get draftRetentionDays => _draftRetentionDays;

  // Notifications (extended)
  bool get notifyDmsOnly => _notifyDmsOnly;
  bool get notifyWhenFocused => _notifyWhenFocused;
  bool get notificationSoundEnabled => _notificationSoundEnabled;
  int get notificationDedupeCacheSize => _notificationDedupeCacheSize;

  // Privacy / deep links / data
  bool get deepLinkAutoJoin => _deepLinkAutoJoin;
  bool get dbWipeRequiresPrompt => _dbWipeRequiresPrompt;
  int get dbBackupKeepCount => _dbBackupKeepCount;
  int get avatarCacheTtlDays => _avatarCacheTtlDays;
  bool get autoLockEnabled => _autoLockEnabled;
  int get autoLockMinutes => _autoLockMinutes;
  bool get wipeLogsOnLogout => _wipeLogsOnLogout;

  // Advanced / debounces
  int get syncDebounceMs => _syncDebounceMs;
  int get searchDebounceMs => _searchDebounceMs;
  int get draftAutosaveMs => _draftAutosaveMs;
  int get notificationPersistMs => _notificationPersistMs;
  int get deepLinkDedupMs => _deepLinkDedupMs;
  int get firstSyncTimeoutS => _firstSyncTimeoutS;
  int get encryptionRefreshDebounceMs => _encryptionRefreshDebounceMs;
  int get searchPageSize => _searchPageSize;

  // Logging
  int get logMaxFileSizeMb => _logMaxFileSizeMb;
  int get logMaxFiles => _logMaxFiles;
  int get logFlushDelayS => _logFlushDelayS;
  LogLevel get logLevel => _logLevel;
  bool get logVerboseRelease => _logVerboseRelease;

  // Tray
  TrayClickAction get trayLeftClick => _trayLeftClick;

  // Updates
  bool get checkForUpdates => _checkForUpdates;

  // Locale
  String? get locale => _locale;

  Future<void> loadSettings() async {
    final snapshot = await _settingsService.loadAll();
    _themeMode = snapshot.themeMode;
    _selectedThemeId = snapshot.selectedThemeId;
    _selectedAccentId = snapshot.selectedAccentId;
    _displayType = snapshot.displayType;

    // Layout settings
    _layoutMode = snapshot.layoutMode;
    _leftSidebarVisible = snapshot.leftSidebarVisible;
    _leftSidebarWidth = snapshot.leftSidebarWidth;
    _rightSidebarVisible = snapshot.rightSidebarVisible;
    _rightSidebarWidth = snapshot.rightSidebarWidth;
    _rightPaneChoice = snapshot.rightPaneChoice;
    _collapsedSidebarSections = snapshot.collapsedSidebarSections;
    _useOsTitleBar = snapshot.useOsTitleBar;
    _showStateEvents = snapshot.showStateEvents;
    _showStatusBar = snapshot.showStatusBar;
    _showTrayIcon = snapshot.showTrayIcon;
    _closeToTray = snapshot.closeToTray;
    _minimizeToTray = snapshot.minimizeToTray;
    _startMinimized = snapshot.startMinimized;
    _fontSize = snapshot.fontSize;
    _uiScale = snapshot.uiScale;
    _notificationsEnabled = snapshot.notificationsEnabled;
    _enableAnimations = snapshot.enableAnimations;

    _density = snapshot.density;
    _bubbleRadius = snapshot.bubbleRadius;
    _fontFamily = snapshot.fontFamily;
    _monoFontFamily = snapshot.monoFontFamily;
    _windowMinWidth = snapshot.windowMinWidth;
    _windowMinHeight = snapshot.windowMinHeight;

    _sendReadReceipts = snapshot.sendReadReceipts;
    _sendTypingNotifications = snapshot.sendTypingNotifications;
    _showTypingIndicator = snapshot.showTypingIndicator;
    _showReadReceipts = snapshot.showReadReceipts;
    _linkPreviewsEnabled = snapshot.linkPreviewsEnabled;
    _replyPreviewThreshold = snapshot.replyPreviewThreshold;
    _imageThumbnailMaxPx = snapshot.imageThumbnailMaxPx;
    _stickerMaxPx = snapshot.stickerMaxPx;
    _videoMaxPx = snapshot.videoMaxPx;
    _audioMaxPx = snapshot.audioMaxPx;
    _fileMaxPx = snapshot.fileMaxPx;
    _locationMaxPx = snapshot.locationMaxPx;
    _attachmentClickThresholdMb = snapshot.attachmentClickThresholdMb;
    _autoDownloadImages = snapshot.autoDownloadImages;
    _autoDownloadFiles = snapshot.autoDownloadFiles;
    _autoDownloadVideos = snapshot.autoDownloadVideos;
    _sendShortcut = snapshot.sendShortcut;
    _draftsEnabled = snapshot.draftsEnabled;
    _draftRetentionDays = snapshot.draftRetentionDays;

    _notifyDmsOnly = snapshot.notifyDmsOnly;
    _notifyWhenFocused = snapshot.notifyWhenFocused;
    _notificationSoundEnabled = snapshot.notificationSoundEnabled;
    _notificationDedupeCacheSize = snapshot.notificationDedupeCacheSize;

    _deepLinkAutoJoin = snapshot.deepLinkAutoJoin;
    _dbWipeRequiresPrompt = snapshot.dbWipeRequiresPrompt;
    _dbBackupKeepCount = snapshot.dbBackupKeepCount;
    _avatarCacheTtlDays = snapshot.avatarCacheTtlDays;
    _autoLockEnabled = snapshot.autoLockEnabled;
    _autoLockMinutes = snapshot.autoLockMinutes;
    _wipeLogsOnLogout = snapshot.wipeLogsOnLogout;

    _syncDebounceMs = snapshot.syncDebounceMs;
    _searchDebounceMs = snapshot.searchDebounceMs;
    _draftAutosaveMs = snapshot.draftAutosaveMs;
    _notificationPersistMs = snapshot.notificationPersistMs;
    _deepLinkDedupMs = snapshot.deepLinkDedupMs;
    _firstSyncTimeoutS = snapshot.firstSyncTimeoutS;
    _encryptionRefreshDebounceMs = snapshot.encryptionRefreshDebounceMs;
    _searchPageSize = snapshot.searchPageSize;

    _logMaxFileSizeMb = snapshot.logMaxFileSizeMb;
    _logMaxFiles = snapshot.logMaxFiles;
    _logFlushDelayS = snapshot.logFlushDelayS;
    _logLevel = snapshot.logLevel;
    _logVerboseRelease = snapshot.logVerboseRelease;

    _trayLeftClick = snapshot.trayLeftClick;

    _checkForUpdates = snapshot.checkForUpdates;

    _locale = snapshot.locale;

    notifyListeners();
  }

  Future<void> updateThemeMode(ThemeMode newThemeMode) async {
    if (newThemeMode != _themeMode) {
      _themeMode = newThemeMode;
      notifyListeners();
      await _settingsService.updateThemeMode(newThemeMode);
    }
  }

  /// Switches the active look theme to the one with [themeId].
  ///
  /// Selecting a theme resets the independent appearance controls that define
  /// the look (layout density, app font family, mono font family and chat
  /// bubble radius) to that theme's defaults, so the change redefines the
  /// entire look and feel rather than just its hue. The accent colour is left
  /// untouched: it continues to recolour the new theme's widgets.
  ///
  /// The resets are announced with a single [notifyListeners] call so the UI
  /// rebuilds once, and each reset value is persisted alongside the theme id.
  Future<void> updateSelectedTheme(String themeId) async {
    final theme = MoonrelayThemes.fromId(themeId);
    _selectedThemeId = theme.id;
    _density = theme.defaultDensity;
    _fontFamily = theme.defaultFontFamily;
    _monoFontFamily = theme.defaultMonoFontFamily;
    _bubbleRadius = theme.defaultBubbleRadius;
    notifyListeners();
    await Future.wait(<Future<void>>[
      _settingsService.updateSelectedTheme(theme.id),
      _settingsService.updateDensity(_density),
      _settingsService.updateFontFamily(_fontFamily),
      _settingsService.updateMonoFontFamily(_monoFontFamily),
      _settingsService.updateBubbleRadius(_bubbleRadius),
    ]);
  }

  /// Switches the active accent colour to the one with [accentId].
  ///
  /// Accents only recolo(u)r the current theme's widgets; they do not touch
  /// the look (fonts, density, corners), so no appearance controls are reset.
  Future<void> updateSelectedAccent(String accentId) async {
    final accent = MoonrelayAccents.fromId(accentId);
    _selectedAccentId = accent.id;
    notifyListeners();
    await _settingsService.updateSelectedAccent(accent.id);
  }

  Future<void> updateDisplayType(DisplayType newDisplayType) async {
    if (newDisplayType != _displayType) {
      _displayType = newDisplayType;
      notifyListeners();
      await _settingsService.updateDisplayType(newDisplayType);
    }
  }

  // -- Layout mutators --------------------------------------------------

  Future<void> setLayoutMode(LayoutMode mode) async {
    if (mode == _layoutMode) return;
    _layoutMode = mode;
    notifyListeners();
    await _settingsService.updateLayoutMode(mode);
  }

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
    if (choice == _rightPaneChoice) return;

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

  Future<void> toggleRightSidebar() async {
    await setRightSidebarVisible(!_rightSidebarVisible);
  }

  /// Collapses or expands the navigation sidebar section [id].
  ///
  /// The set is replaced with a copy so its identity changes only when
  /// the contents do; `context.select` consumers therefore rebuild only
  /// on real section changes, not on unrelated settings notifications.
  Future<void> setSidebarSectionCollapsed(String id, bool collapsed) async {
    final next = Set<String>.of(_collapsedSidebarSections);
    final changed = collapsed ? next.add(id) : next.remove(id);
    if (!changed) return;
    _collapsedSidebarSections = next;
    notifyListeners();
    await _settingsService.updateCollapsedSidebarSections(next);
  }

  Future<void> updateUseOsTitleBar(bool value) async {
    if (value != _useOsTitleBar) {
      _useOsTitleBar = value;
      notifyListeners();
      await _settingsService.updateUseOsTitleBar(value);
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

  Future<void> updateNotificationsEnabled(bool value) async {
    if (value != _notificationsEnabled) {
      _notificationsEnabled = value;
      notifyListeners();
      await _settingsService.updateNotificationsEnabled(value);
    }
  }

  Future<void> updateEnableAnimations(bool value) async {
    if (value != _enableAnimations) {
      _enableAnimations = value;
      notifyListeners();
      await _settingsService.updateEnableAnimations(value);
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

  // -- Appearance extras -----------------------------------------------

  Future<void> updateDensity(LayoutDensity value) async {
    if (value == _density) return;
    _density = value;
    notifyListeners();
    await _settingsService.updateDensity(value);
  }

  Future<void> updateBubbleRadius(double value) async {
    value = value.clamp(0.0, 24.0);
    if (value != _bubbleRadius) {
      _bubbleRadius = value;
      notifyListeners();
      await _settingsService.updateBubbleRadius(value);
    }
  }

  Future<void> updateFontFamily(String value) async {
    if (value == _fontFamily) return;
    _fontFamily = value;
    notifyListeners();
    await _settingsService.updateFontFamily(value);
  }

  Future<void> updateMonoFontFamily(String value) async {
    if (value == _monoFontFamily) return;
    _monoFontFamily = value;
    notifyListeners();
    await _settingsService.updateMonoFontFamily(value);
  }

  Future<void> updateWindowMinWidth(double value) async {
    value = value.clamp(320.0, 2000.0);
    if (value != _windowMinWidth) {
      _windowMinWidth = value;
      notifyListeners();
      await _settingsService.updateWindowMinWidth(value);
    }
  }

  Future<void> updateWindowMinHeight(double value) async {
    value = value.clamp(400.0, 2000.0);
    if (value != _windowMinHeight) {
      _windowMinHeight = value;
      notifyListeners();
      await _settingsService.updateWindowMinHeight(value);
    }
  }

  // -- Chat behaviour --------------------------------------------------

  Future<void> updateSendReadReceipts(bool value) async {
    if (value == _sendReadReceipts) return;
    _sendReadReceipts = value;
    notifyListeners();
    await _settingsService.updateSendReadReceipts(value);
  }

  Future<void> updateSendTypingNotifications(bool value) async {
    if (value == _sendTypingNotifications) return;
    _sendTypingNotifications = value;
    notifyListeners();
    await _settingsService.updateSendTypingNotifications(value);
  }

  Future<void> updateShowTypingIndicator(bool value) async {
    if (value == _showTypingIndicator) return;
    _showTypingIndicator = value;
    notifyListeners();
    await _settingsService.updateShowTypingIndicator(value);
  }

  Future<void> updateShowReadReceipts(bool value) async {
    if (value == _showReadReceipts) return;
    _showReadReceipts = value;
    notifyListeners();
    await _settingsService.updateShowReadReceipts(value);
  }

  Future<void> updateLinkPreviewsEnabled(bool value) async {
    if (value == _linkPreviewsEnabled) return;
    _linkPreviewsEnabled = value;
    notifyListeners();
    await _settingsService.updateLinkPreviewsEnabled(value);
  }

  Future<void> updateReplyPreviewThreshold(int value) async {
    value = value.clamp(20, 500);
    if (value != _replyPreviewThreshold) {
      _replyPreviewThreshold = value;
      notifyListeners();
      await _settingsService.updateReplyPreviewThreshold(value);
    }
  }

  Future<void> updateImageThumbnailMaxPx(int value) async {
    value = value.clamp(80, 1200);
    if (value != _imageThumbnailMaxPx) {
      _imageThumbnailMaxPx = value;
      notifyListeners();
      await _settingsService.updateImageThumbnailMaxPx(value);
    }
  }

  Future<void> updateStickerMaxPx(int value) async {
    value = value.clamp(80, 800);
    if (value != _stickerMaxPx) {
      _stickerMaxPx = value;
      notifyListeners();
      await _settingsService.updateStickerMaxPx(value);
    }
  }

  Future<void> updateVideoMaxPx(int value) async {
    value = value.clamp(80, 1200);
    if (value != _videoMaxPx) {
      _videoMaxPx = value;
      notifyListeners();
      await _settingsService.updateVideoMaxPx(value);
    }
  }

  Future<void> updateAudioMaxPx(int value) async {
    value = value.clamp(80, 1200);
    if (value != _audioMaxPx) {
      _audioMaxPx = value;
      notifyListeners();
      await _settingsService.updateAudioMaxPx(value);
    }
  }

  Future<void> updateFileMaxPx(int value) async {
    value = value.clamp(80, 1200);
    if (value != _fileMaxPx) {
      _fileMaxPx = value;
      notifyListeners();
      await _settingsService.updateFileMaxPx(value);
    }
  }

  Future<void> updateLocationMaxPx(int value) async {
    value = value.clamp(80, 1200);
    if (value != _locationMaxPx) {
      _locationMaxPx = value;
      notifyListeners();
      await _settingsService.updateLocationMaxPx(value);
    }
  }

  Future<void> updateAttachmentClickThresholdMb(int value) async {
    value = value.clamp(1, 2000);
    if (value != _attachmentClickThresholdMb) {
      _attachmentClickThresholdMb = value;
      notifyListeners();
      await _settingsService.updateAttachmentClickThresholdMb(value);
    }
  }

  Future<void> updateAutoDownloadImages(AutoDownloadPolicy value) async {
    if (value == _autoDownloadImages) return;
    _autoDownloadImages = value;
    notifyListeners();
    await _settingsService.updateAutoDownloadImages(value);
  }

  Future<void> updateAutoDownloadFiles(AutoDownloadPolicy value) async {
    if (value == _autoDownloadFiles) return;
    _autoDownloadFiles = value;
    notifyListeners();
    await _settingsService.updateAutoDownloadFiles(value);
  }

  Future<void> updateAutoDownloadVideos(AutoDownloadPolicy value) async {
    if (value == _autoDownloadVideos) return;
    _autoDownloadVideos = value;
    notifyListeners();
    await _settingsService.updateAutoDownloadVideos(value);
  }

  Future<void> updateSendShortcut(SendShortcut value) async {
    if (value == _sendShortcut) return;
    _sendShortcut = value;
    notifyListeners();
    await _settingsService.updateSendShortcut(value);
  }

  Future<void> updateDraftsEnabled(bool value) async {
    if (value == _draftsEnabled) return;
    _draftsEnabled = value;
    notifyListeners();
    await _settingsService.updateDraftsEnabled(value);
  }

  Future<void> updateDraftRetentionDays(int value) async {
    value = value.clamp(0, 365);
    if (value != _draftRetentionDays) {
      _draftRetentionDays = value;
      notifyListeners();
      await _settingsService.updateDraftRetentionDays(value);
    }
  }

  // -- Notifications (extended) ----------------------------------------

  Future<void> updateNotifyDmsOnly(bool value) async {
    if (value == _notifyDmsOnly) return;
    _notifyDmsOnly = value;
    notifyListeners();
    await _settingsService.updateNotifyDmsOnly(value);
  }

  Future<void> updateNotifyWhenFocused(bool value) async {
    if (value == _notifyWhenFocused) return;
    _notifyWhenFocused = value;
    notifyListeners();
    await _settingsService.updateNotifyWhenFocused(value);
  }

  Future<void> updateNotificationSoundEnabled(bool value) async {
    if (value == _notificationSoundEnabled) return;
    _notificationSoundEnabled = value;
    notifyListeners();
    await _settingsService.updateNotificationSoundEnabled(value);
  }

  Future<void> updateNotificationDedupeCacheSize(int value) async {
    value = value.clamp(0, 100000);
    if (value != _notificationDedupeCacheSize) {
      _notificationDedupeCacheSize = value;
      notifyListeners();
      await _settingsService.updateNotificationDedupeCacheSize(value);
    }
  }

  // -- Privacy / deep links / data -------------------------------------

  Future<void> updateDeepLinkAutoJoin(bool value) async {
    if (value == _deepLinkAutoJoin) return;
    _deepLinkAutoJoin = value;
    notifyListeners();
    await _settingsService.updateDeepLinkAutoJoin(value);
  }

  Future<void> updateDbWipeRequiresPrompt(bool value) async {
    if (value == _dbWipeRequiresPrompt) return;
    _dbWipeRequiresPrompt = value;
    notifyListeners();
    await _settingsService.updateDbWipeRequiresPrompt(value);
  }

  Future<void> updateDbBackupKeepCount(int value) async {
    value = value.clamp(0, 10);
    if (value != _dbBackupKeepCount) {
      _dbBackupKeepCount = value;
      notifyListeners();
      await _settingsService.updateDbBackupKeepCount(value);
    }
  }

  Future<void> updateAvatarCacheTtlDays(int value) async {
    value = value.clamp(0, 90);
    if (value != _avatarCacheTtlDays) {
      _avatarCacheTtlDays = value;
      notifyListeners();
      await _settingsService.updateAvatarCacheTtlDays(value);
    }
  }

  Future<void> updateAutoLockEnabled(bool value) async {
    if (value == _autoLockEnabled) return;
    _autoLockEnabled = value;
    notifyListeners();
    await _settingsService.updateAutoLockEnabled(value);
  }

  Future<void> updateAutoLockMinutes(int value) async {
    value = value.clamp(0, 24 * 60);
    if (value != _autoLockMinutes) {
      _autoLockMinutes = value;
      notifyListeners();
      await _settingsService.updateAutoLockMinutes(value);
    }
  }

  Future<void> updateWipeLogsOnLogout(bool value) async {
    if (value == _wipeLogsOnLogout) return;
    _wipeLogsOnLogout = value;
    notifyListeners();
    await _settingsService.updateWipeLogsOnLogout(value);
  }

  // -- Advanced / debounces --------------------------------------------

  Future<void> updateSyncDebounceMs(int value) async {
    value = value.clamp(0, 5000);
    if (value != _syncDebounceMs) {
      _syncDebounceMs = value;
      notifyListeners();
      await _settingsService.updateSyncDebounceMs(value);
    }
  }

  Future<void> updateSearchDebounceMs(int value) async {
    value = value.clamp(0, 5000);
    if (value != _searchDebounceMs) {
      _searchDebounceMs = value;
      notifyListeners();
      await _settingsService.updateSearchDebounceMs(value);
    }
  }

  Future<void> updateDraftAutosaveMs(int value) async {
    value = value.clamp(0, 10000);
    if (value != _draftAutosaveMs) {
      _draftAutosaveMs = value;
      notifyListeners();
      await _settingsService.updateDraftAutosaveMs(value);
    }
  }

  Future<void> updateNotificationPersistMs(int value) async {
    value = value.clamp(0, 5000);
    if (value != _notificationPersistMs) {
      _notificationPersistMs = value;
      notifyListeners();
      await _settingsService.updateNotificationPersistMs(value);
    }
  }

  Future<void> updateDeepLinkDedupMs(int value) async {
    value = value.clamp(0, 10000);
    if (value != _deepLinkDedupMs) {
      _deepLinkDedupMs = value;
      notifyListeners();
      await _settingsService.updateDeepLinkDedupMs(value);
    }
  }

  Future<void> updateFirstSyncTimeoutS(int value) async {
    value = value.clamp(1, 600);
    if (value != _firstSyncTimeoutS) {
      _firstSyncTimeoutS = value;
      notifyListeners();
      await _settingsService.updateFirstSyncTimeoutS(value);
    }
  }

  Future<void> updateEncryptionRefreshDebounceMs(int value) async {
    value = value.clamp(0, 10000);
    if (value != _encryptionRefreshDebounceMs) {
      _encryptionRefreshDebounceMs = value;
      notifyListeners();
      await _settingsService.updateEncryptionRefreshDebounceMs(value);
    }
  }

  Future<void> updateSearchPageSize(int value) async {
    value = value.clamp(10, 1000);
    if (value != _searchPageSize) {
      _searchPageSize = value;
      notifyListeners();
      await _settingsService.updateSearchPageSize(value);
    }
  }

  // -- Logging ---------------------------------------------------------

  Future<void> updateLogMaxFileSizeMb(int value) async {
    value = value.clamp(1, 1024);
    if (value != _logMaxFileSizeMb) {
      _logMaxFileSizeMb = value;
      notifyListeners();
      await _settingsService.updateLogMaxFileSizeMb(value);
    }
  }

  Future<void> updateLogMaxFiles(int value) async {
    value = value.clamp(0, 50);
    if (value != _logMaxFiles) {
      _logMaxFiles = value;
      notifyListeners();
      await _settingsService.updateLogMaxFiles(value);
    }
  }

  Future<void> updateLogFlushDelayS(int value) async {
    value = value.clamp(1, 600);
    if (value != _logFlushDelayS) {
      _logFlushDelayS = value;
      notifyListeners();
      await _settingsService.updateLogFlushDelayS(value);
    }
  }

  Future<void> updateLogLevel(LogLevel value) async {
    if (value == _logLevel) return;
    _logLevel = value;
    notifyListeners();
    await _settingsService.updateLogLevel(value);
  }

  Future<void> updateLogVerboseRelease(bool value) async {
    if (value == _logVerboseRelease) return;
    _logVerboseRelease = value;
    notifyListeners();
    await _settingsService.updateLogVerboseRelease(value);
  }

  // -- Tray ------------------------------------------------------------

  Future<void> updateTrayLeftClick(TrayClickAction value) async {
    if (value == _trayLeftClick) return;
    _trayLeftClick = value;
    notifyListeners();
    await _settingsService.updateTrayLeftClick(value);
  }

  // -- Updates ----------------------------------------------------------

  Future<void> updateCheckForUpdates(bool value) async {
    if (value == _checkForUpdates) return;
    _checkForUpdates = value;
    notifyListeners();
    await _settingsService.updateCheckForUpdates(value);
  }

  // -- Locale ----------------------------------------------------------

  Future<void> updateLocale(String? locale) async {
    if (locale == _locale) return;
    _locale = locale;
    notifyListeners();
    await _settingsService.updateLocale(locale);
  }
}
