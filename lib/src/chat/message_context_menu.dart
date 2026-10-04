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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';

import 'package:moonrelay/src/chat/message_action_runner.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/menu_row.dart';

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

/// The message context menu: right-click or long-press on a message.
///
/// This class is the single source of truth for the menu's contents. It used
/// not to be, and the two halves had drifted:
///
/// - [buildEntries] did not contain the four copy actions. They were prepended
///   by [showForEvent] after the call, so the method's own documentation and
///   its name ("the canonical menu entry list") were both wrong, and any other
///   caller of [buildEntries] got a different menu from the one users see.
/// - The order put those four above react and reply, so the two most-used
///   actions on a message started four rows down. The class comment claimed a
///   quick-actions row kept them one tap away; the implementation had removed
///   the row and left the entries where the row used to be.
/// - Reporting was gated behind `canKick || canBan`. Reporting a user is a
///   report to your own homeserver and needs no room power level at all, so
///   this hid it from exactly the people who most need it: a user with no
///   power in a room cannot report anybody in it. The hoverbar's separate
///   moderation popup gated the whole widget the same way, and its inner
///   report row was written unconditionally, so it was unreachable.
///
/// Ordering is now by frequency: the things you do with almost every message,
/// then the things you do with messages you wrote, then power actions, then
/// the destructive ones, then reference material. Destructive actions sit
/// below a divider rather than in the flow, because "delete" three rows above
/// "copy event id" is how you redact something you meant to quote.
class MessageContextMenu {
  const MessageContextMenu._();

  /// Returns the canonical menu entry list, computed from the runtime
  /// permissions of the current user.
  ///
  /// This is the whole menu. There is no post-processing: whatever
  /// [showForEvent] renders is exactly what this returns, in this order.
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
    final canKick = MessageActionRunner.canModerate(room, event);
    final canBanUser = MessageActionRunner.canBan(room, event);
    final isOwnMessage = event.senderId == client.userID;
    final canPin = room.canChangeStateEvent('m.room.pinned_events');
    final isPinned = MessageActionRunner.isPinned(room, event.eventId);
    final canEdit = MessageActionRunner.canEditText(event, room);
    final tl = timeline;
    final showEditHistory =
        tl != null && event.hasAggregatedEvents(tl, RelationshipTypes.edit);

    final isFailed = event.status.isError;
    // Destructive "remove this" appears in both failure states and must not
    // also be offered as a redaction of an event the server never received.
    final showDelete = canDelete && !isFailed;

    // -- Everyday actions -------------------------------------------------
    final everyday = <PopupMenuEntry<MessageContextAction>>[
      _item(
          MessageContextAction.react, LucideIcons.smilePlus, l10n.reactTooltip),
      if (hasOnReply)
        _item(MessageContextAction.reply, LucideIcons.reply, l10n.replyTooltip),
      if (hasOnForward)
        _item(MessageContextAction.forward, LucideIcons.forward,
            l10n.forwardTooltip),
      if (hasOnThread)
        _item(MessageContextAction.thread, LucideIcons.messagesSquare,
            l10n.openThread),
      if (canEdit)
        _item(MessageContextAction.edit, LucideIcons.pencil, l10n.editTooltip),
      if (showEditHistory)
        _item(MessageContextAction.viewEditHistory, LucideIcons.history,
            l10n.viewEditHistory),
      if (canPin)
        _item(
          isPinned ? MessageContextAction.unpin : MessageContextAction.pin,
          isPinned ? LucideIcons.pinOff : LucideIcons.pin,
          isPinned ? l10n.unpinMessage : l10n.pinMessage,
          color: isPinned ? cs.primary : null,
        ),
    ];

    // -- Copy -------------------------------------------------------------
    final copy = <PopupMenuEntry<MessageContextAction>>[
      _item(MessageContextAction.copy, LucideIcons.copy, l10n.copyTooltip),
      _item(MessageContextAction.copyLink, LucideIcons.link,
          l10n.copyMessageLink),
      _item(
          MessageContextAction.copyEventId, LucideIcons.key, l10n.copyEventId),
      _item(MessageContextAction.copyRawJson, LucideIcons.braces,
          l10n.copyRawJson),
    ];

    // -- Sender and moderation -------------------------------------------
    final sender = <PopupMenuEntry<MessageContextAction>>[
      _item(MessageContextAction.openProfile, LucideIcons.user,
          l10n.openSenderProfile),
      // Report is not a room power action. Anyone may report a user to their
      // own homeserver, so it is offered on every message from someone else
      // whether or not they can be kicked. Gating it on power level, as this
      // did, hid it from exactly the users who report abuse.
      if (!isOwnMessage) ...[
        if (canKick)
          _item(MessageContextAction.kick, LucideIcons.userMinus,
              l10n.actionKick),
        if (canBanUser)
          _item(MessageContextAction.ban, LucideIcons.ban, l10n.actionBan),
        _item(
          MessageContextAction.report,
          LucideIcons.flag,
          l10n.actionReport,
          color: cs.error,
        ),
      ],
    ];

