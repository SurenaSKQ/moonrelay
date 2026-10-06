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

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/feedback.dart';
import 'package:moonrelay/src/helpers/upload_limits.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/hub_screen/initials.dart';
import 'package:moonrelay/src/screens/hub_screen/page_body.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/services/presence_service.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

// -----------------------------------------------------------------------------
// My Profile Page
// -----------------------------------------------------------------------------

class HubMyProfilePage extends StatefulWidget {
  const HubMyProfilePage({super.key, required this.client});
  final Client client;

  @override
  State<HubMyProfilePage> createState() => _HubMyProfilePageState();
}

class _HubMyProfilePageState extends State<HubMyProfilePage> {
  bool _uploadingAvatar = false;
  bool _loading = true;
  Profile? _profile;
  CachedPresence? _presence;

  /// Monotonic token for profile loads. A load whose token is stale by
  /// the time it resolves is discarded, so a slow first request cannot
  /// land on top of a fast second one and show the older data.
  int _loadToken = 0;

  /// Whether a silent refresh is currently in flight, so a burst of
  /// sync pulses starts one refresh rather than several.
  bool _refreshing = false;

  /// Last [SyncPulse.version] observed at build time. The build re-runs
  /// the silent refresh whenever the pulse advances, so we no longer
  /// need to subscribe to `client.onSync.stream` directly.
  int _lastPulseVersion = -1;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant HubMyProfilePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // An account switch delivers a new client to the same Element, so
    // initState does not run again. Without this the page would keep
    // showing the previous account's name, id, presence and status
    // message under the new session.
    if (!identical(oldWidget.client, widget.client)) {
      _loadData();
    }
  }

  /// Initial load: shows progress.
  Future<void> _loadData() async {
    final userId = widget.client.userID;
    if (userId == null) {
      if (!mounted) return;
      setState(() => _loading = false);
      return;
    }
    final token = ++_loadToken;
    try {
      final profile = await widget.client.getProfileFromUserId(userId);
      // fetchCurrentPresence rather than the raw generated getPresence:
      // the helper consults the SDK's in-memory map and its database
      // before hitting the network, and the raw call did neither, so
      // this was one request per refresh with nothing cached.
      final presence = await withTimeoutOrFallback(
        () => widget.client.fetchCurrentPresence(userId),
        fallback: CachedPresence.neverSeen(userId),
        label: 'own presence',
      );
      // A newer load started while this one was in flight; its result is
      // the one the user is waiting for.
      if (!mounted || token != _loadToken) return;
      setState(() {
        _profile = profile;
        _presence = presence;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || token != _loadToken) return;
      setState(() => _loading = false);
    }
  }

  /// Silent refresh: updates the cached data without chasing into a
  /// loading state, so the UI stays stable.
  ///
  /// Guarded twice. The in-flight flag stops a second pulse from
  /// starting overlapping work, and the token means a result that
  /// overtook a newer one is dropped rather than applied late.
  Future<void> _silentRefresh() async {
    if (_refreshing) return;
    final userId = widget.client.userID;
    if (userId == null) return;
    _refreshing = true;
    final token = ++_loadToken;
    try {
      final profile = await widget.client.getProfileFromUserId(userId);
      final presence = await withTimeoutOrFallback(
        () => widget.client.fetchCurrentPresence(userId),
        fallback: CachedPresence.neverSeen(userId),
        label: 'own presence refresh',
      );
      if (!mounted || token != _loadToken) return;
      setState(() {
        _profile = profile;
        _presence = presence;
      });
    } on Object catch (e) {
      // Keep showing stale data rather than flashing an error; the
      // profile is a cache, and a failed refresh is not worth a
      // snackbar on a screen the user did not act on.
      if (mounted) {
        context.read<Logger>().w('Silent profile refresh failed', error: e);
      }
    } finally {
      _refreshing = false;
    }
  }

  /// Opens a file picker for images, uploads the selected file as the
  /// user's avatar, and triggers a UI refresh.
  Future<void> _changeAvatar() async {
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await readFileBytes(file);
    if (bytes.isEmpty) return;

    setState(() => _uploadingAvatar = true);

    try {
      // setAvatar uploads the bytes itself, so a separate uploadContent
      // call would send the file to the server twice.  Skip the
      // redundant upload and let setAvatar own the lifecycle.
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

  Future<void> _editDisplayName() async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    final controller = TextEditingController(text: _profile?.displayName ?? '');
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editDisplayName),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: l10n.displayNameHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.editSave),
          ),
        ],
      ),
    );
    if (newName == null || !mounted) return;
    try {
      await withRetry(
        () => widget.client.setProfileField(
          widget.client.userID!,
          'displayname',
          {'displayname': newName},
        ),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'setDisplayName',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.displayNameUpdated)),
      );
      _silentRefresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _editStatusMessage() async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    final controller = TextEditingController(text: _presence?.statusMsg ?? '');
    final newStatus = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.editStatusMessage),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 2,
          decoration: InputDecoration(hintText: l10n.statusMessageHint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(l10n.editSave),
          ),
        ],
      ),
    );
    if (newStatus == null || !mounted) return;
    // Empty is sent as an empty string, not null. The SDK omits
    // status_msg when it is null, so the server keeps the previous value
    // and the field would visibly refuse to clear. The current presence
    // is passed through rather than defaulted, because an unread
    // presence must not become an implicit "go online" as a side effect
    // of editing a caption.
    await context.showActionResult(
      action: () async {
        final result = await withRetry(
          () => PresenceService.publishTo(
            widget.client,
            type: _presence?.presence ?? PresenceType.online,
            statusMsg: newStatus,
          ),
          maxRetries: 1,
          timeout: kDefaultTimeout,
          log: log,
          label: 'setStatus',
        );
        // withRetry returns a result rather than throwing, so the
        // outcome has to be matched. A bare try/catch around the call
        // would compile, look right, and report success on a 403.
        switch (result) {
          case RetrySuccess():
            return;
          case RetryFailed(:final error):
            throw StateError('$error');
        }
      },
      successMessage: l10n.statusMessageUpdated,
      log: log,
      logLabel: 'update status message',
    );
    if (!mounted) return;
    _silentRefresh();
  }

  Future<void> _setPresence(PresenceType pt) async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    // Route through the service when one is bound, so a manual choice also
    // stops the idle logic overriding it. Without a service (the logged-out
    // tree, or a test) it falls back to the same static helper, so
    // syncPresence is still pinned and the choice still survives the next
    // long-poll. The two paths cannot drift because there is one
    // implementation of the publish step.
    final presenceService = context.read<PresenceService?>();
    await context.showActionResult(
      action: presenceService != null
          ? () => presenceService.setUserPresence(
                pt,
                statusMsg: _presence?.statusMsg,
              )
          : () async {
              final result = await withRetry(
                () => PresenceService.publishTo(
                  widget.client,
                  type: pt,
                  statusMsg: _presence?.statusMsg,
                ),
                maxRetries: 1,
                timeout: kDefaultTimeout,
                log: log,
                label: 'setPresence',
              );
              switch (result) {
                case RetrySuccess():
                  return;
                case RetryFailed(:final error):
                  throw StateError('$error');
              }
            },
      successMessage: l10n.presenceStatusUpdated,
      log: log,
      logLabel: 'update presence',
    );
    if (!mounted) return;
    // Reflect the choice locally rather than re-reading: setPresence does
    // not write the SDK's presence cache, so a fetch right now would
    // return the value from before the change and the chip would not move.
    setState(() {
      _presence = CachedPresence(
        pt,
        0,
        _presence?.statusMsg,
        pt == PresenceType.online,
        _presence?.userid ?? widget.client.userID ?? '',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final mono = MoonrelayThemeExtension.of(context).monoFontFamily;
    // Read the debounced sync pulse so we run a silent refresh on every
    // Read the debounced sync pulse so we can refresh on a coalesced tick
    // rather than every raw sync event. The hub is always mounted inside
    // the account-aware router so the pulse is in scope.
    //
    // The version is only observed here. The refresh is scheduled as a
    // post-frame callback rather than fired from build: a network call
    // started during a build is the same build-phase side effect the
    // layout-shell work removed, and a rebuild caused by anything
    // unrelated (a resize, a theme change) can otherwise re-trigger it.
    final pulseVersion = context.select<SyncPulse, int>((p) => p.version);
    if (pulseVersion != _lastPulseVersion) {
      _lastPulseVersion = pulseVersion;
      if (!_loading) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _silentRefresh();
        });
      }
    }

    final l10n = AppLocalizations.of(context)!;
    final client = widget.client;

    if (_loading) {
      return const LoadingScreen();
    }

    final profile = _profile;
    final presence = _presence;
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final t = theme.moonrelay.tokens;

    // The measure every hub page now gets. This page is the hub's front door and
    // the only one without a title strip, because the app bar above already
    // says "Hub" and repeating it twenty pixels below would be the same double
    // title the other thirteen pages had.
    return HubPageBody(
      children: [
        // -- Avatar + name header --------------------------------
        Row(
          children: [
            GestureDetector(
              onTap: _uploadingAvatar ? null : _changeAvatar,
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: Stack(
                  children: [
                    profile?.avatarUrl == null
                        ? CircleAvatar(
                            radius: 40,
                            backgroundColor: cs.primaryContainer,
                            child: Text(
                              matrixInitials(
                                profile?.displayName ?? profile?.userId,
                              ),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: cs.onPrimaryContainer,
                              ),
                            ),
                          )
                        : AvatarFromUriOrFallbackImage(
                            client: client,
                            avatarUri: profile!.avatarUrl,
                            radius: 40,
                          ),
                    if (_uploadingAvatar)
                      Positioned.fill(
                        child: Container(
                          decoration: BoxDecoration(
                            // `scheme.scrim`, not `Colors.black38`. The colour
                            // role for "something is being worked on and you
                            // cannot touch it yet" already exists and is
                            // black in both brightnesses; a fixed black at
                            // 22% happened to match only because the scrim
                            // happened to be black, and the token's 38% is
                            // the app's existing "inert" step. The spinner is
                            // `onPrimaryContainer` to match the avatar it
                            // covers, since it sits on top of the avatar's own
                            // container tint rather than on the scrim alone.
                            color:
                                cs.scrim.withValues(alpha: t.opacityDisabled),
                            borderRadius: BorderRadius.circular(40),
                          ),
                          child: Center(
                            child: SizedBox(
                              width: t.spaceXl,
                              height: t.spaceXl,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: cs.onPrimaryContainer,
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
                            color: cs.primary,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.surface,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            LucideIcons.camera,
                            size: 14,
                            color: cs.onPrimary,
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          profile?.displayName ?? l10n.unknown,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: cs.onSurface,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      SizedBox(width: t.spaceSm),
                      IconButton(
                        tooltip: l10n.editOwnProfile,
                        icon: Icon(
                          LucideIcons.squarePen,
                          size: t.iconSizeSmall,
                        ),
                        onPressed: _editDisplayName,
                      ),
                    ],
                  ),
                  SizedBox(height: t.spaceXs),
                  Text(
                    profile?.userId ?? '',
                    style: TextStyle(
                      fontSize: 14,
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: t.spaceSm),
                  Text(
                    l10n.profilePageTitle,
                    style: TextStyle(
                      fontSize: 12,
                      color: cs.onSurfaceVariant.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 32),
        const Divider(),
        SizedBox(height: t.spaceXl),

        // -- Display Name ----------------------------------------
        Text(
          l10n.displayName,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: t.spaceSm),
        InkWell(
          onTap: _editDisplayName,
          borderRadius: BorderRadius.circular(t.radiusSm),
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(t.spaceMd),
            decoration: BoxDecoration(
              color:
                  cs.surfaceContainerHighest.withValues(alpha: t.opacitySubtle),
              borderRadius: BorderRadius.circular(t.radiusSm),
            ),
            child: Text(
              profile?.displayName ?? l10n.notSet,
              style: TextStyle(
                fontSize: 16,
                color: cs.onSurface,
              ),
            ),
          ),
        ),

        SizedBox(height: t.spaceXl),

        // -- User ID (read-only) --------------------------------
        Text(
          l10n.userIDLabel,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: t.spaceSm),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(t.spaceMd),
          decoration: BoxDecoration(
            color:
                cs.surfaceContainerHighest.withValues(alpha: t.opacitySubtle),
            borderRadius: BorderRadius.circular(t.radiusSm),
          ),
          child: SelectableText(
            profile?.userId ?? '',
            style: TextStyle(
              fontSize: 14,
              fontFamily: mono,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),

        SizedBox(height: t.spaceXl),
        const Divider(),
        SizedBox(height: t.spaceXl),

        // -- Presence -------------------------------------------
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.presence,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: t.spaceXs),
            Text(
              l10n.presenceDescription,
              style: TextStyle(
                fontSize: 12,
                color: cs.onSurfaceVariant,
              ),
            ),
            SizedBox(height: t.spaceMd),
            Wrap(
              spacing: 8,
              children: [
                for (final p in [
                  PresenceType.online,
                  PresenceType.unavailable,
                  PresenceType.offline,
                ])
                  ChoiceChip(
                    label: Text(_presenceLabel(l10n, p)),
                    selected: presence?.presence == p ||
                        (presence == null && p == PresenceType.online),
                    onSelected: (_) => _setPresence(p),
                  ),
              ],
            ),
            SizedBox(height: t.spaceLg),
            Text(
              l10n.statusMessage,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            SizedBox(height: t.spaceXs),
            InkWell(
              onTap: _editStatusMessage,
              borderRadius: BorderRadius.circular(t.radiusSm),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(t.spaceMd),
                decoration: BoxDecoration(
                  color: cs.surfaceContainerHighest
                      .withValues(alpha: t.opacitySubtle),
                  borderRadius: BorderRadius.circular(t.radiusSm),
                ),
                child: Text(
                  presence?.statusMsg?.isNotEmpty == true
                      ? presence!.statusMsg!
                      : l10n.notSet,
                  style: TextStyle(
                    fontSize: 14,
                    color: cs.onSurface,
                    fontStyle: presence?.statusMsg == null
                        ? FontStyle.italic
                        : FontStyle.normal,
                  ),
                ),
              ),
            ),
          ],
        ),

        SizedBox(height: t.spaceXl),
      ],
    );
  }

  String _presenceLabel(AppLocalizations l10n, PresenceType p) {
    switch (p) {
      case PresenceType.online:
        return l10n.presenceStatusOnline;
      case PresenceType.unavailable:
        return l10n.presenceStatusUnavailable;
      case PresenceType.offline:
        return l10n.presenceStatusOffline;
    }
  }
}
