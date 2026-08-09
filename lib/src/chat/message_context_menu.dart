// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:matrix/matrix.dart';

import 'package:moonrelay/src/chat/message_action_runner.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// -----------------------------------------------------------------------------
//  Enum
// -----------------------------------------------------------------------------

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
  retry,
  cancelSend,
  kick,
  ban,
  report,
  openProfile,
}

// -----------------------------------------------------------------------------
//  Menu builder & dispatcher
// -----------------------------------------------------------------------------

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
///
/// The menu is rendered as a custom overlay positioned exactly at the pointer,
/// with a quick-actions row of icon buttons above the full list, so frequent
/// tasks (react, reply, copy) are one tap away even from the context menu.
class MessageContextMenu {
  const MessageContextMenu._();

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
    final tokens = MoonrelayThemeExtension.of(context).tokens;
    final client = room.client;
    final canDelete = event.canRedact;
    final canModerate = MessageActionRunner.canModerate(room, event);
    final canBanUser = MessageActionRunner.canBan(room, event);
    final isOwnMessage = event.senderId == client.userID;
    final canPin = room.canChangeStateEvent('m.room.pinned_events');
    final isPinned = MessageActionRunner.isPinned(room, event.eventId);
    final canEdit = MessageActionRunner.canEditText(event, room);
    final tl = timeline;
    final showEditHistory =
        tl != null && event.hasAggregatedEvents(tl, RelationshipTypes.edit);

    final isFailed = event.status.isError;

