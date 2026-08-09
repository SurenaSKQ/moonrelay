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

import 'package:moonrelay/src/settings/theme_spec.dart';

/// Moonrelay's signature look: a distinctive app bar with an accent-accented
/// bottom indicator, elevated cards with signature shadows, and softly
/// rounded buttons.
///
/// This is the theme that best expresses Moonrelay's brand identity. The
/// [MoonrelayWidgetStyle.moonrelay] style layers a subtly elevated app bar
/// with a primary-colored underline, signature card shadows, and rounded
/// button shapes on top of the shared token system.
const MoonrelayThemeSpec moonrelayTheme = MoonrelayThemeSpec(
  id: 'moonrelay',
  label: 'Moonrelay',
  description: 'Signature look with distinctive app bar and shadows.',
  cornerRadius: 12.0,
  surfaceElevation: 2.0,
  defaultBubbleRadius: 16.0,
  widgetStyle: MoonrelayWidgetStyle.moonrelay,
);
