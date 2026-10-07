// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:ui';

import 'package:flutter/material.dart';

/// Atomic visual constants for the app's single look.
///
/// Tokens encapsulate every magic number that would otherwise appear inline in
/// widgets. They are computed once by [MoonrelayDesignTokens.standard] and
/// distributed via [MoonrelayThemeExtension] so that any widget can reference
/// `theme.tokens.spaceLg` instead of a bare `16`.
@immutable
class MoonrelayDesignTokens {
  const MoonrelayDesignTokens({
    // Spacing
    required this.spaceXxs,
    required this.spaceXs,
    required this.spaceSm,
    required this.spaceMd,
    required this.spaceLg,
    required this.spaceXl,
    required this.spaceXxl,
    required this.spaceXxxl,
    // Elevation
    required this.elevationNone,
    required this.elevationLow,
    required this.elevationMedium,
    required this.elevationHigh,
    required this.elevationOverlay,
    // Shadows
    required this.shadowLow,
    required this.shadowMedium,
    required this.shadowHigh,
    // Opacity
    required this.opacityDisabled,
    required this.opacityHover,
    required this.opacityFocus,
    required this.opacityFocusRing,
    required this.opacityPressed,
    required this.opacityDragged,
    required this.opacitySubtle,
    required this.opacityMuted,
    // Border widths
    required this.borderWidthThin,
    required this.borderWidthMedium,
    required this.borderWidthThick,
    // Animation
    required this.durationFast,
    required this.durationMedium,
    required this.durationSlow,
    required this.curveStandard,
    required this.curveDecelerate,
    required this.curveAccelerate,
    // Icon sizes
    required this.iconSizeSmall,
    required this.iconSizeMedium,
    required this.iconSizeLarge,
    // Touch targets
    required this.minTapTarget,
    required this.paneBarHeight,
    // Border radii (derived from [baseCornerRadius])
    required this.radiusXs,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusFull,
  });

  // -- Spacing scale (8-point grid) ------------------------------------

  final double spaceXxs;
  final double spaceXs;
  final double spaceSm;
  final double spaceMd;
  final double spaceLg;
  final double spaceXl;
  final double spaceXxl;
  final double spaceXxxl;

  // -- Elevation -------------------------------------------------------

  final double elevationNone;
  final double elevationLow;
  final double elevationMedium;
  final double elevationHigh;
  final double elevationOverlay;

  // -- Shadows ---------------------------------------------------------

  final List<BoxShadow> shadowLow;
  final List<BoxShadow> shadowMedium;
  final List<BoxShadow> shadowHigh;

  // -- Opacity scale ---------------------------------------------------

  final double opacityDisabled;
  final double opacityHover;
  final double opacityFocus;

  /// Keyboard-focus tint, deliberately stronger than [opacityHover].
  ///
  /// The pointer and the keyboard need different treatment because only one
  /// of them can hover. Material's default focus tint sits a few points
  /// above its hover tint, which is too close to tell apart, so a keyboard
  /// user gets roughly the same wash as a mouse user and neither can tell
  /// which state they are in. This is the value the theme's `focusColor`
  /// uses.
  final double opacityFocusRing;
  final double opacityPressed;
  final double opacityDragged;
  final double opacitySubtle;
  final double opacityMuted;

  // -- Border widths ---------------------------------------------------

  final double borderWidthThin;
  final double borderWidthMedium;
  final double borderWidthThick;

  // -- Animation -------------------------------------------------------

  final Duration durationFast;
  final Duration durationMedium;
  final Duration durationSlow;
  final Curve curveStandard;
  final Curve curveDecelerate;
  final Curve curveAccelerate;

  // -- Icon sizes ------------------------------------------------------

  final double iconSizeSmall;
  final double iconSizeMedium;
  final double iconSizeLarge;

  // -- Touch targets ---------------------------------------------------

  final double minTapTarget;

