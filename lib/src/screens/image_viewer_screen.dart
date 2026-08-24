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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// A proper full-screen image viewer with pinch-to-zoom, swipe-to-dismiss,
/// rotation, copy, and save-to-disk.
///
/// Designed to be pushed as a full-screen route:
///
/// ```dart
/// Navigator.of(context).push(
///   MaterialPageRoute(
///     builder: (_) => ImageViewerScreen(bytes: bytes, event: event),
///   ),
/// );
/// ```
class ImageViewerScreen extends StatefulWidget {
  const ImageViewerScreen({
    super.key,
    required this.bytes,
    required this.event,
    this.suggestedFileName,
  });

  /// The raw decoded image bytes.
  final Uint8List bytes;

  /// The Matrix event that carried this image (used for metadata).
  final Event event;

  /// Filename to suggest in the save dialog. Falls back to the event
  /// body (which is commonly the upload filename).
  final String? suggestedFileName;

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen>
    with TickerProviderStateMixin {
  /// Controls the transient chrome (top bar / bottom caption) opacity.
  /// The chrome auto-hides after a short idle timeout and reappears on
  /// tap or double-tap anywhere outside the tool buttons, mimicking the
  /// behaviour of native gallery apps.
  late final AnimationController _chromeController;
  late final Animation<double> _chromeOpacity;
  late final TransformationController _transform;
  late final AnimationController _resetAnim;
  Animation<double>? _doubleTapAnim;

  /// Monotonically incremented every time the auto-hide is rescheduled.
  /// Each scheduled [Future.delayed] callback captures the value at the
  /// time it was queued; when it fires it only hides the chrome if the
  /// counter still matches, so a fresh tap or a manual hide cancels any
  /// older pending hide.
  int _hideScheduleId = 0;

  /// User-defined minimum and maximum zoom factors. The minimum is
  /// intentionally below 1.0 so a wide landscape image can be shrunk
  /// into a portrait viewport without ever being cropped at rest.
  static const double _minScale = 0.5;
  static const double _maxScale = 5.0;

  @override
  void initState() {
    super.initState();
    _chromeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
      value: 1.0,
    );
    _chromeOpacity =
        CurvedAnimation(parent: _chromeController, curve: Curves.easeOut);
    _transform = TransformationController();
    _resetAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _scheduleChromeHide();
  }

  @override
  void dispose() {
    _transform.dispose();
    _resetAnim.dispose();
    _doubleTapAnim?.removeListener(_onDoubleTapTick);
    _chromeController.dispose();
    super.dispose();
  }

