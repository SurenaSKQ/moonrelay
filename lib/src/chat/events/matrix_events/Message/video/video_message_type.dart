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
  int? get _videoWidth => coerceJsonInt(_infoMap['w']) ?? coerceJsonInt(_infoMap['width']);
  int? get _videoHeight => coerceJsonInt(_infoMap['h']) ?? coerceJsonInt(_infoMap['height']);

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
      // Portrait — clamp height, follow width.
      final height = maxHeight;
      final width = (height * ratio).clamp(120.0, maxWidth);
      return Size(width, height);
    }
    // Landscape — clamp width, follow height.
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
      final snap = await (_downloadFuture ??=
          RoomMediaCache.instance.getOrDownload(
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
      builder: (_) => _FullscreenVideoPlayer(controller: controller),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      navigator.push(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final prefs = MediaSizePrefs.of(context);
    final playerSize = _playerSize(prefs.videoMax);

    // The video bubble hugs the player + metadata row. No full-row
    // background — both panels have their own subtle fills so the
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
          color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(14),
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
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      _formatSize(_fileSize!),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: cs.onSurfaceVariant
                                            .withValues(alpha: 0.5),
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
                            final isReady =
                                snapshot.connectionState ==
                                        ConnectionState.done &&
                                    !snapshot.hasError;
                            final isWaiting = snapshot.connectionState ==
                                ConnectionState.waiting;
                            return Container(
                              decoration: BoxDecoration(
                                color: cs.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
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
                                        if (isReady &&
                                            snapshot.data != null) {
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
      // tick only re-paints the surface — the metadata row stays put.
      // Without ValueListenableBuilder we'd rebuild the entire Stack
      // (overlays, progress indicator, fullscreen button) at 60Hz.
      return _InitializedPlayer(controller: c, l10n: l10n);
    }

    return _buildPreviewArea(cs, l10n);
  }

  Widget _buildErrorPlayer(ColorScheme cs, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () {
        // Clear the failure flag and kick off a retry — the user
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
                    Colors.black.withValues(alpha: 0.5),
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
          Positioned(
            top: 6,
            right: 6,
            child: Tooltip(
              message: AppLocalizations.of(context)!.fullscreenVideo,
              child: Material(
                color: Colors.black.withValues(alpha: 0.5),
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

/// Subtree that paints the [VideoPlayer] once it's initialized.
/// Wrapped in its own widget so only this subtree rebuilds on each
/// controller value tick — the surrounding metadata row stays put.
class _InitializedPlayer extends StatelessWidget {
  const _InitializedPlayer({required this.controller, required this.l10n});

  final VideoPlayerController controller;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final v = controller.value;
        return MouseRegion(
          child: GestureDetector(
            onTap: () async {
              try {
                if (v.isPlaying) {
                  await controller.pause();
                } else {
                  await controller.play();
                }
              } catch (_) {
                // Swallow controller exceptions — they don't affect
                // the visual state meaningfully and the user can
                // retry by tapping again.
              }
            },
            onDoubleTap: () {
              try {
                final navigator = Navigator.of(context);
                final c = controller;
                final route = MaterialPageRoute(
                  builder: (_) => _FullscreenVideoPlayer(controller: c),
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!navigator.mounted) return;
                  navigator.push(route);
                });
              } catch (_) {
                // Navigator may not be available yet; defer.
              }
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(
                  child: AspectRatio(
                    aspectRatio:
                        v.aspectRatio == 0 ? 1.0 : v.aspectRatio,
                    child: VideoPlayer(controller),
                  ),
                ),
                if (!v.isPlaying)
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
                        onTap: () {
                          final navigator = Navigator.of(context);
                          final c = controller;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            if (!navigator.mounted) return;
                            navigator.push(MaterialPageRoute(
                              builder: (_) =>
                                  _FullscreenVideoPlayer(controller: c),
                            ));
                          });
                        },
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
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: VideoProgressIndicator(
                    controller,
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
      },
    );
  }
}

class _FullscreenVideoPlayer extends StatefulWidget {
  const _FullscreenVideoPlayer({required this.controller});
  final VideoPlayerController controller;

  @override
  State<_FullscreenVideoPlayer> createState() => _FullscreenVideoPlayerState();
}

class _FullscreenVideoPlayerState extends State<_FullscreenVideoPlayer>
    with TickerProviderStateMixin {
  /// Auto-hide chrome (top bar, controls) after the user stops moving the
  /// mouse.  Mirrors native gallery apps so the video is unobstructed most
  /// of the time but the controls are reachable within a second.
  late final AnimationController _chromeController;
  late final Animation<double> _chromeOpacity;

  /// Monotonic counter so stale "hide chrome" futures can't fire after a
  /// fresh user interaction has overwritten the schedule.
  int _hideScheduleId = 0;

  @override
  void initState() {
    super.initState();
    _chromeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: 1.0,
    );
    _chromeOpacity =
        CurvedAnimation(parent: _chromeController, curve: Curves.easeOut);
    _scheduleChromeHide();
  }

  @override
  void dispose() {
    _chromeController.dispose();
    super.dispose();
  }

  void _scheduleChromeHide() {
    _chromeController.stop();
    _chromeController.forward();
    final id = ++_hideScheduleId;
    Future<void>.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      if (id != _hideScheduleId) return;
      await _chromeController.reverse();
    });
  }

  void _showChrome() {
    _hideScheduleId++;
    _scheduleChromeHide();
  }

  void _hideChrome() {
    _hideScheduleId++;
    _chromeController.reverse();
  }

  void _toggleChrome() {
    if (_chromeController.value > 0.5) {
      _hideChrome();
    } else {
      _showChrome();
    }
  }

  Future<void> _togglePlay(VideoPlayerController c) async {
    try {
      if (c.value.isPlaying) {
        await c.pause();
      } else {
        await c.play();
      }
    } catch (_) {
      // Swallow controller failures — the user can retry with another
      // tap.
    }
    if (mounted) _showChrome();
  }

  Future<void> _seekRelative(VideoPlayerController c, Duration delta) async {
    try {
      final target = c.value.position + delta;
      final clamped = target < Duration.zero
          ? Duration.zero
          : target > c.value.duration
              ? c.value.duration
              : target;
      await c.seekTo(clamped);
    } catch (_) {
      // Ignore seek failures.
    }
    if (mounted) _showChrome();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return AnimatedBuilder(
      animation: c,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            children: [
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _togglePlay(c),
                  onDoubleTap: _toggleChrome,
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: c.value.aspectRatio == 0
                          ? 16 / 9
                          : c.value.aspectRatio,
                      child: VideoPlayer(c),
                    ),
                  ),
                ),
              ),
              if (!c.value.isPlaying)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: true,
                    child: Center(
                      child: Container(
                        width: 88,
                        height: 88,
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
                          size: 52,
                        ),
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: FadeTransition(
                  opacity: _chromeOpacity,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              icon: const Icon(
                                Icons.close,
                                color: Colors.white,
                              ),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.4),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${_formatPos(c.value.position)} / '
                                '${_formatPos(c.value.duration)}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontFeatures: [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: FadeTransition(
                  opacity: _chromeOpacity,
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 12,
                      right: 12,
                      top: 8,
                      bottom: MediaQuery.of(context).padding.bottom + 12,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VideoProgressIndicator(
                          c,
                          allowScrubbing: true,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                IconButton(
                                  tooltip: '−10s',
                                  icon: const Icon(
                                    Icons.replay_10_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _seekRelative(
                                    c,
                                    -const Duration(seconds: 10),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '−5s',
                                  icon: const Icon(
                                    Icons.replay_5_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _seekRelative(
                                    c,
                                    -const Duration(seconds: 5),
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  tooltip: '+5s',
                                  icon: const Icon(
                                    Icons.forward_5_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _seekRelative(
                                    c,
                                    const Duration(seconds: 5),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '+10s',
                                  icon: const Icon(
                                    Icons.forward_10_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => _seekRelative(
                                    c,
                                    const Duration(seconds: 10),
                                  ),
                                ),
                                IconButton(
                                  tooltip: c.value.isPlaying ? 'Pause' : 'Play',
                                  icon: Icon(
                                    c.value.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded,
                                    color: Colors.white,
                                    size: 32,
                                  ),
                                  onPressed: () => _togglePlay(c),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatPos(Duration d) {
    if (d == Duration.zero) return '00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
