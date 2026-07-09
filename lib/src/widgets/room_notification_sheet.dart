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

// Per-room notification override sheet.
//
// Opens as a bottom sheet from the room settings page (or any context
// that has a [Client] + [Room]). Lets the user toggle "muted" via
// [NotificationService.setRoomMuted]; mentions-only is exposed as a
// checkbox that is recorded locally so the UI can render the intent,
// even when the homeserver does not honour per-room push rules.
//
// Wiring lives in the consuming screen; this widget only renders the
// sheet.

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// `SharedPreferences` key used by [NotificationService] to persist the
/// set of muted rooms.  Mirror the key so the per-room sheet reads /
/// writes the same value.
const String _mutedRoomsKey = 'notification_muted_rooms';

Future<void> showRoomNotificationSheet(
  BuildContext context, {
  required Client client,
  required Room room,
}) {
  return showModalBottomSheet(
    context: context,
    builder: (_) => _RoomNotificationSheet(client: client, room: room),
  );
}

class _RoomNotificationSheet extends StatefulWidget {
  const _RoomNotificationSheet({required this.client, required this.room});

  final Client client;
  final Room room;

  @override
  State<_RoomNotificationSheet> createState() =>
      _RoomNotificationSheetState();
}

class _RoomNotificationSheetState extends State<_RoomNotificationSheet> {
  bool _isMuted = false;
  bool _onlyMentions = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final muted = (prefs.getStringList(_mutedRoomsKey) ?? const <String>[])
        .contains(widget.room.id);
    final userId = widget.client.userID;
    if (!mounted) return;
    setState(() {
      _isMuted = muted;
      _onlyMentions = userId == null
          ? false
          : prefs.getBool('mention_only:$userId:${widget.room.id}') ?? false;
    });
  }

  Future<void> _setMuted(bool muted) async {
    setState(() => _isMuted = muted);
    final prefs = await SharedPreferences.getInstance();
    final ids = (prefs.getStringList(_mutedRoomsKey) ?? const <String>[])
        .toSet();
    if (muted) {
      ids.add(widget.room.id);
    } else {
      ids.remove(widget.room.id);
    }
    await prefs.setStringList(_mutedRoomsKey, ids.toList());
  }

  Future<void> _setMentions(bool onlyMentions) async {
    setState(() => _onlyMentions = onlyMentions);
    final userId = widget.client.userID;
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('mention_only:$userId:${widget.room.id}', onlyMentions);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context)!;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(LucideIcons.bell,
                    color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.room.getLocalizedDisplayname(),
                    style: Theme.of(context).textTheme.titleMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              title: Text(loc.muteRoom),
              subtitle: Text(loc.muteRoomDescription),
              value: _isMuted,
              onChanged: _setMuted,
            ),
            SwitchListTile(
              title: Text(loc.notifyOnMentionsOnly),
              subtitle: Text(loc.notifyOnMentionsOnlyDescription),
              value: _onlyMentions,
              onChanged: _setMentions,
            ),
          ],
        ),
      ),
    );
  }
}