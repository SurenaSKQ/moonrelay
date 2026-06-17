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
import 'package:moonrelay/src/screens/image_viewer_screen.dart';

/// Displays an image message with a polished thumbnail card and tap-to-open
/// full-screen viewer.
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

  int? get _fileSize => _infoMap['size'] as int?;

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

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Opens the full-screen image viewer.
  void _openViewer(Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ImageViewerScreen(
          bytes: bytes,
          event: widget.event,
        ),
      ),
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

        return _buildThumbnail(cs, bytes);
      },
    );
  }

  Widget _buildPlaceholder(ColorScheme cs) {
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(Icons.image_outlined, size: 40, color: cs.onSurfaceVariant),
    );
  }

  Widget _buildLoading(ColorScheme cs) {
    return Container(
      width: 180,
      height: 140,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: cs.primary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.loading,
            style: TextStyle(
              fontSize: 11,
              color: cs.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return Tooltip(
      message: AppLocalizations.of(context)!.failedToLoadImage,
      child: Container(
        width: 120,
        height: 120,
        decoration: BoxDecoration(
          color: cs.errorContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.error.withValues(alpha: 0.3),
          ),
        ),
        child: Icon(Icons.broken_image_outlined, size: 40, color: cs.error),
      ),
    );
  }

  Widget _buildThumbnail(ColorScheme cs, Uint8List bytes) {
    return GestureDetector(
      onTap: () => _openViewer(bytes),
      child: Container(
        constraints: _imageConstraints(),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // ── The image ──────────────────────────────────────────────
            Image.memory(
              bytes,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, __, ___) => Container(
                height: 120,
                color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
                child: Icon(Icons.image_outlined,
                    size: 40, color: cs.onSurfaceVariant),
              ),
            ),

            // ── Hover / tap hint overlay ────────────────────────────────
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.5),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.zoom_in,
                      size: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _imgWidth != null && _imgHeight != null
                          ? '${_imgWidth}×${_imgHeight}'
                          : '',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    if (_fileSize != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        _formatSize(_fileSize!),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
