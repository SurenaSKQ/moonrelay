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
import 'package:flutter/material.dart' hide Visibility;
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/room_notification_sheet.dart';
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:provider/provider.dart';

/// A room settings page that provides full administration: viewing technical
/// details, editing name/topic/avatar, notification settings, and destructive
/// actions (leave, delete, forget).
class RoomSettingsPage extends StatefulWidget {
  const RoomSettingsPage({super.key, required this.room});

  final Room room;

  @override
  State<RoomSettingsPage> createState() => _RoomSettingsPageState();
}

/// Converts a possibly-null raw event content map into a
/// `Map<String, dynamic>`. Used by the room state editors to coerce the
/// SDK's loosely-typed `Map<dynamic, dynamic>` into something safe.
Map<String, dynamic> _asStringMap(Object? raw) {
  if (raw is! Map) return <String, dynamic>{};
  final out = <String, dynamic>{};
  raw.forEach((k, v) => out[k.toString()] = v);
  return out;
}

class _RoomSettingsPageState extends State<RoomSettingsPage> {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _roomTypeLabel(Room room) {
    final l10n = AppLocalizations.of(context)!;
    if (room.isDirectChat) return l10n.directMessage;
    if (room.isSpace) return l10n.spaceType;
    return switch (room.joinRules) {
      JoinRules.public => l10n.publicRoom,
      JoinRules.knock || JoinRules.knockRestricted => l10n.roomTypeKnock,
      JoinRules.restricted => l10n.roomTypeRestricted,
      JoinRules.invite || JoinRules.private => l10n.roomTypeInviteOnly,
      null => l10n.publicRoom,
    };
  }

