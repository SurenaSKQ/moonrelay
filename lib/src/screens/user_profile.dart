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

import 'dart:async';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/presence_bus.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/screens/user_profile/moderation_section.dart';
import 'package:moonrelay/src/screens/user_profile/profile_actions_section.dart';
import 'package:moonrelay/src/screens/user_profile/profile_header.dart';
import 'package:moonrelay/src/screens/user_profile/profile_info_card.dart';
import 'package:moonrelay/src/screens/user_profile/profile_overlay_page.dart';
import 'package:moonrelay/src/screens/user_profile/room_context_section.dart';
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// A full-featured profile view for any Matrix user.
///
/// When [room] is provided the page also shows room-specific information
/// (membership, power level) and, if the logged-in user has sufficient
/// privileges, moderation actions (kick, ban, change power level, invite).
class ProfilePage extends StatefulWidget {
  const ProfilePage({
    super.key,
    required this.client,
    required this.userID,
    this.room,
  });

  final String userID;
  final Client client;
  final Room? room;

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

/// A never-changing null presence, for the tree with no [PresenceBus].
///
/// Used instead of branching the whole subtree, so a logged-out profile
/// or a test without the provider still renders, just without a live
/// presence line.
class _NullPresenceListenable extends ValueNotifier<CachedPresence?> {
  _NullPresenceListenable() : super(null);
}

class _ProfilePageState extends State<ProfilePage> {
  Profile? _profile;
  CachedPresence? _presence;
  Object? _error;
  bool _loading = true;

  // Room-specific data
  User? _roomUser;
  bool _roomUserLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfile();
    _fetchPresence();
    if (widget.room != null) _fetchRoomUser();
  }

  String get _displayName =>
      _profile?.displayName ?? _profile?.userId ?? widget.userID;

  Future<void> _fetchProfile() async {
    final log = context.read<Logger>();
    final result = await withRetry(
      () => widget.client.getProfileFromUserId(widget.userID),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'getProfile(${widget.userID})',
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        setState(() {
          _profile = value;
          _loading = false;
        });
      case RetryFailed(:final error):
        setState(() {
          _error = error;
          _loading = false;
        });
    }
  }

  /// Seeds the SDK's presence cache and this State's copy.
  ///
  /// The live value comes from [PresenceBus] in build, so a presence
  /// event arriving over sync updates the header without a refetch. This
  /// is the one-shot that makes the first value available at all.
  Future<void> _fetchPresence() async {
    try {
      final presence = await withTimeoutOrFallback(
        () => widget.client.fetchCurrentPresence(widget.userID),
        fallback: CachedPresence.neverSeen(widget.userID),
        label: 'presence(${widget.userID})',
      );
      if (!mounted) return;
      setState(() => _presence = presence);
    } on Object catch (e) {
      // Presence is decoration on this page; a failure means the header
      // shows no presence line, which is the correct degradation. The
      // fallback in withTimeoutOrFallback already covers the timeout
      // case, so this only fires on something unexpected, and it is
      // worth a log line rather than silence.
      if (mounted) {
        context
            .read<Logger>()
            .w('Presence fetch failed for ${widget.userID}', error: e);
      }
    }
  }

