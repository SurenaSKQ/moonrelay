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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/settings/chat_preferences.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// The one set of measurements every sidebar row uses.
///
/// Four row types used to carry four independent sets: navigation rows and
/// group rows padded with `spaceMd`/`spaceSm` and no corner radius, space
/// rows padded with a hard-coded `10`/`6` *and* a radius, and room rows
/// padded with a density-dependent horizontal inset. None of them agreed, so
/// the pane read as four widgets stacked rather than as one list.
///
/// [forDensity] is the only place these numbers are written down.
@immutable
class SidebarRowMetrics {
  const SidebarRowMetrics({
    required this.minHeight,
    required this.padH,
    required this.padV,
    required this.gap,
    required this.leadingSize,
    required this.titleSize,
    required this.subtitleSize,
  });

  /// Comfortable is the default, and it is deliberately roomy.
  ///
  /// The first version of this type had 13pt titles and a 12pt compact, so
  /// the setting moved the type by one point and the default read small
  /// against the window's own chrome. Both numbers are up: a one point
  /// range is not a density choice, it is a rounding error, and a sidebar
  /// is the densest reading surface in the app and deserves type you can
  /// read without leaning in.
  factory SidebarRowMetrics.forDensity(LayoutDensity density) =>
      switch (density) {
        LayoutDensity.comfortable => const SidebarRowMetrics(
            minHeight: 44,
            padH: 14,
            padV: 7,
            gap: 12,
            leadingSize: 34,
            titleSize: 15,
            subtitleSize: 12.5,
          ),
        LayoutDensity.compact => const SidebarRowMetrics(
            minHeight: 34,
            padH: 12,
            padV: 4,
            gap: 10,
            leadingSize: 26,
            titleSize: 13,
            subtitleSize: 11,
          ),
      };

  /// Floor for the row, so a row with only a title and a room row with a
  /// title and a preview line up on the same rhythm.
  final double minHeight;

  final double padH;
  final double padV;

  /// Space between the leading slot and the text.
  final double gap;

  /// Diameter the leading slot is constrained to, so an icon and an avatar
  /// are centred on the same axis.
  final double leadingSize;

  final double titleSize;
  final double subtitleSize;
}

/// Identifies the accent bar [SidebarRow] draws on its leading edge when
/// selected.
///
/// The bar is a `PositionedDirectional` over the row's leading gutter, which
/// puts it outside the subtree a `find.descendant` over the label would
/// reach, so the test needs a key to ask whether it is there at all.
///
/// Named in the plural sense of "the bar for this row", which is why it
/// carries no room or index: each row owns exactly one, and the list gives
/// every row its own instance.
const Key sidebarRowAccentBarKey = ValueKey('sidebar-row-accent-bar');

/// One row in a sidebar list.
///
/// Used by the navigation destinations, the space tree, space groups and
/// the room list, so that all four share padding, corner radius, type
/// scale and selected treatment.
///
/// Density comes from the user's [LayoutDensity] setting rather than from
/// the pane's width. It used to come from the width, in `_RoomRow` only,
/// against a 260px threshold: a default 300px sidebar therefore rendered
/// room names at 18pt while the space rows above them were 13pt, and the
/// "Interface density" control changed nothing in this pane at all because
/// it only reached the theme's `visualDensity`.
class SidebarRow extends StatelessWidget {
  const SidebarRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.titleSuffix,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.indent = 0,
    this.metrics,
  });

  /// Single-line label. [title] may be a widget when the caller needs a
  /// richer line (a group row puts a count badge beside it).
  final String title;

  /// Optional second line. Omit for rows that are one line tall.
  final String? subtitle;

  /// Sits at the end of the title line, inside the space the title shares,
  /// so it is consumed by the ellipsis when the name is long.
  ///
  /// Distinct from [trailing], which is pinned to the far edge. The
  /// encryption badge belongs here and not there: it is a property of the
  /// room's name, and pinning it opposite the unread count would put the
  /// two pieces of information a user scans for on opposite sides of the
  /// row.
  final Widget? titleSuffix;

  /// Icon or avatar. Sized and centred by this widget, so callers should
  /// not impose their own box.
  final Widget? leading;

  /// Badges, chevrons, counts. Laid out after the text at its natural
  /// size.
  final Widget? trailing;

  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Extra inset for a nested row, so a space inside a group is visibly
  /// inside it.
  final double indent;

  /// Overrides the density-derived metrics. Rarely needed; [SidebarRow] is
  /// the only caller in practice.
  final SidebarRowMetrics? metrics;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;

    // `select` rather than `watch`: a room list can be a few hundred rows
    // and this way only a density change rebuilds them, not every unrelated
    // settings write.
    final density = context.select<SettingsController, LayoutDensity>(
      (s) => s.density,
    );
    final m = metrics ?? SidebarRowMetrics.forDensity(density);

    final radius = BorderRadius.circular(t.radiusSm);