    // -- Reference --------------------------------------------------------
    final reference = <PopupMenuEntry<MessageContextAction>>[
      _item(
          MessageContextAction.details, LucideIcons.info, l10n.messageDetails),
    ];

    // -- Failure recovery -------------------------------------------------
    // Its own group at the top rather than two rows wedged into the compose
    // group, because a message stuck in [EventStatus.error] has exactly two
    // things to do about it and leading with "Retry" above "React" makes a
    // dead message look like a live one.
    final recovery = <PopupMenuEntry<MessageContextAction>>[
      if (isFailed) ...[
        _item(MessageContextAction.retry, LucideIcons.rotateCw, l10n.retry,
            color: cs.tertiary),
        _item(MessageContextAction.cancelSend, LucideIcons.x, l10n.cancel),
      ],
    ];

    // -- Destructive ------------------------------------------------------
    // A redaction, not the failure path. It is deliberately mutually exclusive
    // with [recovery]: a stuck local echo's id is a transaction id the
    // homeserver has never seen, so a redact request against it cannot work,
    // and offering both offered the user one button that always fails.
    final destructive = <PopupMenuEntry<MessageContextAction>>[
      if (showDelete)
        _item(
            MessageContextAction.delete, LucideIcons.trash2, l10n.deleteMessage,
            color: cs.error),
    ];

    return _sections(<List<PopupMenuEntry<MessageContextAction>>>[
      recovery,
      everyday,
      copy,
      sender,
      reference,
      destructive,
    ]);
  }

  /// Joins non-empty groups with a single divider between them.
  ///
  /// Written as a join rather than as dividers sprinkled through the builders
  /// because the sprinkled version is what produced two dividers in a row: the
  /// sender group opened with an unconditional divider, so a message with
  /// nothing to show in that group left two rules with nothing between them.
  /// A group is either there or it is not, and this cannot disagree.
  static List<PopupMenuEntry<MessageContextAction>> _sections(
    List<List<PopupMenuEntry<MessageContextAction>>> groups,
  ) {
    final out = <PopupMenuEntry<MessageContextAction>>[];
    for (final group in groups) {
      if (group.isEmpty) continue;
      if (out.isNotEmpty) out.add(MoonrelayMenuDivider());
      out.addAll(group);
    }
    return out;
  }

  static PopupMenuEntry<MessageContextAction> _item(
    MessageContextAction value,
    IconData icon,
    String label, {
    Color? color,
  }) {
    return MoonrelayMenuItem<MessageContextAction>(
      value: value,
      icon: icon,
      label: label,
      color: color,
    );
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

  // --- Show menu -----------------------------------------------------------

  /// Shows the menu at [position] (in global coordinates).
  ///
  /// Returns once the user has chosen something and the resulting action has
  /// run. It therefore stays pending for as long as the menu is open, so do
  /// not `await` it from a gesture callback expecting it to settle.
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
    final entries = buildEntries(
      context: context,
      event: event,
      room: room,
      timeline: timeline,
      hasOnReply: true,
      hasOnForward: onForward != null,
      hasOnThread: onThread != null,
    );

    // Position at the tap point in overlay coordinates. `showMenu` takes a
    // rect relative to the root overlay and anchors the menu's top-left to it,
    // then clamps the menu to fit on screen, so a zero-size rect at the pointer
    // is the thing to pass. Anything larger and the menu centres itself on
    // the pointer's rect, which puts a click in the middle of a tall menu
    // several hundred pixels below the cursor.
    final overlay = Overlay.of(context, rootOverlay: true);
    final overlayBox = overlay.context.findRenderObject()! as RenderBox;
    final localPosition = overlayBox.globalToLocal(position);

    final selected = await showMenu<MessageContextAction>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(localPosition, localPosition),
        Offset.zero & overlayBox.size,
      ),
      items: entries,
      constraints: moonrelayMenuConstraints(),
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(
          MoonrelayThemeExtension.of(context).components.dialog.cornerRadius,
        ),
        side: BorderSide(
          color: Theme.of(context).colorScheme.outlineVariant.withValues(
                alpha:
                    MoonrelayThemeExtension.of(context).tokens.opacityDisabled,
              ),
        ),
      ),
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
      onEdit: onEdit,
    );
  }
}
