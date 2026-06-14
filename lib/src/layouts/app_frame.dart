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

import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:moonrelay/src/helpers/platform.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/window_buttons.dart';

/// Main application frame shown after authentication.
///
/// Provides a custom header bar with:
/// - Platform-style window management buttons (minimize, maximize, close)
/// - A draggable title area for moving the window
/// - Right-click context menu with window actions and a "System menu" entry
/// - Left sidebar toggle button
/// - Reversible layout (buttons left / title right) via [SettingsController]
class AppFrame extends StatefulWidget {
  const AppFrame({
    super.key,
    required this.child,
  });

  final Widget child;
  @override
  State<AppFrame> createState() => _AppFrameState();
}

class _AppFrameState extends State<AppFrame> with WindowListener {
  @override
  void initState() {
    windowManager.addListener(this);
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: _buildAppBar(context, l10n),
      body: widget.child,
    );
  }

  /// Build the custom header bar.
  PreferredSizeWidget _buildAppBar(
    BuildContext context,
    AppLocalizations l10n,
  ) {
    final SettingsController settings =
        Provider.of<SettingsController>(context, listen: true);
    final ThemeData theme = Theme.of(context);
    final bool reversed = settings.headerReversed;
    final bool showButtons = isDesktop && !settings.useSystemTitlebar;

    final Widget sidebarToggle = IconButton(
      icon: Icon(
        settings.leftSidebarVisible
            ? LucideIcons.panelLeftClose
            : LucideIcons.panelLeftOpen,
      ),
      onPressed: () => settings.toggleLeftSidebar(),
      tooltip: settings.leftSidebarVisible
          ? l10n.collapseSidebar
          : l10n.expandSidebar,
    );

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              (event.buttons & 0x02) != 0) {
            _showContextMenu(context, event.position);
          }
        },
        child: Container(
          height: kToolbarHeight,
          color: theme.colorScheme.surface,
          child: Row(
            children: <Widget>[
              // ── Leading slot ──────────────────────────────────
              if (reversed && showButtons)
                const WindowButtons()
              else
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 4),
                  child: sidebarToggle,
                ),

              // ── Draggable title area ──────────────────────────
              Expanded(
                child: DragToMoveArea(
                  child: SizedBox(
                    height: double.infinity,
                    child: Center(
                      child: _HeaderTitle(l10n: l10n),
                    ),
                  ),
                ),
              ),

              // ── Trailing slot ─────────────────────────────────
              if (reversed)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 4),
                  child: sidebarToggle,
                )
              else if (showButtons)
                const WindowButtons(),
            ],
          ),
        ),
      ),
    );
  }

  /// Show a custom context menu when the user right-clicks the header.
  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final bool isMaxed = await windowManager.isMaximized();

    final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[
      PopupMenuItem<String>(
        value: 'minimize',
        child: _MenuRow(
          icon: Icons.minimize,
          label: l10n.minimize,
        ),
      ),
      PopupMenuItem<String>(
        value: 'maximize',
        child: _MenuRow(
          icon: isMaxed ? Icons.filter_none : Icons.check_box_outline_blank,
          label: isMaxed ? l10n.restore : l10n.maximize,
        ),
      ),
      PopupMenuItem<String>(
        value: 'close',
        child: _MenuRow(
          icon: Icons.close,
          label: l10n.closeWindow,
        ),
      ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: 'system',
        child: _MenuRow(
          icon: Icons.more_horiz,
          label: l10n.showSystemMenu,
        ),
      ),
    ];

    if (!context.mounted) return;
    final String? result = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        globalPosition.dx,
        globalPosition.dy,
        globalPosition.dx + 1,
        globalPosition.dy + 1,
      ),
      items: items,
    );

    if (result == null || !mounted) return;

    switch (result) {
      case 'minimize':
        await windowManager.minimize();
      case 'maximize':
        if (await windowManager.isMaximized()) {
          await windowManager.unmaximize();
        } else {
          await windowManager.maximize();
        }
      case 'close':
        await windowManager.close();
      case 'system':
        try {
          await windowManager.popUpWindowMenu();
        } catch (_) {
          // popUpWindowMenu may not be available on all platforms.
        }
    }
  }

  @override
  void onWindowClose() async {
    final bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted && context.mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          final AppLocalizations l10n = AppLocalizations.of(context)!;
          return AlertDialog(
            title: Text(l10n.confirmClose),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[Text(l10n.areYouSureExit)],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(l10n.yesOrAffirmitive),
                onPressed: () {
                  Navigator.pop(context);
                  windowManager.destroy();
                },
              ),
              TextButton(
                child: Text(l10n.noOrCancellation),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          );
        },
      );
    }
  }
}

/// Title text used in the custom header.
class _HeaderTitle extends StatelessWidget {
  const _HeaderTitle({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Text(
      l10n.appTitle,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 16,
      ),
    );
  }
}

/// A single row in the context menu with an icon and a label.
class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18),
        const SizedBox(width: 12),
        Text(label),
      ],
    );
  }
}
