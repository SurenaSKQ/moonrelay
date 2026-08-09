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

import 'package:moonrelay/src/helpers/responsive.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/widgets/blur_background.dart';
import 'package:moonrelay/src/screens/logs_page.dart';
import 'package:moonrelay/src/screens/encryption/encryption_overview.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/log_service.dart';
import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';
import 'package:moonrelay/src/screens/hub_screen/sub_page_header.dart';
import 'package:moonrelay/src/screens/hub_screen/accounts_page.dart';
import 'package:moonrelay/src/screens/hub_screen/my_profile_page.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/app_settings_overview.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/advanced_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/appearance_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/background_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/blocked_users_page.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/chat_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/layout_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/network_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/notification_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/privacy_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/storage_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/update_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/settings/keybind_settings.dart';
import 'package:moonrelay/src/screens/hub_screen/about_page.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

// -----------------------------------------------------------------------------
// The main Hub screen  tab-based UI
// -----------------------------------------------------------------------------

/// A category selection that may be deep-linked into the [HubScreen].
///
/// The hub has internal state for `_selectedCategoryIndex` and
/// `_selectedSubItemIndex`.  When a route specifies a category (and
/// optional sub-item) the screen must mirror that selection into its
/// internal state so the active tab and content pane agree with the
/// URL.
///
/// The values are stable enough to be passed via GoRouter path
/// parameters rather than query strings, which makes them matchable
/// to specific routes (e.g. `/hub/settings/appearance`).
class HubCategorySelection {
  const HubCategorySelection({this.categoryKey, this.subKey});
  final String? categoryKey;
  final String? subKey;
}

/// Whether a tab in the hub represents a top-level category or one of
/// the sub-items that hang off an expandable parent.
enum _HubTabScope {
  /// The tab targets a top-level category (e.g. Accounts, Settings).
  category,

  /// The tab targets a sub-item of an expandable category (e.g.
  /// Settings > Appearance).  Only used inside the settings tab.
  subItem,
}

/// One entry in the hub's tab strip.
///
/// Each entry knows whether it represents a top-level category or a
/// sub-item of an expandable parent; [controller] is the
/// [TabController] that drives it.  Tapping a tab navigates to the
/// canonical URL so deep links remain in sync.
class _HubTab {
  const _HubTab({
    required this.label,
    required this.icon,
    required this.key,
    required this.scope,
    required this.parentCategoryIndex,
  });

  /// Localised label shown in the tab.
  final String label;

  /// Icon shown in the tab.
  final IconData icon;

  /// Stable key used to resolve content for this tab.
  final String key;

  /// Whether this is a top-level tab or a sub-tab.
  final _HubTabScope scope;

  /// The index of the parent top-level category in [_categories].  For
  /// top-level tabs this equals the tab's own index in the strip.
  final int parentCategoryIndex;
}

class HubScreen extends StatefulWidget {
  const HubScreen({super.key, required this.client, this.selection});

  final Client client;

  /// Optional deep-link selection resolved by the router.  When
  /// present, the screen synchronises its internal category/sub-item
  /// indices to the supplied keys and reacts to subsequent changes
  /// (e.g. the user tapping "Open Settings" from the command palette
  /// while already on `/hub/accounts`).
  final HubCategorySelection? selection;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  // Index tracking: which top-level category and which sub-item (if any).
  int _selectedCategoryIndex = 0;
  int _selectedSubItemIndex = -1;

  // -- Category definitions -------------------------------------------------

  List<HubCategory> _categories = [];

