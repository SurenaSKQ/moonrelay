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

// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:window_manager/window_manager.dart';
import 'package:moonrelay/src/helpers/platform.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/command_palette/command_palette.dart';
import 'package:moonrelay/src/widgets/menu_row.dart';
import 'package:moonrelay/src/widgets/window_buttons.dart';

/// The window's own title bar: drag area, app name, global search, caption
/// buttons, and the right-click system menu.
///
/// Drawn by the app rather than the OS, and there is no longer a setting to
/// hand that back. It used to be `useOsTitleBar`, defaulting to the OS bar,
/// and the custom bar was opt-in. That put the app's chrome in two places at
/// once and left the layout worse in the default case: with the OS bar shown,
/// the window gave up about thirty vertical pixels to draw a title and three
/// buttons, and everything the app wanted to put in a title bar had nowhere
/// to go.
///
/// ## Why the search lives here
///
/// Global search used to be a full-width row inside the navigation sidebar,
/// under a heading, above the room list. That is a poor home for it on three
/// counts. It is not a destination, so drawing it as one made it look like
/// somewhere you go; it is not about the rooms in that pane, so sitting above
/// them implied it filtered them; and it spent a row of height in the pane
/// that has the least to spare, on the axis the user reads least.
///
/// A title bar is where window-level actions belong. Putting search here costs
/// the layout nothing, makes it reachable from every screen including the ones
/// with no sidebar, and lets the room pane start with its destination name
/// instead of a heading and a row of controls.
///
/// ## The drag area
///
/// The left of the bar is a [DragToMoveArea] so the window can be moved by
/// holding it, which is what makes a frameless window feel like a window. The
/// search control sits deliberately *outside* that area: a button inside a drag
/// target swallows its own clicks, and a drag target that swallows clicks is
/// how a search button ends up working only on the second try.
class WindowTitleBar extends StatelessWidget {
  const WindowTitleBar({
    super.key,
    this.showSearch = false,
    this.closeWindow,
  });

  /// Height of the bar.
  ///
  /// It was kToolbarHeight (56) to match Material's toolbar, on the argument
  /// that a bar matching the platform's does not read as a strip someone added
  /// to a window that already had one. That argument is now made by the whole
  /// shell agreeing on one number instead: the navigation header, the room
  /// header and the composer all read [MoonrelayDesignTokens.paneBarHeight], so
  /// a window whose title bar is a different height from the panes under it
  /// would read as the strip, and a window where they all agree does not.
  ///
  /// A static getter rather than a constant, because the value now lives in the
  /// theme. Every caller is inside a uild with a context, so this is free.
  static double height(BuildContext context) =>
      MoonrelayThemeExtension.of(context).tokens.paneBarHeight;

  /// Whether to render the global search control.
  ///
  /// Off on the start screen: there is nothing to search before the user is
  /// signed in, and a search field that opens an empty palette is a dead
  /// control with a real-looking border.
  final bool showSearch;

  /// What "Close" does in the right-click menu.
  ///
  /// Defaults to closing the window. The signed-in frame passes a handler that
  /// honours `closeToTray`, which is a per-account preference and so is not
  /// something the shared bar can decide on its own.
  final Future<void> Function()? closeWindow;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final t = theme.moonrelay.tokens;

    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if (event.kind == PointerDeviceKind.mouse &&
            (event.buttons & 0x02) != 0) {
          showWindowContextMenu(
            context,
            event.position,
            closeWindow: closeWindow,
          );
        }
      },
      child: Container(
        height: height(context),
        color: theme.colorScheme.surface,
        child: Row(
          children: [
            // -- Draggable title area ----------------------------
            Expanded(
              child: DragToMoveArea(
                child: SizedBox(
                  height: double.infinity,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(start: 16),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        l10n.appTitle,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            if (showSearch) ...[
              SizedBox(width: t.spaceSm),
              const GlobalSearchControl(),
              SizedBox(width: t.spaceSm),
            ],

            // -- Trailing slot: window controls ------------------
            if (isDesktop)
              const WindowButtons()
            else
              SizedBox(width: t.spaceXs),
          ],
        ),
      ),
    );
  }
}

