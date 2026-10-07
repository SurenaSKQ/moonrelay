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

  /// The account's own presence, as last reported by [PresenceBus].
  CachedPresence? _presence;
  ValueListenable<CachedPresence?>? _presenceListen;
  VoidCallback? _presenceCallback;

  /// Avatar diameter.
  static const double _kAvatarDiameter = 32;

  /// The presence dot's diameter, and the width of the ring that separates it
  /// from the avatar.
  static const double _kDotDiameter = 12;
  static const double _kDotRing = 2;

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
      child: Material(
        // The rail step, not the app floor.
        //
        // The band sits at the bottom of a pane that is one step lighter, so
        // making it darker again read as a separate surface dropped in rather
        // than as the base the list stands on. The rail step is also what the
        // search field is filled with, which is what makes the footer's
        // presence dot ringable in a colour that is already in the pane.
        color: scheme.surfaceContainerLow,
        child: InkWell(
          // `push`, so the hub covers the window and the chat it was
          // opened from is still underneath when the hub's back button
          // is used. This replaces a modal overlay that existed for
          // exactly that reason.
          onTap: () => context.push(hubPath()),
          // The footer's height is `paneBarHeight`, pinned rather than
          // derived. It used to be whatever its tallest child happened to be,
          // which was the 34px avatar plus 8px of padding above and below: 50.
          // The composer at the other end of the same window is 52, and the two
          // columns meet at a seam, so the sidebar's hairline sat a pixel and a
          // half below the top of the conversation's bottom band and the two
          // rows read as not lining up.
          //
          // The vertical padding is gone and the height is set instead. The
          // avatar still gets its clearance because `Row` centres by default, so
          // now it is guaranteed rather than a consequence of the arithmetic
          // happening to work out. A derived height also meant a long display
          // name could push the row taller and reopen the seam.
          child: SizedBox(
            height: t.paneBarHeight,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: t.spaceSm),
              child: Row(
                children: [
                  _AccountAvatar(
                    diameter: _kAvatarDiameter,
                    loading: _loading,
                    profile: _profile,
                    presenceTint: _presenceTint(scheme),
                    bandColour: scheme.surfaceContainerLow,
                    dotDiameter: _kDotDiameter,
                    dotRing: _kDotRing,
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
                            // One step above the status line, and a step below
                            // the title bar's heading. This is the app's own
                            // name for you and it is not the subject of the
                            // pane, so it does not get the heading's weight.
                            fontSize: 13,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
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
                  // Always visible rather than revealed on hover.
                  //
                  // The row is clickable, so a control that only exists while
                  // the pointer is over it is a control that appears to be
                  // missing from the row it belongs to. It is also the only
                  // route to the hub from here, and the hub is a route rather
                  // than a menu, so there is nothing to be surprised by.
                  Icon(
                    LucideIcons.settings,
                    size: 20,
                    color: scheme.onSurfaceVariant,
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

/// The avatar, with a presence dot at its lower right.
///
/// ## A dot, not a ring
///
/// This used to tint a two-pixel ring *around* the whole avatar with the
/// presence colour. A ring that large stops being a marker and becomes part of
/// the avatar: at thirty-six pixels it is a fifth of the diameter, so a
/// thirty-two pixel avatar inside a coloured ring reads as a badge with a person
/// in it rather than as a person's avatar. It also announced presence twice,
/// once as the ring colour and once as the status line, with nothing tying the
/// two together.
///
/// A small dot at the corner is the convention every other client uses and it
/// survives being small: it says "this account, and this is its state" without
/// competing with the picture. The dot's fill and the status line's colour both
/// come from [PresenceColors], so they cannot disagree.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.diameter,
    required this.loading,
    required this.profile,
    required this.presenceTint,
    required this.bandColour,
    required this.dotDiameter,
    required this.dotRing,
  });

  final double diameter;
  final bool loading;
  final Profile? profile;

  /// Dot fill, taken from the account's presence.
  final Color presenceTint;

  /// The footer's own background.
  ///
  /// The dot is ringed in it so the dot reads as sitting on top of the avatar
  /// rather than as being clipped by the avatar's own edge.
  final Color bandColour;

  final double dotDiameter;
  final double dotRing;

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

    // One ring of extra room on the trailing and bottom edges, so the dot can
    // overhang without the avatar being pushed off the row's padding.
    return SizedBox(
      width: diameter + dotRing,
      height: diameter + dotRing,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          PositionedDirectional(
            start: 0,
            top: 0,
            child: SizedBox(
              width: diameter,
              height: diameter,
              child: ClipOval(child: inner),
            ),
          ),
          PositionedDirectional(
            bottom: 0,
            end: 0,
            child: Container(
              width: dotDiameter,
              height: dotDiameter,
              decoration: BoxDecoration(
                color: presenceTint,
                shape: BoxShape.circle,
                border: Border.all(color: bandColour, width: dotRing),
              ),
            ),
          ),
        ],
      ),
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
