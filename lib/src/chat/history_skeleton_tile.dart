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

/// Single skeleton message tile used to fill the viewport while older
/// history is being paginated in.
///
/// Mirrors the visual rhythm of a real [TimelineItem] (avatar circle
/// + a body block) but renders as muted rounded rectangles so the
/// user sees feedback without misreading the placeholders for actual
/// messages.  A subtle pulse animation cycles the bar opacity to
/// communicate that loading is in progress; it is disabled when the
/// user has turned off app animations in settings.
class HistorySkeletonTile extends StatefulWidget {
  const HistorySkeletonTile({super.key, required this.barFraction});

  /// Width of the bottom "body" bar as a fraction of the available
  /// width.  Per-tile variance makes the stack look like a real
  /// group of mixed-length messages instead of a regular grid.
  final double barFraction;

  @override
  State<HistorySkeletonTile> createState() => _HistorySkeletonTileState();
}

class _HistorySkeletonTileState extends State<HistorySkeletonTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    final motion = Motion.of(context);
    // Use a slow pulse  the user is waiting for new events so the
    // animation needs to convey "working" without flickering.
    _controller = AnimationController(
      vsync: this,
      duration: motion.duration(const Duration(milliseconds: 1200)),
    );
    _opacity = Tween<double>(
      begin: 0.6,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: motion.curve()));
    if (motion.enableAnimations) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 1.0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final base = scheme.surfaceContainerHighest;
    final width = MediaQuery.of(context).size.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _pulse(
                child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: base,
                shape: BoxShape.circle,
              ),
            )),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _pulse(
                    child: _skeletonBar(
                  width: width * 0.32,
                  height: 13,
                  color: base,
                )),
                const SizedBox(height: 6),
                _pulse(
                    child: _skeletonBar(
                  width: double.infinity,
                  height: 12,
                  color: base,
                )),
                const SizedBox(height: 4),
                _pulse(
                    child: _skeletonBar(
                  width: width * widget.barFraction,
                  height: 12,
                  color: base,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _pulse({required Widget child}) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, c) => Opacity(opacity: _opacity.value, child: child),
    );
  }

  Widget _skeletonBar({
    required double width,
    required double height,
    required Color color,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}
