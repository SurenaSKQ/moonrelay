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
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

class RoomIdentityCard extends StatelessWidget {
  const RoomIdentityCard({
    super.key,
    required this.room,
    required this.roomType,
    required this.totalMembers,
    required this.scheme,
    required this.textTheme,
  });

  final Room room;
  final String roomType;
  final int totalMembers;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final displayName = room.getLocalizedDisplayname();
    final topic = room.topic;
    final hasTopic = topic.isNotEmpty;

    return Card(
      elevation: t.elevationNone,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusLg),
        side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: t.opacitySubtle)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Large avatar
            SizedBox(
              width: 80,
              height: 80,
              child: AvatarFromUriOrFallbackImage(
                client: room.client,
                avatarUri: room.avatar,
              ),
            ),
            SizedBox(height: t.spaceLg),

            // Display name
            Text(
              displayName,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            SizedBox(height: t.spaceXs),

            // Topic
            if (hasTopic)
              Padding(
                padding: EdgeInsets.only(bottom: t.spaceSm),
                child: Text(
                  topic,
                  style: textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

            SizedBox(height: t.spaceMd),

            // Badge row
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                InfoChip(
                  icon: room.joinRules == JoinRules.public
                      ? Icons.public_rounded
                      : room.joinRules == JoinRules.knock ||
                              room.joinRules == JoinRules.knockRestricted
                          ? Icons.meeting_room_rounded
                          : Icons.lock_rounded,
                  label: roomType,
                  scheme: scheme,
                ),
                InfoChip(
                  icon: Icons.people_rounded,
                  label: '$totalMembers ${l10n.members}',
                  scheme: scheme,
                ),
                if (room.isDirectChat)
                  InfoChip(
                    icon: Icons.person_rounded,
                    label: 'Direct Chat',
                    scheme: scheme,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
