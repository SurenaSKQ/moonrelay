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

// Read-up-to marker: the event ID of the most recent message the
// user has actually seen in a given room. Persisted per (account, room)
// and consulted by the chat timeline to jump to the last seen position
// when the room is re-opened.
//
// ## Compare-and-swap semantics
//
// Every write carries a monotonic sequence number (_nextSeq, per-instance).
// The stored marker is only overwritten when the incoming seq exceeds the
// stored seq.  This eliminates the race where two concurrent async writes
// (e.g. from back-to-back sync updates) could re-order a newer marker
// behind an older one.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReadMarkerService {
  ReadMarkerService.forAccount(String accountId) : _accountId = accountId;

  final String _accountId;

  /// Per-instance monotonic counter.  Bumped on every write attempt so
  /// that even concurrent async invocations get distinct sequence numbers.
  int _nextSeq = 0;

  /// Persists [eventId] as the last-seen marker for [roomId], or clears
  /// the marker when [eventId] is null/empty.
  ///
  /// Only writes when the internal sequence number has advanced past the
  /// stored value, preventing a stale async write (or a stale clear)
  /// from clobbering a more recent marker.
  Future<void> setLastSeen(String roomId, String? eventId) async {
    final prefs = await SharedPreferences.getInstance();
    final seq = ++_nextSeq;
    final raw = prefs.getString(_keyFor(roomId));

    // Compare-and-swap: skip write if the stored seq is >= ours.
    if (_storedSeq(raw) >= seq) return; // stale write or clear, discard

    if (eventId == null || eventId.isEmpty) {
      // Persist a tombstone rather than removing the key outright.  A
      // concurrent stale write carrying an older seq would otherwise
      // resurrect a marker the user just cleared.
      await prefs.setString(
        _keyFor(roomId),
        jsonEncode({
          'eventId': null,
          'seq': seq,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );
      return;
    }

    await prefs.setString(
      _keyFor(roomId),
      jsonEncode({
        'eventId': eventId,
        'seq': seq,
        'ts': DateTime.now().millisecondsSinceEpoch,
      }),
    );
  }

  /// Extracts the sequence number stored in [raw], or `-1` when absent
  /// or corrupt (so an unset or broken marker is always writable).
  static int _storedSeq(String? raw) {
    if (raw == null || raw.isEmpty) return -1;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['seq'] is int) {
        return decoded['seq'] as int;
      }
    } catch (_) {
      // Corrupt entry: treat as unset.
    }
    return -1;
  }

  /// Returns the last-seen event ID for [roomId], or `null` if no
  /// marker has been persisted.
  Future<String?> getLastSeen(String roomId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_keyFor(roomId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) return decoded['eventId'] as String?;
    } catch (_) {}
    return null;
  }

  String _keyFor(String roomId) {
    final safeAccount = _accountId.replaceAll(':', '_');
    final safeRoom = roomId.replaceAll(':', '_');
    return 'lastseen:$safeAccount:$safeRoom';
  }
}
