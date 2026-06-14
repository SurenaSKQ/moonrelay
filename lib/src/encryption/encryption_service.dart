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

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';

// ---------------------------------------------------------------------------
// Re-export SDK types so UI code can import from a single place.
// ---------------------------------------------------------------------------

export 'package:matrix/encryption/utils/key_verification.dart'
    show KeyVerification, KeyVerificationState, KeyVerificationMethod;

/// Central encryption coordinator.
///
/// Provides a single high-level API for cross-signing, key backup, device
/// management, and SAS verification.  Widgets can listen to this via
/// [ChangeNotifier] to react to state changes.
///
/// Usage
/// -----
/// ```dart
/// final enc = EncryptionService(client: client, logger: log);
/// await enc.init();
/// ```
class EncryptionService extends ChangeNotifier {
  EncryptionService({
    required Client client,
    required Logger logger,
  })  : _client = client,
        _log = logger;

  final Client _client;
  final Logger _log;

  // -----------------------------------------------------------------------
  // Convenience accessors
  // -----------------------------------------------------------------------

  Encryption? get _enc => _client.encryption;
  bool get isSupported => _enc != null && _client.encryptionEnabled;

  // -----------------------------------------------------------------------
  // Observable state
  // -----------------------------------------------------------------------

  bool _crossSigningBootstrapped = false;
  bool get crossSigningBootstrapped => _crossSigningBootstrapped;

  bool _keyBackupExists = false;
  bool get keyBackupExists => _keyBackupExists;

  List<Device> _myDevices = const [];
  List<Device> get myDevices => _myDevices;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  Stream<KeyVerification> get onKeyVerificationRequest =>
      _client.onKeyVerificationRequest.stream;

