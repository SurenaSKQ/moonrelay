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

class SpaceCard extends StatelessWidget {
  const SpaceCard(
      {super.key,
      required this.thumbnailURL,
      required this.name,
      required this.subtitle});
  final String thumbnailURL;
  final String name;
  final String subtitle;

// FIXME Text styling, app wide!
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
            // style: ,
          ),
          Text(
            subtitle,
            // style:,
          ),
        ],
      ),
    );
  }
}
