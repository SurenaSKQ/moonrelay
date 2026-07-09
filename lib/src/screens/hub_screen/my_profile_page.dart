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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/loading_screen.dart';
import 'package:moonrelay/src/widgets/avatar_from_uri.dart';
import 'package:provider/provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
// My Profile Page
// ─────────────────────────────────────────────────────────────────────────────

class HubMyProfilePage extends StatefulWidget {
  const HubMyProfilePage({super.key, required this.client});
  final Client client;

  @override
  State<HubMyProfilePage> createState() => _HubMyProfilePageState();
}

class _HubMyProfilePageState extends State<HubMyProfilePage> {
  bool _uploadingAvatar = false;
  Future<Profile>? _profileFuture;
  Future<CachedPresence?>? _presenceFuture;
  StreamSubscription<Object?>? _syncSub;

  /// Opens a file picker for images, uploads the selected file as the
  /// user's avatar, and triggers a UI refresh.
  Future<void> _changeAvatar() async {
    // Use `pickFile` (singular) for single-image selection; this also
    // avoids the deprecated `allowMultiple: false` and `withData: true`
    // parameters on `pickFiles`.
    final file = await FilePicker.pickFile(type: FileType.image);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) return;

    setState(() => _uploadingAvatar = true);

    try {
      await widget.client.uploadContent(
        bytes,
        filename: file.name,
        contentType:
            file.extension != null ? 'image/${file.extension}' : 'image/png',
      );
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

  Future<void> _editDisplayName(Profile profile) async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    final controller = TextEditingController(text: profile.displayName ?? '');
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
          newName.isEmpty ? const {} : {'displayname': newName},
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
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _editStatusMessage(
    Profile profile,
    CachedPresence? presence,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    final controller =
        TextEditingController(text: presence?.statusMsg ?? '');
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
    try {
      await withRetry(
        () => widget.client.setPresence(
          widget.client.userID!,
          presence?.presence ?? PresenceType.online,
          statusMsg: newStatus.isEmpty ? null : newStatus,
        ),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'setStatus',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.statusMessageUpdated)),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  Future<void> _setPresence(
    Profile profile,
    CachedPresence? presence,
    PresenceType pt,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    try {
      await withRetry(
        () => widget.client.setPresence(
          widget.client.userID!,
          pt,
          statusMsg: presence?.statusMsg,
        ),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'setPresence',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.presenceStatusUpdated)),
      );
      _refresh();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.actionFailed('$e'))),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _refresh();
    _syncSub = widget.client.onSync.stream.listen((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    setState(() {
      _profileFuture = widget.client.getProfileFromUserId(
        widget.client.userID!,
      );
      _presenceFuture = () async {
        try {
          final resp = await widget.client
              .getPresence(widget.client.userID!);
          return CachedPresence.fromPresenceResponse(
            resp,
            widget.client.userID!,
          );
        } catch (_) {
          return null;
        }
      }();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final client = widget.client;
    return FutureBuilder<Profile>(
      future: _profileFuture,
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
                  GestureDetector(
                    onTap: _uploadingAvatar ? null : _changeAvatar,
                    child: MouseRegion(
                      cursor: SystemMouseCursors.click,
                      child: Stack(
                        children: [
                          profile?.avatarUrl == null
                              ? CircleAvatar(
                                  radius: 40,
                                  backgroundColor:
                                      theme.colorScheme.primaryContainer,
                                  child: Text(
                                    (profile?.displayName ??
                                            profile?.userId ??
                                            '?')
                                        .toUpperCase()
                                        .split(RegExp(' +'))
                                        .map((s) => s[0])
                                        .take(2)
                                        .join(),
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.w600,
                                      color: theme
                                          .colorScheme.onPrimaryContainer,
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
                                  color: Colors.black38,
                                  borderRadius: BorderRadius.circular(40),
                                ),
                                child: const Center(
                                  child: SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
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
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: theme.colorScheme.surface,
                                    width: 2,
                                  ),
                                ),
                                child: Icon(
                                  LucideIcons.camera,
                                  size: 14,
                                  color: theme.colorScheme.onPrimary,
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
                                  color: theme.colorScheme.onSurface,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              tooltip: l10n.editOwnProfile,
                              icon: const Icon(LucideIcons.squarePen,
                                  size: 16),
                              onPressed: () => _editDisplayName(profile!),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          profile?.userId ?? '',
                          style: TextStyle(
                            fontSize: 14,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.profilePageTitle,
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurfaceVariant
                                .withValues(alpha: 0.6),
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

              // ── Display Name ────────────────────────────────
              Text(
                l10n.displayName,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () => _editDisplayName(profile!),
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHighest
                        .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    profile?.displayName ?? l10n.notSet,
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── User ID (read-only) ──────────────────────────────
              Text(
                l10n.userIDLabel,
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

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 24),

              // ── Presence (publishes own status) ───────────────────────
              FutureBuilder<CachedPresence?>(
                future: _presenceFuture,
                builder: (context, pSnap) {
                  final presence = pSnap.data;
                  final cs = theme.colorScheme;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.presence,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.presenceDescription,
                        style: TextStyle(
                          fontSize: 12,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Presence select
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
                                  (presence == null &&
                                      p == PresenceType.online),
                              onSelected: (_) =>
                                  _setPresence(profile!, presence, p),
                            ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Status message
                      Text(
                        l10n.statusMessage,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      InkWell(
                        onTap: () =>
                            _editStatusMessage(profile!, presence),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            presence?.statusMsg?.isNotEmpty == true
                                ? presence!.statusMsg!
                                : l10n.notSet,
                            style: TextStyle(
                              fontSize: 14,
                              color: cs.onSurface,
                              fontStyle:
                                  presence?.statusMsg == null
                                      ? FontStyle.italic
                                      : FontStyle.normal,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),

              const SizedBox(height: 24),
            ],
          ),
        );
      },
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