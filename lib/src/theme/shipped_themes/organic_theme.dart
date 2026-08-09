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

/// Soft, generously rounded variant with low elevation and subtle borders.
///
/// Large corner radius, generous list-tile padding and softly elevated
/// surfaces give the interface a friendly, approachable feel.
/// [MoonrelayWidgetStyle.organic] layers rounded scrollbars, rounded chips
/// with a hairline border, and comfortable button heights on top of the
/// shared token system.
const MoonrelayThemeSpec organicTheme = MoonrelayThemeSpec(
  id: 'organic',
  label: 'Organic',
  description: 'Soft, rounded surfaces with subtle shadows.',
  cornerRadius: 20.0,
  surfaceElevation: 1.0,
  defaultDensity: LayoutDensity.comfortable,
  defaultBubbleRadius: 18.0,
  widgetStyle: MoonrelayWidgetStyle.organic,
);
