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
import 'package:flutter/services.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/chat_event.dart';
import 'package:moonrelay/src/chat/message_action_runner.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Enum
// ─────────────────────────────────────────────────────────────────────────────

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

// ─────────────────────────────────────────────────────────────────────────────
//  Menu builder & dispatcher
// ─────────────────────────────────────────────────────────────────────────────

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

    final isFailed = event.status.isError;

    return <PopupMenuEntry<MessageContextAction>>[
      // ─── Failed-send group (only for events stuck in error state) ───
      if (isFailed) ...[
        _menuItem(
          value: MessageContextAction.retry,
          icon: Icons.refresh_rounded,
          label: l10n.retry,
          color: cs.tertiary,
        ),
        _menuItem(
          value: MessageContextAction.cancelSend,
          icon: Icons.close_rounded,
          label: l10n.cancel,
          color: cs.onSurfaceVariant,
        ),
        const PopupMenuDivider(),
      ],
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

  // ─── Build a single PopupMenuItem ───────────────────────────────────────

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

  // ─── Show menu overlay ─────────────────────────────────────────────────

  /// Shows the context menu anchored at [position] (in global coordinates).
  ///
  /// The menu is rendered as a custom overlay at the exact pointer position,
  /// combining a quick-actions icon row (React, Reply, Forward, Thread,
  /// Copy, Delete) at the top with the full menu list below.
  ///
  /// Pass `null` for [onReply] / [onForward] / [onThread] / [onOpenProfile]
  /// to hide those entries from the menu -- they are filtered out
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
    final overlayState = Overlay.of(context, rootOverlay: true);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final topSafe = mediaQuery.padding.top;
    final bottomSafe = mediaQuery.padding.bottom;

    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    final canDelete = event.canRedact;
    final isOwnMessage = event.senderId == room.client.userID;
    final canModerate = _canModerate(room, event);
    final canBanUser = _canBan(room, event);

    // Resolve the composable callbacks needed by quick-action icons so we
    // can store them in the overlay entry without depending on the
    // original context staying mounted.
    final resolvedOnReply = onReply;
    final resolvedOnForward = onForward;
    final resolvedOnThread = onThread;
    final resolvedOnOpenProfile = onOpenProfile;

    // Build menu entries once so they are computed outside the overlay
    // builder where the original context is still valid.
    final entries = buildEntries(
      context: context,
      event: event,
      room: room,
      timeline: timeline,
      hasOnReply: true,
      hasOnForward: onForward != null,
      hasOnThread: onThread != null,
    );

    late OverlayEntry overlayEntry;
    late _ContextMenuState menuState;

    // Wrap the dismiss action so both the overlay and the popup can
    // coordinate cleanup without leaking entries.
    void dismiss() {
      menuState.didDismiss = true;
      overlayEntry.remove();
    }

    overlayEntry = OverlayEntry(
      builder: (ctx) {
        return _ContextMenuPopup(
          position: position,
          screenSize: screenSize,
          topSafe: topSafe,
          bottomSafe: bottomSafe,
          colorScheme: cs,
          l10n: l10n,
          onDismiss: dismiss,
          onStateCreated: (state) => menuState = state,
          quickActions: _buildQuickActions(
            context: context,
            event: event,
            room: room,
            timeline: timeline,
            canDelete: canDelete,
            isOwnMessage: isOwnMessage,
            canModerate: canModerate,
            canBanUser: canBanUser,
            resolvedOnReply: resolvedOnReply,
            resolvedOnForward: resolvedOnForward,
            resolvedOnThread: resolvedOnThread,
            resolvedOnOpenProfile: resolvedOnOpenProfile,
          ),
          entries: entries,
          handleSelection: (MessageContextAction action) async {
            await handleSelection(
              context: context,
              action: action,
              event: event,
              room: room,
              timeline: timeline,
              onReply: resolvedOnReply,
              onForward: resolvedOnForward,
              onThread: resolvedOnThread,
              onOpenProfile: resolvedOnOpenProfile,
            );
          },
        );
      },
    );

    overlayState.insert(overlayEntry);
  }

  /// Builds the quick-actions icon row shown at the top of the menu.
  static Widget _buildQuickActions({
    required BuildContext context,
    required Event event,
    required Room room,
    required Timeline? timeline,
    required bool canDelete,
    required bool isOwnMessage,
    required bool canModerate,
    required bool canBanUser,
    required VoidCallback resolvedOnReply,
    required VoidCallback? resolvedOnForward,
    required VoidCallback? resolvedOnThread,
    required VoidCallback? resolvedOnOpenProfile,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;
    final isFailed = event.status.isError;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isFailed) ...[
            _quickIcon(
              icon: Icons.refresh_rounded,
              tooltip: l10n.retry,
              color: cs.tertiary,
              onTap: () => MessageActionRunner.retrySend(context, event, room),
            ),
            _quickIcon(
              icon: Icons.close_rounded,
              tooltip: l10n.cancel,
              color: cs.onSurfaceVariant,
              onTap: () => MessageActionRunner.cancelFailedSend(context, event),
            ),
            const SizedBox(width: 4),
          ],
          _quickIcon(
            icon: Icons.add_reaction_rounded,
            tooltip: l10n.reactTooltip,
            color: cs.onSurfaceVariant,
            onTap: () => MessageActionRunner.react(context, event, room),
          ),
          _quickIcon(
            icon: Icons.reply_rounded,
            tooltip: l10n.replyTooltip,
            color: cs.onSurfaceVariant,
            onTap: resolvedOnReply,
          ),
          if (resolvedOnForward != null)
            _quickIcon(
              icon: Icons.shortcut_rounded,
              tooltip: l10n.forwardTooltip,
              color: cs.onSurfaceVariant,
              onTap: resolvedOnForward,
            ),
          if (resolvedOnThread != null)
            _quickIcon(
              icon: Icons.forum_rounded,
              tooltip: l10n.openThread,
              color: cs.onSurfaceVariant,
              onTap: resolvedOnThread,
            ),
          _quickIcon(
            icon: Icons.copy_rounded,
            tooltip: l10n.copyTooltip,
            color: cs.onSurfaceVariant,
            onTap: () => MessageActionRunner.copy(context, event),
          ),
          if (canDelete)
            _quickIcon(
              icon: Icons.delete_outline_rounded,
              tooltip: l10n.deleteTooltip,
              color: cs.error,
              onTap: () => MessageActionRunner.confirmDelete(context, event),
            ),
        ],
      ),
    );
  }

  /// A single small icon button in the quick-actions row.
  static Widget _quickIcon({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Semantics(
      label: tooltip,
      button: true,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          hoverColor: color.withValues(alpha: 0.08),
          splashColor: color.withValues(alpha: 0.12),
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Icon(icon, size: 18, color: color),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Overlay popup
// ─────────────────────────────────────────────────────────────────────────────

/// The actual popup widget rendered inside the overlay.
///
/// Positioned at [position] (global), clamped to avoid overflowing the
/// screen edges.  Shows a quick-actions row at the top followed by a
/// scrollable list of menu items.
class _ContextMenuPopup extends StatefulWidget {
  const _ContextMenuPopup({
    required this.position,
    required this.screenSize,
    required this.topSafe,
    required this.bottomSafe,
    required this.colorScheme,
    required this.l10n,
    required this.onDismiss,
    required this.onStateCreated,
    required this.quickActions,
    required this.entries,
    required this.handleSelection,
  });

  final Offset position;
  final Size screenSize;
  final double topSafe;
  final double bottomSafe;
  final ColorScheme colorScheme;
  final AppLocalizations l10n;
  final VoidCallback onDismiss;
  final void Function(_ContextMenuState) onStateCreated;
  final Widget quickActions;
  final List<PopupMenuEntry<MessageContextAction>> entries;
  final void Function(MessageContextAction action) handleSelection;

  @override
  State<_ContextMenuPopup> createState() => _ContextMenuState();
}

class _ContextMenuState extends State<_ContextMenuPopup>
    with TickerProviderStateMixin {
  /// Set to true when the overlay entry has been removed so we can skip
  /// calling setState during the fade-out animation when the entry is
  /// already gone.
  bool didDismiss = false;

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;
  late final AnimationController _scaleController;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    widget.onStateCreated(this);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _scaleAnim = CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -8),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    // Start the entrance animation immediately — no measurement pass
    // needed since we clamp using the estimated menu size.
    _fadeController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _scaleController.dispose();
    super.dispose();
  }

  /// Estimates the total menu height (quick-actions row + entries list)
  /// to clamp the position without needing a real layout pass.
  double _estimateHeight() {
    double h = 0;
    // Quick-actions row: icon row + padding
    h += 48;
    // Divider after quick actions
    h += 1;
    // Each entry
    for (final e in widget.entries) {
      h += e is PopupMenuDivider ? 16.0 : 48.0;
    }
    return h.clamp(0.0, 440.0);
  }

  /// Clamps the cursor position so the menu stays on screen, using an
  /// estimated menu size.
  Offset _clampedPosition() {
    const double margin = 8.0;
    final menuH = _estimateHeight();
    const double menuW = 280; // maxWidth from _MenuCard constraints
    final sw = widget.screenSize.width;
    final sh = widget.screenSize.height;
    final topSafe = widget.topSafe;
    final bottomSafe = widget.bottomSafe;

    double left = widget.position.dx.clamp(margin, sw - menuW - margin);
    double top = widget.position.dy.clamp(
      topSafe + margin,
      sh - bottomSafe - menuH - margin,
    );

    // If the menu would overflow the bottom, flip it above the cursor
    if (top + menuH > sh - bottomSafe - margin) {
      top = (widget.position.dy - menuH - margin)
          .clamp(topSafe + margin, sh - bottomSafe - menuH - margin);
    }

    return Offset(left, top);
  }

  void _handleAction(MessageContextAction action) {
    widget.handleSelection(action);
    if (mounted && !didDismiss) {
      didDismiss = true;
      widget.onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    // An exit animation is not needed because the menu disappears with
    // the overlay entry removal; the entrance animation provides enough
    // polish.

    return Stack(
      children: [
        // Scrim — tap outside to dismiss
        GestureDetector(
          onTap: widget.onDismiss,
          behavior: HitTestBehavior.translucent,
          child: Container(color: Colors.transparent),
        ),
        // Menu positioned at cursor + keyboard dismiss handler
        Positioned(
          left: _clampedPosition().dx,
          top: _clampedPosition().dy,
          child: CallbackShortcuts(
            bindings: <ShortcutActivator, VoidCallback>{
              const SingleActivator(LogicalKeyboardKey.escape):
                  widget.onDismiss,
            },
            child: Focus(
              autofocus: true,
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.escape) {
                  widget.onDismiss();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: _MenuCard(
                      colorScheme: widget.colorScheme,
                      quickActions: widget.quickActions,
                      entries: widget.entries,
                      onSelected: _handleAction,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The visual card containing the quick-actions row and the scrollable
/// menu list.
class _MenuCard extends StatelessWidget {
  const _MenuCard({
    required this.colorScheme,
    required this.quickActions,
    required this.entries,
    required this.onSelected,
  });

  final ColorScheme colorScheme;
  final Widget quickActions;
  final List<PopupMenuEntry<MessageContextAction>> entries;
  final void Function(MessageContextAction action) onSelected;

  @override
  Widget build(BuildContext context) {
    final listHeight = entries
        .map((e) => e is PopupMenuDivider ? 16.0 : 48.0)
        .fold(0.0, (a, b) => a + b);
    // Clamp the list so very large menus don't overflow the screen.
    final clampedListHeight = listHeight.clamp(0.0, 400.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(
          minWidth: 160,
          maxWidth: 280,
          maxHeight: clampedListHeight + 56, // + quick-actions row
        ),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─── Quick actions row ────────────────────────────────────
            quickActions,
            const Divider(height: 1, thickness: 1),
            // ─── Scrollable menu list ─────────────────────────────────
            Flexible(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(12),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      if (entry is PopupMenuDivider) {
                        return entry;
                      }
                      if (entry is PopupMenuItem<MessageContextAction>) {
                        return InkWell(
                          hoverColor: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.08),
                          splashColor: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.12),
                          onTap: () => onSelected(entry.value!),
                          child: entry,
                        );
                      }
                      return entry;
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
