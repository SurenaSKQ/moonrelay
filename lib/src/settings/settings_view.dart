import 'package:fluent_ui/fluent_ui.dart';
import 'package:provider/provider.dart';

import 'settings_controller.dart';

/// Displays the various settings that can be customized by the user.
///
/// When a user changes a setting, the SettingsController is updated and
/// Widgets that listen to the SettingsController are rebuilt.
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  static const routeName = '/settings';

  @override
  Widget build(BuildContext context) {
    final SettingsController controller =
        Provider.of<SettingsController>(context);
    return ScaffoldPage(
      header: const Padding(
        padding: EdgeInsets.all(8.0),
        child: Row(
          children: [
            SizedBox(
              width: 16,
            ),
            Text(
              "Settings",
              style: TextStyle(fontSize: 18),
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
                  onPressed: () => controller.updateThemeMode(ThemeMode.system),
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
          ],
        ),
      ),
    );
  }
}
