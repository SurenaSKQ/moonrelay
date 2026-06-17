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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/logs_page.dart';
import 'package:moonrelay/src/screens/encryption/encryption_overview.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/helpers/log_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Data model for hub navigation items
// ─────────────────────────────────────────────────────────────────────────────

/// A single selectable entry in the hub's category sidebar.
class _HubNavigationItem {
  final String label;
  final IconData icon;

  const _HubNavigationItem({
    required this.label,
    required this.icon,
  });
}

/// A category group that can contain sub-items (e.g. App Settings > Appearance).
class _HubCategory {
  final String label;
  final IconData icon;
  final List<_HubNavigationItem> items;
  final bool isExpandable;

  const _HubCategory({
    required this.label,
    required this.icon,
    this.items = const [],
    this.isExpandable = false,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// The main Hub screen — two-column layout
// ─────────────────────────────────────────────────────────────────────────────

class HubScreen extends StatefulWidget {
  const HubScreen({super.key, required this.client});
  final Client client;

  @override
  State<HubScreen> createState() => _HubScreenState();
}

class _HubScreenState extends State<HubScreen> {
  // Index tracking: which top-level category and which sub-item (if any).
  int _selectedCategoryIndex = 0;
  int _selectedSubItemIndex = -1;
  final Set<int> _expandedCategories = {};

  // ── Category definitions ─────────────────────────────────────────────────

  List<_HubCategory> _categories = [];

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
    }
  }

  void _buildCategories() {
    final l10n = AppLocalizations.of(context)!;
    _categories = [
      _HubCategory(
        label: l10n.accounts,
        icon: LucideIcons.users,
        isExpandable: false,
      ),
      _HubCategory(
        label: l10n.ownProfileDescriptor,
        icon: LucideIcons.user,
        isExpandable: false,
      ),
      _HubCategory(
        label: l10n.appSettings,
        icon: LucideIcons.settings,
        isExpandable: true,
        items: [
          _HubNavigationItem(
            label: l10n.appearance,
            icon: LucideIcons.palette,
          ),
          _HubNavigationItem(
            label: l10n.layout,
            icon: LucideIcons.layoutDashboard,
          ),
          _HubNavigationItem(
            label: l10n.encryptionAndSecurity,
            icon: LucideIcons.shield,
          ),
          _HubNavigationItem(
            label: l10n.chatSettings,
            icon: LucideIcons.messageSquare,
          ),
          _HubNavigationItem(
            label: l10n.network,
            icon: LucideIcons.activity,
          ),
          _HubNavigationItem(
            label: l10n.logs,
            icon: LucideIcons.fileText,
          ),
          _HubNavigationItem(
            label: l10n.backgroundAndTray,
            icon: LucideIcons.minimize2,
          ),
        ],
      ),
    ];
  }

  int get categoryCount => _categories.length;

  Future<void> _logout() async {
    final client = Provider.of<Client>(context, listen: false);
    final log = Provider.of<Logger>(context, listen: false);
    final logService = context.read<LogService>();
    final enc = context.read<EncryptionService>();
    final l10n = AppLocalizations.of(context)!;
    try {
      await enc.onLogout();
      await client.logout();
      // Wipe all log files now that the session has been torn down.
      await logService.wipeLogs();
      if (!mounted) return;
      context.go('/');
    } catch (e) {
      log.e(
        'Logout error',
        error: e,
        time: DateTime.now(),
        stackTrace: StackTrace.current,
      );
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
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Category sidebar ──────────────────────────────────────
            _CategorySidebar(
              categories: _categories,
              selectedIndex: _selectedCategoryIndex,
              selectedSubIndex: _selectedSubItemIndex,
              expanded: _expandedCategories,
              onCategoryTap: _onCategoryTap,
              onSubItemTap: _onSubItemTap,
              onExpansionToggle: _onExpansionToggle,
            ),

            // ── Vertical divider ─────────────────────────────────────
            VerticalDivider(
              width: 1,
              thickness: 1,
              color: Theme.of(context).dividerColor,
            ),

            // ── Content area ─────────────────────────────────────────
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
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

    // Navigate to the encryption overview when that item is tapped.
    if (catIndex == 2 && subIndex == 2) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const EncryptionOverviewScreen(),
        ),
      );
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

  Widget _buildContent() {
    final l10n = AppLocalizations.of(context)!;
    final cat = _categories[_selectedCategoryIndex];

    if (cat.isExpandable && _selectedSubItemIndex >= 0) {
      // Render a sub-item page.
      final subItem = cat.items[_selectedSubItemIndex];
      return _SubPageHeader(
        title: subItem.label,
        child: _buildSubItemContent(_selectedCategoryIndex, subItem),
      );
    }

    // Render a top-level category page.
    switch (_selectedCategoryIndex) {
      case 0:
        return _AccountsPage(onLogout: _logout);
      case 1:
        return _MyProfilePage(client: widget.client);
      case 2:
        // App settings overview — show sub-items as a quick menu.
        return _SubPageHeader(
          title: cat.label,
          child: _AppSettingsOverview(
            items: cat.items,
            onItemTap: (i) {
              setState(() {
                _selectedSubItemIndex = i;
                _expandedCategories.add(2);
              });
            },
          ),
        );
      default:
        return Center(child: Text(l10n.selectCategory));
    }
  }

  Widget _buildSubItemContent(int categoryIndex, _HubNavigationItem item) {
    if (categoryIndex == 2) {
      // App settings sub-items.
      switch (_selectedSubItemIndex) {
        case 0:
          return _AppearanceSettings();
        case 1:
          return _LayoutSettings();
        case 3:
          return _ChatSettings();
        case 4:
          return _NetworkSettings();
        case 5:
          return const LogsPage();
        case 6:
          return _BackgroundSettings();
        default:
          return const SizedBox.shrink();
      }
    }
    return const SizedBox.shrink();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Sidebar
// ─────────────────────────────────────────────────────────────────────────────

class _CategorySidebar extends StatelessWidget {
  final List<_HubCategory> categories;
  final int selectedIndex;
  final int selectedSubIndex;
  final Set<int> expanded;
  final void Function(int index) onCategoryTap;
  final void Function(int categoryIndex, int itemIndex) onSubItemTap;
  final void Function(int index) onExpansionToggle;

  const _CategorySidebar({
    required this.categories,
    required this.selectedIndex,
    required this.selectedSubIndex,
    required this.expanded,
    required this.onCategoryTap,
    required this.onSubItemTap,
    required this.onExpansionToggle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 240,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            color: theme.colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Text(
              'Categories',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const Divider(height: 1),
          // Scrollable list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: categories.length,
              itemBuilder: (context, index) {
                return _buildCategoryTile(context, theme, index);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryTile(
    BuildContext context,
    ThemeData theme,
    int index,
  ) {
    final cat = categories[index];
    final bool isSelected =
        selectedIndex == index && (selectedSubIndex < 0 || !cat.isExpandable);
    final bool isExpanded = expanded.contains(index);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Category header ────────────────────────────────────────
        InkWell(
          onTap: cat.isExpandable
              ? () => onExpansionToggle(index)
              : () => onCategoryTap(index),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? theme.colorScheme.primaryContainer.withValues(alpha: 0.4)
                  : null,
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: theme.colorScheme.primary,
                        width: 3,
                      ),
                    )
                  : null,
            ),
            child: Row(
              children: [
                Icon(
                  cat.icon,
                  size: 20,
                  color: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    cat.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w400,
                      color: isSelected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                ),
                if (cat.isExpandable)
                  Icon(
                    isExpanded
                        ? LucideIcons.chevronDown
                        : LucideIcons.chevronRight,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
              ],
            ),
          ),
        ),

        // ── Sub-items (when expanded) ─────────────────────────────
        if (cat.isExpandable && isExpanded)
          ...List.generate(cat.items.length, (subIndex) {
            final subItem = cat.items[subIndex];
            final bool isSubSelected =
                selectedIndex == index && selectedSubIndex == subIndex;
            return InkWell(
              onTap: () => onSubItemTap(index, subIndex),
              child: Container(
                padding: const EdgeInsets.only(
                  left: 52,
                  right: 16,
                  top: 10,
                  bottom: 10,
                ),
                decoration: BoxDecoration(
                  color: isSubSelected
                      ? theme.colorScheme.secondaryContainer
                          .withValues(alpha: 0.3)
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      subItem.icon,
                      size: 16,
                      color: isSubSelected
                          ? theme.colorScheme.secondary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      subItem.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            isSubSelected ? FontWeight.w600 : FontWeight.w400,
                        color: isSubSelected
                            ? theme.colorScheme.secondary
                            : theme.colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-page header wrapper
// ─────────────────────────────────────────────────────────────────────────────

class _SubPageHeader extends StatelessWidget {
  final String title;
  final Widget child;

  const _SubPageHeader({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: theme.colorScheme.surfaceContainerHighest,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Accounts Page
// ─────────────────────────────────────────────────────────────────────────────

class _AccountsPage extends StatelessWidget {
  const _AccountsPage({required this.onLogout});

  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final client = Provider.of<Client>(context, listen: false);
    final theme = Theme.of(context);

    return FutureBuilder<Profile>(
      future: client.getProfileFromUserId(client.userID!),
      builder: (context, snapshot) {
        final profile = snapshot.data;
        final initials = (profile?.displayName ?? client.userID ?? '?')
            .toUpperCase()
            .split(RegExp(' +'))
            .map((s) => s[0])
            .take(2)
            .join();

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.accounts,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.manageAccounts,
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // ── Account card ─────────────────────────────────────────
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.dividerColor,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      profile?.avatarUrl == null
                          ? CircleAvatar(
                              radius: 28,
                              backgroundColor:
                                  theme.colorScheme.primaryContainer,
                              child: Text(
                                initials,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onPrimaryContainer,
                                ),
                              ),
                            )
                          : AvatarFromUriOrFallbackImage(
                              client: client,
                              avatarUri: profile!.avatarUrl,
                              radius: 28,
                            ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? l10n.unknown,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              client.userID ?? '',
                              style: TextStyle(
                                fontSize: 13,
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        LucideIcons.checkCircle2,
                        color: Colors.green,
                        size: 22,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── Sign-out section ─────────────────────────────────────
              Text(
                l10n.sessions,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 12),

              // An account row with a sign-out action (future-proofed
              // for multi-account — each account gets its own row).
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: theme.dividerColor,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 22,
                      backgroundColor: theme.colorScheme.errorContainer,
                      child: Icon(
                        LucideIcons.logOut,
                        size: 20,
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                    title: Text(
                      l10n.logOut,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.error,
                      ),
                    ),
                    subtitle: Text(
                      client.userID ?? '',
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Icon(
                      LucideIcons.chevronRight,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    onTap: onLogout,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// My Profile Page
// ─────────────────────────────────────────────────────────────────────────────

class _MyProfilePage extends StatefulWidget {
  const _MyProfilePage({required this.client});
  final Client client;

  @override
  State<_MyProfilePage> createState() => _MyProfilePageState();
}

class _MyProfilePageState extends State<_MyProfilePage> {
  bool _uploadingAvatar = false;

  /// Opens a file picker for images, uploads the selected file as the
  /// user's avatar, and triggers a UI refresh.
  Future<void> _changeAvatar() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) return;

    setState(() => _uploadingAvatar = true);

    try {
      await widget.client.uploadContent(
        bytes,
        filename: file.name,
        contentType:
            file.extension != null ? 'image/${file.extension}' : 'image/png',
      );
      await widget.client.setAvatar(MatrixFile(
        bytes: bytes,
        name: file.name,
      ));

      if (!mounted) return;
      setState(() => _uploadingAvatar = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.done),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _uploadingAvatar = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppLocalizations.of(context)!.error}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final client = widget.client;
    return FutureBuilder<Profile>(
      future: client.getProfileFromUserId(client.userID!),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const LoadingScreen();
        }
        final profile = snapshot.data;
        final theme = Theme.of(context);

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar + name header
              Row(
                children: [
                  // Avatar with change overlay
                  GestureDetector(
                    onTap: _uploadingAvatar ? null : _changeAvatar,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Stack(
                        children: [
                          profile?.avatarUrl == null
                              ? CircleAvatar(
                                  radius: 40,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Text(
                                    (profile?.displayName ??
                                            profile?.userId ??
                                            '?')
                                        .toUpperCase()
                                        .split(RegExp(' +'))
                                        .map((s) => s[0])
                                        .take(2)
                                        .join(),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color:
                                          theme.colorScheme.onPrimaryContainer,
                                    ),
                                  ),
                                )
                              : AvatarFromUriOrFallbackImage(
                                  client: client,
                                  avatarUri: profile!.avatarUrl,
                                  radius: 40,
                                ),
                          // Upload overlay
                          if (_uploadingAvatar)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  LucideIcons.camera,
                                  size: 14,
                                  color: theme.colorScheme.onPrimary,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? l10n.unknown,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile?.userId ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.profilePageTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),

              // ── Display Name ──────────────────────────────────────
              Text(
                l10n.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  profile?.displayName ?? l10n.notSet,
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── User ID (read-only) ──────────────────────────────
              Text(
                l10n.userIDLabel,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  profile?.userId ?? '',
                  style: TextStyle(
                    fontSize: 14,
                    fontFamily: 'JetBrainsMono',
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Network Settings
// ─────────────────────────────────────────────────────────────────────────────

class _NetworkSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final scheme = Theme.of(context).colorScheme;
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.network,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.networkDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: l10n.statusBarSection,
                children: [
                  SwitchListTile(
                    title: Text(l10n.showStatusBar),
                    subtitle: Text(
                      l10n.showStatusBarDescription,
                    ),
                    value: controller.showStatusBar,
                    onChanged: (v) => controller.updateShowStatusBar(v),
                    secondary: const Icon(LucideIcons.activity, size: 22),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// App Settings overview (when the category itself is selected)
// ─────────────────────────────────────────────────────────────────────────────

class _AppSettingsOverview extends StatelessWidget {
  final List<_HubNavigationItem> items;
  final void Function(int index) onItemTap;

  const _AppSettingsOverview({
    required this.items,
    required this.onItemTap,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          l10n.appSettings,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.customizeExperience,
          style: TextStyle(
            fontSize: 13,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        ...List.generate(items.length, (index) {
          final item = items[index];
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: ListTile(
              leading: Icon(item.icon, size: 24),
              title: Text(
                item.label,
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                ),
              ),
              trailing: const Icon(LucideIcons.chevronRight, size: 20),
              onTap: () => onItemTap(index),
            ),
          );
        }),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Appearance Settings
// ─────────────────────────────────────────────────────────────────────────────

class _AppearanceSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.appearance,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.controlLookAndFeel,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Theme mode
              _SettingsSection(
                title: l10n.themeMode,
                children: [
                  RadioGroup<ThemeMode>(
                    groupValue: controller.themeMode,
                    onChanged: (v) => controller.updateThemeMode(v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.system),
                          value: ThemeMode.system,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.light),
                          value: ThemeMode.light,
                        ),
                        RadioListTile<ThemeMode>(
                          title: Text(l10n.dark),
                          value: ThemeMode.dark,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Colour theme
              _SettingsSection(
                title: l10n.colourTheme,
                children: [
                  RadioGroup<MoonrelayThemeOption>(
                    groupValue: controller.themeOption,
                    onChanged: (v) {
                      if (v != null) controller.updateThemeOption(v);
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final option in MoonrelayThemeOption.values)
                          RadioListTile<MoonrelayThemeOption>(
                            title: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: option.seedColor,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(_localizedThemeOption(option, l10n)),
                              ],
                            ),
                            value: option,
                            dense: true,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chat display type
              _SettingsSection(
                title: l10n.chatDisplayType,
                children: [
                  RadioGroup<DisplayType>(
                    groupValue: controller.displayType,
                    onChanged: (v) => controller.updateDisplayType(v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<DisplayType>(
                          title: Text(l10n.displayModern),
                          value: DisplayType.modern,
                        ),
                        RadioListTile<DisplayType>(
                          title: Text(l10n.displayIrc),
                          value: DisplayType.irc,
                        ),
                        RadioListTile<DisplayType>(
                          title: Text(l10n.displayBubbles),
                          value: DisplayType.bubbles,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Layout Settings
// ─────────────────────────────────────────────────────────────────────────────

class _LayoutSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.layout,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.customizeLayout,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Left sidebar
              _SettingsSection(
                title: l10n.leftSidebar,
                children: [
                  SwitchListTile(
                    title: Text(l10n.visible),
                    subtitle: Text(
                      l10n.showOrHideLeftSidebar,
                    ),
                    value: controller.leftSidebarVisible,
                    onChanged: (v) => controller.setLeftSidebarVisible(v),
                    secondary: const Icon(LucideIcons.panelLeft),
                  ),
                  if (controller.leftSidebarVisible) ...[
                    ListTile(
                      title: Text(l10n.content),
                      subtitle: Text(
                        _localizedLeftPaneChoice(
                            controller.leftPaneChoice, l10n),
                      ),
                      leading: const Icon(LucideIcons.layoutList),
                      trailing: DropdownButton<LeftPaneChoice>(
                        value: controller.leftPaneChoice,
                        onChanged: (v) {
                          if (v != null) {
                            controller.setLeftPaneChoice(v);
                          }
                        },
                        items: LeftPaneChoice.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(_localizedLeftPaneChoice(c, l10n)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ListTile(
                      title: Text(l10n.widthLabel),
                      subtitle: Text(
                        '${controller.leftSidebarWidth.round()} px',
                      ),
                      leading: const Icon(LucideIcons.moveHorizontal),
                      trailing: SizedBox(
                        width: 160,
                        child: Slider(
                          value: controller.leftSidebarWidth,
                          min: 200,
                          max: 600,
                          divisions: 16,
                          label: '${controller.leftSidebarWidth.round()}',
                          onChanged: (v) => controller.setLeftSidebarWidth(v),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Right sidebar
              _SettingsSection(
                title: 'Right sidebar (experimental)',
                children: [
                  SwitchListTile(
                    title: const Text('Visible'),
                    subtitle: const Text(
                      'Show or hide the right sidebar (hidden on medium screens)',
                    ),
                    value: controller.rightSidebarVisible,
                    onChanged: (v) => controller.setRightSidebarVisible(v),
                    secondary: const Icon(LucideIcons.panelRight),
                  ),
                  if (controller.rightSidebarVisible) ...[
                    ListTile(
                      title: Text(l10n.content),
                      subtitle: Text(
                        _localizedRightPaneChoice(
                            controller.rightPaneChoice, l10n),
                      ),
                      leading: const Icon(LucideIcons.layoutList),
                      trailing: DropdownButton<RightPaneChoice>(
                        value: controller.rightPaneChoice,
                        onChanged: (v) {
                          if (v != null) {
                            controller.setRightPaneChoice(v);
                          }
                        },
                        items: RightPaneChoice.values
                            .map(
                              (c) => DropdownMenuItem(
                                value: c,
                                child: Text(_localizedRightPaneChoice(c, l10n)),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ListTile(
                      title: Text(l10n.widthLabel),
                      subtitle: Text(
                        '${controller.rightSidebarWidth.round()} px',
                      ),
                      leading: const Icon(LucideIcons.moveHorizontal),
                      trailing: SizedBox(
                        width: 160,
                        child: Slider(
                          value: controller.rightSidebarWidth,
                          min: 200,
                          max: 500,
                          divisions: 12,
                          label: '${controller.rightSidebarWidth.round()}',
                          onChanged: (v) => controller.setRightSidebarWidth(v),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 16),

              // Header
              _SettingsSection(
                title: 'Header',
                children: [
                  SwitchListTile(
                    title: const Text('Reversed header'),
                    subtitle: const Text(
                      'Window buttons on the left, title on the right',
                    ),
                    value: controller.headerReversed,
                    onChanged: (v) => controller.updateHeaderReversed(v),
                    secondary: const Icon(LucideIcons.arrowLeftRight),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat Settings
// ─────────────────────────────────────────────────────────────────────────────

class _ChatSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.chatSettings,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.timelineAndMessages,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: l10n.stateEventsSection,
                children: [
                  SwitchListTile(
                    title: Text(l10n.showStateEvents),
                    subtitle: Text(
                      l10n.showStateEventsDescription,
                    ),
                    value: controller.showStateEvents,
                    onChanged: (v) => controller.updateShowStateEvents(v),
                    secondary: const Icon(Icons.info_outline),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Background & Tray Settings
// ─────────────────────────────────────────────────────────────────────────────

class _BackgroundSettings extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<SettingsController>(
      builder: (context, controller, _) {
        final l10n = AppLocalizations.of(context)!;
        final scheme = Theme.of(context).colorScheme;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.backgroundAndTray,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.backgroundAndTrayDescription,
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Show tray icon
              _SettingsSection(
                title: l10n.systemTray,
                children: [
                  SwitchListTile(
                    title: Text(l10n.showTrayIcon),
                    subtitle: Text(l10n.showTrayIconDescription),
                    value: controller.showTrayIcon,
                    onChanged: (v) => controller.updateShowTrayIcon(v),
                    secondary: const Icon(LucideIcons.minimize2, size: 22),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Close to tray
              _SettingsSection(
                title: l10n.windowBehaviour,
                children: [
                  SwitchListTile(
                    title: Text(l10n.closeToTray),
                    subtitle: Text(l10n.closeToTrayDescription),
                    value: controller.closeToTray,
                    onChanged: (v) => controller.updateCloseToTray(v),
                    secondary: const Icon(LucideIcons.xCircle, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.minimizeToTray),
                    subtitle: Text(l10n.minimizeToTrayDescription),
                    value: controller.minimizeToTray,
                    onChanged: (v) => controller.updateMinimizeToTray(v),
                    secondary: const Icon(LucideIcons.minimize, size: 22),
                  ),
                  SwitchListTile(
                    title: Text(l10n.startMinimized),
                    subtitle: Text(l10n.startMinimizedDescription),
                    value: controller.startMinimized,
                    onChanged: controller.showTrayIcon
                        ? (v) => controller.updateStartMinimized(v)
                        : null,
                    secondary: const Icon(LucideIcons.play, size: 22),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings section helper
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSection extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _SettingsSection({
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

// ── Localization helpers ────────────────────────────────────────────────────

String _localizedThemeOption(
    MoonrelayThemeOption option, AppLocalizations l10n) {
  switch (option) {
    case MoonrelayThemeOption.indigo:
      return l10n.themeDefault;
    case MoonrelayThemeOption.oceanBlue:
      return l10n.themeOceanBlue;
    case MoonrelayThemeOption.midnightSlate:
      return l10n.themeMidnightSlate;
    case MoonrelayThemeOption.crimson:
      return l10n.themeCrimson;
    case MoonrelayThemeOption.amber:
      return l10n.themeAmber;
    case MoonrelayThemeOption.steel:
      return l10n.themeSteel;
    case MoonrelayThemeOption.sky:
      return l10n.themeSky;
  }
}

String _localizedLeftPaneChoice(LeftPaneChoice choice, AppLocalizations l10n) {
  switch (choice) {
    case LeftPaneChoice.rooms:
      return l10n.paneRooms;
    case LeftPaneChoice.spaces:
      return l10n.paneSpaces;
    case LeftPaneChoice.friends:
      return l10n.paneFriends;
    case LeftPaneChoice.none:
      return l10n.paneHidden;
  }
}

String _localizedRightPaneChoice(
    RightPaneChoice choice, AppLocalizations l10n) {
  switch (choice) {
    case RightPaneChoice.none:
      return l10n.paneNone;
    case RightPaneChoice.roomInfo:
      return l10n.paneRoomInfo;
    case RightPaneChoice.members:
      return l10n.paneMembers;
  }
}
