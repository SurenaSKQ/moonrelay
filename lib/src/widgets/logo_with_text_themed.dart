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

import 'package:flutter/material.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

class LogoWithTextThemed extends StatelessWidget {
  const LogoWithTextThemed({super.key, this.themeMode});
  final Brightness? themeMode;

  @override
  Widget build(BuildContext context) {
    SettingsController settings = Provider.of<SettingsController>(context);
    bool isLightMode = (settings.themeMode == ThemeMode.light ? true : false);
    if (themeMode != null) isLightMode = themeMode! == Brightness.light;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        ColorFiltered(
          colorFilter: isLightMode
              ? const ColorFilter.matrix(<double>[
                  -1.0, 0.0, 0.0, 0.0, 255.0, //
                  0.0, -1.0, 0.0, 0.0, 255.0, //
                  0.0, 0.0, -1.0, 0.0, 255.0, //
                  0.0, 0.0, 0.0, 1.0, 0.0, //
                ])
              : const ColorFilter.matrix(<double>[
                  1.0, 0.0, 0.0, 0.0, 0.0, //
                  0.0, 1.0, 0.0, 0.0, 0.0, //
                  0.0, 0.0, 1.0, 0.0, 0.0, //
                  0.0, 0.0, 0.0, 1.0, 0.0, //
                ]),
          child: Image(
            image: AssetImage('assets/images/moonrelay_logo.png'),
          ),
        ),
        SizedBox(
          height: 8.0,
        ),
        // Text(
        //   AppLocalizations.of(context)!.projectName,
        //   style: TextStyle(
        //       color: isLightMode
        //           ? MoonrelayColorPalette.cpgDark
        //           : MoonrelayColorPalette.cpgWhite,
        //       fontSize: 32,
        //       fontFamily: 'Oxanium',
        //       fontWeight: FontWeight.bold,
        //       backgroundColor: Colors.grey.withAlpha(125)),
        //   overflow: TextOverflow.clip,
        // ),
      ],
    );
  }
}
