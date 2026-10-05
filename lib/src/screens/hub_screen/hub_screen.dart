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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/log_service.dart';
import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/helpers/shell_navigation.dart';
import 'package:moonrelay/src/layouts/layout_shell_controller.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/screens/encryption/encryption_overview/encryption_overview.dart';
import 'package:moonrelay/src/screens/logs_page.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

import 'about_page.dart';
import 'accounts_page.dart';
import 'hub_nav_list.dart';
import 'my_profile_page.dart';
import 'navigation_items.dart';
import 'settings/advanced_settings.dart';
import 'settings/appearance_settings.dart';
import 'settings/app_settings_overview.dart';
import 'settings/background_settings.dart';
import 'settings/blocked_users_page.dart';
import 'settings/chat_settings.dart';
import 'settings/keybind_settings.dart';
import 'settings/layout_settings.dart';
import 'settings/notification_settings.dart';
import 'settings/privacy_settings.dart';
import 'settings/storage_settings.dart';
import 'settings/update_settings.dart';
import 'sub_page_header.dart';

/// Width of the hub's navigation pane. Fixed rather than resizable: a
/// settings sidebar has no text long enough to need more, and a
/// user-resizable one would mean persisting a second width that has to
/// agree with the dashboard's sidebar width.
const double kHubNavWidth = 260;

/// The hub: your profile, app settings, accounts, and about.
///
/// The selected section comes from the route. That is why the hub became a
/// page at all: while it was a modal overlay the URL could not describe
/// what was on screen, so the widget kept its selection in private integers
/// and every hub link in the command palette resolved to nothing.
///
/// Two arrangements, one set of destinations:
///
///  * **Wide window.** A navigation pane on the left listing App Settings,
///    Accounts and About; content on the right. The active section reveals
///    its children inline, so a settings sub-page is one tap from anywhere.
///    This is the Discord shape, and it is what thirteen settings pages
///    have always needed to be.
///
///  * **Narrow window or the single-pane shell.** The index page *is* the
///    profile, with the section list underneath it. Choosing a section
///    pushes a full-screen page, so Back walks the stack the way it does
///    in any other app.
///
/// The split reads the shell's own [LayoutShellController.fitsTwoPanes],
/// which is the same answer the dashboard's detail pane reads. A hub that
/// went two-pane in a window where the dashboard went one-pane would be two
/// layouts disagreeing about the same measurement.
///
/// What this replaced was a horizontal tab strip that picked its
/// presentation by counting tabs: four sections got an evenly divided row,
/// and "App Settings" expanded the strip to fourteen, which is above the
/// strip's own threshold, so all thirteen settings pages were permanently a
/// dropdown. That is not a presentation detail, it is why the settings
/// never looked like a list of settings.
class HubScreen extends StatelessWidget {
  const HubScreen({
    super.key,
    required this.client,
    required this.categoryKey,
    this.subKey,
  });

  final Client client;

  /// Route path segment naming the section, or null for the index page.
  /// The router validates it, so by the time this builds it names a real
  /// section.
  final String? categoryKey;

  /// Route path segment naming a settings sub-item, or null for a section's
  /// own overview page.
  final String? subKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;
    final layers = ext.layers;
    final double width = MediaQuery.sizeOf(context).width;
    final bool twoPanes = context.read<LayoutShellController>().fitsTwoPanes;

    final Widget content = HubContent(
      client: client,
      categoryKey: categoryKey,
      subKey: subKey,
    );

