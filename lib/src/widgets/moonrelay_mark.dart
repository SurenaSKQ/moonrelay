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
import 'package:flutter_svg/flutter_svg.dart';

/// The Moonrelay mark, drawn from `assets/brand/moonrelay-mark.svg`.
///
/// The SVG is the single source for the geometry. This widget exists only to
/// hand it a colour, and it deliberately does not define a second copy of the
/// paths as a `CustomPainter`: the previous attempt at a mark that the app
/// renders itself would have been two definitions of the same drawing, and the
/// one that ships to users is the one nobody edits.
///
/// The file is line only and strokes with `currentColor`, so the mark has no
/// brand colour of its own and takes [color] from the ramp's `onSurface`. That
/// is the reason it still reads in both brightnesses: a mark with a fixed hex
/// would need two files, and the second one would drift.
class MoonrelayMark extends StatelessWidget {
  const MoonrelayMark({super.key, this.size = 24, this.color});

  final double size;
  final Color? color;

  static const String assetPath = 'assets/brand/moonrelay-mark.svg';

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? Theme.of(context).colorScheme.onSurface;
    return SvgPicture.asset(
      assetPath,
      width: size,
      height: size,
      // The SVG has no fill and strokes with `currentColor`, which
      // `flutter_svg` resolves to black when nothing overrides it. A
      // `ColorFilter.mode` blend paints it with the ramp's colour instead of
      // compositing over it, so the stroke stays crisp rather than picking up
      // the surface behind it.
      colorFilter: ColorFilter.mode(resolved, BlendMode.srcIn),
      semanticsLabel: 'Moonrelay',
      excludeFromSemantics: true,
    );
  }
}
