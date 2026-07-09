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

// Per-room composer draft persistence.
//
// The composer ([ChatBox]) lets users type long messages. If the app is
// closed, the user navigates to another room, or the send fails, the
// draft is lost. This service backs the composer with `SharedPreferences`
// so drafts survive reboots and re-entry.
//
// Drafts are namespaced per account + room so switching accounts doesn't
// leak draft text between identities. They are persisted on a debounce
// rather than on every keystroke to avoid disk thrashing.
//
// Usage:
//   ```dart
//   final drafts = DraftService.forAccount('user:example.com');
//   await drafts.save('!room:example.com', 'half-written message');
//   final draft = await drafts.load('!room:example.com');
//   ```

import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists per-room composer drafts in `SharedPreferences`.
///
/// Keys are namespaced under `draft:<accountId>:<roomId>` so multiple
/// accounts on the same machine don't collide. Drafts are stored as a
/// JSON object containing both the body and the optional `m.in_reply_to`
/// target so a reply-in-progress isn't lost when the composer closes.
class DraftService {
  /// Builds a service scoped to a single Matrix account.
  ///
  /// The [accountId] is typically `client.userID` (e.g. `@user:server`).
  DraftService.forAccount(String accountId)
      : _accountId = accountId;

  final String _accountId;
  Timer? _saveTimer;

  static const Duration _debounce = Duration(milliseconds: 500);

  /// Loads the persisted draft for [roomId], or returns an empty draft
  /// if none is stored. Network failures are caught and treated as
  /// "no draft" — composer restoration must never block startup.
  Future<RoomDraft> load(String roomId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_keyFor(roomId));
      if (raw == null || raw.isEmpty) return const RoomDraft.empty();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const RoomDraft.empty();
      return RoomDraft(
        body: (decoded['body'] as String?) ?? '',
        replyToEventId: decoded['replyToEventId'] as String?,
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch((decoded['ts'] as int?) ?? 0),
      );
    } catch (_) {
      return const RoomDraft.empty();
    }
  }

  /// Schedules a debounced save. Subsequent calls within [_debounce]
  /// reset the timer so we only hit disk once per pause-typing window.
  void scheduleSave(
    String roomId,
    String body, {
    String? replyToEventId,
  }) {
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, () {
      _persist(roomId, body, replyToEventId: replyToEventId);
    });
  }

  /// Synchronous-flush persist. Use on composer teardown or when the
  /// user explicitly clears the draft.
  Future<void> saveNow(
    String roomId,
    String body, {
    String? replyToEventId,
  }) async {
    _saveTimer?.cancel();
    await _persist(roomId, body, replyToEventId: replyToEventId);
  }

  Future<void> _persist(
    String roomId,
    String body, {
    String? replyToEventId,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trimmed = body.trim();
      // Empty drafts are removed instead of stored as empty objects to
      // keep the prefs list clean across many rooms.
      if (trimmed.isEmpty && replyToEventId == null) {
        await prefs.remove(_keyFor(roomId));
        return;
      }
      await prefs.setString(
        _keyFor(roomId),
        jsonEncode({
          'body': body,
          'replyToEventId': replyToEventId,
          'ts': DateTime.now().millisecondsSinceEpoch,
        }),
      );
    } catch (_) {
      // Persist failures are non-fatal — the composer continues working
      // in-memory; the next launch just won't restore this draft.
    }
  }

  /// Clears the draft for [roomId]. Use after a successful send.
  Future<void> clear(String roomId) async {
    _saveTimer?.cancel();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(roomId));
    } catch (_) {
      // ignore
    }
  }

  /// Cancels any pending debounced write. Use from `dispose`.
  void cancelPending() {
    _saveTimer?.cancel();
    _saveTimer = null;
  }

  /// Returns the underlying `SharedPreferences` key for [roomId]. Account
  /// scoping is applied to prevent cross-account leak.
  String _keyFor(String roomId) {
    final safeAccount = _accountId.replaceAll(':', '_');
    final safeRoom = roomId.replaceAll(':', '_');
    return 'draft:$safeAccount:$safeRoom';
  }
}

/// Immutable snapshot of a stored composer draft.
class RoomDraft {
  const RoomDraft({
    required this.body,
    required this.replyToEventId,
    required this.updatedAt,
  });

  const RoomDraft.empty()
      : body = '',
        replyToEventId = null,
        updatedAt = null;

  final String body;
  final String? replyToEventId;
  final DateTime? updatedAt;

  bool get isEmpty => body.trim().isEmpty && replyToEventId == null;
}