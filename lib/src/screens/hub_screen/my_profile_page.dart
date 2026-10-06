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
import 'package:moonrelay/src/widgets/info_widgets.dart';
import 'package:moonrelay/src/services/presence_service.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

// -----------------------------------------------------------------------------
// _IdentityHeader
// -----------------------------------------------------------------------------

/// The avatar + name + user id at the top of the profile page.
///
/// This is the identity header the hub uses, not a settings card.
/// The avatar loads from the Matrix content URI (or falls back to
/// initials) and the name + id are one tap target, keeping the
/// page's front door to a single surface.
class _IdentityHeader extends StatelessWidget {
  const _IdentityHeader({
    required this.displayName,
    required this.userId,
    this.avatarUrl,
    required this.client,
    this.uploading = false,
    this.onAvatarTap,
    this.onNameTap,
  });

  final String displayName;
  final String userId;
  final Uri? avatarUrl;
  final Client client;
  final bool uploading;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onNameTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Row(
      children: [
        GestureDetector(
          onTap: onAvatarTap,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Stack(
              children: [
                avatarUrl == null
                    ? CircleAvatar(
                        radius: 32,
                        backgroundColor: cs.primaryContainer,
                        child: Text(
                          matrixInitials(displayName),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: cs.onPrimaryContainer,
                          ),
                        ),
                      )
                    : AvatarFromUriOrFallbackImage(
                        client: client,
                        avatarUri: avatarUrl,
                        radius: 32,
                      ),
                if (uploading)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            cs.scrim.withValues(alpha: t.opacityDisabled),
                        borderRadius: BorderRadius.circular(32),
                      ),
                      child: const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  )
                else
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: cs.primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: cs.surface, width: 2),
                      ),
                      child: Icon(
                        LucideIcons.camera,
                        size: 11,
                        color: cs.onPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(width: t.spaceMd),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  SizedBox(width: t.spaceXs),
                  IconButton(
                    tooltip: AppLocalizations.of(context)!.editOwnProfile,
                    icon: const Icon(
                      LucideIcons.squarePen,
                      size: 16,
                    ),
                    onPressed: onNameTap,
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                  ),
                ],
              ),
              Text(
                userId,
                style: TextStyle(
                  fontSize: 13,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// InfoPresenceRow
// -----------------------------------------------------------------------------

/// Three presence choice chips in a compact row, each showing its label.
/// The selected presence is shown with a filled chip; the others are outlined.
class InfoPresenceRow extends StatelessWidget {
  const InfoPresenceRow({
    super.key,
    required this.presence,
    required this.onChanged,
    required this.labels,
  });

  final PresenceType presence;
  final void Function(PresenceType)? onChanged;
  final Map<PresenceType, String> labels;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: t.spaceXs,
        vertical: t.spaceSm,
      ),
      child: Wrap(
        spacing: t.spaceXs,
        runSpacing: t.spaceXs,
        children: [
          for (final p in PresenceType.values)
            ChoiceChip(
              label: Text(labels[p] ?? p.name),
              selected: presence == p,
              onSelected: (_) => onChanged?.call(p),
            ),
        ],
      ),
    );
  }
}

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

    // The measure every hub page now gets, and the hub's one panel vocabulary.
    //
    // This page was the last one in the hub not built from it. It spent about
    // 250 vertical lines arranging six blocks with its own `SizedBox(height: 32)`
    // and two `Divider`s, and the result was a screen where each value had a
    // heading above it, a box around it, and roughly 60px of nothing on either
    // side, so the page read as a scrolling form a column tall rather than as
    // four facts about one person. The avatar header repeated the display name
    // and the user id that two of those six blocks then repeated, which meant
    // the same two strings appeared three times on one screen.
    return HubPageBody(
      children: [
        _IdentityHeader(
          // The header *is* the display name and the user id. It is not a
          // summary of a panel below it, so nothing below repeats it.
          displayName: profile?.displayName ?? l10n.unknown,
          userId: profile?.userId ?? client.userID ?? '',
          avatarUrl: profile?.avatarUrl,
          client: client,
          uploading: _uploadingAvatar,
          onAvatarTap: _uploadingAvatar ? null : _changeAvatar,
          onNameTap: _editDisplayName,
        ),

        // -- Identity -----------------------------------------------
        // The two facts as rows rather than as labelled boxes. A row carries
        // its own label and its own value, so a heading above the box and 60px
        // of padding around it were only ever the cost of not having a row.
        InfoPanel(
          title: l10n.identity,
          children: [
            InfoPanelRow(
              label: l10n.displayName,
              description:
                  profile?.displayName ?? l10n.notSet,
              icon: LucideIcons.user,
              onTap: _editDisplayName,
            ),
            InfoPanelRow(
              label: l10n.userIDLabel,
              icon: LucideIcons.atSign,
              // The user id as a selectable value: a reader plausibly wants
              // to copy it, and it reads as a monospace identifier.
              value: profile?.userId ?? '',
              valueFontFamily: mono,
            ),
          ],
        ),

        // -- Presence -----------------------------------------------
        InfoPanel(
          title: l10n.presence,
          children: [
            InfoPanelRow(
              label: l10n.statusMessage,
              description: presence?.statusMsg?.isNotEmpty == true
                  ? presence!.statusMsg!
                  : l10n.notSet,
              icon: LucideIcons.messageSquare,
              onTap: _editStatusMessage,
            ),
            InfoPresenceRow(
              presence: presence?.presence ?? PresenceType.online,
              // Null rather than a no-op: presence is only settable while
              // signed in, and a row that accepts the tap and discards it is
              // worse than one that looks inert.
              onChanged: _setPresence,
              labels: <PresenceType, String>{
                PresenceType.online: l10n.presenceStatusOnline,
                PresenceType.unavailable: l10n.presenceStatusUnavailable,
                PresenceType.offline: l10n.presenceStatusOffline,
              },
            ),
          ],
        ),
      ],
    );
  }
}
