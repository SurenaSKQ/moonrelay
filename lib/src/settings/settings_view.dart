import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAppearanceSection(controller),
                  const SizedBox(height: 24),
                  _buildLayoutSection(controller),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppearanceSection(SettingsController controller) {
    bool systemBar = controller.useSystemTitlebar;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Rubik',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),
        Label(
          label: "Theme mode",
          child: Column(
            children: [
              RadioListTile<ThemeMode>(
                title: const Text('System'),
                value: ThemeMode.system,
                groupValue: controller.themeMode,
                onChanged: (value) => controller.updateThemeMode(value!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Light'),
                value: ThemeMode.light,
                groupValue: controller.themeMode,
                onChanged: (value) => controller.updateThemeMode(value!),
              ),
              RadioListTile<ThemeMode>(
                title: const Text('Dark'),
                value: ThemeMode.dark,
                groupValue: controller.themeMode,
                onChanged: (value) => controller.updateThemeMode(value!),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Label(
          label: "Use system titlebar",
          child: Checkbox(
            value: systemBar,
            onChanged: (value) => controller.updateUseOfSystemTitlebar(value!),
          ),
        ),
        const SizedBox(height: 8),
        Label(
          label: "Chat display type",
          child: Column(
            children: [
              RadioListTile<DisplayType>(
                title: Text(DisplayType.modern.label),
                value: DisplayType.modern,
                groupValue: controller.displayType,
                onChanged: (value) => controller.updateDisplayType(value!),
              ),
              RadioListTile<DisplayType>(
                title: Text(DisplayType.irc.label),
                value: DisplayType.irc,
                groupValue: controller.displayType,
                onChanged: (value) => controller.updateDisplayType(value!),
              ),
              RadioListTile<DisplayType>(
                title: Text(DisplayType.bubbles.label),
                value: DisplayType.bubbles,
                groupValue: controller.displayType,
                onChanged: (value) => controller.updateDisplayType(value!),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLayoutSection(SettingsController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Layout',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            fontFamily: 'Rubik',
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 12),

        // ── Left sidebar ────────────────────────────────────────────
        Label(
          label: 'Left sidebar',
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Visible'),
                subtitle: const Text('Show or hide the left sidebar'),
                value: controller.leftSidebarVisible,
                onChanged: (value) => controller.setLeftSidebarVisible(value),
                secondary: const Icon(LucideIcons.panelLeft),
              ),
              if (controller.leftSidebarVisible) ...[
                ListTile(
                  title: const Text('Content'),
                  subtitle: Text(controller.leftPaneChoice.label),
                  leading: const Icon(LucideIcons.layoutList),
                  trailing: DropdownButton<LeftPaneChoice>(
                    value: controller.leftPaneChoice,
                    onChanged: (value) {
                      if (value != null) {
                        controller.setLeftPaneChoice(value);
                      }
                    },
                    items: LeftPaneChoice.values
                        .map(
                          (choice) => DropdownMenuItem(
                            value: choice,
                            child: Text(choice.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
                ListTile(
                  title: const Text('Width'),
                  subtitle: Text('${controller.leftSidebarWidth.round()} px'),
                  leading: const Icon(LucideIcons.moveHorizontal),
                  trailing: SizedBox(
                    width: 160,
                    child: Slider(
                      value: controller.leftSidebarWidth,
                      min: 200,
                      max: 600,
                      divisions: 16,
                      label: '${controller.leftSidebarWidth.round()}',
                      onChanged: (value) =>
                          controller.setLeftSidebarWidth(value),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Right sidebar ───────────────────────────────────────────
        Label(
          label: 'Right sidebar (experimental)',
          child: Column(
            children: [
              SwitchListTile(
                title: const Text('Visible'),
                subtitle: const Text(
                  'Show or hide the right sidebar '
                  '(hidden on medium screens)',
                ),
                value: controller.rightSidebarVisible,
                onChanged: (value) => controller.setRightSidebarVisible(value),
                secondary: const Icon(LucideIcons.panelRight),
              ),
              if (controller.rightSidebarVisible) ...[
                ListTile(
                  title: const Text('Content'),
                  subtitle: Text(controller.rightPaneChoice.label),
                  leading: const Icon(LucideIcons.layoutList),
                  trailing: DropdownButton<RightPaneChoice>(
                    value: controller.rightPaneChoice,
                    onChanged: (value) {
                      if (value != null) {
                        controller.setRightPaneChoice(value);
                      }
                    },
                    items: RightPaneChoice.values
                        .map(
                          (choice) => DropdownMenuItem(
                            value: choice,
                            child: Text(choice.label),
                          ),
                        )
                        .toList(),
                  ),
                ),
                ListTile(
                  title: const Text('Width'),
                  subtitle: Text('${controller.rightSidebarWidth.round()} px'),
                  leading: const Icon(LucideIcons.moveHorizontal),
                  trailing: SizedBox(
                    width: 160,
                    child: Slider(
                      value: controller.rightSidebarWidth,
                      min: 200,
                      max: 500,
                      divisions: 12,
                      label: '${controller.rightSidebarWidth.round()}',
                      onChanged: (value) =>
                          controller.setRightSidebarWidth(value),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
