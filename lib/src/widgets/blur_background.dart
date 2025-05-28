import 'dart:ui';
import 'package:fluent_ui/fluent_ui.dart';

class BlurBackground extends StatelessWidget {
  final Widget child;

  const BlurBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
              child: Container(
                color: Colors.transparent,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
