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
import 'package:matrix/matrix.dart';

/// Displays detailed information about a single timeline event, including
/// sender metadata, timestamps, event identifiers, and the raw JSON content.
class MessageDetailsPage extends StatelessWidget {
  const MessageDetailsPage({
    super.key,
    required this.event,
    required this.room,
  });

  final Event event;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final sender = event.senderFromMemoryOrFallback;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Message Details'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // --- Sender section ---
          _SectionHeader(title: 'Sender', cs: cs),
          _InfoRow(label: 'Display name', value: sender.calcDisplayname()),
          _InfoRow(label: 'User ID', value: sender.id, mono: true),
          const Divider(),

          // --- Timestamps ---
          _SectionHeader(title: 'Timestamps', cs: cs),
          _InfoRow(
            label: 'Sent at',
            value: event.originServerTs.toIso8601String(),
          ),
          const Divider(),

          // --- Event info ---
          _SectionHeader(title: 'Event Info', cs: cs),
          _InfoRow(label: 'Event type', value: event.type, mono: true),
          _InfoRow(label: 'Event ID', value: event.eventId, mono: true),
          _InfoRow(label: 'Room ID', value: room.id, mono: true),
          _InfoRow(
            label: 'Status',
            value: event.redacted ? 'Redacted (deleted)' : 'Active',
          ),
          if (event.relationshipType != null)
            _InfoRow(
              label: 'Relationship',
              value: event.relationshipType!,
              mono: true,
            ),
          if (event.relationshipEventId != null)
            _InfoRow(
              label: 'Related event ID',
              value: event.relationshipEventId!,
              mono: true,
            ),
          if (event.inReplyToEventId() != null)
            _InfoRow(
              label: 'Reply to event ID',
              value: event.inReplyToEventId()!,
              mono: true,
            ),
          const Divider(),

          // --- Raw JSON ---
          _SectionHeader(title: 'Raw Content', cs: cs),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: cs.surfaceContainerHighest.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: cs.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: SelectableText(
              _formatJson(event.content),
              style: TextStyle(
                fontFamily: 'FiraCode',
                fontSize: 12,
                color: cs.onSurface,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pretty-prints the event content map as JSON.
  String _formatJson(Map<String, dynamic> content) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(content);
  }
}

// ---------------------------------------------------------------------------
// Reusable sub-widgets
// ---------------------------------------------------------------------------

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.cs});

  final String title;
  final ColorScheme cs;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 4),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: cs.primary,
          fontFamily: 'Rubik',
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    this.mono = false,
  });

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: cs.onSurface.withValues(alpha: 0.6),
                fontFamily: 'Rubik',
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: SelectableText(
              value,
              style: TextStyle(
                fontSize: 13,
                fontFamily: mono ? 'FiraCode' : 'Rubik',
                color: cs.onSurface,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