  /// Height of every single-line bar that sits at the edge of a pane: the
  /// window title bar, the navigation pane's header, the room header, the
  /// hub's sub-page header, the single-pane shell's top bar, and the composer
  /// at the bottom of the conversation.
  ///
  /// The conversation is framed by two of these, one above and one below, and
  /// they being the same height is what makes the message list read as framed
  /// rather than stranded between two unrelated strips. They were derived
  /// independently, from a header's own padding and from the composer's
  /// [minTapTarget], and had drifted a few pixels apart.
  ///
  /// This is the single source of truth for "how tall is a bar at the edge of a
  /// pane". It supersedes both `kToolbarHeight` and
  /// [MoonrelayAppBarTokens.toolbarHeight], which claimed the same role at 56
  /// and 48 respectively. Three names for one idea is one more name than a
  /// reader can hold, and every extra one is a place for the panes to drift
  /// apart again.
  ///
  /// The room pane's tab switcher was the one bar I expected to have to
  /// exempt, because it stacks an icon over a label and I assumed that meant
  /// two lines of height. It does not: its content measures 48 (an 18px icon,
  /// a 2px gap, a 10px label at 1.2 line height, and 8px of padding) which fits
  /// inside 52. Stacking and being tall are different properties, and only one
  /// of them is a reason to leave a bar off the token.
  final double paneBarHeight;

  // -- Border radii ----------------------------------------------------

  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusFull;

  // -- Factory ---------------------------------------------------------

  /// The corner radius every rounded surface is derived from.
  ///
  /// Eight pixels, which is the app's standard for cards, buttons, and
  /// inputs. It was twelve, and twelve is a softer, friendlier number for a
  /// page of cards, but the layout this app has is panels and rows rather
  /// than cards on a page, and at twelve the pane corners read as bubbles
  /// around the content instead of as edges of a surface. Eight is also
  /// small enough that a 36px room avatar still clears it visibly, which is
  /// the whole "smoother rounded corners" goal of the current look.
  static const double baseCornerRadius = 8.0;

  /// Width of the icon-only spaces rail.
  ///
  /// Seventy-two, not the sixty-four a Discord server list uses, because this
  /// rail also carries the account avatar at the bottom and a 48px space
  /// icon plus twelve of gutter each side wants the extra room.
  static const double navRailWidth = 72.0;

  /// Diameter of a space icon in the rail.
  static const double spaceIconSize = 48.0;

  /// Inset of the active rail indicator from the rail's leading edge.
  static const double railIndicatorInset = 12.0;

