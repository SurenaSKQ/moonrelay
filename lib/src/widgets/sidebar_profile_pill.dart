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
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/screens/hub_screen.dart';
import 'package:moonrelay/src/widgets/sync_status_pill.dart';

/// User profile pill shown at the top of the navigation sidebar.
///
/// Shows the user's avatar, display name, and a [SyncStatusPill] inside a
/// highlighted container.  Tapping navigates to the Hub/profile screen.
class SidebarProfilePill extends StatefulWidget {
  const SidebarProfilePill({super.key});

  @override
  State<SidebarProfilePill> createState() => _SidebarProfilePillState();
}

class _SidebarProfilePillState extends State<SidebarProfilePill> {
  Profile? _profile;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final client = Provider.of<Client>(context, listen: false);
      final profile = await client.getProfileFromUserId(client.userID!);
      if (mounted) {
        setState(() {
          _profile = profile;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final displayName = _profile?.displayName ??
        Provider.of<Client>(context, listen: false).userID ??
        '';

    return GestureDetector(
      onTap: () => showHubOverlay(
        context,
        selection: const HubCategorySelection(categoryKey: 'profile'),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildAvatar(scheme),
            const SizedBox(width: 10),
            if (!_loading)
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    const SyncStatusPill(),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme scheme) {
    if (_loading) {
      return CircleAvatar(
        radius: 14,
        backgroundColor: scheme.surfaceContainerHighest,
      );
    }

    final avatarUrl = _profile?.avatarUrl;
    if (avatarUrl != null) {
      final client = Provider.of<Client>(context, listen: false);
      return FutureBuilder<Uri>(
        future: withTimeoutOrFallback(
          () => avatarUrl.getThumbnailUri(
            client,
            width: 28,
            height: 28,
          ),
          timeout: kDefaultTimeout,
          fallback: avatarUrl,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            return CircleAvatar(
              radius: 14,
              backgroundImage: NetworkImage(
                snapshot.data.toString(),
                headers: {
                  'authorization': 'Bearer ${client.accessToken}',
                },
              ),
              backgroundColor: scheme.surfaceContainerHighest,
              onBackgroundImageError: (_, __) {},
            );
          }
          return CircleAvatar(
            radius: 14,
            backgroundColor: scheme.surfaceContainerHighest,
          );
        },
      );
    }

    final initials = _initials(
      _profile?.displayName ??
          Provider.of<Client>(context, listen: false).userID ??
          '?',
    );
    return CircleAvatar(
      radius: 14,
      backgroundColor: scheme.primary,
      child: Text(
        initials,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimary,
        ),
      ),
    );
  }

  static String _initials(String name) {
    return name
        .toUpperCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join();
  }
}
