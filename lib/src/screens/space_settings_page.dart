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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// Maximum number of child rooms to delete before showing a progress dialog.
const int _maxDeleteWithoutProgress = 5;

/// A settings page for a space that provides full administration: viewing
/// technical details, editing name/topic/avatar, managing child rooms, and
/// deleting the space.
class SpaceSettingsPage extends StatefulWidget {
  const SpaceSettingsPage({super.key, required this.space});

  final Room space;

  @override
  State<SpaceSettingsPage> createState() => _SpaceSettingsPageState();
}

class _SpaceSettingsPageState extends State<SpaceSettingsPage> {
  /// Last [SyncPulse.version] observed at build time. The build subscribes
  /// via [context.select] so we get a coalesced tick instead of one
  /// rebuild per raw sync event.
  int _lastPulseVersion = -1;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Permission helpers
  // ---------------------------------------------------------------------------

  bool _canChange(String eventType) =>
      widget.space.canChangeStateEvent(eventType);

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    // Read the debounced sync pulse so the page rebuilds on every
    // coalesced tick rather than every raw sync event. The pulse
    // provider is in scope for this screen (mounted inside the
    // account-aware router).
    final pulseVersion = context.select<SyncPulse, int>((p) => p.version);
    if (pulseVersion != _lastPulseVersion) {
      _lastPulseVersion = pulseVersion;
    }

    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final space = widget.space;

    // Current children (rooms and subspaces).
    final children = space.spaceChildren;
    final client = space.client;

    // Rooms that the user has joined and that are NOT already children.
    final availableRooms = client.rooms.where((r) {
      if (r.id == space.id) return false;
      if (r.isSpace) return false;
      return !children.any((c) => c.roomId == r.id);
    }).toList()
      ..sort((a, b) => a
          .getLocalizedDisplayname()
          .toLowerCase()
          .compareTo(b.getLocalizedDisplayname().toLowerCase()));

    final canEdit = _canChange('m.space.child');

    final isEncrypted = _isSpaceEncrypted(space);

    final creationDate = _creationDate(space);

    final canonicalAlias =
        space.canonicalAlias.isNotEmpty ? space.canonicalAlias : null;

    final totalMembers = (space.summary.mInvitedMemberCount ?? 0) +
        (space.summary.mJoinedMemberCount ?? 0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.spaceSettings,
          style: textTheme.titleLarge,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // -- Space identity card ------------------------------------------
          _SpaceIdentityCard(
            space: space,
            displayName: space.getLocalizedDisplayname(),
            topic: space.topic,
            totalMembers: totalMembers,
            scheme: scheme,
            textTheme: textTheme,
          ),
          SizedBox(height: t.spaceLg),

          // -- Technical details --------------------------------------------
          _SectionHeader(title: l10n.detailsSection, scheme: scheme),
          const SizedBox(height: 4),
          _DetailRow(
            icon: LucideIcons.hash,
            label: l10n.roomIdLabel,
            value: space.id,
            scheme: scheme,
          ),
          if (canonicalAlias != null)
            _DetailRow(
              icon: LucideIcons.atSign,
              label: l10n.addressLabel,
              value: canonicalAlias,
              scheme: scheme,
            ),
          _DetailRow(
            icon: LucideIcons.folder,
            label: l10n.typeLabel,
            value: l10n.spaceType,
            scheme: scheme,
          ),
          _DetailRow(
            icon: isEncrypted ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
            label: l10n.encryptionLabel,
            value: isEncrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
            scheme: scheme,
          ),
          _DetailRow(
            icon: LucideIcons.calendar,
            label: l10n.createdLabel,
            value: creationDate,
            scheme: scheme,
          ),
          _DetailRow(
            icon: LucideIcons.users,
            label: l10n.members,
            value: '$totalMembers',
            scheme: scheme,
          ),
          SizedBox(height: t.spaceLg),

          // -- Space editing (permission-gated) ----------------------------
          if (_canChange('m.room.name') ||
              _canChange('m.room.topic') ||
              _canChange('m.room.avatar')) ...[
            _SectionHeader(title: l10n.actionsSection, scheme: scheme),
            const SizedBox(height: 4),
            if (_canChange('m.room.name'))
              _ActionTile(
                icon: LucideIcons.pencil,
                label: l10n.editSpaceName,
                description: space.getLocalizedDisplayname(),
                onTap: _editSpaceName,
                scheme: scheme,
              ),
            if (_canChange('m.room.topic'))
              _ActionTile(
                icon: LucideIcons.alignLeft,
                label: l10n.editSpaceTopic,
                description: space.topic.isNotEmpty ? space.topic : l10n.notSet,
                onTap: _editSpaceTopic,
                scheme: scheme,
              ),
            if (_canChange('m.room.avatar'))
              _ActionTile(
                icon: LucideIcons.image,
                label: l10n.changeSpaceAvatar,
                description: l10n.changeSpaceAvatarDescription,
                onTap: _changeSpaceAvatar,
                scheme: scheme,
              ),
            SizedBox(height: t.spaceSm),
          ],

          // -- Child rooms / subspaces ------------------------------------
          if (children.isNotEmpty) ...[
            _SectionHeader(title: l10n.spaceChildRooms, scheme: scheme),
            SizedBox(height: t.spaceXs),
            ...children.map((child) {
              final childRoomId = child.roomId;
              if (childRoomId == null) return const SizedBox.shrink();
              final childRoom = client.getRoomById(childRoomId);
              final name = childRoom?.getLocalizedDisplayname() ?? childRoomId;
              final isSpace = childRoom?.isSpace ?? false;

              return Card(
                elevation: t.elevationNone,
                margin: const EdgeInsets.only(bottom: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusMd),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      isSpace ? LucideIcons.folder : LucideIcons.hash,
                      size: t.iconSizeSmall,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                  trailing: canEdit
                      ? IconButton(
                          icon: Icon(
                            LucideIcons.trash2,
                            size: 18,
                            color: scheme.error,
                          ),
                          tooltip: l10n.removeRoomFromSpace,
                          onPressed: () => _removeChild(context, childRoomId),
                        )
                      : null,
                ),
              );
            }),
            SizedBox(height: t.spaceSm),
          ],

