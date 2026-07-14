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
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/helpers/threads_provider.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/thread_view.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
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
  late final ThreadsProvider _provider;

  @override
  void initState() {
    super.initState();
    _provider = ThreadsProvider(room: widget.room);
    _provider.bind(context.read<SyncPulse>());
    _provider.fetch(firstPage: true);
  }

  @override
  void dispose() {
    _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final settings = context.watch<SettingsController>();
    final fs = settings.fontSize;

    return ListenableBuilder(
      listenable: _provider,
      builder: (context, _) {
        final threads = _provider.threadRoots;

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
              child: threads.isEmpty && !_provider.isLoading
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.messageSquare,
                              size: 32,
                              color: scheme.onSurfaceVariant
                                  .withValues(alpha: 0.3),
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
                          _provider.fetch();
                        }
                        return false;
                      },
                      child: ListView.separated(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        itemCount:
                            threads.length + (_provider.hasMore ? 1 : 0),
                        separatorBuilder: (_, __) =>
                            const Divider(height: 1, indent: 12, endIndent: 12),
                        itemBuilder: (context, index) {
                          if (index >= threads.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                            );
                          }

                          final event = threads[index];

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
      },
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

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: CircleAvatar(
        radius: 14,
        backgroundImage: event.senderFromMemoryOrFallback.avatarUrl != null
            ? NetworkImage(
                event.senderFromMemoryOrFallback.avatarUrl.toString(),
              )
            : null,
        child: event.senderFromMemoryOrFallback.avatarUrl == null
            ? Icon(Icons.person, size: 14, color: scheme.onSurfaceVariant)
            : null,
      ),
      title: Text(
        event.senderFromMemoryOrFallback.calcDisplayname(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fs * 0.85,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        event.body.isNotEmpty ? event.body : event.type,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: fs * 0.75,
          color: scheme.onSurfaceVariant,
        ),
      ),
      trailing: Text(
        event.originServerTs.localizedTimeShort(context),
        style: TextStyle(
          fontSize: fs * 0.65,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
        ),
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ThreadViewPage(
              room: room,
              threadRootEventId: event.eventId,
            ),
          ),
        );
      },
    );
  }
}
