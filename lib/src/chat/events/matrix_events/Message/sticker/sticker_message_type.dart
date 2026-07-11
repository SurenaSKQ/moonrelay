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
import 'package:moonrelay/src/settings/media_size_prefs.dart';

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

  @override
  void initState() {
    super.initState();
    if (widget.event.hasAttachment) {
      _downloadFuture = widget.event.downloadAndDecryptAttachment();
    }
  }

  /// Image dimensions from the event content's `info` blob.
  int? get _imgWidth => _infoMap['w'] as int? ?? _infoMap['width'] as int?;
  int? get _imgHeight => _infoMap['h'] as int? ?? _infoMap['height'] as int?;

  Map<String, dynamic> get _infoMap => widget.event.content['info'] is Map
      ? widget.event.content['info'] as Map<String, dynamic>
      : const {};

  /// Computes a constrained box size that preserves aspect ratio.
  BoxConstraints _stickerConstraints(double maxStickerDim) {
    final maxStickerHeight = maxStickerDim; // keep sticker roughly square
    if (_imgWidth == null || _imgHeight == null) {
      return BoxConstraints(
        maxWidth: maxStickerDim,
        maxHeight: maxStickerHeight,
      );
    }

    final w = _imgWidth!.toDouble();
    final h = _imgHeight!.toDouble();
    final scale = (maxStickerDim / w).clamp(0.0, 1.0);
    final displayWidth = w * scale;
    final displayHeight = h * scale;

    if (displayHeight > maxStickerHeight) {
      final heightScale = maxStickerHeight / displayHeight;
      return BoxConstraints(
        maxWidth: displayWidth * heightScale,
        maxHeight: maxStickerHeight,
      );
    }

    return BoxConstraints(
      maxWidth: displayWidth,
      maxHeight: displayHeight,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

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
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.sticky_note_2_outlined, size: 36, color: cs.onSurfaceVariant),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
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
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: cs.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.error.withValues(alpha: 0.3)),
      ),
      child: Icon(Icons.broken_image_outlined, size: 32, color: cs.error),
    );
  }

  Widget _buildSticker(ColorScheme cs, Uint8List bytes, BuildContext context) {
    final prefs = MediaSizePrefs.of(context);
    return Container(
      constraints: _stickerConstraints(prefs.stickerMax),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.memory(
        bytes,
        fit: BoxFit.contain,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (_, __, ___) => Container(
          height: 80,
          color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
          child: Icon(Icons.broken_image_outlined, size: 32, color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}
