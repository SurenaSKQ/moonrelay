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
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';

/// A compact bar showing the user's own profile: avatar, display name,
/// and Matrix ID: intended for the bottom of the sidebar pane.
///
/// Loads the profile once on creation and caches the result so that
/// ancestor rebuilds do not trigger repeated network requests.
class OwnProfileBar extends StatefulWidget {
  const OwnProfileBar({super.key, required this.client});

  final Client client;

  @override
  State<OwnProfileBar> createState() => _OwnProfileBarState();
}

class _OwnProfileBarState extends State<OwnProfileBar> {
  Profile? _profile;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    try {
      final profile =
          await widget.client.getProfileFromUserId(widget.client.userID!);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return _loadingIndicator(context);
    if (_error != null || _profile == null) return _errorIndicator(context);
    return _profileBar(context, _profile!);
  }

  // ── Loading state ───────────────────────────────────────────────────────

  Widget _loadingIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
          SizedBox(width: t.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 80,
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(t.radiusXs),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  width: 120,
                  height: 10,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(t.radiusXs),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Error state ─────────────────────────────────────────────────────────

  Widget _errorIndicator(BuildContext context) {
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;
    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: theme.colorScheme.errorContainer,
            child: Icon(
              Icons.error_outline,
              size: 22,
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
          SizedBox(width: t.spaceMd),
          Flexible(
            child: Text(
              widget.client.userID ?? 'Unknown',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // ── Loaded profile ──────────────────────────────────────────────────────

  Widget _profileBar(BuildContext context, Profile profile) {
    final theme = Theme.of(context);
    final t = MoonrelayThemeExtension.of(context).tokens;
    final initials = _extractInitials(
      profile.displayName ?? profile.userId,
    );

    return Container(
      padding: EdgeInsets.symmetric(horizontal: t.spaceLg, vertical: 14),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Avatar (or initials fallback)
          if (profile.avatarUrl != null)
            AvatarFromUriOrFallbackImage(
              client: widget.client,
              avatarUri: profile.avatarUrl,
              radius: 20,
            )
          else
            CircleAvatar(
              radius: 20,
              backgroundColor: theme.colorScheme.primary,
              child: Text(
                initials,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onPrimary,
                ),
              ),
            ),
          SizedBox(width: t.spaceMd),

          // Display name and user ID
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.displayName ?? 'You',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  profile.userId,
                  style: TextStyle(
                    fontSize: 13,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Extract up to 2 uppercase initials from a name.
  static String _extractInitials(String name) {
    return name
        .toUpperCase()
        .split(RegExp(r'\s+'))
        .where((s) => s.isNotEmpty)
        .map((s) => s[0])
        .take(2)
        .join();
  }
}
