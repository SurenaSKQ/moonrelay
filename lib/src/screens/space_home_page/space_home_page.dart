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

import 'dart:async';
import 'package:moonrelay/src/screens/space_home_page/unjoined_room_tile.dart';

import 'package:flutter/material.dart';
import 'package:moonrelay/src/widgets/identity_header.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:provider/provider.dart';

/// The main landing page for a space, showing its avatar, name, topic,
/// member count, child rooms, and child subspaces.
///
/// When the user clicks a space in the navigation sidebar they are taken
/// here.  Tapping a child room opens it, and tapping a child subspace
/// navigates to that subspace's own home page.
class SpaceHomePage extends StatefulWidget {
  const SpaceHomePage({super.key, required this.space});

  /// The space room to display.
  final Room space;

  @override
  State<SpaceHomePage> createState() => _SpaceHomePageState();
}

class _SpaceHomePageState extends State<SpaceHomePage> {
  /// Last [SyncPulse.version] observed at build time. We use
  /// [context.select] in [build] instead of subscribing to
  /// `client.onSync.stream` directly so this page rebuilds only on the
  /// debounced pulse.
  int _lastPulseVersion = -1;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final space = widget.space;
    final client = space.client;

    // Coalesce rebuilds through the shared sync pulse.
    final pulseVersion = context.select<SyncPulse, int>((p) => p.version);
    if (pulseVersion != _lastPulseVersion) {
      _lastPulseVersion = pulseVersion;
    }

    final displayName = space.getLocalizedDisplayname();
    final topic = space.topic;
    final totalMembers = (space.summary.mInvitedMemberCount ?? 0) +
        (space.summary.mJoinedMemberCount ?? 0);
    final isJoined = space.membership == Membership.join;

    // Children split three ways. The unjoined ones are a separate section
    // because they are a different kind of thing: the space says they belong
    // here, but the user is not in them, so the row is a preview and an offer
    // rather than a destination.
    final subspaces = <_ChildEntry>[];
    final joinedRooms = <_ChildEntry>[];
    final unjoined = <_ChildEntry>[];
    for (final child in space.spaceChildren) {
      final roomId = child.roomId;
      if (roomId == null) continue;
      final childRoom = client.getRoomById(roomId);
      final entry = _ChildEntry(
        roomId: roomId,
        room: childRoom,
        suggested: child.suggested == true,
      );
      if (childRoom == null) {
        unjoined.add(entry);
      } else if (childRoom.isSpace) {
        subspaces.add(entry);
      } else {
        joinedRooms.add(entry);
      }
    }

