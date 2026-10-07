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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/services/notification_service.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/room_notification_sheet.dart';
import 'package:provider/provider.dart';

class RoomNotificationTile extends StatefulWidget {
  const RoomNotificationTile({
    super.key,
    required this.room});

  final Room room;

  @override
  State<RoomNotificationTile> createState() => RoomNotificationTileState();
}

class RoomNotificationTileState extends State<RoomNotificationTile> {
  bool _muted = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadMutedState();
  }

  Future<void> _loadMutedState() async {
    final notif = context.read<NotificationService>();
    final muted = await notif.isRoomMuted(widget.room.id);
    if (mounted) {
      setState(() {
        _muted = muted;
        _loading = false;
      });
    }
  }

  Future<void> _toggle() async {
    final notif = context.read<NotificationService>();
    final newMuted = !_muted;
    await notif.setRoomMuted(widget.room.id, newMuted);
    if (mounted) {
      setState(() => _muted = newMuted);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newMuted
                ? AppLocalizations.of(context)!.roomMuted
                : AppLocalizations.of(context)!.roomUnmuted,
          ),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    final client = context.read<Client>();
    return Card(
      elevation: t.elevationNone,
      color: scheme.surfaceContainerLow,
      child: Column(
        children: [
          SwitchListTile(
            secondary: Icon(
              _muted ? LucideIcons.bellOff : LucideIcons.bell,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(l10n.muteRoom),
            subtitle: Text(l10n.muteRoomDescription),
            value: _muted,
            onChanged: _loading ? null : (_) => _toggle(),
          ),
          const Divider(height: 0),
          ListTile(
            leading: Icon(
              LucideIcons.settings,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(l10n.notificationSettings),
            trailing: Icon(
              LucideIcons.chevronRight,
              color: scheme.onSurfaceVariant,
            ),
            onTap: () => showRoomNotificationSheet(
              context,
              client: client,
              room: widget.room,
            ),
          ),
        ],
      ),
    );
  }
}
