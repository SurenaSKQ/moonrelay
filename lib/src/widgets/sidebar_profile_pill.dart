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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/presence_bus.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/router_paths.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/theme/presence_colors.dart';

/// How long the hover lift takes. Short enough to feel like the pointer
/// arriving and not like an animation being performed.
const Duration _kHoverDuration = Duration(milliseconds: 140);

/// The signed-in account, pinned to the foot of the navigation sidebar.
///
/// Two lines: the display name and a presence status.
///
/// The status line used to be the localpart. That is a fact about your
/// account identifier, not about you, and it never changed: this is the one
/// place in the app that could answer "am I showing up as online?", and it
/// answered with a string instead. Presence is the honest second line, and
/// the localpart is still reachable from the profile page.
///
/// Not a card. As a footer, a bordered rectangle with two shadow layers is
/// one container too many; it is a flat band on the app floor, one step
/// darker than the room list above it.
///
/// Deliberately still shows no sync indicator. It used to carry one, which
/// was redundant (the room header reports the same thing) and actively
/// misleading: a connection status under your own name reads as your own
/// presence, which this row now actually reports.
class SidebarProfilePill extends StatefulWidget {
  const SidebarProfilePill({super.key});

  @override
  State<SidebarProfilePill> createState() => _SidebarProfilePillState();
}

class _SidebarProfilePillState extends State<SidebarProfilePill> {
  Profile? _profile;
  bool _loading = true;
  bool _hovered = false;

  /// The account's own presence, as last reported by [PresenceBus].
  CachedPresence? _presence;
  ValueListenable<CachedPresence?>? _presenceListen;
  VoidCallback? _presenceCallback;

  /// Avatar diameter. A multiple of the 2px ring, so the ring lands on whole
  /// pixels: on an odd diameter it straddles a half pixel and goes soft on
  /// one side, which is the whole reason the ring exists.
  static const double _kAvatarDiameter = 36;

