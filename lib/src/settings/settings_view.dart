import 'package:moonrelay/src/layouts/app_frame.dart';
import 'package:moonrelay/src/layouts/custom_scaffold.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:go_router/go_router.dart';
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
  double? _transparencySliderValue;
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, child) {
        return CustomScaffold(
          topBar: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(FluentIcons.back),
                  onPressed: () => context.canPop() ? context.pop() : null,
                ),
                const SizedBox(
                  width: 16,
                ),
                const Text(
                  "Settings",
                  style: TextStyle(fontSize: 18, fontFamily: 'Rubik'),
                )
              ],
            ),
          ),
          content: Padding(
            padding: const EdgeInsets.all(16),
            // Glue the SettingsController to the theme selection DropdownButton.
            //
            // When a user selects a theme from the dropdown list, the
            // SettingsController is updated, which rebuilds the MaterialApp.
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropDownButton(
                  leading: const Text("Application Theme"),
                  // Call the updateThemeMode method any time the user selects a theme.

                  items: [
                    MenuFlyoutItem(
                      text: const Text("System Theme"),
                      onPressed: () =>
                          controller.updateThemeMode(ThemeMode.system),
                    ),
                    MenuFlyoutItem(
                        text: const Text("Light Theme"),
                        onPressed: () =>
                            controller.updateThemeMode(ThemeMode.light)),
                    MenuFlyoutItem(
                        text: const Text("Dark Theme"),
                        onPressed: () =>
                            controller.updateThemeMode(ThemeMode.dark)),
                  ],
                ),
                const SizedBox(
                  height: 8.0,
                ),
                DropDownButton(
                  leading: const Text("Chat display type"),
                  items: [
                    MenuFlyoutItem(
                      text: Text(DisplayType.modern.label),
                      onPressed: () =>
                          controller.updateDisplayType(DisplayType.modern),
                    ),
                    MenuFlyoutItem(
                      text: Text(DisplayType.irc.label),
                      onPressed: () =>
                          controller.updateDisplayType(DisplayType.irc),
                    ),
                    MenuFlyoutItem(
                      text: Text(DisplayType.bubbles.label),
                      onPressed: () =>
                          controller.updateDisplayType(DisplayType.bubbles),
                    ),
                  ],
                ),
                const SizedBox(
                  height: 8.0,
                ),
                Text(
                  'Linux only supports Transparent and solid. Use your WM to apply blur to transparency.',
                  style: TextStyle(fontSize: 16, fontFamily: 'Rubik'),
                ),
                DropDownButton(
                  leading: const Text("Window Effect"),
                  items: [
                    MenuFlyoutItem(
                      text: Text(WindowEffect.acrylic.name),
                      onPressed: () =>
                          controller.updateWindowEffect(WindowEffect.acrylic),
                    ),
                    MenuFlyoutItem(
                      text: Text(WindowEffect.transparent.name),
                      onPressed: () => controller
                          .updateWindowEffect(WindowEffect.transparent),
                    ),
                    MenuFlyoutItem(
                      text: Text(WindowEffect.mica.name),
                      onPressed: () =>
                          controller.updateWindowEffect(WindowEffect.mica),
                    ),
                    MenuFlyoutItem(
                      text: Text(WindowEffect.solid.name),
                      onPressed: () =>
                          controller.updateWindowEffect(WindowEffect.solid),
                    ),
                  ],
                ),
                SizedBox(
                  height: 8.0,
                ),
                Text(
                  'Background transparency value. Higher means more solid.',
                  style: const TextStyle(fontSize: 16, fontFamily: 'Rubik'),
                ),
                SizedBox(
                  height: 6.0,
                ),
                Slider(
                  label: 'Background transparency',
                  value: _transparencySliderValue ??
                      controller.backgroundTransparencyScalar.toDouble(),
                  min: 0,
                  max: 255,
                  onChanged: (double value) {
                    setState(() {
                      controller
                          .updateBackgroundTransparencyScalar(value.toInt());
                      _transparencySliderValue = value;
                    });
                  },
                )
              ],
            ),
          ),
        );
      },
    );
  }
}
