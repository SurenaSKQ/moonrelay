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

import 'package:azhi_main/src/helpers/azhi_color_palette.dart';
import 'package:azhi_main/src/layouts/azhi_custom_scaffold.dart';
import 'package:azhi_main/src/localization/app_localizations.dart';
import 'package:azhi_main/src/settings/settings_controller.dart';
import 'package:azhi_main/src/widgets/blur_background.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'package:azhi_main/src/widgets/window_buttons.dart';

class AzhiAppFrame extends StatefulWidget {
  const AzhiAppFrame({
    super.key,
    required this.child,
    required this.shellContext,
  });

  final Widget child;
  final BuildContext? shellContext;
  @override
  State<AzhiAppFrame> createState() => _AzhiAppFrameState();
}

class _AzhiAppFrameState extends State<AzhiAppFrame> with WindowListener {
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

        // FIXME - Style this from settings controller
        Consumer<SettingsController>(
          builder: (context, value, child) => AzhiCustomScaffold(
            backgroundColor: (MediaQuery.platformBrightnessOf(context).isDark)
                ? AzhiColorPalette.cpgDarkest
                    .withAlpha(value.backgroundTransparencyScalar)
                : AzhiColorPalette.cpgWhite
                    .withAlpha(value.backgroundTransparencyScalar),
            topBar: BlurBackground(child: AzhiTitleBar()),
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

class AzhiTitleBar extends StatelessWidget {
  const AzhiTitleBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
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
              ),
            ),
          ),
          const WindowButtons(),
        ],
      ),
    );
  }
}
