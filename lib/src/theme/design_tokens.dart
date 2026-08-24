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
import 'package:moonrelay/src/settings/theme_spec.dart';

/// Atomic visual constants derived from a [MoonrelayThemeSpec].
///
/// Tokens encapsulate every magic number that would otherwise appear inline in
/// widgets. They are computed once from the active theme spec and distributed
/// via [MoonrelayThemeExtension] so that any widget can reference
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
    // Border radii (derived from spec.cornerRadius)
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

  // -- Border radii ----------------------------------------------------

  final double radiusXs;
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusFull;

  // -- Factory ---------------------------------------------------------

  /// Derives a complete set of tokens from [spec].
  ///
  /// Fixed values (spacing, opacity, animation) follow Material 3 defaults.
  /// Radius tokens are computed relative to [MoonrelayThemeSpec.cornerRadius].
  factory MoonrelayDesignTokens.fromSpec(MoonrelayThemeSpec spec) {
    final r = spec.cornerRadius;
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
      shadowLow: const [
        BoxShadow(
            color: Color(0x1A000000), blurRadius: 2, offset: Offset(0, 1)),
      ],
      shadowMedium: const [
        BoxShadow(
            color: Color(0x1A000000), blurRadius: 4, offset: Offset(0, 2)),
      ],
      shadowHigh: const [
        BoxShadow(
            color: Color(0x1A000000), blurRadius: 8, offset: Offset(0, 4)),
      ],

      // Opacity
      opacityDisabled: 0.38,
      opacityHover: 0.08,
      opacityFocus: 0.12,
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

      // Border radii (derived from spec cornerRadius)
      radiusXs: (r - 8).clamp(0.0, r),
      radiusSm: (r - 4).clamp(0.0, r),
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
    double? opacityPressed,
    double? opacityDragged,
    double? opacitySubtle,
    double? opacityMuted,
    double? borderWidthThin,
    double? borderWidthMedium,
    double? borderWidthThick,
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
        radiusXs,
        radiusSm,
        radiusMd,
        radiusLg,
        radiusXl,
        radiusFull,
      ]);
}