  /// Light-theme shadows: a tight contact shadow directly under a wider,
  /// weaker ambient one.
  ///
  /// The split between the two layers matters more than either opacity. A
  /// single soft shadow reads as a glow around an object; a contact shadow
  /// directly beneath a broad ambient one reads as a surface sitting above
  /// another. One layer cannot do both jobs at once.
  static const ({
    List<BoxShadow> low,
    List<BoxShadow> medium,
    List<BoxShadow> high,
  }) _lightShadowScale = (
    low: <BoxShadow>[
      BoxShadow(color: Color(0x0D000000), blurRadius: 1, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x14000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    medium: <BoxShadow>[
      BoxShadow(color: Color(0x0F000000), blurRadius: 2, offset: Offset(0, 1)),
      BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 3)),
    ],
    high: <BoxShadow>[
      BoxShadow(color: Color(0x14000000), blurRadius: 4, offset: Offset(0, 2)),
      BoxShadow(color: Color(0x29000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );

  /// Dark-theme shadows: a faint light rim above a deeper black drop.
  ///
  /// The light numbers do not travel. A drop shadow is black, and the dark
  /// surfaces these land on are themselves nearly black, so at 8% to 16%
  /// black the shadow is arithmetically present and visually absent: the
  /// message bubble, the room-filter pill and the profile pill all read as
  /// flat fills in dark mode while lifting correctly in light mode.
  ///
  /// Dark needs the opposite cue. The drop is deepened well past anything
  /// the light theme uses, because the contrast available to it is that much
  /// lower, and a low-alpha white rim is added above the surface. The rim is
  /// the part that actually reads: it is the lit top edge of a raised plane,
  /// which is how depth survives on a dark background.
  ///
  /// The rim sits at a negative y offset so it does not stack on top of the
  /// drop it belongs to.
  ///
  /// **Material's `elevation` is not part of this scale and cannot be made
  /// part of it.** A widget given `elevation: 4` does not consult these
  /// lists; it renders `kElevationToShadow[4]`, a hardcoded three-layer map
  /// of pure black in `material/shadows.dart`. `ThemeData.shadowColor` does
  /// not reach it. That is why the popup menus (`elevationOverlay`), the
  /// timeline FABs (`elevationHigh`) and the profile overlay are still flat
  /// in dark mode while the message bubble and the two pills are raised.
  ///
  /// Closing that means stopping at `elevation:` for anything that needs
  /// depth and passing `shadowLow` / `shadowMedium` / `shadowHigh` directly.
  /// There are roughly seventy `elevation:` call sites and most of them ask
  /// for zero, so the change is mechanical but wide.
  static const ({
    List<BoxShadow> low,
    List<BoxShadow> medium,
    List<BoxShadow> high,
  }) _darkShadowScale = (
    low: <BoxShadow>[
      BoxShadow(color: Color(0x0DFFFFFF), blurRadius: 1, offset: Offset(0, -1)),
      BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    medium: <BoxShadow>[
      BoxShadow(color: Color(0x12FFFFFF), blurRadius: 2, offset: Offset(0, -1)),
      BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 3)),
    ],
    high: <BoxShadow>[
      BoxShadow(color: Color(0x1AFFFFFF), blurRadius: 4, offset: Offset(0, -2)),
      BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 8)),
    ],
  );

  /// The one and only token set: Material 3 defaults for spacing, opacity and
  /// animation, with the radius scale derived from [baseCornerRadius].
  ///
  /// [brightness] exists for the shadow scale and nothing else. Every other
  /// token is brightness-independent, and the colour values themselves come
  /// from the `ColorScheme`; a shadow is the exception because it is baked
  /// from a fixed ink colour rather than read from the scheme.
  factory MoonrelayDesignTokens.standard({
    Brightness brightness = Brightness.light,
  }) {
    final r = baseCornerRadius;
    final shadows =
        brightness == Brightness.dark ? _darkShadowScale : _lightShadowScale;
    return MoonrelayDesignTokens(
      // Spacing (8-point grid)
      spaceXxs: 2,
      spaceXs: 4,
      spaceSm: 8,
      spaceMd: 12,
      spaceLg: 16,
      spaceXl: 24,
      spaceXxl: 32,
      spaceXxxl: 48,

      // Elevation
      elevationNone: 0,
      elevationLow: 1,
      elevationMedium: 2,
      elevationHigh: 4,
      elevationOverlay: 8,

      // Shadows
      shadowLow: shadows.low,
      shadowMedium: shadows.medium,
      shadowHigh: shadows.high,

      // Opacity
      opacityDisabled: 0.38,
      opacityHover: 0.08,
      opacityFocus: 0.12,
      opacityFocusRing: 0.20,
      opacityPressed: 0.12,
      opacityDragged: 0.16,
      opacitySubtle: 0.54,
      opacityMuted: 0.12,

      // Border widths
      borderWidthThin: 0.5,
      borderWidthMedium: 1.0,
      borderWidthThick: 1.5,

      // Animation
      durationFast: const Duration(milliseconds: 150),
      durationMedium: const Duration(milliseconds: 250),
      durationSlow: const Duration(milliseconds: 400),
      curveStandard: Curves.easeInOut,
      curveDecelerate: Curves.easeOut,
      curveAccelerate: Curves.easeIn,

      // Icon sizes
      iconSizeSmall: 16,
      iconSizeMedium: 20,
      iconSizeLarge: 24,

      // Touch targets
      minTapTarget: 48,

      // Pane furniture
      paneBarHeight: 52,

      // Border radii (derived from the base corner radius)
      //
      // Offsets rather than a geometric series, because the bottom of the
      // scale used to clamp: at a 12px base, `radiusXs` came out at zero,
      // so the smallest step was not a small radius but a square corner. At
      // a base of 8 the same offsets give 4, which is a real step.
      radiusXs: r - 4,
      radiusSm: r - 2,
      radiusMd: r,
      radiusLg: r + 4,
      radiusXl: r + 8,
      radiusFull: 9999,
    );
  }

