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
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/sync_pulse.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:provider/provider.dart';

/// A scrollable list of all rooms the user is a member of.
///
/// Listens to the client sync stream directly and maintains its own
/// sync-state flag so it refreshes correctly even when the widget is
/// mounted after the initial sync has already completed.
class SpacesPane extends StatefulWidget {
  const SpacesPane({
    super.key,
  });

  @override
  State<SpacesPane> createState() => _SpacesPaneState();
}

class _SpacesPaneState extends State<SpacesPane> {
  bool _disposed = false;
  Timer? _settleTimer;

  /// True once the room list has stabilised (no room count change across
  /// multiple consecutive syncs, or a timeout expires). While false, the
  /// pane keeps reacting to sync events to pick up newly loaded rooms.
  bool _settled = false;

  /// Number of rooms observed at the last sync event.
  int _lastRoomCount = 0;

  /// How many consecutive syncs have had the same room count.
  int _stableStreak = 0;

  /// Maximum streak before we consider the list settled.
  static const int _settleThreshold = 5;

  /// Hard timeout  if we still haven't settled after this, just show what
  /// we have.
  static const Duration _settleTimeout = Duration(seconds: 30);

  /// Monotonically increasing version of the shared sync pulse. Read in
  /// [build] to subscribe to debounced sync ticks.
  int _syncVersion = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // `context.select` is only legal inside `build`. The pulse read
    // happens in [build] below; the version check there compares
    // against the cached [_syncVersion] and runs the settle tick
    // handler when the pulse moves.
  }

  @override
  void didUpdateWidget(covariant SpacesPane oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-reset settle state on widget swap (e.g. tab switch). The
    // pulse-driven path will pick up the change once it next ticks.
    if (oldWidget.key != widget.key) {
      _attach();
    }
  }

  void _attach() {
    _disposed = false;
    _settleTimer?.cancel();
    _settled = false;
    _lastRoomCount = 0;
    _stableStreak = 0;

    final client = context.read<Client>();

    // Treat the current tick as the first observation: if the count is
    // already stable, we'll settle in a few pulses; otherwise we wait.
    if (client.rooms.isNotEmpty) {
      _lastRoomCount = client.rooms.length;
    }

    // Hard timeout: after 30 seconds show whatever we have.
    _settleTimer = Timer(_settleTimeout, () {
      if (mounted && !_disposed) setState(() => _settled = true);
    });
  }

  /// Called from [build] on every sync tick. Uses [setState] only when
  /// the room count changed; otherwise just updates the streak so a
  /// no-op sync doesn't trigger an extra rebuild.
  void _onSyncTick() {
    if (!mounted || _disposed) return;
    final client = context.read<Client>();
    final count = client.rooms.length;
    if (count == _lastRoomCount) {
      _stableStreak++;
      if (_stableStreak >= _settleThreshold) {
        _settleTimer?.cancel();
        if (!_settled) setState(() => _settled = true);
      }
      return;
    }
    _lastRoomCount = count;
    _stableStreak = 0;
    setState(() {});
  }

  @override
  void dispose() {
    _disposed = true;
    _settleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Client client = Provider.of<Client>(context);
    final scheme = Theme.of(context).colorScheme;

    // `context.select` is only legal inside [build]. Subscribe to
    // the shared pulse here; the version check below triggers the
    // settle-tick handler whenever the pulse moves.
    final pulseVersion = context.select<SyncPulse, int>((p) => p.version);
    if (pulseVersion != _syncVersion) {
      _syncVersion = pulseVersion;
      if (pulseVersion > 0) _onSyncTick();
    }

    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Expanded(
          child: _buildBody(client, scheme, l10n),
        ),
      ],
    );
  }

  Widget _buildBody(Client client, ColorScheme scheme, AppLocalizations l10n) {
    final rooms = client.rooms.where((r) => r.isSpace).toList();

    // Loading state  keep retrying until the room list stabilises.
    if (!_settled) {
      // Show a compact footer loader when we already have some rooms.
      if (rooms.isNotEmpty) {
        return Column(
          children: [
            Expanded(
              child: _buildRoomList(rooms, scheme, l10n),
            ),
            _buildLoadingFooter(scheme, l10n),
          ],
        );
      }

      // No rooms at all yet  full-screen spinner.
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.loadingRooms,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    // Empty state (settled but no rooms).
    if (rooms.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                LucideIcons.messageCircle,
                size: 40,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
              ),
              const SizedBox(height: 12),
              Text(
                l10n.noRoomsYet,
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      );
    }

    return _buildRoomList(rooms, scheme, l10n);
  }

  Widget _buildLoadingFooter(ColorScheme scheme, AppLocalizations l10n) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            l10n.loadingRooms,
            style: TextStyle(
              fontSize: 12,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomList(
    List<Room> rooms,
    ColorScheme scheme,
    AppLocalizations l10n,
  ) {
    return ListView.builder(
      itemCount: rooms.length,
      itemBuilder: (context, index) => ListTile(
        leading: CircleAvatar(
          foregroundImage: rooms[index].avatar == null
              ? null
              : NetworkImage(
                  rooms[index].avatar.toString(),
                ),
          onForegroundImageError: (_, __) {},
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                rooms[index].getLocalizedDisplayname(),
              ),
            ),
          ],
        ),
        subtitle: Text(
          rooms[index].lastEvent?.body ?? l10n.noMessages,
          maxLines: 1,
        ),
        trailing: (rooms[index].notificationCount > 0)
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: scheme.error,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  rooms[index].notificationCount.toString(),
                  style: TextStyle(
                    color: scheme.onError,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            : null,
        onTap: () {
          // Open the space home page directly
          context.push('/main/space/${rooms[index].id}');
        },
      ),
    );
  }
}
