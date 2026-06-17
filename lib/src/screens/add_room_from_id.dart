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
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart' hide Visibility;
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/room_directory_search.dart';
import 'package:provider/provider.dart';

/// The entry-point "Add Room" page that offers three methods:
///
/// 1. **Browse directory** — search the homeserver's public room directory
/// 2. **Join by ID** — join a room by its ID or alias, optionally through
///    a specific server.
/// 3. **Create** — create a new room or space with a custom name and topic.
class AddRoomPage extends StatefulWidget {
  const AddRoomPage({super.key});

  @override
  State<AddRoomPage> createState() => _AddRoomPageState();
}

class _AddRoomPageState extends State<AddRoomPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(l10n.addRoom),
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(LucideIcons.search, size: 18),
              text: l10n.rooms,
            ),
            Tab(
              icon: const Icon(LucideIcons.hash, size: 18),
              text: l10n.roomIdOrAlias,
            ),
            Tab(
              icon: const Icon(LucideIcons.plus, size: 18),
              text: l10n.createRoom,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Browse directory
          const _DirectorySearchTab(),

          // Tab 2: Join by room ID / alias
          const _JoinByIdTab(),

          // Tab 3: Create a new room / space
          const _CreateRoomTab(),
        ],
      ),
    );
  }
}

// ── Tab 1: Directory search ──────────────────────────────────────────────────

/// Embeds [RoomDirectorySearch] inside the tab so we get the same
/// search + join UX but without the outer scaffold (already provided
/// by [AddRoomPage]).
class _DirectorySearchTab extends StatelessWidget {
  const _DirectorySearchTab();

  @override
  Widget build(BuildContext context) {
    return const RoomDirectorySearch(embedded: true);
  }
}

// ── Tab 2: Join by room ID / alias ───────────────────────────────────────────

/// A form that lets the user join a room by its ID or alias, optionally
/// specifying a server to join through.
class _JoinByIdTab extends StatefulWidget {
  const _JoinByIdTab();

  @override
  State<_JoinByIdTab> createState() => _JoinByIdTabState();
}