    return MoonrelayInfoPage(
      title: l10n.spaceHome,
      actions: [
        if (isJoined)
          IconButton(
            icon: const Icon(LucideIcons.settings),
            tooltip: l10n.openSpaceSettings,
            onPressed: () => context.push('/main/space/${space.id}/settings'),
          ),
      ],
      children: [
        IdentityHeader(
          name: displayName,
          topic: topic,
          avatar: SizedBox(
            width: 64,
            height: 64,
            child: CircleAvatar(
              radius: 32,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: space.avatar != null
                  ? NetworkImage(
                      space.avatar.toString(),
                      headers: authHeaders(context.read<Client>()),
                    )
                  : null,
              onBackgroundImageError: space.avatar != null ? (_, __) {} : null,
              child: space.avatar == null
                  ? Icon(
                      LucideIcons.folder,
                      size: 30,
                      color: scheme.onPrimaryContainer,
                    )
                  : null,
            ),
          ),
          chips: [
            InfoChip(icon: LucideIcons.folder, label: l10n.spaceType),
            InfoChip(icon: LucideIcons.users, label: '$totalMembers ${l10n.members}'),
          ],
        ),

        // Join is this page's primary action for a space the user is not in,
        // so it sits directly under the header rather than at the bottom of a
        // list of rooms they have not joined yet. It used to live inside the
        // centred identity card, which meant scrolling past everything else to
        // find the button that decides whether you can see any of it.
        if (!isJoined) ...[
          const InfoSectionGap(first: true),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.icon(
              onPressed: () => _joinSpace(context, space),
              icon: const Icon(LucideIcons.userPlus, size: 18),
              label: Text(l10n.joinSpace),
              style: FilledButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: t.spaceXl,
                  vertical: t.spaceMd,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusMd),
                ),
              ),
            ),
          ),
        ],

        const InfoSectionGap(first: true),

        // -- Child subspaces ------------------------------------------------
        if (subspaces.isNotEmpty) ...[
          InfoPanel(
            title: l10n.spaceChildSpaces,
            padding: EdgeInsets.zero,
            children: [
              for (final entry in subspaces)
                _SpaceChildRow(
                  entry: entry,
                  onTap: () => context.push(
                    '/main/space/${Uri.encodeComponent(entry.roomId)}',
                  ),
                ),
            ],
          ),
          const InfoSectionGap(),
        ],

        // -- Child rooms ------------------------------------------------------
        if (joinedRooms.isNotEmpty) ...[
          InfoPanel(
            title: l10n.spaceChildRooms,
            padding: EdgeInsets.zero,
            children: [
              for (final entry in joinedRooms)
                _SpaceChildRow(
                  entry: entry,
                  // Through the shell-aware seam: in the single-pane shell this
                  // pushes so the space page stays on the stack, and on the
                  // dashboard it replaces so a tour of child rooms does not
                  // build a history the user has to walk back through one chat
                  // at a time.
                  onTap: () => openRoom(context, entry.roomId),
                ),
            ],
          ),
          const InfoSectionGap(),
        ],

        // -- Unjoined rooms ----------------------------------------------------
        if (unjoined.isNotEmpty) ...[
          InfoPanel(
            title: l10n.unjoinedRooms,
            padding: EdgeInsets.zero,
            children: [
              for (final entry in unjoined)
                UnjoinedRoomTile(
                  child: entry,
                  client: client,
                  l10n: l10n,
                ),
            ],
          ),
          const InfoSectionGap(),
        ],

        // -- Empty state ---------------------------------------------------------
        // The one place on this page that is centred, because there is nothing
        // to align to: no rows, no panel, just an invitation.
        if (space.spaceChildren.isEmpty)
          Padding(
            padding: EdgeInsets.symmetric(vertical: t.spaceXxl * 2),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    LucideIcons.folderOpen,
                    size: 40,
                    color: scheme.onSurfaceVariant
                        .withValues(alpha: t.opacityDisabled),
                  ),
                  SizedBox(height: t.spaceMd),
                  Text(
                    l10n.spaceNoChildren,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
  Future<void> _joinSpace(BuildContext context, Room space) async {
    final log = context.read<Logger>();
    try {
      final result = await withRetry(
        () => space.join(),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'joinSpace',
      );
      if (result is RetryFailed) {
        throw (result).error;
      }
      if (mounted) setState(() {});
    } catch (e) {
      if (!context.mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final message =
          e is TimeoutException ? l10n.couldNotJoinRoomTimeout : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${l10n.error}: $message')),
      );
    }
  }
} // End of _SpaceHomePageState

// -- Internal widgets ----------------------------------------------------------

/// A tappable action row used in the quick-actions section.

// =============================================================================
// Internal widgets
// =============================================================================

/// One child of a space, resolved as far as the local client allows.
///
/// The room is nullable because a space routinely names children this client
/// has never fetched, and that is exactly the case where the page has to say
/// something useful rather than render an empty row.
class _ChildEntry {
  const _ChildEntry({
    required this.roomId,
    required this.room,
    required this.suggested,
  });

  final String roomId;
  final Room? room;
  final bool suggested;
}

/// One row in a space's child list.
///
/// A row rather than a bordered card because these are list items. The
/// previous version gave every child its own box with a 4px margin, which is
/// how a list of thirty rooms came to look like a stack of thirty unrelated
/// documents rather than a list of thirty rooms.
class _SpaceChildRow extends StatelessWidget {
  const _SpaceChildRow({required this.entry, required this.onTap});

  final _ChildEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    final room = entry.room;
    final isSubspace = room?.isSpace ?? false;
    final name = room?.getLocalizedDisplayname() ?? entry.roomId;
    final avatar = room?.avatar;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.spaceLg,
          vertical: t.spaceSm,
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: ext.components.avatar.sizeMedium / 2,
              backgroundColor: scheme.primaryContainer,
              backgroundImage: avatar != null
                  ? NetworkImage(
                      avatar.toString(),
                      headers: authHeaders(context.read<Client>()),
                    )
                  : null,
              onBackgroundImageError: avatar != null ? (_, __) {} : null,
              child: avatar == null
                  ? Icon(
                      isSubspace ? LucideIcons.folder : LucideIcons.hash,
                      size: 16,
                      color: scheme.onPrimaryContainer,
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
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                  if (entry.suggested) ...[
                    SizedBox(height: t.spaceXxs),
                    Text(
                      l10n.suggested,
                      style: TextStyle(fontSize: 12, color: scheme.tertiary),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              LucideIcons.chevronRight,
              size: t.iconSizeMedium,
              color: scheme.onSurfaceVariant.withValues(alpha: t.opacityMuted),
            ),
          ],
        ),
      ),
    );
  }
}