          // -- Add room section ------------------------------------------
          if (canEdit) ...[
            _SectionHeader(title: l10n.addRoomToSpace, scheme: scheme),
            SizedBox(height: t.spaceXs),
            if (availableRooms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.spaceNoChildren,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...availableRooms.map((room) {
                return Card(
                  elevation: t.elevationNone,
                  margin: const EdgeInsets.only(bottom: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(t.radiusMd),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        LucideIcons.hash,
                        size: t.iconSizeSmall,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      room.getLocalizedDisplayname(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        LucideIcons.plus,
                        size: 18,
                        color: scheme.primary,
                      ),
                      tooltip: l10n.addRoomToSpace,
                      onPressed: () => _addChild(context, room.id),
                    ),
                  ),
                );
              }),
            SizedBox(height: t.spaceSm),
          ],

          // -- Danger zone ------------------------------------------------
          if (_canDeleteSpace()) ...[
            _SectionHeader(
              title: l10n.actionsDeleteSection,
              scheme: scheme,
            ),
            SizedBox(height: t.spaceXs),
            _ActionTile(
              icon: LucideIcons.trash2,
              label: l10n.deleteSpace,
              description: l10n.deleteSpaceDescription,
              color: scheme.error,
              onTap: _deleteSpace,
              scheme: scheme,
            ),
          ],
          SizedBox(height: t.spaceXl),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  bool _isSpaceEncrypted(Room room) {
    try {
      return room.encrypted;
    } catch (_) {
      return false;
    }
  }

  String _creationDate(Room room) {
    final createEvent =
        room.getState(EventTypes.RoomCreate)?.content.tryGet('created_at');
    if (createEvent is String && createEvent.isNotEmpty) {
      final dt = DateTime.tryParse(createEvent);
      if (dt != null) {
        return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
      }
    }
    return AppLocalizations.of(context)!.unknownDate;
  }

  // ---------------------------------------------------------------------------
  // Space editing
  // ---------------------------------------------------------------------------

