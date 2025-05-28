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
import 'package:moonrelay/src/screens/room_details_page.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/blur_background.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:matrix/matrix.dart';

class RoomInfoCard extends StatelessWidget {
  const RoomInfoCard({super.key, required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showDialog(
        context: context,
        barrierDismissible: true,
        builder: (context) => BlurBackground(
          child: RoomInformations(room: room),
        ),
      ),
      child: Container(
        constraints: BoxConstraints.loose(const Size.fromHeight(80)),
        color: MoonrelayColorPalette.cpgDarker.withAlpha(180),
        child: BlurBackground(
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: AvatarFromUriOrFallbackImage(
                  client: room.client,
                  avatarUri: room.avatar,
                ),
              ),
              const SizedBox(
                width: 8.0,
              ),
              Flexible(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      room.getLocalizedDisplayname(),
                      style: const TextStyle(fontSize: 18, fontFamily: 'Rubik'),
                    ),
                    const SizedBox(
                      height: 4.0,
                    ),
                    Flexible(
                      child: Text(
                        room.topic,
                        style:
                            const TextStyle(fontSize: 16, fontFamily: 'Rubik'),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    )
                  ],
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