class _JoinByIdTabState extends State<_JoinByIdTab> {
  final TextEditingController _roomIdController = TextEditingController();
  final TextEditingController _serverController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _roomIdController.dispose();
    _serverController.dispose();
    super.dispose();
  }

  String? _knockingRoomId;

  Future<void> _addRoomFromID(
    Client client,
    String roomidOrAlias,
    String? server,
  ) async {
    final log = context.read<Logger>();
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await withRetry(
      () => client.joinRoom(roomidOrAlias,
          serverName: server != null && server.isNotEmpty ? [server] : null),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'joinRoom',
    );

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    switch (result) {
      case RetrySuccess():
        context.push('/main/rooms/$roomidOrAlias');
      case RetryFailed(:final error):
        // Try to detect if the room requires knocking.
        final joinRule = await _detectJoinRule(client, roomidOrAlias, log);
        if (joinRule == 'knock' || joinRule == 'knock_restricted') {
          if (mounted) {
            setState(() {
              _error = l10n.joinRequiresKnock;
            });
          }
        } else {
          setState(() {
            _error = error is TimeoutException
                ? l10n.joiningTimedOut
                : l10n.couldNotJoinRoom('$error');
          });
        }
    }

    if (mounted) setState(() => _loading = false);
  }

  /// Tries to resolve the room's [join_rule] by fetching a room summary.
  Future<String?> _detectJoinRule(
    Client client,
    String roomIdOrAlias,
    Logger log,
  ) async {
    try {
      final summary = await client.getRoomSummary(roomIdOrAlias);
      log.i('Room summary for $roomIdOrAlias: join_rule=${summary.joinRule}');
      return summary.joinRule;
    } catch (_) {
      return null;
    }
  }

  /// Knocks on the room instead of joining it.
  Future<void> _knockRoom(
    Client client,
    String roomIdOrAlias,
    String? server,
  ) async {
    setState(() {
      _knockingRoomId = roomIdOrAlias;
      _error = null;
    });

    try {
      await client.knockRoom(
        roomIdOrAlias,
        via: server != null && server.isNotEmpty ? [server] : null,
      );
      if (!mounted) return;
      setState(() => _knockingRoomId = null);
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.knockSent(roomIdOrAlias))),
      );
      context.push('/main/rooms/$roomIdOrAlias');
    } catch (e) {
      if (!mounted) return;
      setState(() => _knockingRoomId = null);
      setState(() {
        _error = AppLocalizations.of(context)!.knockFailed('$e');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final client = Provider.of<Client>(context);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Error banner
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.alertCircle,
                        size: 18, color: scheme.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: scheme.onErrorContainer,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Room ID / Alias
          Text(
            l10n.roomIdOrAlias,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _roomIdController,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: '#example:matrix.org',
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

          // Server (optional)
          Text(
            l10n.serverLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.serverOptionalHint,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _serverController,
            enabled: !_loading,
            decoration: InputDecoration(
              hintText: 'matrix.org',
              filled: true,
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
            onSubmitted: (_) => _addRoomFromID(
              client,
              _roomIdController.text,
              _serverController.text,
            ),
          ),

          const SizedBox(height: 24),

          if (_error == l10n.joinRequiresKnock)
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _knockingRoomId != null
                        ? null
                        : () => _knockRoom(
                              client,
                              _roomIdController.text,
                              _serverController.text,
                            ),
                    icon: _knockingRoomId != null
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(LucideIcons.logIn, size: 18),
                    label: Text(
                      _knockingRoomId != null
                          ? l10n.knockingRoom
                          : l10n.knockRoom,
                    ),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            FilledButton.icon(
              onPressed: _loading
                  ? null
                  : () => _addRoomFromID(
                        client,
                        _roomIdController.text,
                        _serverController.text,
                      ),
              icon: _loading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(LucideIcons.plus, size: 18),
              label: Text(_loading ? l10n.joining : l10n.addRoom),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Tab 3: Create room / space ────────────────────────────────────────────────

/// A form that lets the user create a new room or space with a custom name,
/// topic, and visibility setting.
class _CreateRoomTab extends StatefulWidget {
  const _CreateRoomTab();

  @override
  State<_CreateRoomTab> createState() => _CreateRoomTabState();
}

class _CreateRoomTabState extends State<_CreateRoomTab> {
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
  Uint8List? _avatarBytes;
  String? _avatarName;

  /// Selected join rule. Initialised to match [_isPublic].
  late String _joinRule;

  @override
  void initState() {
    super.initState();
    _joinRule = _isPublic ? 'public' : 'invite';
  }

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
        .split(RegExp('[,\\n]'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();
  }

  Future<void> _pickAvatar() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.first;
    if (file.bytes == null) return;
    setState(() {
      _avatarBytes = file.bytes;
      _avatarName = file.name;
    });
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

    // Build initial state.
    final initialState = <StateEvent>[];
    if (_enableEncryption && !_isSpace) {
      initialState.add(
        StateEvent(
          type: 'm.room.encryption',
          content: {'algorithm': 'm.megolm.v1.aes-sha2'},
        ),
      );
    }

    // Determine preset, visibility, and whether we need a custom join_rule
    // state event. When the join rule is 'public' we use the server's preset
    // which also sets the visibility correctly. For any other rule we set
    // the state explicitly so the createRoom call sends the desired rule.
    final usePublicPreset = _joinRule == 'public';
    if (!usePublicPreset) {
      initialState.add(
        StateEvent(
          type: 'm.room.join_rules',
          content: {'join_rule': _joinRule},
        ),
      );
    }

    final result = await withRetry(
      () => client.createRoom(
        name: name.isNotEmpty ? name : null,
        topic: topic.isNotEmpty ? topic : null,
        roomAliasName: alias.isNotEmpty ? alias : null,
        invite: invites.isNotEmpty ? invites : null,
        preset: usePublicPreset
            ? CreateRoomPreset.publicChat
            : CreateRoomPreset.privateChat,
        visibility: usePublicPreset ? Visibility.public : Visibility.private,
        creationContent: _isSpace ? {'type': 'm.space'} : null,
        initialState: initialState.isNotEmpty ? initialState : null,
      ),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'createRoom',
    );

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    switch (result) {
      case RetrySuccess(:final value):
        // Set room avatar if one was picked.
        if (_avatarBytes != null && mounted) {
          try {
            final room = client.getRoomById(value);
            if (room != null) {
              await room.setAvatar(
                MatrixFile(
                  bytes: _avatarBytes!,
                  name: _avatarName ?? 'avatar',
                ),
              );
            }
          } catch (e) {
            log.w('Failed to set room avatar after creation', error: e);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${l10n.error}: $e')),
              );
            }
          }
        }
        if (!mounted) return;
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

    // Show transient error in a SnackBar, then clear it.
    if (_error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
        _error = null;
      });
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Room type toggle (Room / Space) ──────────────────────
          Text(
            l10n.typeLabel,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                icon: Icon(LucideIcons.messageSquare, size: 18),
                label: Text('Room'),
              ),
              ButtonSegment(
                value: true,
                icon: Icon(LucideIcons.folder, size: 18),
                label: Text('Space'),
              ),
            ],
            selected: {_isSpace},
            onSelectionChanged: (selected) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) setState(() => _isSpace = selected.first);
              });
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(height: 20),

          // ── Room / Space name ────────────────────────────────────
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
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

          const SizedBox(height: 16),

          // ── Room avatar ──────────────────────────────────────────
          GestureDetector(
            onTap: _avatarBytes == null ? _pickAvatar : null,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundColor:
                      scheme.primaryContainer.withValues(alpha: 0.5),
                  backgroundImage:
                      _avatarBytes != null ? MemoryImage(_avatarBytes!) : null,
                  child: _avatarBytes == null
                      ? Icon(
                          LucideIcons.camera,
                          size: 28,
                          color: scheme.onPrimaryContainer,
                        )
                      : null,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.changeRoomAvatar,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _avatarBytes != null
                          ? _avatarName ?? ''
                          : l10n.changeRoomAvatarDescription,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                if (_avatarBytes != null) ...[
                  const Spacer(),
                  IconButton(
                    icon: Icon(
                      LucideIcons.x,
                      size: 18,
                      color: scheme.error,
                    ),
                    tooltip: l10n.removeRoomAvatar,
                    onPressed: () => setState(() {
                      _avatarBytes = null;
                      _avatarName = null;
                    }),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── Topic ────────────────────────────────────────────────
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
              fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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

          // ── Visibility toggle ────────────────────────────────────
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
                    ? 'Anyone can find and join this $_typeLabel'
                    : 'Only invited people can join this $_typeLabel',
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
              onChanged: (_loading)
                  ? null
                  : (v) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _isPublic = v;
                            // Sync join rule with the public toggle.
                            if (v) {
                              _joinRule = 'public';
                            } else if (_joinRule == 'public') {
                              _joinRule = 'invite';
                            }
                          });
                        }
                      });
                    },
            ),
          ),

          const SizedBox(height: 16),

          // ── Advanced options toggle ──────────────────────────────
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
              secondary: const Icon(LucideIcons.settings2, size: 22),
              value: _showAdvanced,
              onChanged: (_loading)
                  ? null
                  : (v) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) setState(() => _showAdvanced = v);
                      });
                    },
            ),
          ),

          if (_showAdvanced) ...[
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

            // Encryption toggle (only for non-space rooms)
            if (!_isSpace)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: scheme.outlineVariant),
                ),
                child: SwitchListTile(
                  title: Text(
                    l10n.enableEncryption,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  subtitle: Text(
                    l10n.enableEncryptionDescription,
                    style: TextStyle(
                      fontSize: 13,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  secondary: const Icon(LucideIcons.shield, size: 22),
                  value: _enableEncryption,
                  onChanged: (_loading)
                      ? null
                      : (v) => setState(() => _enableEncryption = v),
                ),
              ),
            if (!_isSpace) const SizedBox(height: 16),

            // ── Join rules picker ────────────────────────────────
            Text(
              l10n.joinRuleLabel,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(color: scheme.outlineVariant),
              ),
              child: Column(
                children: [
                  _JoinRuleTile(
                    value: 'public',
                    groupValue: _joinRule,
                    icon: LucideIcons.globe,
                    title: l10n.joinRulePublic,
                    enabled: !_loading,
                    onChanged: (v) => setState(() {
                      _joinRule = v;
                      _isPublic = v == 'public';
                    }),
                  ),
                  _JoinRuleTile(
                    value: 'invite',
                    groupValue: _joinRule,
                    icon: LucideIcons.lock,
                    title: l10n.joinRuleInvite,
                    enabled: !_loading,
                    onChanged: (v) => setState(() {
                      _joinRule = v;
                      _isPublic = false;
                    }),
                  ),
                  _JoinRuleTile(
                    value: 'knock',
                    groupValue: _joinRule,
                    icon: LucideIcons.logIn,
                    title: l10n.joinRuleKnock,
                    enabled: !_loading,
                    onChanged: (v) => setState(() {
                      _joinRule = v;
                      _isPublic = false;
                    }),
                  ),
                  _JoinRuleTile(
                    value: 'restricted',
                    groupValue: _joinRule,
                    icon: LucideIcons.shield,
                    title: l10n.joinRuleRestricted,
                    enabled: !_loading,
                    onChanged: (v) => setState(() {
                      _joinRule = v;
                      _isPublic = false;
                    }),
                  ),
                  _JoinRuleTile(
                    value: 'knock_restricted',
                    groupValue: _joinRule,
                    icon: LucideIcons.shield,
                    title: l10n.joinRuleKnockRestricted,
                    enabled: !_loading,
                    onChanged: (v) => setState(() {
                      _joinRule = v;
                      _isPublic = false;
                    }),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          const SizedBox(height: 32),

          // ── Create button ────────────────────────────────────────
          FilledButton.icon(
            onPressed: _loading ? null : _createRoom,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(LucideIcons.plus, size: 18),
            label: Text(_loading ? l10n.loading : l10n.createRoom),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String get _typeLabel => _isSpace ? 'space' : 'room';
}

/// A radio list tile used inside the join rules picker.
class _JoinRuleTile extends StatelessWidget {
  const _JoinRuleTile({
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.title,
    required this.enabled,
    required this.onChanged,
  });

  final String value;
  final String groupValue;
  final IconData icon;
  final String title;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selected = value == groupValue;

    return ListTile(
      leading: Icon(icon,
          size: 20, color: selected ? cs.primary : cs.onSurfaceVariant),
      title: Text(title, style: const TextStyle(fontSize: 14)),
      trailing: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        size: 20,
        color: selected ? cs.primary : cs.onSurfaceVariant,
      ),
      onTap: enabled ? () => onChanged(value) : null,
      dense: true,
    );
  }
}
