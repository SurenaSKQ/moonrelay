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
// Sub-page header wrapper
// -----------------------------------------------------------------------------

/// A titled strip above a section's body, with optional trailing actions.
///
/// The [Expanded] is why every section body has to be scrollable or
/// fillable. It is not decoration: it is what stops a short body from
/// stretching and a long one from overflowing, and it is the constraint
/// that `EncryptionOverviewScreen(embedded: true)` exists to satisfy.
///
/// [actions] is how a body that cannot supply its own `AppBar` still gets
/// its controls. The encryption page is the case that matters: it is the
/// only section with a refresh, and while it was embedded the only way to
/// pick up a change made on another device was to leave the hub and open
/// `/main/encryption` instead.
class HubSubPageHeader extends StatelessWidget {
  final String title;
  final Widget child;
  final List<Widget> actions;

  const HubSubPageHeader({
    super.key,
    required this.title,
    required this.child,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ext = theme.moonrelay;
    final t = ext.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          // `surfaceContainerHigh`, the same step the content pane sits on.
          // It was `surfaceContainerHighest`, which is the hover step: a
          // title bar painted in the hover colour reads as a hovered element,
          // and it was the only place in the app that used that value for
          // something other than a hover.
          color: theme.colorScheme.surfaceContainerHigh,
          padding: EdgeInsets.symmetric(
            horizontal: t.spaceLg + t.spaceXs,
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    // `onSurface`, not `onSurfaceVariant`. This is the page's
                    // own title, eleven pixels above the content it heads;
                    // muted it read as a caption for the strip below.
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              ...actions,
            ],
          ),
        ),
        Divider(height: 1, color: ext.layers.hairline),
        Expanded(child: child),
      ],
    );
  }
}
