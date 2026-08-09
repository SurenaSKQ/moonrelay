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

import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/theme_spec.dart';

/// "Darkened Windows Vista UI" look: near-square corners, Segoe UI font and a
/// comfortable density, plus a [MoonrelayWidgetStyle.vista] that re-styles
/// buttons, checkboxes, scrollbars and dividers with Vista's flat, bordered
/// chrome.
///
/// The signature air-force-blue accent (#5C8AA6) is a separate
/// [MoonrelayAccents.vistaBlue] so it can be swapped independently.
const MoonrelayThemeSpec archVistaTheme = MoonrelayThemeSpec(
  id: 'archVista',
  label: 'ArchVista',
  description: 'Darkened Windows Vista UI.',
  defaultFontFamily: 'Segoe UI',
  defaultMonoFontFamily: 'Consolas',
  cornerRadius: 4.0,
  defaultDensity: LayoutDensity.comfortable,
  defaultBubbleRadius: 10.0,
  widgetStyle: MoonrelayWidgetStyle.vista,
);
