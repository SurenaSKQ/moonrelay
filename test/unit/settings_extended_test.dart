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

import 'package:flutter_test/flutter_test.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/media_size_prefs.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/settings_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('LayoutDensity', () {
    test('has exactly two values', () {
      expect(LayoutDensity.values, hasLength(2));
      expect(LayoutDensity.values, contains(LayoutDensity.comfortable));
      expect(LayoutDensity.values, contains(LayoutDensity.compact));
    });
  });

  group('AutoDownloadPolicy', () {
    test('has exactly three values', () {
      expect(AutoDownloadPolicy.values, hasLength(3));
      expect(AutoDownloadPolicy.values, containsAll(<AutoDownloadPolicy>[
        AutoDownloadPolicy.always,
        AutoDownloadPolicy.wifi,
        AutoDownloadPolicy.never,
      ]));
    });
  });

  group('SendShortcut', () {
    test('has exactly three values', () {
      expect(SendShortcut.values, hasLength(3));
    });
  });

  group('TrayClickAction', () {
    test('has exactly three values', () {
      expect(TrayClickAction.values, hasLength(3));
    });
  });

  group('LogLevel', () {
    test('has the expected severity ladder', () {
      expect(LogLevel.values, <LogLevel>[
        LogLevel.all,
        LogLevel.trace,
        LogLevel.debug,
        LogLevel.info,
        LogLevel.warning,
        LogLevel.error,
        LogLevel.fatal,
      ]);
    });
  });

  group('MediaSizePrefs.defaults', () {
    test('exposes the historical hard-coded values', () {
      expect(MediaSizePrefs.defaults.imageThumbnailMax, 360);
      expect(MediaSizePrefs.defaults.stickerMax, 180);
      expect(MediaSizePrefs.defaults.videoMax, 360);
      expect(MediaSizePrefs.defaults.audioMax, 360);
      expect(MediaSizePrefs.defaults.fileMax, 340);
      expect(MediaSizePrefs.defaults.locationMax, 360);
    });
  });

  group('SettingsService.loadAll', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('returns the documented defaults on a fresh install', () async {
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.density, LayoutDensity.comfortable);
      expect(snapshot.bubbleRadius, 12.0);
      expect(snapshot.windowMinWidth, 500.0);
      expect(snapshot.windowMinHeight, 600.0);
      expect(snapshot.sendReadReceipts, isTrue);
      expect(snapshot.showTypingIndicator, isTrue);
      expect(snapshot.linkPreviewsEnabled, isTrue);
      expect(snapshot.replyPreviewThreshold, 90);
      expect(snapshot.autoDownloadImages, AutoDownloadPolicy.wifi);
      expect(snapshot.autoDownloadFiles, AutoDownloadPolicy.never);
      expect(snapshot.sendShortcut, SendShortcut.cmdEnter);
      expect(snapshot.draftsEnabled, isTrue);
      expect(snapshot.draftRetentionDays, 30);
      expect(snapshot.deepLinkAutoJoin, isFalse);
      expect(snapshot.dbWipeRequiresPrompt, isFalse);
      expect(snapshot.syncDebounceMs, 350);
      expect(snapshot.searchDebounceMs, 300);
      expect(snapshot.firstSyncTimeoutS, 8);
      expect(snapshot.logMaxFileSizeMb, 32);
      expect(snapshot.logLevel, LogLevel.warning);
      expect(snapshot.trayLeftClick, TrayClickAction.toggle);
      expect(snapshot.wipeLogsOnLogout, isTrue);
    });

    test('reads persisted values back', () async {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'density': LayoutDensity.compact.index,
        'bubble_radius': 20.0,
        'send_read_receipts': false,
        'auto_download_images': AutoDownloadPolicy.always.index,
        'sync_debounce_ms': 1234,
        'log_level': LogLevel.debug.index,
        'tray_left_click': TrayClickAction.openUnread.index,
        'draft_retention_days': 7,
      });
      final snapshot = await SettingsService().loadAll();
      expect(snapshot.density, LayoutDensity.compact);
      expect(snapshot.bubbleRadius, 20.0);
      expect(snapshot.sendReadReceipts, isFalse);
      expect(snapshot.autoDownloadImages, AutoDownloadPolicy.always);
      expect(snapshot.syncDebounceMs, 1234);
      expect(snapshot.logLevel, LogLevel.debug);
      expect(snapshot.trayLeftClick, TrayClickAction.openUnread);
      expect(snapshot.draftRetentionDays, 7);
    });

    test('round-trips every new setting through the service', () async {
      final service = SettingsService();
      await service.updateDensity(LayoutDensity.compact);
      await service.updateBubbleRadius(8);
      await service.updateSendReadReceipts(false);
      await service.updateAutoDownloadImages(AutoDownloadPolicy.always);
      await service.updateAutoDownloadFiles(AutoDownloadPolicy.wifi);
      await service.updateAutoDownloadVideos(AutoDownloadPolicy.always);
      await service.updateSendShortcut(SendShortcut.both);
      await service.updateDraftsEnabled(false);
      await service.updateDraftRetentionDays(7);
      await service.updateDeepLinkAutoJoin(true);
      await service.updateDbWipeRequiresPrompt(true);
      await service.updateDbBackupKeepCount(3);
      await service.updateAutoLockEnabled(true);
      await service.updateAutoLockMinutes(15);
      await service.updateWipeLogsOnLogout(false);
      await service.updateSyncDebounceMs(100);
      await service.updateSearchDebounceMs(200);
      await service.updateDraftAutosaveMs(300);
      await service.updateNotificationPersistMs(400);
      await service.updateDeepLinkDedupMs(600);
      await service.updateFirstSyncTimeoutS(20);
      await service.updateEncryptionRefreshDebounceMs(800);
      await service.updateSearchPageSize(50);
      await service.updateLogMaxFileSizeMb(64);
      await service.updateLogMaxFiles(5);
      await service.updateLogFlushDelayS(30);
      await service.updateLogLevel(LogLevel.error);
      await service.updateLogVerboseRelease(true);
      await service.updateTrayLeftClick(TrayClickAction.show);
      await service.updateWindowMinWidth(640);
      await service.updateWindowMinHeight(720);
      await service.updateFontFamily('Inter');
      await service.updateMonoFontFamily('JetBrains Mono');
      await service.updateReplyPreviewThreshold(120);
      await service.updateImageThumbnailMaxPx(480);
      await service.updateStickerMaxPx(240);
      await service.updateVideoMaxPx(540);
      await service.updateAudioMaxPx(420);
      await service.updateFileMaxPx(380);
      await service.updateLocationMaxPx(420);
      await service.updateAttachmentClickThresholdMb(50);
      await service.updateNotifyDmsOnly(true);
      await service.updateNotifyWhenFocused(false);
      await service.updateNotificationSoundEnabled(false);
      await service.updateNotificationDedupeCacheSize(1024);
      await service.updateAvatarCacheTtlDays(14);

      final snap = await service.loadAll();
      expect(snap.density, LayoutDensity.compact);
      expect(snap.bubbleRadius, 8);
      expect(snap.sendReadReceipts, isFalse);
      expect(snap.autoDownloadImages, AutoDownloadPolicy.always);
      expect(snap.autoDownloadFiles, AutoDownloadPolicy.wifi);
      expect(snap.autoDownloadVideos, AutoDownloadPolicy.always);
      expect(snap.sendShortcut, SendShortcut.both);
      expect(snap.draftsEnabled, isFalse);
      expect(snap.draftRetentionDays, 7);
      expect(snap.deepLinkAutoJoin, isTrue);
      expect(snap.dbWipeRequiresPrompt, isTrue);
      expect(snap.dbBackupKeepCount, 3);
      expect(snap.autoLockEnabled, isTrue);
      expect(snap.autoLockMinutes, 15);
      expect(snap.wipeLogsOnLogout, isFalse);
      expect(snap.syncDebounceMs, 100);
      expect(snap.searchDebounceMs, 200);
      expect(snap.draftAutosaveMs, 300);
      expect(snap.notificationPersistMs, 400);
      expect(snap.deepLinkDedupMs, 600);
      expect(snap.firstSyncTimeoutS, 20);
      expect(snap.encryptionRefreshDebounceMs, 800);
      expect(snap.searchPageSize, 50);
      expect(snap.logMaxFileSizeMb, 64);
      expect(snap.logMaxFiles, 5);
      expect(snap.logFlushDelayS, 30);
      expect(snap.logLevel, LogLevel.error);
      expect(snap.logVerboseRelease, isTrue);
      expect(snap.trayLeftClick, TrayClickAction.show);
      expect(snap.windowMinWidth, 640);
      expect(snap.windowMinHeight, 720);
      expect(snap.fontFamily, 'Inter');
      expect(snap.monoFontFamily, 'JetBrains Mono');
      expect(snap.replyPreviewThreshold, 120);
      expect(snap.imageThumbnailMaxPx, 480);
      expect(snap.stickerMaxPx, 240);
      expect(snap.videoMaxPx, 540);
      expect(snap.audioMaxPx, 420);
      expect(snap.fileMaxPx, 380);
      expect(snap.locationMaxPx, 420);
      expect(snap.attachmentClickThresholdMb, 50);
      expect(snap.notifyDmsOnly, isTrue);
      expect(snap.notifyWhenFocused, isFalse);
      expect(snap.notificationSoundEnabled, isFalse);
      expect(snap.notificationDedupeCacheSize, 1024);
      expect(snap.avatarCacheTtlDays, 14);
    });
  });

  group('SettingsController clamps out-of-range values', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('clamps font size, bubble radius, and window size', () async {
      final controller = SettingsController(SettingsService());
      await controller.loadSettings();
      await controller.updateFontSize(100); // > 28 → clamped to 28
      expect(controller.fontSize, 28.0);
      await controller.updateBubbleRadius(-10); // < 0 → clamped to 0
      expect(controller.bubbleRadius, 0.0);
      await controller.updateWindowMinWidth(99999); // > 2000 → clamped
      expect(controller.windowMinWidth, 2000.0);
      await controller.updateWindowMinHeight(0); // < 400 → clamped
      expect(controller.windowMinHeight, 400.0);
    });

    test('clamps media size sliders', () async {
      final controller = SettingsController(SettingsService());
      await controller.loadSettings();
      await controller.updateImageThumbnailMaxPx(10);
      expect(controller.imageThumbnailMaxPx, 80);
      await controller.updateImageThumbnailMaxPx(99999);
      expect(controller.imageThumbnailMaxPx, 1200);
      await controller.updateStickerMaxPx(0);
      expect(controller.stickerMaxPx, 80);
      await controller.updateReplyPreviewThreshold(0);
      expect(controller.replyPreviewThreshold, 20);
      await controller.updateReplyPreviewThreshold(99999);
      expect(controller.replyPreviewThreshold, 500);
    });
  });
}