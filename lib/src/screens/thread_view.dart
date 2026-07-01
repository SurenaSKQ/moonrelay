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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/chat/chat_event.dart';
import 'package:moonrelay/src/chat/chat_timeline.dart';
import 'package:moonrelay/src/chat/reactions_bar.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/helpers/thread_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// Full-screen view showing a single thread: the root event, a reply
/// timeline powered by [ChatTimeline] (with scroll-to-load, display modes,
/// and hover actions), and a chat box to respond in the thread.
class ThreadViewPage extends StatefulWidget {
  const ThreadViewPage({
    super.key,
    required this.room,
    required this.threadRootEventId,
  });

  final Room room;
  final String threadRootEventId;

  @override
  State<ThreadViewPage> createState() => _ThreadViewPageState();
}

class _ThreadViewPageState extends State<ThreadViewPage> {
  Event? _rootEvent;
  Timeline? _timeline;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _findRootEvent();
  }

  Future<void> _findRootEvent() async {
    try {
      // Try the fast path: look in the room's existing timeline.
      final timeline = await widget.room.getTimeline();
      if (!mounted) return;

      Event? root;
      for (final e in timeline.events) {
        if (e.eventId == widget.threadRootEventId) {
          root = e;
          break;
        }
      }

      // If not found in the timeline, fetch it from the server.
      if (root == null) {
        try {
          final chunk =
              await widget.room.getEventContext(widget.threadRootEventId);
          if (!mounted) return;
          if (chunk != null) {
            root = chunk.events.firstWhere(
              (e) => e.eventId == widget.threadRootEventId,
            );
          }
        } catch (_) {
          // Server fetch failed; root stays null.
        }
      }

      if (!mounted) return;
      setState(() {
        _rootEvent = root;
        _timeline = timeline;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();
    final fs = settings.fontSize;

    // Count replies via the stored timeline.
    final replyCount = _rootEvent != null && _timeline != null
        ? _rootEvent!
            .aggregatedEvents(_timeline!, RelationshipTypes.thread)
            .length
        : 0;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.thread,
          style: TextStyle(fontSize: fs * 1.1),
        ),
        actions: [
          if (_rootEvent != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  l10n.threadReplies(replyCount),
                  style: TextStyle(
                    fontSize: fs * 0.8,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rootEvent == null
              ? Center(
                  child: Text(
                    '${l10n.error}: Could not load thread',
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                )
              : Column(
                  children: [
                    _ThreadRootTile(
                      event: _rootEvent!,
                      room: widget.room,
                      timeline: _timeline!,
                    ),
                    const Divider(height: 1),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: scheme.surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      child: Text(
                        l10n.threadReplies(replyCount),
                        style: TextStyle(
                          fontSize: fs * 0.85,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: ChatTimeline(
                        room: widget.room,
                        filterEvents: (event) =>
                            ThreadUtils.isThreadReply(event) &&
                            event.relationshipEventId ==
                                widget.threadRootEventId,
                      ),
                    ),
                    const Divider(height: 1),
                    ChatBox(
                      room: widget.room,
                      threadRootEventId: widget.threadRootEventId,
                    ),
                  ],
                ),
    );
  }
}

// ─── Thread root tile ──────────────────────────────────────────────────────────

/// Displays the root event of a thread in a non-interactive card.
class _ThreadRootTile extends StatelessWidget {
  const _ThreadRootTile({
    required this.event,
    required this.room,
    required this.timeline,
  });

  final Event event;
  final Room room;
  final Timeline timeline;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();
    final fs = settings.fontSize;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.3),
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: AvatarFromUriOrFallbackImage(
              client: room.client,
              avatarUri: event.senderFromMemoryOrFallback.avatarUrl,
              radius: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        event.senderFromMemoryOrFallback.calcDisplayname(),
                        style: TextStyle(
                          fontSize: fs,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      event.originServerTs.localizedTimeShort(context),
                      style: TextStyle(
                        fontSize: fs * 0.75,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                MessageEventHandler(
                  event: event,
                  timeline: timeline,
                  room: room,
                ),
                ReactionsBar(
                  event: event,
                  timeline: timeline,
                  room: room,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
