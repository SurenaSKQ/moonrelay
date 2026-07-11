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

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/media_size_prefs.dart';
import 'package:video_player/video_player.dart';

/// Displays a video message with an in-app `video_player` controller.
///
/// Heights follow the message's natural aspect ratio (clamped to the
/// 16:9 – 9:16 range) so portrait videos aren't stretched into a 320×180
/// bar anymore. A bottom play/pause overlay appears whenever the user
/// hovers the video; tapping the video itself toggles play/pause.
class VideoMessageType extends StatefulWidget {
  const VideoMessageType({super.key, required this.event});
  final Event event;

  @override
  State<VideoMessageType> createState() => _VideoMessageTypeState();
}

class _VideoMessageTypeState extends State<VideoMessageType> {
  Future<MatrixFile>? _downloadFuture;
  Future<MatrixFile>? _thumbnailFuture;
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.event.hasAttachment) {
      _downloadFuture = widget.event.downloadAndDecryptAttachment();
    }
    if (widget.event.hasThumbnail) {
      _thumbnailFuture =
          widget.event.downloadAndDecryptAttachment(getThumbnail: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
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
  int? get _videoWidth => _infoMap['w'] as int? ?? _infoMap['width'] as int?;
  int? get _videoHeight => _infoMap['h'] as int? ?? _infoMap['height'] as int?;

  String _formatDuration(int ms) {
    final totalSeconds = ms ~/ 1000;
    final m = totalSeconds ~/ 60;
    final s = totalSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Computes the height-and-width-clamped box for the video player.
  ///
  /// Constrains by height: video fills the available height (max from
  /// [MediaSizePrefs.videoMax]) while the width follows from the aspect
  /// ratio. Falls back to 320×180 when dimensions are unknown.
  Size _playerSize(double maxBox) {
    final maxWidth = maxBox;
    final maxHeight = maxBox;
    final w = _videoWidth?.toDouble();
    final h = _videoHeight?.toDouble();
    if (w == null || h == null || w <= 0 || h <= 0) {
      return const Size(320, 180);
    }
    final ratio = w / h;
    if (h >= w) {
      // Portrait — clamp height, follow width.
      final height = maxHeight;
      final width = (height * ratio).clamp(120.0, maxWidth);
      return Size(width, height);
    } else {
      // Landscape — clamp width, follow height.
      final width = maxWidth;
      final height = (width / ratio).clamp(120.0, maxHeight);
      return Size(width, height);
    }
  }

  Future<void> _buildControllerFromDownload() async {
    if (_controller != null) return;
    final snap = await _downloadFuture;
    final bytes = snap?.bytes;
    if (bytes == null || bytes.isEmpty) return;
    if (!mounted) return;
    await _buildController(bytes);
  }

  Future<void> _buildController(Uint8List bytes) async {
    if (_controller != null) return;
    final name = _fileName ?? 'video_${widget.event.eventId}.mp4';
    final path = '${Directory.systemTemp.path}/moonrelay_$name';
    final tmp = File(path)..writeAsBytesSync(bytes);
    final c = VideoPlayerController.file(tmp);
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(false);
      if (mounted) setState(() {});
      c.addListener(_onControllerTick);
    } catch (_) {}
  }

  void _onControllerTick() {
    if (mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
      return;
    }
    // Initialise on first toggle if the future hasn't completed yet.
    await _buildControllerFromDownload();
  }

  Future<void> _downloadFile(MatrixFile attFile) async {
    await FilePicker.saveFile(
      dialogTitle: AppLocalizations.of(context)!.saveVideo,
      fileName: _fileName ?? 'video.$_extension',
      bytes: attFile.bytes,
    );
  }

  Future<void> _openFullscreen() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _FullscreenVideoPlayer(controller: c),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final prefs = MediaSizePrefs.of(context);
    final playerSize = _playerSize(prefs.videoMax);

    return Container(
      constraints: BoxConstraints(maxWidth: prefs.videoMax),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Player / preview area ────────────────────────────────
          SizedBox(
            width: playerSize.width,
            height: playerSize.height,
            child: _buildPlayerArea(cs, l10n),
          ),

          // ── Metadata row ───────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    LucideIcons.video,
                    size: 18,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 12),

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
                              color: cs.tertiaryContainer
                                  .withValues(alpha: 0.5),
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
                          if (_duration != null) ...[
                            const SizedBox(width: 8),
                            Icon(
                              LucideIcons.clock,
                              size: 12,
                              color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                            ),
                            const SizedBox(width: 2),
                            Text(
                              _formatDuration(_duration!),
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                          ],
                          if (_fileSize != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              _formatSize(_fileSize!),
                              style: TextStyle(
                                fontSize: 11,
                                color: cs.onSurfaceVariant
                                    .withValues(alpha: 0.5),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Download / save button.
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
                          icon: Icon(
                            LucideIcons.download,
                            size: 18,
                            color: cs.primary,
                          ),
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

  Widget _buildPlayerArea(ColorScheme cs, AppLocalizations l10n) {
    final c = _controller;
    if (c != null && c.value.isInitialized) {
      // ── Real video player ─────────────────────────────────────
      return MouseRegion(
        child: GestureDetector(
          onTap: _togglePlay,
          onDoubleTap: _openFullscreen,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: AspectRatio(
                  aspectRatio: c.value.aspectRatio == 0
                      ? 1.0
                      : c.value.aspectRatio,
                  child: VideoPlayer(c),
                ),
              ),
              // Play/pause overlay
              if (!c.value.isPlaying)
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                ),
              // Top-right fullscreen button
              Positioned(
                top: 6,
                right: 6,
                child: Tooltip(
                  message: l10n.fullscreenVideo,
                  child: Material(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: const CircleBorder(),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _openFullscreen,
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(
                          LucideIcons.maximize,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Bottom progress bar
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: VideoProgressIndicator(
                  c,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Thumbnail placeholder ────────────────────────────────
    return _buildPreviewArea(cs, l10n);
  }

  Widget _buildPreviewArea(ColorScheme cs, AppLocalizations l10n) {
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
          return _buildPreviewFallback(cs, l10n);
        },
      );
    }
    return _buildPreviewFallback(cs, l10n);
  }

  Widget _buildThumbnail(ColorScheme cs, Uint8List bytes) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.memory(
            bytes,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildPreviewFallback(cs, null),
          ),
        ),
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
        // Build the controller once downloaded.
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
      ],
    );
  }

  Widget _buildPreviewFallback(ColorScheme cs, AppLocalizations? l10n) {
    return Container(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.video,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  const _FullscreenVideoPlayer({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_FullscreenVideoPlayer> createState() =>
      _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTick);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTick);
    super.dispose();
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: GestureDetector(
          onTap: () => c.value.isPlaying ? c.pause() : c.play(),
          child: AspectRatio(
            aspectRatio:
                c.value.aspectRatio == 0 ? 16 / 9 : c.value.aspectRatio,
            child: VideoPlayer(c),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.white.withValues(alpha: 0.2),
        foregroundColor: Colors.white,
        onPressed: () => c.value.isPlaying ? c.pause() : c.play(),
        child: Icon(c.value.isPlaying ? Icons.pause : Icons.play_arrow),
      ),
    );
  }
}