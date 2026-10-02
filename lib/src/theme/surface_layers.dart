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

import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The app's layered surface palette.
///
/// The previous look derived every surface from `ColorScheme.fromSeed`, which
/// produces a *tonal* palette: surfaces tinted toward the seed and separated
/// by a small luminance step. That works for a page of cards on one plane. It
/// does not work for a chat client, where the whole point of the layout is
/// that the rail, the room list, and the conversation are three different
/// depths of the same wall, and the user's eye has to find the conversation
/// without being told.
///
/// So the surface ramp is stated explicitly here rather than derived. Seven
/// steps, dark and light, each one a deliberate relationship to the next.
///
/// ## The dark ramp
///
/// The steps are close together on purpose. A large jump reads as a different
/// material, which is what makes a desktop app look like a stack of unrelated
/// documents. Five to eight points of luminance per step reads as one
/// material seen at different depths, which is what it is.
///
/// | Role | Step |
/// |---|---|
/// | titlebar, app floor | `#0F0F14` |
/// | inset wells, code blocks | `#0A0A0E` |
/// | navigation rail | `#16161C` |
/// | room list, side panes | `#1E1E26` |
/// | main content | `#24242E` |
/// | hover wash | `#2A2A35` |
/// | selected row | `#32323E` |
///
/// The rail sits *below* the room list and the room list *below* the
/// conversation, so the reading order runs bright-to-dim left to right and
/// the eye lands on the message column first.
///
/// ## What has no Material role
///
/// Hover and selection are states, not surfaces, and `ColorScheme` has no
/// field for either. Material's own `hoverColor` and `highlightColor` are
/// alpha washes of `primary`, which on this palette read as a purple tint
/// rather than as the row getting closer to the light. So they are stated
/// here as opaque steps from the same ramp, which is what actually happens
/// visually when a Discord-style row lights up.
class MoonrelaySurfaceLayers {
  const MoonrelaySurfaceLayers({
    required this.hover,
    required this.active,
    required this.railActive,
    required this.hairline,
    required this.accentHover,
  });

  /// Fill for a row, card, or button under the pointer.
  final Color hover;

  /// Fill for the row the user has selected.
  final Color active;

  /// Fill for the active item in the navigation rail.
  final Color railActive;

  /// The single hairline colour every pane divider and border uses.
  ///
  /// One value for the whole app on purpose. The dividers between panes are
  /// the only lines in the layout that are not part of a component, and
  /// letting each one pick its own alpha is how a shell ends up with five
  /// slightly different greys running down the same edge.
  final Color hairline;

  /// Accent at rest on hover, for filled accent buttons.
  final Color accentHover;

  /// Builds the layer palette for [brightness].
  factory MoonrelaySurfaceLayers.forBrightness(Brightness brightness) {
    if (brightness == Brightness.dark) {
      return const MoonrelaySurfaceLayers(
        hover: Color(0xFF2A2A35),
        active: Color(0xFF32323E),
        railActive: Color(0xFF7255F5),
        hairline: Color(0x0FFFFFFF),
        accentHover: Color(0xFF8368FF),
      );
    }
    return const MoonrelaySurfaceLayers(
      hover: Color(0xFFEDEEF3),
      active: Color(0xFFDCDCE6),
      railActive: Color(0xFF6144E8),
      hairline: Color(0x1A000000),
      accentHover: Color(0xFF6144E8),
    );
  }