    final Widget nav = HubNavList(
      selectedCategory: categoryKey,
      selectedSubItem: subKey,
      expandActive: twoPanes,
      onSelect: (String category, String? sub) => _go(context, category, sub),
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.hub),
        // Two buttons, because "back" means two different things here and
        // users mean different things by each.
        //
        // The arrow is a history step: it walks out of the hub the way it
        // was entered, undoing one section switch at a time. That is what
        // someone expects from a back arrow and it is the only thing that
        // gets them back to the room they opened settings from.
        //
        // The cross is an exit. It discards the hub's whole stack and goes
        // to the dashboard, which is what someone wants when they opened
        // the hub to change one setting and have changed it. Making them
        // press Back once per section visited to leave a surface they do
        // not think of as a stack is a small thing that adds up.
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          tooltip: l10n.back,
          onPressed: () => _leave(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(LucideIcons.x),
            tooltip: l10n.close,
            onPressed: () => closeToRoomList(context),
          ),
        ],
      ),
      body: LayoutScope(
        // Window width, not the pane's: the pane is 260px on a wide window
        // and the whole width on a narrow one, and a descendant that
        // measures itself should be told what the window is, the same
        // answer the dashboard's panes get.
        size: LayoutBreakpoints.sizeForWidth(width),
        availableWidth: width,
        child: twoPanes
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // The nav pane sits one step below the content, so the
                  // content is the surface the user came to read and the nav
                  // recedes. Same relationship as the dashboard's rail and
                  // room list.
                  Container(
                    width: kHubNavWidth,
                    color: scheme.surfaceContainerLow,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _AccountHeader(
                          // Push, not `go`: this is a move *within* the
                          // hub, and `go` would discard the sections the
                          // user came from, including the route the hub
                          // itself was opened from.
                          onTap: () => _go(context, null, null),
                          selected: categoryKey == null,
                        ),
                        Divider(height: 1, color: layers.hairline),
                        Expanded(child: nav),
                      ],
                    ),
                  ),
                  VerticalDivider(width: 1, color: layers.hairline),
                  Expanded(child: content),
                ],
              )
            // The index page is the profile with the section list under it.
            // On any other page the list is not repeated: the section is
            // full-screen and Back returns here.
            : categoryKey == null
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: content),
                      Divider(height: 1, color: scheme.outlineVariant),
                      SizedBox(
                        height: _kIndexNavHeight,
                        child: nav,
                      ),
                      SizedBox(height: t.spaceXs),
                    ],
                  )
                : content,
      ),
    );
  }

  /// Moves to a hub location, always by pushing.
  ///
  /// This used to `go` on the wide shell, on the grounds that a sidebar
  /// click is a lateral move. That was wrong in a way that only showed up
  /// once someone pressed Back: `go` replaces the whole page stack, so the
  /// first section switch inside the hub destroyed the route the hub was
  /// opened from. After one click there was nothing left to pop, the back
  /// button went inert, and the chat the user had opened settings *from*
  /// was unrecoverable. Not a cosmetic problem: the entry point was being
  /// thrown away.
  ///
  /// Pushing keeps the hub a stack in both shells, so Back works at every
  /// depth and walking out of the hub returns to where you came from. It
  /// also removes the last behavioural difference between the shells, which
  /// was the point of having two arrangements of one design rather than two
  /// designs.
  void _go(BuildContext context, String? category, String? sub) {
    final String path = hubPath(category: category, sub: sub);
    // Re-tapping the row you are already on would otherwise stack a
    // duplicate entry, making Back appear to do nothing for one press.
    if (GoRouter.of(context).state.uri.path == path) return;
    context.push(path);
  }

  /// Walks one step back through the hub, the way it was entered.
  ///
  /// This is the arrow, not the cross. It undoes one section switch at a
  /// time and, at the hub's entry point, returns to whatever opened the
  /// hub. The `go` fallback fires only when there is genuinely nothing
  /// behind: a cold start on `/hub`, or a deep link. [closeToRoomList] is
  /// the unconditional way out, and it is the cross in the app bar.
  void _leave(BuildContext context) {
    if (context.canPop()) {
      context.pop();
      return;
    }
    context.go(MoonRoutePaths.roomListTemplate);
  }
}

/// Height reserved for the section list on the narrow index page. Enough
/// for the three rows plus their dividers without the profile above it
/// being squeezed out.
const double _kIndexNavHeight = 168;

