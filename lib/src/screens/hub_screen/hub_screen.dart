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
        // Mirror the URL when collapsing a category: fall back to
        // the bare `/hub/<key>` so the back button matches what is
        // visible.
        if (_selectedCategoryIndex == index && cat.key != null) {
          _pushHubUrl(cat.key!, null);
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
      // Non-expandable category: push the canonical hub URL so the
      // browser back button tracks selection.
      if (cat.key != null) _pushHubUrl(cat.key!, null);
    }
  }

  void _onSubItemTap(int catIndex, int subIndex) {
    final cat = _categories[catIndex];
    final sub = cat.items[subIndex];
    setState(() {
      _selectedCategoryIndex = catIndex;
      _selectedSubItemIndex = subIndex;
    });
    if (cat.key != null && sub.key != null) {
      _pushHubUrl(cat.key!, sub.key);
    }
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

  /// Renders the content pane for the currently-selected category /
  /// sub-item.  Resolution is by stable key, not by array index, so
  /// reordering or inserting new categories in `_categories` does
  /// not silently misroute.
  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    final cat = _categories[_selectedCategoryIndex];

    // When a sub-item is selected inside an expandable category,
    // render that sub-item's content (handled by key lookup).
    if (cat.isExpandable && _selectedSubItemIndex >= 0) {
      final subItem = cat.items[_selectedSubItemIndex];
      return HubSubPageHeader(
        title: subItem.label,
        child: _buildSubItemContent(subItem.key),
      );
    }

    // Render a top-level category page keyed by the category's stable
    // identifier.
    switch (cat.key) {
      case 'accounts':
        return HubAccountsPage(
          onLogout: _logout,
          onAddAccount: () => context.push('/add-account'),
        );
      case 'profile':
        return HubMyProfilePage(client: widget.client);
      case 'settings':
        // App settings overview — show sub-items as a quick menu.
        return HubSubPageHeader(
          title: cat.label,
          child: HubAppSettingsOverview(
            items: cat.items,
            onItemTap: (i) {
              final catIdx = _indexOfCategory('settings');
              if (catIdx < 0) return;
              setState(() {
                _selectedCategoryIndex = catIdx;
                _selectedSubItemIndex = i;
                _expandedCategories.add(catIdx);
              });
              _pushHubUrl(cat.key!, cat.items[i].key);
            },
          ),
        );
      case 'about':
        return HubAboutPage(client: widget.client);
      default:
        return Center(child: Text(l10n.selectCategory));
    }
  }

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
      default:
        return const SizedBox.shrink();
    }
  }

  /// Look up a category's index by its stable `key`, or `-1` if missing.
  int _indexOfCategory(String key) =>
      _categories.indexWhere((c) => c.key == key);

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
  /// *replace* the room page in the navigator stack — which is exactly
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

// ── Hub overlay ────────────────────────────────────────────────────────────

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

/// Wraps [HubScreen] in a centered, blur-backed card so it appears as a
/// floating overlay rather than a full-screen page.
class _HubOverlayPage extends StatelessWidget {
  const _HubOverlayPage({required this.client, this.selection});

  final Client client;
  final HubCategorySelection? selection;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      // Wrap the page body in a fullscreen outside-tap detector so
      // tapping the dimmed background dismisses the hub overlay.  The
      // PageRoute's barrierDismissible flag is not sufficient on its
      // own because the page is laid out over the barrier in the
      // overlay; see [BarrierDismissableOverlay] for the full
      // rationale.
      child: BarrierDismissableOverlay(
        child: BlurBackground(
          overlayColor: Colors.black54,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900, maxHeight: 680),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Material(
                  elevation: 12,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(context).colorScheme.surface,
                  child: HubScreen(client: client, selection: selection),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
