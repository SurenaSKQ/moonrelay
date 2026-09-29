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
import 'package:moonrelay/src/screens/user_profile.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';

class RoomContextSection extends StatelessWidget {
  const RoomContextSection({
    super.key,
    required this.room,
    required this.roomUser,
    required this.roomUserLoading,
    required this.displayName,
    required this.userId,
    required this.scheme,
    required this.l10n,
  });

  final Room room;
  final User? roomUser;
  final bool roomUserLoading;
  final String displayName;
  final String userId;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InfoSectionHeader(
          icon: LucideIcons.shield,
          title: l10n.roomInfoTitle,
          scheme: scheme,
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: roomUserLoading
                ? const Center(
                    child: Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ))
                : roomUser == null
                    ? Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(
                          l10n.notSet,
                          style: TextStyle(color: scheme.onSurfaceVariant),
                        ),
                      )
                    : RoomContextContent(
                        room: room,
                        roomUser: roomUser!,
                        scheme: scheme,
                        l10n: l10n,
                      ),
          ),
        ),
      ],
    );
  }
}

class RoomContextContent extends StatelessWidget {
  const RoomContextContent({
    super.key,
    required this.room,
    required this.roomUser,
    required this.scheme,
    required this.l10n,
  });

  final Room room;
  final User roomUser;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final membershipLabel = switch (roomUser.membership) {
      Membership.join => null,
      Membership.invite => l10n.invitedBadge,
      Membership.ban => l10n.bannedBadge,
      Membership.knock => l10n.knockingBadge,
      Membership.leave => l10n.leftBadge,
    };

    final roleLabel = roomUser.powerLevel.level >= 100
        ? l10n.adminBadge
        : roomUser.powerLevel.level >= 50
            ? l10n.moderatorBadge
            : null;

    return Column(
      children: [
        ProfileInfoRow(
          icon: LucideIcons.shield,
          label: l10n.powerLevelLabel,
          value: '${roomUser.powerLevel.level}',
          scheme: scheme,
        ),
        if (roleLabel != null) ...[
          const Divider(height: 20),
          ProfileInfoRow(
            icon: LucideIcons.star,
            label: l10n.roleLabel,
            value: roleLabel,
            scheme: scheme,
          ),
        ],
        if (membershipLabel != null) ...[
          const Divider(height: 20),
          ProfileInfoRow(
            icon: LucideIcons.userCheck,
            label: l10n.membershipLabel,
            value: membershipLabel,
            scheme: scheme,
          ),
        ],
      ],
    );
  }
}