  // -- copyWith --------------------------------------------------------

  MoonrelayDesignTokens copyWith({
    double? spaceXxs,
    double? spaceXs,
    double? spaceSm,
    double? spaceMd,
    double? spaceLg,
    double? spaceXl,
    double? spaceXxl,
    double? spaceXxxl,
    double? elevationNone,
    double? elevationLow,
    double? elevationMedium,
    double? elevationHigh,
    double? elevationOverlay,
    List<BoxShadow>? shadowLow,
    List<BoxShadow>? shadowMedium,
    List<BoxShadow>? shadowHigh,
    double? opacityDisabled,
    double? opacityHover,
    double? opacityFocus,
    double? opacityFocusRing,
    double? opacityPressed,
    double? opacityDragged,
    double? opacitySubtle,
    double? opacityMuted,
    double? borderWidthThin,
    double? borderWidthMedium,
    double? borderWidthThick,
    double? paneBarHeight,
    Duration? durationFast,
    Duration? durationMedium,
    Duration? durationSlow,
    Curve? curveStandard,
    Curve? curveDecelerate,
    Curve? curveAccelerate,
    double? iconSizeSmall,
    double? iconSizeMedium,
    double? iconSizeLarge,
    double? minTapTarget,
    double? radiusXs,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusFull,
  }) {
    return MoonrelayDesignTokens(
      spaceXxs: spaceXxs ?? this.spaceXxs,
      spaceXs: spaceXs ?? this.spaceXs,
      spaceSm: spaceSm ?? this.spaceSm,
      spaceMd: spaceMd ?? this.spaceMd,
      spaceLg: spaceLg ?? this.spaceLg,
      spaceXl: spaceXl ?? this.spaceXl,
      spaceXxl: spaceXxl ?? this.spaceXxl,
      spaceXxxl: spaceXxxl ?? this.spaceXxxl,
      elevationNone: elevationNone ?? this.elevationNone,
      elevationLow: elevationLow ?? this.elevationLow,
      elevationMedium: elevationMedium ?? this.elevationMedium,
      elevationHigh: elevationHigh ?? this.elevationHigh,
      elevationOverlay: elevationOverlay ?? this.elevationOverlay,
      shadowLow: shadowLow ?? this.shadowLow,
      shadowMedium: shadowMedium ?? this.shadowMedium,
      shadowHigh: shadowHigh ?? this.shadowHigh,
      opacityDisabled: opacityDisabled ?? this.opacityDisabled,
      opacityHover: opacityHover ?? this.opacityHover,
      opacityFocus: opacityFocus ?? this.opacityFocus,
      opacityFocusRing: opacityFocusRing ?? this.opacityFocusRing,
      opacityPressed: opacityPressed ?? this.opacityPressed,
      opacityDragged: opacityDragged ?? this.opacityDragged,
      opacitySubtle: opacitySubtle ?? this.opacitySubtle,
      opacityMuted: opacityMuted ?? this.opacityMuted,
      borderWidthThin: borderWidthThin ?? this.borderWidthThin,
      borderWidthMedium: borderWidthMedium ?? this.borderWidthMedium,
      borderWidthThick: borderWidthThick ?? this.borderWidthThick,
      durationFast: durationFast ?? this.durationFast,
      durationMedium: durationMedium ?? this.durationMedium,
      durationSlow: durationSlow ?? this.durationSlow,
      curveStandard: curveStandard ?? this.curveStandard,
      curveDecelerate: curveDecelerate ?? this.curveDecelerate,
      curveAccelerate: curveAccelerate ?? this.curveAccelerate,
      iconSizeSmall: iconSizeSmall ?? this.iconSizeSmall,
      iconSizeMedium: iconSizeMedium ?? this.iconSizeMedium,
      iconSizeLarge: iconSizeLarge ?? this.iconSizeLarge,
      minTapTarget: minTapTarget ?? this.minTapTarget,
      paneBarHeight: paneBarHeight ?? this.paneBarHeight,
      radiusXs: radiusXs ?? this.radiusXs,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusFull: radiusFull ?? this.radiusFull,
    );
  }

