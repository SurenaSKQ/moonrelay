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

import 'dart:convert';

import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// All persisted settings loaded in one batch.  Individual getters remain
/// available for granular reads after the initial load.
class SettingsSnapshot {
  final MoonrelayThemeOption themeOption;
  final ThemeMode themeMode;
  final DisplayType displayType;
  final LayoutMode layoutMode;
  final bool leftSidebarVisible;
  final double leftSidebarWidth;
  final LeftPaneChoice leftPaneChoice;
  final bool rightSidebarVisible;
  final double rightSidebarWidth;
  final RightPaneChoice rightPaneChoice;
  final bool headerReversed;
  final bool showStateEvents;
  final bool showStatusBar;
  final bool showTrayIcon;
  final bool closeToTray;
  final bool minimizeToTray;
  final bool startMinimized;
  final Set<String> pinnedSpaces;
  final List<String> spaceOrder;
  final Set<String> collapsedGroups;
  final Map<String, List<String>> spaceGroups;
  final double fontSize;
  final double uiScale;
  final bool notificationsEnabled;
  final bool enableAnimations;
  final LayoutDensity density;
  final double bubbleRadius;
  final String fontFamily;
  final String monoFontFamily;
  final double windowMinWidth;
  final double windowMinHeight;
  final bool sendReadReceipts;
  final bool sendTypingNotifications;
  final bool showTypingIndicator;
  final bool showReadReceipts;
  final bool linkPreviewsEnabled;
  final int replyPreviewThreshold;
  final int imageThumbnailMaxPx;
  final int stickerMaxPx;
  final int videoMaxPx;
  final int audioMaxPx;
  final int fileMaxPx;
  final int locationMaxPx;
  final int attachmentClickThresholdMb;
  final AutoDownloadPolicy autoDownloadImages;
  final AutoDownloadPolicy autoDownloadFiles;
  final AutoDownloadPolicy autoDownloadVideos;
  final SendShortcut sendShortcut;
  final bool draftsEnabled;
  final int draftRetentionDays;
  final bool notifyDmsOnly;
  final bool notifyWhenFocused;
  final bool notificationSoundEnabled;
  final int notificationDedupeCacheSize;
  final bool deepLinkAutoJoin;
  final bool dbWipeRequiresPrompt;
  final int dbBackupKeepCount;
  final int avatarCacheTtlDays;
  final bool autoLockEnabled;
  final int autoLockMinutes;
  final int syncDebounceMs;
  final int searchDebounceMs;
  final int draftAutosaveMs;
  final int notificationPersistMs;
  final int deepLinkDedupMs;
  final int firstSyncTimeoutS;
  final int encryptionRefreshDebounceMs;
  final int searchPageSize;
  final int logMaxFileSizeMb;
  final int logMaxFiles;
  final int logFlushDelayS;
  final LogLevel logLevel;
  final bool logVerboseRelease;
  final TrayClickAction trayLeftClick;
  final bool wipeLogsOnLogout;

  const SettingsSnapshot({
    this.themeOption = MoonrelayThemeOption.indigo,
    this.themeMode = ThemeMode.system,
    this.displayType = DisplayType.modern,
    this.layoutMode = LayoutMode.auto,
    this.leftSidebarVisible = true,
    this.leftSidebarWidth = 320.0,
    this.leftPaneChoice = LeftPaneChoice.rooms,
    this.rightSidebarVisible = true,
    this.rightSidebarWidth = 280.0,
    this.rightPaneChoice = RightPaneChoice.roomInfo,
    this.headerReversed = false,
    this.showStateEvents = true,
    this.showStatusBar = true,
    this.showTrayIcon = true,
    this.closeToTray = false,
    this.minimizeToTray = false,
    this.startMinimized = false,
    this.pinnedSpaces = const {},
    this.spaceOrder = const [],
    this.collapsedGroups = const {},
    this.spaceGroups = const {},
    this.fontSize = 16.0,
    this.uiScale = 1.0,
    this.notificationsEnabled = true,
    this.enableAnimations = true,
    this.density = LayoutDensity.comfortable,
    this.bubbleRadius = 12.0,
    this.fontFamily = 'Rubik',
    this.monoFontFamily = 'FiraCode',
    this.windowMinWidth = 500.0,
    this.windowMinHeight = 600.0,
    this.sendReadReceipts = true,
    this.sendTypingNotifications = true,
    this.showTypingIndicator = true,
    this.showReadReceipts = true,
    this.linkPreviewsEnabled = true,
    this.replyPreviewThreshold = 90,
    this.imageThumbnailMaxPx = 360,
    this.stickerMaxPx = 180,
    this.videoMaxPx = 360,
    this.audioMaxPx = 340,
    this.fileMaxPx = 360,
    this.locationMaxPx = 340,
    this.attachmentClickThresholdMb = 20,
    this.autoDownloadImages = AutoDownloadPolicy.wifi,
    this.autoDownloadFiles = AutoDownloadPolicy.never,
    this.autoDownloadVideos = AutoDownloadPolicy.never,
    this.sendShortcut = SendShortcut.cmdEnter,
    this.draftsEnabled = true,
    this.draftRetentionDays = 30,
    this.notifyDmsOnly = false,
    this.notifyWhenFocused = true,
    this.notificationSoundEnabled = true,
    this.notificationDedupeCacheSize = 256,
    this.deepLinkAutoJoin = false,
    this.dbWipeRequiresPrompt = false,
    this.dbBackupKeepCount = 1,
    this.avatarCacheTtlDays = 7,
    this.autoLockEnabled = false,
    this.autoLockMinutes = 0,
    this.syncDebounceMs = 350,
    this.searchDebounceMs = 300,
    this.draftAutosaveMs = 500,
    this.notificationPersistMs = 750,
    this.deepLinkDedupMs = 500,
    this.firstSyncTimeoutS = 8,
    this.encryptionRefreshDebounceMs = 750,
    this.searchPageSize = 100,
    this.logMaxFileSizeMb = 32,
    this.logMaxFiles = 0,
    this.logFlushDelayS = 120,
    this.logLevel = LogLevel.warning,
    this.logVerboseRelease = false,
    this.trayLeftClick = TrayClickAction.toggle,
    this.wipeLogsOnLogout = true,
  });
}

