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

import 'package:libadwaita/libadwaita.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/helpers/color_palette.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

class AppFrame extends StatefulWidget {
  const AppFrame({
    super.key,
    required this.child,
    required this.shellContext,
  });

  final Widget child;
  final BuildContext? shellContext;
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
    bool isDark = MediaQuery.platformBrightnessOf(context) == Brightness.dark
        ? true
        : false;
    //STUB - For future!
    // final TextEditingController searchController = TextEditingController();
    // final settingsController = Provider.of<SettingsController>(context);
    // FIXME Rework titlebar widget
    return Consumer<SettingsController>(
      builder: (context, value, child) => Scaffold(
        backgroundColor: (value.themeMode == ThemeMode.dark)
            ? MoonrelayColorPalette.cpgDarkest
            : MoonrelayColorPalette.cpgWhite,
        appBar: AppBar(
          title: Text(
            AppLocalizations.of(context)!.appTitle,
            style: const TextStyle(
              fontFamily: 'Oxanium',
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(size: 16, LucideIcons.minimize2),
              onPressed: () => windowManager.minimize(),
            ),
            FutureBuilder<bool>(
              future: windowManager.isMaximized(),
              builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
                if (snapshot.data == true) {
                  return IconButton(
                    icon: Icon(size: 16, LucideIcons.minimize),
                    onPressed: () => windowManager.unmaximize(),
                  );
                } else {
                  return IconButton(
                    icon: Icon(size: 16, LucideIcons.maximize),
                    onPressed: () => windowManager.maximize(),
                  );
                }
              },
            ),
            IconButton(
              icon: Icon(size: 16, LucideIcons.squareX),
              onPressed: () => windowManager.close(),
            )
          ],
        ),
        body: widget.child,
      ),
    );
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted) {
      showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(AppLocalizations.of(context)!.confirmClose),
            content: SingleChildScrollView(
              child: ListBody(
                children: <Widget>[
                  Text(AppLocalizations.of(context)!.areYouSureExit)
                ],
              ),
            ),
            actions: <Widget>[
              TextButton(
                child: Text(AppLocalizations.of(context)!.yesOrAffirmitive),
                onPressed: () {
                  Navigator.pop(context);
                  windowManager.destroy();
                },
              ),
              TextButton(
                child: Text(AppLocalizations.of(context)!.noOrCancellation),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
            ],
          );
        },
      );
    }
  }
}
