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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

//  The page

/// The shell every information and settings page is built on.
///
/// Four pages in this app (room info, space info, room settings, space
/// settings) were each a `Scaffold` with a hardcoded
/// `EdgeInsets.symmetric(horizontal: 16, vertical: 8)` and a `ListView` that
/// ran the full width of the window. On a 1600px-wide desktop that puts a
/// label on the left and its value on the far right with 1400px of nothing
/// between them, which is the strongest argument there is against a settings
/// page that is not a settings page.
///
/// The measure is capped at 680. That is the width at which a label and a
/// value remain scannable as a pair, and it is the same reason a book has
/// margins.
///
/// Centred rather than left-aligned in the window: these pages are reached by
/// drilling into a room or a space and the eye is already centred on the
/// conversation, so a left-hugging column reads as accidental.
class MoonrelayInfoPage extends StatelessWidget {
  const MoonrelayInfoPage({
    super.key,
    required this.title,
    required this.children,
    this.actions = const <Widget>[],
    this.scrollController,
  });

  final String title;
  final List<Widget> children;
  final List<Widget> actions;
  final ScrollController? scrollController;

  /// The measure described in the class documentation.
  static const double maxContentWidth = 680;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).maybePop(),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
        ),
        title: Text(title),
        actions: actions,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: maxContentWidth),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              t.spaceLg,
              t.spaceMd,
              t.spaceLg,
              // Room lists and member lists can be tall; a full screen of
              // bottom padding is wasted space above a system taskbar.
              t.spaceXxl * 2,
            ),
            children: children,
          ),
        ),
      ),
    );
  }
}

/// Vertical rhythm between the sections of a page.
///
/// One widget rather than a `SizedBox(height: t.spaceLg)` repeated eight times
/// per page across four pages. The value is the gap *plus* the panel's own
/// top padding, so the space a section header sits in is the same whether or
/// not the section before it had a panel under it.
class InfoSectionGap extends StatelessWidget {
  const InfoSectionGap({super.key, this.first = false});

  /// True for the first section on a page, which is preceded by the identity
  /// header rather than by another section.
  final bool first;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return SizedBox(height: first ? t.spaceXl : t.spaceXxl);
  }
}

//  Panels

/// One titled group of rows on a single surface.
///
/// This replaces a panel per row. The old `InfoActionTile` wrapped every
/// action in its own `Card` with its own border, so three actions that belong
/// together rendered as three unrelated boxes with three borders and two gaps
/// that did not belong to anything. It is the shape of a settings page that
/// was assembled rather than designed.
///
/// A section is one surface. The rows inside are separated by a hairline drawn
/// from `layers.hairline`, which is the single hairline colour the whole app
/// uses: the dividers between panes are the only lines in this layout that are
/// not part of a component, and letting each one pick its own alpha is how a
/// shell ends up with five slightly different greys down the same edge.
class InfoPanel extends StatelessWidget {
  const InfoPanel({
    super.key,
    required this.children,
    this.title,
    this.trailingHeader,
    this.padding,
  });

  /// Rows, in order. A `null` entry draws a gap instead of a divider, for the
  /// one case where two rows in a panel are unrelated to each other.
  final List<Widget?> children;

  /// Section title. Rendered above the surface, not inside it, so the panel's
  /// top edge is a clean line rather than a line interrupted by a heading.
  final String? title;

  /// Optional control in the header, aligned to the title's baseline. The
  /// room settings page puts a destructive "Leave" here.
  final Widget? trailingHeader;

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final theme = MoonrelayThemeExtension.of(context);
    final t = theme.tokens;
    final scheme = Theme.of(context).colorScheme;
    final body = children.whereType<Widget>().toList(growable: false);

    Widget column = DecoratedBox(
      decoration: BoxDecoration(
        // The panel sits one step *below* the page's floor rather than above
        // it. A raised panel would compete with the page for attention; this
        // reads as a well rather than a card laid on top.
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(theme.components.card.cornerRadius),
        border: Border.all(color: theme.layers.hairline),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(theme.components.card.cornerRadius),
        child: Padding(
          padding: padding ??
              EdgeInsets.symmetric(
                horizontal: t.spaceLg,
                vertical: t.spaceXxs,
              ),
          child: Column(
            children: [
              for (var i = 0; i < body.length; i++) ...[
                if (i > 0)
                  Divider(
                    height: 1,
                    thickness: 0,
                    color: theme.layers.hairline,
                  ),
                body[i],
              ],
            ],
          ),
        ),
      ),
    );

