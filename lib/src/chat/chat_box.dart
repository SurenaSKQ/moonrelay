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
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/chat_box_sticker_picker.dart';
import 'package:moonrelay/src/chat/poll_send_dialog.dart';
import 'package:moonrelay/src/chat/share_location_dialog.dart';
import 'package:moonrelay/src/chat/typing_indicator.dart';
import 'package:moonrelay/src/chat/voice_recorder_dialog.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/markdown_to_html.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/services/draft_service.dart';
import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:provider/provider.dart';

/// A modern chat composition widget with formatting tools,
/// attachment support, and a compact/expanded mode toggle.
///
/// **Compact mode** – single-line text field with an attach button,
/// an expand toggle, and a send button.
///
/// **Expanded mode** – multi-line editor with a full formatting toolbar
/// (bold, italic, strikethrough, inline code, blockquote, heading,
/// unordered list, link), an attach button, and a send button.
class ChatBox extends StatefulWidget {
  const ChatBox({
    super.key,
    required this.room,
    this.replyTarget,
    this.threadRootEventId,
  });

  final Room room;

  /// A notifier that signals which event (if any) the user is currently
  /// replying to.  Set to `null` to clear the reply preview.
  final ValueNotifier<Event?>? replyTarget;

  /// When non-null, messages are sent as replies in this thread.
  final String? threadRootEventId;

  @override
  State<ChatBox> createState() => _ChatBoxState();
}

class _ChatBoxState extends State<ChatBox> with SingleTickerProviderStateMixin {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;
  late final AnimationController _expandController;
  late final Animation<double> _expandAnimation;

  bool _isExpanded = false;
  bool _isEmpty = true;
  Event? _replyEvent;
  bool _disposed = false;
  late final TypingNotifier _typingNotifier = TypingNotifier(widget.room);

  /// The composer text captured immediately before [_send] cleared the
  /// controller.  Stored so we can restore it if `sendFn` throws  the
  /// user can correct and resend without retyping a long message.
  String? _draftValue;

