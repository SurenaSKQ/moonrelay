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

class SpaceCard extends StatelessWidget {
  const SpaceCard(
      {super.key,
      required this.thumbnailURL,
      required this.name,
      required this.subtitle});
  final String thumbnailURL;
  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(
            foregroundImage:
                thumbnailURL.isEmpty ? null : NetworkImage(thumbnailURL),
          ),
          Text(
            name,
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
          Text(
            subtitle,
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ),
    );
  }
}