/// The title bar's global search control.
///
/// Shaped like the recessed fields elsewhere in the app rather than as a bare
/// icon, because it is a target with a label rather than a command, and a user
/// who has not seen the shortcut is looking for something that says "search".
/// It shows the shortcut as a hint for the people who already know it.
class GlobalSearchControl extends StatelessWidget {
  const GlobalSearchControl({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.moonrelay.tokens;
    final scheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Tooltip(
      message: l10n.commandPalette,
      excludeFromSemantics: true,
      child: Semantics(
        container: true,
        button: true,
        label: l10n.commandPalette,
        child: InkResponse(
          onTap: () => showCommandPalette(context),
          radius: 20,
          child: Container(
            width: 260,
            height: 30,
            padding: EdgeInsets.symmetric(horizontal: t.spaceSm),
            decoration: BoxDecoration(
              // One step below the bar, so the control reads as a field sitting
              // on the chrome rather than as part of the chrome.
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(t.radiusSm),
              border: Border.all(color: theme.moonrelay.layers.hairline),
            ),
            child: Row(
              children: [
                Icon(
                  LucideIcons.search,
                  size: t.iconSizeSmall,
                  color: scheme.onSurfaceVariant,
                ),
                SizedBox(width: t.spaceXs),
                Expanded(
                  child: Text(
                    l10n.search,
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // The shortcut, not a button. It is a hint: the whole control
                // is the button, and a chip inside a button that looks like a
                // second thing to press is one too many.
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: t.spaceXs,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(t.radiusXs),
                  ),
                  child: Text(
                    'Ctrl K',
                    style: TextStyle(
                      fontFamily: theme.moonrelay.monoFontFamily,
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The right-click system menu on the title bar.
///
/// Shared by both frames so the two cannot drift. The only thing they
/// disagree about is what "Close" does, which is a tray preference the start
/// screen has no account to hide behind, and that is the [closeWindow] hook.
Future<void> showWindowContextMenu(
  BuildContext context,
  Offset globalPosition, {
  Future<void> Function()? closeWindow,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final isMaxed = await windowManager.isMaximized();
  if (!context.mounted) return;

  final items = <PopupMenuEntry<String>>[
    MoonrelayMenuItem<String>(
      value: 'minimize',
      icon: LucideIcons.minus,
      label: l10n.minimize,
    ),
    MoonrelayMenuItem<String>(
      value: 'maximize',
      // Restore and maximize are the same action on different windows, so
      // the label already distinguishes them. The icon used to be
      // `Icons.check_box_outline_blank`, which reads as an unchecked
      // checkbox and is not a window glyph in any desktop convention.
      icon: LucideIcons.copy,
      label: isMaxed ? l10n.restore : l10n.maximize,
    ),
    MoonrelayMenuItem<String>(
      value: 'close',
      icon: LucideIcons.x,
      label: l10n.closeWindow,
    ),
    const MoonrelayMenuDivider(),
    MoonrelayMenuItem<String>(
      value: 'system',
      icon: LucideIcons.moreHorizontal,
      label: l10n.showSystemMenu,
    ),
  ];

  if (!context.mounted) return;
  final result = await showMenu<String>(
    context: context,
    position: RelativeRect.fromRect(
      Rect.fromPoints(globalPosition, globalPosition),
      Offset.zero & MediaQuery.sizeOf(context),
    ),
    constraints: moonrelayMenuConstraints(),
    items: items,
  );

  if (result == null || !context.mounted) return;
  await onWindowMenuAction(context, result, closeWindow: closeWindow);
}

/// Acts on a choice from [showWindowContextMenu].
Future<void> onWindowMenuAction(
  BuildContext context,
  String action, {
  Future<void> Function()? closeWindow,
}) async {
  switch (action) {
    case 'minimize':
      await windowManager.minimize();
    case 'maximize':
      if (await windowManager.isMaximized()) {
        await windowManager.unmaximize();
      } else {
        await windowManager.maximize();
      }
    case 'close':
      if (closeWindow != null) {
        await closeWindow();
      } else {
        await windowManager.close();
      }
    case 'system':
      try {
        await windowManager.popUpWindowMenu();
      } catch (_) {
        // `popUpWindowMenu` is not available on every platform. Failing to
        // offer the OS's own menu is not worth reporting: the three window
        // commands above it are the ones the user came for.
      }
  }
}

/// A single row in the system menu.
