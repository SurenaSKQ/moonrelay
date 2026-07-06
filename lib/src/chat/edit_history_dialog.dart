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
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/message_details_page.dart';

/// Shows a scrollable history of prior versions of [event]'s body.
///
/// Matrix stores edits as separate `m.replace` events that all point at
/// the original. We scan the [Timeline] (the locally cached set of events)
/// to find every replacement, then render them newest-first.
Future<void> showEditHistoryDialog(
  BuildContext context, {
  required Event event,
  required Timeline timeline,
  required Room room,
}) async {
  final versions = _collectEditVersions(event, timeline, room);
  if (!context.mounted) return;
  final l10n = AppLocalizations.of(context)!;
  final cs = Theme.of(context).colorScheme;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.editHistoryTitle),
      content: SizedBox(
        width: 520,
        child: versions.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.noEditHistory,
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ),
              )
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 420),
                child: ListView.separated(
                  itemCount: versions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (_, i) {
                    final v = versions[i];
                    return _EditHistoryTile(
                      version: v,
                      isLatest: i == 0,
                      room: room,
                    );
                  },
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(l10n.close),
        ),
      ],
    ),
  );
}

/// Collects every version of [original] found in [timeline].
List<_EventVersion> _collectEditVersions(
  Event original,
  Timeline timeline,
  Room room,
) {
  final versions = <_EventVersion>[];
  versions.add(_EventVersion(event: original));

  for (final e in timeline.events) {
    if (e.eventId == original.eventId) continue;
    final rel = e.content['m.relates_to'];
    if (rel is Map &&
        rel['rel_type'] == 'm.replace' &&
        rel['event_id'] == original.eventId) {
      versions.add(_EventVersion(event: e));
    }
  }

  versions.sort((a, b) => b.event.originServerTs.compareTo(a.event.originServerTs));
  return versions;
}

class _EventVersion {
  _EventVersion({required this.event});
  final Event event;
}

class _EditHistoryTile extends StatelessWidget {
  const _EditHistoryTile({
    required this.version,
    required this.isLatest,
    required this.room,
  });
  final _EventVersion version;
  final bool isLatest;
  final Room room;

  String _body(Event event) {
    try {
      final newContent = event.content['m.new_content'];
      if (newContent is Map && newContent['body'] is String) {
        return newContent['body'] as String;
      }
    } catch (_) {}
    return event.body;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final body = _body(version.event);
    final time = version.event.originServerTs.localizedTimeShort(context);
    final name = version.event.senderFromMemoryOrFallback.calcDisplayname();

    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.of(context).pop();
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MessageDetailsPage(
              event: version.event,
              room: room,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isLatest
              ? cs.primaryContainer.withValues(alpha: 0.5)
              : cs.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: cs.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isLatest ? l10n.editedIndicator : '$time · $name',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: cs.primary,
                    ),
                  ),
                ),
                if (isLatest)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: cs.primary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'CURRENT',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              body,
              style: const TextStyle(fontSize: 14),
              maxLines: 6,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}