/// A service that stores and retrieves user settings.
class SettingsService {
  static const _themeModeKey = 'theme_mode';
  static const _themeOptionKey = 'theme_option';
  static const _displayTypeKey = 'display_type';
  static const _layoutModeKey = 'layout_mode';

  // Layout keys
  static const _leftSidebarVisibleKey = 'left_sidebar_visible';
  static const _leftSidebarWidthKey = 'left_sidebar_width';
  static const _leftPaneChoiceKey = 'left_pane_choice';
  static const _rightSidebarVisibleKey = 'right_sidebar_visible';
  static const _rightSidebarWidthKey = 'right_sidebar_width';
  static const _rightPaneChoiceKey = 'right_pane_choice';
  static const _headerReversedKey = 'header_reversed';
  static const _showStateEventsKey = 'show_state_events';
  static const _showStatusBarKey = 'show_status_bar';
  static const _showTrayIconKey = 'show_tray_icon';
  static const _closeToTrayKey = 'close_to_tray';
  static const _minimizeToTrayKey = 'minimize_to_tray';
  static const _startMinimizedKey = 'start_minimized';
  static const _pinnedSpacesKey = 'pinned_spaces';
  static const _spaceOrderKey = 'space_order';
  static const _collapsedGroupsKey = 'collapsed_groups';
  static const _spaceGroupsKey = 'space_groups';
  static const _fontSizeKey = 'font_size';
  static const _uiScaleKey = 'ui_scale';
  static const _notificationsEnabledKey = 'notifications_enabled';
  static const _enableAnimationsKey = 'enable_animations';

  // Appearance
  static const _densityKey = 'density';
  static const _bubbleRadiusKey = 'bubble_radius';
  static const _fontFamilyKey = 'font_family';
  static const _monoFontFamilyKey = 'mono_font_family';
  static const _windowMinWidthKey = 'window_min_width';
  static const _windowMinHeightKey = 'window_min_height';

  // Chat behaviour
  static const _sendReadReceiptsKey = 'send_read_receipts';
  static const _sendTypingNotificationsKey = 'send_typing_notifications';
  static const _showTypingIndicatorKey = 'show_typing_indicator';
  static const _showReadReceiptsKey = 'show_read_receipts';
  static const _linkPreviewsEnabledKey = 'link_previews_enabled';
  static const _replyPreviewThresholdKey = 'reply_preview_threshold';
  static const _imageThumbnailMaxPxKey = 'image_thumbnail_max_px';
  static const _stickerMaxPxKey = 'sticker_max_px';
  static const _videoMaxPxKey = 'video_max_px';
  static const _audioMaxPxKey = 'audio_max_px';
  static const _fileMaxPxKey = 'file_max_px';
  static const _locationMaxPxKey = 'location_max_px';
  static const _attachmentClickThresholdMbKey = 'attachment_click_threshold_mb';
  static const _autoDownloadImagesKey = 'auto_download_images';
  static const _autoDownloadFilesKey = 'auto_download_files';
  static const _autoDownloadVideosKey = 'auto_download_videos';
  static const _sendShortcutKey = 'send_shortcut';
  static const _draftsEnabledKey = 'drafts_enabled';
  static const _draftRetentionDaysKey = 'draft_retention_days';

  // Notifications
  static const _notifyDmsOnlyKey = 'notify_dms_only';
  static const _notifyWhenFocusedKey = 'notify_when_focused';
  static const _notificationSoundEnabledKey = 'notification_sound_enabled';
  static const _notificationDedupeCacheSizeKey =
      'notification_dedupe_cache_size';

  // Privacy / deep links / data
  static const _deepLinkAutoJoinKey = 'deep_link_auto_join';
  static const _dbWipeRequiresPromptKey = 'db_wipe_requires_prompt';
  static const _dbBackupKeepCountKey = 'db_backup_keep_count';
  static const _avatarCacheTtlDaysKey = 'avatar_cache_ttl_days';
  static const _autoLockEnabledKey = 'auto_lock_enabled';
  static const _autoLockMinutesKey = 'auto_lock_minutes';
  static const _wipeLogsOnLogoutKey = 'wipe_logs_on_logout';

