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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

class SpaceIdentityCard extends StatelessWidget {
  const SpaceIdentityCard({
    super.key,
    required this.space,
    required this.displayName,
    required this.topic,
    required this.totalMembers,
    required this.scheme,
    required this.textTheme,
  });

  final Room space;
  final String displayName;
  final String topic;
  final int totalMembers;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Card(
      elevation: t.elevationNone,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusLg),
        side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: t.opacitySubtle)),
      ),
      child: Padding(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: AvatarFromUriOrFallbackImage(
                client: space.client,
                avatarUri: space.avatar,
              ),
            ),
            SizedBox(height: t.spaceLg),
            Text(
              displayName,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (topic.isNotEmpty) ...[
              SizedBox(height: t.spaceXs),
              Text(
                topic,
                style: textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            SizedBox(height: t.spaceMd),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                InfoChip(
                  icon: LucideIcons.folder,
                  label: l10n.spaceType,
                  scheme: scheme,
                ),
                InfoChip(
                  icon: LucideIcons.users,
                  label: '$totalMembers ${l10n.members}',
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