// The selected row's text stays `onSurface`, not the accent. The leading
  // bar already says "this one"; making the label the accent too meant two
  // signals competing, and it changed the row's colour with the accent seed,
  // so switching to a blue accent recoloured the whole room list.
  final foreground = scheme.onSurface;
  final muted =
      selected ? scheme.onSurfaceVariant : scheme.onSurfaceVariant;

    Widget titleLine() {
      final label = Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: m.titleSize,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
          color: foreground,
        ),
      );
      if (titleSuffix == null) return label;
      return Row(
        children: [
          Expanded(child: label),
          SizedBox(width: t.spaceSm),
          titleSuffix!,
        ],
      );
    }

    Widget text() {
      if (subtitle == null) return titleLine();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          titleLine(),
          SizedBox(height: t.spaceXxs),
          Text(
            subtitle!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: m.subtitleSize,
              fontWeight: FontWeight.w400,
              color: muted,
            ),
          ),
        ],
      );
    }

    return Material(
      // A step from the surface ramp, not an accent wash. The room list sits
      // at `surfaceContainer`, so `active` is the next step up: the selected
      // row reads as nearer to the user rather than as tinted, and it does not
      // change colour with the accent, so a blue accent no longer turns the
      // whole list blue.
      color: selected ? ext.layers.active : Colors.transparent,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: radius,
        child: Stack(
          children: [
            // The accent bar. The fill alone is not enough to find the
            // current room in a list of two hundred, because a row that is
            // merely *near* it, or hovered, or mid-transition, all read the
            // same. A bar on the leading edge is a position, not a colour, so
            // the eye can find it without comparing shades.
            //
            // Width rather than opacity, so it cannot wash out against the
            // row behind it.
            if (selected)
              PositionedDirectional(
                key: sidebarRowAccentBarKey,
                start: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: t.borderWidthThick * 2,
                  color: scheme.primary,
                ),
              ),
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: m.minHeight),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  // Nothing here accounts for the bar. The bar is 3px wide
                  // and sits at start: 0 of the Stack, so it draws over the
                  // row's own leading gutter: padH is 12 or 14, always wider
                  // than the bar, and the label never reaches it.
                  //
                  // Adding the bar's width to this padding, which is what
                  // used to happen, shifted the label and the avatar 3px
                  // right on every selected row, so moving the selection
                  // reflowed the list under the pointer. Worse, it was the
                  // kind of shift that reads as intentional until you
                  // click a second row and watch the first one jump back.
                  m.padH + indent,
                  m.padV,
                  m.padH,
                  m.padV,
                ),
                child: Row(
                  children: [
                    if (leading != null) ...[
                      SizedBox(
                        width: m.leadingSize,
                        height: m.leadingSize,
                        child: Center(child: leading),
                      ),
                      SizedBox(width: m.gap),
                    ],
                    Expanded(child: text()),
                    if (trailing != null) ...[
                      SizedBox(width: t.spaceSm),
                      trailing!,
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Resolves the metrics a row should use at [context].
///
/// For callers that are not [SidebarRow] but still need to agree with it,
/// such as a drag feedback or a hover preview that has to be the same size
/// as the row it replaces.
SidebarRowMetrics sidebarMetricsFor(
  BuildContext context, {
  SidebarRowMetrics? override,
}) =>
    override ??
    SidebarRowMetrics.forDensity(
      context.read<SettingsController>().density,
    );