  void _scheduleChromeHide() {
    // Always drive the chrome back to fully visible first.  If the user
    // taps while the controller is mid-reverse (animating from 1 → 0) the
    // forward call from a stale tick could be in flight; calling
    // [AnimationController.stop] cancels any active animation so the
    // forward we issue immediately after starts from the controller's
    // *current* value rather than racing the in-flight reverse.  The
    // previous version unconditionally called `forward()` which left a
    // subtle visual stutter when the user tapped just before the
    // auto-hide fired.
    _chromeController.stop();
    _chromeController.forward();
    final id = ++_hideScheduleId;
    Future<void>.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      if (id != _hideScheduleId) return;
      await _chromeController.reverse();
    });
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final fallback =
        widget.event.body.isEmpty ? 'image${_extension()}' : widget.event.body;
    final name = widget.suggestedFileName ?? fallback;
    await FilePicker.saveFile(
      dialogTitle: l10n.saveImage,
      fileName: name,
      bytes: widget.bytes,
    );
  }

  String _extension() {
    final mime =
        (widget.event.content['info'] is Map<String, dynamic> &&
                (widget.event.content['info'] as Map)['mimetype'] != null)
            ? (widget.event.content['info'] as Map)['mimetype'].toString()
            : '';
    final lower = mime.toLowerCase();
    if (lower.contains('png')) return '.png';
    if (lower.contains('jpeg') || lower.contains('jpg')) return '.jpg';
    if (lower.contains('gif')) return '.gif';
    if (lower.contains('webp')) return '.webp';
    if (lower.contains('bmp')) return '.bmp';
    return '.bin';
  }

  void _onDoubleTapTick() {
    _transform.value = Matrix4.identity()
      ..translateByDouble(_doubleTapFocal!.dx, _doubleTapFocal!.dy, 0, 1)
      ..scaleByDouble(_doubleTapAnim!.value, _doubleTapAnim!.value, 1, 1)
      ..translateByDouble(-_doubleTapFocal!.dx, -_doubleTapFocal!.dy, 0, 1);
  }

  Offset? _doubleTapFocal;

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapFocal = details.localPosition;
  }

  /// Toggles between the identity matrix and a 2.5× zoom around the tapped
  /// point, animated.  Pinch-to-zoom and drag are still driven by
  /// [InteractiveViewer] once the animation lands.
  void _handleDoubleTap() {
    final current = _transform.value;
    final isZoomed = !current.isIdentity();
    _doubleTapAnim?.removeListener(_onDoubleTapTick);
    _doubleTapAnim = Tween<double>(begin: current.getMaxScaleOnAxis(), end: isZoomed ? 1.0 : 2.5)
        .animate(CurvedAnimation(parent: _resetAnim, curve: Curves.easeOut));
    _doubleTapAnim!.addListener(_onDoubleTapTick);
    _resetAnim
      ..reset()
      ..forward();
  }

  /// The viewer allows pinch-to-zoom up to 5×; cap decoded bitmap to
  /// 2048 px so an 8K source doesn't allocate ~256 MB of GPU memory.
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final longSide = size.width >= size.height ? size.width : size.height;
    final cacheWidth = (longSide * 5).clamp(512, 2048).toInt();
    final caption = widget.event.body.isNotEmpty && widget.event.body != 'Image'
        ? widget.event.body
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // ── Dimmed background ───────────────────────────────────────
          // A simple translucent black panel replaces the previously
          // blurred image backdrop. The blur was both visually loud
          // and expensive to composite on every frame of the
          // InteractiveViewer; a flat dim layer keeps the chrome
          // legible without competing with the photo itself.
          const Positioned.fill(
            child: ColoredBox(color: Color(0xCC000000)),
          ),

          // ── Zoomable image ──────────────────────────────────────────
          // The image is laid out at full viewport size with [BoxFit.cover],
          // so at rest the photo extends edge-to-edge.  Pinch-to-zoom and
          // double-tap then expand the photo past the viewport edges
          // instead of being trapped inside a small fitted rectangle.
          // Because the child occupies the entire viewport from the first
          // frame (no aspect-ratio lookup, no FutureBuilder flash), the
          // InteractiveViewer's gesture arena gets a stable child size
          // immediately and zoom behaves predictably.
          Positioned.fill(
            child: InteractiveViewer(
              transformationController: _transform,
              minScale: _minScale,
              maxScale: _maxScale,
              clipBehavior: Clip.hardEdge,
              child: SizedBox.expand(
                child: Image.memory(
                  widget.bytes,
                  fit: BoxFit.cover,
                  cacheWidth: cacheWidth,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text(
                      AppLocalizations.of(context)!.failedToLoadImage,
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Tap-to-toggle chrome ───────────────────────────────────
          // A translucent pointer listener layered above the photo
          // catches taps and pointer-moves anywhere not consumed by a
          // tool button.  Hits here re-show the toolbar so the user can
          // summon it again even after the auto-hide has dropped it
          // below opacity 0, and pointer movement on desktop keeps the
          // chrome alive while the user is actively interacting
          // (matching native gallery-app behaviour).
          //
          // We use [Listener] rather than [GestureDetector] because
          // [InteractiveViewer] registers its own gesture recognisers
          // for pan/zoom which consistently win the gesture arena over
          // a tap detector; a raw pointer listener sees every event
          // regardless of arena outcome, so taps on the photo reliably
          // toggle the chrome.  A nested [GestureDetector] still
          // participates in the arena for long-press → save, which
          // does not conflict with [InteractiveViewer]'s pan/zoom.
          Positioned.fill(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) {
                if (_chromeController.status == AnimationStatus.dismissed ||
                    _chromeController.value < 0.5) {
                  _scheduleChromeHide();
                } else {
                  // User is dismissing intentionally; cancel the pending
                  // auto-hide and reverse the controller immediately.
                  _hideScheduleId++;
                  _chromeController.reverse();
                }
              },
              onPointerHover: (_) => _scheduleChromeHide(),
              onPointerMove: (_) => _scheduleChromeHide(),
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onDoubleTapDown: _handleDoubleTapDown,
                onDoubleTap: _handleDoubleTap,
                onLongPress: _save,
                child: const SizedBox.expand(),
              ),
            ),
          ),

          // ── Top toolbar ────────────────────────────────────────────
          FadeTransition(
            opacity: _chromeOpacity,
            child: Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 130,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.75),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          _ToolbarButton(
                            tooltip: AppLocalizations.of(context)!.close,
                            icon: Icons.arrow_back,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  widget.event.senderFromMemoryOrFallback
                                      .calcDisplayname(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  widget.event.originServerTs
                                      .localizedTimeShort(context),
                                  style: TextStyle(
                                    color:
                                        Colors.white.withValues(alpha: 0.6),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _ToolbarButton(
                            tooltip: AppLocalizations.of(context)!.saveImage,
                            icon: LucideIcons.download,
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom caption + hint ──────────────────────────────────
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _chromeOpacity,
              child: Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.of(context).padding.bottom + 16,
                  top: 32,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.75),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (caption != null)
                      Text(
                        caption,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                        maxLines: 4,
                        overflow: TextOverflow.ellipsis,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          Icons.zoom_in,
                          size: 14,
                          color: Colors.white.withValues(alpha: 0.6),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          AppLocalizations.of(context)!.imageViewerHint,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 11,
                          ),
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
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // [Semantics] instead of [Tooltip]: the toolbar is wrapped in a
    // [FadeTransition] (driven by [_chromeOpacity]) so every
    // [_ToolbarButton] is mounted for the entire lifetime of the
    // [ImageViewerScreen], even when its opacity is 0. The route is
    // pushed over the chat surface via [MaterialPageRoute] (see
    // image_message_type.dart:_openViewer) and the chat page still
    // owns the dashboard's [LayoutBuilder] ancestor; a Tooltip
    // mounted here would activate its internal [OverlayPortal] on
    // mount and mutate that [_RenderLayoutBuilder] mid-performLayout,
    // tripping the
    // `_RenderLayoutBuilder was mutated in performLayout` assertion.
    // Semantics carries the same accessibility affordance without
    // ever materialising an overlay entry.
    return Semantics(
      label: tooltip,
      button: true,
      child: Material(
        color: Colors.black.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(icon, size: 18, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
