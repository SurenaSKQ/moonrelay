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
/// So the surface ramp is stated explicitly here rather than derived. Six
/// steps, dark and light, each one a deliberate relationship to the next, and
/// both ramps are the same object seen under two suns.
///
/// ## Light: the near side
///
/// The Moon's sunlit face is not white. It is a chalky, faintly warm grey:
/// the highlands are a pale buff, and the maria are basalt that has taken on a
/// brown-grey cast from a billion years of micrometeorite iron. So the light
/// ramp runs moon white at the floor down to mare dust at the composer, and
/// every step is warm rather than the clinical blue-white that "moon" invites
/// people to reach for. Blue-white would also have collided with the accent
/// picker, whose cool accents are the one place the app is allowed to be
/// chromatic.
///
/// | Role | Step |
/// |---|---|
/// | titlebar, app floor | `#F6F4EF` |
/// | inset wells | `#EAE7E0` |
/// | navigation rail | `#F1EEE8` |
/// | room list, side panes | `#E9E6DF` |
/// | main content | `#E2DED6` |
/// | composer, raised fields | `#DAD6CD` |
///
/// The steps are close on purpose. A large jump reads as a different material,
/// which is what makes a desktop app look like a stack of unrelated documents.
/// These sit between 1.05:1 and 1.08:1 apart, which reads as one surface at
/// different depths, which is what it is.
///
/// ## Dark: the far side, and what lights it
///
/// The unlit Moon is not black either, and this is the part worth knowing: on
/// the far side the only light is **earthshine**, sunlight bounced off Earth
/// as seen from the Moon. It is blue-white, and it is why the far side has
/// always been described as glowing rather than as dark. That is the dark
/// ramp. A blue-black rather than a neutral black is not a stylistic reach for
/// "night"; it is what the only light source in that scene is tinted by.
///
/// | Role | Step |
/// |---|---|
/// | titlebar, app floor | `#0C0E14` |
/// | inset wells | `#07090D` |
/// | navigation rail | `#151823` |
/// | room list, side panes | `#1D2029` |
/// | main content | `#242833` |
/// | composer, raised fields | `#2C313D` |
///
/// The rail sits *below* the room list and the room list *below* the
/// conversation, so the reading order runs bright-to-dim left to right and
/// the eye lands on the message column first.
///
/// Note that `hover` and `selected` are *not* steps in the same sequence: a
/// hovered row is one step off its own pane, not a fixed value, so on the
/// conversation plane the hover step sits between the plane and its own
/// composer. That is why they are states and not ramp positions, and why they
/// live here rather than in the `ColorScheme`.
///
/// The light ramp is the dark ramp's answer role for role, so a widget that
/// reads a ramp step works in both brightnesses without a branch.
///
/// ## What has no Material role
///
/// Hover and selection are states, not surfaces, and `ColorScheme` has no
/// field for either. Material's own `hoverColor` and `highlightColor` are
/// alpha washes of `primary`, which on this palette read as a purple tint
/// rather than as the row getting closer to the light. So they are stated
/// here as opaque steps from the same ramp, which is what actually happens
/// visually when a row lights up.
///
/// [glow] has no Material role either and is not a surface at all: it is the
/// earthshine halo, and it is the only value in the theme that is a light
/// source rather than a material. See its own documentation for why it is
/// transparent in light mode.
class MoonrelaySurfaceLayers {
  const MoonrelaySurfaceLayers({
    required this.hover,
    required this.active,
    required this.railActive,
    required this.hairline,
    required this.accentHover,
    required this.mediaBackdrop,
    required this.glow,
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

  /// The earthshine halo: moonlight spilling off a lit thing.
  ///
  /// The only value in the theme that is a light source rather than a
  /// material, which is why it is the only one with no ramp position. It is
  /// drawn as a soft outer shadow behind two things: the active space in the
  /// rail, and the message the keyboard cursor is on. Both are the places
  /// where the app is saying "this one", and a halo says it more quietly than
  /// a brighter fill would.
  ///
  /// Transparent in light mode, deliberately and not as an oversight. Earthshine
  /// is only visible against darkness; the near side of the Moon is lit from
  /// the front by the Sun, and adding a glow there would be drawing a light
  /// source that is not in the scene. The light ramp's two highlighted states
  /// carry their own tint instead.
  final Color glow;

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
        // One step off its own pane rather than a fixed grey. See the class
        // documentation: on the conversation plane this sits between the plane
        // and its own composer.
        hover: const Color(0xFF2B3140),
        active: const Color(0xFF343B4C),
        railActive: rail.fill,
        hairline: const Color(0x14B9C6FF),
        accentHover: rail.hover,
        mediaBackdrop: const Color(0xFF07080C),
        // Earthshine. Blue-white and barely there: this is a halo, and the
        // moment it is strong enough to read as a border it stops being a
        // light and starts being an outline.
        glow: const Color(0x2EDCE8FF),
      );
    }
    return MoonrelaySurfaceLayers(
      hover: const Color(0xFFDBD7CE),
      active: const Color(0xFFCBC6BB),
      railActive: rail.fill,
      // Warm, not neutral. A neutral black hairline over a warm grey step
      // reads as dirt on the surface rather than as a seam between two of them.
      hairline: const Color(0x1F2B2620),
      accentHover: rail.hover,
      // The same value in both brightnesses. See [mediaBackdrop].
      mediaBackdrop: const Color(0xFF07080C),
      glow: const Color(0x00FFFFFF),
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
        surface: const Color(0xFF0C0E14),
        surfaceContainerLowest: const Color(0xFF07090D),
        surfaceContainerLow: const Color(0xFF151823),
        surfaceContainer: const Color(0xFF1D2029),
        surfaceContainerHigh: const Color(0xFF242833),
        surfaceContainerHighest: const Color(0xFF2C313D),
        surfaceTint: Colors.transparent,
        // Earthshine rather than paper white. `#F2F3F5` was a neutral white
        // and read as a bright monitor; this is cooler and a touch dimmer,
        // which is what the only light source in the scene is like. 11.5:1 on
        // the composer's own step, so nothing was traded away to get the cast.
        onSurface: const Color(0xFFEFF1F5),
        // The mockup's secondary is `#949BA4`, which on the old composer step
        // was 4.05:1 and below the 4.5 body-sized text has to clear. It is
        // `#A3A9B8` here and lands at 5.53:1 on the composer while still
        // reading as a cool grey beside the primary rather than as a fifth
        // surface colour.
        onSurfaceVariant: const Color(0xFFA3A9B8),
        outline: const Color(0xFF646C80),
        outlineVariant: const Color(0xFF343A48),
        primary: accent.primary,
        onPrimary: accent.onPrimary,
        secondaryContainer: const Color(0xFF2C313D),
        onSecondaryContainer: const Color(0xFFE2E6EF),
      );
    }

    return base.copyWith(
      surface: const Color(0xFFF6F4EF),
      surfaceContainerLowest: const Color(0xFFEAE7E0),
      surfaceContainerLow: const Color(0xFFF1EEE8),
      surfaceContainer: const Color(0xFFE9E6DF),
      surfaceContainerHigh: const Color(0xFFE2DED6),
      surfaceContainerHighest: const Color(0xFFDAD6CD),
      surfaceTint: Colors.transparent,
      // Warm near-black. The composition of these two greys, not a chosen
      // grey: anything pure grey next to `#F6F4EF` reads as a monitor in a
      // warm room.
      onSurface: const Color(0xFF211F1A),
      onSurfaceVariant: const Color(0xFF585448),
      outline: const Color(0xFFA8A192),
      outlineVariant: const Color(0xFFC9C2B4),
      primary: accent.primary,
      onPrimary: accent.onPrimary,
      secondaryContainer: const Color(0xFFDAD6CD),
      onSecondaryContainer: const Color(0xFF2A271F),
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
        0.2126 * channel(c.r) + 0.7152 * channel(c.g) + 0.0722 * channel(c.b);

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
          other.mediaBackdrop == mediaBackdrop &&
          other.glow == glow;

  @override
  int get hashCode => Object.hash(
        hover,
        active,
        railActive,
        hairline,
        accentHover,
        mediaBackdrop,
        glow,
      );
}
