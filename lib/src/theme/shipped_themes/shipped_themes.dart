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

// Barrel export for every shipped theme definition.
//
// Individual theme specs live in their own files so each look-and-feel can
// be understood in isolation. The MoonrelayThemes registry in
// lib/src/settings/theme_spec.dart imports this barrel to assemble its
// master list.
export 'material_theme.dart';
export 'high_contrast_theme.dart';
export 'compact_theme.dart';
export 'arch_vista_theme.dart';
export 'moonrelay_theme.dart';
