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

import 'package:flutter/material.dart' hide Visibility;
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

/// A page for creating a new room with optional customisation.
class CreateNewRoomPage extends StatefulWidget {
  const CreateNewRoomPage({super.key});

  @override
  State<CreateNewRoomPage> createState() => _CreateNewRoomPageState();
}

class _CreateNewRoomPageState extends State<CreateNewRoomPage> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _topicController = TextEditingController();
  final TextEditingController _aliasController = TextEditingController();
  final TextEditingController _inviteController = TextEditingController();
  bool _isPublic = true;
  bool _isSpace = false;
  bool _enableEncryption = false;
  bool _showAdvanced = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _topicController.dispose();
    _aliasController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  List<String> _parseInvites() {
    final text = _inviteController.text.trim();
    if (text.isEmpty) return [];
    return text
        .split(RegExp('[,\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _createRoom() async {
    final client = context.read<Client>();
    final log = context.read<Logger>();

    setState(() {
      _loading = true;
      _error = null;
    });

    final name = _nameController.text.trim();
    final topic = _topicController.text.trim();
    final alias = _aliasController.text.trim();
    final invites = _parseInvites();
    final l10n = AppLocalizations.of(context)!;

    // Build initial state for encryption.
    final initialState = <StateEvent>[];
    if (_enableEncryption && !_isSpace) {
      initialState.add(
        StateEvent(
          type: 'm.room.encryption',
          content: {'algorithm': 'm.megolm.v1.aes-sha2'},
        ),
      );
    }

    final result = await withRetry(
      () => client.createRoom(
        name: name.isNotEmpty ? name : null,
        topic: topic.isNotEmpty ? topic : null,
        roomAliasName: alias.isNotEmpty ? alias : null,
        invite: invites.isNotEmpty ? invites : null,
        preset: _isPublic
            ? CreateRoomPreset.publicChat
            : CreateRoomPreset.privateChat,
        visibility: _isPublic ? Visibility.public : Visibility.private,
        creationContent: _isSpace ? {'type': 'm.space'} : null,
        initialState: initialState.isNotEmpty ? initialState : null,
      ),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'createRoom',
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess(:final value):
        if (_isSpace) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.spaceCreated)),
          );
          context.go('/main/space/$value');
        } else {
          context.go('/main/rooms/$value');
        }
      case RetryFailed(:final error):
        setState(() {
          _error = error is TimeoutException
              ? l10n.creatingRoomTimedOut
              : l10n.couldNotCreateRoom('$error');
          _loading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    if (_error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => context.pop(),
        ),
        title: Text(
          _isSpace ? l10n.createSpace : l10n.createNewRoom,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Room name
            Text(
              l10n.displayName,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              enabled: !_loading,
              decoration: InputDecoration(
                hintText: l10n.roomInfoTitle,
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.next,
            ),

            const SizedBox(height: 20),

            // Room topic
            Text(
              l10n.roomInfoTitle,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _topicController,
              enabled: !_loading,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.noTopicSet,
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 20),

            // Create as Space toggle
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: SwitchListTile(
                title: Text(
                  l10n.createAsSpace,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  l10n.createAsSpaceDescription,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                secondary: Icon(
                  LucideIcons.folder,
                  size: 22,
                ),
                value: _isSpace,
                onChanged:
                    (_loading) ? null : (v) { WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isSpace = v); }); },
              ),
            ),

            const SizedBox(height: 16),

            // Visibility toggle
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: SwitchListTile(
                title: Text(
                  _isPublic ? l10n.publicRoom : l10n.privateRoom,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text(
                  _isPublic
                      ? 'Anyone can find and join this room'
                      : 'Only invited people can join this room',
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                secondary: Icon(
                  _isPublic ? LucideIcons.globe : LucideIcons.lock,
                  size: 22,
                ),
                value: _isPublic,
                onChanged:
                    (_loading) ? null : (v) { WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _isPublic = v); }); },
              ),
            ),

            const SizedBox(height: 16),

            // Advanced options toggle
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: SwitchListTile(
                title: Text(
                  l10n.advancedOptions,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                secondary: Icon(
                  LucideIcons.settings2,
                  size: 22,
                ),
                value: _showAdvanced,
                onChanged: (_loading)
                    ? null
                    : (v) { WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) setState(() => _showAdvanced = v); }); },
              ),
            ),

            AnimatedSize(
              duration: const Duration(milliseconds: 250),
              alignment: Alignment.topCenter,
              curve: Curves.easeInOut,
              child: _showAdvanced
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        // Room alias
                        Text(
                          l10n.roomAlias,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _aliasController,
                          enabled: !_loading,
                          decoration: InputDecoration(
                            hintText: l10n.roomAliasHint,
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 20),
                        // Invite users
                        Text(
                          l10n.inviteUsers,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _inviteController,
                          enabled: !_loading,
                          decoration: InputDecoration(
                            hintText: l10n.inviteUsersHint,
                            filled: true,
                            fillColor: scheme.surfaceContainerHighest
                                .withValues(alpha: 0.5),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          textInputAction: TextInputAction.next,
                        ),
                        const SizedBox(height: 20),
                        // Encryption toggle (only for non-space rooms)
                        if (!_isSpace)
                          Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color: scheme.outlineVariant,
                              ),
                            ),
                            child: SwitchListTile(
                              title: Text(
                                l10n.enableEncryption,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              subtitle: Text(
                                l10n.enableEncryptionDescription,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                              secondary: const Icon(
                                LucideIcons.shield,
                                size: 22,
                              ),
                              value: _enableEncryption,
                              onChanged: (_loading)
                                  ? null
                                  : (v) =>
                                      setState(() => _enableEncryption = v),
                            ),
                          ),
                        if (!_isSpace) const SizedBox(height: 16),
                      ],
                    )
                  : const SizedBox.shrink(),
            ),

            const SizedBox(height: 32),

            // Create button
            FilledButton.icon(
              onPressed: _loading ? null : _createRoom,
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.plus, size: 18),
              label: Text(_loading
                  ? l10n.loading
                  : _isSpace
                      ? l10n.createSpace
                      : l10n.createRoom),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
