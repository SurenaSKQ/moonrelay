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
/// Used for the cases the route layer deliberately does not treat as errors:
/// a route id that is genuinely invalid (`ProfileView`), a filter that matched
/// nothing, and the seven other sites listed below.
///
/// The icon sits in a raised tile rather than floating bare. A 40px glyph
/// against a full pane of flat surface has no edge and no weight, so it reads
/// as an ornament rather than as the thing you are meant to look at; a tile
/// gives it an edge, a fill a step above the pane, and somewhere for the
/// shadow to land.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.iconColor,
  });

  /// Icon shown in the tile above the title.
  final IconData icon;

  /// Short, prominent heading.
  final String title;

  /// Secondary explanatory text.
  final String message;

  /// Label for the optional recovery button. When null no button is shown.
  final String? actionLabel;

  /// Handler wired to [actionLabel].
  final VoidCallback? onAction;

  /// Tile fill for the icon. Defaults to the pane's raised surface; pass a
  /// semantic colour where the state has one, such as the no-match state.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final text = theme.textTheme;

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(t.spaceXl),
        child: ConstrainedBox(
          // Caps the measure so the copy does not run the full width of an
          // expanded pane, which at that size is a fifteen-hundred-pixel line
          // of centred text.
          constraints: const BoxConstraints(maxWidth: 380),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EmptyIconTile(
                icon: icon,
                color: iconColor,
              ),
              SizedBox(height: t.spaceXl),
              Text(
                title,
                style: text.headlineSmall?.copyWith(color: scheme.onSurface),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: t.spaceSm),
              Text(
                message,
                style: text.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.5,
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
      ),
    );
  }
}

/// The raised tile an [EmptyState]'s icon sits in.
class _EmptyIconTile extends StatelessWidget {
  const _EmptyIconTile({
    required this.icon,
    required this.color,
  });

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;
    final fill = color ?? scheme.surfaceContainerHigh;

    return Container(
      width: t.spaceXxxl * 1.75,
      height: t.spaceXxxl * 1.75,
      decoration: BoxDecoration(
        color: fill,
        // Twenty-four on a seventy-two box. Enough to read as a rounded
        // square rather than a circle, which keeps it from competing with the
        // circular avatars elsewhere in the shell.
        borderRadius: BorderRadius.circular(t.radiusXl),
        boxShadow: t.shadowMedium,
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        size: t.spaceXxl,
        color: color != null
            ? scheme.onErrorContainer
            : scheme.onSurfaceVariant.withValues(alpha: t.opacitySubtle),
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
