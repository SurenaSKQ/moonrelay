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
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Displays an image message with thumbnail, loading state, and tap-to-zoom.
class ImageMessageType extends StatefulWidget {
  const ImageMessageType({super.key, required this.event});
  final Event event;

  @override
  State<ImageMessageType> createState() => _ImageMessageTypeState();
}

class _ImageMessageTypeState extends State<ImageMessageType> {
  Future<MatrixFile>? _downloadFuture;

  @override
  void initState() {
    super.initState();
    if (widget.event.hasAttachment) {
      _downloadFuture = widget.event.downloadAndDecryptAttachment();
    }
  }

  /// Maximum display size for thumbnails in the timeline.
  static const double _maxThumbnailWidth = 320;
  static const double _maxThumbnailHeight = 400;

  /// Image dimensions from the event content's `info` blob.
  int? get _imgWidth => _infoMap['w'] as int? ?? _infoMap['width'] as int?;
  int? get _imgHeight => _infoMap['h'] as int? ?? _infoMap['height'] as int?;

  Map<String, dynamic> get _infoMap => widget.event.content['info'] is Map
      ? widget.event.content['info'] as Map<String, dynamic>
      : const {};

  /// Computes a constrained box size that preserves aspect ratio.
  BoxConstraints _imageConstraints() {
    if (_imgWidth == null || _imgHeight == null) {
      return BoxConstraints(
        maxWidth: _maxThumbnailWidth,
        maxHeight: _maxThumbnailHeight,
      );
    }

    final w = _imgWidth!.toDouble();
    final h = _imgHeight!.toDouble();
    final scale = (_maxThumbnailWidth / w).clamp(0.0, 1.0);
    final displayWidth = w * scale;
    final displayHeight = h * scale;

    if (displayHeight > _maxThumbnailHeight) {
      final heightScale = _maxThumbnailHeight / displayHeight;
      return BoxConstraints(
        maxWidth: displayWidth * heightScale,
        maxHeight: _maxThumbnailHeight,
      );
    }

    return BoxConstraints(
      maxWidth: displayWidth,
      maxHeight: displayHeight,
    );
  }

  void _openFullscreen(Uint8List bytes) {
    showDialog(
      context: context,
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Container(
          color: Colors.black,
          child: Center(
            child: InteractiveViewer(
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Center(
                  child: Text(
                    AppLocalizations.of(context)!.failedToLoadImage,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_downloadFuture == null) {
      return const Icon(Icons.description, size: 48);
    }

    return FutureBuilder<MatrixFile>(
      future: _downloadFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            width: 120,
            height: 120,
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Tooltip(
            message: AppLocalizations.of(context)!
                .failedToLoadImageWithError('${snapshot.error}'),
            child: const Icon(Icons.error, size: 48),
          );
        }

        final bytes = snapshot.data?.bytes;
        if (bytes == null || bytes.isEmpty) {
          return const Icon(Icons.error, size: 48);
        }

        return ConstrainedBox(
          constraints: _imageConstraints(),
          child: GestureDetector(
            onTap: () => _openFullscreen(bytes),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.description,
                  size: 48,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