  // -- lerp ------------------------------------------------------------

  /// Linearly interpolates between two token sets.
  ///
  /// BoxShadow and Curve values are not interpolatable; the midpoint picks
  /// the closer value.
  MoonrelayDesignTokens lerp(MoonrelayDesignTokens? other, double t) {
    if (other is! MoonrelayDesignTokens) return this;
    return MoonrelayDesignTokens(
      spaceXxs: lerpDouble(spaceXxs, other.spaceXxs, t)!,
      spaceXs: lerpDouble(spaceXs, other.spaceXs, t)!,
      spaceSm: lerpDouble(spaceSm, other.spaceSm, t)!,
      spaceMd: lerpDouble(spaceMd, other.spaceMd, t)!,
      spaceLg: lerpDouble(spaceLg, other.spaceLg, t)!,
      spaceXl: lerpDouble(spaceXl, other.spaceXl, t)!,
      spaceXxl: lerpDouble(spaceXxl, other.spaceXxl, t)!,
      spaceXxxl: lerpDouble(spaceXxxl, other.spaceXxxl, t)!,
      elevationNone: lerpDouble(elevationNone, other.elevationNone, t)!,
      elevationLow: lerpDouble(elevationLow, other.elevationLow, t)!,
      elevationMedium: lerpDouble(elevationMedium, other.elevationMedium, t)!,
      elevationHigh: lerpDouble(elevationHigh, other.elevationHigh, t)!,
      elevationOverlay:
          lerpDouble(elevationOverlay, other.elevationOverlay, t)!,
      shadowLow: t < 0.5 ? shadowLow : other.shadowLow,
      shadowMedium: t < 0.5 ? shadowMedium : other.shadowMedium,
      shadowHigh: t < 0.5 ? shadowHigh : other.shadowHigh,
      opacityDisabled: lerpDouble(opacityDisabled, other.opacityDisabled, t)!,
      opacityHover: lerpDouble(opacityHover, other.opacityHover, t)!,
      opacityFocus: lerpDouble(opacityFocus, other.opacityFocus, t)!,
      opacityFocusRing:
          lerpDouble(opacityFocusRing, other.opacityFocusRing, t)!,
      opacityPressed: lerpDouble(opacityPressed, other.opacityPressed, t)!,
      opacityDragged: lerpDouble(opacityDragged, other.opacityDragged, t)!,
      opacitySubtle: lerpDouble(opacitySubtle, other.opacitySubtle, t)!,
      opacityMuted: lerpDouble(opacityMuted, other.opacityMuted, t)!,
      borderWidthThin: lerpDouble(borderWidthThin, other.borderWidthThin, t)!,
      borderWidthMedium:
          lerpDouble(borderWidthMedium, other.borderWidthMedium, t)!,
      borderWidthThick:
          lerpDouble(borderWidthThick, other.borderWidthThick, t)!,
      durationFast: t < 0.5 ? durationFast : other.durationFast,
      durationMedium: t < 0.5 ? durationMedium : other.durationMedium,
      durationSlow: t < 0.5 ? durationSlow : other.durationSlow,
      curveStandard: t < 0.5 ? curveStandard : other.curveStandard,
      curveDecelerate: t < 0.5 ? curveDecelerate : other.curveDecelerate,
      curveAccelerate: t < 0.5 ? curveAccelerate : other.curveAccelerate,
      iconSizeSmall: lerpDouble(iconSizeSmall, other.iconSizeSmall, t)!,
      iconSizeMedium: lerpDouble(iconSizeMedium, other.iconSizeMedium, t)!,
      iconSizeLarge: lerpDouble(iconSizeLarge, other.iconSizeLarge, t)!,
      minTapTarget: lerpDouble(minTapTarget, other.minTapTarget, t)!,
      paneBarHeight: lerpDouble(paneBarHeight, other.paneBarHeight, t)!,
      radiusXs: lerpDouble(radiusXs, other.radiusXs, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t)!,
      radiusFull: lerpDouble(radiusFull, other.radiusFull, t)!,
    );
  }

