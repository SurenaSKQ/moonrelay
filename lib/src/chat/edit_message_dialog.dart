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
import 'package:moonrelay/src/helpers/markdown_to_html.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

/// Shows a dialog that lets the user replace the body of [event] with new
/// text. The new text is sent as a `m.replace` relation against the
/// original event using `Event.edit()`.
///
/// Returns `true` if an edit was submitted, `false` if the user cancelled.
Future<bool> showEditMessageDialog(
  BuildContext context, {
  required Event event,
  required Room room,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final log = context.read<Logger>();

  final controller = TextEditingController(
    text: latestEditedBody(event),
  );

  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l10n.editMessageTitle),
      content: SizedBox(
        width: 480,
        child: TextField(
          controller: controller,
          autofocus: true,
          minLines: 3,
          maxLines: 12,
          decoration: InputDecoration(
            hintText: event.body,
          ),
          textCapitalization: TextCapitalization.sentences,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(l10n.editSave),
        ),
      ],
    ),
  );

  if (result != true) return false;
  if (!context.mounted) return false;

  final newBody = controller.text.trim();
  if (newBody.isEmpty || newBody == latestEditedBody(event)) {
    return false;
  }

  try {
    final html = MarkdownToHtml.convert(newBody);
    final hasHtml = html.isNotEmpty && html != newBody;

    final content = <String, dynamic>{
      'msgtype': event.messageType,
      'body': newBody,
      if (hasHtml) ...<String, dynamic>{
        'format': 'org.matrix.custom.html',
        'formatted_body': html,
      },
      'm.new_content': <String, dynamic>{
        'msgtype': event.messageType,
        'body': newBody,
        if (hasHtml) ...<String, dynamic>{
          'format': 'org.matrix.custom.html',
          'formatted_body': html,
        },
      },
      'm.relates_to': <String, dynamic>{
        'rel_type': 'm.replace',
        'event_id': event.eventId,
      },
    };

    // Preserve thread context when editing a threaded message.
    final threadRel = _threadRelation(event);
    if (threadRel != null) {
      (content['m.relates_to'] as Map<String, dynamic>)['m.thread'] = threadRel;
    }

    await withRetry(
      () => room.sendEvent(content, threadRootEventId: _threadRootId(event)),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'editMessage',
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.editFailed('$e'))),
    );
    return false;
  }
}

/// Returns the most recent edited body for [event], or its original body
/// when the event hasn't been edited.
String latestEditedBody(Event event) {
  try {
    final newContent = event.content['m.new_content'];
    if (newContent is Map && newContent['body'] is String) {
      return newContent['body'] as String;
    }
  } catch (_) {}
  return event.body;
}

/// `m.thread` payload for the event, or null.
Map<String, dynamic>? _threadRelation(Event event) {
  try {
    final rel = event.relationshipEventId;
    final isThread = rel != null &&
        event.content['m.relates_to'] is Map &&
        (event.content['m.relates_to'] as Map)['rel_type'] == 'm.thread';
    if (isThread) {
      return {'event_id': rel};
    }
  } catch (_) {}
  return null;
}

/// `m.thread` root id for [event], if any.
String? _threadRootId(Event event) {
  final rel = _threadRelation(event);
  return rel?['event_id'] as String?;
}