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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// A full-screen image viewer.
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
///
/// ## It fits, it does not crop
///
/// The image is laid out at viewport size with [BoxFit.contain]. It used to be
/// [BoxFit.cover], on the reasoning that a photo should extend edge to edge and
/// that zooming would then "expand it past the viewport". That is a wallpaper
/// behaviour. A viewer whose job is to show someone a picture that crops the
/// picture whenever the aspect ratios disagree means the portrait in a
/// landscape window loses its top and bottom, silently, with no indication
/// that there was more to see.
///
/// ## Zoom is a control, not an instruction
///
/// There used to be a permanent line of text at the bottom saying "pinch to
/// zoom". On a desktop there is no pinch, so the hint described a gesture the
/// reader could not perform and the thing that would actually work was
/// undocumented. There are now buttons, a readout, and keyboard shortcuts. The
/// readout is relative to one-to-one rather than to the fitted size, because a
/// zoom percentage of "fit" is not a zoom percentage.
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
  late final AnimationController _chromeController;
  late final Animation<double> _chromeOpacity;
  late final TransformationController _transform;
  late final AnimationController _zoomAnim;

  /// Drives the animated zoom used by the buttons and `1:1`.
  ///
  /// The buttons change the transform, and without an animation the image jumps
  /// by a visible step. `InteractiveViewer`'s own pinch stays instantaneous
  /// because it is driven by the pointer, which is the right feel for a
  /// gesture the user is still performing.
  Animation<double>? _zoomAnimValue;
  Offset _zoomCentre = Offset.zero;

  /// Natural pixel size of the image, or `null` until the decode completes.
  ///
  /// Needed for two things: the `1:1` control, which is meaningless without
  /// knowing how many device-independent pixels the image really occupies, and
  /// the dimensions in the metadata row. Read once from a codec rather than
  /// from the rendered widget, so it is available before the first frame
  /// settles.
  ui.Size? _natural;

/// Monotonically incremented every time the auto-hide is rescheduled. Each
  /// scheduled callback captures the value at the time it was queued; when it
  /// fires it only hides the chrome if the counter still matches, so a fresh tap
  /// cancels an older pending hide.
  int _hideScheduleId = 0;

  /// The pending auto-hide.
  ///
  /// A `Timer` and not a bare `Future.delayed`, so it can be cancelled. The
  /// delayed future could only be made harmless with a `mounted` check, which
  /// leaves a live three-second timer on the event loop after the route is gone
  /// for every image the user opened and closed.
  Timer? _hideTimer;

  /// User-defined zoom limits. The minimum is below one so a wide image can be
  /// shrunk into a tall viewport without ever being cropped at rest.
  static const double _minScale = 0.5;
  static const double _maxScale = 5.0;

  /// How long the chrome stays up after the last interaction.
  static const Duration _chromeLinger = Duration(seconds: 3);

  /// Upper bound on the decode size.
  ///
  /// An 8K source decoded at full size is roughly 256MB of bitmap, which is
  /// enough to take the app out. `1:1` is therefore best-effort above this:
  /// on a source wider than the cap the control still centres and still stops
  /// at 1:1, it just cannot show every original pixel. The alternative, an
  /// OOM on a large panorama, is worse than a slightly soft one.
  static const int _maxDecodeWidth = 4096;

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
    _transform = TransformationController();
    _zoomAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _readNaturalSize();
    _scheduleChromeHide();
  }

@override
  void dispose() {
    // Before the controller: the pending timer's callback animates it, so a
    // timer left live past its own controller is a use-after-dispose.
    _hideTimer?.cancel();
    _zoomAnimValue?.removeListener(_applyZoom);
    _transform.dispose();
    _zoomAnim.dispose();
    _chromeController.dispose();
    super.dispose();
  }

  /// Reads the image's pixel size from a throwaway codec.
  ///
  /// The codec is disposed immediately; only the numbers are kept. Decoding the
  /// whole image twice would be wasteful, and `instantiateImageCodec` stops at
  /// the header, so this is cheap.
  Future<void> _readNaturalSize() async {
    ui.Codec? codec;
    try {
      codec = await ui.instantiateImageCodec(widget.bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() {
        _natural = Size(
          frame.image.width.toDouble(),
          frame.image.height.toDouble(),
        );
      });
      frame.image.dispose();
    } catch (_) {
      // A codec that will not open is not worth reporting: the image itself
      // renders through `Image.memory`, which has its own error path, and this
      // only ever feeds a zoom control and a dimension label.
    } finally {
      codec?.dispose();
    }
  }

