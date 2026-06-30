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

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:moonrelay/src/encryption/encryption_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// StoredAccount — immutable serialisable metadata for a single Matrix session
// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight account descriptor persisted in [SharedPreferences].
///
/// This holds the bare minimum needed to display an account in the UI and to
/// locate its per-account database on disk.  The Matrix SDK's [Client] stores
/// the actual access token, device keys, sync state etc. inside its own
/// per-account database – we never persist tokens here.
class StoredAccount {
  final String userId;
  final String homeserver;

  const StoredAccount({
    required this.userId,
    required this.homeserver,
  });

  /// A file-system-safe name for the per-account SQLite database.
  /// Example: `moonrelay__user_matrix_org.db`
  String get databaseName {
    final safe = userId.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');
    return 'moonrelay_$safe.db';
  }

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'homeserver': homeserver,
      };

  factory StoredAccount.fromJson(Map<String, dynamic> json) => StoredAccount(
        userId: json['userId'] as String,
        homeserver: json['homeserver'] as String,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StoredAccount &&
          runtimeType == other.runtimeType &&
          userId == other.userId;

  @override
  int get hashCode => userId.hashCode;

  @override
  String toString() => 'StoredAccount($userId @ $homeserver)';
}

// ─────────────────────────────────────────────────────────────────────────────
// AccountManager — ChangeNotifier that owns the multi-account lifecycle
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level controller for multi-account support.
///
/// Responsible for:
/// - Persisting the list of known accounts in [SharedPreferences].
/// - Tracking which account is currently active.
/// - Creating / destroying the [Client] and [EncryptionService] instances
///   that belong to the active account so the rest of the app can consume
///   them via [Provider].
///
/// The boot process (in `main.dart`) calls [load] once, then sets up factory
/// callbacks so this class can lazily create clients on account switch.
class AccountManager extends ChangeNotifier {
  static const String _accountsKey = 'moonrelay_saved_accounts';
  static const String _activeKey = 'moonrelay_active_account';

  final Logger log;

  AccountManager({required this.log});

  // ── Account list ───────────────────────────────────────────────────

  List<StoredAccount> _accounts = [];
  List<StoredAccount> get accounts => List.unmodifiable(_accounts);
  bool get hasAccounts => _accounts.isNotEmpty;

  // ── Active account selection ───────────────────────────────────────

  StoredAccount? _activeAccount;
  StoredAccount? get activeAccount => _activeAccount;

  /// The active Matrix [Client].  `null` while booting or during a switch.
  Client? _activeClient;
  Client? get client => _activeClient;

  /// Whether the active client has a valid session.
  bool get isLoggedIn => _activeClient?.isLogged() ?? false;

  // ── Factories (set once by the boot process) ───────────────────────

  /// Used by [switchToAccount] to obtain a fresh [Client] for a given account.
  Future<Client> Function(StoredAccount account)? clientFactory;

  /// Called with (client, storedAccount) after a client is created so the
  /// caller can attach any additional setup (encryption, tray, etc.).
  Future<void> Function(Client client)? onClientReady;

  // ── Lifecycle ──────────────────────────────────────────────────────

  /// Load persisted accounts from [SharedPreferences].
  ///
  /// Must be called once during app boot before any account-dependent
  /// operations.
  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString(_accountsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        _accounts = list
            .map((e) => StoredAccount.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        log.w('Failed to parse saved accounts', error: e);
      }
    }

    final activeUserId = prefs.getString(_activeKey);
    if (activeUserId != null && activeUserId.isNotEmpty) {
      _activeAccount = _accounts.cast<StoredAccount?>().firstWhere(
            (a) => a!.userId == activeUserId,
            orElse: () => null,
          );
    }

    // Fallback: first saved account if the stored active one is gone.
    if (_activeAccount == null && _accounts.isNotEmpty) {
      _activeAccount = _accounts.first;
    }

