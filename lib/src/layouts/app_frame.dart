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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:moonrelay/src/helpers/app_shutdown.dart';
import 'package:moonrelay/src/helpers/window_chrome.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/services/tray_service.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/layouts/window_title_bar.dart';

/// Main application frame shown after authentication.
///
/// Always renders [WindowTitleBar] rather than the OS title bar. The frame owns
/// a draggable title area, the global search control, the caption buttons and
/// the right-click system menu; nothing about the window's chrome is left to
/// the platform, which is what frees the top of the layout for app content.
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
    applyWindowChrome();
    super.initState();
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(WindowTitleBar.height),
        child: WindowTitleBar(
          showSearch: true,
          // Close honours the tray, which is an account preference and so is
          // not something the shared bar can decide. See [WindowTitleBar].
          closeWindow: () async {
            if (settings.closeToTray && TrayService.instance != null) {
              await TrayService.instance!.hideWindow();
            } else {
              await windowManager.close();
            }
          },
        ),
      ),
      body: widget.child,
    );
  }

  @override
  void onWindowClose() async {
    if (!mounted) return;
    final settings = context.read<SettingsController>();

    // Close-to-tray overrides the confirm-close dialog.
    if (settings.closeToTray && TrayService.instance != null) {
      await TrayService.instance!.hideWindow();
      return;
    }

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
}

