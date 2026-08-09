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

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/number_coercion.dart';
import 'package:moonrelay/src/helpers/room_media_cache.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/media_size_prefs.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// Renders an `m.sticker` event as a compact image card without the
/// tap-to-open viewer (stickers are meant to be lightweight).
class StickerMessageType extends StatefulWidget {
  const StickerMessageType({super.key, required this.event});
  final Event event;

  @override
  State<StickerMessageType> createState() => _StickerMessageTypeState();
}

class _StickerMessageTypeState extends State<StickerMessageType> {
  Future<MatrixFile>? _downloadFuture;

  bool _autoDownloadResolved = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveAutoDownload();
  }

  void _resolveAutoDownload() {
    if (_autoDownloadResolved) return;
    _autoDownloadResolved = true;
    if (!widget.event.hasAttachment) return;
    if (!_shouldAutoDownload()) return;
    // Share the in-flight future with the global cache so other
    // States for the same event don't download a second copy.
    _downloadFuture = RoomMediaCache.instance.getOrDownload(
      widget.event.roomId ?? widget.event.eventId,
      widget.event.eventId,
      () => widget.event.downloadAndDecryptAttachment(),
    );
  }

  /// Checks the user's auto-download preference for images (stickers).
  bool _shouldAutoDownload() {
    try {
      final policy = context.read<SettingsController>().autoDownloadImages;
      switch (policy) {
        case AutoDownloadPolicy.always:
        case AutoDownloadPolicy.wifi:
          return true;
        case AutoDownloadPolicy.never:
          return false;
      }
    } catch (_) {
      return true;
    }
  }

  /// Image dimensions from the event content's `info` blob. Tolerates
  /// [num] of any runtime type via [coerceJsonInt].
  int? get _imgWidth =>
      coerceJsonInt(_infoMap['w']) ?? coerceJsonInt(_infoMap['width']);
  int? get _imgHeight =>
      coerceJsonInt(_infoMap['h']) ?? coerceJsonInt(_infoMap['height']);

  Map<String, dynamic> get _infoMap {
    final info = widget.event.content['info'];
    if (info is Map<String, dynamic>) return info;
    if (info is Map) return Map<String, dynamic>.from(info);
    return const {};
  }

  /// Computes the rendered sticker size preserving aspect ratio.
  ///
  /// Returns the on-screen size the sticker should be drawn at so it
  /// never grows past [maxStickerDim] on either axis.  When the source
  /// dimensions are unknown the bubble falls back to a square box of
  /// [maxStickerDim] pixels.
  Size _stickerSize(double maxStickerDim) {
    final w = _imgWidth;
    final h = _imgHeight;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return Size(maxStickerDim, maxStickerDim);
    }
    final ar = w / h;
    if (ar >= 1) {
      final width = maxStickerDim;
      final height = (maxStickerDim / ar).clamp(1.0, maxStickerDim);
      return Size(width, height);
    }
    final height = maxStickerDim;
    final width = (maxStickerDim * ar).clamp(1.0, maxStickerDim);
    return Size(width, height);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    final cached = RoomMediaCache.instance
        .get(widget.event.roomId ?? widget.event.eventId, widget.event.eventId);
    if (cached != null && cached.isNotEmpty) {
      return _buildSticker(cs, cached, context);
    }

    if (_downloadFuture == null) {
      return _buildPlaceholder(cs);
    }

    return FutureBuilder<MatrixFile>(
      future: _downloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return _buildLoading(cs);
        }

        if (snapshot.hasError) {
          return _buildError(cs);
        }

        final bytes = snapshot.data?.bytes;
        if (bytes == null || bytes.isEmpty) {
          return _buildError(cs);
        }

        return _buildSticker(cs, bytes, context);
      },
    );
  }

  Widget _buildPlaceholder(ColorScheme cs) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Icon(Icons.sticky_note_2_outlined,
          size: 36, color: cs.onSurfaceVariant),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return SizedBox(
      width: 100,
      height: 100,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: cs.primary),
        ),
      ),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return SizedBox(
      width: 80,
      height: 80,
      child: Icon(Icons.broken_image_outlined, size: 32, color: cs.error),
    );
  }

  Widget _buildSticker(ColorScheme cs, Uint8List bytes, BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final prefs = MediaSizePrefs.of(context);
    // Cap decoded bitmap to display size × DPR. Stickers are typically
    // small but the raw attachment can still be a multi-megapixel PNG.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final stickerMax = prefs.stickerMax;
    final size = _stickerSize(stickerMax);
    // Stickers render as the picture alone — no borders, no info
    // overlays, no background card.  The sticker is the whole bubble.
    return Image.memory(
      bytes,
      fit: BoxFit.contain,
      width: size.width,
      height: size.height,
      cacheWidth: (stickerMax * dpr).ceil(),
      errorBuilder: (_, __, ___) => SizedBox(
        width: size.width,
        height: size.height,
        child: Container(
          color: cs.surfaceContainerHighest.withValues(alpha: t.opacitySubtle),
          child: Icon(
            Icons.broken_image_outlined,
            size: 32,
            color: cs.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