    log.i('AccountManager loaded: ${_accounts.length} account(s)'
        '${_activeAccount != null ? ', active: ${_activeAccount!.userId}' : ''}');
  }

  /// Persist account list and active selection to [SharedPreferences].
  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _accountsKey,
      jsonEncode(_accounts.map((a) => a.toJson()).toList()),
    );
    await prefs.setString(_activeKey, _activeAccount?.userId ?? '');
  }

  // ── Account operations ─────────────────────────────────────────────

  /// Record a new account or update an existing one, and set it as the
  /// active account with the given [client] and optional [encryptionService].
  ///
  /// Call this after a successful login or registration.  The provided
  /// [client] must already be authenticated.
  Future<void> addOrUpdateAccount(
    StoredAccount account, {
    required Client client,
    EncryptionService? encryptionService,
  }) async {
    _accounts.removeWhere((a) => a.userId == account.userId);
    _accounts.add(account);
    _activeAccount = account;
    _activeClient = client;
    _encryptionService = encryptionService;
    await _save();
    notifyListeners();
  }

  /// Switch the active account without disposing the current client.
  ///
  /// Used when the app boots with an active account or after the first login.
  /// The [client] is already alive and connected; this just tells the manager
  /// what account metadata it belongs to.
  Future<void> setActiveAccountDirect(
    StoredAccount account, {
    required Client client,
    EncryptionService? encryptionService,
  }) async {
    _activeAccount = account;
    _activeClient = client;
    _encryptionService = encryptionService;
    // Don't persist here – the account is already saved; this is just a
    // runtime association.  Notify so the provider tree re-reads.
    notifyListeners();
  }

  /// Switch to a different saved account.
  ///
  /// Disposes the current [Client] (if any), creates a fresh one for the
  /// target account via [clientFactory], and notifies listeners.
  /// Returns `true` if the new client has a valid session.
  Future<bool> switchToAccount(String userId) async {
    final idx = _accounts.indexWhere((a) => a.userId == userId);
    if (idx < 0) {
      log.w('switchToAccount: account not found $userId');
      return false;
    }
    if (_activeAccount?.userId == userId) return false; // already active

    final target = _accounts[idx];

    // Tear down the current session.
    _encryptionService?.dispose();
    _encryptionService = null;
    await _disposeActiveClient();

    // Create a fresh client for the target account.
    log.i('Switching to account $userId');
    _activeAccount = target;
    _activeClient = await clientFactory!(target);
    final loggedIn = _activeClient!.isLogged();
    if (loggedIn) {
      await onClientReady?.call(_activeClient!);
    }
    await _save();
    notifyListeners();
    return loggedIn;
  }

  /// Remove a saved account (does NOT log out from the server).
  Future<void> removeSavedAccount(String userId) async {
    _accounts.removeWhere((a) => a.userId == userId);
    if (_activeAccount?.userId == userId) {
      if (_accounts.isNotEmpty) {
        _activeAccount = _accounts.first;
      } else {
        _activeAccount = null;
        await _disposeActiveClient();
        _encryptionService = null;
      }
    }
    await _save();
    notifyListeners();
  }

  // ── Logout ─────────────────────────────────────────────────────────

  /// Log out from the server and remove the current account.
  Future<void> logout() async {
    if (_activeClient != null && _activeClient!.isLogged()) {
      try {
        await _encryptionService?.onLogout();
        await _activeClient!.logout();
      } catch (e) {
        log.w('Logout error, continuing with account removal', error: e);
      }
    }
    if (_activeAccount != null) {
      _accounts.removeWhere((a) => a.userId == _activeAccount!.userId);
    }
    await _disposeActiveClient();
    _encryptionService = null;
    _activeAccount = _accounts.isNotEmpty ? _accounts.first : null;
    await _save();
    notifyListeners();
  }

  // ── Encryption service ─────────────────────────────────────────────

  EncryptionService? _encryptionService;
  EncryptionService? get encryptionService => _encryptionService;

  // ── Internal helpers ───────────────────────────────────────────────

  Future<void> _disposeActiveClient() async {
    try {
      await _activeClient?.dispose();
    } catch (e) {
      log.w('Error disposing client', error: e);
    }
    _activeClient = null;
  }

  @override
  void dispose() {
    _disposeActiveClient();
    _encryptionService?.dispose();
    _encryptionService = null;
    super.dispose();
  }
}
