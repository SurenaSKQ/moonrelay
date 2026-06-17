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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_preview_screen.dart';
import 'package:provider/provider.dart';

/// Maximum number of child rooms to delete before showing a progress dialog.
const int _maxDeleteWithoutProgress = 5;

/// The main landing page for a space, showing its avatar, name, topic,
/// member count, child rooms, and child subspaces.
///
/// When the user clicks a space in the [NavigationPane] they are taken
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
  StreamSubscription? _syncSub;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    // Refresh when new sync data arrives so child lists stay current.
    final client = context.read<Client>();
    _syncSub = client.onSync.stream.listen((_) {
      if (mounted && !_disposed) setState(() {});
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Parent-space breadcrumb ──────────────────────────────────
          if (parentSpaces.isNotEmpty) ...[
            _buildBreadcrumb(context, parentSpaces, scheme),
            const SizedBox(height: 16),
          ],

          // ── Space identity card ────────────────────────────────────────
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
          const SizedBox(height: 24),

          // ── Quick actions (for members with permission) ────────────────
          if (isJoined && canEdit) ...[
            _SectionHeader(title: l10n.actionsSection, scheme: scheme),
            const SizedBox(height: 8),
            _ActionTile(
              icon: LucideIcons.plus,
              label: l10n.addRoomToSpace,
              description: l10n.spaceSettingsDescription,
              onTap: () => context.push('/main/space/${space.id}/settings'),
              scheme: scheme,
            ),
            const SizedBox(height: 16),
          ],

          // ── Danger zone (space deletion) ──────────────────────────────
          if (_canDeleteSpace()) ...[
            _SectionHeader(
              title: l10n.actionsDeleteSection,
              scheme: scheme,
            ),
            const SizedBox(height: 8),
            _ActionTile(
              icon: LucideIcons.trash2,
              label: l10n.deleteSpace,
              description: l10n.deleteSpaceDescription,
              color: scheme.error,
              onTap: _deleteSpace,
              scheme: scheme,
            ),
            const SizedBox(height: 16),
          ],

          // ── Child subspaces ────────────────────────────────────────────
          if (subspaces.isNotEmpty) ...[
            _SectionHeader(title: l10n.spaceChildSpaces, scheme: scheme),
            const SizedBox(height: 8),
            for (final child in subspaces)
              _buildChildTile(
                context,
                client,
                child,
                isSubspace: true,
                scheme: scheme,
                l10n: l10n,
              ),
            const SizedBox(height: 16),
          ],

          // ── Child rooms (joined) ───────────────────────────────────────
          if (joinedRooms.isNotEmpty) ...[
            _SectionHeader(title: l10n.spaceChildRooms, scheme: scheme),
            const SizedBox(height: 8),
            for (final child in joinedRooms)
              _buildChildTile(
                context,
                client,
                child,
                isSubspace: false,
                scheme: scheme,
                l10n: l10n,
              ),
            const SizedBox(height: 16),
          ],

          // ── Unjoined rooms ──────────────────────────────────────────────
          if (unjoined.isNotEmpty) ...[
            _SectionHeader(title: l10n.unjoinedRooms, scheme: scheme),
            const SizedBox(height: 8),
            for (final child in unjoined)
              _UnjoinedRoomTile(
                child: child,
                client: client,
                scheme: scheme,
                l10n: l10n,
              ),
          ],

          // ── Empty state ────────────────────────────────────────────────
          if (space.spaceChildren.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.folderOpen,
                      size: 48,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                    ),
                    const SizedBox(height: 12),
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
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
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
            const SizedBox(height: 16),

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
            const SizedBox(height: 4),

            // Topic
            if (topic.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
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

            const SizedBox(height: 12),

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
                    borderRadius: BorderRadius.circular(12),
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
    final roomId = child.roomId as String?;
    final childRoom = roomId != null ? client.getRoomById(roomId) : null;
    final name = childRoom?.getLocalizedDisplayname() ?? roomId ?? '?';
    final avatar = childRoom?.avatar;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
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
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            GestureDetector(
              onTap: () => context.push('/main/space/${parents[i].id}'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: scheme.primaryContainer.withValues(alpha: 0.4),
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

  // ---------------------------------------------------------------------------
  // Space deletion
  // ---------------------------------------------------------------------------

  /// Whether the current user is admin of the space and all its child rooms.
  bool _canDeleteSpace() {
    final space = widget.space;
    if (space.membership != Membership.join) return false;

    // Room must have a power levels state event.  Without it
    // canChangeStateEvent defaults to requiring power level 0, which
    // would let any joined user see the delete button.
    if (space.getState(EventTypes.RoomPowerLevels) == null) return false;
    // Must be admin of the space itself.
    if (!space.canChangeStateEvent('m.room.power_levels')) return false;

    // Must be admin of all joined child rooms.
    final client = space.client;
    for (final child in space.spaceChildren) {
      final cid = child.roomId;
      if (cid == null) continue;
      final childRoom = client.getRoomById(cid);
      if (childRoom == null) continue;
      if (childRoom.membership != Membership.join) continue;
      // Same guard for each child room.
      if (childRoom.getState(EventTypes.RoomPowerLevels) == null) return false;
      if (!childRoom.canChangeStateEvent('m.room.power_levels')) return false;
    }
    return true;
  }

  /// Delete a child room via the admin API.
  Future<void> _deleteChildRoom(Room room, Logger log) async {
    final client = room.client;
    final serverUrl = client.homeserver.toString();
    final url = serverUrl.endsWith('/')
        ? '${serverUrl}_synapse/admin/v2/rooms/${room.id}/delete'
        : '$serverUrl/_synapse/admin/v2/rooms/${room.id}/delete';

    await withRetry(
      () => client.httpClient.post(Uri.parse(url), body: '{}'),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'deleteChildRoom',
    );
  }

  /// Permanently delete this space and all its child rooms.
  Future<void> _deleteSpace() async {
    final space = widget.space;
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();

    if (!_canDeleteSpace()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteSpaceNotEnoughPower),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteSpace),
        content: Text(l10n.deleteSpaceConfirm(
          space.getLocalizedDisplayname(),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final client = space.client;
    final childRooms = space.spaceChildren
        .map((c) => c.roomId != null ? client.getRoomById(c.roomId!) : null)
        .whereType<Room>()
        .where((r) => r.membership == Membership.join)
        .toList();

    // For many children, show a progress dialog.
    if (childRooms.length > _maxDeleteWithoutProgress && mounted) {
      return showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => _DeleteSpaceProgressDialog(
          space: space,
          childRooms: childRooms,
          l10n: l10n,
          log: log,
        ),
      );
    }

    try {
      // Delete children first.
      for (final child in childRooms) {
        try {
          await _deleteChildRoom(child, log);
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.deleteChildRoomFailed(
                child.getLocalizedDisplayname(),
                '$e',
              )),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }

      // Delete the space itself.
      final serverUrl = client.homeserver.toString();
      final url = serverUrl.endsWith('/')
          ? '${serverUrl}_synapse/admin/v2/rooms/${space.id}/delete'
          : '$serverUrl/_synapse/admin/v2/rooms/${space.id}/delete';

      await withRetry(
        () => client.httpClient.post(Uri.parse(url), body: '{}'),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'deleteSpace',
      );

      await space.leave();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteSpaceSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/main/rooms');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteSpaceFailed('$e')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
      if (mounted && !_disposed) setState(() {});
    } catch (e) {
      if (!mounted) return;
      final message = e is TimeoutException
          ? AppLocalizations.of(context)!.couldNotJoinRoomTimeout
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('${AppLocalizations.of(context)!.error}: $message')),
      );
    }
  }
}

// ── Internal widgets ──────────────────────────────────────────────────────────

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: scheme.onSecondaryContainer),
          const SizedBox(width: 4),
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
    this.color,
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final ColorScheme scheme;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? scheme.primary;
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
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

/// A modal dialog that shows deletion progress for a space with many children.
class _DeleteSpaceProgressDialog extends StatefulWidget {
  const _DeleteSpaceProgressDialog({
    required this.space,
    required this.childRooms,
    required this.l10n,
    required this.log,
  });

  final Room space;
  final List<Room> childRooms;
  final AppLocalizations l10n;
  final Logger log;

  @override
  State<_DeleteSpaceProgressDialog> createState() =>
      _DeleteSpaceProgressDialogState();
}

class _DeleteSpaceProgressDialogState
    extends State<_DeleteSpaceProgressDialog> {
  int _deleted = 0;
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _deleteAll());
  }

  Future<void> _deleteAll() async {
    final l10n = widget.l10n;
    final log = widget.log;
    final space = widget.space;
    final client = space.client;

    // Delete children.
    for (final child in widget.childRooms) {
      try {
        final serverUrl = client.homeserver.toString();
        final url = serverUrl.endsWith('/')
            ? '${serverUrl}_synapse/admin/v2/rooms/${child.id}/delete'
            : '$serverUrl/_synapse/admin/v2/rooms/${child.id}/delete';

        await withRetry(
          () => client.httpClient.post(Uri.parse(url), body: '{}'),
          maxRetries: 1,
          timeout: kDefaultTimeout,
          log: log,
          label: 'deleteChildRoom',
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = l10n.deleteChildRoomFailed(
            child.getLocalizedDisplayname(),
            '$e',
          );
        });
        // Continue trying the rest.
      }

      if (!mounted) return;
      setState(() => _deleted++);
    }

    // Delete the space itself.
    try {
      final serverUrl = client.homeserver.toString();
      final url = serverUrl.endsWith('/')
          ? '${serverUrl}_synapse/admin/v2/rooms/${space.id}/delete'
          : '$serverUrl/_synapse/admin/v2/rooms/${space.id}/delete';

      await withRetry(
        () => client.httpClient.post(Uri.parse(url), body: '{}'),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'deleteSpace',
      );

      await space.leave();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.deleteSpaceFailed('$e');
      });
    }

    if (!mounted) return;
    setState(() => _done = true);

    // Close dialog and navigate after a brief delay.
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_error ?? l10n.deleteSpaceSuccess),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (context.mounted) context.go('/main/rooms');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final total = widget.childRooms.length + 1; // +1 for the space itself

    return AlertDialog(
      title: Text(widget.l10n.deleteSpace),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: _done ? 1.0 : _deleted / total,
          ),
          const SizedBox(height: 16),
          Text(
            _done
                ? widget.l10n.deleteSpaceSuccess
                : _error ??
                    '$_deleted / $total ${widget.l10n.delete.toLowerCase()}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

/// A tile for a room in a space that the user has not yet joined.
///
/// Shows the room ID with a preview button that opens [RoomPreviewScreen].
class _UnjoinedRoomTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final roomId = child.roomId ?? '?';
    final isSuggested = child.suggested == true;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          radius: 18,
          backgroundColor: scheme.primaryContainer.withValues(alpha: 0.5),
          child: Icon(
            LucideIcons.hash,
            size: 18,
            color: scheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          roomId,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontFamily: 'JetBrainsMono',
            fontSize: 13,
          ),
        ),
        subtitle: isSuggested
            ? Text(
                l10n.roomPreviewSuggested,
                style: TextStyle(
                  fontSize: 12,
                  color: scheme.tertiary,
                ),
              )
            : null,
        trailing: FilledButton.tonal(
          onPressed: () => context.push('/main/room_preview/$roomId'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            l10n.roomPreviewView,
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ),
    );
  }
}
