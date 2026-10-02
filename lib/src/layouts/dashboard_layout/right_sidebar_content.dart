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
import 'package:moonrelay/src/screens/hub_screen/localization_helpers.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/sidebar_members_list.dart';
import 'package:moonrelay/src/widgets/sidebar_pinned_messages.dart';

import 'sidebar_room_info.dart';

// --- Right sidebar: content with view switcher -----------------------------

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
      final t = MoonrelayThemeExtension.of(context).tokens;
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.arrowRightFromLine,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(
                alpha: t.opacityDisabled,
              ),
            ),
            SizedBox(height: t.spaceMd),
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
        // -- View switcher header ----------------------------------
        RightSidebarHeader(
          currentChoice: choice,
          onChanged: (c) => settings.setRightPaneChoice(c),
        ),
        const Divider(height: 1),
        // -- Content -----------------------------------------------
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

/// A tab strip across the top of the right pane.
///
/// This was a `DropdownButton` over the same five values. A dropdown is the
/// wrong control here for two reasons. It hides four destinations behind a
/// closed menu, and threads and pinned messages are not secondary: they are
/// where a user goes to answer a mention or find something they were told
/// to look at. And the header showed only the selected value as a bare
/// icon, so the pane did not advertise what it could show.
///
/// The labels it hard-coded ('Room Info', 'Members', 'Threads', 'Pinned')
/// are gone with it. [localizedRightPaneChoice] already existed and was
/// already used by the hub's layout settings, so the same mapping is used
/// here rather than a second one.
class RightSidebarHeader extends StatelessWidget {
  const RightSidebarHeader({
    super.key,
    required this.currentChoice,
    required this.onChanged,
  });

  final RightPaneChoice currentChoice;
  final void Function(RightPaneChoice) onChanged;

  /// The destinations worth a tab, in reading order.
  ///
  /// [RightPaneChoice.none] is deliberately absent. "Show nothing" is not a
  /// destination, and the pane already has a collapse control for it, so
  /// giving it a tab would spend one of four slots on turning the pane
  /// off. The value stays valid in storage: a user who was last on `none`
  /// opens the pane to a strip with nothing selected rather than to an
  /// error, and one tap puts them somewhere.
  static const List<RightPaneChoice> destinations = <RightPaneChoice>[
    RightPaneChoice.roomInfo,
    RightPaneChoice.members,
    RightPaneChoice.threads,
    RightPaneChoice.pinned,
  ];

  static IconData _iconFor(RightPaneChoice choice) =>
      switch (choice) {
        RightPaneChoice.roomInfo => LucideIcons.info,
        RightPaneChoice.members => LucideIcons.users,
        RightPaneChoice.threads => LucideIcons.messageSquare,
        RightPaneChoice.pinned => Icons.push_pin_outlined,
        RightPaneChoice.none => LucideIcons.panelRight,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final layers = ext.layers;
    final l10n = AppLocalizations.of(context)!;

    // One step *below* the pane's own fill, so the switcher reads as a strip
    // attached to the top of the panel rather than as a fourth surface.  It
    // was `surfaceContainerHighest`, which is the hover step, so the one
    // always-visible bar in the detail pane was painted in the colour the app
    // uses for "the pointer is over this".
    return Container(
      color: layers.hover,
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceSm,
        vertical: t.spaceXs,
      ),
      child: Row(
        children: [
          for (final choice in destinations) ...[
            Expanded(
              child: _PaneTab(
                icon: _iconFor(choice),
                label: localizedRightPaneChoice(choice, l10n),
                selected: choice == currentChoice,
                onTap: () => onChanged(choice),
              ),
            ),
            if (choice != destinations.last)
              SizedBox(width: t.borderWidthThin * 2),
          ],
        ],
      ),
    );
  }
}

/// One destination in [RightSidebarHeader].
///
/// Icon plus a short label, selected state carried by the container rather
/// than by colour alone, so the strip still reads at a glance in a theme
/// where the accent is close to the surface.
class _PaneTab extends StatelessWidget {
  const _PaneTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.of(context);
    final scheme = Theme.of(context).colorScheme;
    final t = ext.tokens;

    return Tooltip(
      message: label,
      child: Semantics(
        selected: selected,
        button: true,
        child: Material(
          // `surfaceContainerHighest`: one step above the switcher strip's
          // `hover`, which puts the selected tab *above* the strip rather
          // than beside it. It was `secondaryContainer`, which is a fourth
          // use of a container role for a selection state.
          color: selected
              ? scheme.surfaceContainerHighest
              : Colors.transparent,
          borderRadius: BorderRadius.circular(t.radiusSm),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: t.spaceXs),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: t.iconSizeSmall + 2,
                    color: selected
                        ? scheme.primary
                        : scheme.onSurfaceVariant,
                  ),
                  SizedBox(height: 2),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1.2,
                      fontWeight:
                          selected ? FontWeight.w600 : FontWeight.w500,
                      color: selected
                          ? scheme.onSurface
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
