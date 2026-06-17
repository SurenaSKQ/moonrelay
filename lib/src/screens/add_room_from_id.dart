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
import 'package:moonrelay/src/screens/room_directory_search.dart';
import 'package:moonrelay/src/widgets/create_room_form.dart';
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

/// A thin wrapper that embeds the reusable [CreateRoomWidget] inside the
/// tab layout so the creation form is available from the \"Add Room\" page.
class _CreateRoomTab extends StatelessWidget {
  const _CreateRoomTab();

  @override
  Widget build(BuildContext context) {
    return const CreateRoomWidget();
  }
}
