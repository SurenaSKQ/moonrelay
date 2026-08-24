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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
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
  Widget build(BuildContext context) {
    // Coalesce rebuilds through the shared sync pulse.
    final pulseVersion = context.select<SyncPulse, int>((p) => p.version);
    if (pulseVersion != _lastPulseVersion) {
      _lastPulseVersion = pulseVersion;
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final space = widget.space;

    final displayName = space.getLocalizedDisplayname();
    final topic = space.topic;
    final totalMembers = (space.summary.mInvitedMemberCount ?? 0) +
        (space.summary.mJoinedMemberCount ?? 0);

    final client = space.client;
    final bool isJoined = space.membership == Membership.join;
    final canEdit = space.canChangeStateEvent('m.space.child');

    // Build parent-space breadcrumb trail.
    final parentSpaces = <Room>[];
    for (final parent in space.spaceParents) {
      final parentId = parent.roomId;
      if (parentId == null) continue;
      final parentRoom = client.getRoomById(parentId);
      if (parentRoom != null) {
        parentSpaces.add(parentRoom);
      }
    }

    // Pre-compute child lists for conditional spreads below.
    final subspaces = space.spaceChildren.where((c) {
      final roomId = c.roomId;
      if (roomId == null) return false;
      final room = client.getRoomById(roomId);
      return room != null && room.isSpace;
    }).toList();

    final joinedRooms = space.spaceChildren.where((c) {
      final roomId = c.roomId;
      if (roomId == null) return false;
      final room = client.getRoomById(roomId);
      return room != null && !room.isSpace;
    }).toList();

    final unjoined = space.spaceChildren.where((c) {
      final roomId = c.roomId;
      if (roomId == null) return false;
      return client.getRoomById(roomId) == null;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.spaceHome,
          style: textTheme.titleLarge,
        ),
        actions: [
          if (isJoined)
            IconButton(
              icon: const Icon(LucideIcons.settings),
              tooltip: l10n.openSpaceSettings,
              onPressed: () => context.push('/main/space/${space.id}/settings'),
            ),
        ],
      ),
      body: ListView(
        padding:
            EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: t.spaceSm),
        children: [
          // -- Parent-space breadcrumb ----------------------------------
          if (parentSpaces.isNotEmpty) ...[
            _buildBreadcrumb(context, parentSpaces, scheme),
            SizedBox(height: t.spaceLg),
          ],

          // -- Space identity card ----------------------------------------
          _buildIdentityCard(
            context,
            space,
            displayName,
            topic,
            totalMembers,
            isJoined,
            scheme,
            textTheme,
            l10n,
          ),
          SizedBox(height: t.spaceXl),

          // -- Quick actions (for members with permission) ----------------
          if (isJoined && canEdit) ...[
            _SectionHeader(title: l10n.actionsSection, scheme: scheme),
            SizedBox(height: t.spaceSm),
            _ActionTile(
              icon: LucideIcons.plus,
              label: l10n.addRoomToSpace,
              description: l10n.spaceSettingsDescription,
              onTap: () => context.push('/main/space/${space.id}/settings'),
              scheme: scheme,
            ),
            SizedBox(height: t.spaceLg),
          ],

          // -- Child subspaces --------------------------------------------
          if (subspaces.isNotEmpty) ...[
            _SectionHeader(title: l10n.spaceChildSpaces, scheme: scheme),
            SizedBox(height: t.spaceSm),
            for (final child in subspaces)
              _buildChildTile(
                context,
                client,
                child,
                isSubspace: true,
                scheme: scheme,
                l10n: l10n,
              ),
            SizedBox(height: t.spaceLg),
          ],

          // -- Child rooms (joined) ---------------------------------------
          if (joinedRooms.isNotEmpty) ...[
            _SectionHeader(title: l10n.spaceChildRooms, scheme: scheme),
            SizedBox(height: t.spaceSm),
            for (final child in joinedRooms)
              _buildChildTile(
                context,
                client,
                child,
                isSubspace: false,
                scheme: scheme,
                l10n: l10n,
              ),
            SizedBox(height: t.spaceLg),
          ],

          // -- Unjoined rooms ----------------------------------------------
          if (unjoined.isNotEmpty) ...[
            _SectionHeader(title: l10n.unjoinedRooms, scheme: scheme),
            SizedBox(height: t.spaceSm),
            for (final child in unjoined)
              _UnjoinedRoomTile(
                child: child,
                client: client,
                scheme: scheme,
                l10n: l10n,
              ),
          ],

          // -- Empty state ------------------------------------------------
          if (space.spaceChildren.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.folderOpen,
                      size: 48,
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
      ),
    );
  }

  Widget _buildIdentityCard(
    BuildContext context,
    Room space,
    String displayName,
    String topic,
    int totalMembers,
    bool isJoined,
    ColorScheme scheme,
    TextTheme textTheme,
    AppLocalizations l10n,
  ) {
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
            // Avatar
            SizedBox(
              width: 80,
              height: 80,
              child: CircleAvatar(
                radius: 40,
                backgroundColor: scheme.primaryContainer,
                backgroundImage: space.avatar != null
                    ? NetworkImage(space.avatar.toString())
                    : null,
                onBackgroundImageError:
                    space.avatar != null ? (_, __) {} : null,
                child: space.avatar == null
                    ? Icon(
                        LucideIcons.folder,
                        size: 36,
                        color: scheme.onPrimaryContainer,
                      )
                    : null,
              ),
            ),
            SizedBox(height: t.spaceLg),

            // Name
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
            if (topic.isNotEmpty)
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
                _InfoChip(
                  icon: LucideIcons.folder,
                  label: l10n.spaceType,
                  scheme: scheme,
                ),
                _InfoChip(
                  icon: LucideIcons.users,
                  label: '$totalMembers ${l10n.members}',
                  scheme: scheme,
                ),
              ],
            ),

            // Join button for non-members
            if (!isJoined) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => _joinSpace(context, space),
                icon: const Icon(LucideIcons.userPlus, size: 18),
                label: Text(l10n.joinSpace),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusMd),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChildTile(
    BuildContext context,
    Client client,
    dynamic child, {
    required bool isSubspace,
    required ColorScheme scheme,
    required AppLocalizations l10n,
  }) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final roomId = child.roomId as String?;
    final childRoom = roomId != null ? client.getRoomById(roomId) : null;
    final name = childRoom?.getLocalizedDisplayname() ?? roomId ?? '?';
    final avatar = childRoom?.avatar;

    return Card(
      elevation: t.elevationNone,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: ext.components.avatar.sizeMedium / 2,
          backgroundColor: scheme.primaryContainer,
          backgroundImage:
              avatar != null ? NetworkImage(avatar.toString()) : null,
          onBackgroundImageError: avatar != null ? (_, __) {} : null,
          child: avatar == null
              ? Icon(
                  isSubspace ? LucideIcons.folder : LucideIcons.hash,
                  size: 18,
                  color: scheme.onPrimaryContainer,
                )
              : null,
        ),
        title: Text(
          name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: child.suggested == true
            ? Text(
                l10n.suggested,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.tertiary,
                ),
              )
            : null,
        trailing: isSubspace
            ? Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: scheme.onSurfaceVariant,
              )
            : null,
        onTap: () {
          if (roomId == null) return;
          if (isSubspace) {
            // Navigate to the subspace home page.
            context.push('/main/space/$roomId');
          } else {
            // Navigate to the room chat.
            context.push('/main/rooms/$roomId');
          }
        },
      ),
    );
  }

  /// Builds a breadcrumb trail of parent spaces, each tappable to navigate up.
  Widget _buildBreadcrumb(
    BuildContext context,
    List<Room> parents,
    ColorScheme scheme,
  ) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Wrap(
        spacing: 4,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (int i = 0; i < parents.length; i++) ...[
            if (i > 0)
              Icon(
                LucideIcons.chevronRight,
                size: 14,
                color:
                    scheme.onSurfaceVariant.withValues(alpha: t.opacitySubtle),
              ),
            GestureDetector(
              onTap: () => context.push('/main/space/${parents[i].id}'),
              child: Container(
                padding: EdgeInsets.symmetric(
                    horizontal: t.spaceSm, vertical: t.spaceXs),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer
                      .withValues(alpha: t.opacityDisabled),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  parents[i].getLocalizedDisplayname(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
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

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: t.opacitySubtle),
        borderRadius: BorderRadius.circular(t.radiusXl),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          SizedBox(width: t.spaceXs),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: scheme.onSecondaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

/// A tappable action row used in the quick-actions section.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.description,
    required this.onTap,
    required this.scheme,
  }) : color = null;

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final effectiveColor = color ?? scheme.primary;
    return Card(
      elevation: t.elevationNone,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, size: 22, color: effectiveColor),
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500),
        ),
        subtitle: description != null
            ? Text(
                description!,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              )
            : null,
        trailing: Icon(
          LucideIcons.chevronRight,
          size: 18,
          color: scheme.onSurfaceVariant,
        ),
        onTap: onTap,
      ),
    );
  }
}

