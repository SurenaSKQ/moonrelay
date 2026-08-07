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
// One [DraftService] instance is created per account and shared across
// every ChatBox in the app via [DraftService.instanceFor]. The instance
// is reference-counted: each caller invokes [release] in a `finally`
// block; the last release flushes any queued drafts and drops the
// service, so a hot-swap of ChatBox instances (e.g. user switches
// rooms) never leaks a pending disk write or loses a draft.

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
  DraftService._internal(this._accountId) {
    _liveInstances[_accountId] = (_liveInstances[_accountId] ?? 0) + 1;
  }

  final String _accountId;
  Timer? _saveTimer;

  /// Drafts awaiting a debounced flush, keyed by room id.  Keeping the
  /// pending body here (rather than only capturing the last room in the
  /// timer closure) means typing in room B no longer cancels room A's
  /// pending save: one timer flushes every room that was edited within
  /// the debounce window.
  final Map<String, ({String body, String? replyToEventId})>
      _pendingSaves = <String, ({String body, String? replyToEventId})>{};

  /// Active services per account, used so that [instanceFor] returns
  /// the same instance instead of allocating a new one every time the
  /// ChatBox remounts.  Multiple instances would clobber each other's
  /// in-flight debounce timers.
  static final Map<String, DraftService> _services = <String, DraftService>{};

  /// Tracks the number of [DraftService.instanceFor] consumers per
  /// account. When the last consumer calls [release], the timer is
  /// cancelled and the service is dropped from [_services] so a fresh
  /// login allocates a clean instance.
  static final Map<String, int> _liveInstances = <String, int>{};

  /// Returns the shared [DraftService] for [accountId], allocating it
  /// on first access. Increments the reference count; the caller MUST
  /// invoke [release] in a `finally` block to balance it.
  static DraftService instanceFor(String accountId) {
    final existing = _services[accountId];
    if (existing != null) {
      existing._ref();
      return existing;
    }
    final created = DraftService._internal(accountId);
    _services[accountId] = created;
    return created;
  }

  void _ref() {
    _liveInstances[_accountId] = (_liveInstances[_accountId] ?? 0) + 1;
  }

  /// Decrements the reference count. When the count returns to zero
  /// the pending drafts are flushed, the timer is cancelled, and the
  /// service is dropped from the shared map so the next login allocates
  /// a fresh service.  Flushing (instead of dropping) means closing the
  /// last composer within the debounce window still persists the draft.
  void release() {
    final count = (_liveInstances[_accountId] ?? 1) - 1;
    if (count <= 0) {
      _liveInstances.remove(_accountId);
      _saveTimer?.cancel();
      _saveTimer = null;
      _flushPendingSaves();
      if (identical(_services[_accountId], this)) {
        _services.remove(_accountId);
      }
    } else {
      _liveInstances[_accountId] = count;
    }
  }

  static const Duration _debounce = Duration(milliseconds: 500);

  /// Loads the persisted draft for [roomId], or returns an empty draft
  /// if none is stored. Network failures are caught and treated as
  /// "no draft" - composer restoration must never block startup.
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
  ///
  /// Pending bodies are tracked per room, so typing in a different room
  /// before the timer fires does not cancel another room's pending
  /// draft; the flush persists every room that changed.
  void scheduleSave(
    String roomId,
    String body, {
    String? replyToEventId,
  }) {
    _pendingSaves[roomId] = (
      body: body,
      replyToEventId: replyToEventId,
    );
    _saveTimer?.cancel();
    _saveTimer = Timer(_debounce, _flushPendingSaves);
  }

  void _flushPendingSaves() {
    _saveTimer = null;
    if (_pendingSaves.isEmpty) return;
    final pending = Map<
        String,
        ({String body, String? replyToEventId})>.from(_pendingSaves);
    _pendingSaves.clear();
    for (final entry in pending.entries) {
      unawaited(
        _persist(
          entry.key,
          entry.value.body,
          replyToEventId: entry.value.replyToEventId,
        ),
      );
    }
  }

  /// Synchronous-flush persist. Use on composer teardown or when the
  /// user explicitly clears the draft.
  Future<void> saveNow(
    String roomId,
    String body, {
    String? replyToEventId,
  }) async {
    _saveTimer?.cancel();
    _pendingSaves.remove(roomId);
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
      // Persist failures are non-fatal - the composer continues working
      // in-memory; the next launch just won't restore this draft.
    }
  }

  /// Clears the draft for [roomId]. Use after a successful send.
  Future<void> clear(String roomId) async {
    _saveTimer?.cancel();
    _pendingSaves.remove(roomId);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyFor(roomId));
    } catch (_) {
      // ignore
    }
  }

  /// Cancels any pending debounced write and forgets the queued
  /// drafts. The reference count is not decremented; use [release] for
  /// that.
  void cancelPending() {
    _saveTimer?.cancel();
    _saveTimer = null;
    _pendingSaves.clear();
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
