// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:moonrelay/src/widgets/empty_state.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:moonrelay/src/chat/room_pane/room_pane_tab.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/date_time_extension.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_threads_view.dart';
import 'package:moonrelay/src/screens/thread_view.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

class TopThreadsSection extends StatefulWidget {
  const TopThreadsSection({
    super.key,
    required this.room,
  });

  final Room room;

  @override
  State<TopThreadsSection> createState() => TopThreadsSectionState();
}

class TopThreadsSectionState extends State<TopThreadsSection> {
  List<Event> _threadRoots = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadThreadRoots();
  }

  Future<void> _loadThreadRoots() async {
    try {
      final response = await widget.room.client.getThreadRoots(
        widget.room.id,
        include: Include.all,
        limit: 10,
      );
      if (!mounted) return;
      setState(() {
        _threadRoots = response.chunk
            .map((m) => Event.fromMatrixEvent(m, widget.room))
            .toList();
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
    final t = MoonrelayThemeExtension.of(context).tokens;

    if (_isLoading) {
      return PaneLoading(label: AppLocalizations.of(context)!.loading);
    }

    return Column(
      children: [
        ..._threadRoots.map((event) {
          final sender = event.senderFromMemoryOrFallback;
          return ThreadRootTile(
            event: event,
            sender: sender,
            room: widget.room,
          );
        }),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(LucideIcons.messageSquare, size: 18),
              label: Text(
                l10n.showAllThreads(_threadRoots.length),
              ),
              onPressed: () => _openFullThreadList(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: scheme.primary,
                side: BorderSide(color: scheme.outline),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusMd),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openFullThreadList(BuildContext context) {
    // If the right sidebar is visible and already showing threads, navigate
    // back to the room page with the threads sidebar active.
    final settings = context.read<SettingsController>();
    if (settings.rightSidebarVisible &&
        settings.roomPaneTab == RoomPaneTab.threads) {
      Navigator.of(context).pop();
      return;
    }

    // Otherwise, open the dedicated full-screen threads list.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullRoomThreadsList(room: widget.room),
      ),
    );
  }
}

class ThreadRootTile extends StatelessWidget {
  const ThreadRootTile({
    super.key,
    required this.event,
    required this.sender,
    required this.room,
  });

  final Event event;
  final User sender;
  final Room room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    // The InkWell below already handles this tap. The GestureDetector that used
    // to wrap it registered the same handler a second time on the same
    // gesture arena.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusMd),
        color: Colors.transparent,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(t.radiusMd),
        onTap: () => _openThread(context),
        child: Row(
          children: [
            // Avatar
            SizedBox(
              width: 36,
              height: 36,
              child: AvatarFromUriOrFallbackImage(
                client: room.client,
                avatarUri: sender.avatarUrl,
              ),
            ),
            SizedBox(width: t.spaceMd),
            // Preview
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sender.calcDisplayname(),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: t.spaceXxs),
                  Text(
                    event.body.isNotEmpty ? event.body : '(image or file)',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            SizedBox(width: t.spaceSm),
            Text(
              event.originServerTs.localizedTimeShort(context),
              style: TextStyle(
                fontSize: 11,
                color: scheme.onSurface.withValues(alpha: 0.45),
              ),
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
