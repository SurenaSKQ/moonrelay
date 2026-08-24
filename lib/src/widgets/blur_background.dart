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

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

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
/// Two things matter for reliable dismissal:
///
///   1. The "card" the user sees (typically a centred dialog body)
///      must mark **itself** as the non-dismissable region.  The
///      previous implementation tried to infer that region by
///      capturing the whole child subtree's render box; that failed
///      because the overlay's blur backdrop is full-screen, so the
///      captured box always contained the tap.
///
///   2. The dismiss detector must observe taps but **not** steal
///      them from descendants that handle their own gestures (text
///      fields, list tiles, ink wells).  [HitTestBehavior.translucent]
///      lets descendants compete in the gesture arena; the dismiss
///      handler only fires when no descendant claimed the tap.
///
/// Both are achieved by combining [_DismissBoundaryScope] with
/// [BarrierDismissBoundary]:
///
///   * [BarrierDismissableOverlay] declares a [GlobalKey] and a
///     [_DismissBoundaryScope] inherited widget so it can later
///     check whether the tap landed on a registered boundary.
///   * [BarrierDismissBoundary] (wrapped around the visible card)
///     registers its own [BuildContext] with that scope.  When the
///     scope later hit-tests a global pointer position, it asks each
///     registered boundary "did this land on you?"; if any returns
///     `true` the overlay does not dismiss.
///
/// Pass [enabled] as `false` for forms that must not be
/// accidentally dismissed (e.g. confirmation dialogs).
class BarrierDismissableOverlay extends StatefulWidget {
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
  State<BarrierDismissableOverlay> createState() =>
      _BarrierDismissableOverlayState();
}

class _BarrierDismissableOverlayState extends State<BarrierDismissableOverlay> {
  /// The set of currently-mounted [BarrierDismissBoundary] widgets.
  /// Each registers its [BuildContext] through
  /// [_DismissBoundaryScope.register]; the overlay walks this list
  /// at tap-time to decide whether the pointer landed on the card.
  final List<_DismissBoundaryEntry> _boundaries =
      <_DismissBoundaryEntry>[];

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return _DismissBoundaryScope(
      register: _register,
      unregister: _unregister,
      child: Listener(
        // Translucent: descendants compete in the gesture arena and
        // win when they have handlers.  When no descendant wins (the
        // tap landed on the dim backdrop, the key handle, or any
        // empty area inside the card boundary that doesn't have a
        // gesture detector) our onPointerDown fires.
        behavior: HitTestBehavior.translucent,
        onPointerDown: _handlePointerDown,
        child: widget.child,
      ),
    );
  }

  void _handlePointerDown(PointerDownEvent event) {
    final boundaries = List<_DismissBoundaryEntry>.from(_boundaries);
    if (boundaries.isEmpty) {
      // No card registered a boundary.  Fall back to the previous
      // Navigator.maybePop behaviour so we still dismiss on
      // outside-tap for overlays that forgot to wrap their card.
      Navigator.of(context).maybePop();
      return;
    }
    for (final entry in boundaries) {
      final ctx = entry.context;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) continue;
      // Hit-test the boundary against the pointer's global position.
      // [contains] returns true only when the position lies inside
      // the box's transformed bounds: a full-screen blur backdrop
      // would say yes, but a centred card with real padding/elevation
      // will not, so this correctly distinguishes "tapped inside the
      // card" from "tapped on the dim backdrop around it".
      if (box.hitTest(
        BoxHitTestResult(),
        position: box.globalToLocal(event.position),
      )) {
        return;
      }
    }
    Navigator.of(context).maybePop();
  }

  void _register(_DismissBoundaryEntry entry) {
    if (!_boundaries.contains(entry)) {
      _boundaries.add(entry);
    }
  }

  void _unregister(_DismissBoundaryEntry entry) {
    _boundaries.remove(entry);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The boundary list is rebuilt via register/unregister from
    // descendants; no extra work needed when the configuration
    // changes.
  }
}

/// Inherited widget exposing the registrar handle of the
/// nearest [BarrierDismissableOverlay] to descendants so they can
/// advertise their non-dismissable area at layout time.
class _DismissBoundaryScope extends InheritedWidget {
  const _DismissBoundaryScope({
    required this.register,
    required this.unregister,
    required super.child,
  });

  final void Function(_DismissBoundaryEntry entry) register;
  final void Function(_DismissBoundaryEntry entry) unregister;

  static _DismissBoundaryScope of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<_DismissBoundaryScope>();
    assert(scope != null,
        'BarrierDismissBoundary used outside a BarrierDismissableOverlay.');
    return scope!;
  }

  @override
  bool updateShouldNotify(_DismissBoundaryScope oldWidget) =>
      register != oldWidget.register || unregister != oldWidget.unregister;
}

/// Lightweight record of one mounted [BarrierDismissBoundary].  The
/// overlay keeps a list of these so it can hit-test each registered
/// card against the pointer's global position when the dismiss
/// detector fires.  The context is nullable so an entry that has been
/// detached from the tree (the boundary was disposed or moved) is
/// safely skipped at hit-test time without requiring the overlay to
/// synchronously unregister it.
class _DismissBoundaryEntry {
  _DismissBoundaryEntry(this.context);
  BuildContext? context;
}

/// Marks a subtree as the non-dismissable region inside a
/// [BarrierDismissableOverlay].
///
/// Wrap the visible "card" or any portion of the overlay that should
/// *not* trigger a dismiss on tap.  Anything outside the wrapper
/// (typically the dim backdrop, the central padding, the close-X in
/// the corner) will dismiss; anything inside this widget will not.
///
/// The widget itself is a no-op render-wise (it inserts a single
/// `RepaintBoundary` so we have a clean render box to hit-test
/// against).  Multiple boundaries are supported: a complex overlay
/// can wrap each interactive area in its own
/// [BarrierDismissBoundary] and they all opt out of the
/// dismiss-on-outside-tap behaviour independently.
class BarrierDismissBoundary extends StatefulWidget {
  const BarrierDismissBoundary({super.key, required this.child});

  final Widget child;

  @override
  State<BarrierDismissBoundary> createState() =>
      _BarrierDismissBoundaryState();
}

class _BarrierDismissBoundaryState extends State<BarrierDismissBoundary> {
  _DismissBoundaryEntry? _entry;
  _DismissBoundaryScope? _scope;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final newScope = _DismissBoundaryScope.of(context);
    if (newScope == _scope) return;
    // Re-bind: unregister from the old scope (if any) and register
    // with the new one.
    if (_scope != null && _entry != null) {
      _scope!.unregister(_entry!);
      _entry = null;
    }
    _scope = newScope;
    _entry = _DismissBoundaryEntry(context);
    _scope!.register(_entry!);
  }

  @override
  void dispose() {
    if (_scope != null && _entry != null) {
      _scope!.unregister(_entry!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(child: widget.child);
  }
}