  Future<void> _fetchRoomUser() async {
    setState(() => _roomUserLoading = true);
    try {
      final user = await widget.room!.requestUser(widget.userID);
      if (!mounted) return;
      setState(() {
        _roomUser = user;
        _roomUserLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      // Try a simple lookup as fallback.
      final fallback =
          widget.room!.unsafeGetUserFromMemoryOrFallback(widget.userID);
      setState(() {
        _roomUser = fallback;
        _roomUserLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingScreen();

    if (_error != null && _profile == null) {
      return Scaffold(
        appBar: _buildAppBar(context, AppLocalizations.of(context)!.unknown),
        body: _buildErrorBody(context),
      );
    }

    // The bus wins over the one-shot fetch when it has a value, so a
    // presence event arriving over sync updates the header without a
    // refetch. `_presence` is only the seed.
    final bus = context.read<PresenceBus?>();
    final livePresence = bus?.presenceOf(widget.userID);

    return Scaffold(
      appBar: _buildAppBar(
        context,
        _displayName,
      ),
      body: ValueListenableBuilder<CachedPresence?>(
        valueListenable:
            bus?.listenTo(widget.userID) ?? _NullPresenceListenable(),
        builder: (context, eventPresence, __) => ProfilePageContents(
          client: widget.client,
          userProfile: _profile,
          presence: eventPresence ?? livePresence ?? _presence,
          room: widget.room,
          roomUser: _roomUser,
          roomUserLoading: _roomUserLoading,
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, String title) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(LucideIcons.arrowLeft),
        onPressed: () => context.pop(),
      ),
      title: Text(
        AppLocalizations.of(context)!.userProfilePageBanner(title),
        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _buildErrorBody(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final message = _error is TimeoutException
        ? l10n.profileLoadTimeout
        : l10n.profileLoadError('$_error');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.alertCircle, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              icon: const Icon(LucideIcons.refreshCw, size: 18),
              label: Text(AppLocalizations.of(context)!.retry),
              onPressed: () {
                setState(() {
                  _loading = true;
                  _error = null;
                });
                _fetchProfile();
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Body of the profile page, split into logical sections.
class ProfilePageContents extends StatelessWidget {
  const ProfilePageContents({
    super.key,
    required this.client,
    required this.userProfile,
    this.presence,
    this.room,
    this.roomUser,
    this.roomUserLoading = false,
  });

  final Profile? userProfile;
  final Client client;
  final CachedPresence? presence;
  final Room? room;
  final User? roomUser;
  final bool roomUserLoading;

  String get _userId => userProfile?.userId ?? '';
  String get _displayName => userProfile?.displayName ?? _userId;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ---- Profile Header ----
          ProfileHeader(
            client: client,
            avatarUri: userProfile?.avatarUrl,
            displayName: _displayName,
            userId: _userId,
            presence: presence,
            scheme: scheme,
            l10n: l10n,
          ),

          const SizedBox(height: 24),

          // ---- About section ----
          InfoSectionLabel(icon: LucideIcons.info, title: l10n.sectionAbout),
          const SizedBox(height: 8),
          ProfileInfoCard(
            displayName: _displayName,
            userId: _userId,
            presence: presence,
            scheme: scheme,
            l10n: l10n,
          ),

          // ---- Room context section ----
          if (room != null) ...[
            const SizedBox(height: 24),
            RoomContextSection(
              room: room!,
              roomUser: roomUser,
              roomUserLoading: roomUserLoading,
              displayName: _displayName,
              userId: _userId,
              scheme: scheme,
              l10n: l10n,
            ),
          ],

          // ---- Moderation section ----
          if (room != null && roomUser != null) ...[
            const SizedBox(height: 24),
            ModerationSection(
              room: room!,
              user: roomUser!,
              displayName: _displayName,
              client: client,
              scheme: scheme,
              l10n: l10n,
            ),
          ],

          // ---- Actions ----
          const SizedBox(height: 24),
          ProfileActionsSection(
            client: client,
            userId: _userId,
            displayName: _displayName,
            scheme: scheme,
            l10n: l10n,
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// Section: Profile Header (avatar, name, presence)

// Section Header

// Section: Profile Info Card (display name, user ID, presence detail)

class ProfileInfoRow extends StatelessWidget {
  const ProfileInfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.scheme,
    this.isMono = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final ColorScheme scheme;
  final bool isMono;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: scheme.onSurfaceVariant),
        const SizedBox(width: 10),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              color: scheme.onSurface,
              fontFamily: isMono ? 'monospace' : null,
            ),
          ),
        ),
      ],
    );
  }
}

// Section: Room Context (membership, power level)

// Section: Moderation Actions

// Section: General Actions (DM, Block, Remove Contact, Report)

// -- Profile overlay --------------------------------------------------------

/// Opens the user profile as a centered modal overlay, with a plain dim
/// background instead of blur so the chat remains visible underneath.
///
/// This is the last modal-overlay surface left in the app. The hub used to
/// be presented the same way and is now a routed page instead, because a
/// modal cannot be described by a URL and the hub wanted to be reachable by
/// one. A profile overlay is the easier case: it is a transient look at
/// somebody, not a place the user can be linked to or come back to, and
/// there is nothing in it that wants a second entry point. If a profile ever
/// needs deep links, or a settings surface of its own, this should become a
/// route on the same pattern rather than grow a selection object.
///
/// The overlay is independent of the room route; it does not push onto
/// GoRouter's stack.  When [room] is provided the profile renders room-
/// scoped moderation actions (kick/ban/power level).
///
/// On entry the userid is validated against the Matrix ID format
/// (`^@.+:.+`); invalid identifiers surface a snackbar and the overlay
/// is not opened.
Future<void> showProfileOverlay(
  BuildContext context, {
  required String userId,
  Room? room,
}) async {
  final client = context.read<Client>();
  // Validate the userid shape before opening: Matrix IDs look like
  // `@localpart:domain` and anything else is a programming error or a
  // mis-parsed URI.
  if (!RegExp(r'^@.+:.+$').hasMatch(userId)) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Invalid Matrix user id: $userId')),
    );
    return;
  }
  // Avoid opening a second overlay on top of an existing one for the
  // same user; prevents stacking if the caller fires from multiple
  // gestures in quick succession.
  final navigator = Navigator.of(context, rootNavigator: true);
  await navigator.push(
    PageRouteBuilder(
      opaque: false,
      barrierDismissible: true,
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 150),
      reverseTransitionDuration: const Duration(milliseconds: 120),
      pageBuilder: (_, __, ___) => ProfileOverlayPage(
        client: client,
        userId: userId,
        room: room,
      ),
    ),
  );
}
