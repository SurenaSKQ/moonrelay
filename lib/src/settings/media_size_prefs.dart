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
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

/// Resolved pixel widths for the various media bubbles in a chat message.
///
/// Each renderer (image / video / sticker / audio / file / location) reads
/// from this helper rather than a hard-coded constant so users can tune
/// the bubble sizes via the appearance settings.
///
/// The lookup is O(1) (a single [Provider.read]) and falls back to the
/// historical hard-coded defaults when the [SettingsController] is not in
/// the widget tree (which is the case in isolated widget tests).
class MediaSizePrefs {
  const MediaSizePrefs._({
    required this.imageThumbnailMax,
    required this.stickerMax,
    required this.videoMax,
    required this.audioMax,
    required this.fileMax,
    required this.locationMax,
  });

  /// Default values that match the pre-settings hard-coded constants.
  /// Used when no [SettingsController] is available.  Keep in sync with
  /// the [SettingsController] defaults (audio 340, file 360,
  /// location 340) so isolated widget tests see the same sizes as the
  /// real app.
  static const MediaSizePrefs _fallback = MediaSizePrefs._(
    imageThumbnailMax: 360,
    stickerMax: 180,
    videoMax: 360,
    audioMax: 340,
    fileMax: 360,
    locationMax: 340,
  );

  /// Maximum display dimension for image thumbnails.
  final double imageThumbnailMax;

  /// Maximum display width for stickers.
  final double stickerMax;

  /// Maximum display width for video previews.
  final double videoMax;

  /// Maximum display width for audio messages.
  final double audioMax;

  /// Maximum display width for generic file attachments.
  final double fileMax;

  /// Maximum display width for location messages.
  final double locationMax;

  /// Resolves the active media-size preferences from the nearest
  /// [SettingsController] in the widget tree.
  ///
  /// Falls back to [_fallback] when the controller is missing (e.g. in
  /// widget tests).
  factory MediaSizePrefs.of(BuildContext context) {
    try {
      final c = context.read<SettingsController>();
      return MediaSizePrefs._(
        imageThumbnailMax: c.imageThumbnailMaxPx.toDouble(),
        stickerMax: c.stickerMaxPx.toDouble(),
        videoMax: c.videoMaxPx.toDouble(),
        audioMax: c.audioMaxPx.toDouble(),
        fileMax: c.fileMaxPx.toDouble(),
        locationMax: c.locationMaxPx.toDouble(),
      );
    } catch (_) {
      return _fallback;
    }
  }

  /// Bare defaults; useful when no [BuildContext] is available (e.g. in a
  /// static `const` context).
  static const MediaSizePrefs defaults = _fallback;
}