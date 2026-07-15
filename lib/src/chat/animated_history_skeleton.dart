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

import 'package:flutter/material.dart';
import 'package:moonrelay/src/settings/motion.dart';

/// Smoothly-fading block of skeleton tiles shown at the top of the
/// timeline when the user has reached the end of the loaded history
/// and the SDK is paginating more events in.
///
/// The transition is driven by an internal [AnimationController] so
/// the block grows from zero height when the user first scrolls to
/// the end, and collapses back to zero when the SDK clears
/// [Room.prev_batch].  The contained [FadeTransition] makes the
/// placeholders softly appear / disappear instead of snapping.
class AnimatedHistorySkeleton extends StatefulWidget {
  const AnimatedHistorySkeleton({
    super.key,
    required this.show,
    required this.children,
  });

  /// When `true`, the block expands to show the [children].  When
  /// `false`, the block collapses to zero height and the children
  /// are removed from the widget tree once the animation finishes.
  final bool show;
  final List<Widget> children;

  @override
  State<AnimatedHistorySkeleton> createState() =>
      _AnimatedHistorySkeletonState();
}

class _AnimatedHistorySkeletonState extends State<AnimatedHistorySkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;
  late Motion _motion;

  @override
  void initState() {
    super.initState();
    _motion = Motion.of(context);
    _controller = AnimationController(
      vsync: this,
      duration: _motion.duration(MotionDurations.slow),
      value: widget.show ? 1.0 : 0.0,
    );
    _animation = CurvedAnimation(
      parent: _controller,
      curve: _motion.curve(),
    );
  }

  @override
  void didUpdateWidget(covariant AnimatedHistorySkeleton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.show != widget.show) {
      if (widget.show) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // ClipRect keeps the skeleton tiles from peeking out as the
    // block's height animates from zero.  FadeTransition + SizeTransition
    // give us both opacity and height transitions from a single
    // animation value.
    return ClipRect(
      child: SizeTransition(
        axis: Axis.vertical,
        sizeFactor: _animation,
        alignment: const Alignment(-1.0, -1.0),
        child: FadeTransition(
          opacity: _animation,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: widget.children,
          ),
        ),
      ),
    );
  }
}
