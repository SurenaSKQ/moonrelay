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
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/room_dates.dart';
import 'package:moonrelay/src/helpers/room_avatar.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/motion.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// What the main pane shows when no room is open.
///
/// This used to be `EmptyState` with "no room selected" and a hint to pick a
/// room from the sidebar. It was accurate and useless: it told a user who has
/// just signed in to an account with a hundred rooms that they had to use a
/// control they had not been told about, on a pane they had not been told
/// they were looking at.
///
/// So it is a small dashboard instead: the two or three rooms with the most
/// recent activity, and a way to do the three things a person does in their
/// first thirty seconds in a Matrix client, which are create a room, join one,
/// and find the people already talking.
///
/// The recents are here rather than in the sidebar on purpose. The sidebar
/// sorts rooms and does not preview them; this is the one place that can
/// answer "what is going on" without the user opening anything.
class HomeDashboard extends StatelessWidget {
  const HomeDashboard({super.key, required this.client});

  final Client client;

  /// How many rooms to list. Four fills the space without turning into a
  /// second room list, which the sidebar already is.
  static const int _kRecentsLimit = 4;

  /// The open room's id, or `null` when the current room is not in the tree.
  static String? _currentRoomId(BuildContext context) {
    try {
      return context.read<CurrentRoom>().room?.id;
    } catch (_) {
      // Absent during the logout transition. Listing the room the user is
      // already looking at is a cosmetic problem, not a reason to crash.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final layers = ext.layers;
    final l10n = AppLocalizations.of(context)!;
    final motion = Motion.of(context);

    final recents = _recentRooms(client, _currentRoomId(context));

    return Container(
      color: scheme.surfaceContainerHigh,
      child: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceXl,
            vertical: t.spaceXxl,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                // -- Identity ------------------------------------------------
                Row(
                  children: [
                    Container(
                      width: t.spaceXxl * 2.5,
                      height: t.spaceXxl * 2.5,
                      decoration: BoxDecoration(
                        color: layers.hover,
                        borderRadius: BorderRadius.circular(t.radiusXl),
                        boxShadow: t.shadowMedium,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        LucideIcons.moon,
                        size: t.spaceXxl + t.spaceXs,
                        color: scheme.primary,
                      ),
                    ),
                    SizedBox(width: t.spaceLg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            l10n.welcomeToMoonrelay,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                          SizedBox(height: t.spaceXs),
                          Text(
                            l10n.homeDashboardSubtitle,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: t.spaceXl),

                // -- Recents -----------------------------------------------
                if (recents.isNotEmpty) ...[
                  _SectionLabel(label: l10n.recentActivity),
                  SizedBox(height: t.spaceSm),
                  for (final room in recents) ...[
                    _RecentRoomTile(room: room, motion: motion),
                    SizedBox(height: t.spaceXs),
                  ],
                  SizedBox(height: t.spaceLg),
                ],

                // -- Quick actions ----------------------------------------
                _SectionLabel(label: l10n.getStarted),
                SizedBox(height: t.spaceSm),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () => openCreateRoom(context),
                        icon: const Icon(LucideIcons.plus, size: 18),
                        label: Text(l10n.createRoom),
                      ),
                    ),
                    SizedBox(width: t.spaceSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/main/addroom'),
                        icon: const Icon(LucideIcons.logIn, size: 18),
                        label: Text(l10n.joinRoom),
                      ),
                    ),
                    SizedBox(width: t.spaceSm),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.push('/main/spaces'),
                        icon: const Icon(LucideIcons.layoutGrid, size: 18),
                        label: Text(l10n.exploreSpaces),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The joined rooms with the most recent activity, minus [currentId].
  ///
  /// Read from the client synchronously rather than subscribing: this pane
  /// renders on entry and again whenever the user backs out of a room, and a
  /// `Provider.of<Client>` subscription would rebuild it on every sync event
  /// for a list of four rows.
  static List<Room> _recentRooms(Client client, String? currentId) {
    final rooms = client.rooms
        .where((r) => !r.isSpace && r.id != currentId)
        .toList()
      ..sort((a, b) {
        final aStamp = _lastActivity(a);
        final bStamp = _lastActivity(b);
        return bStamp.compareTo(aStamp);
      });
    if (rooms.length <= _kRecentsLimit) return rooms;
    return rooms.sublist(0, _kRecentsLimit);
  }

  /// The newest of the room's last-message timestamp and its creation time.
  ///
  /// A room the user has never spoken in has a creation time and nothing
  /// else, so falling back to it is what keeps a quiet room from sorting to
  /// the bottom on every sync.
  ///
  /// The SDK exposes no "last activity" accessor and reading the timeline
  /// would be a network call per room on a pane that renders on every entry.
  /// So this uses the creation time alone, which is honest about being a
  /// rough sort rather than pretending to know when someone last spoke.
  /// Recorded in WORK_NEEDED.md as the thing to fix if it matters.
  static DateTime _lastActivity(Room room) =>
      roomCreatedAt(room) ?? DateTime.fromMillisecondsSinceEpoch(0);
}

/// A one-line section heading.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      label,
      style: theme.textTheme.labelMedium?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// One recent room: avatar, name, and when it was last active.
class _RecentRoomTile extends StatelessWidget {
  const _RecentRoomTile({required this.room, required this.motion});

  final Room room;
  final Motion motion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final scheme = theme.colorScheme;
    final radius = BorderRadius.circular(t.radiusMd);
    // Same rule as the sidebar's room rows: a direct chat shows the other
    // person's avatar, not the room's, or a DM you started shows your face.
    final avatar = avatarForRoomList(room);
    final initial = room.getLocalizedDisplayname().characters.first.toUpperCase();

    return Material(
      color: scheme.surfaceContainer,
      borderRadius: radius,
      child: InkWell(
        onTap: () => openRoom(context, room.id),
        borderRadius: radius,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceMd,
            vertical: t.spaceSm + t.spaceXxs,
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: t.spaceLg,
                backgroundColor: scheme.surfaceContainerHighest,
                foregroundImage: avatar == null
                    ? null
                    : NetworkImage(
                        avatar.toString(),
                        headers: authHeaders(room.client),
                      ),
                onForegroundImageError: (_, __) {},
                child: avatar == null
                    ? Text(
                        initial,
                        style: TextStyle(
                          fontSize: t.spaceMd,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      )
                    : null,
              ),
              SizedBox(width: t.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      room.getLocalizedDisplayname(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    if (room.topic.isNotEmpty) ...[
                      SizedBox(height: 2),
                      Text(
                        room.topic,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}