// Copyright (C) 2024 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <https://www.gnu.org/licenses/>.

import 'package:azhi_main/src/helpers/azhi_color_palette.dart';
import 'package:azhi_main/src/localization/app_localizations.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LogoWithTextThemed extends StatelessWidget {
  const LogoWithTextThemed({super.key, this.themeModeOverride});
  final Brightness? themeModeOverride;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SvgPicture.asset(
          'assets/images/azhi_logo.svg',
          colorFilter: ColorFilter.mode(
              ((themeModeOverride ?? FluentTheme.of(context).brightness) ==
                      Brightness.dark)
                  ? AzhiColorPalette.cpgWhite
                  : AzhiColorPalette.cpgDark,
              BlendMode.srcIn),
          fit: BoxFit.scaleDown,
        ),
        Text(
          AppLocalizations.of(context)!.projectName,
          style: TextStyle(
              color:
                  ((themeModeOverride ?? FluentTheme.of(context).brightness) ==
                          Brightness.dark)
                      ? AzhiColorPalette.cpgWhite
                      : AzhiColorPalette.cpgDark,
              fontSize: 32,
              fontFamily: 'Oxanium',
              fontWeight: FontWeight.bold,
              backgroundColor: Colors.grey.withAlpha(125)),
          overflow: TextOverflow.clip,
        ),
      ],
    );
  }
}
