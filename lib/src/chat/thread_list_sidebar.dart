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
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/thread_view.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

/// Displays a list of all threads in the room, fetched from the server via
/// the thread roots API.
class SidebarThreadList extends StatefulWidget {
  const SidebarThreadList({super.key, required this.room});

  final Room room;

  @override
  State<SidebarThreadList> createState() => _SidebarThreadListState();
}

class _SidebarThreadListState extends State<SidebarThreadList> {
  final List<MatrixEvent> _threads = [];
  bool _isLoading = false;
  bool _hasMore = true;
  String? _nextBatch;
  StreamSubscription? _syncSub;

  static const int _batchSize = 20;

  @override
  void initState() {
    super.initState();
    _fetchThreads();
    _syncSub = widget.room.client.onSync.stream.listen((_) {
      if (mounted) _fetchThreads(forceRefresh: true);
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  Future<void> _fetchThreads({bool forceRefresh = false}) async {
    if (_isLoading) return;
    if (!forceRefresh && !_hasMore) return;

    setState(() => _isLoading = true);

    try {
      final response = await widget.room.client.getThreadRoots(
        widget.room.id,
        include: Include.all,
        limit: _batchSize,
        from: forceRefresh ? null : _nextBatch,
      );

      if (!mounted) return;

      setState(() {
        if (forceRefresh) {
          _threads.clear();
        }
        _threads.addAll(response.chunk);
        _nextBatch = response.nextBatch;
        _hasMore = response.nextBatch != null;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();
    final fs = settings.fontSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            l10n.threads,
            style: TextStyle(
              fontSize: fs * 0.9,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _threads.isEmpty && !_isLoading
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.messageSquare,
                          size: 32,
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.noThreadsYet,
                          style: TextStyle(
                            fontSize: fs * 0.85,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : NotificationListener<ScrollEndNotification>(
                  onNotification: (notification) {
                    if (notification.metrics.pixels >=
                        notification.metrics.maxScrollExtent - 100) {
                      _fetchThreads();
                    }
                    return false;
                  },
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: _threads.length + (_hasMore ? 1 : 0),
                    separatorBuilder: (_, __) =>
                        Divider(height: 1, indent: 12, endIndent: 12),
                    itemBuilder: (context, index) {
                      if (index >= _threads.length) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final matrixEvent = _threads[index];
                      final event = Event.fromMatrixEvent(
                        matrixEvent,
                        widget.room,
                      );

                      return _ThreadListTile(
                        event: event,
                        room: widget.room,
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

// ─── Thread list tile ──────────────────────────────────────────────────────────

/// A single tile in the thread list showing the thread root preview.
class _ThreadListTile extends StatelessWidget {
  const _ThreadListTile({
    required this.event,
    required this.room,
  });

  final Event event;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<SettingsController>();
    final fs = settings.fontSize;
    final sender = event.senderFromMemoryOrFallback;

    return InkWell(
      onTap: () => _openThread(context),
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AvatarFromUriOrFallbackImage(
              client: room.client,
              avatarUri: sender.avatarUrl,
              radius: 16,
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
                          sender.calcDisplayname(),
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
                  Text(
                    event.body.isNotEmpty
                        ? event.body
                        : '(image or file)',
                    style: TextStyle(
                      fontSize: fs * 0.8,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: scheme.onSurface.withValues(alpha: 0.3),
            ),
          ],
        ),
      ),
    );
  }

  void _openThread(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ThreadViewPage(
          room: room,
          threadRootEventId: event.eventId,
        ),
      ),
    );
  }
}