void _scheduleChromeHide() {
    // Always drive the chrome back to fully visible first. `stop` cancels any
    // in-flight reverse so the forward starts from the controller's *current*
    // value rather than racing it, which is where the old version stuttered.
    _chromeController.stop();
    _chromeController.forward();
    final id = ++_hideScheduleId;
    _hideTimer?.cancel();
    _hideTimer = Timer(_chromeLinger, () async {
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
    final info = widget.event.content['info'];
    final mime = info is Map && info['mimetype'] != null
        ? info['mimetype'].toString()
        : '';
    final lower = mime.toLowerCase();
    if (lower.contains('png')) return '.png';
    if (lower.contains('jpeg') || lower.contains('jpg')) return '.jpg';
    if (lower.contains('gif')) return '.gif';
    if (lower.contains('webp')) return '.webp';
    if (lower.contains('bmp')) return '.bmp';
    return '.bin';
  }

  /// The scale that puts one image pixel in one logical pixel.
  ///
  /// `null` until the size is known, which is what keeps the control disabled
  /// rather than making it jump once the decode lands.
  double? get _actualScale {
    final natural = _natural;
    if (natural == null || natural.width == 0 || natural.height == 0) {
      return null;
    }
    final viewport = MediaQuery.sizeOf(context);
    // `BoxFit.contain` scale: the smaller of the two ratios.
    final fitted = (viewport.width / natural.width)
        .clamp(0.0001, double.infinity);
    final fittedY = (viewport.height / natural.height)
        .clamp(0.0001, double.infinity);
    final fit = fitted < fittedY ? fitted : fittedY;
    return 1 / fit;
  }

  /// Animates the transform to [target], scaling around [centre].
  void _animateScaleTo(double target, Offset centre) {
    final current = _transform.value.getMaxScaleOnAxis();
    if ((current - target).abs() < 0.001) return;
    _zoomAnimValue?.removeListener(_applyZoom);
    _zoomCentre = centre;
    _zoomAnimValue = Tween<double>(begin: current, end: target)
        .animate(CurvedAnimation(parent: _zoomAnim, curve: Curves.easeOut));
    _zoomAnimValue!.addListener(_applyZoom);
    _zoomAnim
      ..reset()
      ..forward();
  }

  /// Scales the current transform by [factor] around [centre].
  ///
  /// Composed on the existing matrix rather than replacing it, so repeated
  /// presses multiply instead of resetting. The translation is corrected by the
  /// same factor so the point under the cursor stays under the cursor.
  void _zoomBy(double factor, Offset centre) {
    final matrix = _transform.value.clone();
    final current = matrix.getMaxScaleOnAxis();
    final next = (current * factor).clamp(_minScale, _maxScale);
    final applied = next / current;
    final dx = (1 - applied) * centre.dx;
    final dy = (1 - applied) * centre.dy;
    _transform.value = matrix
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(applied, applied, 1, 1);
    _scheduleChromeHide();
  }

  /// The animated zoom's value written into the transform each tick.
  void _applyZoom() {
    final anim = _zoomAnimValue;
    if (anim == null) return;
    final factor = anim.value;
    _transform.value = Matrix4.identity()
      ..translateByDouble(_zoomCentre.dx, _zoomCentre.dy, 0, 1)
      ..scaleByDouble(factor, factor, 1, 1)
      ..translateByDouble(-_zoomCentre.dx, -_zoomCentre.dy, 0, 1);
  }

  void _resetZoom() {
    _zoomAnimValue?.removeListener(_applyZoom);
    _transform.value = Matrix4.identity();
    _scheduleChromeHide();
  }

  void _toggleActual() {
    final actual = _actualScale;
    if (actual == null) return;
    final current = _transform.value.getMaxScaleOnAxis();
    final viewport = MediaQuery.sizeOf(context);
    final centre = Offset(viewport.width / 2, viewport.height / 2);
    // Already at or past one-to-one: snap back to fitted. Otherwise go to it.
    if (current >= actual * 0.98) {
      _animateScaleTo(1, centre);
    } else {
      _animateScaleTo(
        actual.clamp(_minScale, _maxScale),
        centre,
      );
    }
    _scheduleChromeHide();
  }

  void _onDoubleTap() {
    final current = _transform.value.getMaxScaleOnAxis();
    final centre = _lastDoubleTapFocal ?? Offset.zero;
    if (current > 1.05) {
      _animateScaleTo(1, centre);
    } else {
      _animateScaleTo(2.5, centre);
    }
    _scheduleChromeHide();
  }

  Offset? _lastDoubleTapFocal;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final layers = Theme.of(context).moonrelay.layers;
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final longSide = size.width >= size.height ? size.width : size.height;
    final cacheWidth = (longSide * _maxScale).clamp(512, _maxDecodeWidth).toInt();

    final body = widget.event.body.isNotEmpty && widget.event.body != 'Image'
        ? widget.event.body
        : null;
    final sender = widget.event.senderFromMemoryOrFallback.calcDisplayname();

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The chrome is drawn over a near-black backdrop in both brightnesses,
      // so the system icons must be light in both. Reading the theme's own
      // `systemOverlayStyle` here would give light icons in light mode, where
      // this screen does not exist.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: layers.mediaBackdrop,
        body: Stack(
          children: [
            // -- The image --------------------------------------------
            // Laid out at viewport size and *contained*, so at rest the whole
            // picture is visible whatever the aspect ratios are.
            Positioned.fill(
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: _minScale,
                maxScale: _maxScale,
                clipBehavior: Clip.hardEdge,
                child: SizedBox.expand(
                  child: Image.memory(
                    widget.bytes,
                    fit: BoxFit.contain,
                    cacheWidth: cacheWidth,
                    errorBuilder: (_, __, ___) => Center(
                      child: Text(
                        l10n.failedToLoadImage,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // -- Tap to toggle the chrome ------------------------------
            // A raw `Listener` rather than a `GestureDetector` for the tap,
            // because `InteractiveViewer` registers its own pan and zoom
            // recognisers and wins the arena: a tap detector layered under it
            // never sees the tap. A `Listener` sees every pointer event
            // regardless of arena outcome. The double-tap and the arrow keys
            // are handled separately below.
            Positioned.fill(
              child: Listener(
                behavior: HitTestBehavior.translucent,
                onPointerDown: (_) {
                  if (_chromeController.status == AnimationStatus.dismissed ||
                      _chromeController.value < 0.5) {
                    _scheduleChromeHide();
                  } else {
                    // Intentional dismissal: cancel the pending hide.
                    _hideScheduleId++;
                    unawaited(_chromeController.reverse());
                  }
                },
                onPointerHover: (_) => _scheduleChromeHide(),
                child: GestureDetector(
                  // Double-tap only. A single-tap detector here would never
                  // fire, because `InteractiveViewer` owns the pan and zoom
                  // recognisers and wins the arena; that is why the tap that
                  // toggles the chrome is a raw `Listener` above instead.
                  behavior: HitTestBehavior.translucent,
                  onDoubleTapDown: (details) =>
                      _lastDoubleTapFocal = details.localPosition,
                  onDoubleTap: _onDoubleTap,
                  child: const SizedBox.expand(),
                ),
              ),
            ),

            // -- Keyboard ----------------------------------------------
            // A desktop viewer is driven from the keyboard. Escape and Backspace
            // close, the arrows pan, and `+`/`-`/`0` zoom, because a photo
            // viewer with a "pinch to zoom" hint and no shortcuts is telling
            // its actual audience nothing.
            Positioned.fill(
              child: Focus(
                autofocus: true,
                onKeyEvent: (node, event) => _onKey(node, event),
                child: const SizedBox.expand(),
              ),
            ),

// -- Top bar ----------------------------------------------
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _chromeOpacity,
                child: _ViewerBar(
                  gradient: Alignment.topCenter,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        t.spaceSm,
                        t.spaceXs,
                        t.spaceSm,
                        // Tall enough to fade the controls out rather than
                        // ending the gradient at their last pixel.
                        t.spaceXl * 2,
                      ),
                      child: Row(
                        children: [
                          _ViewerButton(
                            tooltip: l10n.close,
                            icon: LucideIcons.arrowLeft,
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                          SizedBox(width: t.spaceSm),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  sender,
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
                                    color: Colors.white
                                        .withValues(alpha: t.opacitySubtle),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _ViewerButton(
                            tooltip: l10n.saveImage,
                            icon: LucideIcons.download,
                            onPressed: _save,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // -- Bottom bar -------------------------------------------
            // The caption the sender typed, and the facts about the file. The
            // facts replace a permanent line of hint text: they are the only
            // thing down here that is worth the space, and they are still
            // there after the chrome fades because they sit on the gradient
            // rather than in a control.
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: FadeTransition(
                opacity: _chromeOpacity,
                child: _ViewerBar(
                  gradient: Alignment.bottomCenter,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        t.spaceMd,
                        t.spaceXl * 2,
                        t.spaceMd,
                        t.spaceSm,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (body != null) ...[
                            Text(
                              body,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                              ),
                              maxLines: 4,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: t.spaceSm),
                          ],
                          _ViewerMeta(
                            natural: _natural,
                            extension: _extension(),
                            byteLength: widget.bytes.length,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // -- Zoom controls ----------------------------------------
            // Bottom right, out of the way of the caption, and the only part of
            // the chrome that reports state: the readout is what makes the
            // other two buttons mean something.
            FadeTransition(
              opacity: _chromeOpacity,
              child: Align(
                alignment: AlignmentDirectional.bottomEnd,
                child: SafeArea(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      t.spaceSm,
                      t.spaceSm,
                      t.spaceMd,
                      // Clears the bottom bar's gradient.
                      t.spaceXl * 2,
                    ),
                    child: ValueListenableBuilder<Matrix4>(
                      valueListenable: _transform,
                      builder: (context, matrix, _) {
                        final scale = matrix.getMaxScaleOnAxis();
                        final actual = _actualScale;
                        final atFit = (scale - 1).abs() < 0.01;
                        return _ZoomControls(
                          scale: scale,
                          readout: actual == null || actual <= 0
                              ? '${(scale * 100).round()}%'
                              : '${(scale / actual * 100).round()}%',
                          canActual: actual != null,
                          atFit: atFit,
                          onZoomOut: () => _zoomBy(
                            1 / 1.4,
                            size.center(Offset.zero),
                          ),
                          onZoomIn: () =>
                              _zoomBy(1.4, size.center(Offset.zero)),
                          onActual: _toggleActual,
                          onReset: _resetZoom,
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final l10n = AppLocalizations.of(context)!;
    final size = MediaQuery.sizeOf(context);
    final centre = size.center(Offset.zero);

    switch (event.logicalKey) {
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.backspace:
        Navigator.of(context).maybePop();
        return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft:
        _panBy(Offset(48, 0));
      case LogicalKeyboardKey.arrowRight:
        _panBy(Offset(-48, 0));
      case LogicalKeyboardKey.arrowUp:
        _panBy(Offset(0, 48));
      case LogicalKeyboardKey.arrowDown:
        _panBy(Offset(0, -48));
      case LogicalKeyboardKey.add:
      case LogicalKeyboardKey.equal:
        _zoomBy(1.4, centre);
      case LogicalKeyboardKey.minus:
        _zoomBy(1 / 1.4, centre);
      case LogicalKeyboardKey.digit0:
        _resetZoom();
      case LogicalKeyboardKey.digit1:
        _toggleActual();
      case LogicalKeyboardKey.keyS:
        if (HardwareKeyboard.instance.isMetaPressed ||
            HardwareKeyboard.instance.isControlPressed) {
          _save();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      default:
        // `l10n` is read so a missing key set is a compile error rather than
        // a null crash on a key this widget owns.
        assert(l10n.close.isNotEmpty);
        return KeyEventResult.ignored;
    }
    _scheduleChromeHide();
    return KeyEventResult.handled;
  }

  void _panBy(Offset delta) {
    _transform.value = _transform.value.clone()..translateByDouble(
          delta.dx,
          delta.dy,
          0,
          1,
        );
  }
}

/// The gradient a bar's contents sit on.
///
/// A gradient rather than a flat fill so the controls have something to be
/// legible against at the edge of a photograph. It fades out below the
/// controls rather than ending at their last pixel, which is what stops the
/// controls appearing to float on a hard-edged rectangle.
///
/// Takes no position of its own: the caller has to place it with [Positioned]
/// as a *direct* child of the [Stack], and a `Positioned` nested inside the
/// [FadeTransition] that hides it is a `ParentDataWidget` with the wrong
/// ancestor.
class _ViewerBar extends StatelessWidget {
  const _ViewerBar({
    required this.gradient,
    required this.child,
  });

  final Alignment gradient;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: gradient,
          end: gradient == Alignment.topCenter
              ? Alignment.bottomCenter
              : Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.72),
            Colors.transparent,
          ],
        ),
      ),
      child: child,
    );
  }
}

/// The caption and the facts about the file.
///
/// Dimensions, type and size. These replaced a permanent line of hint text that
/// said "pinch to zoom", which on a desktop describes a gesture the reader
/// cannot perform, and which said the same thing on every image forever.
class _ViewerMeta extends StatelessWidget {
  const _ViewerMeta({
    required this.natural,
    required this.extension,
    required this.byteLength,
  });

  /// Natural pixel size, or `null` while unknown.
  final Size? natural;

  final String extension;
  final int byteLength;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final muted = Colors.white.withValues(alpha: t.opacitySubtle);

    final parts = <String>[
      if (natural != null)
        '${natural!.width.toInt()} × ${natural!.height.toInt()}',
      if (extension.isNotEmpty) extension,
      _formatBytes(byteLength),
    ];

    return Wrap(
      spacing: t.spaceSm,
      runSpacing: t.spaceXxs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        for (final part in parts)
          Text(
            part,
            style: TextStyle(
              fontFamily: Theme.of(context).moonrelay.monoFontFamily,
              fontSize: 11,
              color: muted,
            ),
          ),
      ],
    );
  }

  /// Binary kilobytes, so the number agrees with what a file manager says.
  static String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    final kb = bytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(0)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}

/// The zoom controls: out, in, and one-to-one, with a readout.
///
/// One-to-one is the control that makes the rest honest. Without it a user who
/// has zoomed past the point of legibility has no way to say so, and a viewer
/// that cannot tell you whether you are looking at the real pixels is asking
/// you to trust it.
class _ZoomControls extends StatelessWidget {
  const _ZoomControls({
    required this.scale,
    required this.readout,
    required this.canActual,
    required this.atFit,
    required this.onZoomOut,
    required this.onZoomIn,
    required this.onActual,
    required this.onReset,
  });

  final double scale;

  /// Percentage relative to one-to-one, or to the fitted size when the natural
  /// size is not known yet.
  final String readout;

  final bool canActual;
  final bool atFit;
  final VoidCallback onZoomOut;
  final VoidCallback onZoomIn;
  final VoidCallback onActual;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ViewerButton(
            tooltip: l10n.zoomOut,
            icon: LucideIcons.minus,
            onPressed: onZoomOut,
            dense: true,
          ),
          // A fixed width so the pill does not resize as the number changes.
          SizedBox(
            width: 52,
            child: Text(
              readout,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
              ),
            ),
          ),
          _ViewerButton(
            tooltip: l10n.zoomIn,
            icon: LucideIcons.plus,
            onPressed: onZoomIn,
            dense: true,
          ),
          _ViewerButton(
            tooltip: atFit ? l10n.fitToScreen : l10n.actualSize,
            icon: atFit ? LucideIcons.maximize : LucideIcons.scan,
            onPressed: canActual ? onActual : onReset,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// A circular button in the viewer's chrome.
///
/// [Semantics] rather than [Tooltip], deliberately. The whole toolbar is
/// wrapped in a [FadeTransition] driven by the chrome's opacity, so every button
/// stays mounted for the life of the route even at opacity zero, and a `Tooltip`
/// mounted under it materialises an `OverlayPortal` on mount. That has tripped a
/// `_RenderLayoutBuilder was mutated in performLayout` assertion when the route
/// is pushed over a page that owns a `LayoutBuilder`. Semantics carries the
/// same accessible name without ever creating an overlay entry.
class _ViewerButton extends StatelessWidget {
  const _ViewerButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.dense = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final size = dense ? 32.0 : t.minTapTarget;
    return Semantics(
      label: tooltip,
      button: true,
      child: Material(
        color: dense
            ? Colors.transparent
            : Colors.black.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: size,
            height: size,
            child: Icon(
              icon,
              size: dense ? t.iconSizeSmall : t.iconSizeMedium,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

