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
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:moonrelay/src/helpers/platform.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/window_buttons.dart';

/// Start screen frame shown before authentication.
///
/// Provides a custom header bar with:
/// - Platform-native window management buttons (minimize, maximize, close)
/// - Right-click context menu with window actions and a "System menu" entry
/// - Reversible layout (buttons left / title right) via [SettingsController]
class StartscreenFrame extends StatefulWidget {
  const StartscreenFrame({
    super.key,
    required this.child,
  });

  final Widget child;
  @override
  State<StartscreenFrame> createState() => _StartscreenFrameState();
}

class _StartscreenFrameState extends State<StartscreenFrame>
    with WindowListener {
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

    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (event) {
          if (event.kind == PointerDeviceKind.mouse &&
              // kSecondaryMouseButton (2) = right mouse button
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
                const SizedBox(width: 4),

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
                const SizedBox(width: 4)
              else if (showButtons)
                const WindowButtons(),
            ],
          ),
        ),
      ),
    );
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

  /// Show a custom context menu when the user right-clicks the header.
  Future<void> _showContextMenu(
    BuildContext context,
    Offset globalPosition,
  ) async {
    final bool isMaxed = await windowManager.isMaximized();
    if (!context.mounted) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

    final List<PopupMenuEntry<String>> items = <PopupMenuEntry<String>>[
      const PopupMenuItem<String>(
        value: 'minimize',
        child: _MenuRow(
          icon: Icons.minimize,
          label: 'Minimize',
        ),
      ),
      PopupMenuItem<String>(
        value: 'maximize',
        child: _MenuRow(
          icon: isMaxed ? Icons.filter_none : Icons.check_box_outline_blank,
          label: isMaxed ? 'Restore' : 'Maximize',
        ),
      ),
      const PopupMenuItem<String>(
        value: 'close',
        child: _MenuRow(
          icon: Icons.close,
          label: 'Close',
        ),
      ),
      const PopupMenuDivider(),
      const PopupMenuItem<String>(
        value: 'system',
        child: _MenuRow(
          icon: Icons.more_horiz,
          label: 'Show system menu',
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
