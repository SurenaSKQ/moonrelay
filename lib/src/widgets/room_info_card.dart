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
import 'package:flutter/widgets.dart';
import 'package:matrix/matrix.dart';

class RoomInfoCard extends StatelessWidget {
  const RoomInfoCard({super.key, required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints.loose(const Size.fromHeight(70)),
      decoration: BoxDecoration(
        color: FluentTheme.of(context).cardColor,
      ),
      child: Row(
        children: [
          // TODO: Fallback image
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: CircleAvatar(
              child: Text(
                room
                    .getLocalizedDisplayname()
                    .toUpperCase()
                    .split(RegExp(' +'))
                    .map((s) => s[0])
                    .take(2)
                    .join(),
              ),
              // (room.avatar != null)
              //     ? Image.network(room.avatar.toString())
              //     : Text(
              //         room.getLocalizedDisplayname()
              //           ..toUpperCase()
              //           ..split(RegExp(' +')).map((s) => s[0]).take(2).join(),
              //       ),
            ),
          ),
          const SizedBox(
            width: 8.0,
          ),
          Flexible(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              // TODO: Configurable text size
              children: [
                Text(
                  room.getLocalizedDisplayname(),
                  style: FluentTheme.of(context).typography.bodyLarge,
                ),
                const SizedBox(
                  height: 4.0,
                ),
                Flexible(
                  child: Text(
                    room.topic,
                    style: FluentTheme.of(context).typography.bodyStrong,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                )
              ],
            ),
          )
        ],
      ),
    );
  }
}
