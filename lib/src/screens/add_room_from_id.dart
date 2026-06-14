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
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/widgets/label.dart';
import 'package:provider/provider.dart';

// FIXME Text Styling
class AddRoomFromID extends StatefulWidget {
  const AddRoomFromID({super.key});

  @override
  State<AddRoomFromID> createState() => _AddRoomFromIDState();
}

class _AddRoomFromIDState extends State<AddRoomFromID> {
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
          serverName: server != null ? [server] : null),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'joinRoom',
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess():
        context.push('/main/rooms/$roomidOrAlias');
      case RetryFailed(:final error):
        setState(() {
          _error = error is TimeoutException
              ? 'Joining room timed out. The server may be unreachable.'
              : 'Could not join room: $error';
        });
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    Client client = Provider.of<Client>(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.pop(),
          icon: const Icon(LucideIcons.arrowLeft),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(LucideIcons.alertCircle,
                          size: 18, color: Theme.of(context).colorScheme.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onErrorContainer,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            Text(
              'Search for the room you wish to join:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            ),
            const SizedBox(height: 8.0),
            Label(
              label: 'Room ID or Alias',
              child: TextField(
                controller: _roomIdController,
                enabled: !_loading,
              ),
            ),
            const SizedBox(height: 8.0),
            Text(
              'Enter the server to join through:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.normal),
            ),
            Text(
              'If left empty, your own homeserver will be used.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8.0),
            Label(
              label: 'Server',
              child: TextField(
                controller: _serverController,
                enabled: !_loading,
              ),
            ),
            const SizedBox(height: 12),
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
              label: Text(_loading ? 'Joining\u2026' : 'Add Room'),
            ),
          ],
        ),
      ),
    );
  }
}
