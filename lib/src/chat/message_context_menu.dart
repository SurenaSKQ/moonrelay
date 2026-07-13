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
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/chat_event.dart';
import 'package:moonrelay/src/chat/message_action_runner.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Stable identifier for every action exposed by [MessageContextMenu].
///
/// Values are used as the `value` of [PopupMenuEntry]s so the menu handler
/// can switch on them without using lambdas (improves testability).
enum MessageContextAction {
  react,
  reply,
  forward,
  thread,
  copy,
  copyEventId,
  copyLink,
  copyRawJson,
  details,
  edit,
  viewEditHistory,
  pin,
  unpin,
  delete,
  kick,
  ban,
  report,
  openProfile,
}

/// A rich, keyboard- and pointer-friendly context menu for chat messages.
///
/// The menu exposes every action offered by the hoverbar (react, reply,
/// forward, thread, copy, details, edit, edit history, pin/unpin, delete,
/// kick, ban, report) plus a few extras that don't fit on a compact bar:
///
/// - Open sender's profile
/// - Copy event ID
/// - Copy message permalink (`matrix.to` URL)
/// - Copy raw event JSON
///
/// Use [showForEvent] from a `GestureDetector.onSecondaryTapDown` /
/// `onLongPress` handler, or build the menu directly via [buildEntries] to
/// surface it through any host widget.
class MessageContextMenu {
  const MessageContextMenu._();

  /// Whether the current user can moderate the sender of [event].
  static bool _canModerate(Room room, Event event) {
    if (event.senderId == room.client.userID) return false;
    try {
      return room
          .unsafeGetUserFromMemoryOrFallback(event.senderId)
          .canKick;
    } catch (_) {
      return false;
    }
  }

  /// Whether the current user can ban the sender of [event].
  static bool _canBan(Room room, Event event) {
    if (event.senderId == room.client.userID) return false;
    try {
      return room
          .unsafeGetUserFromMemoryOrFallback(event.senderId)
          .canBan;
    } catch (_) {
      return false;
    }
  }

  /// Whether [event] is editable by the current user.
  static bool _canEditText(Event event, Room room) {
    final client = room.client;
    final isMine = event.senderId == client.userID;
    if (!isMine) return false;
    if (event.redacted) return false;
    if (event.relationshipEventId != null) return false;
    final mt = event.messageType;
    if (mt != MessageTypes.Text &&
        mt != MessageTypes.Emote &&
        mt != MessageTypes.Notice) {
      return false;
    }
    try {
      return event.canRedact;
    } catch (_) {
      return true;
    }
  }

  /// Whether [eventId] is currently pinned in [room].
  static bool _isPinned(Room room, String eventId) {
    final state = room.getState('m.room.pinned_events');
    if (state == null) return false;
    final pinned = state.content['pinned'];
    if (pinned is! List) return false;
    return pinned.contains(eventId);
  }

