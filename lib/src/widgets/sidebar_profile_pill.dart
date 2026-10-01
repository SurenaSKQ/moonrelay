// Part of Moonrelay, a matrix protocol client.
// Copyright (C) 2025 Surena Karimpour Ghannadi
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU Affero General Public License as
// published by the Free Software Foundation, either version 3 of the
// License, or (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public
// License along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// How long the hover lift takes. Short enough to feel like the pointer
/// arriving and not like an animation being performed.
const Duration _kHoverDuration = Duration(milliseconds: 140);

/// The signed-in account, as a card at the foot of the navigation sidebar.
///
/// This is the one lifted object in the sidebar. Everything above it is a
/// flat fill on a flat surface, which is what lets this read as an object
/// rather than as the last row of a list. It was moved to the bottom
/// earlier and it looked out of place there as a plain tinted strip: the
/// move was right, the treatment was not.
///
/// Two lines, not one. A Matrix client is full of people whose display
/// names are identical to somebody else's, and the localpart is what tells
/// two of them apart. It was not on screen at all before, and on a
/// professional client it belongs where the account is.
///
/// Deliberately still shows no sync indicator. It used to carry one, which
/// was redundant (the room header reports the same thing) and actively
/// misleading: a connection status under your own name reads as your own
/// presence, and `PresenceService` publishes a real one.
class SidebarProfilePill extends StatefulWidget {
  const SidebarProfilePill({super.key});

  @override
  State<SidebarProfilePill> createState() => _SidebarProfilePillState();
}

class _SidebarProfilePillState extends State<SidebarProfilePill> {
  Profile? _profile;
  bool _loading = true;
  bool _hovered = false;

  /// Avatar diameter. A multiple of the 2px ring, so the ring lands on whole
  /// pixels: on an odd diameter it straddles a half pixel and goes soft on
  /// one side, which is the whole reason the ring exists.
  static const double _kAvatarDiameter = 36;

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

  /// The identity line under the display name.
  ///
  /// Drops the homeserver when it is long enough to be noise. A 300px card
  /// ellipsises `@alice:very-long-homeserver.example.com` before the useful
  /// half is readable, while the localpart on its own almost never does.
  String _identityLine() {
    final userId = Provider.of<Client>(context, listen: false).userID ?? '';
    final colon = userId.indexOf(':');
    if (colon <= 0) return userId;
    final localpart = userId.substring(1, colon);
    final domain = userId.substring(colon + 1);
    return domain.length > 18 ? localpart : '$localpart:$domain';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final displayName = _profile?.displayName ??
        Provider.of<Client>(context, listen: false).userID ??
        '';

    final radius = BorderRadius.circular(t.radiusLg);

    return Semantics(
      button: true,
      label: l10n.myProfile,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: AnimatedContainer(
          duration: _kHoverDuration,
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: _hovered
                ? scheme.surfaceContainerHighest
                : scheme.surfaceContainerHigh,
            borderRadius: radius,
            border: Border.all(
              color: scheme.outlineVariant.withValues(alpha: t.opacitySubtle),
            ),
            // The lift answers the pointer. Motion that reacts to something
            // the person did is welcome; motion that plays on its own is
            // noise, and this pane has enough of it already.
            boxShadow: _hovered ? t.shadowMedium : t.shadowLow,
          ),
          clipBehavior: Clip.antiAlias,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              // `push`, so the hub covers the window and the chat it was
              // opened from is still underneath when the hub's back button
              // is used. This replaces a modal overlay that existed for
              // exactly that reason.
              onTap: () => context.push(hubPath()),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
                child: Row(
                  children: [
                    _AccountAvatar(
                      diameter: _kAvatarDiameter,
                      loading: _loading,
                      profile: _profile,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            displayName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              // One step above a sidebar row's title. This
                              // is the app's own name for you, and it is
                              // the largest text in this pane.
                              fontSize: 15,
                              height: 1.2,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            _identityLine(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              height: 1.3,
                              fontWeight: FontWeight.w400,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Says where this goes without spending a row on it.
                    AnimatedOpacity(
                      opacity: _hovered ? 1.0 : 0.4,
                      duration: _kHoverDuration,
                      child: Icon(
                        LucideIcons.chevronRight,
                        size: 14,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The avatar, ringed in the card's own colour so it reads as inset.
///
/// Without the ring the avatar and the card share an edge and the two merge
/// into one flat rectangle, which is the specific problem with a flat
/// design language: nothing states which element is on top of which.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.diameter,
    required this.loading,
    required this.profile,
  });

  final double diameter;
  final bool loading;
  final Profile? profile;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget inner;
    if (loading) {
      inner = CircleAvatar(
        radius: diameter / 2,
        backgroundColor: scheme.surfaceContainerHighest,
      );
    } else if (profile?.avatarUrl != null) {
      inner = _remoteAvatar(context, profile!.avatarUrl!);
    } else {
      inner = _initialsAvatar(context, scheme);
    }

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: scheme.surfaceContainerHigh, width: 2),
      ),
      child: ClipOval(child: inner),
    );
  }

  Widget _remoteAvatar(BuildContext context, Uri avatarUrl) {
    final scheme = Theme.of(context).colorScheme;
    final client = Provider.of<Client>(context, listen: false);
    return FutureBuilder<Uri>(
      future: withTimeoutOrFallback(
        () => avatarUrl.getThumbnailUri(
          client,
          width: diameter.toInt(),
          height: diameter.toInt(),
        ),
        timeout: kDefaultTimeout,
        fallback: avatarUrl,
      ),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return _initialsAvatar(context, scheme);
        return CircleAvatar(
          radius: diameter / 2,
          backgroundImage: NetworkImage(
            snapshot.data.toString(),
            headers: {'authorization': 'Bearer ${client.accessToken}'},
          ),
          backgroundColor: scheme.surfaceContainerHighest,
          onBackgroundImageError: (_, __) {},
        );
      },
    );
  }

  Widget _initialsAvatar(BuildContext context, ColorScheme scheme) {
    final name = profile?.displayName ??
        Provider.of<Client>(context, listen: false).userID ??
        '?';
    return CircleAvatar(
      radius: diameter / 2,
      backgroundColor: scheme.primary,
      child: Text(
        _letters(name),
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimary,
        ),
      ),
    );
  }

  static String _letters(String name) => name
      .toUpperCase()
      .split(RegExp(r'\s+'))
      .where((s) => s.isNotEmpty)
      .map((s) => s[0])
      .take(2)
      .join();
}
