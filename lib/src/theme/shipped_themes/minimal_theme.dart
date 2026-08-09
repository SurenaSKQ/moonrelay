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

/// Flat, borderless, no-elevation variant for users who want pure content
/// with no surface chrome.
///
/// Square corners, zero surface elevation, thin dividers and borderless buttons
/// give the interface a utility-panel feel. Pairs best with the neutral
/// [MoonrelayAccents.charcoal] accent for a truly monochrome look.
const MoonrelayThemeSpec minimalTheme = MoonrelayThemeSpec(
  id: 'minimal',
  label: 'Minimal',
  description: 'Flat surfaces with no elevation or borders.',
  cornerRadius: 0.0,
  surfaceElevation: 0.0,
  defaultBubbleRadius: 0.0,
  widgetStyle: MoonrelayWidgetStyle.minimal,
);
