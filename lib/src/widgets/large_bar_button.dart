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

import 'package:fluent_ui/fluent_ui.dart';

class LargeBarButton extends StatelessWidget {
  const LargeBarButton({
    super.key,
    required this.onTap,
    required this.title,
    this.subTitle,
    required this.icon,
    this.decoration,
  });
  final Icon icon;
  final String title;
  final String? subTitle;
  final Function onTap;
  final BoxDecoration? decoration;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap,
      child: Container(
        decoration: decoration,
        padding: const EdgeInsets.all(8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CircleAvatar(
              child: icon,
            ),
            const SizedBox(
              width: 8.0,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: FluentTheme.of(context).typography.title,
                ),
                const SizedBox(
                  height: 2.0,
                ),
                if (subTitle != null)
                  Text(
                    subTitle ?? "",
                    style: FluentTheme.of(context).typography.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
