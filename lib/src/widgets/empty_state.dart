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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// A centred, self-contained empty/error state for a content pane.
///
/// Used for the two cases the route layer deliberately does not treat as
/// errors: no room is selected yet (`RoomsListRoute`) and a route id that is
/// genuinely invalid (`ProfileView`).
///
/// The state is a plain message with an icon; pass [actionLabel] and
/// [onAction] to offer a single recovery affordance (e.g. "Back" or
/// "Preview room").
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  /// Icon shown above the title.
  final IconData icon;

  /// Short, prominent heading.
  final String title;

  /// Secondary explanatory text.
  final String message;

  /// Label for the optional recovery button. When null no button is shown.
  final String? actionLabel;

  /// Handler wired to [actionLabel].
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 40,
              color: scheme.onSurfaceVariant.withValues(alpha: t.opacityDisabled),
            ),
            SizedBox(height: t.spaceLg),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: t.spaceSm),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
if (actionLabel != null && onAction != null) ...[
              SizedBox(height: t.spaceXl),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(LucideIcons.arrowLeft, size: 16),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A centred loading state for a content pane, optionally labelled.
///
/// The counterpart to [EmptyState], and it exists because there was no
/// shared equivalent. Every pane hand-rolled its own
/// `Center(child: CircularProgressIndicator())`, which is why the loading
/// experience was ad hoc: roughly half the sites paired the spinner with a
/// line of text and the rest did not, so some panes announced themselves and
/// some just sat there spinning.
///
/// A spinner on its own is not wrong, but a pane whose whole content is a
/// bare circle gives the eye nothing to hold while it waits. Pass [label]
/// wherever the pane is wide enough for one.
class PaneLoading extends StatelessWidget {
  const PaneLoading({super.key, this.label});

  /// Optional line of text under the spinner, naming what is loading.
  ///
  /// Should already be localised by the caller.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final text = label;
    if (text == null) {
      return Center(
        child: SizedBox(
          width: t.spaceXl,
          height: t.spaceXl,
          child: CircularProgressIndicator(
            strokeWidth: t.borderWidthThick,
            color: scheme.primary,
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: EdgeInsets.all(t.spaceXl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: t.spaceXl,
              height: t.spaceXl,
              child: CircularProgressIndicator(
                strokeWidth: t.borderWidthThick,
                color: scheme.primary,
              ),
            ),
            SizedBox(height: t.spaceLg),
            Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