  // Advanced / debounces
  static const _syncDebounceMsKey = 'sync_debounce_ms';
  static const _searchDebounceMsKey = 'search_debounce_ms';
  static const _draftAutosaveMsKey = 'draft_autosave_ms';
  static const _notificationPersistMsKey = 'notification_persist_ms';
  static const _deepLinkDedupMsKey = 'deep_link_dedup_ms';
  static const _firstSyncTimeoutSKey = 'first_sync_timeout_s';
  static const _encryptionRefreshDebounceMsKey =
      'encryption_refresh_debounce_ms';
  static const _searchPageSizeKey = 'search_page_size';

  // Logging
  static const _logMaxFileSizeMbKey = 'log_max_file_size_mb';
  static const _logMaxFilesKey = 'log_max_files';
  static const _logFlushDelaySKey = 'log_flush_delay_s';
  static const _logLevelKey = 'log_level';
  static const _logVerboseReleaseKey = 'log_verbose_release';

  // Tray
  static const _trayLeftClickKey = 'tray_left_click';

  Future<MoonrelayThemeOption> themeOption() async {
    final prefs = await SharedPreferences.getInstance();
    final int? index = prefs.getInt(_themeOptionKey);
    return index != null
        ? MoonrelayThemeOption.values[index]
        : MoonrelayThemeOption.indigo;
  }