  Future<void> _editSpaceName() async {
    final space = widget.space;
    final l10n = AppLocalizations.of(context)!;
    final controller =
        TextEditingController(text: space.getLocalizedDisplayname());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editSpaceName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.editSpaceNameHint,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final newName = controller.text.trim();
    if (newName.isEmpty || newName == space.getLocalizedDisplayname()) return;

    try {
      await space.setName(newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.spaceNameUpdated),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _editSpaceTopic() async {
    final space = widget.space;
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: space.topic);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editSpaceTopic),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.editSpaceTopicHint,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final newTopic = controller.text.trim();
    if (newTopic == space.topic) return;

    try {
      await space.setDescription(newTopic);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.spaceTopicUpdated),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _changeSpaceAvatar() async {
    final space = widget.space;
    final l10n = AppLocalizations.of(context)!;

    // Use `pickFile` (singular) for single-image selection; this also
    // avoids the deprecated `allowMultiple: false` and `withData: true`
    // parameters on `pickFiles`.
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    try {
      await space.setAvatar(MatrixFile(bytes: bytes, name: file.name));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.spaceAvatarUpdated),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Child room management
  // ---------------------------------------------------------------------------

  Future<void> _addChild(BuildContext context, String roomId) async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    try {
      await withRetry(
        () => widget.space.setSpaceChild(roomId),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'addSpaceChild',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.roomAddedToSpace),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      // Refetch the l10n via a captured reference before the await to
      // avoid using [context] across the async gap.
      final errorLabel = l10n.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorLabel: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeChild(BuildContext context, String roomId) async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    try {
      await withRetry(
        () => widget.space.removeSpaceChild(roomId),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'removeSpaceChild',
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.roomRemovedFromSpace),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      final errorLabel = l10n.error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$errorLabel: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Space deletion
  // ---------------------------------------------------------------------------

  /// Whether the current user is admin of the space and all its child rooms.
  bool _canDeleteSpace() {
    final space = widget.space;
    if (space.membership != Membership.join) return false;

    if (space.getState(EventTypes.RoomPowerLevels) == null) return false;
    if (!space.canChangeStateEvent('m.room.power_levels')) return false;

    final client = space.client;
    for (final child in space.spaceChildren) {
      final cid = child.roomId;
      if (cid == null) continue;
      final childRoom = client.getRoomById(cid);
      if (childRoom == null) continue;
      if (childRoom.membership != Membership.join) continue;
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
      () => client.httpClient.post(
        Uri.parse(url),
        body: '{}',
        headers: {'authorization': 'Bearer ${client.accessToken}'},
      ),
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

      final serverUrl = client.homeserver.toString();
      final url = serverUrl.endsWith('/')
          ? '${serverUrl}_synapse/admin/v2/rooms/${space.id}/delete'
          : '$serverUrl/_synapse/admin/v2/rooms/${space.id}/delete';

      await withRetry(
        () => client.httpClient.post(
          Uri.parse(url),
          body: '{}',
          headers: {'authorization': 'Bearer ${client.accessToken}'},
        ),
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
}

// =============================================================================
// Internal widgets
// =============================================================================

/// Space identity card shown at the top of the settings page.
class _SpaceIdentityCard extends StatelessWidget {
  const _SpaceIdentityCard({
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
          ],
        ),
      ),
    );
  }
}

/// A small chip used for room metadata badges.
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

/// A section header label.
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

/// A tappable action row.
class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    this.description,
    this.color,
    required this.onTap,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final String? description;
  final Color? color;
  final VoidCallback onTap;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final effectiveColor = color ?? scheme.primary;
    final t = MoonrelayThemeExtension.of(context).tokens;
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

/// A read-only detail row with icon, label, and value.
class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          SizedBox(width: t.spaceMd),
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
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

    for (final child in widget.childRooms) {
      try {
        final serverUrl = client.homeserver.toString();
        final url = serverUrl.endsWith('/')
            ? '${serverUrl}_synapse/admin/v2/rooms/${child.id}/delete'
            : '$serverUrl/_synapse/admin/v2/rooms/${child.id}/delete';

        await withRetry(
          () => client.httpClient.post(
            Uri.parse(url),
            body: '{}',
            headers: {'authorization': 'Bearer ${client.accessToken}'},
          ),
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
      }

      if (!mounted) return;
      setState(() => _deleted++);
    }

    try {
      final serverUrl = client.homeserver.toString();
      final url = serverUrl.endsWith('/')
          ? '${serverUrl}_synapse/admin/v2/rooms/${space.id}/delete'
          : '$serverUrl/_synapse/admin/v2/rooms/${space.id}/delete';

      await withRetry(
        () => client.httpClient.post(
          Uri.parse(url),
          body: '{}',
          headers: {'authorization': 'Bearer ${client.accessToken}'},
        ),
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
    final t = MoonrelayThemeExtension.of(context).tokens;
    final total = widget.childRooms.length + 1;

    return AlertDialog(
      title: Text(widget.l10n.deleteSpace),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: _done ? 1.0 : _deleted / total,
          ),
          SizedBox(height: t.spaceLg),
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
