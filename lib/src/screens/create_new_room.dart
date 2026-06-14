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
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

class CreateNewRoom extends StatefulWidget {
  const CreateNewRoom({super.key});

  @override
  State<CreateNewRoom> createState() => _CreateNewRoomState();
}

class _CreateNewRoomState extends State<CreateNewRoom> {
  bool _loading = false;
  String? _error;

  Future<void> _createRoom() async {
    final client = context.read<Client>();
    final log = context.read<Logger>();

    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await withRetry(
      () => client.createRoom(),
      maxRetries: 1,
      timeout: kDefaultTimeout,
      log: log,
      label: 'createRoom',
    );

    if (!mounted) return;

    final l10n = AppLocalizations.of(context)!;

    switch (result) {
      case RetrySuccess(:final value):
        context.go('/main/rooms/$value');
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
    if (_error != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_error!)),
        );
      });
    }

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.createNewRoom),
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_loading)
              const CircularProgressIndicator()
            else ...[
              FilledButton.icon(
                icon: const Icon(LucideIcons.plus, size: 18),
                label: Text(l10n.createRoom),
                onPressed: _createRoom,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                icon: const Icon(LucideIcons.arrowLeft, size: 18),
                label: Text(l10n.back),
                onPressed: () => context.pop(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