  /// Per-room draft persistence.  Initialized when a room is available
  /// and [draftsEnabled] is true.
  DraftService? _draftService;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode(onKeyEvent: _handleKeyEvent);
    _expandController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _expandAnimation = CurvedAnimation(
      parent: _expandController,
      curve: Curves.easeInOut,
    );
    _controller.addListener(_onTextChanged);
    widget.replyTarget?.addListener(_onReplyTargetChanged);
    // Load persisted draft after init so the listener is ready.
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadDraft());
  }

  /// Loads the persisted draft for the current room, if drafts are enabled.
  Future<void> _loadDraft() async {
    if (!context.mounted) return;
    final settings = context.read<SettingsController>();
    if (!settings.draftsEnabled) return;
    final client = context.read<Client>();
    final userId = client.userID;
    if (userId == null) return;
    // Shared per-account DraftService so multiple ChatBox instances
    // share the same debounce timer.  [release] is called in
    // [dispose] to balance the reference count.
    final drafts = DraftService.instanceFor(userId);
    _draftService = drafts;
    final draft = await drafts.load(widget.room.id);
    if (!mounted || draft.isEmpty) return;
    _controller.text = draft.body;
  }

  @override
  void didUpdateWidget(ChatBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.replyTarget != widget.replyTarget) {
      oldWidget.replyTarget?.removeListener(_onReplyTargetChanged);
      widget.replyTarget?.addListener(_onReplyTargetChanged);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    widget.replyTarget?.removeListener(_onReplyTargetChanged);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _expandController.dispose();
    _typingNotifier.dispose();
    // Balance the ref count we took in [_loadDraft]; the underlying
    // service may be torn down (timer cancelled) once we're the last
    // ChatBox for this account.
    _draftService?.release();
    super.dispose();
  }

  void _onReplyTargetChanged() {
    if (!mounted) return;
    setState(() => _replyEvent = widget.replyTarget?.value);
    if (widget.replyTarget?.value != null) {
      _focusNode.requestFocus();
    }
  }

  void _onTextChanged() {
    final empty = _controller.text.trim().isEmpty;
    if (empty != _isEmpty) {
      setState(() => _isEmpty = empty);
    }
    // Typing indicators: fire only when transitioning to non-empty,
    // and rely on the TypingNotifier to throttle & auto-stop.
    if (!empty) {
      // Honour the user-level "send typing notifications" toggle.
      final settings = context.read<SettingsController>();
      if (settings.sendTypingNotifications) {
        _typingNotifier.notify();
      }
    }
    // Debounced draft save, if drafts are enabled.
    _draftService?.scheduleSave(
      widget.room.id,
      _controller.text,
      replyToEventId: _replyEvent?.eventId,
    );
  }

  /// Whether plain Enter should send the message (vs. only Cmd+Enter).
  bool _shouldEnterSend() {
    if (!context.mounted) return !_isExpanded;
    final shortcut = context.read<SettingsController>().sendShortcut;
    switch (shortcut) {
      case SendShortcut.enter:
      case SendShortcut.both:
        return true;
      case SendShortcut.cmdEnter:
        return false;
    }
  }

  /// Handles raw key events on the composer's [FocusNode] so we can
  /// intercept Enter / Cmd+Enter regardless of [TextInputAction].
  ///
  /// Plain Enter dispatches [_send] or inserts a newline depending on
  /// the user's [SendShortcut] preference.  Cmd/Ctrl+Enter always sends.
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final isMeta = HardwareKeyboard.instance.isMetaPressed ||
        HardwareKeyboard.instance.isControlPressed;

    if (event.logicalKey != LogicalKeyboardKey.enter &&
        event.logicalKey != LogicalKeyboardKey.numpadEnter) {
      return KeyEventResult.ignored;
    }

    if (isMeta) {
      _send();
      return KeyEventResult.handled;
    }

    if (_shouldEnterSend() && !HardwareKeyboard.instance.isShiftPressed) {
      _send();
      return KeyEventResult.handled;
    }

    // Let Shift+Enter / plain Enter when not in send-mode insert a newline.
    return KeyEventResult.ignored;
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final log = context.read<Logger>();
    final replyTo = _replyEvent;
    // Parse the Markdown on a background isolate so the UI thread
    // stays responsive even when the user pastes a long message with
    // many code fences / list items.
    final html = await MarkdownToHtml.convertAsync(text);
    final hasHtml = html.isNotEmpty && html != text;

    // ── Slash commands ──────────────────────────────────────────────────
    // The chat composer accepts a tiny set of builtin commands:
    //   /me <text>       sends as m.emote (third-person action).
    //   /shrug <text>    prepends the ¯\_(ツ)_/¯ shrug glyph and sends
    //                     as plain text.
    String effectiveBody = text;
    String? emoteMsgtype;

    if (text.startsWith('/')) {
      final firstSpace = text.indexOf(' ');
      final cmd = firstSpace < 0 ? text : text.substring(0, firstSpace);
      final arg = firstSpace < 0 ? '' : text.substring(firstSpace + 1).trim();
      switch (cmd.toLowerCase()) {
        case '/me':
          if (arg.isEmpty) {
            return; // nothing to send
          }
          emoteMsgtype = MessageTypes.Emote;
          effectiveBody = arg;
          break;
        case '/shrug':
          if (arg.isEmpty) {
            return; // nothing to send
          }
          effectiveBody = '¯\\_(ツ)_/¯ $arg';
          break;
        default:
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                AppLocalizations.of(context)!.unsupportedSlashCommand(cmd),
              ),
              duration: const Duration(seconds: 2),
            ),
          );
          return;
      }
    }

    // Build the relation payload once so that the reply, threaded-reply,
    // and plain-text branches all use the same content (and the same
    // formatted_body when the user typed markdown).
    final Map<String, dynamic> content = <String, dynamic>{
      'msgtype': emoteMsgtype ?? MessageTypes.Text,
      'body': effectiveBody,
      if (hasHtml && emoteMsgtype == null) ...<String, dynamic>{
        'format': 'org.matrix.custom.html',
        'formatted_body': html,
      },
    };
    if (replyTo != null) {
      content['m.relates_to'] = <String, dynamic>{
        'm.in_reply_to': <String, dynamic>{'event_id': replyTo.eventId},
      };
    }
    if (widget.threadRootEventId != null) {
      // Threading lives in the same relates_to block.  We add the
      // thread root on top of the in-reply-to for the threaded case
      // (replies inside a thread).  For top-level messages the
      // Matrix SDK already defaults to thread-less sending.
      final relates = (content['m.relates_to'] as Map<String, dynamic>?) ??
          <String, dynamic>{};
      relates['m.thread'] = <String, dynamic>{
        'event_id': widget.threadRootEventId,
      };
      if (!relates.containsKey('rel_type')) {
        relates['rel_type'] = 'm.thread';
      }
      content['m.relates_to'] = relates;
    }

    Future<void> sendFn() async {
      if (widget.threadRootEventId != null || replyTo != null) {
        await widget.room.sendEvent(
          content,
          threadRootEventId: widget.threadRootEventId,
        );
      } else {
        await widget.room.sendEvent(content);
      }
    }

    try {
      // Clear the input immediately for responsive UX.  If sending
      // fails the draft is restored into the controller so the user
      // can correct the message instead of having to retype it.
      if (!mounted) return;
      _draftValue = effectiveBody;
      _controller.clear();

      await withTimeout(sendFn, timeout: kDefaultTimeout);
      // Success  clear the draft.
      _draftValue = null;
      _draftService?.cancelPending();
      unawaited(_draftService?.clear(widget.room.id));
      _clearReply();
    } catch (e) {
      log.w('Failed to send message', error: e);
      if (!mounted) return;
      final restored = _draftValue;
      _draftValue = null;
      if (restored != null && _controller.text.isEmpty) {
        _controller.text = restored;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppLocalizations.of(context)!.error}: '
            '${e is TimeoutException ? '${AppLocalizations.of(context)!.sendFailed} ${AppLocalizations.of(context)!.sendTimedOut}' : '${AppLocalizations.of(context)!.sendFailed} $e'}',
          ),
        ),
      );
    }
  }

  void _clearReply() {
    widget.replyTarget?.value = null;
    setState(() => _replyEvent = null);
  }

  Future<void> _attachFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
    );
    if (_disposed) return;
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      // Read bytes on demand via the new PlatformFile API; the older
      // `file.bytes` and `withData: true` parameters are deprecated in
      // file_picker 12.
      try {
        final fileBytes = await file.readAsBytes();
        await withTimeout(
          () => widget.room.sendFileEvent(
            MatrixFile(bytes: fileBytes, name: file.name),
          ),
          timeout: kUploadTimeout,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)!.error}: '
                '${e is TimeoutException ? AppLocalizations.of(context)!.uploadTimedOut : '$e'}',
              ),
            ),
          );
        }
      }
    }
  }

  void _toggleExpand() {
    setState(() => _isExpanded = !_isExpanded);
    if (_isExpanded) {
      _expandController.forward();
      _focusNode.requestFocus();
    } else {
      _expandController.reverse();
      _focusNode.unfocus();
    }
  }

  // ---------------------------------------------------------------------------
  // Text selection helpers
  // ---------------------------------------------------------------------------

  /// Wraps the current selection with [before] and [after] markers.
  ///
  /// If no text is selected, the markers are inserted at the cursor and the
  /// cursor is placed between them.
  void _wrapSelection(String before, String after) {
    final text = _controller.text;
    final sel = _controller.selection;
    final start = sel.start;
    final end = sel.end;

    if (start == end) {
      final newText = '${text.substring(0, start)}$before$after'
          '${text.substring(start)}';
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(offset: start + before.length),
      );
    } else {
      final selected = text.substring(start, end);
      final newText = '${text.substring(0, start)}$before$selected$after'
          '${text.substring(end)}';
      _controller.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: start + before.length + selected.length + after.length,
        ),
      );
    }

    _focusNode.requestFocus();
  }

  /// Inserts [prefix] at the start of the current line.
  void _insertLinePrefix(String prefix) {
    final text = _controller.text;
    final cursor = _controller.selection.start;

    int lineStart = cursor;
    while (lineStart > 0 && text[lineStart - 1] != '\n') {
      lineStart--;
    }

    final newText = '${text.substring(0, lineStart)}$prefix'
        '${text.substring(lineStart)}';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: cursor + prefix.length),
    );
    _focusNode.requestFocus();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Expanded toolbar (shown when expanded)
          SizeTransition(
            sizeFactor: _expandAnimation,
            alignment: Alignment.topCenter,
            child: _buildFormattingToolbar(colorScheme),
          ),

          // Reply preview banner
          if (_replyEvent != null) _buildReplyPreview(colorScheme, l10n),

          // Main input row
          Padding(
            padding: EdgeInsets.only(
              left: 8,
              right: 6,
              top: _isExpanded ? 6 : 10,
              bottom: _isExpanded ? 6 : 10,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach button
                _IconButton(
                  icon: LucideIcons.paperclip,
                  tooltip: l10n.chatBoxAttach,
                  onPressed: _attachFile,
                  colorScheme: colorScheme,
                ),

                const SizedBox(width: 2),

                // Sticker button
                _IconButton(
                  icon: Icons.emoji_emotions_outlined,
                  tooltip: l10n.chatBoxSticker,
                  onPressed: () => showStickerPicker(context, widget.room),
                  colorScheme: colorScheme,
                ),

                const SizedBox(width: 2),

                // Voice note recorder
                _IconButton(
                  icon: LucideIcons.mic,
                  tooltip: l10n.recordVoiceNote,
                  onPressed: () =>
                      showVoiceRecorderDialog(context, widget.room),
                  colorScheme: colorScheme,
                ),

                // Location share
                _IconButton(
                  icon: LucideIcons.mapPin,
                  tooltip: l10n.shareLocation,
                  onPressed: () =>
                      showShareLocationDialog(context, widget.room),
                  colorScheme: colorScheme,
                ),

                // Poll creation
                _IconButton(
                  icon: LucideIcons.listChecks,
                  tooltip: l10n.createPoll,
                  onPressed: () => showPollCreateDialog(context, widget.room),
                  colorScheme: colorScheme,
                ),

                const SizedBox(width: 2),

                // Text field
                Expanded(
                  child: Container(
                      constraints: BoxConstraints(
                        maxHeight: _isExpanded ? 200 : 48,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest
                            .withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color:
                              colorScheme.outlineVariant.withValues(alpha: 0.6),
                        ),
                      ),
                      child: TextField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: _isExpanded ? null : 1,
                        minLines: _isExpanded ? 3 : 1,
                        textInputAction: _shouldEnterSend()
                            ? TextInputAction.send
                            : TextInputAction.newline,
                        onSubmitted: _shouldEnterSend() ? (_) => _send() : null,
                        style: TextStyle(
                          fontSize: 15,
                          color: colorScheme.onSurface,
                        ),
                        decoration: InputDecoration(
                          hintText: l10n.chatBoxSendMessage,
                          hintStyle: TextStyle(
                            fontSize: 15,
                            color: colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          isDense: true,
                        ),
                    ),
                  ),
                ),

                const SizedBox(width: 2),

                // Expand / Collapse button
                _IconButton(
                  icon: _isExpanded
                      ? LucideIcons.chevronDown
                      : LucideIcons.chevronUp,
                  tooltip:
                      _isExpanded ? l10n.chatBoxCollapse : l10n.chatBoxExpand,
                  onPressed: _toggleExpand,
                  colorScheme: colorScheme,
                ),

                // Send button
                _IconButton(
                  icon: LucideIcons.send,
                  tooltip: l10n.chatBoxSend,
                  onPressed: _isEmpty ? null : _send,
                  colorScheme: colorScheme,
                  isPrimary: true,
                  enabled: !_isEmpty,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Reply preview banner
  // ---------------------------------------------------------------------------

  /// Builds a banner showing which message the user is replying to, with a
  /// dismiss button to cancel the reply.
  Widget _buildReplyPreview(ColorScheme colorScheme, AppLocalizations? l10n) {
    final replyTo = _replyEvent;
    if (replyTo == null) return const SizedBox.shrink();

    final senderName = replyTo.senderFromMemoryOrFallback.calcDisplayname();
    final preview = replyTo.body.length > 80
        ? '${replyTo.body.substring(0, 80)}…'
        : replyTo.body;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 8, 2),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 32,
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Icon(
            Icons.reply_rounded,
            size: 16,
            color: colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n!.chatBoxReplyingTo(senderName),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.primary,
                  ),
                ),
                Text(
                  preview,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 4),
          // [Semantics] instead of [Tooltip]: the cancel-reply button
          // is part of the always-mounted chat surface. A Tooltip
          // would mount an internal [OverlayPortal] (via
          // [RawTooltip]) that activates the moment the page mounts;
          // the page is wrapped in a [FadeTransition] from
          // [genericPageBuilder] which lives inside the dashboard's
          // [LayoutBuilder] shell, so the portal activation marks a
          // sibling [_RenderLayoutBuilder] as needing layout mid-
          // performLayout and trips the
          // `_RenderLayoutBuilder was mutated in performLayout`
          // assertion (the chat-page layout race). A Semantics label
          // gives screen readers the same affordance without ever
          // materialising an overlay entry.
          Semantics(
            label: l10n.chatBoxCancelReply,
            button: true,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: _clearReply,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Formatting toolbar
  // ---------------------------------------------------------------------------

  Widget _buildFormattingToolbar(ColorScheme colorScheme) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          _formatButton(
            icon: LucideIcons.bold,
            tooltip: l10n.formatBold,
            onTap: () => _wrapSelection('**', '**'),
          ),
          _formatButton(
            icon: LucideIcons.italic,
            tooltip: l10n.formatItalic,
            onTap: () => _wrapSelection('*', '*'),
          ),
          _formatButton(
            icon: LucideIcons.strikethrough,
            tooltip: l10n.formatStrikethrough,
            onTap: () => _wrapSelection('~~', '~~'),
          ),
          _formatDivider(),
          _formatButton(
            icon: LucideIcons.code,
            tooltip: l10n.formatInlineCode,
            onTap: () => _wrapSelection('`', '`'),
          ),
          _formatButton(
            icon: LucideIcons.code2,
            tooltip: l10n.formatCodeBlock,
            onTap: () => _wrapSelection('```\n', '\n```'),
          ),
          _formatDivider(),
          _formatButton(
            icon: LucideIcons.textQuote,
            tooltip: l10n.formatBlockquote,
            onTap: () => _insertLinePrefix('> '),
          ),
          _formatButton(
            icon: LucideIcons.heading1,
            tooltip: l10n.formatHeading,
            onTap: () => _insertLinePrefix('# '),
          ),
          _formatButton(
            icon: LucideIcons.list,
            tooltip: l10n.formatUnorderedList,
            onTap: () => _insertLinePrefix('- '),
          ),
          _formatButton(
            icon: LucideIcons.listOrdered,
            tooltip: l10n.formatOrderedList,
            onTap: () => _insertLinePrefix('1. '),
          ),
          _formatDivider(),
          _formatButton(
            icon: LucideIcons.link,
            tooltip: l10n.formatLink,
            onTap: () => _wrapSelection('[', '](url)'),
          ),
        ],
      ),
    );
  }

  Widget _formatDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
      child: Container(
        width: 1,
        color:
            Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
  }

  Widget _formatButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final cs = Theme.of(context).colorScheme;
    // [Semantics] instead of [Tooltip] for the same reason as the
    // rest of the chat-box chrome: this widget lives inside a
    // [SizeTransition] inside the always-mounted chat surface, and
    // Tooltip's internal [OverlayPortal] would activate on mount
    // while the dashboard's [LayoutBuilder] ancestor is mid-
    // performLayout, tripping the
    // `_RenderLayoutBuilder was mutated in performLayout` assertion.
    // Semantics carries the same accessibility label without ever
    // materialising an overlay entry.
    return SizedBox(
      width: 32,
      height: 32,
      child: Semantics(
        label: tooltip,
        button: true,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(6),
            onTap: onTap,
            child: Icon(
              icon,
              size: 18,
              color: cs.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable icon button used in the chat box
// ---------------------------------------------------------------------------

/// A small, clean icon button for the chat box toolbar.
class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    required this.colorScheme,
    this.isPrimary = false,
    this.enabled = true,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onPressed;
  final ColorScheme colorScheme;
  final bool isPrimary;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final canTap = enabled && onPressed != null;
    // We intentionally wrap in [Semantics] rather than [Tooltip] here.
    // [Tooltip] mounts an internal [OverlayPortal] (via [RawTooltip])
    // that activates the moment the page mounts.  When the page is
    // pushed through a custom page transition (the dashboard's
    // [LayoutBuilder] shell) the overlay portal's activation marks a
    // sibling [_RenderLayoutBuilder] as needing layout mid-performLayout,
    // which trips the
    // `_RenderLayoutBuilder was mutated in performLayout` assertion
    // and the associated `traversalParentIdentifier must be unique`
    // semantics error.  A `Semantics` label gives screen readers the
    // same affordance without ever materialising the overlay entry.
    return Semantics(
      label: tooltip,
      button: true,
      enabled: canTap,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: canTap ? onPressed : null,
          child: Container(
            width: 36,
            height: 36,
            decoration: isPrimary && canTap
                ? BoxDecoration(
                    color: colorScheme.primary,
                    borderRadius: BorderRadius.circular(8),
                  )
                : null,
            child: Icon(
              icon,
              size: 20,
              color: isPrimary
                  ? (canTap
                      ? colorScheme.onPrimary
                      : colorScheme.onSurface.withValues(alpha: 0.3))
                  : colorScheme.onSurface.withValues(alpha: canTap ? 0.7 : 0.3),
            ),
          ),
        ),
      ),
    );
  }
}
