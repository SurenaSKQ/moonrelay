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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/encryption/encryption_overview.dart';
import 'package:moonrelay/src/settings/layout_settings.dart';
import 'package:moonrelay/src/settings/settings_controller.dart';
import 'package:moonrelay/src/settings/display_type.dart';
import 'package:moonrelay/src/settings/theme.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';

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
    _categories = [
      _HubCategory(
        label: 'Accounts',
        icon: LucideIcons.users,
        isExpandable: false,
      ),
      _HubCategory(
        label:
            AppLocalizations.of(context)?.ownProfileDescriptor ?? 'My Profile',
        icon: LucideIcons.user,
        isExpandable: false,
      ),
      _HubCategory(
        label: 'App Settings',
        icon: LucideIcons.settings,
        isExpandable: true,
        items: const [
          _HubNavigationItem(
            label: 'Appearance',
            icon: LucideIcons.palette,
          ),
          _HubNavigationItem(
            label: 'Layout',
            icon: LucideIcons.layoutDashboard,
          ),
          _HubNavigationItem(
            label: 'Encryption & Security',
            icon: LucideIcons.shield,
          ),
          _HubNavigationItem(
            label: 'Chat',
            icon: LucideIcons.messageSquare,
          ),
        ],
      ),
    ];
  }

  int get categoryCount => _categories.length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Hub',
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
        return const _AccountsPage();
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
        return const Center(child: Text('Select a category'));
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
  const _AccountsPage();

  @override
  Widget build(BuildContext context) {
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
                'Accounts',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your connected Matrix accounts',
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
                      CircleAvatar(
                        radius: 28,
                        backgroundColor: theme.colorScheme.primaryContainer,
                        child: Text(
                          initials,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? 'Unknown',
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

class _MyProfilePage extends StatelessWidget {
  const _MyProfilePage({required this.client});
  final Client client;

  @override
  Widget build(BuildContext context) {
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
                  profile?.avatarUrl == null
                      ? CircleAvatar(
                          radius: 40,
                          backgroundColor: theme.colorScheme.primaryContainer,
                          child: Text(
                            (profile?.displayName ?? profile?.userId ?? '?')
                                .toUpperCase()
                                .split(RegExp(' +'))
                                .map((s) => s[0])
                                .take(2)
                                .join(),
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onPrimaryContainer,
                            ),
                          ),
                        )
                      : AvatarFromUriOrFallbackImage(
                          client: client,
                          avatarUri: profile!.avatarUrl,
                          radius: 40,
                        ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.displayName ?? 'You',
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
                'Display Name',
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
                  profile?.displayName ?? 'Not set',
                  style: TextStyle(
                    fontSize: 16,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── User ID (read-only) ──────────────────────────────
              Text(
                'User ID',
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
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text(
          'App Settings',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Customize your experience',
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Appearance',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Control the look and feel of the app',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Theme mode
              _SettingsSection(
                title: 'Theme mode',
                children: [
                  RadioGroup<ThemeMode>(
                    groupValue: controller.themeMode,
                    onChanged: (v) => controller.updateThemeMode(v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<ThemeMode>(
                          title: const Text('System'),
                          value: ThemeMode.system,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Light'),
                          value: ThemeMode.light,
                        ),
                        RadioListTile<ThemeMode>(
                          title: const Text('Dark'),
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
                title: 'Colour theme',
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
                                Text(option.label),
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

              // Use system titlebar
              _SettingsSection(
                title: 'Use system titlebar',
                children: [
                  SwitchListTile(
                    title: const Text('Enable'),
                    subtitle: const Text(
                      'Use the native window title bar instead of the custom one',
                    ),
                    value: controller.useSystemTitlebar,
                    onChanged: (v) => controller.updateUseOfSystemTitlebar(v),
                    secondary: const Icon(LucideIcons.monitor),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Chat display type
              _SettingsSection(
                title: 'Chat display type',
                children: [
                  RadioGroup<DisplayType>(
                    groupValue: controller.displayType,
                    onChanged: (v) => controller.updateDisplayType(v!),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        RadioListTile<DisplayType>(
                          title: Text(DisplayType.modern.label),
                          value: DisplayType.modern,
                        ),
                        RadioListTile<DisplayType>(
                          title: Text(DisplayType.irc.label),
                          value: DisplayType.irc,
                        ),
                        RadioListTile<DisplayType>(
                          title: Text(DisplayType.bubbles.label),
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Layout',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Customize the arrangement of UI panels',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),

              // Left sidebar
              _SettingsSection(
                title: 'Left sidebar',
                children: [
                  SwitchListTile(
                    title: const Text('Visible'),
                    subtitle: const Text(
                      'Show or hide the left sidebar',
                    ),
                    value: controller.leftSidebarVisible,
                    onChanged: (v) => controller.setLeftSidebarVisible(v),
                    secondary: const Icon(LucideIcons.panelLeft),
                  ),
                  if (controller.leftSidebarVisible) ...[
                    ListTile(
                      title: const Text('Content'),
                      subtitle: Text(
                        controller.leftPaneChoice.label,
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
                                child: Text(c.label),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ListTile(
                      title: const Text('Width'),
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
                      title: const Text('Content'),
                      subtitle: Text(
                        controller.rightPaneChoice.label,
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
                                child: Text(c.label),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    ListTile(
                      title: const Text('Width'),
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
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Chat',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Timeline and message display options',
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _SettingsSection(
                title: 'State events',
                children: [
                  SwitchListTile(
                    title: const Text('Show state events'),
                    subtitle: const Text(
                      'Display join/leave/room changes in the timeline',
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
