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
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.canPop() ? context.pop() : null,
            ),
            title: const Text(
              "Settings",
              style: TextStyle(fontSize: 18, fontFamily: 'Rubik'),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
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
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('System'),
                value: ThemeMode.system,
                groupValue: widget.controller.themeMode,
                onChanged: (value) => widget.controller.updateThemeMode(value!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                value: ThemeMode.light,
                groupValue: widget.controller.themeMode,
                onChanged: (value) => widget.controller.updateThemeMode(value!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                value: ThemeMode.dark,
                groupValue: widget.controller.themeMode,
                onChanged: (value) => widget.controller.updateThemeMode(value!),
              ),
            ],
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
          child: Column(
            children: [
              RadioListTile<DisplayType>(
                title: Text(DisplayType.modern.label),
                value: DisplayType.modern,
                groupValue: widget.controller.displayType,
                onChanged: (value) =>
                    widget.controller.updateDisplayType(value!),
              ),
              RadioListTile<DisplayType>(
                title: Text(DisplayType.irc.label),
                value: DisplayType.irc,
                groupValue: widget.controller.displayType,
                onChanged: (value) =>
                    widget.controller.updateDisplayType(value!),
              ),
              RadioListTile<DisplayType>(
                title: Text(DisplayType.bubbles.label),
                value: DisplayType.bubbles,
                groupValue: widget.controller.displayType,
                onChanged: (value) =>
                    widget.controller.updateDisplayType(value!),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
