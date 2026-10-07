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

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Builder dialog for creating a new MSC3381 poll.
///
/// Sends the poll via [Room.sendEvent] with the `m.poll.start` event type
/// so other Matrix clients render it as an interactive poll.
Future<void> showPollCreateDialog(BuildContext context, Room room) async {
  await showDialog<void>(
    context: context,
    builder: (_) => _PollCreateDialog(room: room),
  );
}

class _PollCreateDialog extends StatefulWidget {
  const _PollCreateDialog({required this.room});
  final Room room;

  @override
  State<_PollCreateDialog> createState() => _PollCreateDialogState();
}

class _PollCreateDialogState extends State<_PollCreateDialog> {
  final TextEditingController _questionController = TextEditingController();
  final List<TextEditingController> _optionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  bool _sending = false;

  @override
  void dispose() {
    _questionController.dispose();
    for (final c in _optionControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    if (_optionControllers.length >= 10) return;
    setState(() => _optionControllers.add(TextEditingController()));
  }

  void _removeOption(int index) {
    if (_optionControllers.length <= 2) return;
    setState(() {
      _optionControllers[index].dispose();
      _optionControllers.removeAt(index);
    });
  }

  Future<void> _send() async {
    final l10n = AppLocalizations.of(context)!;
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pollInvalid)),
      );
      return;
    }

    setState(() => _sending = true);
    try {
      await withRetry(
        () => widget.room.sendEvent(
          <String, dynamic>{
            'm.poll': <String, dynamic>{
              'question': <String, dynamic>{
                'body': question,
                'msgtype': 'm.text',
              },
              'answers': List.generate(
                options.length,
                (i) => <String, dynamic>{
                  'id': _idForIndex(i),
                  'body': options[i],
                  'msgtype': 'm.text',
                },
              ),
              'max_selections': 1,
              'kind': 'm.poll.disclosed',
            },
          },
          type: 'm.poll.start',
        ),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: null,
        label: 'sendPoll',
      );

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  // Stable, readable IDs that won't collide between options.
  String _idForIndex(int i) => 'opt_${i + 1}';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final cs = Theme.of(context).colorScheme;

    return AlertDialog(
      icon: Icon(LucideIcons.listChecks, color: cs.primary),
      title: Text(l10n.pollQuestion),
      content: SizedBox(
        width: 440,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // -- Question ----------------------------------------------
              TextField(
                controller: _questionController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: l10n.pollQuestion,
                  hintText: l10n.pollQuestionHint,
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: 16),

              // -- Options -----------------------------------------------
              Text(
                l10n.pollOptions,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 6),
              ..._optionControllers.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: c,
                          decoration: InputDecoration(
                            hintText: l10n.pollOptionHint,
                            isDense: true,
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        IconButton(
                          icon: const Icon(LucideIcons.minusCircle, size: 18),
                          tooltip: l10n.cancel,
                          onPressed: () => _removeOption(i),
                        ),
                    ],
                  ),
                );
              }),
              TextButton.icon(
                icon: const Icon(LucideIcons.plusCircle, size: 18),
                label: Text(l10n.pollAddOption),
                onPressed: _optionControllers.length < 10 ? _addOption : null,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton.icon(
          icon: _sending
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.send, size: 18),
          label: Text(l10n.pollSend),
          onPressed: _sending ? null : _send,
        ),
      ],
    );
  }
}
