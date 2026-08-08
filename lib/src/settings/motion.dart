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

// Animation gating helpers.
//
// Centralises the "are animations enabled?" decision in one place so the
// settings toggle (and the OS-level reduced-motion preference) can be
// honoured by every animated widget without scattering conditionals.
//
// The recommended pattern is:
//
// ```dart
// final motion = Motion.of(context);
// controller = AnimationController(
//   duration: motion.duration(milliseconds: 220),
//   vsync: this,
// );
// ```
//
// When the user disables animations, all callers receive
// [Duration.zero] and the controller's value jumps immediately to its
// final state.

import 'package:flutter/material.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

/// Default durations used across the app.  Centralised so that the
/// motion budget is consistent and tweakable in one place.
class MotionDurations {
  const MotionDurations._();

  /// Very short cross-fades / row additions (~80ms).
  static const Duration fast = Duration(milliseconds: 80);

  /// Default transition between two surfaces in the same screen (~150ms).
  static const Duration medium = Duration(milliseconds: 150);

  /// Page-level animations such as the timeline scroll bar (~220ms).
  static const Duration slow = Duration(milliseconds: 220);

  /// Bottom-sheet, dialog, and full-screen route (~250ms).
  static const Duration sheet = Duration(milliseconds: 250);
}

/// Resolves animation-related helpers given the current settings.
///
/// A new [Motion] is created on demand via [Motion.of] and re-used by
/// passing the instance to descendant widgets.  The lookup is cheap
/// `Provider.of` for a `ChangeNotifier` is O(1).
class Motion {
  Motion._(this.enableAnimations);

  /// Animations on when the user has not opted out of them.
  factory Motion.of(BuildContext context) {
    // Honour the user's explicit choice first; fall back to "on" when
    // no controller is available yet (e.g. during boot).
    bool enabled = true;
    try {
      enabled = context.read<SettingsController>().enableAnimations;
    } catch (_) {/* not in tree */}
    return Motion._(enabled);
  }

  /// True when animations should be played.
  final bool enableAnimations;

  /// Returns [requested] when animations are enabled, otherwise
  /// [Duration.zero] so callers can pass the result straight to an
  /// [AnimationController] without a `if` check.
  Duration duration(Duration requested) =>
      enableAnimations ? requested : Duration.zero;

  /// Standard curve used across the app.  Returns a constant linear
  /// curve when animations are disabled.
  Curve curve([Curve curve = Curves.easeOutCubic]) =>
      enableAnimations ? curve : Curves.linear;

  /// Wraps a builder so that, when animations are off, the result is
  /// returned immediately without scheduling an [AnimatedSwitcher]
  /// transition.
  ///
  /// Use this when conditionally returning different widgets based on
  /// animation state  calling [AnimatedSwitcher] with a zero duration
  /// still incurs a frame delay on some platforms.
  Widget instantSwap(Widget child, {Key? key}) => enableAnimations
      ? AnimatedSwitcher(
          duration: MotionDurations.fast,
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(key: key, child: child),
        )
      : KeyedSubtree(key: key, child: child);
}
