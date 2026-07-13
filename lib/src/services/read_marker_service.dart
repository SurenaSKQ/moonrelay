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

// Read-up-to marker  the event ID of the most recent message the
// user has actually seen in a given room. Persisted per (account, room)
// and consulted by the chat timeline to jump to the last seen position
// when the room is re-opened.

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class ReadMarkerService {
  ReadMarkerService.forAccount(String accountId) : _accountId = accountId;

  final String _accountId;

  Future<void> setLastSeen(String roomId, String? eventId) async {
    final prefs = await SharedPreferences.getInstance();
    if (eventId == null || eventId.isEmpty) {
      await prefs.remove(_keyFor(roomId));
      return;
    }
    await prefs.setString(
      _keyFor(roomId),
      jsonEncode({'eventId': eventId, 'ts': DateTime.now().millisecondsSinceEpoch}),
    );
  }

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