  // -- == / hashCode --------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MoonrelayDesignTokens &&
        other.spaceXxs == spaceXxs &&
        other.spaceXs == spaceXs &&
        other.spaceSm == spaceSm &&
        other.spaceMd == spaceMd &&
        other.spaceLg == spaceLg &&
        other.spaceXl == spaceXl &&
        other.spaceXxl == spaceXxl &&
        other.spaceXxxl == spaceXxxl &&
        other.elevationNone == elevationNone &&
        other.elevationLow == elevationLow &&
        other.elevationMedium == elevationMedium &&
        other.elevationHigh == elevationHigh &&
        other.elevationOverlay == elevationOverlay &&
        other.opacityDisabled == opacityDisabled &&
        other.opacityHover == opacityHover &&
        other.opacityFocus == opacityFocus &&
        other.opacityFocusRing == opacityFocusRing &&
        other.opacityPressed == opacityPressed &&
        other.opacityDragged == opacityDragged &&
        other.opacitySubtle == opacitySubtle &&
        other.opacityMuted == opacityMuted &&
        other.borderWidthThin == borderWidthThin &&
        other.borderWidthMedium == borderWidthMedium &&
        other.borderWidthThick == borderWidthThick &&
        other.durationFast == durationFast &&
        other.durationMedium == durationMedium &&
        other.durationSlow == durationSlow &&
        other.iconSizeSmall == iconSizeSmall &&
        other.iconSizeMedium == iconSizeMedium &&
        other.iconSizeLarge == iconSizeLarge &&
        other.minTapTarget == minTapTarget &&
        other.paneBarHeight == paneBarHeight &&
        other.radiusXs == radiusXs &&
        other.radiusSm == radiusSm &&
        other.radiusMd == radiusMd &&
        other.radiusLg == radiusLg &&
        other.radiusXl == radiusXl &&
        other.radiusFull == radiusFull;
  }

  @override
  int get hashCode => Object.hashAll([
        spaceXxs,
        spaceXs,
        spaceSm,
        spaceMd,
        spaceLg,
        spaceXl,
        spaceXxl,
        spaceXxxl,
        elevationNone,
        elevationLow,
        elevationMedium,
        elevationHigh,
        elevationOverlay,
        opacityDisabled,
        opacityHover,
        opacityFocus,
        opacityFocusRing,
        opacityPressed,
        opacityDragged,
        opacitySubtle,
        opacityMuted,
        borderWidthThin,
        borderWidthMedium,
        borderWidthThick,
        durationFast,
        durationMedium,
        durationSlow,
        iconSizeSmall,
        iconSizeMedium,
        iconSizeLarge,
        minTapTarget,
        paneBarHeight,
        radiusXs,
        radiusSm,
        radiusMd,
        radiusLg,
        radiusXl,
        radiusFull,
      ]);
}
