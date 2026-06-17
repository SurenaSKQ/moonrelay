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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Displays a video message with a thumbnail preview (if available),
/// metadata overlay, and download action.
///
/// A future iteration will add an in-app video player.
class VideoMessageType extends StatefulWidget {
  const VideoMessageType({super.key, required this.event});
  final Event event;

  @override
  State<VideoMessageType> createState() => _VideoMessageTypeState();
}

class _VideoMessageTypeState extends State<VideoMessageType> {
  Future<MatrixFile>? _downloadFuture;
  Future<MatrixFile>? _thumbnailFuture;

  @override
  void initState() {
    super.initState();
    if (widget.event.hasAttachment) {
      _downloadFuture = widget.event.downloadAndDecryptAttachment();
    }
    // Try to fetch the video thumbnail if available.
    if (widget.event.hasThumbnail) {
      _thumbnailFuture =
          widget.event.downloadAndDecryptAttachment(getThumbnail: true);
    }
  }

  // ---- Content helpers ----

  String? get _fileName => widget.event.content['filename']?.toString();
  String? get _mimeType => widget.event.content['mimetype']?.toString();
  String get _extension =>
      (_fileName?.split('.').last ?? _mimeType?.split('/').last ?? 'VIDEO')
          .toUpperCase();

  Map<String, dynamic> get _infoMap => widget.event.content['info'] is Map
      ? widget.event.content['info'] as Map<String, dynamic>
      : const {};

  int? get _duration => _infoMap['duration'] as int?;
  int? get _fileSize => _infoMap['size'] as int?;

  /// Video dimensions from the content's info blob.
  int? get _videoWidth => _infoMap['w'] as int? ?? _infoMap['width'] as int?;
  int? get _videoHeight => _infoMap['h'] as int? ?? _infoMap['height'] as int?;

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  // ---- Actions ----

  Future<void> _downloadFile(MatrixFile attFile) async {
    await FilePicker.saveFile(
      dialogTitle: AppLocalizations.of(context)!.saveVideo,
      fileName: _fileName,
      bytes: attFile.bytes,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final hasDuration = _duration != null;

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Thumbnail / preview area ─────────────────────────────────
          _buildPreviewArea(cs, l10n),

          // ── Metadata row ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                // File icon
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.videocam_rounded,
                    size: 18,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),

                // Info text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _fileName ?? l10n.videoFileName,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  cs.tertiaryContainer.withValues(alpha: 0.5),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _extension,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                                color: cs.onTertiaryContainer,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          if (hasDuration) ...[
                            const SizedBox(width: 8),
                            Icon(Icons.schedule_outlined,
                                size: 12,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.6)),
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(_duration!),
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          if (_fileSize != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatSize(_fileSize!),
                              style: TextStyle(
                                fontSize: 11,
                                color:
                                    cs.onSurfaceVariant.withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Download button
                Tooltip(
                  message: l10n.downloadVideo,
                  child: FutureBuilder<MatrixFile>(
                    future: _downloadFuture,
                    builder: (context, snapshot) {
                      final isReady =
                          snapshot.connectionState == ConnectionState.done &&
                              !snapshot.hasError;
                      return Container(
                        decoration: BoxDecoration(
                          color: cs.primary.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.download_rounded, size: 20),
                          color: cs.primary,
                          onPressed: isReady && snapshot.data != null
                              ? () => _downloadFile(snapshot.data!)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea(ColorScheme cs, AppLocalizations l10n) {
    // If there's a thumbnail, show it.
    if (_thumbnailFuture != null) {
      return FutureBuilder<MatrixFile>(
        future: _thumbnailFuture,
        builder: (context, snapshot) {
          final data = snapshot.data;
          final thumbnailBytes = data?.bytes;
          if (snapshot.connectionState == ConnectionState.done &&
              !snapshot.hasError &&
              thumbnailBytes != null) {
            return _buildThumbnail(cs, thumbnailBytes);
          }
          // While loading or on error, show the fallback preview.
          return _buildPreviewFallback(cs, l10n);
        },
      );
    }

    // No thumbnail at all — show the fallback.
    return _buildPreviewFallback(cs, l10n);
  }

  Widget _buildThumbnail(ColorScheme cs, Uint8List bytes) {
    return Stack(
      children: [
        // The thumbnail image
        ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
          child: Image.memory(
            bytes,
            width: double.infinity,
            height: 180,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPreviewFallback(cs, null),
          ),
        ),

        // Dark gradient overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        // Play button overlay
        Center(
          child: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.3),
                width: 2,
              ),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 30,
              color: Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),

        // Resolution badge (bottom-left)
        if (_videoWidth != null && _videoHeight != null)
          Positioned(
            bottom: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${_videoWidth}×${_videoHeight}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),

        // Duration badge (bottom-right)
        if (_duration != null)
          Positioned(
            bottom: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 3,
              ),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.schedule_outlined,
                    size: 12,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                  const SizedBox(width: 3),
                  Text(
                    _formatDuration(_duration!),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildPreviewFallback(ColorScheme cs, AppLocalizations? l10n) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.videocam_rounded,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 8),
            Text(
              l10n?.unknownType ?? '',
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