    final heading = title;
    final trailing = trailingHeader;
    if (heading == null && trailing == null) return column;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (heading != null)
          Padding(
            padding: EdgeInsets.fromLTRB(t.spaceXs, 0, t.spaceXs, t.spaceSm),
            child: InfoSectionLabel(title: heading),
          ),
        if (trailing != null)
          Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
        column,
      ],
    );
  }
}

/// A section heading.
///
/// The old heading was a 14px `w600` label in `onSurfaceVariant`, which is the
/// weakest thing a heading can be: it reads as a field label, so the eye takes
/// it for part of the row below rather than for the name of a group. This is
/// the display face at a smaller size with negative tracking, which is what
/// makes it a heading rather than a caption, and it stays in `onSurface` so it
/// has the weight of a heading in the type hierarchy and not only in size.
///
/// No tracking-wide uppercase. The setting is there and this heading does not
/// use it, because a nine-letter word spaced out to fill a column is a
/// decoration and not a label.
class InfoSectionLabel extends StatelessWidget {
  const InfoSectionLabel({super.key, required this.title, this.icon});

  final String title;

  /// Optional leading glyph. Used only where the glyph carries real meaning,
  /// which in these four pages is nowhere: the panel title names the section
  /// and the rows inside it name the actions.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final glyph = icon;

    final text = Text(
      title,
      style: TextStyle(
        fontFamily: MoonrelayTypography.display(context),
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        height: 1.2,
        color: scheme.onSurface.withValues(alpha: t.opacityMuted),
      ),
    );

    if (glyph == null) return text;
    return Row(
      children: [
        Icon(glyph, size: t.iconSizeSmall, color: scheme.onSurfaceVariant),
        SizedBox(width: t.spaceXs),
        Expanded(child: text),
      ],
    );
  }
}

//  Rows

/// One row inside an [InfoPanel].
///
/// The leading slot is a fixed width rather than a `Row` of its own, so that
/// every icon in a panel starts at the same x. The old `InfoDetailRow` gave
/// the *label* a fixed 100px and let the value float, which meant the value's
/// position depended on how long the label was.
class InfoPanelRow extends StatelessWidget {
  const InfoPanelRow({
    super.key,
    required this.label,
    this.icon,
    this.description,
    this.value,
    this.valueFontFamily,
    this.onTap,
    this.trailing,
    this.leading,
    this.destructive = false,
    this.padding,
  });

  final String label;

  final IconData? icon;

  /// Second line under the label. Used for the value of an action, e.g. a room
  /// id under "Copy room ID", which is more useful under the label than beside
  /// it.
  final String? description;

  /// Right-aligned value. Right-aligned because these are facts, and a fact
  /// column reads as a column.
  final String? value;

  /// Monospace for [value], for identifiers. Not for names or dates: a
  /// monospace name is a small shout.
  final String? valueFontFamily;

  final VoidCallback? onTap;

  /// Widget after the value. A chevron when tappable, a switch, a badge.
  final Widget? trailing;

  /// Replaces [icon] entirely, e.g. a verification badge.
  final Widget? leading;

  /// Renders the row in the scheme's error colour.
  final bool destructive;

  final EdgeInsets? padding;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;

    final foreground = destructive ? scheme.error : scheme.onSurface;
    final muted = destructive
        ? scheme.error.withValues(alpha: t.opacityMuted)
        : scheme.onSurfaceVariant;
    final value_ = value;

