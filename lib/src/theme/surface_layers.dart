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
/// | inset wells | `#0A0A0E` |
/// | navigation rail | `#1E1F22` |
/// | room list, side panes | `#2B2D31` |
/// | main content | `#313338` |
/// | composer, raised fields | `#383A40` |
/// | hover wash | `#35373C` |
/// | selected row | `#404249` |
///
/// The rail sits *below* the room list and the room list *below* the
/// conversation, so the reading order runs bright-to-dim left to right and
/// the eye lands on the message column first.
///
/// Note that `hover` and `selected` are *not* steps in the same sequence: a
/// hovered row is one step off its own pane, not a fixed value, so on the
/// conversation plane `#35373C` sits between the plane and its own composer.
/// That is why they are states and not ramp positions, and why they live
/// here rather than in the `ColorScheme`.
///
/// ## The light ramp
///
/// The same relationships, inverted. Each step is the light ramp's answer to
/// the dark ramp's role, so a widget that reads a ramp step works in both
/// brightnesses without a branch.
///
/// ## What has no Material role
///
/// Hover and selection are states, not surfaces, and `ColorScheme` has no
/// field for either. Material's own `hoverColor` and `highlightColor` are
/// alpha washes of `primary`, which on this palette read as a purple tint
/// rather than as the row getting closer to the light. So they are stated
/// here as opaque steps from the same ramp, which is what actually happens
/// visually when a row lights up.
class MoonrelaySurfaceLayers {
  const MoonrelaySurfaceLayers({
    required this.hover,
    required this.active,
    required this.railActive,
    required this.hairline,
    required this.accentHover,
    required this.mediaBackdrop,
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

  /// The backdrop behind a full-screen photo or video.
  ///
  /// The one surface that is *not* taken from the brightness. A viewer is a hole
  /// in the app: the reader is looking at a picture and the picture must not
  /// sit on a light grey rectangle in light mode, because every photograph has
  /// a border invented for it and none of them are that grey.
  ///
  /// It is the app floor rather than pure black. Pure black next to a
  /// photograph with real blacks in it reads as a glowing edge, and pure black
  /// is also the one value a display cannot dim, so a full-screen near-black
  /// panel at maximum brightness is uncomfortable on a laptop at night.
  ///
  /// Stated here rather than written as `Colors.black` at each call site because
  /// both full-screen media surfaces have to agree, and they had not: the image
  /// viewer painted `0xCC000000` over a black scaffold and the video player
  /// painted `Colors.black`, which is a visible seam when one opens from the
  /// other.
  final Color mediaBackdrop;

  /// Builds the layer palette for [brightness].
  ///
  /// [accent] is the user's chosen seed. The two accent-derived values are
  /// computed from it rather than hardcoded, because a rail that stays purple
  /// while the rest of the app follows the accent picker is the kind of thing
  /// that reads as a bug in one of the two places, and never in the palette.
  factory MoonrelaySurfaceLayers.forBrightness(
    Brightness brightness, {
    Color? accent,
  }) {
    // The rail's active tile is a *fill* carrying a white glyph, so it is
    // clamped against white. The scheme's `primary` is clamped against its own
    // `onPrimary` instead, which in dark mode is near-black, so the two
    // accents are deliberately not the same colour: one is a background for
    // white text and the other is text on a background. See [_legibleOn].
    final rail = _legibleOn(
      accent ?? const Color(0xFF7C5DFA),
      Colors.white,
    );

    if (brightness == Brightness.dark) {
      return MoonrelaySurfaceLayers(
        hover: const Color(0xFF35373C),
        active: const Color(0xFF404249),
        railActive: rail.fill,
        hairline: const Color(0x0FFFFFFF),
        accentHover: rail.hover,
        mediaBackdrop: const Color(0xFF0B0B0D),
      );
    }
    return MoonrelaySurfaceLayers(
      hover: const Color(0xFFE0E0E9),
      active: const Color(0xFFCFCFD9),
      railActive: rail.fill,
      hairline: const Color(0x1A000000),
      accentHover: rail.hover,
      // The same value in both brightnesses. See [mediaBackdrop].
      mediaBackdrop: const Color(0xFF0B0B0D),
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
        surfaceContainerLow: const Color(0xFF1E1F22),
        surfaceContainer: const Color(0xFF2B2D31),
        surfaceContainerHigh: const Color(0xFF313338),
        surfaceContainerHighest: const Color(0xFF383A40),
        surfaceTint: Colors.transparent,
        // `#F2F3F5` is the mockup's primary text and clears AA on every
        // step with room to spare.
        onSurface: const Color(0xFFF2F3F5),
        // The mockup's secondary is `#949BA4`, and on its own composer step
        // `#383A40` that is 4.05:1: below the 4.5 that body-sized text has
        // to clear. It is lifted two points to `#9EA5AE`, which is 4.57:1 on
        // the composer and still reads as a cool grey beside the primary
        // rather than as a fourth surface colour. Taking the mockup's value
        // literally would have shipped unreadable placeholder text in the one
        // place it appears most, which is the composer's hint.
        onSurfaceVariant: const Color(0xFF9EA5AE),
        outline: const Color(0xFF6A6A7C),
        outlineVariant: const Color(0xFF3A3A48),
        primary: accent.primary,
        onPrimary: accent.onPrimary,
        secondaryContainer: const Color(0xFF383A40),
        onSecondaryContainer: const Color(0xFFE4E4EC),
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
      secondaryContainer: const Color(0xFFE3E3EC),
      onSecondaryContainer: const Color(0xFF1F1F2B),
    );
  }

  /// Darkens [seed] until [on] text on it clears WCAG AA at 4.5:1, and reports
  /// the slightly lighter step a filled tile takes on hover.
  ///
  /// The step is applied to the *candidate*. It used to be applied to [seed],
  /// which made every pass recompute the same colour from the same original:
  /// the loop spun up to 64 times without the candidate moving, and returned
  /// whatever a single 2% step produced. It looked like a working clamp and
  /// was not one.
  ///
  /// It was latent for `primary`, because `ColorScheme.fromSeed` already hands
  /// back a `primary` and an `onPrimary` between 6.4:1 and 7.8:1 for every
  /// accent in the picker, so the threshold was cleared before the loop
  /// mattered. That is luck, not a property of the loop: the new white pairing
  /// below is a different question and a mid-lightness seed needs ten steps to
  /// answer it, so the same bug would have shipped a rail tile at 3.3:1.
  ///
  /// The result is quantised to 8 bits per channel. `Color.from` takes floats
  /// and keeps them, so a float clamp produces a colour no longer
  /// representable as an ARGB integer, which then differs depending on which
  /// platform computed it and cannot be compared or persisted.
  static ({Color fill, Color hover}) _legibleOn(Color seed, Color on) {
    var candidate = seed;
    for (var i = 0; i < 64 && _contrast(candidate, on) < 4.5; i++) {
      candidate = Color.fromARGB(
        (seed.a * 255).round(),
        (candidate.r * 0.98 * 255).round(),
        (candidate.g * 0.98 * 255).round(),
        (candidate.b * 0.98 * 255).round(),
      );
    }
    return (
      fill: candidate,
      hover: Color.lerp(candidate, on, 0.10)!,
    );
  }

  /// [primary] and [onPrimary], darkened together until the pair clears AA.
  ///
  /// The accent stays a user choice. A hardcoded `primary` would have made
  /// the accent picker dead, which the appearance settings test caught.
  ///
  /// The pair is clamped against `onPrimary` rather than against white,
  /// because Material's tonal palettes do not agree with each other about
  /// which end is light. A dark scheme's `primary` is a *light* tint meant to
  /// be read as text on a dark surface, with a dark `onPrimary`; forcing white
  /// onto that would have dropped the pair to about 1.8:1. So the scheme's own
  /// `onPrimary` is kept and only the fill moves, which preserves both the
  /// tonal convention and the user's hue.
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
    return (primary: _legibleOn(seed, onSeed).fill, onPrimary: onSeed);
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
          other.accentHover == accentHover &&
          other.mediaBackdrop == mediaBackdrop;

  @override
  int get hashCode =>
      Object.hash(
        hover,
        active,
        railActive,
        hairline,
        accentHover,
        mediaBackdrop,
      );
}
