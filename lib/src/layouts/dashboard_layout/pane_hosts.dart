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
import 'package:provider/provider.dart';

import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

import 'right_sidebar_content.dart';

// --- Resize handle ---------------------------------------------------------

/// A draggable resize handle between panes.
class ResizeHandle extends StatelessWidget {
  final void Function(double delta) onDrag;
  final VoidCallback? onDragEnd;

  const ResizeHandle({
    super.key,
    required this.onDrag,
    this.onDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Wider hit target (8px) so the handle is easier to grab on small panes,
    // with a subtle always-visible track.
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (details) => onDrag(details.delta.dx),
        onHorizontalDragEnd: (_) => onDragEnd?.call(),
        child: Container(
          width: 8,
          color: Colors.transparent,
          alignment: Alignment.center,
          child: Container(
            width: 1,
            color: scheme.outlineVariant,
          ),
        ),
      ),
    );
  }
}

// --- Sidebar pane ----------------------------------------------------------

/// A sidebar pane with a header, scrollable body, and optional bottom bar.
class SidebarPane extends StatelessWidget {
  final double width;
  final double minWidth;
  final String title;
  final Widget body;
  final Widget? bottomBar;
  final ThemeData theme;

  /// The pane's own fill.
  ///
  /// Optional because the pane previously had none and inherited whatever
  /// was behind it, which is how the right detail pane ended up looking like
  /// part of the conversation rather than like a panel beside it.
  final Color? background;

  const SidebarPane({
    super.key,
    required this.width,
    required this.minWidth,
    required this.title,
    required this.body,
    this.bottomBar,
    required this.theme,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final ext = MoonrelayThemeExtension.fromTheme(theme);
    final tokens = ext.tokens;
    final layers = ext.layers;

    return SizedBox(
      width: width.clamp(minWidth, double.infinity),
      child: ColoredBox(
        color: background ?? Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Simple header bar; skipped when there is no title so panes
          // that render their own header (e.g. the right sidebar's view
          // switcher) do not show a redundant empty strip.
          if (title.isNotEmpty) ...[
            Container(
              color: theme.colorScheme.surfaceContainer,
              padding: EdgeInsets.symmetric(
                horizontal: tokens.spaceMd,
                vertical: tokens.spaceSm,
              ),
              child: Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Divider(height: tokens.borderWidthThin, color: layers.hairline),
          ],
          Expanded(child: body),
          if (bottomBar != null) ...[
            Divider(height: tokens.borderWidthThin, color: layers.hairline),
            bottomBar!,
          ],
          ],
        ),
      ),
    );
  }
}

// --- Right pane host -------------------------------------------------------

/// Hosts the right side pane (room info, members, threads, pinned).
class RightPaneHost extends StatelessWidget {
  const RightPaneHost({
    super.key,
    required this.widthNotifier,
    required this.theme,
  });

  final ValueNotifier<double?> widthNotifier;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    // The detail pane is a step *below* the conversation, not on it.  It
    // used to have no background at all and inherited the main pane's, so
    // the only thing separating it from the messages was a one-pixel rule.
    // That made the conversation and its own detail panel look like one wide
    // surface with a line through it.
    return ListenableBuilder(
      listenable: widthNotifier,
      builder: (context, _) {
        return SidebarPane(
          width: widthNotifier.value ?? settings.rightSidebarWidth,
          minWidth: LayoutBreakpoints.minSidebarWidth,
          title: '',
          body: const RightSidebarContent(),
          bottomBar: null,
          theme: theme,
          background: theme.colorScheme.surfaceContainer,
        );
      },
    );
  }
}
