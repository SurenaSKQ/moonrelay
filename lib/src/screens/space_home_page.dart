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
import 'package:moonrelay/src/screens/space_settings_page.dart';
import 'package:provider/provider.dart';

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

  @override
  void initState() {
    super.initState();
    // Refresh when new sync data arrives so child lists stay current.
    final client = context.read<Client>();
    _syncSub = client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
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

    // Separate children into rooms and subspaces.
    final children = space.spaceChildren;
    final childRooms = <dynamic>[];
    final childSubspaces = <dynamic>[];
    final client = space.client;

    for (final child in children) {
      final roomId = child.roomId;
      if (roomId == null) continue;
      final childRoom = client.getRoomById(roomId);
      if (childRoom != null) {
        if (childRoom.isSpace) {
          childSubspaces.add(child);
        } else {
          childRooms.add(child);
        }
      }
    }

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
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpaceSettingsPage(space: space),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Parent-space breadcrumb ──────────────────────────────────
          if (parentSpaces.isNotEmpty) ...[            _buildBreadcrumb(context, parentSpaces, scheme),
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
          if (isJoined && canEdit) ...[            _SectionHeader(title: l10n.actionsSection, scheme: scheme),
            const SizedBox(height: 8),
            _ActionTile(
              icon: LucideIcons.plus,
              label: l10n.addRoomToSpace,
              description: l10n.spaceSettingsDescription,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SpaceSettingsPage(space: space),
                ),
              ),
              scheme: scheme,
            ),
            const SizedBox(height: 16),
          ],

          // ── Child subspaces ────────────────────────────────────────────
          if (childSubspaces.isNotEmpty) ...[            _SectionHeader(title: l10n.spaceChildSpaces, scheme: scheme),
            const SizedBox(height: 8),
            ...childSubspaces.map(
              (child) => _buildChildTile(
                context,
                client,
                child,
                isSubspace: true,
                scheme: scheme,
                l10n: l10n,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Child rooms ────────────────────────────────────────────────
          if (childRooms.isNotEmpty) ...[            _SectionHeader(title: l10n.spaceChildRooms, scheme: scheme),
            const SizedBox(height: 8),
            ...childRooms.map(
              (child) => _buildChildTile(
                context,
                client,
                child,
                isSubspace: false,
                scheme: scheme,
                l10n: l10n,
              ),
            ),
          ],

          // ── Empty state ────────────────────────────────────────────────
          if (children.isEmpty)
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
          for (int i = 0; i < parents.length; i++) ...[            if (i > 0)
              Icon(
                LucideIcons.chevronRight,
                size: 14,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
              ),
            GestureDetector(
              onTap: () => context.push('/main/space/${parents[i].id}'),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
  });

  final IconData icon;
  final String label;
  final String? description;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: ListTile(
        leading: Icon(icon, size: 22, color: scheme.primary),
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