    return <PopupMenuEntry<MessageContextAction>>[
      // --- Failed-send group (only for events stuck in error state) ---
      if (isFailed) ...[
        _menuItem(
          value: MessageContextAction.retry,
          icon: Icons.refresh_rounded,
          label: l10n.retry,
          color: cs.tertiary,
          tokens: tokens,
        ),
        _menuItem(
          value: MessageContextAction.cancelSend,
          icon: Icons.close_rounded,
          label: l10n.cancel,
          color: cs.onSurfaceVariant,
          tokens: tokens,
        ),
        const PopupMenuDivider(),
      ],
      // --- Compose group ----------------------------------------------
      _menuItem(
        value: MessageContextAction.react,
        icon: Icons.add_reaction_rounded,
        label: l10n.reactTooltip,
        color: cs.onSurfaceVariant,
        tokens: tokens,
      ),
      if (hasOnReply)
        _menuItem(
          value: MessageContextAction.reply,
          icon: Icons.reply_rounded,
          label: l10n.replyTooltip,
          color: cs.onSurfaceVariant,
          tokens: tokens,
        ),
      if (hasOnForward)
        _menuItem(
          value: MessageContextAction.forward,
          icon: Icons.shortcut_rounded,
          label: l10n.forwardTooltip,
          color: cs.onSurfaceVariant,
          tokens: tokens,
        ),
      if (hasOnThread)
        _menuItem(
          value: MessageContextAction.thread,
          icon: Icons.forum_rounded,
          label: l10n.openThread,
          color: cs.onSurfaceVariant,
          tokens: tokens,
        ),
      if (canEdit) ...[
        const PopupMenuDivider(),
        _menuItem(
          value: MessageContextAction.edit,
          icon: Icons.edit_outlined,
          label: l10n.editTooltip,
          color: cs.onSurfaceVariant,
          tokens: tokens,
        ),
      ],
      if (showEditHistory)
        _menuItem(
          value: MessageContextAction.viewEditHistory,
          icon: Icons.history_rounded,
          label: l10n.viewEditHistory,
          color: cs.onSurfaceVariant,
          tokens: tokens,
        ),
      if (canPin) ...[
        _menuItem(
          value:
              isPinned ? MessageContextAction.unpin : MessageContextAction.pin,
          icon: isPinned ? Icons.push_pin : Icons.push_pin_outlined,
          label: isPinned ? l10n.unpinMessage : l10n.pinMessage,
          color: isPinned ? cs.primary : cs.onSurfaceVariant,
          tokens: tokens,
        ),
      ],
      if (canDelete) ...[
        const PopupMenuDivider(),
        _menuItem(
          value: MessageContextAction.delete,
          icon: Icons.delete_outline_rounded,
          label: l10n.deleteMessage,
          color: cs.error,
          tokens: tokens,
        ),
      ],
      // --- Sender group -----------------------------------------------
      const PopupMenuDivider(),
      _menuItem(
        value: MessageContextAction.openProfile,
        icon: Icons.person_outline_rounded,
        label: l10n.openSenderProfile,
        color: cs.onSurfaceVariant,
        tokens: tokens,
      ),
      if (!isOwnMessage && (canModerate || canBanUser)) ...[
        if (canModerate)
          _menuItem(
            value: MessageContextAction.kick,
            icon: Icons.person_remove_outlined,
            label: l10n.actionKick,
            color: cs.tertiary,
            tokens: tokens,
          ),
        if (canBanUser)
          _menuItem(
            value: MessageContextAction.ban,
            icon: Icons.block_outlined,
            label: l10n.actionBan,
            color: cs.error,
            tokens: tokens,
          ),
        _menuItem(
          value: MessageContextAction.report,
          icon: Icons.flag_outlined,
          label: l10n.actionReport,
          color: cs.error,
          tokens: tokens,
        ),
      ],
      // --- Details group ----------------------------------------------
      const PopupMenuDivider(),
      _menuItem(
        value: MessageContextAction.details,
        icon: Icons.info_outline_rounded,
        label: l10n.messageDetails,
        color: cs.onSurfaceVariant,
        tokens: tokens,
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
    VoidCallback? onEdit,
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
        if (onEdit != null) {
          onEdit();
        } else {
          await MessageActionRunner.edit(context, event, room,
              timeline: timeline);
        }
      case MessageContextAction.viewEditHistory:
        MessageActionRunner.showEditHistory(context, event, timeline, room);
      case MessageContextAction.pin:
      case MessageContextAction.unpin:
        await MessageActionRunner.togglePin(context, event, room);
      case MessageContextAction.delete:
        await MessageActionRunner.confirmDelete(context, event);
      case MessageContextAction.retry:
        await MessageActionRunner.retrySend(context, event, room);
      case MessageContextAction.cancelSend:
        await MessageActionRunner.cancelFailedSend(context, event);
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

  // --- Build a single PopupMenuItem ---------------------------------------

  static PopupMenuItem<MessageContextAction> _menuItem({
    required MessageContextAction value,
    required IconData icon,
    required String label,
    required Color color,
    required MoonrelayDesignTokens tokens,
  }) {
    return PopupMenuItem<MessageContextAction>(
      value: value,
      child: Row(
        children: [
          Icon(icon, size: tokens.iconSizeSmall, color: color),
          SizedBox(width: tokens.spaceMd),
          Text(label),
        ],
      ),
    );
  }

  // --- Show menu -----------------------------------------------------------

  /// Shows the context menu anchored at [position] (in global coordinates).
  ///
  /// Uses Flutter's standard [showMenu] API instead of a custom overlay.
  /// The menu items come from [buildEntries], with copy shortcuts prepended
  /// (they were previously in a separate quick-actions row in the overlay).
  ///
  /// Pass `null` for [onReply] / [onForward] / [onThread] / [onOpenProfile]
  /// to hide those entries from the menu.
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
    VoidCallback? onEdit,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final menuTokens = MoonrelayThemeExtension.of(context).tokens;

    final entries = buildEntries(
      context: context,
      event: event,
      room: room,
      timeline: timeline,
      hasOnReply: true,
      hasOnForward: onForward != null,
      hasOnThread: onThread != null,
    );

    // Prepend copy shortcuts so they are one tap away even from the
    // context menu (they were previously in the quick-actions row).
    final allEntries = <PopupMenuEntry<MessageContextAction>>[
      _menuItem(
        value: MessageContextAction.copy,
        icon: Icons.copy_rounded,
        label: l10n.copyTooltip,
        color: cs.onSurfaceVariant,
        tokens: menuTokens,
      ),
      _menuItem(
        value: MessageContextAction.copyEventId,
        icon: Icons.key_rounded,
        label: l10n.copyEventId,
        color: cs.onSurfaceVariant,
        tokens: menuTokens,
      ),
      _menuItem(
        value: MessageContextAction.copyLink,
        icon: Icons.link_rounded,
        label: l10n.copyMessageLink,
        color: cs.onSurfaceVariant,
        tokens: menuTokens,
      ),
      _menuItem(
        value: MessageContextAction.copyRawJson,
        icon: Icons.code_rounded,
        label: l10n.copyRawJson,
        color: cs.onSurfaceVariant,
        tokens: menuTokens,
      ),
      const PopupMenuDivider(),
      ...entries,
    ];

    // Position at the tap point in overlay coordinates.
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject() as RenderBox;
    final localPosition = overlayBox.globalToLocal(position);

    final selected = await showMenu<MessageContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(localPosition, localPosition),
        Offset.zero & overlayBox.size,
      ),
      items: allEntries,
      color: cs.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(menuTokens.radiusMd),
        side: BorderSide(
          color:
              cs.outlineVariant.withValues(alpha: menuTokens.opacityDisabled),
        ),
      ),
      elevation: menuTokens.elevationOverlay,
    );

    if (selected == null) return;

    await handleSelection(
      // ignore: use_build_context_synchronously
      context: context,
      action: selected,
      event: event,
      room: room,
      timeline: timeline,
      onReply: onReply,
      onForward: onForward,
      onThread: onThread,
      onOpenProfile: onOpenProfile,
      onEdit: onEdit,
    );
  }
}
