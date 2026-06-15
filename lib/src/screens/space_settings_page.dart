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

import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

/// A settings page for a space that lets the user add and remove rooms.
///
/// Shows the list of current child rooms with a "remove" action, and
/// provides a "Add Room to Space" button that opens a room picker.
class SpaceSettingsPage extends StatefulWidget {
  const SpaceSettingsPage({super.key, required this.space});

  final Room space;

  @override
  State<SpaceSettingsPage> createState() => _SpaceSettingsPageState();
}

class _SpaceSettingsPageState extends State<SpaceSettingsPage> {
  StreamSubscription? _syncSub;

  @override
  void initState() {
    super.initState();
    final client = context.read<Client>();
    _syncSub = client.onSync.stream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _syncSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    final space = widget.space;

    // Current children (rooms and subspaces).
    final children = space.spaceChildren;
    final client = space.client;

    // Rooms that the user has joined and that are NOT already children.
    final availableRooms = client.rooms.where((r) {
      if (r.id == space.id) return false;
      if (r.isSpace) return false; // Only show regular rooms for adding.
      return !children.any((c) => c.roomId == r.id);
    }).toList()
      ..sort((a, b) => a
          .getLocalizedDisplayname()
          .toLowerCase()
          .compareTo(b.getLocalizedDisplayname().toLowerCase()));

    final canEdit = space.canChangeStateEvent('m.space.child');

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          l10n.spaceSettings,
          style: textTheme.titleLarge,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // ── Description ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Text(
              l10n.spaceSettingsDescription,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 14,
              ),
            ),
          ),

          // ── Child rooms / subspaces ────────────────────────────────────
          if (children.isNotEmpty) ...[
            _SectionHeader(title: l10n.spaceChildRooms, scheme: scheme),
            const SizedBox(height: 8),
            ...children.map((child) {
              final childRoomId = child.roomId;
              if (childRoomId == null) return const SizedBox.shrink();
              final childRoom = client.getRoomById(childRoomId);
              final name = childRoom?.getLocalizedDisplayname() ?? childRoomId;
              final isSpace = childRoom?.isSpace ?? false;

              return Card(
                elevation: 0,
                margin: const EdgeInsets.only(bottom: 4),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(
                      isSpace ? LucideIcons.folder : LucideIcons.hash,
                      size: 16,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  title: Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: child.suggested == true
                      ? Text(
                          l10n.suggested,
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.tertiary,
                          ),
                        )
                      : null,
                  trailing: canEdit
                      ? IconButton(
                          icon: Icon(
                            LucideIcons.trash2,
                            size: 18,
                            color: scheme.error,
                          ),
                          tooltip: l10n.removeRoomFromSpace,
                          onPressed: () => _removeChild(context, childRoomId),
                        )
                      : null,
                ),
              );
            }),
            const SizedBox(height: 16),
          ],

          // ── Add room section ──────────────────────────────────────────
          if (canEdit) ...[
            _SectionHeader(title: l10n.addRoomToSpace, scheme: scheme),
            const SizedBox(height: 8),
            if (availableRooms.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text(
                    l10n.spaceNoChildren,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              )
            else
              ...availableRooms.map((room) {
                return Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: scheme.outlineVariant.withValues(alpha: 0.3),
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      radius: 16,
                      backgroundColor: scheme.primaryContainer,
                      child: Icon(
                        LucideIcons.hash,
                        size: 16,
                        color: scheme.onPrimaryContainer,
                      ),
                    ),
                    title: Text(
                      room.getLocalizedDisplayname(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        LucideIcons.plus,
                        size: 18,
                        color: scheme.primary,
                      ),
                      tooltip: l10n.addRoomToSpace,
                      onPressed: () => _addChild(context, room.id),
                    ),
                  ),
                );
              }),
          ],
        ],
      ),
    );
  }

  Future<void> _addChild(BuildContext context, String roomId) async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    try {
      await withRetry(
        () => widget.space.setSpaceChild(roomId),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'addSpaceChild',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.roomAddedToSpace),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _removeChild(BuildContext context, String roomId) async {
    final l10n = AppLocalizations.of(context)!;
    final log = context.read<Logger>();
    try {
      await withRetry(
        () => widget.space.removeSpaceChild(roomId),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'removeSpaceChild',
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.roomRemovedFromSpace),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${l10n.error}: $e'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

/// A section header label.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.scheme});

  final String title;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
    );
  }
}
