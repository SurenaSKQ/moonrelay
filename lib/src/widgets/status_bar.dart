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
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';

/// A thin status bar that sits below the main dashboard content and reports
/// the current Matrix sync state by listening to [Client.onSyncStatus].
class ApplicationStatusBar extends StatefulWidget {
  const ApplicationStatusBar({super.key});

  @override
  State<ApplicationStatusBar> createState() => _ApplicationStatusBarState();
}

class _ApplicationStatusBarState extends State<ApplicationStatusBar> {
  StreamSubscription<SyncStatusUpdate>? _sub;
  SyncStatus _status = SyncStatus.finished;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sub?.cancel();
    final client = context.read<Client>();
    _sub = client.onSyncStatus.stream.listen((update) {
      if (!mounted) return;
      setState(() => _status = update.status);
    });
    // Seed with the latest known status if available.
    try {
      final known = client.onSyncStatus.value;
      if (known != null) _status = known.status;
    } catch (_) {}
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String statusLabel;

    switch (_status) {
      case SyncStatus.waitingForResponse:
        statusLabel = 'Waiting for response';
      case SyncStatus.processing:
      case SyncStatus.cleaningUp:
        statusLabel = 'Syncing';
      case SyncStatus.error:
        statusLabel = 'Error';
      case SyncStatus.finished:
        statusLabel = 'Synced';
    }

    return Container(
      height: 24,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            'Status: $statusLabel',
            style: TextStyle(
              fontSize: 11,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
