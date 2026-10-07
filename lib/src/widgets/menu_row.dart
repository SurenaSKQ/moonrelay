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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// A popup-menu row that cannot overflow, which is the whole point of it.
///
/// Every menu in this app used to build its row as
/// `Row(children: [Icon, SizedBox, Text])`, which is fine until the label is
/// longer than the menu is wide, at which point the row overflows and Flutter
/// paints a yellow-and-black stripe through the label. It was not a rare
/// label: `showMenu` clamps its own width to
/// `BoxConstraints(minWidth: 112, maxWidth: 280)` in
/// `material/popup_menu.dart`, so *any* label past roughly 240px overflowed,
/// and the chat menu's labels include "Copy message link" and "Open sender's
/// profile". The message menu therefore threw a layout exception on every
/// single open, in every locale, and had done for as long as it existed.
///
/// The fix is the `Expanded`: the label gets whatever width is left and
/// ellipsises if even that is not enough. A menu row that clips a long label
/// is a cosmetic problem; one that throws during layout is a broken feature.
///
/// Also single-sources the icon gap, the label's vertical centring, and the
/// optional trailing glyph, which four menus had each reimplemented with
/// slightly different spacing.
class MoonrelayMenuItem<T> extends PopupMenuItem<T> {
  MoonrelayMenuItem({
    super.key,
    required super.value,
    required this.icon,
    required this.label,
    this.color,
    this.trailing,
  }) : super(
          child: _MenuRowContent(
            icon: icon,
            label: label,
            color: color,
            trailing: trailing,
          ),
        );

  /// Leading glyph. Should be a Lucide icon; this app has no Material icon set.
  final IconData icon;

  final String label;

  /// Overrides the label colour. Defaults to the scheme's `onSurface`.
  final Color? color;

  /// Optional trailing widget, e.g. a keyboard shortcut hint.
  final Widget? trailing;
}

/// The visible part of a [MoonrelayMenuItem].
///
/// A separate widget rather than an inline `Row` because [PopupMenuItem] takes
/// its child in the constructor, where there is no `BuildContext` to read
/// tokens from.
class _MenuRowContent extends StatelessWidget {
  const _MenuRowContent({
    required this.icon,
    required this.label,
    this.color,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final Color? color;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = MoonrelayThemeExtension.of(context);
    final tokens = theme.tokens;
    final foreground = color ?? Theme.of(context).colorScheme.onSurface;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: theme.components.input.contentPaddingH,
        vertical: theme.components.input.contentPaddingV,
      ),
      child: Row(
        children: [
          Icon(icon, size: tokens.iconSizeSmall, color: foreground),
          SizedBox(width: tokens.spaceSm),
          // The `Expanded` is the fix. Without it the label takes its natural
          // width, the row cannot shrink, and the popup paints an overflow
          // stripe through any label wider than the menu.
          Expanded(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
              style: TextStyle(color: foreground),
            ),
          ),
          if (trailing != null) ...[
            SizedBox(width: tokens.spaceSm),
            trailing!,
          ],
        ],
      ),
    );
  }
}

/// A menu section break that indents to the label column rather than running
/// edge to edge.
///
/// Material's `PopupMenuDivider` draws a full-bleed rule, which in a menu whose
/// rows all carry an icon reads as a divider between the window and the menu
/// rather than as a divider between two groups of actions.
class MoonrelayMenuDivider extends PopupMenuDivider {
  const MoonrelayMenuDivider({super.key}) : super(height: 9);
}

/// Builds the standard popup-menu geometry for this app.
///
/// [showMenu]'s default of `maxWidth: 280` is the constraint that caused the
/// overflow, and simply raising it is not enough on its own: the row still has
/// to cope. This gives a roomier menu for the long labels the chat surface has
/// while leaving [MoonrelayMenuItem] responsible for the case where even this
/// is too narrow.
BoxConstraints moonrelayMenuConstraints() =>
    const BoxConstraints(minWidth: 180, maxWidth: 340);