  // When the user is inside an expandable category with sub-items, we
  // swap the tab strip's contents for the parent category's items so
  // the user can flip between Appearance / Layout / Encryption & …
  // without leaving the parent tab.  The parent's index is preserved
  // so we can render the parent's overview page (or first item) when
  // the user re-selects the top-level tab.
  int _subTabsParentIndex = -1;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_categories.isEmpty) {
      _buildCategories();
      // Apply initial selection from the route if one was supplied.
      _applySelection(widget.selection, duringBuild: true);
    }
  }

  @override
  void didUpdateWidget(covariant HubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selection != widget.selection) {
      _applySelection(widget.selection);
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Maps a [HubCategorySelection] (category/sub keys) into the
  /// screen's internal indices.
  ///
  /// When [duringBuild] is true, the indices are mutated directly and
  /// a follow-up [setState] is scheduled for after the current frame.
  /// This avoids triggering an assertion failure when the caller is
  /// already inside a build cycle (e.g. [didChangeDependencies]).
  void _applySelection(HubCategorySelection? selection,
      {bool duringBuild = false}) {
    if (selection == null) return;
    final catIdx = _categories.indexWhere(
      (c) => c.key == selection.categoryKey,
    );
    if (catIdx < 0) return;

    int subIdx = -1;
    if (selection.subKey != null &&
        catIdx < _categories.length &&
        _categories[catIdx].items.isNotEmpty) {
      subIdx = _categories[catIdx]
          .items
          .indexWhere((s) => s.key == selection.subKey);
    }

    if (catIdx == _selectedCategoryIndex && subIdx == _selectedSubItemIndex) {
      return;
    }

    if (duringBuild) {
      _selectedCategoryIndex = catIdx;
      _selectedSubItemIndex = subIdx;
      _subTabsParentIndex = subIdx >= 0 ? catIdx : -1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {
        _selectedCategoryIndex = catIdx;
        _selectedSubItemIndex = subIdx;
        _subTabsParentIndex = subIdx >= 0 ? catIdx : -1;
      });
    }
  }

  void _buildCategories() {
    final l10n = AppLocalizations.of(context)!;
    _categories = [
      HubCategory(
        key: 'accounts',
        label: l10n.accounts,
        icon: LucideIcons.users,
        isExpandable: false,
      ),
      HubCategory(
        key: 'profile',
        label: l10n.ownProfileDescriptor,
        icon: LucideIcons.user,
        isExpandable: false,
      ),
      HubCategory(
        key: 'settings',
        label: l10n.appSettings,
        icon: LucideIcons.settings,
        isExpandable: true,
        items: [
          HubNavigationItem(
            key: 'appearance',
            label: l10n.appearance,
            icon: LucideIcons.palette,
          ),
          HubNavigationItem(
            key: 'layout',
            label: l10n.layout,
            icon: LucideIcons.layoutDashboard,
          ),
          HubNavigationItem(
            key: 'security',
            label: l10n.encryptionAndSecurity,
            icon: LucideIcons.shield,
          ),
          HubNavigationItem(
            key: 'chat',
            label: l10n.chatSettings,
            icon: LucideIcons.messageSquare,
          ),
          HubNavigationItem(
            key: 'keybinds',
            label: l10n.keybinds,
            icon: LucideIcons.keyboard,
          ),
          HubNavigationItem(
            key: 'network',
            label: l10n.network,
            icon: LucideIcons.activity,
          ),
          HubNavigationItem(
            key: 'logs',
            label: l10n.logs,
            icon: LucideIcons.fileText,
          ),
          HubNavigationItem(
            key: 'background',
            label: l10n.backgroundAndTray,
            icon: LucideIcons.minimize2,
          ),
          HubNavigationItem(
            key: 'notifications',
            label: l10n.notifications,
            icon: LucideIcons.bell,
          ),
          HubNavigationItem(
            key: 'privacy',
            label: l10n.privacy,
            icon: LucideIcons.shieldCheck,
          ),
          HubNavigationItem(
            key: 'storage',
            label: l10n.storage,
            icon: LucideIcons.hardDrive,
          ),
          HubNavigationItem(
            key: 'advanced',
            label: l10n.advanced,
            icon: LucideIcons.settings2,
          ),
          HubNavigationItem(
            key: 'blocked',
            label: l10n.blockedUsers,
            icon: LucideIcons.ban,
          ),
          HubNavigationItem(
            key: 'updates',
            label: l10n.updates,
            icon: LucideIcons.download,
          ),
        ],
      ),
      HubCategory(
        key: 'about',
        label: l10n.about,
        icon: LucideIcons.info,
        isExpandable: false,
      ),
    ];
  }

  /// Returns the list of tabs to render in the top strip.
  ///
  /// When the user is inside a top-level category (or has just
  /// selected one without a sub-item) the strip shows the four
  /// top-level categories.  When the user is on a sub-item of an
  /// expandable parent, the strip shows that parent's sub-items so the
  /// user can flip between settings panes without going back through
  /// the overview.
  List<_HubTab> _tabsForCurrentSelection() {
    if (_subTabsParentIndex >= 0) {
      final parent = _categories[_subTabsParentIndex];
      // First tab: the parent overview page.
      final parentLabel = parent.label;
      final tabs = <_HubTab>[
        _HubTab(
          label: parentLabel,
          icon: parent.icon,
          key: parent.key ?? '',
          scope: _HubTabScope.category,
          parentCategoryIndex: _subTabsParentIndex,
        ),
      ];
      for (var i = 0; i < parent.items.length; i++) {
        final sub = parent.items[i];
        tabs.add(_HubTab(
          label: sub.label,
          icon: sub.icon,
          key: sub.key ?? '',
          scope: _HubTabScope.subItem,
          parentCategoryIndex: _subTabsParentIndex,
        ));
      }
      return tabs;
    }
    // Top-level strip  one tab per top-level category.
    return [
      for (var i = 0; i < _categories.length; i++)
        _HubTab(
          label: _categories[i].label,
          icon: _categories[i].icon,
          key: _categories[i].key ?? '',
          scope: _HubTabScope.category,
          parentCategoryIndex: i,
        ),
    ];
  }

  int get categoryCount => _categories.length;

  Future<void> _logout() async {
    final l10n = AppLocalizations.of(context)!;
    try {
      final accountManager = context.read<AccountManager>();
      final logService = context.read<LogService>();
      await accountManager.logout();
      // Wipe all log files now that the session has been torn down.
      await logService.wipeLogs();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      final log = context.read<Logger>();
      log.e('Logout error', error: e, stackTrace: StackTrace.current);
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

  void _selectTab(_HubTab tab) {
    if (tab.scope == _HubTabScope.category) {
      if (_subTabsParentIndex != tab.parentCategoryIndex ||
          _selectedCategoryIndex != tab.parentCategoryIndex) {
        setState(() {
          _selectedCategoryIndex = tab.parentCategoryIndex;
          _selectedSubItemIndex = -1;
          // Entering a top-level tab that is expandable should NOT
          // expand its sub-tabs automatically  the user has to tap
          // a sub-tab or the parent overview page.  This matches the
          // previous "category opens on its overview" behaviour.
          _subTabsParentIndex = -1;
        });
        final cat = _categories[tab.parentCategoryIndex];
        if (cat.key != null) _pushHubUrl(cat.key!, null);
      }
    } else {
      final cat = _categories[tab.parentCategoryIndex];
      setState(() {
        _selectedCategoryIndex = tab.parentCategoryIndex;
        _selectedSubItemIndex = cat.items.indexWhere((s) => s.key == tab.key);
        _subTabsParentIndex = tab.parentCategoryIndex;
      });
      if (cat.key != null) _pushHubUrl(cat.key!, tab.key);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tabs = _tabsForCurrentSelection();
    final activeIndex = _activeTabIndex(tabs);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/main/rooms');
            }
          },
        ),
        title: Text(
          l10n.hub,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final size = LayoutBreakpoints.sizeForWidth(constraints.maxWidth);
          return LayoutScope(
            size: size,
            availableWidth: constraints.maxWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _HubTabStrip(
                  tabs: tabs,
                  activeIndex: activeIndex,
                  onTap: (i) {
                    if (i < 0 || i >= tabs.length) return;
                    _selectTab(tabs[i]);
                  },
                ),
                if (_subTabsParentIndex >= 0 &&
                    _categories[_subTabsParentIndex].items.length > 1)
                  _buildBackToTopRow(),
                const Divider(height: 1),
                Expanded(
                  child: KeyedSubtree(
                    // Re-key on selection so each tab gets a fresh
                    // element when it becomes visible.  Avoids the
                    // [TabBarView] controller lifecycle issues and
                    // doesn't eagerly build inactive tabs (which
                    // would force all settings pages to mount
                    // simultaneously and call into the [Client]).
                    key: ValueKey(activeIndex),
                    child: activeIndex >= 0 && activeIndex < tabs.length
                        ? _buildTabBody(tabs[activeIndex])
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  /// Computes which index in the current [tabs] list represents the
  /// active selection.  Returns 0 when the selection does not match
  /// any tab (e.g. the deep-link referenced a category the user has
  /// since collapsed) so the strip and body stay in sync.
  int _activeTabIndex(List<_HubTab> tabs) {
    if (tabs.isEmpty) return 0;
    if (_subTabsParentIndex >= 0) {
      // Sub-tabs strip: index 0 is the parent overview, the rest are
      // sub-items in order.
      final sub = _selectedSubItemIndex;
      if (sub < 0) return 0;
      return (sub + 1).clamp(0, tabs.length - 1);
    }
    return _selectedCategoryIndex.clamp(0, tabs.length - 1);
  }

  /// Builds the top-level tab strip as a custom widget that does not
  /// rely on [TabController].
  Widget _buildBackToTopRow() {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      color: scheme.surfaceContainerLow,
      padding: EdgeInsets.symmetric(horizontal: t.spaceMd, vertical: t.spaceXs),
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        icon: const Icon(LucideIcons.chevronLeft, size: 14),
        label: const Text('All categories'),
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 0),
          textStyle: const TextStyle(fontSize: 12),
        ),
        onPressed: () {
          setState(() {
            _subTabsParentIndex = -1;
            _selectedSubItemIndex = -1;
          });
          final cat = _categories[_selectedCategoryIndex];
          if (cat.key != null) _pushHubUrl(cat.key!, null);
        },
      ),
    );
  }

  Widget _buildTabBody(_HubTab tab) {
    if (tab.scope == _HubTabScope.category) {
      // First tab of a sub-tab strip is the parent's overview page.
      final cat = _categories[tab.parentCategoryIndex];
      if (_subTabsParentIndex >= 0) {
        return HubSubPageHeader(
          title: cat.label,
          child: HubAppSettingsOverview(
            items: cat.items,
            onItemTap: (i) {
              final sub = cat.items[i];
              setState(() {
                _selectedCategoryIndex = tab.parentCategoryIndex;
                _selectedSubItemIndex = i;
                _subTabsParentIndex = tab.parentCategoryIndex;
              });
              _pushHubUrl(cat.key!, sub.key);
            },
          ),
        );
      }
      switch (cat.key) {
        case 'accounts':
          return HubAccountsPage(
            onLogout: _logout,
            onAddAccount: () => context.push('/add-account'),
          );
        case 'profile':
          return HubMyProfilePage(client: widget.client);
        case 'settings':
          return HubSubPageHeader(
            title: cat.label,
            child: HubAppSettingsOverview(
              items: cat.items,
              onItemTap: (i) {
                final sub = cat.items[i];
                setState(() {
                  _selectedCategoryIndex = tab.parentCategoryIndex;
                  _selectedSubItemIndex = i;
                  _subTabsParentIndex = tab.parentCategoryIndex;
                });
                _pushHubUrl(cat.key!, sub.key);
              },
            ),
          );
        case 'about':
          return HubAboutPage(client: widget.client);
        default:
          return const Center(child: Text('…'));
      }
    }
    // Sub-item body.
    return HubSubPageHeader(
      title: tab.label,
      child: _buildSubItemContent(tab.key),
    );
  }

  // -- Content routing -----------------------------------------------------

  /// Renders a settings sub-item page keyed by the item's stable
  /// identifier.  Adding a new sub-item is a one-line case and never
  /// depends on positional indices.
  Widget _buildSubItemContent(String? subKey) {
    // Only the settings category currently has sub-items; other
    // expandable categories would dispatch here too if added later.
    final cat = _categories[_selectedCategoryIndex];
    if (cat.key != 'settings') return const SizedBox.shrink();

    switch (subKey) {
      case 'appearance':
        return const HubAppearanceSettings();
      case 'layout':
        return const HubLayoutSettings();
      case 'security':
        return const EncryptionOverviewScreen(embedded: true);
      case 'chat':
        return const HubChatSettings();
      case 'keybinds':
        return const HubKeybindSettings();
      case 'network':
        return const HubNetworkSettings();
      case 'logs':
        return const LogsPage();
      case 'background':
        return const HubBackgroundSettings();
      case 'notifications':
        return const HubNotificationSettings();
      case 'privacy':
        return const HubPrivacySettings();
      case 'storage':
        return const HubStorageSettings();
      case 'advanced':
        return const HubAdvancedSettings();
      case 'blocked':
        return const HubBlockedUsersPage();
      case 'updates':
        return const HubUpdateSettings();
      default:
        return const SizedBox.shrink();
    }
  }

  /// Build the canonical `/hub/<category>/<sub>` URL for the current
  /// selection.  Returns `null` for the bare `/hub` index route when
  /// the user is sitting on the top-level of a non-expandable category.
  String? _hubUrlFor(String categoryKey, String? subKey) {
    final base = '/hub/$categoryKey';
    if (subKey == null || subKey.isEmpty) return base;
    return '$base/$subKey';
  }

  /// Push the hub sub-route corresponding to the given category / sub
  /// keys so the URL matches the visible selection and the back button
  /// can exit cleanly.
  ///
  /// The hub can be opened in two ways: as a top-level [GoRoute] (where
  /// the URL is the source of truth and `context.go` rewrites it) or
  /// as a modal overlay via [showHubOverlay] (where the URL has no
  /// effect on the visible state because the overlay sits on top of
  /// the room page).  In the overlay case calling `context.go` would
  /// *replace* the room page in the navigator stack  which is exactly
  /// the bug we just fixed.  We detect the overlay case via
  /// [ModalRoute.opaque] and skip the URL push.
  void _pushHubUrl(String categoryKey, String? subKey) {
    if (!_isOverlay) {
      final url = _hubUrlFor(categoryKey, subKey);
      if (url != null && mounted) context.go(url);
    }
  }

  /// True when the hub is presented as a modal overlay (i.e. the
  /// surrounding [ModalRoute] is non-opaque, which is what
  /// [showHubOverlay] uses).  False when the hub is the top-level
  /// [GoRoute] and a URL push is appropriate.
  bool get _isOverlay {
    final route = ModalRoute.of(context);
    if (route == null) return false;
    return !route.opaque;
  }
}