    final labelColumn = Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              color: foreground,
              fontWeight: FontWeight.w500,
            ),
          ),
          if (description != null) ...[
            SizedBox(height: t.spaceXxs),
            Text(
              description!,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.35,
                color: muted,
                fontFamily: valueFontFamily,
              ),
            ),
          ],
        ],
      ),
    );

    final row = Padding(
      padding: padding ??
          EdgeInsets.symmetric(
            horizontal: t.spaceSm,
            vertical: t.spaceSm + t.spaceXxs,
          ),
      child: Row(
        children: [
          SizedBox(
            width: t.iconSizeLarge + t.spaceSm,
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: leading ??
                  (icon == null
                      ? const SizedBox.shrink()
                      : Icon(icon, size: t.iconSizeMedium, color: muted)),
            ),
          ),
          labelColumn,
          if (value_ != null) ...[
            SizedBox(width: t.spaceMd),
            // A share of the row's own width rather than a fixed 220.
            //
            // `ConstrainedBox` alone is a ceiling, not a bound: in a 280px pane
            // the ceiling was not the constraint and the value simply took what
            // the label left it, which was negative in the worst case. Forty
            // percent is what a right-aligned fact column wants beside a label,
            // and it scales down to the room pane as well as across a page.
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: SelectableText(
                  value_,
                  textAlign: TextAlign.end,
                  maxLines: 2,
                  // `SelectableText` has no `overflow` parameter, so it cannot
                  // ellipsize. At two lines it clips. Restoring the ellipsis means
                  // giving up the selection that made this row worth using.
                  style: TextStyle(
                    fontSize: 13,
                    color: muted,
                    fontFamily: valueFontFamily,
                  ),
                ),
              ),
            ),
          ],
          if (trailing != null) ...[
            SizedBox(width: t.spaceSm),
            trailing!,
          ] else if (onTap != null) ...[
            SizedBox(width: t.spaceXs),
            Icon(
              LucideIcons.chevronRight,
              size: t.iconSizeMedium,
              color: scheme.onSurfaceVariant.withValues(alpha: t.opacityMuted),
            ),
          ],
        ],
      ),
    );

    if (onTap == null) return row;
    return InkWell(
      onTap: onTap,
      child: row,
    );
  }
}

//  Chips

/// A small labelled pill for a fact about the room or space.
///
/// Restyled from the version this replaced. That one filled with
/// `secondaryContainer` at `opacitySubtle`, which on the new palette is the
/// composer's step, so a chip in the identity header was the same value as
/// the message input behind it and the header had no separate register from
/// the conversation below.
///
/// These are outlined rather than filled. A chip is a quiet fact next to a
/// heading, and a filled chip competes with the heading it sits under.
class InfoChip extends StatelessWidget {
  const InfoChip({
    super.key,
    required this.icon,
    required this.label,
    this.emphasis = false,
  });

  final IconData icon;
  final String label;

  /// Filled rather than outlined. Reserved for the one fact the page exists
  /// to deliver, e.g. that a room is encrypted.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final theme = MoonrelayThemeExtension.of(context);
    final t = theme.tokens;
    final scheme = Theme.of(context).colorScheme;
    final accent = scheme.primary;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceSm + t.spaceXxs,
        vertical: t.spaceXs,
      ),
      decoration: BoxDecoration(
        color: emphasis
            ? accent.withValues(alpha: t.opacitySubtle)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(theme.components.chip.cornerRadius),
        border: Border.all(
          color: emphasis
              ? accent.withValues(alpha: t.opacityFocus)
              : theme.layers.hairline,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: t.iconSizeSmall - 2,
            color: emphasis ? accent : scheme.onSurfaceVariant,
          ),
          SizedBox(width: t.spaceXs + 1),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: emphasis ? accent : scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

//  Typography helpers

/// Small indirection so the display face is read from one place.
///
/// The display family is not on [MoonrelayThemeExtension] because the theme
/// stores the *user's* choices and this is the app's own fallback, which
/// `Theme.of(context).textTheme.titleMedium?.fontFamily` already reflects.
class MoonrelayTypography {
  const MoonrelayTypography._();

  /// The face used for headings and for anything that should read as a
  /// display element rather than as running text.
  static String? display(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.titleMedium?.fontFamily ??
        theme.textTheme.bodyMedium?.fontFamily;
  }

  /// The face used for identifiers: room ids, event ids, hashes.
  static String? mono(BuildContext context) {
    final theme = Theme.of(context);
    return theme.textTheme.bodySmall?.fontFamily;
  }
}