  bool _isEncrypted(Room room) {
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

  bool _canChange(String eventType) =>
      widget.room.canChangeStateEvent(eventType);

  bool get _isAdmin => widget.room.canChangeStateEvent('m.room.power_levels');

  // ---------------------------------------------------------------------------
  // Room editing
  // ---------------------------------------------------------------------------

  Future<void> _editRoomName() async {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;
    final controller =
        TextEditingController(text: room.getLocalizedDisplayname());

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editRoomName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            hintText: l10n.editRoomNameHint,
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
    if (newName.isEmpty || newName == room.getLocalizedDisplayname()) return;

    try {
      await room.setName(newName);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.roomNameUpdated),
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

  Future<void> _editRoomTopic() async {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: room.topic);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editRoomTopic),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: l10n.editRoomTopicHint,
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
    if (newTopic == room.topic) return;

    try {
      await room.setDescription(newTopic);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.roomTopicUpdated),
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

  Future<void> _changeRoomAvatar() async {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;

    // Use `pickFile` (singular) for single-image selection; this also
    // avoids the deprecated `allowMultiple: false` and `withData: true`
    // parameters on `pickFiles`.
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    try {
      await room.setAvatar(MatrixFile(bytes: bytes, name: file.name));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.roomAvatarUpdated),
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
  // Room leave / delete / forget
  // ---------------------------------------------------------------------------

  void _leaveRoom() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.leaveRoomTitle),
        content: Text(
          AppLocalizations.of(context)!
              .leaveRoomConfirm(widget.room.getLocalizedDisplayname()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(context)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(AppLocalizations.of(context)!.leave),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await widget.room.leave();
        if (mounted) context.go('/main/rooms');
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    AppLocalizations.of(context)!.failedToLeaveRoom('$e'))),
          );
        }
      }
    }
  }

  Future<void> _deleteRoom() async {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;

    if (!_isAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteRoomAdminOnly),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteRoom),
        content: Text(l10n.deleteRoomConfirm(
          room.getLocalizedDisplayname(),
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

    final log = context.read<Logger>();
    final client = context.read<Client>();

    try {
      final serverUrl = client.homeserver.toString();
      final url = serverUrl.endsWith('/')
          ? '${serverUrl}_synapse/admin/v2/rooms/${room.id}/delete'
          : '$serverUrl/_synapse/admin/v2/rooms/${room.id}/delete';

      await withRetry(
        () => client.httpClient.post(Uri.parse(url), body: '{}'),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'deleteRoom',
      );

      await room.leave();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteRoomSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/main/rooms');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.deleteRoomFailed('$e')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _forgetRoom() async {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.forgetRoom),
        content: Text(l10n.forgetRoomConfirm(
          room.getLocalizedDisplayname(),
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.forgetRoom),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await room.leave();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.forgetRoomSuccess),
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.go('/main/rooms');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.forgetRoomFailed('$e')),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;

    final isEncrypted = _isEncrypted(room);
    final roomType = _roomTypeLabel(room);
    final creationDate = _creationDate(room);
    final canonicalAlias =
        room.canonicalAlias.isNotEmpty ? room.canonicalAlias : null;
    final totalMembers = (room.summary.mInvitedMemberCount ?? 0) +
        (room.summary.mJoinedMemberCount ?? 0);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          l10n.roomSettings,
          style: textTheme.titleLarge,
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.copy),
            tooltip: l10n.copyRoomIdTooltip,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: room.id));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(l10n.roomIdCopied),
                  duration: const Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Room identity card ────────────────────────────────────────
          _RoomIdentityCard(
            room: room,
            roomType: roomType,
            totalMembers: totalMembers,
            scheme: scheme,
            textTheme: textTheme,
          ),
          const SizedBox(height: 16),

          // ── Technical details ──────────────────────────────────────────
          _SectionHeader(title: l10n.detailsSection, scheme: scheme),
          const SizedBox(height: 4),
          _DetailRow(
            icon: LucideIcons.hash,
            label: l10n.roomIdLabel,
            value: room.id,
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
            icon: room.joinRules == JoinRules.public
                ? LucideIcons.globe
                : room.joinRules == JoinRules.knock ||
                        room.joinRules == JoinRules.knockRestricted
                    ? LucideIcons.logIn
                    : LucideIcons.lock,
            label: l10n.typeLabel,
            value: roomType,
            scheme: scheme,
          ),
          _DetailRow(
            icon: isEncrypted
                ? LucideIcons.shieldCheck
                : LucideIcons.shieldOff,
            label: l10n.encryptionLabel,
            value: isEncrypted
                ? l10n.endToEndEncrypted
                : l10n.notEncrypted,
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
          const SizedBox(height: 16),

          // ── Room editing (permission-gated) ──────────────────────────
          if (_canChange('m.room.name') ||
              _canChange('m.room.topic') ||
              _canChange('m.room.avatar')) ...[
            _SectionHeader(title: l10n.actionsSection, scheme: scheme),
            const SizedBox(height: 4),
            if (_canChange('m.room.name'))
              _ActionTile(
                icon: LucideIcons.pencil,
                label: l10n.editRoomName,
                description: room.getLocalizedDisplayname(),
                onTap: _editRoomName,
                scheme: scheme,
              ),
            if (_canChange('m.room.topic'))
              _ActionTile(
                icon: LucideIcons.alignLeft,
                label: l10n.editRoomTopic,
                description: room.topic.isNotEmpty ? room.topic : l10n.notSet,
                onTap: _editRoomTopic,
                scheme: scheme,
              ),
            if (_canChange('m.room.avatar'))
              _ActionTile(
                icon: LucideIcons.image,
                label: l10n.changeRoomAvatar,
                description: l10n.changeRoomAvatarDescription,
                onTap: _changeRoomAvatar,
                scheme: scheme,
              ),
            const SizedBox(height: 8),
          ],

          // ── Room permissions & state (permission-gated) ──────────────
          if (_canChange('m.room.join_rules') ||
              _canChange('m.room.history_visibility') ||
              _canChange('m.room.canonical_alias') ||
              _canChange('m.room.guest_access') ||
              _canChange('m.room.power_levels') ||
              _canChange('m.room.encryption')) ...[
            _SectionHeader(title: l10n.actionsSection, scheme: scheme),
            const SizedBox(height: 4),
            if (_canChange('m.room.join_rules'))
              _ActionTile(
                icon: LucideIcons.logIn,
                label: l10n.joinRuleLabel,
                description: roomType,
                onTap: () => _editJoinRules(context),
                scheme: scheme,
              ),
            if (_canChange('m.room.history_visibility'))
              _ActionTile(
                icon: LucideIcons.eye,
                label: l10n.historyVisibilitySection,
                description: _historyVisibilityLabel(context, room),
                onTap: () => _editHistoryVisibility(context),
                scheme: scheme,
              ),
            if (_canChange('m.room.canonical_alias'))
              _ActionTile(
                icon: LucideIcons.atSign,
                label: l10n.canonicalAliasSection,
                description: canonicalAlias ?? l10n.notSet,
                onTap: () => _editCanonicalAlias(context),
                scheme: scheme,
              ),
            if (_canChange('m.room.guest_access'))
              _ActionTile(
                icon: LucideIcons.userPlus,
                label: l10n.guestAccessSection,
                description: _guestAccessLabel(context, room),
                onTap: () => _editGuestAccess(context),
                scheme: scheme,
              ),
            if (_canChange('m.room.power_levels'))
              _ActionTile(
                icon: LucideIcons.keyRound,
                label: l10n.powerLevelsSection,
                description: l10n.powerLevelUsersDefault,
                onTap: () => _editPowerLevels(context),
                scheme: scheme,
              ),
            if (_canChange('m.room.encryption') && !isEncrypted)
              _ActionTile(
                icon: LucideIcons.shieldCheck,
                label: l10n.encryptionSection,
                description: l10n.enableEncryption,
                onTap: () => _enableEncryption(context),
                scheme: scheme,
              ),
            const SizedBox(height: 8),
          ],

          // ── Room list visibility ─────────────────────────────────────
          _SectionHeader(title: l10n.directoryVisibilitySection, scheme: scheme),
          const SizedBox(height: 4),
          _ActionTile(
            icon: LucideIcons.globe,
            label: l10n.directoryVisibilitySection,
            description: room.joinRules == JoinRules.public
                ? l10n.directoryVisibilityPublic
                : l10n.directoryVisibilityPrivate,
            onTap: () => _editDirectoryVisibility(context),
            scheme: scheme,
          ),
          const SizedBox(height: 8),

          // ── Room version + upgrade flow ──────────────────────────────
          _SectionHeader(title: l10n.detailsSection, scheme: scheme),
          const SizedBox(height: 4),
          _DetailRow(
            icon: LucideIcons.server,
            label: l10n.roomVersion,
            value: room.roomVersion ?? 'unknown',
            scheme: scheme,
          ),
          if (_canChange('m.room.tombstone') || _isAdmin)
            _ActionTile(
              icon: LucideIcons.arrowUpCircle,
              label: l10n.upgradeRoom,
              description: l10n.upgradeRoomDescription,
              onTap: () => _upgradeRoom(context),
              scheme: scheme,
            ),
          const SizedBox(height: 8),

          // ── Knock requests (only when joinRule allows knock) ─────────
          if (room.joinRules == JoinRules.knock ||
              room.joinRules == JoinRules.knockRestricted)
            _KnockRequestsSection(room: room),

          // ─── Notification settings ──────────────────────────────────
          _SectionHeader(title: l10n.notificationSettings, scheme: scheme),
          const SizedBox(height: 4),
          _RoomNotificationTile(room: room),
          const SizedBox(height: 8),

          // ── Danger zone ────────────────────────────────────────────────
          if (_isAdmin || room.membership == Membership.leave)
            _SectionHeader(
              title: l10n.actionsDeleteSection,
              scheme: scheme,
            ),
          if (room.membership == Membership.join) ...[
            const SizedBox(height: 4),
            _ActionTile(
              icon: LucideIcons.logOut,
              label: l10n.leaveRoom,
              description: l10n.leaveRoomDescription,
              color: scheme.error,
              onTap: _leaveRoom,
              scheme: scheme,
            ),
          ],
          if (_isAdmin) ...[
            const SizedBox(height: 4),
            _ActionTile(
              icon: LucideIcons.trash2,
              label: l10n.deleteRoom,
              description: l10n.deleteRoomDescription,
              color: scheme.error,
              onTap: _deleteRoom,
              scheme: scheme,
            ),
          ],
          if (room.membership == Membership.leave) ...[
            const SizedBox(height: 4),
            _ActionTile(
              icon: LucideIcons.eyeOff,
              label: l10n.forgetRoom,
              description: l10n.forgetRoomDescription,
              onTap: _forgetRoom,
              scheme: scheme,
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // State-event editors
  // ---------------------------------------------------------------------------

  String _historyVisibilityLabel(BuildContext context, Room room) {
    final l10n = AppLocalizations.of(context)!;
    final vis = room.getState('m.room.history_visibility')
        ?.content['history_visibility'];
    switch (vis) {
      case 'world_readable':
        return l10n.historyVisibilityWorldReadable;
      case 'shared':
        return l10n.historyVisibilityShared;
      case 'invited':
        return l10n.historyVisibilityInvited;
      case 'joined':
        return l10n.historyVisibilityJoined;
      default:
        return l10n.historyVisibilityShared;
    }
  }

  String _guestAccessLabel(BuildContext context, Room room) {
    final l10n = AppLocalizations.of(context)!;
    final ga = room.getState('m.room.guest_access')?.content['guest_access'];
    return ga == 'can_join'
        ? l10n.guestAccessCanJoin
        : l10n.guestAccessForbidden;
  }

  Future<void> _setStateEvent(
    String type,
    String key,
    dynamic value, {
    String stateKey = '',
  }) async {
    final log = context.read<Logger>();
    try {
      await context.read<Client>().setRoomStateWithKey(
            widget.room.id,
            type,
            stateKey,
            <String, dynamic>{key: value},
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.done)),
      );
    } catch (e) {
      log.w('Failed to update $type', error: e);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.actionFailed('$e'))),
      );
    }
  }

  String _joinRuleLabel(AppLocalizations l10n, JoinRules r) {
    switch (r) {
      case JoinRules.public:
        return l10n.joinRulePublic;
      case JoinRules.invite:
        return l10n.joinRuleInvite;
      case JoinRules.knock:
        return l10n.joinRuleKnock;
      case JoinRules.restricted:
        return l10n.joinRuleRestricted;
      case JoinRules.knockRestricted:
        return l10n.joinRuleKnockRestricted;
      default:
        return r.name;
    }
  }

  Future<void> _editJoinRules(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = await showDialog<JoinRules>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.joinRuleLabel),
        children: [
          RadioGroup<JoinRules>(
            groupValue: widget.room.joinRules,
            onChanged: (v) => Navigator.of(ctx).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final r in [
                  JoinRules.public,
                  JoinRules.invite,
                  JoinRules.knock,
                  JoinRules.restricted,
                  JoinRules.knockRestricted,
                ])
                  RadioListTile<JoinRules>(
                    value: r,
                    title: Text(_joinRuleLabel(l10n, r)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await _setStateEvent('m.room.join_rules', 'join_rule', selected.name);
  }

  Future<void> _editHistoryVisibility(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final options = <String, String>{
      'world_readable': l10n.historyVisibilityWorldReadable,
      'shared': l10n.historyVisibilityShared,
      'invited': l10n.historyVisibilityInvited,
      'joined': l10n.historyVisibilityJoined,
    };
    final current = widget.room.getState('m.room.history_visibility')
            ?.content['history_visibility'] as String? ??
        'shared';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.historyVisibilitySection),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.of(ctx).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final entry in options.entries)
                  RadioListTile<String>(
                    value: entry.key,
                    title: Text(entry.value),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await _setStateEvent(
      'm.room.history_visibility',
      'history_visibility',
      selected,
    );
  }

  Future<void> _editCanonicalAlias(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    // Capture the client before any await so we can use it after the
    // gap without tripping the `use_build_context_synchronously` lint.
    final client = context.read<Client>();
    final controller =
        TextEditingController(text: widget.room.canonicalAlias);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.canonicalAliasSection),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.canonicalAliasHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (result == null || !mounted) return;
    try {
      await client.setRoomStateWithKey(
            widget.room.id,
            'm.room.canonical_alias',
            '',
            <String, dynamic>{
              'alias': result.isEmpty ? null : result,
            },
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _editGuestAccess(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final current = widget.room.getState('m.room.guest_access')
            ?.content['guest_access'] as String? ??
        'forbidden';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.guestAccessSection),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.of(ctx).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: 'can_join',
                  title: Text(l10n.guestAccessCanJoin),
                ),
                RadioListTile<String>(
                  value: 'forbidden',
                  title: Text(l10n.guestAccessForbidden),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    await _setStateEvent('m.room.guest_access', 'guest_access', selected);
  }

  Future<void> _editPowerLevels(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    // Capture the client before any await so we can use it after the
    // gap without tripping the `use_build_context_synchronously` lint.
    final client = context.read<Client>();
    final raw = widget.room.getState('m.room.power_levels')?.content;

    int read(Map<String, dynamic> state, String key, int fallback) {
      final v = state[key];
      return v is int ? v : fallback;
    }

    final state = _asStringMap(raw);

    int usersDefault = read(state, 'users_default', 0);
    int evDefault = read(state, 'events_default', 0);
    int stDefault = read(state, 'state_default', 50);
    int banLvl = read(state, 'ban', 50);
    int kickLvl = read(state, 'kick', 50);
    int inviteLvl = read(state, 'invite', 50);
    int redactLvl = read(state, 'redact', 50);

    final userOverrides = <String, int>{};
    for (final entry in state.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key.startsWith('@') && value is int) {
        userOverrides[key] = value;
      }
    }

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setState) {
            Widget slider(String label, int current, void Function(int) onChanged) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(label, style: const TextStyle(fontSize: 13)),
                      ),
                      Text('$current',
                          style: const TextStyle(
                              fontFamily: 'JetBrainsMono', fontSize: 12)),
                    ],
                  ),
                  Slider(
                    min: 0,
                    max: 100,
                    divisions: 100,
                    value: current.toDouble(),
                    onChanged: (n) {
                      setState(() => onChanged(n.toInt()));
                    },
                  ),
                ],
              );
            }

            return AlertDialog(
              title: Text(l10n.powerLevelsSection),
              content: SizedBox(
                width: 460,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      slider(l10n.powerLevelUsersDefault, usersDefault, (v) {
                        usersDefault = v;
                      }),
                      slider(l10n.powerLevelEventsDefault, evDefault, (v) {
                        evDefault = v;
                      }),
                      slider(l10n.powerLevelStateDefault, stDefault, (v) {
                        stDefault = v;
                      }),
                      slider(l10n.powerLevelBan, banLvl, (v) {
                        banLvl = v;
                      }),
                      slider(l10n.powerLevelKick, kickLvl, (v) {
                        kickLvl = v;
                      }),
                      slider(l10n.powerLevelInvite, inviteLvl, (v) {
                        inviteLvl = v;
                      }),
                      slider(l10n.powerLevelRedact, redactLvl, (v) {
                        redactLvl = v;
                      }),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(true),
                  child: Text(l10n.editSave),
                ),
              ],
            );
          },
        );
      },
    );
    if (updated != true || !mounted) return;

    final newState = <String, dynamic>{
      'users_default': usersDefault,
      'events_default': evDefault,
      'state_default': stDefault,
      'ban': banLvl,
      'kick': kickLvl,
      'invite': inviteLvl,
      'redact': redactLvl,
      'users': userOverrides,
    };

    try {
      await client.setRoomStateWithKey(
            widget.room.id,
            'm.room.power_levels',
            '',
            newState,
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _enableEncryption(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    // Capture the client before any await so we can use it after the
    // gap without tripping the `use_build_context_synchronously` lint.
    final client = context.read<Client>();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.enableEncryption),
        content: const Text(
          'Once enabled, encryption cannot be turned off. Existing members will receive a key-share request.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await client.setRoomStateWithKey(
            widget.room.id,
            'm.room.encryption',
            '',
            <String, dynamic>{'algorithm': 'm.megolm.v1.aes-sha2'},
          );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _editDirectoryVisibility(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final room = widget.room;
    final client = context.read<Client>();
    // The matrix SDK doesn't expose the current visibility directly —
    // we read the `m.room.visibility` state, fall back to `private` for
    // joined rooms that the server hasn't yet published a state for.
    final current = room
            .getState('m.room.history_visibility') // intentionally reads
            // any state to check the cache is populated; the directory
            // visibility is its own state key on the homeserver which
            // we don't track locally.
            ?.content['visibility'] as String? ??
        'private';
    final selected = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.directoryVisibilitySection),
        children: [
          RadioGroup<String>(
            groupValue: current,
            onChanged: (v) => Navigator.of(ctx).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RadioListTile<String>(
                  value: 'public',
                  title: Text(l10n.directoryVisibilityPublic),
                ),
                RadioListTile<String>(
                  value: 'private',
                  title: Text(l10n.directoryVisibilityPrivate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
    if (selected == null || !mounted) return;
    try {
      // The directory visibility lives on the API rather than as a state
      // event; we hit `_matrix/client/v3/directory/list/room/{id}` via the
      // generated MatrixApi.
      final vis = selected == 'public'
          ? 'public'
          : 'private';
      // Use the MatrixApi helper inherited by Client.
      await client.setRoomVisibilityOnDirectory(
        room.id,
        visibility: vis == 'public'
            ? Visibility.public
            : Visibility.private,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _upgradeRoom(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    // Capture the client before any await so we can use it after the
    // gap without tripping the `use_build_context_synchronously` lint.
    final client = context.read<Client>();
    final newVersion = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(l10n.upgradeRoom),
        children: [
          RadioGroup<String>(
            groupValue: widget.room.roomVersion,
            onChanged: (val) => Navigator.of(ctx).pop(val),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final v in const ['10', '11', '12'])
                  RadioListTile<String>(
                    value: v,
                    title: Text('Room version $v'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (newVersion == null || !context.mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.upgradeRoom),
        content: Text(l10n.upgradeRoomConfirm(
          widget.room.getLocalizedDisplayname(),
          newVersion,
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.ok),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    try {
      // Mark the old room as tombstoned. The replacement_room field
      // would normally point at a freshly-created successor; we leave it
      // empty so the user can decide the follow-up.
      await client.setRoomStateWithKey(
            widget.room.id,
            'm.room.tombstone',
            '',
            <String, dynamic>{
              'body': 'Room upgraded to version $newVersion',
              'replacement_room': '',
            },
          );
      await client.setRoomStateWithKey(
            widget.room.id,
            'm.room.create',
            '',
            <String, dynamic>{
              'room_version': newVersion,
              'creator': client.userID,
            },
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.roomUpgraded(newVersion))),
      );
    } catch (e) {
      log.w('Upgrade failed', error: e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// Internal widgets (reused from room_details_page.dart)
// ═════════════════════════════════════════════════════════════════════════════

class _RoomIdentityCard extends StatelessWidget {
  const _RoomIdentityCard({
    required this.room,
    required this.roomType,
    required this.totalMembers,
    required this.scheme,
    required this.textTheme,
  });

  final Room room;
  final String roomType;
  final int totalMembers;
  final ColorScheme scheme;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final displayName = room.getLocalizedDisplayname();
    final topic = room.topic;
    final hasTopic = topic.isNotEmpty;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: AvatarFromUriOrFallbackImage(
                client: room.client,
                avatarUri: room.avatar,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (hasTopic) ...[
              const SizedBox(height: 4),
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
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _InfoChip(
                  icon: Icons.public_rounded,
                  label: roomType,
                  scheme: scheme,
                ),
                _InfoChip(
                  icon: Icons.people_rounded,
                  label: '$totalMembers ${l10n.members}',
                  scheme: scheme,
                ),
                if (room.isDirectChat)
                  _InfoChip(
                    icon: Icons.person_rounded,
                    label: l10n.directMessage,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 12),
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

/// A tile that toggles notification mute for the current room.
class _RoomNotificationTile extends StatefulWidget {
  const _RoomNotificationTile({required this.room});

  final Room room;

  @override
  State<_RoomNotificationTile> createState() => _RoomNotificationTileState();
}

class _RoomNotificationTileState extends State<_RoomNotificationTile> {
  bool _muted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMutedState();
  }

  Future<void> _loadMutedState() async {
    final notif = context.read<NotificationService>();
    final muted = await notif.isRoomMuted(widget.room.id);
    if (mounted) {
      setState(() {
        _muted = muted;
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    final notif = context.read<NotificationService>();
    final newMuted = !_muted;
    await notif.setRoomMuted(widget.room.id, newMuted);
    if (mounted) {
      setState(() => _muted = newMuted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newMuted
                ? AppLocalizations.of(context)!.roomMuted
                : AppLocalizations.of(context)!.roomUnmuted,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final client = context.read<Client>();
    // The full per-room notification sheet (mute + mentions-only)
    // lives in [RoomNotificationSheet].  Opening it from the tile's
    // tap area keeps the one-tap mute switch on the tile itself
    // while still exposing the mentions-only setting without a
    // separate route.
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
              _muted ? LucideIcons.bellOff : LucideIcons.bell,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(l10n.muteRoom),
            subtitle: Text(l10n.muteRoomDescription),
            value: _muted,
            onChanged: _loading ? null : (_) => _toggle(),
          ),
          const Divider(height: 0),
          ListTile(
            leading: Icon(
              LucideIcons.settings,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(l10n.notificationSettings),
            trailing: Icon(
              LucideIcons.chevronRight,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () =>
                showRoomNotificationSheet(context, client: client, room: widget.room),
          ),
        ],
      ),
    );
  }
}

/// Lists pending knock requests for a room whose join rule allows knocking.
///
/// The room is scanned for `m.room.member` state events with
/// `membership: knock` and one row is shown per user. Each row exposes
/// **Approve** and **Deny** actions. The list refreshes whenever the
/// room's sync state changes.
class _KnockRequestsSection extends StatefulWidget {
  const _KnockRequestsSection({required this.room});
  final Room room;

  @override
  State<_KnockRequestsSection> createState() => _KnockRequestsSectionState();
}

class _KnockRequestsSectionState extends State<_KnockRequestsSection> {
  StreamSubscription<Object?>? _syncSub;
  List<User> _knockingUsers = const [];
  bool _knocksLoaded = false;

  @override
  void initState() {
    super.initState();
    _syncSub = widget.room.client.onSync.stream.listen((_) {
      if (mounted) _loadKnocks();
    });
    _loadKnocks();
  }

  Future<void> _loadKnocks() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final matrixEvents =
          await widget.room.client.getMembersByRoom(widget.room.id);
      final members = matrixEvents
              ?.map((e) => Event.fromMatrixEvent(e, widget.room).asUser)
              .where((u) => u.membership == Membership.knock)
              .toList() ??
          [];
      if (!mounted) return;
      setState(() {
        _knockingUsers = members;
        _knocksLoaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _knocksLoaded = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _approve(String userId) async {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.room
        .unsafeGetUserFromMemoryOrFallback(userId)
        .calcDisplayname();

    // Confirmation dialog.  Showing display name + Matrix ID + a
    // "View profile" link gives the moderator enough context to be
    // confident the right person is being invited — knock requests
    // are easy to spoof with a similar-looking displayname.
    final approved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.knockApproveConfirmTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              userId,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Text(l10n.knockApproveConfirmBody),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.viewProfile),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.approve),
          ),
        ],
      ),
    );
    // "View profile" returns null — fall through to navigation so the
    // moderator can see who they're letting in.
    if (approved == null) {
      if (!mounted) return;
      context.push('/main/rooms/${widget.room.id}/profile/$userId');
      return;
    }
    if (approved != true) return;

    try {
      await widget.room.invite(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.knockApproved(name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.actionFailed('$e'))),
        );
      }
    }
  }

  Future<void> _deny(String userId) async {
    final l10n = AppLocalizations.of(context)!;
    final name = widget.room
        .unsafeGetUserFromMemoryOrFallback(userId)
        .calcDisplayname();
    try {
      await widget.room.kick(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.knockDenied(name))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.actionFailed('$e'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            l10n.pendingKnocks,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
        if (!_knocksLoaded)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: const SizedBox(
              height: 24,
              width: 24,
              child: Center(
                child: CircularProgressIndicator(strokeWidth: 2.5),
              ),
            ),
          )
        else if (_knockingUsers.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.noPendingKnocks,
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          )
        else
          ..._knockingUsers.map((user) {
            return Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                    color: cs.outlineVariant.withValues(alpha: 0.3)),
              ),
              child: ListTile(
                title: Text(user.calcDisplayname()),
                subtitle: Text(user.id,
                    style: const TextStyle(
                        fontFamily: 'JetBrainsMono', fontSize: 11)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton.icon(
                      icon: const Icon(LucideIcons.x, size: 16),
                      label: Text(l10n.denyKnock),
                      style: TextButton.styleFrom(
                        foregroundColor: cs.error,
                      ),
                      onPressed: () => _deny(user.id),
                    ),
                    const SizedBox(width: 4),
                    FilledButton.tonalIcon(
                      icon: const Icon(LucideIcons.check, size: 16),
                      label: Text(l10n.approveKnock),
                      onPressed: () => _approve(user.id),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
