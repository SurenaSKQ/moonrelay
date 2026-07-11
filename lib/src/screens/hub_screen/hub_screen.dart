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
import 'package:moonrelay/src/screens/logs_page.dart';
import 'package:moonrelay/src/screens/encryption/encryption_overview.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/log_service.dart';
import 'package:moonrelay/src/screens/hub_screen/navigation_items.dart';
import 'package:moonrelay/src/screens/hub_screen/category_sidebar.dart';
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
import 'package:moonrelay/src/screens/hub_screen/about_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// The main Hub screen — two-column layout
// ─────────────────────────────────────────────────────────────────────────────

/// A category selection that may be deep-linked into the [HubScreen].
///
/// The hub has internal state for `_selectedCategoryIndex` and
/// `_selectedSubItemIndex`.  When a route specifies a category (and
/// optional sub-item) the screen must mirror that selection into its
/// internal state so the sidebar highlight and content pane agree with
/// the URL.
///
/// The values are stable enough to be passed via GoRouter path
/// parameters rather than query strings, which makes them matchable
/// to specific routes (e.g. `/hub/settings/appearance`).
class HubCategorySelection {
  const HubCategorySelection({this.categoryKey, this.subKey});
  final String? categoryKey;
  final String? subKey;
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
  final Set<int> _expandedCategories = {};

  // ── Category definitions ─────────────────────────────────────────────────

  List<HubCategory> _categories = [];

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_categories.isEmpty) {
      _buildCategories();
      if (_categories.isNotEmpty) {
        _expandedCategories.add(0);
      }
      // Apply initial selection from the route if one was supplied.
      // Defer setState into a microtask if we're mid-build — direct
      // setState() inside didChangeDependencies is technically safe
      // but a few assertion paths disable it.  The simplest robust
      // path is to compare and assign explicitly.
      _applySelection(widget.selection, duringBuild: true);
    }
  }

  @override
  void didUpdateWidget(covariant HubScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // React to the user navigating from another hub path while
    // already on the hub screen.
    if (oldWidget.selection != widget.selection) {
      _applySelection(widget.selection);
    }
  }

  /// Maps a [HubCategorySelection] (category/sub keys) into the
  /// screen's internal indices and expands the matching parent.
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
      subIdx = _categories[catIdx].items
          .indexWhere((s) => s.key == selection.subKey);
    }

    if (catIdx == _selectedCategoryIndex &&
        subIdx == _selectedSubItemIndex) {
      return;
    }

    if (_categories[catIdx].isExpandable) {
      _expandedCategories.add(catIdx);
    }
    if (duringBuild) {
      _selectedCategoryIndex = catIdx;
      _selectedSubItemIndex = subIdx;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {
        _selectedCategoryIndex = catIdx;
        _selectedSubItemIndex = subIdx;
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Category sidebar ─────────────────────────────────
                HubCategorySidebar(
                  categories: _categories,
                  selectedIndex: _selectedCategoryIndex,
                  selectedSubIndex: _selectedSubItemIndex,
                  expanded: _expandedCategories,
                  onCategoryTap: _onCategoryTap,
                  onSubItemTap: _onSubItemTap,
                  onExpansionToggle: _onExpansionToggle,
                ),

                // ── Vertical divider ───────────────────────────────
                VerticalDivider(
                  width: 1,
                  thickness: 1,
                  color: Theme.of(context).dividerColor,
                ),

                // ── Content area ────────────────────────────────────
                Expanded(
                  child: _buildContent(),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  void _onCategoryTap(int index) {
    // Toggle expansion for expandable categories; otherwise just select.
    final cat = _categories[index];
    if (cat.isExpandable) {
      if (_expandedCategories.contains(index)) {
        _expandedCategories.remove(index);
        // If the selected sub-item was in this category, reset.
        if (_selectedCategoryIndex == index) {
          _selectedSubItemIndex = -1;
        }
      } else {
        _expandedCategories.add(index);
      }
      setState(() {});
    } else {
      setState(() {
        _selectedCategoryIndex = index;
        _selectedSubItemIndex = -1;
      });
    }
  }

  void _onSubItemTap(int catIndex, int subIndex) {
    setState(() {
      _selectedCategoryIndex = catIndex;
      _selectedSubItemIndex = subIndex;
    });
  }

  void _onExpansionToggle(int index) {
    if (_expandedCategories.contains(index)) {
      _expandedCategories.remove(index);
    } else {
      _expandedCategories.add(index);
    }
    setState(() {});
  }

  // ── Content routing ─────────────────────────────────────────────────────

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    final cat = _categories[_selectedCategoryIndex];

    if (cat.isExpandable && _selectedSubItemIndex >= 0) {
      // Render a sub-item page.
      final subItem = cat.items[_selectedSubItemIndex];
      return HubSubPageHeader(
        title: subItem.label,
        child: _buildSubItemContent(_selectedCategoryIndex, subItem),
      );
    }

    // Render a top-level category page.
    switch (_selectedCategoryIndex) {
      case 0:
        return HubAccountsPage(
          onLogout: _logout,
          onAddAccount: () => context.push('/add-account'),
        );
      case 1:
        return HubMyProfilePage(client: widget.client);
      case 2:
        // App settings overview — show sub-items as a quick menu.
        return HubSubPageHeader(
          title: cat.label,
          child: HubAppSettingsOverview(
            items: cat.items,
            onItemTap: (i) {
              setState(() {
                _selectedSubItemIndex = i;
                _expandedCategories.add(2);
              });
            },
          ),
        );
      case 3:
        return HubAboutPage(client: widget.client);
      default:
        return Center(child: Text(l10n.selectCategory));
    }
  }

  Widget _buildSubItemContent(int categoryIndex, HubNavigationItem item) {
    if (categoryIndex == 2) {
      // App settings sub-items.
      switch (_selectedSubItemIndex) {
        case 0:
          return const HubAppearanceSettings();
        case 1:
          return const HubLayoutSettings();
        case 2:
          return const EncryptionOverviewScreen(embedded: true);
        case 3:
          return const HubChatSettings();
        case 4:
          return const HubNetworkSettings();
        case 5:
          return const LogsPage();
        case 6:
          return const HubBackgroundSettings();
        case 7:
          return const HubNotificationSettings();
        case 8:
          return const HubPrivacySettings();
        case 9:
          return const HubStorageSettings();
        case 10:
          return const HubAdvancedSettings();
        case 11:
          return const HubBlockedUsersPage();
        default:
          return const SizedBox.shrink();
      }
    }
    return const SizedBox.shrink();
  }
}

// ── Hub overlay ────────────────────────────────────────────────────────────

/// Opens the hub screen as a modal overlay on top of the current
/// navigation stack (like the command palette), preserving the
/// dashboard state underneath.
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
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, __, ___) => HubScreen(client: client, selection: selection),
    ),
  );
}
