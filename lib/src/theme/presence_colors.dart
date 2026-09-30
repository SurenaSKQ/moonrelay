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
import 'package:matrix/matrix.dart';

/// Scheme-derived colours for a contact's presence.
///
/// The three surfaces that render presence (the profile header, the
/// member tile, the top-members list) all hardcoded the same pair of
/// saturated greens and ambers, and all three failed WCAG AA as *text*:
/// `0xFF2ECC71` measured 1.84:1 against the chip background and
/// `0xFFF39C12` measured 1.92:1, against a 4.5:1 requirement for body
/// text. The same values were used for the dots, which need 3:1 and
/// also failed. It only looked acceptable because the failures are
/// light-mode-only, and a dark-themed dev machine never shows them.
///
/// Everything here is derived from [ColorScheme] instead, so the colours
/// follow the user's accent and pass in both brightnesses. The tint used
/// for the chip background is built from the same foreground, which
/// keeps the pair consistent by construction.
class PresenceColors {
  const PresenceColors._({
    required this.online,
    required this.away,
    required this.offline,
  });

  /// Foreground for `PresenceType.online`.
  final Color online;

  /// Foreground for `PresenceType.unavailable` ("away").
  final Color away;

  /// Foreground for `PresenceType.offline` and for a null presence.
  final Color offline;

  /// Resolves the colours for [scheme] at the given [presence].
  ///
  /// All three states are returned regardless of [presence], so a caller
  /// can repaint without re-resolving when a presence event arrives.
  factory PresenceColors.of(ColorScheme scheme, PresenceType? presence) {
    return PresenceColors._(
      online: _online(scheme),
      away: _away(scheme),
      offline: scheme.onSurfaceVariant,
    );
  }

  /// The foreground for a single [presence].
  Color forPresence(PresenceType? presence) {
    return switch (presence) {
      PresenceType.online => online,
      PresenceType.unavailable => away,
      _ => offline,
    };
  }

  /// A low-opacity background that reads as a tinted chip behind
  /// [forPresence]'s foreground.
  static Color tint(Color foreground, ColorScheme scheme) {
    return Color.alphaBlend(
      foreground.withValues(alpha: 0.16),
      scheme.surfaceContainerHighest,
    );
  }

  // `secondary` and `tertiary` are scheme roles, so they track the
  // accent the user picked and, unlike a literal hex, are generated
  // against the surface for the current brightness. Neither is a literal
  // "success" green: Material has no such role, and inventing one
  // outside the scheme is what produced the contrast failures.
  static Color _online(ColorScheme scheme) => scheme.secondary;

  static Color _away(ColorScheme scheme) => scheme.tertiary;
}
