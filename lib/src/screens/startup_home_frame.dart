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

import 'package:moonrelay/src/helpers/color_palette.dart';
import 'package:moonrelay/src/widgets/blur_background.dart';
import 'package:moonrelay/src/widgets/logo_with_text_themed.dart';
import 'package:flutter/material.dart';

class StartupHomeFrame extends StatelessWidget {
  const StartupHomeFrame({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        image: DecorationImage(
          // TODO: User selectable image?
          image: AssetImage(
              'assets/images/milad-fakurian-u8Jn2rzYIps-unsplash.jpg'),
          fit: BoxFit.cover,
        ),
      ),
      child: Center(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Flexible(
              flex: 4,
              child: LogoWithTextThemed(
                themeMode: Brightness.dark,
              ),
            ),
            Flexible(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(18.0),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: MoonrelayColorPalette.cpgDarkest.withAlpha(90)),
                  child: BlurBackground(
                    child: SizedBox.expand(
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
