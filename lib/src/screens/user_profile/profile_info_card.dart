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
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/user_profile.dart';

class ProfileInfoCard extends StatelessWidget {
  const ProfileInfoCard({
    super.key,
    required this.displayName,
    required this.userId,
    required this.presence,
    required this.scheme,
    required this.l10n,
  });

  final String displayName;
  final String userId;
  final CachedPresence? presence;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHighest.withValues(alpha: 0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          children: [
            ProfileInfoRow(
              icon: LucideIcons.user,
              label: l10n.displayName,
              value: displayName,
              scheme: scheme,
            ),
            const Divider(height: 20),
            ProfileInfoRow(
              icon: LucideIcons.atSign,
              label: l10n.userIDLabel,
              value: userId,
              scheme: scheme,
              isMono: true,
            ),
            if (presence?.statusMsg != null &&
                presence!.statusMsg!.isNotEmpty) ...[
              const Divider(height: 20),
              ProfileInfoRow(
                icon: LucideIcons.messageSquare,
                label: l10n.statusLabel,
                value: presence!.statusMsg!,
                scheme: scheme,
              ),
            ],
            if (presence?.lastActiveTimestamp != null) ...[
              const Divider(height: 20),
              ProfileInfoRow(
                icon: LucideIcons.clock,
                label: l10n.lastActive,
                value:
                    presence!.lastActiveTimestamp!.relativeTimeShort(context),
                scheme: scheme,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
