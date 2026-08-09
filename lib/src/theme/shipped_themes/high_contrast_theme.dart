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

/// Sharp-cornered, elevated variant for clarity on large screens.
///
/// Zero corner radius and a half-elevation surface give the UI a crisp,
/// high-contrast look. Pairs best with the neutral [MoonrelayAccents.charcoal].
const MoonrelayThemeSpec highContrastTheme = MoonrelayThemeSpec(
  id: 'highContrast',
  label: 'High Contrast',
  description: 'Sharp corners and elevated surfaces.',
  cornerRadius: 0.0,
  surfaceElevation: 0.5,
);