  StreamSubscription? _syncSubscription;

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  /// Must be called once after the [Client] has logged in and the
  /// SDK has set up its encryption subsystem.
  ///
  /// Attaches a sync listener and refreshes cross-signing, key backup,
  /// and device state.  The Matrix SDK initialises the Olm/Megolm engine
  /// automatically during login; this method waits for it to be ready.
  Future<void> init() async {
    if (_isInitialized) return;
    _log.i('EncryptionService: initializing');

    // ── Wait for the SDK to finish setting up encryption ────────────
    // The Matrix SDK creates and initialises the Encryption object
    // during the login flow.  If it hasn't finished yet, give it a
    // brief window before we start querying its state.
    var waited = 0;
    while (_client.encryption == null && waited < 50) {
      await Future.delayed(const Duration(milliseconds: 100));
      waited++;
    }
    if (_client.encryption == null) {
      _log.w('EncryptionService: encryption object still null after waiting; '
          'the SDK may not support encryption on this homeserver');
      // We still set up the sync listener so state will be refreshed if
      // encryption becomes available later.
    }

    // ── Attach sync listener BEFORE the first refresh so we don't ──
    // ── miss a sync event that fires concurrently.                ──
    _syncSubscription = _client.onSync.stream.listen((_) {
      _cachedUnverified = null;
      _refreshCrossSigningStatus();
      _refreshBackupState();
      _refreshMyDevices();
    });

    try {
      _isBusy = true;
      notifyListeners();

      await _refreshCrossSigningStatus();
      await _refreshBackupState();
      await _refreshMyDevices();

      _isInitialized = true;
      _log.i('EncryptionService: initialized');
    } catch (e, s) {
      _log.e('EncryptionService: init failed', error: e, stackTrace: s);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Dispose of resources. Call when the service is no longer needed.
  @override
  void dispose() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
    super.dispose();
  }

  // -----------------------------------------------------------------------
  // Cross-signing
  // -----------------------------------------------------------------------

  /// Whether cross-signing is fully set up (via SSSS).
  Future<void> _refreshCrossSigningStatus() async {
    try {
      final enc = _enc;
      if (enc == null) {
        _crossSigningBootstrapped = false;
        return;
      }
      _crossSigningBootstrapped = enc.crossSigning.enabled;
    } catch (e, s) {
      _log.w('could not refresh cross-signing status', error: e, stackTrace: s);
    }
  }

  /// Start the bootstrap process.  Returns a [Bootstrap] object whose state
  /// you can listen to (via [Bootstrap.onUpdate]) to drive a wizard UI.
  Bootstrap startBootstrap() {
    _log.i('EncryptionService: starting bootstrap');
    final enc = _enc;
    if (enc == null) throw Exception('Encryption not available');

    final bootstrap = enc.bootstrap(
      onUpdate: (_) {
        _refreshCrossSigningStatus();
        _refreshBackupState();
        notifyListeners();
      },
    );
    notifyListeners();
    return bootstrap;
  }

  /// Quick-check: is the current user cross-signed?
  bool get isUserVerified => _crossSigningBootstrapped && isThisDeviceVerified;

  /// Whether the current device is verified via cross-signing.
  bool get isThisDeviceVerified {
    try {
      final enc = _enc;
      if (enc == null) return false;
      return _client.userDeviceKeys[_client.userID]
              ?.deviceKeys[_client.deviceID]?.verified ==
          true;
    } catch (_) {
      return false;
    }
  }

  /// Whether [userId] is verified via cross-signing.
  bool isUserVerifiedById(String userId) {
    try {
      final enc = _enc;
      if (enc == null) return false;
      return _client.userDeviceKeys[userId]?.masterKey?.verified == true;
    } catch (_) {
      return false;
    }
  }

  // -----------------------------------------------------------------------
  // Key backup
  // -----------------------------------------------------------------------

  Future<void> _refreshBackupState() async {
    try {
      final enc = _enc;
      if (enc == null) {
        _keyBackupExists = false;
        return;
      }
      // Key backup is active when the megolm key secret is stored in SSSS.
      _keyBackupExists = enc.keyManager.enabled;
    } catch (_) {
      _keyBackupExists = false;
    }
  }

  /// Whether the online key backup is active and keys are being uploaded.
  bool get isKeyBackupEnabled => _keyBackupExists;

  // -----------------------------------------------------------------------
  // Device management
  // -----------------------------------------------------------------------

  Future<void> _refreshMyDevices() async {
    try {
      if (!_client.isLogged()) return;
      final devices = await withTimeout(
        () => _client.getDevices(),
        timeout: kDefaultTimeout,
      );
      _myDevices = devices ?? [];
      notifyListeners();
    } catch (e, s) {
      _log.w('could not refresh device list', error: e, stackTrace: s);
    }
  }

  /// Fetch devices for [userId] (cached from the crypto store).
  Future<List<DeviceKeys>> devicesForUser(String userId) async {
    try {
      final enc = _enc;
      if (enc == null) return [];
      await withTimeout(
        () => _client.updateUserDeviceKeys(additionalUsers: {userId}),
        timeout: kDefaultTimeout,
      );
      final keys = _client.userDeviceKeys[userId]?.deviceKeys.values ?? [];
      return keys.toList();
    } catch (e, s) {
      _log.e('could not get devices for $userId', error: e, stackTrace: s);
      return [];
    }
  }

  /// Delete one of our own devices from the server.
  Future<void> deleteDevice(String deviceId) async {
    _log.i('deleting device $deviceId');
    try {
      await withTimeout(
        () => _client.deleteDevices([deviceId]),
        timeout: kDefaultTimeout,
      );
      await _refreshMyDevices();
    } catch (e, s) {
      _log.e('failed to delete device $deviceId', error: e, stackTrace: s);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Verification
  // -----------------------------------------------------------------------

  /// Request a new user-level verification via to-device messages.
  Future<KeyVerification> requestVerification(String userId) async {
    _log.i('requesting verification with $userId');
    final enc = _enc;
    if (enc == null) throw Exception('Encryption not available');

    final kv = KeyVerification(encryption: enc, userId: userId);
    await withTimeout(
      () => kv.start(),
      timeout: kDefaultTimeout,
    );
    return kv;
  }

  /// Manually mark a user as verified (once their master key is trusted).
  Future<void> markUserAsVerified(String userId) async {
    _log.i('marking user $userId as verified');
    try {
      final masterKey = _client.userDeviceKeys[userId]?.masterKey;
      if (masterKey != null) {
        await withTimeout(
          () => masterKey.setVerified(true),
          timeout: kDefaultTimeout,
        );
      }
    } catch (e, s) {
      _log.e('failed to mark user $userId as verified',
          error: e, stackTrace: s);
      rethrow;
    }
  }

  // -----------------------------------------------------------------------
  // Convenience
  // -----------------------------------------------------------------------

  ({int own, int other})? _cachedUnverified;

  /// The number of unverified devices belonging to the current user and to
  /// other users (aggregated across all joined rooms).
  ///
  /// Results are cached until the next sync invalidates them.
  Future<({int own, int other})> countUnverified() async {
    if (_cachedUnverified != null) return _cachedUnverified!;

    int own = 0;
    int other = 0;

    try {
      // Own devices
      for (final d in _myDevices) {
        if (d.deviceId == _client.deviceID) continue;
        final keys = _client.userDeviceKeys[_client.userID];
        if (keys?.deviceKeys[d.deviceId]?.verified != true) own++;
      }

      // Other users — use a Set to avoid double-counting a user
      // who appears in multiple rooms.
      final seen = <String>{};
      for (final room in _client.rooms) {
        final participants = room.getParticipants();
        for (final user in participants) {
          if (user.id == _client.userID) continue;
          if (seen.add(user.id)) {
            final mk = _client.userDeviceKeys[user.id]?.masterKey;
            if (mk?.verified != true) other++;
          }
        }
      }
    } catch (_) {
      // best-effort
    }

    _cachedUnverified = (own: own, other: other);
    return _cachedUnverified!;
  }

  // -----------------------------------------------------------------------
  // Logout
  // -----------------------------------------------------------------------

  Future<void> onLogout() async {
    _log.i('cleaning up encryption state');
    _syncSubscription?.cancel();
    _syncSubscription = null;

    _isInitialized = false;
    _crossSigningBootstrapped = false;
    _keyBackupExists = false;
    _myDevices = [];
    _cachedUnverified = null;
    notifyListeners();
  }
}