/// The account identity at the top of the hub's navigation pane.
///
/// Tappable, and it is the way back to the index page when the index page's
/// profile is scrolled past or the user is several sections deep. On the
/// narrow shell this is not rendered: there the profile *is* the index
/// page, and there is nothing to navigate back to from.
class _AccountHeader extends StatelessWidget {
  const _AccountHeader({required this.onTap, required this.selected});

  final VoidCallback onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Semantics(
      selected: selected,
      button: true,
      label: AppLocalizations.of(context)!.myProfile,
      child: InkWell(
        onTap: onTap,
        child: Container(
          // Same selected treatment as every row below, so "your profile" and
          // "appearance" do not mark themselves differently.
          color: selected
              ? MoonrelayThemeExtension.of(context).layers.active
              : scheme.surfaceContainerLow,
          padding:
              EdgeInsets.fromLTRB(t.spaceSm, t.spaceMd, t.spaceSm, t.spaceMd),
          child: Row(
            children: [
              const _ClientAvatar(),
              SizedBox(width: t.spaceSm),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.myProfile,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The signed-in user's own avatar, falling back to their Matrix id.
///
/// Read from the client rather than passed in: the header is a navigation
/// affordance and has no business carrying an avatar cache entry, and the
/// profile page directly below it already resolves the same value. Showing
/// the fallback rather than a blank circle matters because the id is what
/// identifies the account when the avatar is missing or 404s, which is the
/// common case in the integration test.
class _ClientAvatar extends StatelessWidget {
  const _ClientAvatar();

  @override
  Widget build(BuildContext context) {
    final Client client = context.read<Client>();
    final String userId = client.userID ?? '';
    return CircleAvatar(
      radius: 16,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Text(
        userId.isEmpty ? '?' : userId.substring(1, 2).toUpperCase(),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// The hub's content pane for one section.
///
/// Separate from the chrome above it so the same dispatcher serves both
/// arrangements, and so the settings pages keep their existing
/// `HubSubPageHeader` constraint: they are wrapped in an [Expanded], so
/// every one of them has to be scrollable or fillable.
class HubContent extends StatelessWidget {
  const HubContent({
    super.key,
    required this.client,
    required this.categoryKey,
    this.subKey,
  });

  final Client client;
  final String? categoryKey;
  final String? subKey;

  @override
  Widget build(BuildContext context) {
    final String? sub = subKey;

    if (categoryKey == null) {
      return HubMyProfilePage(client: client);
    }

    if (sub != null) {
      return HubSubPageHeader(
        title: _subItemTitle(context, sub),
        // The encryption page is the one section with a control of its own,
        // and it is the only way to pick up a cross-signing or key-backup
        // change made on another device. It used to come with an `AppBar`
        // that the embedded presentation threw away, along with the refresh.
        actions: sub == HubRouteKeys.security
            ? const [EncryptionRefreshAction()]
            : const [],
        child: _buildSubItem(context, sub),
      );
    }

    switch (categoryKey) {
      case HubRouteKeys.accounts:
        return _AccountsPane(client: client);
      case HubRouteKeys.settings:
        return HubSubPageHeader(
          title: AppLocalizations.of(context)!.appSettings,
          child: _SettingsOverview(),
        );
      case HubRouteKeys.about:
        return HubAboutPage(client: client);
      default:
        // Unreachable via a route: the router rejects unknown categories.
        // Reachable by a hand-built widget, so it renders nothing rather
        // than throwing.
        return const SizedBox.shrink();
    }
  }

  String _subItemTitle(BuildContext context, String sub) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    return switch (sub) {
      HubRouteKeys.appearance => l10n.appearance,
      HubRouteKeys.layout => l10n.layout,
      HubRouteKeys.security => l10n.encryptionAndSecurity,
      HubRouteKeys.chat => l10n.chatSettings,
      HubRouteKeys.keybinds => l10n.keybinds,
      HubRouteKeys.logs => l10n.logs,
      HubRouteKeys.background => l10n.backgroundAndTray,
      HubRouteKeys.notifications => l10n.notifications,
      HubRouteKeys.privacy => l10n.privacy,
      HubRouteKeys.storage => l10n.storage,
      HubRouteKeys.advanced => l10n.advanced,
      HubRouteKeys.blocked => l10n.blockedUsers,
      HubRouteKeys.updates => l10n.updates,
      _ => sub,
    };
  }

  /// Renders a settings sub-item keyed by its stable identifier. Adding a
  /// new sub-item is one case here, one entry in `HubRouteKeys`, and one
  /// row in `HubNavList`; it never depends on a positional index.
  Widget _buildSubItem(BuildContext context, String subKey) {
    switch (subKey) {
      case HubRouteKeys.appearance:
        return const HubAppearanceSettings();
      case HubRouteKeys.layout:
        return const HubLayoutSettings();
      case HubRouteKeys.security:
        return const EncryptionOverviewScreen(embedded: true);
      case HubRouteKeys.chat:
        return const HubChatSettings();
      case HubRouteKeys.keybinds:
        return const HubKeybindSettings();
      case HubRouteKeys.logs:
        return const LogsPage();
      case HubRouteKeys.background:
        return const HubBackgroundSettings();
      case HubRouteKeys.notifications:
        return const HubNotificationSettings();
      case HubRouteKeys.privacy:
        return const HubPrivacySettings();
      case HubRouteKeys.storage:
        return const HubStorageSettings();
      case HubRouteKeys.advanced:
        return const HubAdvancedSettings();
      case HubRouteKeys.blocked:
        return const HubBlockedUsersPage();
      case HubRouteKeys.updates:
        return const HubUpdateSettings();
      default:
        return const SizedBox.shrink();
    }
  }
}

/// The list of settings sections, shown on the App Settings overview page.
///
/// Rebuilt from [HubRouteKeys] rather than hand-listed, so a section added
/// to the nav list is reachable from the overview too. The two used to be
/// separate lists and could disagree, which is how `/hub/settings/network`
/// came to exist in the command palette while naming nothing at all.
class _SettingsOverview extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return HubAppSettingsOverview(
      onItemTap: (int index) {
        // The index is into this page's own item list, so it is resolved
        // through the same source of truth rather than trusted as a key.
        final String? sub = _subKeyAt(index);
        if (sub == null) return;
        context.push(hubPath(category: HubRouteKeys.settings, sub: sub));
      },
      items: _overviewItems(context),
    );
  }

  String? _subKeyAt(int index) {
    if (index < 0 || index >= HubRouteKeys.settingsSubItems.length) {
      return null;
    }
    return HubRouteKeys.settingsSubItems[index];
  }

  List<HubNavigationItem> _overviewItems(BuildContext context) =>
      buildSettingsNavigationItems(AppLocalizations.of(context)!);
}

/// The accounts section, which owns logging out.
///
/// A `StatefulWidget` for one piece of state: whether the wipe-on-logout
/// preference is on. The logout sequence itself stays in one place because
/// it spans the account manager, the log service and the router, and it is
/// the kind of thing that should not be reachable from two call sites.
class _AccountsPane extends StatefulWidget {
  const _AccountsPane({required this.client});

  final Client client;

  @override
  State<_AccountsPane> createState() => _AccountsPaneState();
}

class _AccountsPaneState extends State<_AccountsPane> {
  Future<void> _logout() async {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    try {
      final AccountManager accountManager = context.read<AccountManager>();
      final LogService logService = context.read<LogService>();
      // Read through the service, not a single reference: the advanced
      // settings page applies changes through it, so holding this identity
      // keeps the long-lived reference valid.
      final bool wipeLogs = context.read<SettingsController>().wipeLogsOnLogout;
      await accountManager.logout();
      if (!mounted) return;
      if (wipeLogs) {
        await logService.wipeLogs();
      }
      if (!mounted) return;
      context.go('/');
    } catch (e, stack) {
      if (!mounted) return;
      context.read<Logger>().e('Logout error', error: e, stackTrace: stack);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.error),
              Text(l10n.logoutError(e.toString())),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return HubAccountsPage(
      onLogout: _logout,
      onAddAccount: () => context.push('/add-account'),
    );
  }
}