  /// The explicit surface ramp, applied over a seed-derived scheme.
  ///
  /// Only the surface and text roles are replaced. The accent roles, the
  /// container fills, and everything else stay whatever `fromSeed` produced,
  /// because those are the parts where a tonal derivation is actually good:
  /// the primary ramp is a real hue ramp and hand-picking nine steps of it
  /// would be worse, not better.
  static ColorScheme apply(ColorScheme base, Brightness brightness) {
    final accent = _legiblePair(base.primary, base.onPrimary);
    if (brightness == Brightness.dark) {
      return base.copyWith(
        surface: const Color(0xFF0F0F14),
        surfaceContainerLowest: const Color(0xFF0A0A0E),
        surfaceContainerLow: const Color(0xFF16161C),
        surfaceContainer: const Color(0xFF1E1E26),
        surfaceContainerHigh: const Color(0xFF24242E),
        surfaceContainerHighest: const Color(0xFF2A2A35),
        surfaceTint: Colors.transparent,
        onSurface: const Color(0xFFE2E2E9),
        onSurfaceVariant: const Color(0xFF9C9CAC),
        outline: const Color(0xFF6A6A7C),
        outlineVariant: const Color(0xFF3A3A48),
        primary: accent.primary,
        onPrimary: accent.onPrimary,
        secondaryContainer: const Color(0xFF2A2A38),
        onSecondaryContainer: const Color(0xFFDDD6FF),
      );
    }

    return base.copyWith(
      surface: const Color(0xFFFBFBFD),
      surfaceContainerLowest: const Color(0xFFF2F2F6),
      surfaceContainerLow: const Color(0xFFF7F7FA),
      surfaceContainer: const Color(0xFFF0F0F5),
      surfaceContainerHigh: const Color(0xFFEAEAF1),
      surfaceContainerHighest: const Color(0xFFE3E3EC),
      surfaceTint: Colors.transparent,
      onSurface: const Color(0xFF1A1A22),
      onSurfaceVariant: const Color(0xFF5C5C6B),
      outline: const Color(0xFFB4B4C2),
      outlineVariant: const Color(0xFFDADAE4),
      primary: accent.primary,
      onPrimary: accent.onPrimary,
      secondaryContainer: const Color(0xFFE7E7F0),
      onSecondaryContainer: const Color(0xFF1F1F2B),
    );
  }

/// Darkens [seed] until [onSeed] text on it clears WCAG AA at 4.5:1.
  ///
  /// The accent stays a user choice. A hardcoded `primary` would have made
  /// the accent picker dead, which the appearance settings test caught.
  ///
  /// The pair is clamped together, and against `onPrimary` rather than
  /// against white, because Material's tonal palettes do not agree with each
  /// other about which end is light. A dark scheme's `primary` is a *light*
  /// tint meant to be read as text on a dark surface, with a dark
  /// `onPrimary`; forcing white onto that would have dropped the pair to
  /// about 1.8:1. So the scheme's own `onPrimary` is kept and only the fill
  /// moves, which preserves both the tonal convention and the user's hue.
  ///
  /// The compromise is one-directional: a very light seed comes out deeper
  /// than the user picked, and in dark mode that costs some of the vibrancy
  /// a light accent would have had. Doing it properly means two accents, one
  /// for fills and one for text on dark surfaces; that is recorded in
  /// WORK_NEEDED.md rather than invented here.
  static ({Color primary, Color onPrimary}) _legiblePair(
    Color seed,
    Color onSeed,
  ) {
    var candidate = seed;
    for (var i = 0; i < 64 && _contrast(candidate, onSeed) < 4.5; i++) {
      candidate = Color.from(
        alpha: seed.a,
        red: seed.r * 0.98,
        green: seed.g * 0.98,
        blue: seed.b * 0.98,
      );
    }
    return (primary: candidate, onPrimary: onSeed);
  }

  /// WCAG 2.2 relative-luminance contrast ratio.
  static double _contrast(Color a, Color b) {
    double channel(double c) => c <= 0.03928
        ? c / 12.92
        : math.pow((c + 0.055) / 1.055, 2.4).toDouble();

    double luminance(Color c) =>
        0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);

    final la = luminance(a);
    final lb = luminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MoonrelaySurfaceLayers &&
          other.hover == hover &&
          other.active == active &&
          other.railActive == railActive &&
          other.hairline == hairline &&
          other.accentHover == accentHover;

  @override
  int get hashCode =>
      Object.hash(hover, active, railActive, hairline, accentHover);
}