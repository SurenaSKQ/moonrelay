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

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/edit_history_dialog.dart';
import 'package:moonrelay/src/chat/edit_message_dialog.dart';
import 'package:moonrelay/src/chat/reactions_bar.dart';
import 'package:moonrelay/src/helpers/feedback.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/message_details_page.dart';
import 'package:provider/provider.dart';

/// Canonical implementations for every matrix action exposed by the chat
/// hoverbar, the right-click context menu, and the long-press menu.
///
/// Centralising the action logic here keeps the hoverbar and the context
/// menu perfectly in sync: every action appears identically (same snackbars,
/// same confirmation dialogs) regardless of how it was triggered.
class MessageActionRunner {
  const MessageActionRunner._();

  /// Opens the reaction emoji picker and sends the chosen reaction.
  static void react(BuildContext context, Event event, Room room) {
    showReactionPicker(
      context,
      onSelected: (emoji) {
        room.sendReaction(event.eventId, emoji);
      },
    );
  }

  /// Copies the message body to the clipboard.
  static void copy(BuildContext context, Event event) {
    final body = event.body;
    Clipboard.setData(ClipboardData(text: body));
    context.showMessage(
      AppLocalizations.of(context)!.messageCopiedToClipboard,
      duration: kFeedbackDuration,
    );
  }

  /// Copies the event ID to the clipboard. Useful for moderation / debug.
  static void copyEventId(BuildContext context, Event event) {
    Clipboard.setData(ClipboardData(text: event.eventId));
    context.showMessage(
      AppLocalizations.of(context)!.messageEventIdCopied,
      duration: kFeedbackDuration,
    );
  }

  /// Copies a `https://matrix.to/#/room/event` permalink to the clipboard.
  static void copyLink(BuildContext context, Event event, Room room) {
    final link = _permalinkFor(event, room);
    Clipboard.setData(ClipboardData(text: link));
    context.showMessage(
      AppLocalizations.of(context)!.messageLinkCopied,
      duration: kFeedbackDuration,
    );
  }

  /// Copies the raw event JSON to the clipboard: power-user / debug aid.
  static void copyRawJson(BuildContext context, Event event) {
    final text = const JsonEncoder.withIndent('  ').convert(event.content);
    Clipboard.setData(ClipboardData(text: text));
    context.showMessage(
      AppLocalizations.of(context)!.messageRawJsonCopied,
      duration: kFeedbackDuration,
    );
  }

