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
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/markdown_to_html.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
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
  const ChatBox({super.key, required this.room, this.replyTarget});

  final Room room;

  /// A notifier that signals which event (if any) the user is currently
  /// replying to.  Set to `null` to clear the reply preview.
  final ValueNotifier<Event?>? replyTarget;

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

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _focusNode = FocusNode();
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
    widget.replyTarget?.removeListener(_onReplyTargetChanged);
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _focusNode.dispose();
    _expandController.dispose();
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
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final log = context.read<Logger>();
    final replyTo = _replyEvent;
    final html = MarkdownToHtml.convert(text);

    Future<void> sendFn() async {
      if (replyTo != null) {
        await widget.room.sendTextEvent(
          text,
          inReplyTo: replyTo,
        );
      } else if (html == text || html.isEmpty) {
        await widget.room.sendTextEvent(text);
      } else {
        await widget.room.sendEvent({
          'body': text,
          'msgtype': MessageTypes.Text,
          'format': 'org.matrix.custom.html',
          'formatted_body': html,
        });
      }
    }

    withTimeout(sendFn, timeout: kDefaultTimeout).then((_) {
      if (!mounted) return;
      _controller.clear();
      _clearReply();
    }).catchError((Object e) {
      log.w('Failed to send message', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)?.error ?? "Error"}: '
              'Failed to send message. ${e is TimeoutException ? "The request timed out." : e}',
            ),
          ),
        );
      }
    });
  }

  void _clearReply() {
    widget.replyTarget?.value = null;
    setState(() => _replyEvent = null);
  }

  Future<void> _attachFile() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: true,
    );
    if (result == null || result.files.isEmpty) return;

    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        // Fallback: read from path.
        final path = file.path;
        if (path == null) continue;
        try {
          final fileBytes = await File(path).readAsBytes();
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
                  '${AppLocalizations.of(context)?.error ?? "Error"}: '
                  '${e is TimeoutException ? "Upload timed out." : e}',
                ),
              ),
            );
          }
        }
        continue;
      }

      try {
        await withTimeout(
          () => widget.room.sendFileEvent(
            MatrixFile(bytes: bytes, name: file.name),
          ),
          timeout: kUploadTimeout,
        );
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${AppLocalizations.of(context)?.error ?? "Error"}: '
                '${e is TimeoutException ? "Upload timed out." : e}',
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
    final l10n = AppLocalizations.of(context);

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
                  tooltip: l10n?.chatBoxAttach ?? 'Attach file',
                  onPressed: _attachFile,
                  colorScheme: colorScheme,
                ),

                const SizedBox(width: 4),

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
                      textInputAction: _isExpanded
                          ? TextInputAction.newline
                          : TextInputAction.send,
                      onSubmitted: _isExpanded ? null : (_) => _send(),
                      style: TextStyle(
                        fontSize: 15,
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText:
                            l10n?.chatBoxSendMessage ?? 'Send a message\u2026',
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
                  tooltip: _isExpanded
                      ? (l10n?.chatBoxCollapse ?? 'Collapse')
                      : (l10n?.chatBoxExpand ?? 'Expand editor'),
                  onPressed: _toggleExpand,
                  colorScheme: colorScheme,
                ),

                // Send button
                _IconButton(
                  icon: LucideIcons.send,
                  tooltip: l10n?.chatBoxSend ?? 'Send',
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
                  l10n?.chatBoxReplyingTo(senderName) ??
                      'Replying to $senderName',
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
          Tooltip(
            message: l10n?.chatBoxCancelReply ?? 'Cancel reply',
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Wrap(
        spacing: 2,
        runSpacing: 2,
        children: [
          _formatButton(
            icon: LucideIcons.bold,
            tooltip: 'Bold',
            onTap: () => _wrapSelection('**', '**'),
          ),
          _formatButton(
            icon: LucideIcons.italic,
            tooltip: 'Italic',
            onTap: () => _wrapSelection('*', '*'),
          ),
          _formatButton(
            icon: LucideIcons.strikethrough,
            tooltip: 'Strikethrough',
            onTap: () => _wrapSelection('~~', '~~'),
          ),
          _formatDivider(),
          _formatButton(
            icon: LucideIcons.code,
            tooltip: 'Inline code',
            onTap: () => _wrapSelection('`', '`'),
          ),
          _formatButton(
            icon: LucideIcons.code2,
            tooltip: 'Code block',
            onTap: () => _wrapSelection('```\n', '\n```'),
          ),
          _formatDivider(),
          _formatButton(
            icon: LucideIcons.textQuote,
            tooltip: 'Blockquote',
            onTap: () => _insertLinePrefix('> '),
          ),
          _formatButton(
            icon: LucideIcons.heading1,
            tooltip: 'Heading',
            onTap: () => _insertLinePrefix('# '),
          ),
          _formatButton(
            icon: LucideIcons.list,
            tooltip: 'Unordered list',
            onTap: () => _insertLinePrefix('- '),
          ),
          _formatButton(
            icon: LucideIcons.listOrdered,
            tooltip: 'Ordered list',
            onTap: () => _insertLinePrefix('1. '),
          ),
          _formatDivider(),
          _formatButton(
            icon: LucideIcons.link,
            tooltip: 'Link',
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
    return SizedBox(
      width: 32,
      height: 32,
      child: Tooltip(
        message: tooltip,
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
    return Tooltip(
      message: tooltip,
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
