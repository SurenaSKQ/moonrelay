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
import 'package:window_manager/window_manager.dart';
import 'package:moonrelay/src/helpers/app_shutdown.dart';
import 'package:moonrelay/src/helpers/window_chrome.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/layouts/window_title_bar.dart';

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
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(WindowTitleBar.height(context)),
        // No search: there is nothing to search before the user is signed in,
        // and a search field that opens an empty palette is a dead control
        // with a real-looking border.
        child: const WindowTitleBar(),
      ),
      body: widget.child,
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

}
