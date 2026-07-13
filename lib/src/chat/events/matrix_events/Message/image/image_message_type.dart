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
import 'package:moonrelay/src/helpers/room_media_cache.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/image_viewer_screen.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

/// Displays an image message with a polished thumbnail card and tap-to-open
/// full-screen viewer.
///
/// Sizing rule: the thumbnail is **height-constrained** so wide panoramic
/// images or tall portrait shots both render as a comfortable rectangle
/// instead of stretching to the full timeline width. The image is then
/// scaled with `BoxFit.contain` so its aspect ratio is preserved without
/// cropping  it fits inside the box, not the other way around.
class ImageMessageType extends StatefulWidget {
  const ImageMessageType({super.key, required this.event});
  final Event event;

  @override
  State<ImageMessageType> createState() => _ImageMessageTypeState();
}

class _ImageMessageTypeState extends State<ImageMessageType> {
  Future<MatrixFile>? _downloadFuture;

  bool _autoDownloadResolved = false;

  /// Resolve the room id once for [RoomMediaCache] keying. Falls back
  /// to the event id when the room id isn't yet attached (early in the
  /// sync lifecycle); the cache key is per-event either way.
  String get _roomId {
    try {
      final id = widget.event.roomId;
      if (id == null) return widget.event.eventId;
      return id.isNotEmpty ? id : widget.event.eventId;
    } catch (_) {
      return widget.event.eventId;
    }
  }

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
    // Use the shared cache so multiple State objects for the same
    // event share a single downloaded blob and a single in-flight
    // future. The State no longer holds a long-lived Future — once
    // the cache resolves, the bytes live in the global cache and the
    // State reads them from there.
    _downloadFuture = RoomMediaCache.instance.getOrDownload(
      _roomId,
      widget.event.eventId,
      () => widget.event.downloadAndDecryptAttachment(),
    );
  }

  /// Checks the user's auto-download preference for images.
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

  /// Maximum display size for thumbnails in the timeline. Both axes are
  /// upper bounds  the larger dimension of the image decides the box,
  /// and the smaller dimension follows proportionally.
  ///
  /// Honoured as a fallback when the [SettingsController] cannot be read
  /// (e.g. isolated widget tests).  In production the value comes from
  /// `SettingsController.imageThumbnailMaxPx`.
  static const double _defaultMaxThumbnailDimension = 360;

  /// Image dimensions from the event content's `info` blob.
  int? get _imgWidth => _infoMap['w'] as int? ?? _infoMap['width'] as int?;
  int? get _imgHeight => _infoMap['h'] as int? ?? _infoMap['height'] as int?;

  Map<String, dynamic> get _infoMap => widget.event.content['info'] is Map
      ? widget.event.content['info'] as Map<String, dynamic>
      : const {};

  int? get _fileSize => _infoMap['size'] as int?;

  /// Whether this image is a GIF (animated or static).
  bool get _isGif =>
      (_infoMap['mimetype'] as String?)?.toLowerCase() == 'image/gif';

  /// Computes a height-constrained box size that preserves aspect ratio.
  ///
  /// We pick the larger of the two axes of the source image as the
  /// reference, scale so that reference equals [_maxThumbnailDimension],
  /// and let the other axis follow proportionally. That means:
  ///   - a 1600×900 landscape image renders as 360×202,
  ///   - a 400×900 portrait image renders as 160×360,
  ///   - a 100×100 square renders as 360×360.
  ///
  /// When dimensions are unknown we fall back to a square 240px default.
  Size _imageSize(double maxDim) {
    final w = _imgWidth;
    final h = _imgHeight;
    if (w == null || h == null || w <= 0 || h <= 0) {
      return const Size(240, 240);
    }

    final longSide = w >= h ? maxDim : maxDim * (w / h);
    final shortSide = w >= h ? maxDim * (h / w) : maxDim;
    return Size(longSide, shortSide);
  }

  /// Returns the configured thumbnail max dimension (px).  Falls back to
  /// [_defaultMaxThumbnailDimension] when the [SettingsController] is not
  /// available in the widget tree.
  double _resolveMaxThumbnailDimension() {
    try {
      return context.read<SettingsController>().imageThumbnailMaxPx.toDouble();
    } catch (_) {
      return _defaultMaxThumbnailDimension;
    }
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Opens the full-screen image viewer.
  ///
  /// The push is deferred to the next frame for the same reason as
  /// [MessageActionRunner.showDetails]: stacking a `MaterialPageRoute`
  /// over the router page's `FadeTransition` mid-build mutates render
  /// objects during `performLayout` and trips Flutter's assertions.
  void _openViewer(Uint8List bytes) {
    final event = widget.event;
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute(
      builder: (_) => ImageViewerScreen(
        bytes: bytes,
        event: event,
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      navigator.push(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Fast path: bytes are already in the shared cache (e.g. we
    // previously downloaded the same attachment, or this is a
    // rebuild after the FutureBuilder resolved once). Avoid creating
    // another FutureBuilder — the underlying bytes never go stale.
    final cached =
        RoomMediaCache.instance.get(_roomId, widget.event.eventId);
    if (cached != null && cached.isNotEmpty) {
      return _buildThumbnail(cs, cached);
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

        // Bytes live in the shared cache; release this State's
        // reference to the FutureBuilder's result so the next rebuild
        // uses the fast-path cache lookup above.
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
    final maxDim = _resolveMaxThumbnailDimension();
    final size = _imageSize(maxDim);

    // Cap the decoded bitmap to the rendered box (scaled by device pixel
    // ratio for HiDPI). Without this, Flutter decodes the full source
    // image — a 4032×3024 photo becomes a ~48 MB ui.Image even though
    // it displays at a few hundred logical pixels.
    final dpr = MediaQuery.devicePixelRatioOf(context);

    return GestureDetector(
      onTap: () => _openViewer(bytes),
      child: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        // Wrap the body in a MouseRegion so the metadata overlay (image
        // dimensions + file size) only appears while the user is
        // actually looking at the thumbnail  the rest of the time the
        // image is just the picture itself, no chrome.  Using a
        // stateful widget for the hover state would also work but
        // would require lifting the hover state out of the build
        // method, which complicates the FutureBuilder chain.  A
        // dedicated [_ImageHoverRegion] is the smallest possible
        // change.
        child: _ImageHoverRegion(
          isGif: _isGif,
          imgWidth: _imgWidth,
          imgHeight: _imgHeight,
          fileSize: _fileSize,
          formattedSize: _fileSize == null ? null : _formatSize(_fileSize!),
          child: Image.memory(
            bytes,
            // fitWidth preserves aspect ratio while filling the box
            // horizontally  no more centred letterboxing.  When the
            // image's intrinsic aspect already matches the box (the
            // common case) the picture fills it exactly.
            fit: BoxFit.fitWidth,
            alignment: AlignmentDirectional.centerStart,
            cacheWidth: (size.width * dpr).ceil(),
            errorBuilder: (_, __, ___) => Container(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Icon(
                Icons.image_outlined,
                size: 40,
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Lightweight [MouseRegion] wrapper that shows an informational
/// overlay (GIF badge, dimensions, file size) only while the cursor
/// is over the image.
///
/// Lives next to [ImageMessageType] because the thumbnail widget is
/// stateful and exposing a dedicated stateful widget avoids a refactor
/// of [ImageMessageType] to track hover state in its own
/// `_ImageMessageTypeState`.
class _ImageHoverRegion extends StatefulWidget {
  const _ImageHoverRegion({
    required this.child,
    required this.isGif,
    required this.imgWidth,
    required this.imgHeight,
    required this.fileSize,
    required this.formattedSize,
  });

  final Widget child;
  final bool isGif;
  final int? imgWidth;
  final int? imgHeight;
  final int? fileSize;
  final String? formattedSize;

  @override
  State<_ImageHoverRegion> createState() => _ImageHoverRegionState();
}

class _ImageHoverRegionState extends State<_ImageHoverRegion> {
  final ValueNotifier<bool> _isHovered = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _isHovered.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _isHovered.value = true,
      onExit: (_) => _isHovered.value = false,
      child: Stack(
        children: [
          widget.child,
          if (widget.isGif)
            const Positioned(
              top: 6,
              left: 6,
              child: _GifBadge(),
            ),
          // The hover overlay is the only subtree that re-paints on
          // hover; the image and the GIF badge stay put.
          ValueListenableBuilder<bool>(
            valueListenable: _isHovered,
            builder: (context, hovered, _) {
              if (!hovered || !_hasInfoToShow) {
                return const SizedBox.shrink();
              }
              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Color(0x80000000),
                        Color(0x00000000),
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
                      if (widget.imgWidth != null && widget.imgHeight != null)
                        Text(
                          '${widget.imgWidth}x${widget.imgHeight}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      if (widget.fileSize != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          widget.formattedSize ?? '',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  /// True when there's at least one piece of metadata to display in
  /// the hover overlay.  When the event has no dimensions and no
  /// file size we don't render the gradient at all  the GIF badge
  /// and a clean thumbnail are enough.
  bool get _hasInfoToShow =>
      (widget.imgWidth != null && widget.imgHeight != null) ||
      widget.fileSize != null;
}

/// Small badge that overlays a "GIF" label in the top-left of an
/// image.  Pulled out so the parent Stack can use it via a `const`
/// reference, which keeps the image subtree stable across rebuilds.
class _GifBadge extends StatelessWidget {
  const _GifBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'GIF',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
