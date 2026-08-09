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

import 'package:flutter/material.dart';
import 'package:moonrelay/src/settings/theme_spec.dart';
import 'package:moonrelay/src/theme/component_tokens.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';

/// Custom design tokens that fall outside Material 3's [ColorScheme].
///
/// Access via `Theme.of(context).extension<MoonrelayThemeExtension>()`.
///
/// Carries the full token hierarchy: atomic [MoonrelayDesignTokens],
/// per-component [MoonrelayComponentTokens], and the monospace font family.
@immutable
class MoonrelayThemeExtension extends ThemeExtension<MoonrelayThemeExtension> {
  /// Material-default tokens used when a host theme does not carry the
  /// Moonrelay extension (e.g. a bare MaterialApp in widget tests).
  static final MoonrelayThemeExtension _fallback = _buildFallback();

  /// Resolves the extension from [context], falling back to material
  /// defaults when the host theme does not carry it.
  static MoonrelayThemeExtension of(BuildContext context) =>
      Theme.of(context).extension<MoonrelayThemeExtension>() ?? _fallback;

  /// Resolves the extension from [theme], falling back to material
  /// defaults when [theme] does not carry it.
  static MoonrelayThemeExtension fromTheme(ThemeData theme) =>
      theme.extension<MoonrelayThemeExtension>() ?? _fallback;

  static MoonrelayThemeExtension _buildFallback() {
    final spec = MoonrelayThemes.material;
    final tokens = MoonrelayDesignTokens.fromSpec(spec);
    return MoonrelayThemeExtension(
      monoFontFamily: 'FiraCode',
      tokens: tokens,
      components: MoonrelayComponentTokens.fromDesignTokens(tokens, spec),
    );
  }

  /// Font family for monospace text (code blocks, etc.).
  final String monoFontFamily;

  /// Atomic visual constants (spacing, elevation, shadows, radii, etc.).
  final MoonrelayDesignTokens tokens;

  /// Per-component semantic tokens (button, input, card, chat, etc.).
  final MoonrelayComponentTokens components;

  const MoonrelayThemeExtension({
    required this.monoFontFamily,
    required this.tokens,
    required this.components,
  });

  @override
  MoonrelayThemeExtension copyWith({
    String? monoFontFamily,
    MoonrelayDesignTokens? tokens,
    MoonrelayComponentTokens? components,
  }) {
    return MoonrelayThemeExtension(
      monoFontFamily: monoFontFamily ?? this.monoFontFamily,
      tokens: tokens ?? this.tokens,
      components: components ?? this.components,
    );
  }

  @override
  MoonrelayThemeExtension lerp(
    covariant MoonrelayThemeExtension? other,
    double t,
  ) {
    if (other is! MoonrelayThemeExtension) return this;
    return MoonrelayThemeExtension(
      monoFontFamily: t < 0.5 ? monoFontFamily : other.monoFontFamily,
      tokens: tokens.lerp(other.tokens, t),
      components: t < 0.5 ? components : other.components,
    );
  }
}

/// Convenience accessor so call sites can write `theme.moonrelay.tokens`
/// instead of the null-checked extension lookup.
extension MoonrelayThemeDataX on ThemeData {
  MoonrelayThemeExtension get moonrelay =>
      MoonrelayThemeExtension.fromTheme(this);
}
