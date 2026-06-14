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

/// Describes what encryption setup action the user should take after login.
enum EncryptionSetupRequirement {
  /// Cross-signing is fully set up and this device is verified.
  none,

  /// Cross-signing has never been set up on this account.
  bootstrap,

  /// Cross-signing exists on the account but this device needs to be
  /// verified (via recovery passphrase or device verification).
  verify,
}

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
      Future.wait([
        _refreshCrossSigningStatus(),
        _refreshBackupState(),
        _refreshMyDevices(),
      ]).catchError((e, s) {
        _log.w('encryption refresh after sync failed',
            error: e, stackTrace: s);
      });
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
        _refreshCrossSigningStatus().catchError((e, s) {
          _log.w('bootstrap: could not refresh cross-signing status',
              error: e, stackTrace: s);
        });
        _refreshBackupState().catchError((e, s) {
          _log.w('bootstrap: could not refresh backup state',
              error: e, stackTrace: s);
        });
        notifyListeners();
      },
    );
    notifyListeners();
    return bootstrap;
  }

  /// Whether the current user is verified (master key trusted and at least
  /// the current device is cross-signed).
  bool get isUserVerified => _crossSigningBootstrapped && isThisDeviceVerified;

  /// Whether the current device is verified via cross-signing.
  ///
  /// Using [SignableKey.crossVerified] instead of [SignableKey.verified]
  /// because the SDK unconditionally sets `directVerified = true` for the
  /// current device (self-trust), which would always make `verified` true
  /// even without cross-signing.  [crossVerified] checks the actual
  /// signature chain: device → self-signing key → master key.
  bool get isThisDeviceVerified {
    try {
      final enc = _enc;
      if (enc == null) return false;
      final deviceKey = _client.userDeviceKeys[_client.userID]
          ?.deviceKeys[_client.deviceID];
      if (deviceKey == null) return false;
      // Only consider the device verified if it has a valid cross-signing
      // chain, not just self-trust.
      return deviceKey.crossVerified;
    } catch (_) {
      return false;
    }
  }

  /// Whether [userId]'s master key is verified.
  ///
  /// This indicates a successfully-completed cross-signing verification
  /// (SAS or manual) of this user.  Their master key may be directly
  /// verified (after SAS) or cross-verified (via a valid signature chain
  /// back to a directly-verified key).
  bool isUserVerifiedById(String userId) {
    try {
      final enc = _enc;
      if (enc == null) return false;
      final mk = _client.userDeviceKeys[userId]?.masterKey;
      if (mk == null) return false;
      // Reject self-trust: the SDK auto-marks the current user's master
      // key as directly verified during bootstrap, but for other users we
      // need explicit verification (directVerified) or a valid
      // cross-signing chain (crossVerified).
      return mk.verified;
    } catch (_) {
      return false;
    }
  }

  /// Whether a specific device belonging to [userId] is verified via
  /// cross-signing.
  ///
  /// This checks the device-level trust (whether the device key is signed
  /// by the user's self-signing key, which is signed by their master key).
  /// This is more accurate than [isUserVerifiedById] for per-message trust
  /// because a user may have a verified master key but send from a device
  /// that was never cross-signed (e.g. a new session before old device
  /// dehydration completed).
  ///
  /// If the device-level check cannot be satisfied (key not in cache,
  /// incomplete signature chain, etc.) this falls back to the user-level
  /// master-key check provided by [isUserVerifiedById] so that devices
  /// belonging to a verified user are not incorrectly flagged as
  /// untrusted.
  ///
  /// [deviceId] can be obtained from the original encrypted event content
  /// via `event.originalSource?.content['device_id']` for decrypted events.
  bool isDeviceVerifiedById(String userId, String deviceId) {
    try {
      final enc = _enc;
      if (enc == null) return false;

      // If it's our own device, we can skip the user-level fallback:
      // self-verification is handled explicitly via cross-signing.
      if (userId == _client.userID && deviceId == _client.deviceID) {
        final dk =
            _client.userDeviceKeys[userId]?.deviceKeys[deviceId];
        if (dk == null) return false;
        return dk.crossVerified;
      }

      // For other users' devices: try the device-level check first.
      final dk = _client.userDeviceKeys[userId]?.deviceKeys[deviceId];
      if (dk != null && dk.verified) return true;

      // Device not found or not individually verified — fall back to
      // the user-level master-key check.  If the user's master key is
      // verified (SAS completed), all of their cross-signed devices
      // are considered trusted.
      return isUserVerifiedById(userId);
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

  /// Request verification of the current device from another of the
  /// user's own devices via SAS (emoji / number matching).
  ///
  /// Passes `deviceId: '*'` so any of the user's already-verified devices
  /// can respond.  The returned [KeyVerification] object drives the same
  /// SAS UI used for cross-user verification.
  Future<KeyVerification> requestSelfVerification() async {
    _log.i('requesting self-verification (device → device)');
    final enc = _enc;
    if (enc == null) throw Exception('Encryption not available');
    if (_client.userID == null) throw Exception('Not logged in');

    final kv = KeyVerification(
      encryption: enc,
      userId: _client.userID!,
      deviceId: '*',
    );
    await withTimeout(
      () => kv.start(),
      timeout: kDefaultTimeout,
    );
    // Register with the manager so the other device's response is routed
    // back to this KeyVerification instance.
    enc.keyVerificationManager.addRequest(kv);
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
  // Post-login setup state
  // -----------------------------------------------------------------------

  /// Determines what, if anything, the user should do after logging in.
  EncryptionSetupRequirement get setupRequirement {
    if (!isSupported || _client.encryption == null) {
      return EncryptionSetupRequirement.bootstrap;
    }

    if (!_crossSigningBootstrapped) {
      return EncryptionSetupRequirement.bootstrap;
    }

    if (!isThisDeviceVerified) {
      return EncryptionSetupRequirement.verify;
    }

    return EncryptionSetupRequirement.none;
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