// -- Hub overlay ------------------------------------------------------------

/// Opens the hub screen as a centered modal overlay on top of the current
/// navigation stack (like the command palette), preserving the dashboard
/// state underneath and blurring the background.
///
/// When [selection] is provided, the hub opens to the specified
/// category/sub-item (e.g. profile, settings, accounts).
Future<void> showHubOverlay(
  BuildContext context, {
  HubCategorySelection? selection,
}) {
  final client = Provider.of<Client>(context, listen: false);
  return Navigator.of(context, rootNavigator: true).push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, __, ___) => _HubOverlayPage(
        client: client,
        selection: selection,
      ),
    ),
  );
}

/// Maximum number of tabs shown inline before the strip switches to a
/// dropdown selector.  Beyond this threshold a [PopupMenuButton] with
/// the active tab as its label replaces the scrollable row, so items
/// never overflow off-screen or require horizontal scrolling.
const int _kMaxInlineTabs = 6;

/// A tab strip widget that does not depend on [TabController].
///
/// We avoid [TabController] here because its length is fixed at
/// construction time and the hub swaps between two different tab
/// strips (top-level categories vs. a parent's sub-items).  Using a
/// controller would force us to dispose and re-create it on every
/// swap, which trips [ChangeNotifier] assertions during paint.  A
/// stateless strip driven by the parent's selection state is simpler
/// and avoids the lifecycle pitfalls.
///
/// When the number of tabs exceeds [_kMaxInlineTabs] the strip
/// switches to a dropdown selector so items never overflow or require
/// off-screen horizontal scrolling.
class _HubTabStrip extends StatelessWidget {
  const _HubTabStrip({
    required this.tabs,
    required this.activeIndex,
    required this.onTap,
  });

