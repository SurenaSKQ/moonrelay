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
import 'package:moonrelay/src/chat/chat_box.dart';
import 'package:moonrelay/src/chat/chat_event.dart';
import 'package:moonrelay/src/chat/reactions_bar.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/helpers/thread_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// Full-screen view showing a single thread: the root event, all replies,
/// and a chat box to respond in the thread.
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
  Timeline? _timeline;
  Event? _rootEvent;
  List<Event> _replies = [];
  bool _loading = true;
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    _initThread();
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _initThread() async {
    try {
      final timeline = await widget.room.getTimeline();
      if (!mounted) return;

      // Find the root event in the timeline (fast path).
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
          if (chunk != null) {
            root = chunk.events.firstWhere(
              (e) => e.eventId == widget.threadRootEventId,
            );
          }
        } catch (_) {
          // Server fetch failed; root stays null.
        }
      }

      setState(() {
        _timeline = timeline;
        _rootEvent = root;
        _loading = false;
        if (root != null) {
          _replies = ThreadUtils.threadReplies(root, timeline);
        }
      });

      // Listen for new events via sync.
      _syncSub = widget.room.client.onSync.stream.listen((_) {
        if (!mounted) return;
        _refreshReplies();
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _refreshReplies() {
    if (_timeline == null || _rootEvent == null) return;
    setState(() {
      _replies = ThreadUtils.threadReplies(_rootEvent!, _timeline!);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();
    final fs = settings.fontSize;

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
                  '${_replies.length} ${l10n.threadReplies(_replies.length)}',
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
                    // Thread root event (non-interactive)
                    _ThreadRootTile(
                      event: _rootEvent!,
                      room: widget.room,
                      timeline: _timeline!,
                    ),
                    const Divider(height: 1),
                    // Reply count header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                      child: Text(
                        '${_replies.length} ${l10n.threadReplies(_replies.length)}',
                        style: TextStyle(
                          fontSize: fs * 0.85,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    // Thread replies list
                    Expanded(
                      child: _replies.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noRepliesYet,
                                style: TextStyle(
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            )
                          : ListView.builder(
                              reverse: true,
                              padding: const EdgeInsets.only(top: 4),
                              itemCount: _replies.length,
                              itemBuilder: (context, index) {
                                // _replies is oldest-first, so reverse for ListView.
                                final reply =
                                    _replies.reversed.toList()[index];
                                return _ThreadReplyTile(
                                  event: reply,
                                  room: widget.room,
                                  timeline: _timeline!,
                                );
                              },
                            ),
                    ),
                    const Divider(height: 1),
                    // Chat box for thread replies
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

// ─── Thread reply tile ─────────────────────────────────────────────────────────

/// Renders a single reply within a thread.
class _ThreadReplyTile extends StatelessWidget {
  const _ThreadReplyTile({
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AvatarFromUriOrFallbackImage(
              client: room.client,
              avatarUri: event.senderFromMemoryOrFallback.avatarUrl,
              radius: 16,
            ),
          ),
          const SizedBox(width: 8),
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
                          fontSize: fs * 0.85,
                          fontWeight: FontWeight.w600,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      event.originServerTs.localizedTimeShort(context),
                      style: TextStyle(
                        fontSize: fs * 0.7,
                        color: scheme.onSurface.withValues(alpha: 0.45),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
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