  /// Opens the message details page.
  ///
  /// Defer the navigation by one frame so the route is pushed outside the
  /// current build / layout pass.  The message details page is a full
  /// `MaterialPageRoute` over an existing page, and the surrounding
  /// router page is built inside a `FadeTransition` from
  /// [genericPageBuilder].  Pushing the `MaterialPageRoute` mid-build
  /// makes the route's `OverlayPortal` insert its entry while the
  /// `FadeTransition` is still performing layout, which trips Flutter's
  /// "RenderObject was mutated in performLayout" assertion and the
  /// `_elements.contains(element)` assertion that follows.  A
  /// post-frame callback resolves the race without changing the visible
  /// behaviour; the user sees the new page on the next frame either
  /// way.
  static void showDetails(BuildContext context, Event event, Room room) {
    final navigator = Navigator.of(context);
    final route = MaterialPageRoute(
      builder: (_) => MessageDetailsPage(event: event, room: room),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!navigator.mounted) return;
      navigator.push(route);
    });
  }

  /// Opens the in-place editor for the message body and writes the edit
  /// (m.replace) when the user confirms.
  static Future<void> edit(
    BuildContext context,
    Event event,
    Room room, {
    Timeline? timeline,
  }) async {
    await showEditMessageDialog(context,
        event: event, room: room, timeline: timeline);
  }

  /// Shows the edit history dialog.
  static void showEditHistory(
    BuildContext context,
    Event event,
    Timeline? timeline,
    Room room,
  ) {
    if (timeline == null) return;
    showEditHistoryDialog(context, event: event, timeline: timeline, room: room);
  }

  /// Toggles the pin state of this event.
  static Future<void> togglePin(
    BuildContext context,
    Event event,
    Room room,
  ) async {
    final state = room.getState('m.room.pinned_events');
    final existing = state?.content['pinned'];
    final pinned = existing is List
        ? List<String>.from(existing.map((e) => e.toString()))
        : <String>[];
    final eventId = event.eventId;

    final wasPinned = pinned.contains(eventId);
    final List<String> updated = wasPinned
        ? pinned.where((id) => id != eventId).toList()
        : [...pinned, eventId];

    final l10n = AppLocalizations.of(context)!;
    await context.showActionResult(
      action: () => room.setPinnedEvents(updated),
      successMessage: wasPinned ? l10n.unpinMessage : l10n.pinMessage,
    );
  }

  /// Shows a confirmation dialog before redacting (or cancelling) the event.
  ///
  /// For events stuck in [EventStatus.error] whose `eventId` may still be a
  /// local transaction ID (UUID), a redact request would fail since the
  /// server doesn't know about that ID.  Instead we cancel the local echo.
  static Future<void> confirmDelete(
    BuildContext context,
    Event event,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    // The two branches differ only in what the user is asked and in what
    // actually happens, so they share one dialog and one confirm handler
    // rather than carrying a near-identical copy of each.
    final isStuckEcho = event.status.isError;
    final confirmed = await context.confirmDestructive(
      title: l10n.deleteMessage,
      // A stuck local echo is not on the server yet, so redaction would
      // fail on an eventId the homeserver has never seen. The wording has
      // to say we are cancelling, not deleting, or the user thinks the
      // wrong thing happened.
      message: isStuckEcho
          ? l10n.cancelFailedSendConfirm
          : l10n.areYouSureDeleteMessage,
      confirmLabel: l10n.delete,
    );
    if (!confirmed) return;
    if (!context.mounted) return;
    await _deleteAfterConfirm(context, event, isStuckEcho: isStuckEcho);
  }

  static Future<void> _deleteAfterConfirm(
    BuildContext context,
    Event event, {
    required bool isStuckEcho,
  }) async {
    if (isStuckEcho) {
      await cancelFailedSend(context, event);
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    await context.showActionResult(
      action: () => event.redactEvent(reason: 'Deleted by user'),
      // A successful redact redraws the timeline behind the snackbar, so
      // there is nothing to confirm.
      successMessage: null,
      formatError: (e) => l10n.failedToDelete('$e'),
    );
  }

  /// Kicks the sender of [event] from [room] after a confirmation dialog.
  static Future<void> kick(
    BuildContext context,
    Event event,
    Room room,
  ) async {
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final l10n = AppLocalizations.of(context)!;
    await _runModerationAction(
      context: context,
      logLabel: 'kick',
      title: l10n.actionKick,
      message: l10n.kickConfirm(senderName),
      confirmLabel: l10n.actionKick,
      successMessage: l10n.userKicked(senderName),
      action: () => room.kick(event.senderId),
    );
  }

  /// Bans the sender of [event] from [room] after a confirmation dialog.
  static Future<void> ban(
    BuildContext context,
    Event event,
    Room room,
  ) async {
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final l10n = AppLocalizations.of(context)!;
    await _runModerationAction(
      context: context,
      logLabel: 'ban',
      title: l10n.actionBan,
      message: l10n.banConfirm(senderName),
      confirmLabel: l10n.actionBan,
      successMessage: l10n.userBanned(senderName),
      action: () => room.ban(event.senderId),
    );
  }

  /// Asks for a reason and reports the sender of [event] to the user's
  /// homeserver.
  static Future<void> report(
    BuildContext context,
    Event event,
    Room room,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    // Captured before the dialog: a provider read after the await would
    // touch a context that may be gone.
    final log = context.read<Logger>();
    final reason = await _promptForReason(context, l10n);
    if (reason == null) return;
    if (!context.mounted) return;
    await context.showActionResult(
      action: () => room.client.reportUser(event.senderId, reason),
      successMessage: l10n.userReported,
      log: log,
      logLabel: 'report user',
    );
  }

  /// Retries sending a failed event by calling [Event.sendAgain].
  ///
  /// Shows a success/failure snackbar so the user gets feedback even when
  /// the retry is triggered from a context menu or hotkey (not just the
  /// inline delivery indicator).
  static Future<void> retrySend(
    BuildContext context,
    Event event,
    Room room,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await context.showActionResult(
      action: event.sendAgain,
      successMessage: l10n.sendRetried,
      duration: kFeedbackDuration,
      log: context.read<Logger>(),
      logLabel: 'retry send',
    );
  }

  /// Removes a failed (unsent) event from the local timeline.
  ///
  /// Uses [Event.cancelSend] which works only for events whose status is
  /// `sending` or `error`.  When the event was never delivered to the
  /// server this cleanly removes it without leaving a ghost in the
  /// timeline.
  static Future<void> cancelFailedSend(
    BuildContext context,
    Event event,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await context.showActionResult(
      action: event.cancelSend,
      successMessage: l10n.sendCancelled,
      duration: kFeedbackDuration,
      formatError: (e) => l10n.failedToDelete('$e'),
      log: context.read<Logger>(),
      logLabel: 'cancel send',
    );
  }

  /// The shared shape of every moderation action: confirm, act, report.
  ///
  /// Keeping kick and ban (and anything added later) on one code path is what
  /// makes them behave the same way: identical confirm button, identical
  /// success wording, identical error wording, and a log line naming the
  /// action that failed.
  static Future<void> _runModerationAction({
    required BuildContext context,
    required String logLabel,
    required String title,
    required String message,
    required String confirmLabel,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    // Captured before the dialog: a provider read after the await would
    // touch a context that may be gone.
    final log = context.read<Logger>();
    final confirmed = await context.confirmDestructive(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
    );
    if (!confirmed) return;
    if (!context.mounted) return;
    await context.showActionResult(
      action: action,
      successMessage: successMessage,
      log: log,
      logLabel: logLabel,
    );
  }

  /// Collects an optional free-text reason for a moderation action.
  ///
  /// Returns `null` when the user cancels, which is different from an empty
  /// string: an empty reason is still a valid report.
  static Future<String?> _promptForReason(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionReport),
        content: TextField(
          controller: controller,
          autofocus: true,
          minLines: 2,
          maxLines: 5,
          decoration: InputDecoration(hintText: l10n.reportReasonHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.actionReport),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  /// Whether the current user can moderate (kick) the sender of [event]
  /// in [room].  Returns `false` if the sender is the current user.
  static bool canModerate(Room room, Event event) {
    final client = room.client;
    if (event.senderId == client.userID) return false;
    try {
      return room
          .unsafeGetUserFromMemoryOrFallback(event.senderId)
            .canKick;
        } catch (_) {
          // `unsafeGetUserFromMemoryOrFallback` throws when the sender is
          // not in the local user cache yet. No cached user, no known
          // power level, so no kick.
          return false;
        }
  }

  /// Whether the current user can ban the sender of [event] in [room].
  /// Returns `false` if the sender is the current user.
  static bool canBan(Room room, Event event) {
    final client = room.client;
    if (event.senderId == client.userID) return false;
    try {
      return room
          .unsafeGetUserFromMemoryOrFallback(event.senderId)
            .canBan;
        } catch (_) {
          // Same probe as canKick: an uncached User throws, and an
          // uncached user cannot be banned.
          return false;
        }
  }

  /// Whether [event] is editable by the current user: text-shaped, sent
  /// by us, and not redacted.
  static bool canEditText(Event event, Room room) {
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
      // `canRedact` walks the power level chain, which the SDK throws from
      // when a user or room state event has not loaded yet. Answering
      // `true` here would put an Edit button in front of the user that
      // then fails when tapped, so fail closed and hide the action until
      // the state arrives.
      return false;
    }
  }

  /// Whether [eventId] is currently pinned in [room].
  static bool isPinned(Room room, String eventId) {
    final state = room.getState('m.room.pinned_events');
    if (state == null) return false;
    final pinned = state.content['pinned'];
    if (pinned is! List) return false;
    return pinned.contains(eventId);
  }

  /// Builds a `https://matrix.to/#/roomId/eventId` permalink for the event.
  static String _permalinkFor(Event event, Room room) {
    return 'https://matrix.to/#/${room.id}/${event.eventId}';
  }
}