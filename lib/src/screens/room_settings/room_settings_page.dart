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
import 'package:moonrelay/src/helpers/upload_limits.dart';
import 'package:moonrelay/src/helpers/feedback.dart';
import 'package:moonrelay/src/helpers/room_dates.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/widgets/identity_header.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:moonrelay/src/screens/room_settings/power_levels_editor.dart';
import 'package:moonrelay/src/screens/room_settings/room_notification_tile.dart';
import 'package:moonrelay/src/screens/room_settings/knock_requests_section.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
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

class _RoomSettingsPageState extends State<RoomSettingsPage> {
  // Helpers

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
      // The SDK throws when the room's `m.room.encryption` state has not
      // loaded. Not encrypted as far as this screen can tell, which is
      // the safe direction: the encryption badge is informational, the
      // real enforcement is in the SDK.
      return false;
    }
  }

  String _creationDate(Room room) {
    final created = roomCreatedAt(room);
    if (created == null) return AppLocalizations.of(context)!.unknownDate;
    return formatIsoDay(created);
  }

  bool _canChange(String eventType) =>
      widget.room.canChangeStateEvent(eventType);

  bool get _isAdmin => widget.room.canChangeStateEvent('m.room.power_levels');

  /// Whether the current user can leave this room.
  ///
  /// Membership only, never a power level. The SDK bakes
  /// `membership == Membership.join` into every capability getter it offers, so
  /// this is the whole of the check: leave is self-targeted and unprivileged.
  bool get canLeave => widget.room.membership == Membership.join;

  /// Whether the current user can forget this room.
  ///
  /// Only after leaving. Forget purges local state and asks the server to drop
  /// it, which the spec only permits once you are out of the room.
  bool get canForget => widget.room.membership == Membership.leave;

  // Room editing

  Future<void> _editRoomName() async {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;
    final newName = await _promptText(
      title: l10n.editRoomName,
      hintText: l10n.editRoomNameHint,
      initial: room.getLocalizedDisplayname(),
    );
    // A room always has a name, so an empty one is a rejected edit rather
    // than a request to clear the field.
    if (newName == null || newName.isEmpty || !mounted) return;
    if (newName == room.getLocalizedDisplayname()) return;

    await context.showActionResult(
      action: () => room.setName(newName),
      successMessage: l10n.roomNameUpdated,
      floating: true,
      formatError: (e) => '${l10n.error}: $e',
    );
  }

  Future<void> _editRoomTopic() async {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;
    // Unlike the name, an empty topic is a legitimate way to clear it.
    final newTopic = await _promptText(
      title: l10n.editRoomTopic,
      hintText: l10n.editRoomTopicHint,
      initial: room.topic,
      maxLines: 3,
    );
    if (newTopic == null || !mounted) return;
    if (newTopic == room.topic) return;

    await context.showActionResult(
      action: () => room.setDescription(newTopic),
      successMessage: l10n.roomTopicUpdated,
      floating: true,
      formatError: (e) => '${l10n.error}: $e',
    );
  }

  Future<void> _changeRoomAvatar() async {
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;

    // Use `pickFile` (singular) for single-image selection; this also
    // avoids the deprecated `allowMultiple: false` and `withData: true`
    // parameters on `pickFiles`.
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await readFileBytes(file);
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

  // Room leave / delete / forget

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
        () => client.httpClient.post(
          Uri.parse(url),
          body: '{}',
          headers: {'authorization': 'Bearer ${client.accessToken}'},
        ),
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
      // `forget`, not `leave`. This called `leave` and then reported
      // `forgetRoomSuccess`, so the user was told a room had been forgotten
      // while the server still held it and the local row was untouched. Forget
      // is a separate operation: it purges the local database row and POSTs
      // `/forget`, and the spec only allows it once you have already left,
      // which is what [canForget] gates on.
      await room.forget();
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

  // Build

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final room = widget.room;
    final l10n = AppLocalizations.of(context)!;

    final isEncrypted = _isEncrypted(room);
    final roomType = _roomTypeLabel(room);
    final creationDate = _creationDate(room);
    final canonicalAlias =
        room.canonicalAlias.isNotEmpty ? room.canonicalAlias : null;
    final totalMembers = (room.summary.mInvitedMemberCount ?? 0) +
        (room.summary.mJoinedMemberCount ?? 0);

    return MoonrelayInfoPage(
      title: l10n.roomSettings,
      actions: [
        IconButton(
          icon: const Icon(LucideIcons.copy),
          tooltip: l10n.copyRoomIdTooltip,
          onPressed: _copyRoomIdWithFeedback,
        ),
      ],
      children: [
        IdentityHeader(
          name: room.getLocalizedDisplayname(),
          topic: room.topic,
          avatar: SizedBox(
            width: 56,
            height: 56,
            child: AvatarFromUriOrFallbackImage(
              client: room.client,
              avatarUri: room.avatar,
            ),
          ),
          chips: [
            InfoChip(
              icon: room.joinRules == JoinRules.public
                  ? LucideIcons.globe
                  : LucideIcons.lock,
              label: roomType,
            ),
            InfoChip(
                icon: LucideIcons.users,
                label: '$totalMembers ${l10n.members}'),
            if (room.encrypted)
              InfoChip(
                icon: LucideIcons.shieldCheck,
                label: l10n.endToEndEncrypted,
                emphasis: true,
              ),
          ],
        ),

        const InfoSectionGap(first: true),

        // -- What this room is ------------------------------------------
        // Facts first and edits below. The previous order put the facts in a
        // panel headed "Details" and the editable state under a second panel
        // *also* headed "Actions", so two adjacent sections on one page had
        // the same title and the reader could not tell which was which.
        InfoPanel(
          title: l10n.detailsSection,
          children: [
            InfoPanelRow(
              icon: LucideIcons.fingerprint,
              label: l10n.roomIdLabel,
              description: room.id,
              valueFontFamily: MoonrelayTypography.mono(context),
            ),
            if (canonicalAlias != null)
              InfoPanelRow(
                icon: LucideIcons.hash,
                label: l10n.addressLabel,
                value: canonicalAlias,
              ),
            InfoPanelRow(
              icon: LucideIcons.tag,
              label: l10n.typeLabel,
              value: roomType,
            ),
            InfoPanelRow(
              icon:
                  isEncrypted ? LucideIcons.shieldCheck : LucideIcons.shieldOff,
              label: l10n.encryptionLabel,
              value: isEncrypted ? l10n.endToEndEncrypted : l10n.notEncrypted,
            ),
            InfoPanelRow(
              icon: LucideIcons.calendar,
              label: l10n.createdLabel,
              value: creationDate,
            ),
            InfoPanelRow(
              icon: LucideIcons.server,
              label: l10n.roomVersion,
              value: room.roomVersion ?? 'unknown',
              valueFontFamily: MoonrelayTypography.mono(context),
            ),
          ],
        ),

        const InfoSectionGap(),

        // -- Editing the room's own fields -------------------------------
        if (_canChange('m.room.name') ||
            _canChange('m.room.topic') ||
            _canChange('m.room.avatar'))
          InfoPanel(
            title: l10n.roomDetailsEditSection,
            children: [
              if (_canChange('m.room.name'))
                InfoPanelRow(
                  icon: LucideIcons.pencil,
                  label: l10n.editRoomName,
                  description: room.getLocalizedDisplayname(),
                  onTap: _editRoomName,
                ),
              if (_canChange('m.room.topic'))
                InfoPanelRow(
                  icon: LucideIcons.alignLeft,
                  label: l10n.editRoomTopic,
                  description: room.topic.isNotEmpty ? room.topic : l10n.notSet,
                  onTap: _editRoomTopic,
                ),
              if (_canChange('m.room.avatar'))
                InfoPanelRow(
                  icon: LucideIcons.image,
                  label: l10n.changeRoomAvatar,
                  description: l10n.changeRoomAvatarDescription,
                  onTap: _changeRoomAvatar,
                ),
            ],
          ),

        if (_canChange('m.room.name') ||
            _canChange('m.room.topic') ||
            _canChange('m.room.avatar'))
          const InfoSectionGap(),

        // -- Access and history ------------------------------------------
        if (_canChange('m.room.join_rules') ||
            _canChange('m.room.history_visibility') ||
            _canChange('m.room.canonical_alias') ||
            _canChange('m.room.guest_access') ||
            _canChange('m.room.power_levels') ||
            _canChange('m.room.encryption'))
          InfoPanel(
            title: l10n.accessAndHistorySection,
            children: [
              if (_canChange('m.room.join_rules'))
                InfoPanelRow(
                  icon: LucideIcons.doorOpen,
                  label: l10n.joinRuleLabel,
                  description: roomType,
                  onTap: () => _editJoinRules(context),
                ),
              if (_canChange('m.room.history_visibility'))
                InfoPanelRow(
                  icon: LucideIcons.eye,
                  label: l10n.historyVisibilitySection,
                  description: _historyVisibilityLabel(context, room),
                  onTap: () => _editHistoryVisibility(context),
                ),
              if (_canChange('m.room.guest_access'))
                InfoPanelRow(
                  icon: LucideIcons.userPlus,
                  label: l10n.guestAccessSection,
                  description: _guestAccessLabel(context, room),
                  onTap: () => _editGuestAccess(context),
                ),
              if (_canChange('m.room.power_levels'))
                InfoPanelRow(
                  icon: LucideIcons.keyRound,
                  label: l10n.powerLevelsSection,
                  description: l10n.powerLevelUsersDefault,
                  onTap: () => _editPowerLevels(context),
                ),
              if (_canChange('m.room.canonical_alias'))
                InfoPanelRow(
                  icon: LucideIcons.atSign,
                  label: l10n.canonicalAliasSection,
                  description: canonicalAlias ?? l10n.notSet,
                  onTap: () => _editCanonicalAlias(context),
                ),
              if (_canChange('m.room.encryption') && !isEncrypted)
                InfoPanelRow(
                  icon: LucideIcons.shieldCheck,
                  label: l10n.encryptionSection,
                  description: l10n.enableEncryption,
                  onTap: () => _enableEncryption(context),
                ),
            ],
          ),

        if (_canChange('m.room.join_rules') ||
            _canChange('m.room.history_visibility') ||
            _canChange('m.room.canonical_alias') ||
            _canChange('m.room.guest_access') ||
            _canChange('m.room.power_levels') ||
            _canChange('m.room.encryption'))
          const InfoSectionGap(),

        // -- Discoverability ----------------------------------------------
        InfoPanel(
          title: l10n.directoryVisibilitySection,
          children: [
            InfoPanelRow(
              icon: LucideIcons.globe,
              label: l10n.directoryVisibilitySection,
              description: room.joinRules == JoinRules.public
                  ? l10n.directoryVisibilityPublic
                  : l10n.directoryVisibilityPrivate,
              onTap: () => _editDirectoryVisibility(context),
            ),
            // Upgrade sits in the same panel as the other things that change
            // what *other* people see about this room. It used to sit under a
            // second panel titled "Details", which was a duplicate title and
            // put a version-upgrade button next to a read-only version number.
            if (_canChange('m.room.tombstone') || _isAdmin)
              InfoPanelRow(
                icon: LucideIcons.arrowUpCircle,
                label: l10n.upgradeRoom,
                description: l10n.upgradeRoomDescription,
                onTap: () => _upgradeRoom(context),
              ),
          ],
        ),

        const InfoSectionGap(),

        // -- Knock requests, only when the join rule allows them --------
        if (room.joinRules == JoinRules.knock ||
            room.joinRules == JoinRules.knockRestricted) ...[
          KnockRequestsSection(room: room),
          const InfoSectionGap(),
        ],

        // -- Notifications ------------------------------------------------
        InfoPanel(
          title: l10n.notificationSettings,
          padding: EdgeInsets.zero,
          children: [
            RoomNotificationTile(room: room),
          ],
        ),

        const InfoSectionGap(),

        // -- Leaving and deleting ------------------------------------------
        // One panel, and the destructive rows are last in it rather than in
        // their own panel. "Leave", "delete" and "forget" are the same kind of
        // decision at different severities, and separating them into three
        // one-row panels made the mildest of them look as final as the worst.
        //
        // The panel is gated on whether it has anything to show, not on who is
        // looking at it. It used to be wrapped in `_isAdmin ||`, which meant
        // that "Leave room" required power level 50, because the row's own
        // membership check was nested inside an admin-only panel and therefore
        // only ever reachable by an admin. Leaving is
        // `POST /rooms/{id}/leave`, a self-targeted `m.room.member` event that
        // the spec puts no power requirement on at all, so the gate hid the one
        // destructive action every single member is entitled to take from
        // exactly the people who most often want it.
        //
        // This is the same bug as the one `message_context_menu.dart` already
        // documents for Report: an unprivileged action gated on power, hiding
        // it from the users who need it.
        if (canLeave || canForget || _isAdmin) ...[
          InfoPanel(
            title: l10n.actionsDeleteSection,
            children: [
              if (canLeave)
                InfoPanelRow(
                  icon: LucideIcons.logOut,
                  label: l10n.leaveRoom,
                  description: l10n.leaveRoomDescription,
                  destructive: true,
                  onTap: _leaveRoom,
                ),
              if (_isAdmin)
                InfoPanelRow(
                  icon: LucideIcons.trash2,
                  label: l10n.deleteRoom,
                  description: l10n.deleteRoomDescription,
                  destructive: true,
                  onTap: _deleteRoom,
                ),
              if (canForget)
                InfoPanelRow(
                  icon: LucideIcons.eyeOff,
                  label: l10n.forgetRoom,
                  description: l10n.forgetRoomDescription,
                  onTap: _forgetRoom,
                ),
            ],
          ),
          SizedBox(height: t.spaceLg),
        ],
      ],
    );
  }

  /// Copies the room id and confirms it, rather than copying silently.
  ///
  /// The confirmation used to be inlined in the [AppBar] callback, which meant
  /// it was the one copy in the app with no logger and no `FeedbackContext`
  /// helper and the reader had no way to tell whether it had worked.
  void _copyRoomIdWithFeedback() {
    Clipboard.setData(ClipboardData(text: widget.room.id));
    context.showMessage(
      AppLocalizations.of(context)!.roomIdCopied,
      duration: const Duration(seconds: 2),
    );
  }

  // State-event editors

  String _historyVisibilityLabel(BuildContext context, Room room) {
    final l10n = AppLocalizations.of(context)!;
    final vis = room
        .getState('m.room.history_visibility')
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
    await context.showActionResult(
      action: () => context.read<Client>().setRoomStateWithKey(
        widget.room.id,
        type,
        stateKey,
        <String, dynamic>{key: value},
      ),
      successMessage: AppLocalizations.of(context)!.done,
      floating: true,
      log: log,
      logLabel: 'update $type',
    );
  }

  /// Shows a radio list and returns the picked value, or `null` on cancel.
  ///
  /// Every "one of a fixed set of enum-ish strings" room setting is this
  /// dialog with a different title and list, so the pre-change copy of it
  /// appeared six times in this file.
  Future<T?> _pickOption<T>({
    required String title,
    required T? current,
    required List<T> values,
    required String Function(T value) labelOf,
  }) {
    return showDialog<T>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title),
        children: [
          RadioGroup<T>(
            groupValue: current,
            onChanged: (v) => Navigator.of(ctx).pop(v),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final value in values)
                  RadioListTile<T>(
                    value: value,
                    title: Text(labelOf(value)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Shows a single-line (or multi-line) text prompt and returns the trimmed
  /// text, or `null` on cancel.
  ///
  /// An empty string is a valid answer here: clearing the room alias or the
  /// topic is a real edit, so the caller cannot treat "empty" as "cancel".
  Future<String?> _promptText({
    required String title,
    String? hintText,
    String initial = '',
    int maxLines = 1,
  }) {
    final controller = TextEditingController(text: initial);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: maxLines,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(hintText: hintText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(AppLocalizations.of(ctx)!.ok),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
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
    final selected = await _pickOption<JoinRules>(
      title: l10n.joinRuleLabel,
      current: widget.room.joinRules,
      values: const [
        JoinRules.public,
        JoinRules.invite,
        JoinRules.knock,
        JoinRules.restricted,
        JoinRules.knockRestricted,
      ],
      labelOf: (r) => _joinRuleLabel(l10n, r),
    );
    if (selected == null || !mounted) return;
    await _setStateEvent('m.room.join_rules', 'join_rule', selected.name);
  }

  Future<void> _editHistoryVisibility(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final current = widget.room
            .getState('m.room.history_visibility')
            ?.content['history_visibility'] as String? ??
        'shared';
    final selected = await _pickOption<String>(
      title: l10n.historyVisibilitySection,
      current: current,
      values: const ['world_readable', 'shared', 'invited', 'joined'],
      labelOf: (value) => switch (value) {
        'world_readable' => l10n.historyVisibilityWorldReadable,
        'invited' => l10n.historyVisibilityInvited,
        'joined' => l10n.historyVisibilityJoined,
        _ => l10n.historyVisibilityShared,
      },
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
    final result = await _promptText(
      title: l10n.canonicalAliasSection,
      hintText: l10n.canonicalAliasHint,
      initial: widget.room.canonicalAlias,
    );
    if (result == null || !context.mounted) return;
    // An empty alias is a real edit (it removes the alias), so this sends
    // an explicit null rather than skipping the request.
    await context.showActionResult(
      action: () => client.setRoomStateWithKey(
        widget.room.id,
        'm.room.canonical_alias',
        '',
        <String, dynamic>{
          'alias': result.isEmpty ? null : result,
        },
      ),
      successMessage: null,
      floating: true,
    );
  }

  Future<void> _editGuestAccess(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final current = widget.room
            .getState('m.room.guest_access')
            ?.content['guest_access'] as String? ??
        'forbidden';
    final selected = await _pickOption<String>(
      title: l10n.guestAccessSection,
      current: current,
      values: const ['can_join', 'forbidden'],
      labelOf: (value) => value == 'can_join'
          ? l10n.guestAccessCanJoin
          : l10n.guestAccessForbidden,
    );
    if (selected == null || !mounted) return;
    await _setStateEvent('m.room.guest_access', 'guest_access', selected);
  }

  Future<void> _editPowerLevels(BuildContext context) {
    return showPowerLevelsEditor(context, widget.room);
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
    // The matrix SDK doesn't expose the current visibility directly
    // we read the `m.room.visibility` state, fall back to `private` for
    // joined rooms that the server hasn't yet published a state for.
    final current = room
            .getState('m.room.history_visibility') // intentionally reads
            // any state to check the cache is populated; the directory
            // visibility is its own state key on the homeserver which
            // we don't track locally.
            ?.content['visibility'] as String? ??
        'private';
    final selected = await _pickOption<String>(
      title: l10n.directoryVisibilitySection,
      current: current,
      values: const ['public', 'private'],
      labelOf: (value) => value == 'public'
          ? l10n.directoryVisibilityPublic
          : l10n.directoryVisibilityPrivate,
    );
    if (selected == null || !context.mounted) return;
    // The directory visibility lives on the API rather than as a state
    // event; we hit `_matrix/client/v3/directory/list/room/{id}` via the
    // generated MatrixApi.
    await context.showActionResult(
      action: () => client.setRoomVisibilityOnDirectory(
        room.id,
        visibility:
            selected == 'public' ? Visibility.public : Visibility.private,
      ),
      successMessage: null,
      floating: true,
    );
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
