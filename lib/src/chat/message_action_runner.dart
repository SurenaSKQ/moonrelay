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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/message_details_page.dart';
import 'package:provider/provider.dart';

/// Canonical implementations for every matrix action exposed by the chat
/// hoverbar, the right-click context menu, and the long-press menu.
///
/// Centralising the action logic here keeps the hoverbar and the context
/// menu perfectly in sync  every action appears identically (same snackbars,
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
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.messageCopiedToClipboard),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Copies the event ID to the clipboard. Useful for moderation / debug.
  static void copyEventId(BuildContext context, Event event) {
    Clipboard.setData(ClipboardData(text: event.eventId));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.messageEventIdCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Copies a `https://matrix.to/#/room/event` permalink to the clipboard.
  static void copyLink(BuildContext context, Event event, Room room) {
    final link = _permalinkFor(event, room);
    Clipboard.setData(ClipboardData(text: link));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.messageLinkCopied),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Copies the raw event JSON to the clipboard  power-user / debug aid.
  static void copyRawJson(BuildContext context, Event event) {
    final text = const JsonEncoder.withIndent('  ').convert(event.content);
    Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.messageRawJsonCopied),
        duration: const Duration(seconds: 2),
      ),
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
  /// behaviour  the user sees the new page on the next frame either
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

    try {
      await room.setPinnedEvents(updated);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasPinned
                ? AppLocalizations.of(context)!.unpinMessage
                : AppLocalizations.of(context)!.pinMessage,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.actionFailed('$e'))),
      );
    }
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

    if (event.status.isError) {
      // Stuck local echo — remove it from the timeline instead of
      // attempting to redact a server event that may not exist or
      // whose eventId we don't know.
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.deleteMessage),
          content: Text(l10n.cancelFailedSendConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(
                l10n.delete,
                style: TextStyle(color: Theme.of(ctx).colorScheme.error),
              ),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      try {
        await event.cancelSend();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.sendCancelled),
            duration: const Duration(seconds: 2),
          ),
        );
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedToDelete('$e'))),
        );
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.deleteMessage),
        content: Text(l10n.areYouSureDeleteMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l10n.delete,
              style: TextStyle(color: Theme.of(ctx).colorScheme.error),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await event.redactEvent(reason: 'Deleted by user');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedToDelete('$e'))),
      );
    }
  }

  /// Kicks the sender of [event] from [room] after a confirmation dialog.
  static Future<void> kick(
    BuildContext context,
    Event event,
    Room room,
  ) async {
    final log = context.read<Logger>();
    final l10n = AppLocalizations.of(context)!;
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionKick),
        content: Text(l10n.kickConfirm(senderName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionKick),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await room.kick(event.senderId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userKicked(senderName))),
      );
    } catch (e) {
      log.w('Failed to kick', error: e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  /// Bans the sender of [event] from [room] after a confirmation dialog.
  static Future<void> ban(
    BuildContext context,
    Event event,
    Room room,
  ) async {
    final log = context.read<Logger>();
    final l10n = AppLocalizations.of(context)!;
    final senderName = event.senderFromMemoryOrFallback.calcDisplayname();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.actionBan),
        content: Text(l10n.banConfirm(senderName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l10n.actionBan),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await room.ban(event.senderId);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userBanned(senderName))),
      );
    } catch (e) {
      log.w('Failed to ban', error: e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  /// Asks for a reason and reports the sender of [event] to the user's
  /// homeserver.
  static Future<void> report(
    BuildContext context,
    Event event,
    Room room,
  ) async {
    final log = context.read<Logger>();
    final l10n = AppLocalizations.of(context)!;
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
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
              onPressed: () =>
                  Navigator.of(ctx).pop(controller.text.trim()),
              child: Text(l10n.actionReport),
            ),
          ],
        );
      },
    );
    if (reason == null) return;
    try {
      await room.client.reportUser(event.senderId, reason);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.userReported)),
      );
    } catch (e) {
      log.w('Failed to report user', error: e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
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
    final log = context.read<Logger>();
    try {
      await event.sendAgain();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sendRetried),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      log.w('Failed to retry send', error: e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
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
    final log = context.read<Logger>();
    try {
      await event.cancelSend();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.sendCancelled),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      log.w('Failed to cancel send', error: e);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  /// Builds a `https://matrix.to/#/roomId/eventId` permalink for the event.
  static String _permalinkFor(Event event, Room room) {
    return 'https://matrix.to/#/${room.id}/${event.eventId}';
  }
}