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

import 'dart:async';
import 'package:moonrelay/src/chat/events/matrix_events/Message/video/fullscreen_video_player.dart';
import 'package:moonrelay/src/chat/events/matrix_events/Message/video/video_player_surface.dart';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/number_coercion.dart';
import 'package:moonrelay/src/helpers/room_media_cache.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/media_size_prefs.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';

/// Displays a video message with an in-app `video_player` controller.
///
/// Heights follow the message's natural aspect ratio so portrait videos
/// aren't stretched into a 320×180 bar.  The bubble is left-aligned to
/// the message (matching the rest of the timeline) instead of being
/// forced to a full row width.
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

  /// True after the first controller initialization failed.  Cleared
  /// when a new attempt is made so the UI offers a retry instead of a
  /// permanently silent fallback.
  bool _controllerFailed = false;

  /// Monotonic token so stale build-controller futures can't clobber a
  /// newer one if the user retries mid-download.
  int _buildToken = 0;

  /// Scratch timer we schedule when auto-download is in flight so the
  /// spinner's first frame shows immediately.  Tracked so it can be
  /// cancelled in [dispose].
  Timer? _spinnerTimer;

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
    // Share the in-flight future with the global cache.
    _downloadFuture = RoomMediaCache.instance.getOrDownload(
      widget.event.roomId ?? widget.event.eventId,
      widget.event.eventId,
      () => widget.event.downloadAndDecryptAttachment(),
    );
    if (widget.event.hasThumbnail && _thumbnailFuture == null) {
      _thumbnailFuture = RoomMediaCache.instance.getOrDownload(
        '${widget.event.roomId ?? widget.event.eventId}::thumb',
        widget.event.eventId,
        () => widget.event.downloadAndDecryptAttachment(getThumbnail: true),
      );
    }
  }

  /// Checks the user's auto-download preference for videos.
  bool _shouldAutoDownload() {
    try {
      final policy = context.read<SettingsController>().autoDownloadVideos;
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

  @override
  void dispose() {
    _spinnerTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ---- Content helpers ----

  String? get _fileName => widget.event.content['filename']?.toString();
  String? get _mimeType => widget.event.content['mimetype']?.toString();
  String get _extension =>
      (_fileName?.split('.').last ?? _mimeType?.split('/').last ?? 'VIDEO')
          .toUpperCase();

  Map<String, dynamic> get _infoMap {
    final info = widget.event.content['info'];
    if (info is Map<String, dynamic>) return info;
    if (info is Map) return Map<String, dynamic>.from(info);
    return const {};
  }

  int? get _duration => coerceJsonInt(_infoMap['duration']);
  int? get _fileSize => coerceJsonInt(_infoMap['size']);
  int? get _videoWidth =>
      coerceJsonInt(_infoMap['w']) ?? coerceJsonInt(_infoMap['width']);
  int? get _videoHeight =>
      coerceJsonInt(_infoMap['h']) ?? coerceJsonInt(_infoMap['height']);

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
  /// Falls back to 320×180 when dimensions are unknown.
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
      // Portrait: clamp height, follow width.
      final height = maxHeight;
      final width = (height * ratio).clamp(120.0, maxWidth);
      return Size(width, height);
    }
    // Landscape: clamp width, follow height.
    final width = maxWidth;
    final height = (width / ratio).clamp(120.0, maxHeight);
    return Size(width, height);
  }

  /// Brings the controller up, downloading the attachment first if we
  /// don't have it yet.  Errors during either stage surface as a
  /// retry-able state in [_buildPlayerArea].
  Future<void> _buildControllerFromDownload() async {
    if (_controller != null && _controller!.value.isInitialized) {
      await _playIfReady(_controller!);
      return;
    }
    if (_controllerFailed) {
      // Clear the stale controller and rebuild from scratch.
      _disposeController();
      _controllerFailed = false;
    }
    final token = ++_buildToken;
    try {
      final snap =
          await (_downloadFuture ??= RoomMediaCache.instance.getOrDownload(
        widget.event.roomId ?? widget.event.eventId,
        widget.event.eventId,
        () => widget.event.downloadAndDecryptAttachment(),
      ));
      if (!mounted || token != _buildToken) return;
      final bytes = snap.bytes;
      if (bytes.isEmpty) {
        throw StateError('Empty video attachment');
      }
      await _buildController(bytes);
      if (!mounted || token != _buildToken) return;
      await _playIfReady(_controller!);
    } catch (_) {
      if (!mounted || token != _buildToken) return;
      // Surface the failure so the UI offers a retry rather than a
      // silent fallback.
      setState(() {
        _controllerFailed = true;
      });
    }
  }

  Future<void> _playIfReady(VideoPlayerController c) async {
    if (c.value.isInitialized && !c.value.isPlaying) {
      await c.play();
    }
  }

  Future<void> _buildController(Uint8List bytes) async {
    // Defensive cleanup: if a previous attempt left us with a half-built
    // controller, dispose it before constructing a new one.
    if (_controller != null) {
      _disposeController();
    }
    final name = _fileName ?? 'video_${widget.event.eventId}.mp4';
    final dir = Directory.systemTemp;
    final file = File('${dir.path}/moonrelay_$name');
    try {
      file.writeAsBytesSync(bytes, flush: true);
    } on FileSystemException {
      // Could be a read-only temp dir or a name collision.  Re-throw
      // so [_buildControllerFromDownload] reports it to the user via
      // the retry state.
      rethrow;
    }
    final c = VideoPlayerController.file(file);
    _controller = c;
    try {
      await c.initialize();
      await c.setLooping(false);
      if (mounted) setState(() {});
    } catch (_) {
      // Initialization failed (codec, corrupt file, no decoder).  Mark
      // the controller for disposal and rethrow so the outer future
      // surfaces the retry state.
      _disposeController();
      rethrow;
    }
  }

  void _disposeController() {
    final c = _controller;
    _controller = null;
    if (c != null) {
      // VideoPlayerController.dispose is async; we don't await it so
      // callers can react immediately.  Errors here are best-effort
      // because the controller is going away anyway.
      unawaited(c.dispose().catchError((_) {}));
    }
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
    await _buildControllerFromDownload();
  }

  Future<void> _downloadFile(MatrixFile attFile) async {
    final l10n = AppLocalizations.of(context)!;
    await FilePicker.saveFile(
      dialogTitle: l10n.saveVideo,
      fileName: _fileName ?? 'video.$_extension',
      bytes: attFile.bytes,
    );
  }

  /// Ad-hoc download: pulls the video attachment when the user taps
  /// the save icon even though the auto-download policy is "never".
  /// Reuses the shared cache so a second tap doesn't refetch.
  ///
  /// Uses block-body lambdas for `setState` because the arrow form
  /// `() => _x = future` returns the assigned `Future`, which
  /// `State.setState` rejects as "the closure returned a Future".
  Future<void> _downloadOnDemand() async {
    final future = RoomMediaCache.instance.getOrDownload(
      widget.event.roomId ?? widget.event.eventId,
      widget.event.eventId,
      () => widget.event.downloadAndDecryptAttachment(),
    );
    setState(() {
      _downloadFuture = future;
    });
    try {
      final mf = await future;
      if (!mounted) return;
      await _downloadFile(mf);
    } catch (_) {
      // Keep the icon tappable for retry.
    } finally {
      if (mounted) {
        setState(() {
          _downloadFuture = null;
        });
      }
    }
  }

  Future<void> _openFullscreen() async {
    final c = _controller;
    if (c == null || !c.value.isInitialized) return;
    final navigator = Navigator.of(context);
    final controller = c;
    final route = MaterialPageRoute(
      builder: (_) => FullscreenVideoPlayer(controller: controller),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      navigator.push(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final prefs = MediaSizePrefs.of(context);
    final playerSize = _playerSize(prefs.videoMax);

    // The video bubble hugs the player + metadata row. No full-row
    // background: both panels have their own subtle fills so the
    // bubble reads as a unit only when the player itself is being
    // rendered.  The outer `Align` keeps the bubble glued to the left
    // edge so the chat doesn't get an oversized video card centred in
    // the row.
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        constraints: BoxConstraints(maxWidth: prefs.videoMax),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color:
              cs.surfaceContainerHighest.withValues(alpha: t.opacityDisabled),
          borderRadius: BorderRadius.circular(t.radiusMd),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: playerSize.width,
              height: playerSize.height,
              child: _buildPlayerArea(cs, l10n),
            ),
            SizedBox(
              width: playerSize.width,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: cs.primary.withValues(alpha: t.opacityFocus),
                        borderRadius: BorderRadius.circular(t.radiusMd),
                      ),
                      child: Icon(
                        LucideIcons.video,
                        size: 18,
                        color: cs.primary,
                      ),
                    ),
                    SizedBox(width: t.spaceMd),

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
                          SizedBox(height: t.spaceXxs),
                          // The metadata row sits inside an [Expanded]
                          // above and is itself allowed to shrink; the
                          // duration/size widgets can otherwise request
                          // more horizontal space than the bubble has
                          // (a long file size pushes us past the 36-px
                          // icon + 48-px trailing [IconButton] budget,
                          // producing a 51 px right overflow).
                          Flexible(
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cs.tertiaryContainer
                                        .withValues(alpha: t.opacitySubtle),
                                    borderRadius:
                                        BorderRadius.circular(t.radiusXs),
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
                                  SizedBox(width: t.spaceSm),
                                  Icon(
                                    LucideIcons.clock,
                                    size: 12,
                                    color: cs.onSurfaceVariant
                                        .withValues(alpha: 0.6),
                                  ),
                                  const SizedBox(width: 2),
                                  Flexible(
                                    child: Text(
                                      _formatDuration(_duration!),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant
                                            .withValues(alpha: 0.7),
                                      ),
                                    ),
                                  ),
                                ],
                                if (_fileSize != null) ...[
                                  SizedBox(width: t.spaceSm),
                                  Flexible(
                                    child: Text(
                                      _formatSize(_fileSize!),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant
                                            .withValues(alpha: t.opacitySubtle),
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Tight-size the trailing [IconButton] to match the
                    // leading 36×36 icon container.  Without this wrap the
                    // [IconButton] claims its default 48×48 Material tap
                    // target and the row overflows on the right.
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Semantics(
                        label: l10n.downloadVideo,
                        button: true,
                        child: FutureBuilder<MatrixFile>(
                          future: _downloadFuture,
                          builder: (context, snapshot) {
                            final isReady = snapshot.connectionState ==
                                    ConnectionState.done &&
                                !snapshot.hasError;
                            final isWaiting = snapshot.connectionState ==
                                ConnectionState.waiting;
                            return Container(
                              decoration: BoxDecoration(
                                color: cs.primary
                                    .withValues(alpha: t.opacityFocus),
                                borderRadius: BorderRadius.circular(t.radiusMd),
                              ),
                              child: IconButton(
                                padding: EdgeInsets.zero,
                                iconSize: 18,
                                constraints: const BoxConstraints(
                                  minWidth: 36,
                                  minHeight: 36,
                                  maxWidth: 36,
                                  maxHeight: 36,
                                ),
                                icon: isWaiting
                                    ? SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: cs.primary,
                                        ),
                                      )
                                    : Icon(
                                        LucideIcons.download,
                                        size: 18,
                                        color: cs.primary,
                                      ),
                                onPressed: isWaiting
                                    ? null
                                    : () async {
                                        if (isReady && snapshot.data != null) {
                                          await _downloadFile(snapshot.data!);
                                        } else {
                                          await _downloadOnDemand();
                                        }
                                      },
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlayerArea(ColorScheme cs, AppLocalizations l10n) {
    final c = _controller;

    if (_controllerFailed) {
      return _buildErrorPlayer(cs, l10n);
    }

    if (c != null && c.value.isInitialized) {
      // Subscribe only to the controller's ValueListenable so a frame
      // tick only re-paints the surface: the metadata row stays put.
      // Without ValueListenableBuilder we'd rebuild the entire Stack
      // (overlays, progress indicator, fullscreen button) at 60Hz.
      return InitializedVideoPlayer(controller: c, l10n: l10n);
    }

    return _buildPreviewArea(cs, l10n);
  }

  Widget _buildErrorPlayer(ColorScheme cs, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () {
        // Clear the failure flag and kick off a retry; the user
        // gets one explicit tap instead of an invisible dead button.
        setState(() {
          _controllerFailed = false;
        });
        _buildControllerFromDownload();
      },
      child: Container(
        color: cs.errorContainer.withValues(alpha: 0.4),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 36,
                color: cs.onErrorContainer,
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  l10n.videoLoadFailed,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: cs.onErrorContainer,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.tapToRetry,
                style: TextStyle(
                  fontSize: 11,
                  color: cs.onErrorContainer.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = _playerSize(MediaSizePrefs.of(context).videoMax);
    final longSide = size.width >= size.height ? size.width : size.height;
    return GestureDetector(
      onTap: _togglePlay,
      onDoubleTap: _openFullscreen,
      child: Stack(
        children: [
          Positioned.fill(
            child: Image.memory(
              bytes,
              fit: BoxFit.cover,
              cacheWidth: (longSide * dpr).ceil(),
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
                    Colors.black.withValues(alpha: t.opacitySubtle),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Center(
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: t.opacitySubtle),
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
          Positioned(
            top: 6,
            right: 6,
            // [Semantics] instead of [Tooltip]: the fullscreen
            // overlay button is part of the always-mounted video
            // thumbnail. Tooltip would mount an internal
            // [OverlayPortal] that activates on mount; inside the
            // dashboard's [LayoutBuilder] shell that activation
            // marks a sibling [_RenderLayoutBuilder] as needing
            // layout mid-performLayout and trips the
            // `_RenderLayoutBuilder was mutated in performLayout`
            // assertion (chat-page layout race). Semantics carries
            // the same accessibility label without ever
            // materialising an overlay entry.
            child: Semantics(
              label: AppLocalizations.of(context)!.fullscreenVideo,
              button: true,
              child: Material(
                color: Colors.black.withValues(alpha: t.opacitySubtle),
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _openFullscreen,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(
                      LucideIcons.maximize,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewFallback(ColorScheme cs, AppLocalizations? l10n) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          child: Center(
            child: Icon(
              LucideIcons.video,
              size: 40,
              color: cs.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
        if (_downloadFuture != null)
          const Positioned(
            bottom: 8,
            left: 0,
            right: 0,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
      ],
    );
  }
}
