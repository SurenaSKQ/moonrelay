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
// You should have received a copy of the GNU Affero General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/menu_row.dart';

/// Right-click and long-press menu for a member row.
///
/// This replaces three hand-written copies of the same two-item menu, one in
/// the sidebar's member list, one in the full-screen members view, and one in
/// the room details pane. They had drifted in ways that were all wrong or all
/// inconsistent:
///
/// - Each positioned the menu at a hardcoded guess at the tile's width
///   (`offset.dx + 160` in one, `+ 200` in the others, with a comment
///   admitting it was "roughly the tile width"), so right-clicking a member
///   opened a menu somewhere near the row rather than at the pointer, and
///   which guess you got depended on which pane you were in.
/// - Each built its rows as `PopupMenuItem(child: ListTile(...))`, which
///   stacks two sets of padding and two sets of minimum heights, and used
///   Material glyphs in a Lucide app.
/// - A single left click opened the menu. In all three, `onTap` was wired to
///   the same popup as `onSecondaryTap` and `onLongPress`, so the members list
///   had no primary action at all: clicking someone opened a two-item popup
///   instead of their profile, and the menu was the only way to navigate.
///
/// A left click is [onOpenProfile] here. The popup is for the secondary
/// actions, which is what makes it a context menu rather than the only route
/// to the thing it describes.
class MemberContextMenu extends StatefulWidget {
  const MemberContextMenu({
    super.key,
    required this.member,
    required this.onOpenProfile,
    required this.onSendMessage,
    required this.child,
  });

  final User member;

  /// Primary action, bound to a plain click.
  final VoidCallback onOpenProfile;

  /// Starts (or opens) a direct chat.
  final VoidCallback onSendMessage;

  final Widget child;

  @override
  State<MemberContextMenu> createState() => _MemberContextMenuState();
}

class _MemberContextMenuState extends State<MemberContextMenu> {
  /// Where the menu opens, in global coordinates.
  ///
  /// Recorded separately because `onSecondaryTap` carries no position and
  /// using `Offset.zero` would open the menu in the corner of the screen.
  Offset _tapPosition = Offset.zero;

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.deferToChild,
        onTap: widget.onOpenProfile,
        onLongPressStart: (details) {
          _tapPosition = details.globalPosition;
          _show(context);
        },
        // Records the position without opening the menu: `onSecondaryTap`
        // has none, so opening there would put it wherever the pointer last
        // was, and opening on press instead of release is the desktop
        // convention for a context menu.
        onSecondaryTapDown: (details) => _tapPosition = details.globalPosition,
        onSecondaryTap: () => _show(context),
        child: widget.child,
      );

  void _show(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final overlay =
        Overlay.of(context, rootOverlay: true).context.findRenderObject()!
            as RenderBox;
    final local = overlay.globalToLocal(_tapPosition);

    showMenu<String>(
      context: context,
      position: RelativeRect.fromRect(
        Rect.fromPoints(local, local),
        Offset.zero & overlay.size,
      ),
      constraints: moonrelayMenuConstraints(),
      items: [
        MoonrelayMenuItem<String>(
          value: 'profile',
          icon: LucideIcons.user,
          label: l10n.viewProfile,
        ),
        MoonrelayMenuItem<String>(
          value: 'message',
          icon: LucideIcons.messageSquare,
          label: l10n.sendMessage,
        ),
      ],
    ).then((value) {
      if (value == null || !context.mounted) return;
      switch (value) {
        case 'profile':
          widget.onOpenProfile();
        case 'message':
          widget.onSendMessage();
      }
    });
  }
}