/// A tile for a room in a space that the user has not yet joined.
///
/// Fetches the room preview summary from the server to show the display name
/// and avatar, falling back to the room ID when unavailable.
class _UnjoinedRoomTile extends StatefulWidget {
  const _UnjoinedRoomTile({
    required this.child,
    required this.client,
    required this.scheme,
    required this.l10n,
  });

  final dynamic child;
  final Client client;
  final ColorScheme scheme;
  final AppLocalizations l10n;

  @override
  State<_UnjoinedRoomTile> createState() => _UnjoinedRoomTileState();
}

class _UnjoinedRoomTileState extends State<_UnjoinedRoomTile> {
  /// The room summary fetched from the server.
  ///
  /// Null while loading or if the fetch failed.
  GetRoomSummaryResponse$3? _summary;
  bool _loading = true;

  String get _roomId => (widget.child.roomId as String?) ?? '?';

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    try {
      final summary = await widget.client.getRoomSummary(_roomId);
      if (mounted) {
        setState(() {
          _summary = summary;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final isSuggested = widget.child.suggested == true;

    final displayName = _loading
        ? _roomId
        : (_summary?.name?.isNotEmpty == true
            ? _summary!.name!
            : _summary?.canonicalAlias ?? _roomId);

    final avatarUri = _summary?.avatarUrl;

    return Card(
      elevation: t.elevationNone,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(t.radiusMd),
        side: BorderSide(
            color: widget.scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: ext.components.avatar.sizeMedium / 2,
          backgroundColor:
              widget.scheme.primaryContainer.withValues(alpha: t.opacitySubtle),
          backgroundImage:
              avatarUri != null ? NetworkImage(avatarUri.toString()) : null,
          onBackgroundImageError: avatarUri != null ? (_, __) {} : null,
          child: avatarUri == null
              ? Icon(
                  LucideIcons.hash,
                  size: 18,
                  color: widget.scheme.onPrimaryContainer,
                )
              : null,
        ),
        title: Text(
          displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontFamily: _loading || _summary?.name?.isNotEmpty != true
                ? 'JetBrainsMono'
                : null,
            fontSize:
                _loading || _summary?.name?.isNotEmpty != true ? 13 : null,
          ),
        ),
        subtitle: isSuggested
            ? Text(
                widget.l10n.roomPreviewSuggested,
                style: TextStyle(
                  fontSize: 12,
                  color: widget.scheme.tertiary,
                ),
              )
            : null,
        trailing: FilledButton.tonal(
          onPressed: () => context.push('/main/room_preview/$_roomId'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            widget.l10n.roomPreviewView,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
