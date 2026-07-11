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
