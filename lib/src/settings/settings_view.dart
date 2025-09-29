import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:moonrelay/src/widgets/label.dart';
import 'package:provider/provider.dart';

import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  static const routeName = '/settings';

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, child) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(LucideIcons.arrowLeft),
              onPressed: () => context.canPop() ? context.pop() : null,
            ),
            title: Text(
              "Settings",
              style: TextStyle(fontSize: 18, fontFamily: 'Rubik'),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            // Glue the SettingsController to the theme selection DropdownButton.
            //
            // When a user selects a theme from the dropdown list, the
            // SettingsController is updated, which rebuilds the MaterialApp.
            child: OldPage(controller: controller),
          ),
        );
      },
    );
  }
}

class OldPage extends StatefulWidget {
  const OldPage({super.key, required this.controller});
  final SettingsController controller;

  @override
  State<OldPage> createState() => _OldPageState();
}

class _OldPageState extends State<OldPage> {
  @override
  Widget build(BuildContext context) {
    bool systemBar = widget.controller.useSystemTitlebar;
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Label(
          label: "Theme mode",
          child: RadioGroup<ThemeMode>(
            onChanged: (value) => widget.controller.updateThemeMode(value!),
            child: Column(
              children: [
                Radio(value: ThemeMode.system),
                Radio(value: ThemeMode.light),
                Radio(value: ThemeMode.dark),
              ],
            ),
          ),
        ),
        const SizedBox(
          height: 8.0,
        ),
        Label(
          label: "Use system titlebar",
          child: Checkbox(
            value: systemBar,
            onChanged: (value) =>
                widget.controller.updateUseOfSystemTitlebar(value!),
          ),
        ),
        const SizedBox(
          height: 8.0,
        ),
        Label(
          label: "Chat display type",
          child: RadioGroup<DisplayType>(
            onChanged: (value) => widget.controller.updateDisplayType(value!),
            child: Column(
              children: [
                ListTile(
                  title: Text(DisplayType.modern.label),
                  leading: Radio(value: DisplayType.modern),
                ),
                ListTile(
                  title: Text(DisplayType.irc.label),
                  leading: Radio(value: DisplayType.irc),
                ),
                ListTile(
                  title: Text(DisplayType.bubbles.label),
                  leading: Radio(value: DisplayType.bubbles),
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}