  @override
  void initState() {
    super.initState();
    _fetch();
    _listenToPresence();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The account can change without this widget being rebuilt (a login, an
    // account switch), so the subscription is keyed on the user id rather
    // than set up once.
    _listenToPresence();
  }

  @override
  void dispose() {
    final callback = _presenceCallback;
    final listen = _presenceListen;
    if (callback != null && listen != null) {
      listen.removeListener(callback);
    }
    super.dispose();
  }

  void _listenToPresence() {
    if (!mounted) return;
    final client = Provider.of<Client>(context, listen: false);
    final userId = client.userID;
    if (userId == null) return;

    final bus = Provider.of<PresenceBus?>(context, listen: false);
    if (bus == null) return;

    final listen = bus.listenTo(userId);
    final callback = _presenceCallback;
    if (identical(_presenceListen, listen) && callback != null) {
      // Already subscribed; just take the latest value in case it moved
      // while this widget was being built.
      final latest = listen.value;
      if (latest != _presence) setState(() => _presence = latest);
      return;
    }

    if (callback != null && _presenceListen != null) {
      _presenceListen!.removeListener(callback);
    }
    // The closure is kept, not discarded.
    //
    // This stored `() {}` after adding an *anonymous* closure, so
    // `dispose()` removed a listener that was never added and the real one
    // stayed attached to the bus's `ValueNotifier` for the life of the bus.
    // The bus outlives the sidebar (it is app-wide), so every account switch
    // leaked a `State` object that still had a mounted-check closure on it,
    // and the leak kept the whole sidebar subtree reachable.
    void listener() {
      if (!mounted) return;
      setState(() => _presence = listen.value);
    }

    listen.addListener(listener);
    _presenceListen = listen;
    _presenceCallback = listener;
    _presence = listen.value;
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

  // The identity line moved off the footer's second row. It was the localpart,
// optionally with the homeserver, and it never changed: the only question a
// user has about the row at the bottom of the sidebar is whether they are
// showing up, and that is what the line says now. The full user id is on
// the profile page, which is where a user goes to copy it.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final ext = theme.moonrelay;
    final t = ext.tokens;
    final l10n = AppLocalizations.of(context)!;
    final client = Provider.of<Client>(context, listen: false);
    final userId = client.userID ?? '';
    final displayName = _profile?.displayName ?? userId;

    // The footer's own status line.
    //
    // This used to show the localpart, which is a fact about your account
    // identifier and not about you. Presence is the thing a user checks this
    // row for: it is the one place in the app that answers "am I showing up
    // as online?", and answering it with a string identifier meant the answer
    // was always the same no matter what.
    final presenceLabel = _presenceLabel(l10n);

    // Not a card.
    //
    // The pill used to be a rounded rectangle with a border and two shadow
    // layers, floating in the pane. As a footer that is one container too
    // many: the pane already has an edge, and the footer's job is to be the
    // last thing on the way down, not to be a control sitting in the list.
    // It is now a flat band on the app floor, one step darker than the room
    // list above it, separated by the same hairline as every other pane
    // divider.
    return Semantics(
      button: true,
      label: l10n.myProfile,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: Material(
          color: scheme.surface,
          child: InkWell(
            // `push`, so the hub covers the window and the chat it was
            // opened from is still underneath when the hub's back button
            // is used. This replaces a modal overlay that existed for
            // exactly that reason.
            onTap: () => context.push(hubPath()),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.spaceSm,
                vertical: t.spaceSm,
              ),
              child: Row(
                children: [
                  _AccountAvatar(
                    diameter: _kAvatarDiameter,
                    loading: _loading,
                    profile: _profile,
                    presenceTint: _presenceTint(scheme),
                  ),
                  SizedBox(width: t.spaceSm),
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
                            // One step above a sidebar row's title. This is
                            // the app's own name for you, and it is the
                            // largest text in this pane.
                            fontSize: 15,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.1,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          presenceLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            fontWeight: FontWeight.w400,
                            color: _presenceTextColor(scheme),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: t.spaceXs),
                  // Says where this goes without spending a row on it, and
                  // answers the pointer so the whole row looks live.
                  AnimatedOpacity(
                    opacity: _hovered ? 1.0 : t.opacitySubtle,
                    duration: _kHoverDuration,
                    child: Icon(
                      LucideIcons.settings,
                      size: t.iconSizeSmall,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// The status line under the display name.
  ///
  /// Falls back to the localpart when presence has not arrived, because a
  /// blank line reads as a rendering fault and the localpart is at least
  /// something true.
  String _presenceLabel(AppLocalizations l10n) {
    final userId = Provider.of<Client>(context, listen: false).userID ?? '';
    final colon = userId.indexOf(':');
    final localpart =
        colon <= 0 ? userId : userId.substring(1, colon).replaceFirst('@', '');
    return switch (_presenceType) {
      null => localpart,
      PresenceType.online => l10n.presenceOnline,
      PresenceType.unavailable => l10n.presenceUnavailable,
      _ => l10n.presenceOffline,
    };
  }

  /// The presence type, or `null` when none has arrived.
  ///
  /// Kept as the SDK's own type rather than compared as a string, so an
  /// unrecognised value degrades to "offline" instead of falling through to
  /// the localpart and making the two failure modes look identical.
  PresenceType? get _presenceType => _presence?.presence;

  Color _presenceTint(ColorScheme scheme) {
    final type = _presenceType;
    if (type == null) return scheme.surfaceContainerHigh;
    return PresenceColors.of(scheme, type).forPresence(type);
  }

  Color _presenceTextColor(ColorScheme scheme) {
    final type = _presenceType;
    if (type == null) return scheme.onSurfaceVariant;
    return PresenceColors.of(scheme, type).forPresence(type);
  }
}

/// The avatar, ringed in the footer's own colour so it reads as inset, with
/// a presence dot.
///
/// Without the ring the avatar and the band behind it share an edge and the
/// two merge into one flat rectangle, which is the specific problem with a
/// flat design language: nothing states which element is on top of which.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.diameter,
    required this.loading,
    required this.profile,
    required this.presenceTint,
  });

  final double diameter;
  final bool loading;
  final Profile? profile;

  /// Ring colour. Doubles as the presence signal: the ring is tinted with the
  /// account's presence colour, so the dot and the ring cannot disagree.
  final Color presenceTint;

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
        border: Border.all(color: presenceTint, width: 2),
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
