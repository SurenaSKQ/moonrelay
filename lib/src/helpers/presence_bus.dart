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
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:matrix/matrix.dart';

/// Process-wide fan-out for `Client.onPresenceChanged`.
///
/// Contact presence was frozen at first fetch for the whole session. The
/// SDK caches every presence it sees in a map with no TTL, and the only
/// thing that invalidates an entry is a presence event arriving over
/// `/sync`; the app never subscribed to one. So a member who came online
/// after you opened the list stayed shown as offline until you closed
/// and reopened the screen, and the relative "active 5m ago" strings
/// were computed from a frozen timestamp.
///
/// Modelled on [RoomStateBus]: one stream subscription for the whole
/// app, and per-user [ValueListenable]s that consumers read with O(1)
/// work, rather than every member tile subscribing and filtering.
class PresenceBus extends ChangeNotifier {
  PresenceBus({int maxUsers = 5000}) : _maxUsers = maxUsers;

  /// Hard cap on tracked users. A large directory server can report
  /// presence for tens of thousands, so this is generous; the bound
  /// exists so a pathological account cannot grow the map without limit.
  final int _maxUsers;

  /// Per-user notifiers, lazily allocated. A [LinkedHashMap] so LRU
  /// eviction is a move-to-end rather than a sort.
  final LinkedHashMap<String, ValueNotifier<CachedPresence?>> _perUser =
      LinkedHashMap<String, ValueNotifier<CachedPresence?>>();

  /// The presence most recently seen for a user, for consumers that read
  /// on first build rather than waiting for a change.
  final Map<String, CachedPresence> _latest = <String, CachedPresence>{};

  StreamSubscription<CachedPresence>? _sub;
  Client? _boundClient;

  /// Binds to [client]'s presence stream, replacing any prior binding.
  ///
  /// Rebinds rather than early-returning, because a new client is a new
  /// stream: leaving the old subscription attached would keep this bus
  /// pointed at a disposed client's controller.
  void bind(Client client) {
    if (identical(_boundClient, client) && _sub != null) return;
    _sub?.cancel();
    _boundClient = client;
    // The cache belongs to the previous account, so it goes with it.
    for (final notifier in _perUser.values) {
      notifier.dispose();
    }
    _perUser.clear();
    _latest.clear();

    _sub = client.onPresenceChanged.stream.listen(
      _onPresence,
      onError: (Object _) {
        // The SDK's presence stream is a CachedStreamController that can
        // error when the client is disposed underneath us. A presence
        // update is not worth tearing the bus down for.
      },
    );
  }

  void _onPresence(CachedPresence presence) {
    _latest[presence.userid] = presence;
    final notifier = _perUser[presence.userid];
    if (notifier != null) {
      // Move-to-end for LRU before notifying, so a consumer that reads
      // presenceOf during the notification sees an already-current map.
      _perUser.remove(presence.userid);
      _perUser[presence.userid] = notifier;
      notifier.value = presence;
    }
  }

  /// The notifier for [userId], allocated on first request.
  ///
  /// Consumers watch this and read [presenceOf] for the value, rather
  /// than holding the presence itself, so a single fetch serves every
  /// tile for that user.
  ValueListenable<CachedPresence?> listenTo(String userId) {
    final existing = _perUser[userId];
    if (existing != null) {
      // Move-to-end for LRU.
      _perUser.remove(userId);
      _perUser[userId] = existing;
      return existing;
    }
    final notifier = ValueNotifier<CachedPresence?>(_latest[userId]);
    _perUser[userId] = notifier;
    _evictIfNeeded();
    return notifier;
  }

  /// The presence last seen for [userId], or null if none has arrived.
  CachedPresence? presenceOf(String userId) => _latest[userId];

  /// Drops every tracked user. Used when the account logs out, so a
  /// later login does not see the previous account's presence.
  void clear() {
    for (final notifier in _perUser.values) {
      notifier.dispose();
    }
    _perUser.clear();
    _latest.clear();
  }

  void _evictIfNeeded() {
    while (_perUser.length > _maxUsers) {
      final oldest = _perUser.keys.first;
      _perUser.remove(oldest)?.dispose();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _sub = null;
    clear();
    super.dispose();
  }
}
