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

/// The default Material 3 look shared by most accent colours.
///
/// No [MoonrelayWidgetStyle] override: the app keeps Material 3's native
/// component chrome and only layers Moonrelay's token system on top.
const MoonrelayThemeSpec materialTheme = MoonrelayThemeSpec(
  id: 'material',
  label: 'Material',
  description: 'Smooth Material 3 surfaces.',
);
