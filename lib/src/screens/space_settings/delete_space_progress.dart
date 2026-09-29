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
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

class DeleteSpaceProgressDialog extends StatefulWidget {
  const DeleteSpaceProgressDialog({
    super.key,
    required this.space,
    required this.childRooms,
    required this.l10n,
    required this.log,
  });

  final Room space;
  final List<Room> childRooms;
  final AppLocalizations l10n;
  final Logger log;

  @override
  State<DeleteSpaceProgressDialog> createState() =>
      DeleteSpaceProgressDialogState();
}

class DeleteSpaceProgressDialogState
    extends State<DeleteSpaceProgressDialog> {
  int _deleted = 0;
  String? _error;
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _deleteAll());
  }

  Future<void> _deleteAll() async {
    final l10n = widget.l10n;
    final log = widget.log;
    final space = widget.space;
    final client = space.client;

    for (final child in widget.childRooms) {
      try {
        final serverUrl = client.homeserver.toString();
        final url = serverUrl.endsWith('/')
            ? '${serverUrl}_synapse/admin/v2/rooms/${child.id}/delete'
            : '$serverUrl/_synapse/admin/v2/rooms/${child.id}/delete';

        await withRetry(
          () => client.httpClient.post(
            Uri.parse(url),
            body: '{}',
            headers: {'authorization': 'Bearer ${client.accessToken}'},
          ),
          maxRetries: 1,
          timeout: kDefaultTimeout,
          log: log,
          label: 'deleteChildRoom',
        );
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _error = l10n.deleteChildRoomFailed(
            child.getLocalizedDisplayname(),
            '$e',
          );
        });
      }

      if (!mounted) return;
      setState(() => _deleted++);
    }

    try {
      final serverUrl = client.homeserver.toString();
      final url = serverUrl.endsWith('/')
          ? '${serverUrl}_synapse/admin/v2/rooms/${space.id}/delete'
          : '$serverUrl/_synapse/admin/v2/rooms/${space.id}/delete';

      await withRetry(
        () => client.httpClient.post(
          Uri.parse(url),
          body: '{}',
          headers: {'authorization': 'Bearer ${client.accessToken}'},
        ),
        maxRetries: 1,
        timeout: kDefaultTimeout,
        log: log,
        label: 'deleteSpace',
      );

      await space.leave();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.deleteSpaceFailed('$e');
      });
    }

    if (!mounted) return;
    setState(() => _done = true);

    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_error ?? l10n.deleteSpaceSuccess),
        behavior: SnackBarBehavior.floating,
      ),
    );
    if (context.mounted) context.go('/main/rooms');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;
    final total = widget.childRooms.length + 1;

    return AlertDialog(
      title: Text(widget.l10n.deleteSpace),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          LinearProgressIndicator(
            value: _done ? 1.0 : _deleted / total,
          ),
          SizedBox(height: t.spaceLg),
          Text(
            _done
                ? widget.l10n.deleteSpaceSuccess
                : _error ??
                    '$_deleted / $total ${widget.l10n.delete.toLowerCase()}',
            style: TextStyle(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
