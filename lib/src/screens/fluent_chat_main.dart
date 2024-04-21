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

import 'package:azhi_main/src/settings/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:azhi_main/src/settings/settings_controller.dart';
import 'package:azhi_main/src/settings/settings_view.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'fluent_login_page.dart';
import 'package:window_manager/window_manager.dart';
import 'package:azhi_main/src/widgets/window_buttons.dart';

class FluentChatMain extends StatefulWidget {
  const FluentChatMain({super.key, required this.settingsController});
  static const routeName = "/chatMain";
  final SettingsController settingsController;
  @override
  State<FluentChatMain> createState() => _FluentChatMainState();
}

class _FluentChatMainState extends State<FluentChatMain> with WindowListener {
  late final List<NavigationPaneItem> paneItems = [
    PaneItem(
      key: const ValueKey("home"),
      title: Text(AppLocalizations.of(context)!.home),
      icon: const Icon(FluentIcons.home),
      body: const SizedBox.shrink(),
    ),
    PaneItem(
      //TODO - AppLocalization
      key: const ValueKey("spaces"),
      title: const Text("Spaces"),
      icon: const Icon(FluentIcons.chat),
      body: const SizedBox.shrink(),
    )
  ].map<NavigationPaneItem>((e) {
    PaneItem buildPaneItem(PaneItem item) {
      return PaneItem(
        key: item.key,
        icon: item.icon,
        title: item.title,
        body: item.body,
        onTap: () {
          final path = (item.key as ValueKey).value;
          // FIXME: Navigation
          // if ( ) {
          // }
          item.onTap?.call();
        },
      );
    }

    if (e is PaneItemExpander) {
      return PaneItemExpander(
        key: e.key,
        icon: e.icon,
        title: e.title,
        body: e.body,
        items: e.items.map((item) {
          if (item is PaneItem) return buildPaneItem(item);
          return item;
        }).toList(),
      );
    }
    if (e is PaneItem) return buildPaneItem(e);
    return e;
  }).toList();

  late final List<NavigationPaneItem> footerItems = [
    PaneItemSeparator(),
    PaneItem(
      key: const ValueKey(SettingsView.routeName),
      icon: const Icon(FluentIcons.settings),
      title: const Text('Settings'),
      body: const SizedBox.shrink(),
      onTap: () {
        Navigator.pushNamed(context, SettingsView.routeName);
      },
    ),
  ];

  void _logout() async {
    final client = Provider.of<Client>(context, listen: false);
    final log = Provider.of<Logger>(context, listen: false);
    try {
      await client.logout();
      mounted
          ? Navigator.of(context).pushAndRemoveUntil(
              FluentPageRoute(
                builder: (_) => FluentLoginPage(
                    settingsController: widget.settingsController),
              ),
              (route) => false,
            )
          : throw "Build context async failure widget not mounted";
    } catch (e) {
      log.e("Logout error",
          error: e, time: DateTime.now(), stackTrace: StackTrace.current);
      mounted
          ? await displayInfoBar(context, builder: (context, close) {
              return InfoBar(
                title: Text(AppLocalizations.of(context)!.error),
                content: Text(e.toString()),
                action: IconButton(
                  icon: const Icon(FluentIcons.clear),
                  onPressed: close,
                ),
                severity: InfoBarSeverity.error,
              );
            })
          : throw "Build context async failure widget not mounted";
    }
  }

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
    final TextEditingController searchController = TextEditingController();

    void _join(Room room) async {
      try {
        if (room.membership != Membership.join) {
          await room.join();
        }
        Navigator.of(context).push(
          FluentPageRoute(
            // TODO:
            builder: (_) => const Placeholder(),
          ),
        );
      } catch (e) {
        Provider.of<Logger>(context).f(
          "Failed to join",
          error: e,
          stackTrace: StackTrace.current,
          time: DateTime.now(),
        );
        // FIXME: Better error and localization
        await displayInfoBar(context, builder: (context, close) {
          return InfoBar(
            title: Text(AppLocalizations.of(context)!.error),
            content: Text(e.toString()),
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
            severity: InfoBarSeverity.error,
          );
        });
      }
    }

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
        actions: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
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
                    widget.settingsController.updateThemeMode(ThemeMode.light);
                  }
                },
              ),
            ),
          ),
          IconButton(
            icon: const Icon(FluentIcons.settings),
            onPressed: () {
              Navigator.restorablePushNamed(context, SettingsView.routeName);
            },
          ),
          const WindowButtons(),
        ]),
      ),
      pane: NavigationPane(
        header: SizedBox(
          height: kOneLineTileHeight,
          child: ShaderMask(
            shaderCallback: (rect) {
              final color = _appTheme.color.defaultBrushFor(
                theme.brightness,
              );
              return LinearGradient(
                colors: [
                  color,
                  color,
                ],
              ).createShader(rect);
            },
            child: SvgPicture.asset(
              'assets/images/azhi_logo.svg',
              colorFilter: ColorFilter.mode(
                  (FluentTheme.of(context).brightness == Brightness.dark)
                      ? Colors.white
                      : Colors.black,
                  BlendMode.srcIn),
            ),
          ),
        ),
        displayMode: _appTheme.displayMode,
        indicator: () {
          switch (_appTheme.indicator) {
            case NavigationIndicators.end:
              return const EndNavigationIndicator();
            case NavigationIndicators.sticky:
            default:
              return const StickyNavigationIndicator();
          }
        }(),
        items: paneItems,
        footerItems: footerItems,
      ),
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