  final List<_HubTab> tabs;
  final int activeIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final useDropdown = tabs.length > _kMaxInlineTabs;
    return Container(
      color: scheme.surfaceContainerLow,
      child: SizedBox(
        height: 56,
        child: useDropdown
            ? _buildDropdown(context, scheme)
            : (tabs.length > 4
                ? SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (var i = 0; i < tabs.length; i++)
                          _HubTabStripEntry(
                            tab: tabs[i],
                            active: i == activeIndex,
                            onTap: () => onTap(i),
                          ),
                      ],
                    ),
                  )
                : Row(
                    children: [
                      for (var i = 0; i < tabs.length; i++)
                        Expanded(
                          child: _HubTabStripEntry(
                            tab: tabs[i],
                            active: i == activeIndex,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  )),
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, ColorScheme scheme) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final activeTab = activeIndex >= 0 && activeIndex < tabs.length
        ? tabs[activeIndex]
        : tabs.first;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spaceSm),
      child: Center(
        child: PopupMenuButton<int>(
          initialValue: activeIndex,
          onSelected: onTap,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(activeTab.icon, size: 18, color: scheme.onSurfaceVariant),
              SizedBox(width: t.spaceSm),
              Text(
                activeTab.label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              SizedBox(width: t.spaceXs),
              Icon(
                LucideIcons.chevronDown,
                size: t.iconSizeSmall,
                color: scheme.onSurfaceVariant,
              ),
            ],
          ),
          itemBuilder: (context) => [
            for (var i = 0; i < tabs.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Row(
                  children: [
                    Icon(
                      tabs[i].icon,
                      size: t.iconSizeSmall,
                      color: i == activeIndex
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tabs[i].label,
                      style: TextStyle(
                        fontWeight: i == activeIndex
                            ? FontWeight.w600
                            : FontWeight.w400,
                        color: i == activeIndex
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// A single tab button in [_HubTabStrip].  Visually mimics a Material
/// [Tab] but stays a plain [InkWell] so the parent controls selection
/// state directly.
class _HubTabStripEntry extends StatelessWidget {
  const _HubTabStripEntry({
    required this.tab,
    required this.active,
    required this.onTap,
  });

  final _HubTab tab;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final fg = active ? scheme.primary : scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding:
            EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: t.spaceSm),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? scheme.primary : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 18, color: fg),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                tab.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                  color: fg,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Wraps [HubScreen] in a centered, blur-backed card so it appears as a
/// floating overlay rather than a full-screen page.
class _HubOverlayPage extends StatelessWidget {
  const _HubOverlayPage({required this.client, this.selection});

  final Client client;
  final HubCategorySelection? selection;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Material(
      color: Colors.transparent,
      // Wrap the page body in a fullscreen outside-tap detector so
      // tapping the dimmed background dismisses the hub overlay.  The
      // PageRoute's barrierDismissible flag is not sufficient on its
      // own because the page is laid out over the barrier in the
      // overlay; see [BarrierDismissableOverlay] for the full
      // rationale.  The card itself is wrapped in
      // [BarrierDismissBoundary] so taps inside the hub (including
      // empty padding around widgets) don't dismiss the overlay.
      child: BarrierDismissableOverlay(
        child: BlurBackground(
          overlayColor: Colors.black54,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 680),
              child: Padding(
                padding: EdgeInsets.all(t.spaceXl),
                child: BarrierDismissBoundary(
                  child: Material(
                    elevation: 12,
                    borderRadius: BorderRadius.circular(t.radiusLg),
                    clipBehavior: Clip.antiAlias,
                    color: Theme.of(context).colorScheme.surface,
                    child: HubScreen(client: client, selection: selection),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
