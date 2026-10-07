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
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/common/feedback.dart';

/// Shared editing dialogs for room and space settings.
///
/// These wrap the Matrix SDK calls with the most common boilerplate
/// (show a dialog, await the user's pick, post the state event).
/// Each function takes the runtime context it needs explicitly so it
/// can be called from any [State] implementation without inheritance.

/// Sets a state event on the given room.  Returns true on success,
/// false on failure.  Shows a snackbar with the result.
Future<bool> setRoomStateEvent(
  BuildContext context,
  Room room, {
  required String eventType,
  required String key,
  required dynamic value,
  String stateKey = '',
  String successMessage = 'Done',
  Logger? log,
}) async {
  try {
    await room.client.setRoomStateWithKey(
      room.id,
      eventType,
      stateKey,
      <String, dynamic>{key: value},
    );
    if (!context.mounted) return true;
    if (successMessage.isNotEmpty) {
      showFloatingSnackBar(context, successMessage);
    }
    return true;
  } catch (e) {
    log?.w('Failed to update $eventType', error: e);
    if (!context.mounted) return false;
    final l10n = AppLocalizations.of(context);
    showFloatingSnackBar(
      context,
      l10n?.actionFailed('$e') ?? 'Action failed: $e',
    );
    return false;
  }
}

/// Resolves a [JoinRules] to a localised label.
String joinRuleLabel(AppLocalizations l10n, JoinRules r) {
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

/// Shows a radio-dialog letting the user pick a join rule, and posts
/// the new value as the `m.room.join_rules` state event.  Returns
/// true when the dialog was submitted and the API call returned
/// without error.
Future<bool> editJoinRules(BuildContext context, Room room) async {
  final l10n = AppLocalizations.of(context)!;
  final selected = await showDialog<JoinRules>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(l10n.joinRuleLabel),
      children: [
        RadioGroup<JoinRules>(
          groupValue: room.joinRules,
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
                  title: Text(joinRuleLabel(l10n, r)),
                ),
            ],
          ),
        ),
      ],
    ),
  );
  if (selected == null || !context.mounted) return false;
  return setRoomStateEvent(
    context,
    room,
    eventType: 'm.room.join_rules',
    key: 'join_rule',
    value: selected.name,
  );
}

/// Shows a radio-dialog letting the user pick a history-visibility.
Future<bool> editHistoryVisibility(BuildContext context, Room room) async {
  final l10n = AppLocalizations.of(context)!;
  final options = <String, String>{
    'world_readable': l10n.historyVisibilityWorldReadable,
    'shared': l10n.historyVisibilityShared,
    'invited': l10n.historyVisibilityInvited,
    'joined': l10n.historyVisibilityJoined,
  };
  final current =
      room.getState('m.room.history_visibility')?.content['history_visibility']
              as String? ??
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
  if (selected == null || !context.mounted) return false;
  return setRoomStateEvent(
    context,
    room,
    eventType: 'm.room.history_visibility',
    key: 'history_visibility',
    value: selected,
  );
}

/// Shows a radio-dialog letting the user pick a guest-access mode.
Future<bool> editGuestAccess(BuildContext context, Room room) async {
  final l10n = AppLocalizations.of(context)!;
  final current =
      room.getState('m.room.guest_access')?.content['guest_access']
              as String? ??
          'forbidden';
  final selected = await showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(
        l10n.guestAccessSection,
      ),
      children: [
        RadioGroup<String>(
          groupValue: current,
          onChanged: (v) => Navigator.of(ctx).pop(v),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                value: 'can_join',
                title: Text(
                  l10n.guestAccessCanJoin,
                ),
              ),
              RadioListTile<String>(
                value: 'forbidden',
                title: Text(
                  l10n.guestAccessForbidden,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  if (selected == null || !context.mounted) return false;
  return setRoomStateEvent(
    context,
    room,
    eventType: 'm.room.guest_access',
    key: 'guest_access',
    value: selected,
  );
}

/// Shows a name/topic editor dialog with the given initial value, and
/// returns the (trimmed) value the user entered or `null` if cancelled.
Future<String?> editTextField(
  BuildContext context, {
  required String title,
  String? hint,
  String? initial,
  int maxLines = 1,
  String confirmLabel = 'OK',
}) async {
  final l10n = AppLocalizations.of(context)!;
  final controller = TextEditingController(text: initial ?? '');
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: TextField(
        controller: controller,
        autofocus: true,
        maxLines: maxLines,
        decoration: InputDecoration(hintText: hint),
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result;
}