  /// Returns the canonical menu entry list, computed from the runtime
  /// permissions of the current user.
  ///
  /// Sections are visually separated using [PopupMenuDivider] so the menu
  /// reads as a grouped list rather than a flat one.
  static List<PopupMenuEntry<MessageContextAction>> buildEntries({
    required BuildContext context,
    required Event event,
    required Room room,
    required Timeline? timeline,
    required bool hasOnReply,
    required bool hasOnForward,
    required bool hasOnThread,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final client = room.client;
    final canDelete = event.canRedact;
    final canModerate = _canModerate(room, event);
    final canBanUser = _canBan(room, event);
    final isOwnMessage = event.senderId == client.userID;
    final canPin = room.canChangeStateEvent('m.room.pinned_events');
    final isPinned = _isPinned(room, event.eventId);
    final canEdit = _canEditText(event, room);
    final showEditHistory =
        isOwnMessage && isEditedMessage(event) && timeline != null;

    return <PopupMenuEntry<MessageContextAction>>[
      // ─── Compose group ──────────────────────────────────────────────
      _menuItem(
        value: MessageContextAction.react,
        icon: Icons.add_reaction_rounded,
        label: l10n.reactTooltip,
        color: cs.onSurfaceVariant,
      ),
      if (hasOnReply)
        _menuItem(
          value: MessageContextAction.reply,
          icon: Icons.reply_rounded,
          label: l10n.replyTooltip,
          color: cs.onSurfaceVariant,
        ),
      if (hasOnForward)
        _menuItem(
          value: MessageContextAction.forward,
          icon: Icons.shortcut_rounded,
          label: l10n.forwardTooltip,
          color: cs.onSurfaceVariant,
        ),
      if (hasOnThread)
        _menuItem(
          value: MessageContextAction.thread,
          icon: Icons.forum_rounded,
          label: l10n.openThread,
          color: cs.onSurfaceVariant,
        ),
      if (canEdit) ...[
        const PopupMenuDivider(),
        _menuItem(
          value: MessageContextAction.edit,
          icon: Icons.edit_outlined,
          label: l10n.editTooltip,
          color: cs.onSurfaceVariant,
        ),
      ],
      if (showEditHistory)
        _menuItem(
          value: MessageContextAction.viewEditHistory,
          icon: Icons.history_rounded,
          label: l10n.viewEditHistory,
          color: cs.onSurfaceVariant,
        ),
      if (canPin) ...[
        _menuItem(
          value: isPinned
              ? MessageContextAction.unpin
              : MessageContextAction.pin,
          icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          label: isPinned ? l10n.unpinMessage : l10n.pinMessage,
          color: isPinned ? cs.primary : cs.onSurfaceVariant,
        ),
      ],
      if (canDelete) ...[
        const PopupMenuDivider(),
        _menuItem(
          value: MessageContextAction.delete,
          icon: Icons.delete_outline_rounded,
          label: l10n.deleteMessage,
          color: cs.error,
        ),
      ],
      // ─── Sender group ───────────────────────────────────────────────
      const PopupMenuDivider(),
      _menuItem(
        value: MessageContextAction.openProfile,
        icon: Icons.person_outline_rounded,
        label: l10n.openSenderProfile,
        color: cs.onSurfaceVariant,
      ),
      if (!isOwnMessage && (canModerate || canBanUser)) ...[
        if (canModerate)
          _menuItem(
            value: MessageContextAction.kick,
            icon: Icons.person_remove_outlined,
            label: l10n.actionKick,
            color: cs.tertiary,
          ),
        if (canBanUser)
          _menuItem(
            value: MessageContextAction.ban,
            icon: Icons.block_outlined,
            label: l10n.actionBan,
            color: cs.error,
          ),
        _menuItem(
          value: MessageContextAction.report,
          icon: Icons.flag_outlined,
          label: l10n.actionReport,
          color: cs.error,
        ),
      ],
      // ─── Clipboard / inspection group ───────────────────────────────
      const PopupMenuDivider(),
      _menuItem(
        value: MessageContextAction.copy,
        icon: Icons.copy_rounded,
        label: l10n.copyMessage,
        color: cs.onSurfaceVariant,
      ),
      _menuItem(
        value: MessageContextAction.copyEventId,
        icon: Icons.tag_rounded,
        label: l10n.copyEventId,
        color: cs.onSurfaceVariant,
      ),
      _menuItem(
        value: MessageContextAction.copyLink,
        icon: Icons.link_rounded,
        label: l10n.copyMessageLink,
        color: cs.onSurfaceVariant,
      ),
      _menuItem(
        value: MessageContextAction.copyRawJson,
        icon: Icons.data_object_rounded,
        label: l10n.copyRawJson,
        color: cs.onSurfaceVariant,
      ),
      const PopupMenuDivider(),
      _menuItem(
        value: MessageContextAction.details,
        icon: Icons.info_outline_rounded,
        label: l10n.messageDetails,
        color: cs.onSurfaceVariant,
      ),
    ];
  }

  /// Dispatches the selected action to [MessageActionRunner] / the caller
  /// callbacks. Returns the resolved action so callers can decide whether
  /// to consume a long-press event themselves.
  static Future<void> handleSelection({
    required BuildContext context,
    required MessageContextAction action,
    required Event event,
    required Room room,
    required Timeline? timeline,
    required VoidCallback onReply,
    VoidCallback? onForward,
    VoidCallback? onThread,
    VoidCallback? onOpenProfile,
  }) async {
    switch (action) {
      case MessageContextAction.react:
        MessageActionRunner.react(context, event, room);
      case MessageContextAction.reply:
        onReply();
      case MessageContextAction.forward:
        onForward?.call();
      case MessageContextAction.thread:
        onThread?.call();
      case MessageContextAction.copy:
        MessageActionRunner.copy(context, event);
      case MessageContextAction.copyEventId:
        MessageActionRunner.copyEventId(context, event);
      case MessageContextAction.copyLink:
        MessageActionRunner.copyLink(context, event, room);
      case MessageContextAction.copyRawJson:
        MessageActionRunner.copyRawJson(context, event);
      case MessageContextAction.details:
        MessageActionRunner.showDetails(context, event, room);
      case MessageContextAction.edit:
        await MessageActionRunner.edit(context, event, room);
      case MessageContextAction.viewEditHistory:
        MessageActionRunner.showEditHistory(context, event, timeline, room);
      case MessageContextAction.pin:
      case MessageContextAction.unpin:
        await MessageActionRunner.togglePin(context, event, room);
      case MessageContextAction.delete:
        await MessageActionRunner.confirmDelete(context, event);
      case MessageContextAction.kick:
        await MessageActionRunner.kick(context, event, room);
      case MessageContextAction.ban:
        await MessageActionRunner.ban(context, event, room);
      case MessageContextAction.report:
        await MessageActionRunner.report(context, event, room);
      case MessageContextAction.openProfile:
        onOpenProfile?.call();
    }
  }

  /// Shows the context menu anchored at [position] (in global coordinates).
  ///
  /// Pass `null` for [onReply] / [onForward] / [onThread] / [onOpenProfile]
  /// to hide those entries from the menu  they are filtered out
  /// automatically.
  static Future<void> showForEvent({
    required BuildContext context,
    required Offset position,
    required Event event,
    required Room room,
    Timeline? timeline,
    required VoidCallback onReply,
    VoidCallback? onForward,
    VoidCallback? onThread,
    VoidCallback? onOpenProfile,
  }) async {
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (overlay == null) return;
    final cs = Theme.of(context).colorScheme;

    final entries = buildEntries(
      context: context,
      event: event,
      room: room,
      timeline: timeline,
      hasOnReply: true,
      hasOnForward: onForward != null,
      hasOnThread: onThread != null,
    );

    final selected = await showMenu<MessageContextAction>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      color: cs.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: entries,
    );

    if (selected == null) return;
    if (!context.mounted) return;

    await handleSelection(
      context: context,
      action: selected,
      event: event,
      room: room,
      timeline: timeline,
      onReply: onReply,
      onForward: onForward,
      onThread: onThread,
      onOpenProfile: onOpenProfile,
    );
  }

  static PopupMenuItem<MessageContextAction> _menuItem({
    required MessageContextAction value,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return PopupMenuItem<MessageContextAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }
}