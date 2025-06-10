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

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/helpers/color_palette.dart';
import 'package:moonrelay/src/layouts/custom_scaffold.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/widgets/blur_background.dart';
import 'package:fluent_ui/fluent_ui.dart';
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
    //STUB - For future!
    // final TextEditingController searchController = TextEditingController();
    // final settingsController = Provider.of<SettingsController>(context);

    return Stack(
      children: [
        // DragToResizeArea(
        //   child: Container(),
        // ),

        Consumer<SettingsController>(
          builder: (context, value, child) => CustomScaffold(
            backgroundColor: (value.themeMode == ThemeMode.dark)
                ? MoonrelayColorPalette.cpgDarkest
                    .withAlpha(value.backgroundTransparencyScalar)
                : MoonrelayColorPalette.cpgWhite
                    .withAlpha(value.backgroundTransparencyScalar),
            topBar: value.useSystemTitlebar
                ? null
                : BlurBackground(
                    child: TitleBar(
                        brightness: (value.themeMode == ThemeMode.dark)
                            ? Brightness.dark
                            : Brightness.light),
                  ),
            content: widget.child,
          ),
        ),
      ],
    );
  }

  @override
  void onWindowClose() async {
    bool isPreventClose = await windowManager.isPreventClose();
    if (isPreventClose && mounted) {
      showDialog(
        context: context,
        builder: (_) {
          return ContentDialog(
            title: Text(AppLocalizations.of(context)!.confirmClose),
            content: Text(AppLocalizations.of(context)!.areYouSureExit),
            actions: [
              FilledButton(
                child: Text(AppLocalizations.of(context)!.yesOrAffirmitive),
                onPressed: () {
                  Navigator.pop(context);
                  windowManager.destroy();
                },
              ),
              Button(
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

class TitleBar extends StatefulWidget {
  const TitleBar({
    super.key,
    required this.brightness,
  });

  final Brightness brightness;

  @override
  State<TitleBar> createState() => _TitleBarState();
}

class _TitleBarState extends State<TitleBar> with WindowListener {
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
  void onWindowMaximize() {
    setState(() {});
  }

  @override
  void onWindowUnmaximize() {
    setState(() {});
  }

  @override
  void onWindowMinimize() {
    setState(() {});
    super.onWindowMinimize();
  }

  @override
  void onWindowRestore() {
    setState(() {});
    super.onWindowRestore();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = (widget.brightness == Brightness.dark);
    return DragToMoveArea(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(
              AppLocalizations.of(context)!.appTitle,
              style: const TextStyle(
                fontFamily: 'Oxanium',
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: MoonrelayColorPalette.the90sBrick,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 6.0),
            child: Container(
              width: 156,
              height: 32,
              decoration: BoxDecoration(
                  border: Border.all(
                      color: isDark
                          ? MoonrelayColorPalette.the90sBrick
                          : MoonrelayColorPalette.cpgDark),
                  borderRadius: BorderRadius.circular(12.0)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  FutureBuilder<bool>(
                    future: windowManager.isMinimized(),
                    builder: (context, AsyncSnapshot<bool> snapshot) {
                      if (snapshot.data == true) {
                        return IconButton(
                          icon: Icon(LucideIcons.maximize2),
                          onPressed: () => windowManager.restore(),
                        );
                      } else {
                        return IconButton(
                          icon: Icon(LucideIcons.minimize2),
                          onPressed: () => windowManager.minimize(),
                        );
                      }
                    },
                  ),
                  FutureBuilder<bool>(
                    future: windowManager.isMaximized(),
                    builder:
                        (BuildContext context, AsyncSnapshot<bool> snapshot) {
                      if (snapshot.data == true) {
                        return IconButton(
                          icon: Icon(LucideIcons.minimize),
                          onPressed: () => windowManager.unmaximize(),
                        );
                      }
                      return IconButton(
                        icon: Icon(LucideIcons.maximize),
                        onPressed: () => windowManager.maximize(),
                      );
                    },
                  ),
                  IconButton(
                    style: ButtonStyle(backgroundColor:
                        WidgetStateProperty.resolveWith<Color?>(
                      (states) {
                        if (states.contains(WidgetState.hovered) ||
                            states.contains(WidgetState.focused)) {
                          return MoonrelayColorPalette.brightMaroon
                              .withAlpha(128);
                        }
                        if (states.contains(WidgetState.pressed)) {
                          return MoonrelayColorPalette.brightMaroon
                              .withAlpha(255);
                        }
                        return null;
                      },
                    )),
                    icon: Icon(LucideIcons.squareX),
                    onPressed: () => windowManager.close(),
                  )
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
