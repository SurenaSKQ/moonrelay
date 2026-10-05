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

import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/settings/accents.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:flutter/material.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane_tab.dart';
import 'package:window_manager/window_manager.dart';

import 'settings_service.dart';

/// App-wide user settings: theme, accent, layout, sidebar geometry,
/// and misc preferences. Notifies listeners on every change so widgets can
/// rebuild off `context.watch<SettingsController>()`.
///
/// Persistence goes through [SettingsService]; values are cached in memory
/// after [loadSettings] and written back eagerly by the individual setters.
class SettingsController with ChangeNotifier, WindowListener {
  final SettingsService _settingsService;
  ThemeMode _themeMode = ThemeMode.system;
  String _selectedAccentId = MoonrelayAccents.defaultAccentId;
  DisplayType _displayType = DisplayType.modern;

  // Layout state
  LayoutMode _layoutMode = LayoutMode.auto;
  double _leftSidebarWidth = LayoutBreakpoints.defaultLeftSidebarWidth;
  double _roomPaneWidth = 280.0;
  RoomPaneTab _roomPaneTab = RoomPaneTab.info;

  bool _showStateEvents = true;
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
  int _dbBackupKeepCount = 1;
  bool _autoOfflinePresenceEnabled = false;
  int _autoOfflinePresenceMinutes = 0;
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
  double get leftSidebarWidth => _leftSidebarWidth;
  double get roomPaneWidth => _roomPaneWidth;
  RoomPaneTab get roomPaneTab => _roomPaneTab;
  bool get showStateEvents => _showStateEvents;
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
  int get dbBackupKeepCount => _dbBackupKeepCount;
  bool get autoOfflinePresenceEnabled => _autoOfflinePresenceEnabled;
  int get autoOfflinePresenceMinutes => _autoOfflinePresenceMinutes;
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
    // Normalised on load rather than on read. The accents were renamed to
    // lunar names, and the picker compares `accent.id == selectedAccentId`, so
    // a stale id in storage would resolve to the right *colour* through
    // `fromId` and then light up no radio button at all. Resolving once here
    // means `selectedAccentId` only ever holds a current id.
    _selectedAccentId = MoonrelayAccents.fromId(snapshot.selectedAccentId).id;
    _displayType = snapshot.displayType;

    // Layout settings
    _layoutMode = snapshot.layoutMode;
    _leftSidebarWidth = snapshot.leftSidebarWidth;
    _roomPaneWidth = snapshot.roomPaneWidth;
    _roomPaneTab = snapshot.roomPaneTab;
    _showStateEvents = snapshot.showStateEvents;
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
    _dbBackupKeepCount = snapshot.dbBackupKeepCount;
    _autoOfflinePresenceEnabled = snapshot.autoOfflinePresenceEnabled;
    _autoOfflinePresenceMinutes = snapshot.autoOfflinePresenceMinutes;
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

  /// Switches the active accent colour to the one with [accentId].
  ///
  /// Accents only recolor the widgets; they never touch the app's geometry
  /// (fonts, density, corners), so no appearance controls are reset.
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

  Future<void> setLeftSidebarWidth(double width) async {
    width = width.clamp(200.0, 600.0);
    if (width != _leftSidebarWidth) {
      _leftSidebarWidth = width;
      notifyListeners();
      await _settingsService.updateLeftSidebarWidth(width);
    }
  }

  /// Sets the room pane's width, clamped to the range the drag handle allows.
  ///
  /// A preference rather than a piece of activation config: the pane opens
  /// from the room it belongs to, but how wide someone likes it beside the
  /// conversation is theirs to keep.
  Future<void> setRoomPaneWidth(double width) async {
    width = width.clamp(200.0, 500.0);
    if (width != _roomPaneWidth) {
      _roomPaneWidth = width;
      notifyListeners();
      await _settingsService.updateRoomPaneWidth(width);
    }
  }

  /// Sets which tab the room pane opens on.
  ///
  /// This does not open the pane. Whether it is open is `RoomPage`'s state;
  /// this is which tab it opens on.
  ///
  /// It used to also flip a visibility flag, which made the two inseparable:
  /// choosing a tab turned the pane on, and choosing `none` turned it off, in
  /// one call, from two different places. Activation is contextual now, so
  /// there is no flag to keep in step with anything.
  Future<void> setRoomPaneTab(RoomPaneTab tab) async {
    final RoomPaneTab restorable = tab.restorableAs;
    if (restorable == _roomPaneTab) return;
    _roomPaneTab = restorable;
    notifyListeners();
    await _settingsService.updateRoomPaneTab(restorable);
  }

  /// Collapses or expands the navigation sidebar section [id].
  ///
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

  /// Sets the in-memory notification dedupe cache size.
  ///
  /// Clamped to at least 1, not 0: the cache is what stops the same event
  /// raising two notifications inside one boot, and a limit of 0 would
  /// evict the entry the instant it was inserted, leaving the control
  /// looking configured while the dedupe does nothing. The on-disk
  /// last-notified map is the cross-boot backstop, but it only records
  /// per-room read markers, so it cannot cover every duplicate.
  Future<void> updateNotificationDedupeCacheSize(int value) async {
    value = value.clamp(1, 100000);
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

  Future<void> updateDbBackupKeepCount(int value) async {
    value = value.clamp(0, 10);
    if (value != _dbBackupKeepCount) {
      _dbBackupKeepCount = value;
      notifyListeners();
      await _settingsService.updateDbBackupKeepCount(value);
    }
  }

  Future<void> updateAutoOfflinePresenceEnabled(bool value) async {
    if (value == _autoOfflinePresenceEnabled) return;
    _autoOfflinePresenceEnabled = value;
    notifyListeners();
    await _settingsService.updateAutoOfflinePresenceEnabled(value);
  }

  /// Sets the idle window, in minutes, before the account is marked offline.
  ///
  /// Clamped to start at 1 rather than 0: turning the toggle on without
  /// touching the slider would otherwise mean "go offline on every
  /// activity gap", with no way back in.
  Future<void> updateAutoOfflinePresenceMinutes(int value) async {
    value = value.clamp(1, 24 * 60);
    if (value != _autoOfflinePresenceMinutes) {
      _autoOfflinePresenceMinutes = value;
      notifyListeners();
      await _settingsService.updateAutoOfflinePresenceMinutes(value);
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
