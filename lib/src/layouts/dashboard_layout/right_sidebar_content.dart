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
import 'package:provider/provider.dart';
import 'package:moonrelay/src/chat/thread_list_sidebar.dart';
import 'package:moonrelay/src/helpers/current_room.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/sidebar_members_list.dart';
import 'package:moonrelay/src/widgets/sidebar_pinned_messages.dart';

import 'sidebar_room_info.dart';

// ─── Right sidebar: content with view switcher ─────────────────────────────

/// Manages the right sidebar content with a built-in dropdown to switch
/// between room-info and members views.
///
/// Listens to [CurrentRoom] directly so that room changes rebuild only the
/// right sidebar body, not the surrounding dashboard shell.
class RightSidebarContent extends StatelessWidget {
  const RightSidebarContent({super.key});

  @override
  Widget build(BuildContext context) {
    final room = context.watch<CurrentRoom>().room;
    if (room == null) {
      final scheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.arrowRightFromLine,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.selectCategory,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    return RightSidebarWithSwitcher(key: ValueKey(room.id), room: room);
  }
}

/// The right sidebar body with a segmented/dropdown switcher at the top.
class RightSidebarWithSwitcher extends StatelessWidget {
  const RightSidebarWithSwitcher({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final choice = settings.rightPaneChoice;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── View switcher header ──────────────────────────────────
        RightSidebarHeader(
          currentChoice: choice,
          onChanged: (c) => settings.setRightPaneChoice(c),
        ),
        const Divider(height: 1),
        // ── Content ───────────────────────────────────────────────
        Expanded(
          child: switch (choice) {
            RightPaneChoice.none => const SizedBox.shrink(),
            RightPaneChoice.roomInfo => SidebarRoomInfo(room: room),
            RightPaneChoice.members =>
              SidebarMembersList(key: ValueKey(room.id), room: room),
            RightPaneChoice.threads =>
              SidebarThreadList(key: ValueKey(room.id), room: room),
            RightPaneChoice.pinned =>
              SidebarPinnedMessages(key: ValueKey(room.id), room: room),
          },
        ),
      ],
    );
  }
}

/// A compact header bar with a dropdown to switch between room-info and
/// members views.
class RightSidebarHeader extends StatelessWidget {
  const RightSidebarHeader({
    super.key,
    required this.currentChoice,
    required this.onChanged,
  });

  final RightPaneChoice currentChoice;
  final void Function(RightPaneChoice) onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          // Selected view icon
          Icon(
            switch (currentChoice) {
              RightPaneChoice.roomInfo => LucideIcons.info,
              RightPaneChoice.members => LucideIcons.users,
              RightPaneChoice.threads => LucideIcons.messageSquare,
              RightPaneChoice.pinned => Icons.push_pin_outlined,
              RightPaneChoice.none => LucideIcons.panelRight,
            },
            size: 16,
            color: scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          // Dropdown
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<RightPaneChoice>(
                value: currentChoice,
                isDense: true,
                isExpanded: true,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
                items: [
                  DropdownMenuItem(
                    value: RightPaneChoice.roomInfo,
                    child: Text('Room Info'),
                  ),
                  DropdownMenuItem(
                    value: RightPaneChoice.members,
                    child: Text('Members'),
                  ),
                  DropdownMenuItem(
                    value: RightPaneChoice.threads,
                    child: Text('Threads'),
                  ),
                  DropdownMenuItem(
                    value: RightPaneChoice.pinned,
                    child: Text('Pinned'),
                  ),
                  DropdownMenuItem(
                    value: RightPaneChoice.none,
                    child: Text('None'),
                  ),
                ],
                onChanged: (v) {
                  if (v != null) onChanged(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
