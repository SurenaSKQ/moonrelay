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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/navigation_state.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

/// A narrow vertical navigation bar that lets users switch between
/// **Home** (direct messages), **All Channels**, and each **Space**
/// they are a member of.
///
/// Modeled after the server list in Discord / Element's space panel.
/// Width is fixed at 68 px.
class NavigationPane extends StatefulWidget {
  const NavigationPane({super.key});

  @override
  State<NavigationPane> createState() => _NavigationPaneState();
}

class _NavigationPaneState extends State<NavigationPane> {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Client client = Provider.of<Client>(context);
    final l10n = AppLocalizations.of(context)!;

    // Collect spaces, sorted by name for consistency.
    final List<Room> spaces = client.rooms.where((r) => r.isSpace).toList()
      ..sort((a, b) => a
          .getLocalizedDisplayname()
          .toLowerCase()
          .compareTo(b.getLocalizedDisplayname().toLowerCase()));

    return Consumer<NavigationState>(
      builder: (context, nav, _) {
        final bool isHome = nav.isHome;
        final bool isAll = nav.isAll;

        return Container(
          width: 68,
          color: theme.colorScheme.surfaceContainerLow,
          child: Column(
            children: [
              const SizedBox(height: 8),

              // ── Home (direct messages) ────────────────────────────
              _NavIconButton(
                icon: LucideIcons.home,
                label: l10n.navigationHome,
                isSelected: isHome,
                onTap: nav.selectHome,
                theme: theme,
              ),

              // ── All Channels ──────────────────────────────────────
              _NavIconButton(
                icon: LucideIcons.messageCircle,
                label: l10n.navigationAll,
                isSelected: isAll,
                onTap: nav.selectAll,
                theme: theme,
              ),

              // ── Separator ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Container(
                  height: 2,
                  width: 32,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurfaceVariant
                        .withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),

              // ── Spaces ────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 4),
                  itemCount: spaces.length,
                  itemBuilder: (context, index) {
                    final Room space = spaces[index];
                    final bool isSelected =
                        nav.isSpace && nav.selectedId == space.id;

                    return _NavIconButton(
                      icon: LucideIcons.folder,
                      label: space.getLocalizedDisplayname(),
                      isSelected: isSelected,
                      onTap: () => nav.selectSpace(space.id),
                      theme: theme,
                      // Use the space avatar if available
                      avatarUri: space.avatar,
                      client: client,
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A single icon button in the navigation pane.
class _NavIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final ThemeData theme;
  final Uri? avatarUri;
  final Client? client;

  const _NavIconButton({
    required this.icon,
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.theme,
    this.avatarUri,
    this.client,
  });

  @override
  Widget build(BuildContext context) {
    final Color selectedColor = theme.colorScheme.primary;
    final Color unselectedColor = theme.colorScheme.onSurfaceVariant;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
      child: Tooltip(
        message: label,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: isSelected
                  ? selectedColor.withValues(alpha: 0.15)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(
                isSelected ? 16 : 12,
              ),
            ),
            child: Center(
              child: avatarUri != null && client != null
                  ? AvatarIcon(
                      uri: avatarUri!,
                      client: client!,
                      size: 28,
                    )
                  : Icon(
                      icon,
                      size: 24,
                      color: isSelected ? selectedColor : unselectedColor,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A small circle avatar for space icons.
class AvatarIcon extends StatelessWidget {
  final Uri uri;
  final Client client;
  final double size;

  const AvatarIcon({
    super.key,
    required this.uri,
    required this.client,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uri>(
      future: withTimeoutOrFallback(
        () => uri.getThumbnailUri(
          client,
          method: ThumbnailMethod.scale,
          width: size.round(),
          height: size.round(),
        ),
        timeout: kDefaultTimeout,
        fallback: uri, // fall through and let NetworkImage try
      ),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return CircleAvatar(
            radius: size / 2,
            backgroundImage: NetworkImage(
              snapshot.data.toString(),
              headers: {
                'authorization': 'Bearer ${client.accessToken}',
              },
            ),
          );
        }
        return CircleAvatar(
          radius: size / 2,
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(
            LucideIcons.folder,
            size: size * 0.6,
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        );
      },
    );
  }
}
