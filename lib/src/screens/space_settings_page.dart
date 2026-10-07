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
import 'package:moonrelay/src/screens/space_settings/delete_space_progress.dart';
import 'package:moonrelay/src/screens/space_settings/space_child_rows.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/identity_header.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/upload_limits.dart';
import 'package:moonrelay/src/helpers/room_dates.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
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

  // Permission helpers

  bool _canChange(String eventType) =>
      widget.space.canChangeStateEvent(eventType);

  // Build

  @override
  Widget build(BuildContext context) {
    // Read the debounced sync pulse so the page rebuilds on every
    // coalesced tick rather than every raw sync event.
    final pulseVersion = context.select<SyncPulse, int>((p) => p.version);
    if (pulseVersion != _lastPulseVersion) {
      _lastPulseVersion = pulseVersion;
    }

    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final space = widget.space;

    final children = space.spaceChildren;
    final client = space.client;

    // Rooms the user has joined that are not already children.
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

    return MoonrelayInfoPage(
      title: l10n.spaceSettings,
      children: [
        IdentityHeader(
          name: space.getLocalizedDisplayname(),
          topic: space.topic,
          avatar: SizedBox(
            width: 56,
            height: 56,
            child: AvatarFromUriOrFallbackImage(
              client: space.client,
              avatarUri: space.avatar,
            ),
          ),
          chips: [
            InfoChip(icon: LucideIcons.folder, label: l10n.spaceType),
            InfoChip(icon: LucideIcons.users, label: '$totalMembers ${l10n.members}'),
            if (isEncrypted)
              InfoChip(
                icon: LucideIcons.shieldCheck,
                label: l10n.endToEndEncrypted,
                emphasis: true,
              ),
          ],
        ),

        const InfoSectionGap(first: true),

        // -- What this space is -------------------------------------------
        InfoPanel(
          title: l10n.detailsSection,
          children: [
            InfoPanelRow(
              icon: LucideIcons.fingerprint,
              label: l10n.roomIdLabel,
              description: space.id,
              valueFontFamily: MoonrelayTypography.mono(context),
            ),
            if (canonicalAlias != null)
              InfoPanelRow(
                icon: LucideIcons.hash,
                label: l10n.addressLabel,
                value: canonicalAlias,
              ),
            InfoPanelRow(
              icon: LucideIcons.folder,
              label: l10n.typeLabel,
              value: l10n.spaceType,
            ),
            InfoPanelRow(
              icon: isEncrypted ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
              label: l10n.encryptionLabel,
              value: isEncrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
            ),
            InfoPanelRow(
              icon: LucideIcons.calendar,
              label: l10n.createdLabel,
              value: creationDate,
            ),
          ],
        ),

        const InfoSectionGap(),

        // -- Editing the space's own fields --------------------------------
        if (_canChange('m.room.name') ||
            _canChange('m.room.topic') ||
            _canChange('m.room.avatar'))
          InfoPanel(
            title: l10n.spaceDetailsEditSection,
            children: [
              if (_canChange('m.room.name'))
                InfoPanelRow(
                  icon: LucideIcons.pencil,
                  label: l10n.editSpaceName,
                  description: space.getLocalizedDisplayname(),
                  onTap: _editSpaceName,
                ),
              if (_canChange('m.room.topic'))
                InfoPanelRow(
                  icon: LucideIcons.alignLeft,
                  label: l10n.editSpaceTopic,
                  description: space.topic.isNotEmpty ? space.topic : l10n.notSet,
                  onTap: _editSpaceTopic,
                ),
              if (_canChange('m.room.avatar'))
                InfoPanelRow(
                  icon: LucideIcons.image,
                  label: l10n.changeSpaceAvatar,
                  description: l10n.changeSpaceAvatarDescription,
                  onTap: _changeSpaceAvatar,
                ),
            ],
          ),

        if (_canChange('m.room.name') ||
            _canChange('m.room.topic') ||
            _canChange('m.room.avatar'))
          const InfoSectionGap(),

        // -- Child rooms ----------------------------------------------------
        // One panel with a row per child, so the list reads as a list. It was a
        // column of separate bordered cards with a 4px margin each, which is
        // how you draw a list when you want it to look like a stack of
        // unrelated things.
        if (children.isNotEmpty) ...[
          InfoPanel(
            title: l10n.spaceChildRooms,
            padding: EdgeInsets.zero,
            children: [
              for (final child in children)
                if (child.roomId != null)
                  SpaceChildRoomRow(
                    roomId: child.roomId!,
                    room: client.getRoomById(child.roomId!),
                    suggested: child.suggested == true,
                    canEdit: canEdit,
                    onRemove: () => _removeChild(context, child.roomId!),
                  ),
            ],
          ),
          const InfoSectionGap(),
        ],

        // -- Add a room ------------------------------------------------------
        if (canEdit) ...[
          InfoPanel(
            title: l10n.addRoomToSpace,
            padding: EdgeInsets.zero,
            children: [
              if (availableRooms.isEmpty)
                Padding(
                  padding: EdgeInsets.symmetric(vertical: t.spaceXl),
                  child: Center(
                    child: Text(
                      l10n.spaceNoChildren,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  ),
                )
              else
                for (final room in availableRooms)
                  AvailableRoomRow(
                    room: room,
                    onAdd: () => _addChild(context, room.id),
                  ),
            ],
          ),
          const InfoSectionGap(),
        ],

        // -- Deleting the space -----------------------------------------------
        if (_canDeleteSpace()) ...[
          InfoPanel(
            title: l10n.actionsDeleteSection,
            children: [
              InfoPanelRow(
                icon: LucideIcons.trash2,
                label: l10n.deleteSpace,
                description: l10n.deleteSpaceDescription,
                destructive: true,
                onTap: _deleteSpace,
              ),
            ],
          ),
          SizedBox(height: t.spaceLg),
        ],
      ],
    );
  }
  // Helpers

  bool _isSpaceEncrypted(Room room) {
    try {
      return room.encrypted;
    } catch (_) {
      return false;
    }
  }

  String _creationDate(Room room) {
    final created = roomCreatedAt(room);
    if (created == null) return AppLocalizations.of(context)!.unknownDate;
    return formatIsoDay(created);
  }

  // Space editing

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
    final bytes = await readFileBytes(file);
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

  // Child room management

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

  // Space deletion

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
        builder: (ctx) => DeleteSpaceProgressDialog(
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

// Internal widgets


/// A small chip used for room metadata badges.

/// A section header label.

/// A tappable action row.

/// A read-only detail row with icon, label, and value.
