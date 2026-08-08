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

import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:moonrelay/src/helpers/app_shutdown.dart';
import 'package:moonrelay/src/helpers/platform.dart';
import 'package:moonrelay/src/helpers/window_chrome.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/window_buttons.dart';

/// Start screen frame shown before authentication.
///
/// Like [AppFrame], the header is optional: with OS window decorations
/// enabled (the default) no header is rendered; otherwise a slim bar
/// with a draggable title area, platform-style window buttons, and a
/// right-click system menu is shown.
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
  SettingsController? _settings;

  @override
  void initState() {
    windowManager.addListener(this);
    _settings = context.read<SettingsController>();
    _settings!.addListener(_applyChrome);
    _applyChrome();
    super.initState();
  }

  void _applyChrome() {
    final settings = _settings;
    if (settings != null) applyWindowChrome(settings);
  }

  @override
  void dispose() {
    _settings?.removeListener(_applyChrome);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    final showHeader = !settings.useOsTitleBar;

    return Scaffold(
      appBar: showHeader ? _buildAppBar(context) : null,
      body: widget.child,
    );
  }

  /// Build the slim custom header bar.
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final bool showButtons = isDesktop;

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
              // -- Draggable title area --------------------------
              Expanded(
                child: DragToMoveArea(
                  child: SizedBox(
                    height: double.infinity,
                    child: Center(
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

              // -- Trailing slot: window controls ----------------
              if (showButtons)
                const WindowButtons()
              else
                const SizedBox(width: 4),
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
                onPressed: () async {
                  Navigator.pop(context);
                  await MoonShutdown.call();
                  await windowManager.destroy();
                  // `windowManager.destroy()` only tears the window down;
                  // it does not terminate the Dart VM. Exit explicitly so
                  // the process does not linger on the system as a zombie
                  // after the UI is gone.
                  exit(0);
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
    final l10n = AppLocalizations.of(context)!;
    final bool isMaxed = await windowManager.isMaximized();
    if (!context.mounted) return;

    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;

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
