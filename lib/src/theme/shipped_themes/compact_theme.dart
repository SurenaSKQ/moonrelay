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

/// Tighter, smaller-cornered variant for dense workspaces.
///
/// Compact density and a six-degree corner radius pack more content into the
/// available screen real estate without sacrificing readability.
const MoonrelayThemeSpec compactTheme = MoonrelayThemeSpec(
  id: 'compact',
  label: 'Compact Modern',
  description: 'Slim corners and a compact layout.',
  cornerRadius: 6.0,
  defaultDensity: LayoutDensity.compact,
);
