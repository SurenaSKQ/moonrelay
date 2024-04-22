// Copyright (C) 2024 Surena Karimpour Ghannadi
//
// This file is part of Prject Azhi.
//
// Prject Azhi is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Prject Azhi is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Prject Azhi.  If not, see <https://www.gnu.org/licenses/>.

import 'package:azhi_main/src/settings/settings_controller.dart';
import 'package:azhi_main/src/settings/settings_view.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:matrix/matrix.dart';
import 'package:window_manager/window_manager.dart';
import 'package:azhi_main/src/widgets/window_buttons.dart';
import 'package:provider/provider.dart';
import 'package:azhi_main/src/settings/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:logger/logger.dart';

class FluentMainPage extends StatefulWidget {
  const FluentMainPage({
    super.key,
    required this.child,
    required this.shellContext,
    required this.settingsController,
  });
  final Widget child;
  final BuildContext? shellContext;
  final SettingsController settingsController;
  @override
  State<FluentMainPage> createState() => _FluentMainPageState();
}

class _FluentMainPageState extends State<FluentMainPage> with WindowListener {
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
    final theme = FluentTheme.of(context);
    final _appTheme = AppTheme();
    final client = Provider.of<Client>(context, listen: false);
    //STUB - For future!
    final TextEditingController searchController = TextEditingController();
    return NavigationView(
      appBar: NavigationAppBar(
        automaticallyImplyLeading: false,
        title: () {
          return DragToMoveArea(
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                AppLocalizations.of(context)!.appTitle,
                style: const TextStyle(fontFamily: 'JetBrainsMono'),
              ),
            ),
          );
        }(),
        actions: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Align(
              alignment: AlignmentDirectional.centerEnd,
              child: Padding(
                padding: const EdgeInsetsDirectional.only(end: 8.0),
                child: ToggleSwitch(
                  content: Text(AppLocalizations.of(context)!.darkMode),
                  checked: FluentTheme.of(context).brightness.isDark,
                  onChanged: (v) {
                    if (v) {
                      widget.settingsController.updateThemeMode(ThemeMode.dark);
                    } else {
                      widget.settingsController
                          .updateThemeMode(ThemeMode.light);
                    }
                  },
                ),
              ),
            ),
            IconButton(
              icon: const Icon(FluentIcons.settings),
              onPressed: () {
                context.go("/settings", extra: widget.settingsController);
              },
            ),
            const WindowButtons(),
          ],
        ),
      ),
      content: widget.child,
    );
  }

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
