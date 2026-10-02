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

import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// -----------------------------------------------------------------------------
// Settings section helper
// -----------------------------------------------------------------------------

/// A reusable section for grouping related settings controls.
///
/// The card is [surfaceContainer] on a pane at [surfaceContainerHigh], which
/// puts it one step below its own surroundings rather than the same step with
/// a hairline around it. A border on the same value as the background is a
/// line that says "edge of something" without saying what is on either side;
/// a step says it by itself. The hairline stays as a definition of the
/// section's own extent, at the app's one hairline value rather than
/// `theme.dividerColor`, which was the second grey in the app.
///
/// Every settings page uses this, so this is where the hub's look is actually
/// decided. Thirteen pages each drawing their own card is thirteen chances to
/// drift.
class HubSettingsSection extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const HubSettingsSection({
    super.key,
    required this.title,
    this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final scheme = theme.colorScheme;
    final text = theme.textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: text.titleSmall?.copyWith(
            // `labelMedium`, not `primary`. The accent on every section
            // heading made the settings page read as a list of links rather
            // than as a set of groups, and it was the single loudest thing on
            // the page.
            color: scheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (subtitle != null)
          Padding(
            padding: EdgeInsets.only(top: t.spaceXxs),
            child: Text(
              subtitle!,
              style: text.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        SizedBox(height: t.spaceSm),
        // `Card`, not a `Container` with a decoration, and that is load
        // bearing rather than incidental. These sections hold `ListTile`s, and
        // a `ListTile` paints its background and its ink splashes on the
        // nearest `Material` ancestor. A decorated `Container` is not a
        // `Material`, so the card's fill would sit on top of every ripple and
        // every selection wash, and Flutter asserts about it in debug. `Card`
        // *is* a `Material`, which is why the original code used it here and
        // why the container rewrite had to be undone.
        Card(
          elevation: t.elevationNone,
          // One step below the pane, so the card reads as recessed rather
          // than as a border drawn around the same value as its background.
          color: scheme.surfaceContainer,
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(t.radiusMd),
            side: BorderSide(color: ext.layers.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}
