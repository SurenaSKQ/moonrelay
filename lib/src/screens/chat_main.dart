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

import 'package:azhi_main/src/layouts/empty_space.dart';
import 'package:azhi_main/src/settings/theme.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:window_manager/window_manager.dart';
import 'package:badges/badges.dart' as badges;

class FluentChatMain extends StatefulWidget {
  const FluentChatMain({super.key});
  @override
  State<FluentChatMain> createState() => _FluentChatMainState();
}

class _FluentChatMainState extends State<FluentChatMain> with WindowListener {
  late final List<NavigationPaneItem> paneItems =
      [].map<NavigationPaneItem>((e) {
    PaneItem buildPaneItem(PaneItem item) {
      return PaneItem(
        key: item.key,
        icon: item.icon,
        title: item.title,
        body: item.body,
        onTap: () {
          final path = (item.key as ValueKey).value;
          context.go(path);
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
      icon: const Icon(FluentIcons.back),
      title: const Text("Logout"),
      body: const SizedBox.shrink(),
      onTap: _logout,
    )
  ];

  void _logout() async {
    final client = Provider.of<Client>(context, listen: false);
    final log = Provider.of<Logger>(context, listen: false);
    try {
      await client.logout();
      mounted
          ? context.go("/")
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

  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final _appTheme = AppTheme();
    final client = Provider.of<Client>(context, listen: false);
    Widget windowChild = const EmptySpace();

    return NavigationView(
      pane: NavigationPane(
        // FIXME: Add header?
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
}

class ChatsUncategorized extends StatefulWidget {
  const ChatsUncategorized({super.key});

  @override
  State<ChatsUncategorized> createState() => _ChatsUncategorizedState();
}

class _ChatsUncategorizedState extends State<ChatsUncategorized> {
  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context);
    void _join(Room room) async {
      try {
        if (room.membership != Membership.join) {
          await room.join();
        }
        context.go("rooms", extra: room);
      } catch (e) {
        Provider.of<Logger>(context).f(
          "Failed to join",
          error: e,
          stackTrace: StackTrace.current,
          time: DateTime.now(),
        );
        // FIXME: Better error and localization
        await displayInfoBar(
          context,
          builder: (context, close) {
            return InfoBar(
              title: Text(AppLocalizations.of(context)!.error),
              content: Text(e.toString()),
              action: IconButton(
                icon: const Icon(FluentIcons.clear),
                onPressed: close,
              ),
              severity: InfoBarSeverity.error,
            );
          },
        );
      }
    }

    return ScaffoldPage(
      content: Flex(
        direction: Axis.horizontal,
        children: [
          Expanded(
            flex: 1,
            child: Column(
              children: [
                StreamBuilder(
                  stream: client.onSync.stream,
                  builder: (context, _) => ListView.builder(
                    itemCount: client.rooms.length,
                    itemBuilder: (context, index) => ListTile.selectable(
                      leading: CircleAvatar(
                        foregroundImage: client.rooms[index].avatar == null
                            ? null
                            : NetworkImage(
                                client.rooms[index].avatar.toString(),
                              ),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              client.rooms[index].getLocalizedDisplayname(),
                            ),
                          ),
                        ],
                      ),
                      subtitle: Text(
                        client.rooms[index].lastEvent?.body ?? 'No messages',
                        maxLines: 1,
                      ),
                      trailing: (client.rooms[index].notificationCount > 0)
                          ? badges.Badge(
                              child: Text(
                                client.rooms[index].notificationCount
                                    .toString(),
                              ),
                            )
                          : null,
                      onPressed: () => _join(client.rooms[index]),
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
    ;
  }
}
