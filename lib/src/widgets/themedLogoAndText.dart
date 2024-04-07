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

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class LogoWithTextThemed extends StatelessWidget {
  const LogoWithTextThemed({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/images/azhi_logo.svg',
            colorFilter: ColorFilter.mode(
                (Theme.of(context).brightness == Brightness.dark)
                    ? Colors.white
                    : Colors.black,
                BlendMode.srcIn),
          ),
          Center(
            child: Text(
              'Project Azhi',
              style: TextStyle(
                color: (Theme.of(context).brightness == Brightness.dark)
                    ? Colors.white
                    : Colors.black,
                fontSize: 32,
                fontFamily: 'assets/fonts/variable/JetBrainsMono[wght].ttf',
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