  Future<void> updateThemeOption(MoonrelayThemeOption option) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeOptionKey, option.index);
  }

  Future<ThemeMode> themeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final int? themeIndex = prefs.getInt(_themeModeKey);
    return themeIndex != null ? ThemeMode.values[themeIndex] : ThemeMode.system;
  }

  Future<void> updateThemeMode(ThemeMode theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeModeKey, theme.index);
  }

  Future<DisplayType> displayType() async {
    final prefs = await SharedPreferences.getInstance();
    final int? typeIndex = prefs.getInt(_displayTypeKey);
    return typeIndex != null
        ? DisplayType.values[typeIndex]
        : DisplayType.modern;
  }

  Future<void> updateDisplayType(DisplayType displayType) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_displayTypeKey, displayType.index);
  }

  Future<LayoutMode> layoutMode() async {
    final prefs = await SharedPreferences.getInstance();
    final int? index = prefs.getInt(_layoutModeKey);
    return index != null ? LayoutMode.values[index] : LayoutMode.auto;
  }

  Future<void> updateLayoutMode(LayoutMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_layoutModeKey, mode.index);
  }

  // ── Batch load ────────────────────────────────────────────────────────

  /// Loads all settings in a single [SharedPreferences] read, returning a
  /// [SettingsSnapshot] with all keys populated.  This replaces the 27
  /// individual async getter calls used on startup.
  Future<SettingsSnapshot> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsSnapshot(
      themeOption: _readThemeOption(prefs),
      themeMode: _readThemeMode(prefs),
      displayType: _readDisplayType(prefs),
      layoutMode: _readLayoutMode(prefs),
      leftSidebarVisible: prefs.getBool(_leftSidebarVisibleKey) ?? true,
      leftSidebarWidth: prefs.getDouble(_leftSidebarWidthKey) ?? 320.0,
      leftPaneChoice: _readLeftPaneChoice(prefs),
      rightSidebarVisible: prefs.getBool(_rightSidebarVisibleKey) ?? true,
      rightSidebarWidth: prefs.getDouble(_rightSidebarWidthKey) ?? 280.0,
      rightPaneChoice: _readRightPaneChoice(prefs),
      headerReversed: prefs.getBool(_headerReversedKey) ?? false,
      showStateEvents: prefs.getBool(_showStateEventsKey) ?? true,
      showStatusBar: prefs.getBool(_showStatusBarKey) ?? true,
      showTrayIcon: prefs.getBool(_showTrayIconKey) ?? true,
      closeToTray: prefs.getBool(_closeToTrayKey) ?? false,
      minimizeToTray: prefs.getBool(_minimizeToTrayKey) ?? false,
      startMinimized: prefs.getBool(_startMinimizedKey) ?? false,
      pinnedSpaces: _readCommaSet(prefs, _pinnedSpacesKey),
      spaceOrder: _readCommaList(prefs, _spaceOrderKey),
      collapsedGroups: _readCommaSet(prefs, _collapsedGroupsKey),
      spaceGroups: _readSpaceGroups(prefs),
      fontSize: prefs.getDouble(_fontSizeKey) ?? 16.0,
      uiScale: prefs.getDouble(_uiScaleKey) ?? 1.0,
      notificationsEnabled: prefs.getBool(_notificationsEnabledKey) ?? true,
      enableAnimations: prefs.getBool(_enableAnimationsKey) ?? true,
      density: _readEnum<LayoutDensity>(
        prefs,
        _densityKey,
        LayoutDensity.values,
        LayoutDensity.comfortable,
      ),
      bubbleRadius: prefs.getDouble(_bubbleRadiusKey) ?? 12.0,
      fontFamily: prefs.getString(_fontFamilyKey) ?? 'Rubik',
      monoFontFamily: prefs.getString(_monoFontFamilyKey) ?? 'FiraCode',
      windowMinWidth: prefs.getDouble(_windowMinWidthKey) ?? 500.0,
      windowMinHeight: prefs.getDouble(_windowMinHeightKey) ?? 600.0,
      sendReadReceipts: prefs.getBool(_sendReadReceiptsKey) ?? true,
      sendTypingNotifications:
          prefs.getBool(_sendTypingNotificationsKey) ?? true,
      showTypingIndicator: prefs.getBool(_showTypingIndicatorKey) ?? true,
      showReadReceipts: prefs.getBool(_showReadReceiptsKey) ?? true,
      linkPreviewsEnabled: prefs.getBool(_linkPreviewsEnabledKey) ?? true,
      replyPreviewThreshold: prefs.getInt(_replyPreviewThresholdKey) ?? 90,
      imageThumbnailMaxPx: prefs.getInt(_imageThumbnailMaxPxKey) ?? 360,
      stickerMaxPx: prefs.getInt(_stickerMaxPxKey) ?? 180,
      videoMaxPx: prefs.getInt(_videoMaxPxKey) ?? 360,
      audioMaxPx: prefs.getInt(_audioMaxPxKey) ?? 340,
      fileMaxPx: prefs.getInt(_fileMaxPxKey) ?? 360,
      locationMaxPx: prefs.getInt(_locationMaxPxKey) ?? 340,
      attachmentClickThresholdMb:
          prefs.getInt(_attachmentClickThresholdMbKey) ?? 20,
      autoDownloadImages: _readEnum<AutoDownloadPolicy>(
        prefs,
        _autoDownloadImagesKey,
        AutoDownloadPolicy.values,
        AutoDownloadPolicy.wifi,
      ),
      autoDownloadFiles: _readEnum<AutoDownloadPolicy>(
        prefs,
        _autoDownloadFilesKey,
        AutoDownloadPolicy.values,
        AutoDownloadPolicy.never,
      ),
      autoDownloadVideos: _readEnum<AutoDownloadPolicy>(
        prefs,
        _autoDownloadVideosKey,
        AutoDownloadPolicy.values,
        AutoDownloadPolicy.never,
      ),
      sendShortcut: _readEnum<SendShortcut>(
        prefs,
        _sendShortcutKey,
        SendShortcut.values,
        SendShortcut.cmdEnter,
      ),
      draftsEnabled: prefs.getBool(_draftsEnabledKey) ?? true,
      draftRetentionDays: prefs.getInt(_draftRetentionDaysKey) ?? 30,
      notifyDmsOnly: prefs.getBool(_notifyDmsOnlyKey) ?? false,
      notifyWhenFocused: prefs.getBool(_notifyWhenFocusedKey) ?? true,
      notificationSoundEnabled:
          prefs.getBool(_notificationSoundEnabledKey) ?? true,
      notificationDedupeCacheSize:
          prefs.getInt(_notificationDedupeCacheSizeKey) ?? 256,
      deepLinkAutoJoin: prefs.getBool(_deepLinkAutoJoinKey) ?? false,
      dbWipeRequiresPrompt: prefs.getBool(_dbWipeRequiresPromptKey) ?? false,
      dbBackupKeepCount: prefs.getInt(_dbBackupKeepCountKey) ?? 1,
      avatarCacheTtlDays: prefs.getInt(_avatarCacheTtlDaysKey) ?? 7,
      autoLockEnabled: prefs.getBool(_autoLockEnabledKey) ?? false,
      autoLockMinutes: prefs.getInt(_autoLockMinutesKey) ?? 0,
      wipeLogsOnLogout: prefs.getBool(_wipeLogsOnLogoutKey) ?? true,
      syncDebounceMs: prefs.getInt(_syncDebounceMsKey) ?? 350,
      searchDebounceMs: prefs.getInt(_searchDebounceMsKey) ?? 300,
      draftAutosaveMs: prefs.getInt(_draftAutosaveMsKey) ?? 500,
      notificationPersistMs: prefs.getInt(_notificationPersistMsKey) ?? 750,
      deepLinkDedupMs: prefs.getInt(_deepLinkDedupMsKey) ?? 500,
      firstSyncTimeoutS: prefs.getInt(_firstSyncTimeoutSKey) ?? 8,
      encryptionRefreshDebounceMs:
          prefs.getInt(_encryptionRefreshDebounceMsKey) ?? 750,
      searchPageSize: prefs.getInt(_searchPageSizeKey) ?? 100,
      logMaxFileSizeMb: prefs.getInt(_logMaxFileSizeMbKey) ?? 32,
      logMaxFiles: prefs.getInt(_logMaxFilesKey) ?? 0,
      logFlushDelayS: prefs.getInt(_logFlushDelaySKey) ?? 120,
      logLevel: _readEnum<LogLevel>(
        prefs,
        _logLevelKey,
        LogLevel.values,
        LogLevel.warning,
      ),
      logVerboseRelease: prefs.getBool(_logVerboseReleaseKey) ?? false,
      trayLeftClick: _readEnum<TrayClickAction>(
        prefs,
        _trayLeftClickKey,
        TrayClickAction.values,
        TrayClickAction.toggle,
      ),
    );
  }

  static MoonrelayThemeOption _readThemeOption(SharedPreferences prefs) {
    final index = prefs.getInt(_themeOptionKey);
    return index != null
        ? MoonrelayThemeOption.values[index]
        : MoonrelayThemeOption.indigo;
  }

  static ThemeMode _readThemeMode(SharedPreferences prefs) {
    final index = prefs.getInt(_themeModeKey);
    return index != null ? ThemeMode.values[index] : ThemeMode.system;
  }

  static DisplayType _readDisplayType(SharedPreferences prefs) {
    final index = prefs.getInt(_displayTypeKey);
    return index != null ? DisplayType.values[index] : DisplayType.modern;
  }

  static LayoutMode _readLayoutMode(SharedPreferences prefs) {
    final index = prefs.getInt(_layoutModeKey);
    return index != null ? LayoutMode.values[index] : LayoutMode.auto;
  }

  static LeftPaneChoice _readLeftPaneChoice(SharedPreferences prefs) {
    final index = prefs.getInt(_leftPaneChoiceKey);
    return index != null ? LeftPaneChoice.values[index] : LeftPaneChoice.rooms;
  }

  static RightPaneChoice _readRightPaneChoice(SharedPreferences prefs) {
    final index = prefs.getInt(_rightPaneChoiceKey);
    return index != null
        ? RightPaneChoice.values[index]
        : RightPaneChoice.roomInfo;
  }

  static T _readEnum<T extends Enum>(
    SharedPreferences prefs,
    String key,
    List<T> values,
    T fallback,
  ) {
    final index = prefs.getInt(key);
    if (index == null) return fallback;
    if (index < 0 || index >= values.length) return fallback;
    return values[index];
  }

  static Set<String> _readCommaSet(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().where((s) => s.isNotEmpty).toSet();
      }
    } catch (_) {
      // Legacy comma-separated format — fall through.
    }
    return raw.split(',').where((id) => id.isNotEmpty).toSet();
  }

  static List<String> _readCommaList(SharedPreferences prefs, String key) {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.whereType<String>().where((s) => s.isNotEmpty).toList();
      }
    } catch (_) {
      // Legacy comma-separated format — fall through.
    }
    return raw.split(',').where((id) => id.isNotEmpty).toList();
  }

  static Map<String, List<String>> _readSpaceGroups(SharedPreferences prefs) {
    final raw = prefs.getString(_spaceGroupsKey);
    if (raw == null || raw.isEmpty) return {};
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final result = <String, List<String>>{};
        decoded.forEach((k, v) {
          if (k is String && v is List) {
            result[k] = v.whereType<String>().where((s) => s.isNotEmpty).toList();
          }
        });
        return result;
      }
    } catch (_) {
      // Legacy `key:value,key:value` format — fall through.
    }
    final map = <String, List<String>>{};
    for (final entry in raw.split('|')) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        map[parts[0]] =
            parts[1].split(',').where((id) => id.isNotEmpty).toList();
      }
    }
    return map;
  }

  // ── Layout settings ──────────────────────────────────────────────────

  Future<bool> leftSidebarVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_leftSidebarVisibleKey) ?? true;
  }

  Future<void> updateLeftSidebarVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_leftSidebarVisibleKey, visible);
  }

  Future<double> leftSidebarWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_leftSidebarWidthKey) ?? 320.0;
  }

  Future<void> updateLeftSidebarWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_leftSidebarWidthKey, width);
  }

  Future<LeftPaneChoice> leftPaneChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final int? index = prefs.getInt(_leftPaneChoiceKey);
    return index != null ? LeftPaneChoice.values[index] : LeftPaneChoice.rooms;
  }

  Future<void> updateLeftPaneChoice(LeftPaneChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_leftPaneChoiceKey, choice.index);
  }

  Future<bool> rightSidebarVisible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_rightSidebarVisibleKey) ?? true;
  }

  Future<void> updateRightSidebarVisible(bool visible) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_rightSidebarVisibleKey, visible);
  }

  Future<RightPaneChoice> rightPaneChoice() async {
    final prefs = await SharedPreferences.getInstance();
    final int? index = prefs.getInt(_rightPaneChoiceKey);
    return index != null
        ? RightPaneChoice.values[index]
        : RightPaneChoice.roomInfo;
  }

  Future<void> updateRightPaneChoice(RightPaneChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_rightPaneChoiceKey, choice.index);
  }

  Future<bool> headerReversed() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_headerReversedKey) ?? false;
  }

  Future<void> updateHeaderReversed(bool reversed) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_headerReversedKey, reversed);
  }

  Future<bool> showStateEvents() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showStateEventsKey) ?? true;
  }

  Future<void> updateShowStateEvents(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showStateEventsKey, value);
  }

  Future<bool> showStatusBar() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showStatusBarKey) ?? true;
  }

  Future<void> updateShowStatusBar(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showStatusBarKey, value);
  }

  // ── Tray & background ───────────────────────────────────────────────

  Future<bool> showTrayIcon() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showTrayIconKey) ?? true;
  }

  Future<void> updateShowTrayIcon(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTrayIconKey, value);
  }

  Future<bool> closeToTray() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_closeToTrayKey) ?? false;
  }

  Future<void> updateCloseToTray(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_closeToTrayKey, value);
  }

  Future<bool> minimizeToTray() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_minimizeToTrayKey) ?? false;
  }

  Future<void> updateMinimizeToTray(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_minimizeToTrayKey, value);
  }

  Future<bool> startMinimized() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_startMinimizedKey) ?? false;
  }

  Future<void> updateStartMinimized(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_startMinimizedKey, value);
  }

  // ── Pinned spaces ───────────────────────────────────────────────────

  /// Loads the set of manually pinned subspace room IDs.
  ///
  /// Stored as a JSON array of strings so room IDs that contain `,` or
  /// `|` are preserved verbatim.  A legacy comma-separated value is
  /// still accepted on read to make upgrades from older versions
  /// transparent.
  Future<Set<String>> pinnedSpaces() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_pinnedSpacesKey);
    if (raw == null || raw.isEmpty) return {};
    return _readCommaSet(prefs, _pinnedSpacesKey);
  }

  /// Persists the set of pinned subspace room IDs.
  Future<void> updatePinnedSpaces(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinnedSpacesKey, jsonEncode(ids.toList()));
  }

  // ── Space order ──────────────────────────────────────────────────────

  Future<List<String>> spaceOrder() async {
    final prefs = await SharedPreferences.getInstance();
    return _readCommaList(prefs, _spaceOrderKey);
  }

  Future<void> updateSpaceOrder(List<String> order) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_spaceOrderKey, jsonEncode(order));
  }

  // ── Collapsed groups ─────────────────────────────────────────────────

  Future<Set<String>> collapsedGroups() async {
    final prefs = await SharedPreferences.getInstance();
    return _readCommaSet(prefs, _collapsedGroupsKey);
  }

  Future<void> updateCollapsedGroups(Set<String> ids) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_collapsedGroupsKey, jsonEncode(ids.toList()));
  }

  // ── Space groups (Map<String, List<String>>) ─────────────────────────

  /// Persists the space groups map.  Stored as a JSON object so room IDs
  /// and event IDs that contain `,` or `|` are not corrupted by the
  /// previous stringly-typed encoding.
  Future<void> updateSpaceGroups(Map<String, List<String>> groups) async {
    final prefs = await SharedPreferences.getInstance();
    // Cast to Map<String, dynamic> for jsonEncode — the inner lists stay
    // as List<String> which jsonEncode accepts as a list of strings.
    final encoded = <String, dynamic>{
      for (final entry in groups.entries) entry.key: entry.value,
    };
    await prefs.setString(_spaceGroupsKey, jsonEncode(encoded));
  }

  Future<double> rightSidebarWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_rightSidebarWidthKey) ?? 280.0;
  }

  Future<void> updateRightSidebarWidth(double width) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_rightSidebarWidthKey, width);
  }

  // ── Font size & UI scale ──────────────────────────────────────────

  Future<double> fontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_fontSizeKey) ?? 16.0;
  }

  Future<void> updateFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_fontSizeKey, size);
  }

  Future<double> uiScale() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_uiScaleKey) ?? 1.0;
  }

  Future<void> updateUiScale(double scale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_uiScaleKey, scale);
  }

  // ── Notifications ───────────────────────────────────────────

  Future<bool> notificationsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationsEnabledKey) ?? true;
  }

  Future<void> updateNotificationsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsEnabledKey, value);
  }

  Future<bool> enableAnimations() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enableAnimationsKey) ?? true;
  }

  Future<void> updateEnableAnimations(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_enableAnimationsKey, value);
  }

  // ── Appearance extras ───────────────────────────────────────────────

  Future<LayoutDensity> density() async {
    final prefs = await SharedPreferences.getInstance();
    return _readEnum<LayoutDensity>(
      prefs,
      _densityKey,
      LayoutDensity.values,
      LayoutDensity.comfortable,
    );
  }

  Future<void> updateDensity(LayoutDensity value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_densityKey, value.index);
  }

  Future<double> bubbleRadius() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_bubbleRadiusKey) ?? 12.0;
  }

  Future<void> updateBubbleRadius(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_bubbleRadiusKey, value);
  }

  Future<String> fontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fontFamilyKey) ?? 'Rubik';
  }

  Future<void> updateFontFamily(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_fontFamilyKey, value);
  }

  Future<String> monoFontFamily() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_monoFontFamilyKey) ?? 'FiraCode';
  }

  Future<void> updateMonoFontFamily(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_monoFontFamilyKey, value);
  }

  Future<double> windowMinWidth() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_windowMinWidthKey) ?? 500.0;
  }

  Future<void> updateWindowMinWidth(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_windowMinWidthKey, value);
  }

  Future<double> windowMinHeight() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(_windowMinHeightKey) ?? 600.0;
  }

  Future<void> updateWindowMinHeight(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_windowMinHeightKey, value);
  }

  // ── Chat behaviour ──────────────────────────────────────────────────

  Future<bool> sendReadReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sendReadReceiptsKey) ?? true;
  }

  Future<void> updateSendReadReceipts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sendReadReceiptsKey, value);
  }

  Future<bool> sendTypingNotifications() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sendTypingNotificationsKey) ?? true;
  }

  Future<void> updateSendTypingNotifications(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sendTypingNotificationsKey, value);
  }

  Future<bool> showTypingIndicator() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showTypingIndicatorKey) ?? true;
  }

  Future<void> updateShowTypingIndicator(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showTypingIndicatorKey, value);
  }

  Future<bool> showReadReceipts() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_showReadReceiptsKey) ?? true;
  }

  Future<void> updateShowReadReceipts(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_showReadReceiptsKey, value);
  }

  Future<bool> linkPreviewsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_linkPreviewsEnabledKey) ?? true;
  }

  Future<void> updateLinkPreviewsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_linkPreviewsEnabledKey, value);
  }

  Future<int> replyPreviewThreshold() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_replyPreviewThresholdKey) ?? 90;
  }

  Future<void> updateReplyPreviewThreshold(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_replyPreviewThresholdKey, value);
  }

  Future<int> imageThumbnailMaxPx() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_imageThumbnailMaxPxKey) ?? 360;
  }

  Future<void> updateImageThumbnailMaxPx(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_imageThumbnailMaxPxKey, value);
  }

  Future<int> stickerMaxPx() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_stickerMaxPxKey) ?? 180;
  }

  Future<void> updateStickerMaxPx(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_stickerMaxPxKey, value);
  }

  Future<int> videoMaxPx() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_videoMaxPxKey) ?? 360;
  }

  Future<void> updateVideoMaxPx(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_videoMaxPxKey, value);
  }

  Future<int> audioMaxPx() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_audioMaxPxKey) ?? 340;
  }

  Future<void> updateAudioMaxPx(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_audioMaxPxKey, value);
  }

  Future<int> fileMaxPx() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_fileMaxPxKey) ?? 360;
  }

  Future<void> updateFileMaxPx(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_fileMaxPxKey, value);
  }

  Future<int> locationMaxPx() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_locationMaxPxKey) ?? 340;
  }

  Future<void> updateLocationMaxPx(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_locationMaxPxKey, value);
  }

  Future<int> attachmentClickThresholdMb() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_attachmentClickThresholdMbKey) ?? 20;
  }

  Future<void> updateAttachmentClickThresholdMb(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_attachmentClickThresholdMbKey, value);
  }

  Future<AutoDownloadPolicy> autoDownloadImages() async {
    final prefs = await SharedPreferences.getInstance();
    return _readEnum<AutoDownloadPolicy>(
      prefs,
      _autoDownloadImagesKey,
      AutoDownloadPolicy.values,
      AutoDownloadPolicy.wifi,
    );
  }

  Future<void> updateAutoDownloadImages(AutoDownloadPolicy value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoDownloadImagesKey, value.index);
  }

  Future<AutoDownloadPolicy> autoDownloadFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return _readEnum<AutoDownloadPolicy>(
      prefs,
      _autoDownloadFilesKey,
      AutoDownloadPolicy.values,
      AutoDownloadPolicy.never,
    );
  }

  Future<void> updateAutoDownloadFiles(AutoDownloadPolicy value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoDownloadFilesKey, value.index);
  }

  Future<AutoDownloadPolicy> autoDownloadVideos() async {
    final prefs = await SharedPreferences.getInstance();
    return _readEnum<AutoDownloadPolicy>(
      prefs,
      _autoDownloadVideosKey,
      AutoDownloadPolicy.values,
      AutoDownloadPolicy.never,
    );
  }

  Future<void> updateAutoDownloadVideos(AutoDownloadPolicy value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoDownloadVideosKey, value.index);
  }

  Future<SendShortcut> sendShortcut() async {
    final prefs = await SharedPreferences.getInstance();
    return _readEnum<SendShortcut>(
      prefs,
      _sendShortcutKey,
      SendShortcut.values,
      SendShortcut.cmdEnter,
    );
  }

  Future<void> updateSendShortcut(SendShortcut value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sendShortcutKey, value.index);
  }

  Future<bool> draftsEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_draftsEnabledKey) ?? true;
  }

  Future<void> updateDraftsEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_draftsEnabledKey, value);
  }

  Future<int> draftRetentionDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_draftRetentionDaysKey) ?? 30;
  }

  Future<void> updateDraftRetentionDays(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_draftRetentionDaysKey, value);
  }

  // ── Notifications (extended) ────────────────────────────────────────

  Future<bool> notifyDmsOnly() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifyDmsOnlyKey) ?? false;
  }

  Future<void> updateNotifyDmsOnly(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyDmsOnlyKey, value);
  }

  Future<bool> notifyWhenFocused() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notifyWhenFocusedKey) ?? true;
  }

  Future<void> updateNotifyWhenFocused(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notifyWhenFocusedKey, value);
  }

  Future<bool> notificationSoundEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_notificationSoundEnabledKey) ?? true;
  }

  Future<void> updateNotificationSoundEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationSoundEnabledKey, value);
  }

  Future<int> notificationDedupeCacheSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_notificationDedupeCacheSizeKey) ?? 256;
  }

  Future<void> updateNotificationDedupeCacheSize(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notificationDedupeCacheSizeKey, value);
  }

  // ── Privacy / deep links / data ─────────────────────────────────────

  Future<bool> deepLinkAutoJoin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_deepLinkAutoJoinKey) ?? false;
  }

  Future<void> updateDeepLinkAutoJoin(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_deepLinkAutoJoinKey, value);
  }

  Future<bool> dbWipeRequiresPrompt() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_dbWipeRequiresPromptKey) ?? false;
  }

  Future<void> updateDbWipeRequiresPrompt(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_dbWipeRequiresPromptKey, value);
  }

  Future<int> dbBackupKeepCount() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_dbBackupKeepCountKey) ?? 1;
  }

  Future<void> updateDbBackupKeepCount(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dbBackupKeepCountKey, value);
  }

  Future<int> avatarCacheTtlDays() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_avatarCacheTtlDaysKey) ?? 7;
  }

  Future<void> updateAvatarCacheTtlDays(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_avatarCacheTtlDaysKey, value);
  }

  Future<bool> autoLockEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoLockEnabledKey) ?? false;
  }

  Future<void> updateAutoLockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoLockEnabledKey, value);
  }

  Future<int> autoLockMinutes() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_autoLockMinutesKey) ?? 0;
  }

  Future<void> updateAutoLockMinutes(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_autoLockMinutesKey, value);
  }

  Future<bool> wipeLogsOnLogout() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_wipeLogsOnLogoutKey) ?? true;
  }

  Future<void> updateWipeLogsOnLogout(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_wipeLogsOnLogoutKey, value);
  }

  // ── Advanced / debounces ────────────────────────────────────────────

  Future<int> syncDebounceMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_syncDebounceMsKey) ?? 350;
  }

  Future<void> updateSyncDebounceMs(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_syncDebounceMsKey, value);
  }

  Future<int> searchDebounceMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_searchDebounceMsKey) ?? 300;
  }

  Future<void> updateSearchDebounceMs(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_searchDebounceMsKey, value);
  }

  Future<int> draftAutosaveMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_draftAutosaveMsKey) ?? 500;
  }

  Future<void> updateDraftAutosaveMs(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_draftAutosaveMsKey, value);
  }

  Future<int> notificationPersistMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_notificationPersistMsKey) ?? 750;
  }

  Future<void> updateNotificationPersistMs(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_notificationPersistMsKey, value);
  }

  Future<int> deepLinkDedupMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_deepLinkDedupMsKey) ?? 500;
  }

  Future<void> updateDeepLinkDedupMs(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_deepLinkDedupMsKey, value);
  }

  Future<int> firstSyncTimeoutS() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_firstSyncTimeoutSKey) ?? 8;
  }

  Future<void> updateFirstSyncTimeoutS(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_firstSyncTimeoutSKey, value);
  }

  Future<int> encryptionRefreshDebounceMs() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_encryptionRefreshDebounceMsKey) ?? 750;
  }

  Future<void> updateEncryptionRefreshDebounceMs(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_encryptionRefreshDebounceMsKey, value);
  }

  Future<int> searchPageSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_searchPageSizeKey) ?? 100;
  }

  Future<void> updateSearchPageSize(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_searchPageSizeKey, value);
  }

  // ── Logging ─────────────────────────────────────────────────────────

  Future<int> logMaxFileSizeMb() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_logMaxFileSizeMbKey) ?? 32;
  }

  Future<void> updateLogMaxFileSizeMb(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_logMaxFileSizeMbKey, value);
  }

  Future<int> logMaxFiles() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_logMaxFilesKey) ?? 0;
  }

  Future<void> updateLogMaxFiles(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_logMaxFilesKey, value);
  }

  Future<int> logFlushDelayS() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_logFlushDelaySKey) ?? 120;
  }

  Future<void> updateLogFlushDelayS(int value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_logFlushDelaySKey, value);
  }

  Future<LogLevel> logLevel() async {
    final prefs = await SharedPreferences.getInstance();
    return _readEnum<LogLevel>(
      prefs,
      _logLevelKey,
      LogLevel.values,
      LogLevel.warning,
    );
  }

  Future<void> updateLogLevel(LogLevel value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_logLevelKey, value.index);
  }

  Future<bool> logVerboseRelease() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_logVerboseReleaseKey) ?? false;
  }

  Future<void> updateLogVerboseRelease(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_logVerboseReleaseKey, value);
  }

  // ── Tray ────────────────────────────────────────────────────────────

  Future<TrayClickAction> trayLeftClick() async {
    final prefs = await SharedPreferences.getInstance();
    return _readEnum<TrayClickAction>(
      prefs,
      _trayLeftClickKey,
      TrayClickAction.values,
      TrayClickAction.toggle,
    );
  }

  Future<void> updateTrayLeftClick(TrayClickAction value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_trayLeftClickKey, value.index);
  }

  // ── Space groups ────────────────────────────────────────────────
  // (Persistence is centralised via the JSON-aware
  // [updateSpaceGroups] further up in this file, and reads go through
  // [_readSpaceGroups].  This section kept only the now-redundant
  // accessor for the legacy key; new callers should use the snapshot
  // path on [loadAll] instead.)
}
