import 'dart:ui';
import 'package:flutter/material.dart';

/// A widget that blurs its background using a [BackdropFilter].
///
/// Optionally applies a dark [overlayColor] to dim the blurred content
/// so that foreground elements (e.g. cards) stand out clearly.
class BlurBackground extends StatelessWidget {
  final Widget child;
  final double sigma;
  final Color? overlayColor;

  const BlurBackground({
    super.key,
    required this.child,
    this.sigma = 15.0,
    this.overlayColor,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        if (overlayColor != null)
          Positioned.fill(child: Container(color: overlayColor)),
        child,
      ],
    );
  }
}

/// Wraps an overlay page so that tapping outside the page's visible
/// content dismisses the surrounding [PageRoute] via [Navigator.maybePop].
///
/// `PageRouteBuilder`'s `barrierDismissible: true` flag is not enough
/// on its own: the page is laid out *over* the barrier in the
/// navigator's overlay, and a [RawGestureDetector] inside the barrier
/// loses the gesture arena to the page's own (passive) widgets.
/// Wrapping the page body in a fullscreen
/// [GestureDetector] with [HitTestBehavior.opaque] guarantees the
/// outside-tap always lands on a dismiss handler, regardless of how
/// the content is laid out.
///
/// Pass [enabled] as `false` for non-dismissible overlays.
class BarrierDismissableOverlay extends StatelessWidget {
  const BarrierDismissableOverlay({
    super.key,
    required this.child,
    this.enabled = true,
  });

  final Widget child;

  /// When `false`, the outside-tap detector is omitted.  Use this for
  /// forms that must not be accidentally dismissed.
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.of(context).maybePop(),
      child: child,
    );
  }
}
