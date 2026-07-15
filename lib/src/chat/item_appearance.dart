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

/// Per-item appearance transition.
///
/// Used to fade newly-paginated history into view at the top of the
/// timeline (the oldest end with `reverse: true`).  When the
/// animations setting is off, the wrapper reduces to its child so the
/// frame budget stays free of unnecessary transitions.
class ItemAppearance extends StatefulWidget {
  const ItemAppearance({super.key, required this.child});
  final Widget child;

  @override
  State<ItemAppearance> createState() => _ItemAppearanceState();
}

class _ItemAppearanceState extends State<ItemAppearance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _slide;
  late Motion _motion;

  @override
  void initState() {
    super.initState();
    _motion = Motion.of(context);
    _controller = AnimationController(
      vsync: this,
      duration: _motion.duration(MotionDurations.medium),
      value: 0.0,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: _motion.curve());
    // The new event is appended at the *top* of the list (which sits
    // at the top of the viewport with `reverse: true`).  We want it
    // to slide *down* into the viewport, so the slide begins from a
    // small negative-Y offset (offscreen-above) and settles at zero.
    _slide = Tween<Offset>(
      begin: const Offset(0, -0.05),
      end: Offset.zero,
    ).animate(_opacity);
    // Defer the forward() call by one frame so the new widget first
    // paints in its from-state; without this Flutter optimises the
    // starting frame out and the transition is invisible.
    if (_motion.enableAnimations) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // The widget may have been disposed before the next frame was
        // drawn (e.g. when paginated history is removed immediately
        // after insertion); guard with `mounted` to avoid calling
        // forward() on a disposed controller.
        if (mounted) _controller.forward();
      });
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
    if (!_motion.enableAnimations) return widget.child;
    return ClipRect(
      child: FadeTransition(
        opacity: _opacity,
        child: SlideTransition(
          position: _slide,
          child: widget.child,
        ),
      ),
    );
  }
}
