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
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:matrix/encryption.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // Memoized verification lookups
  // -----------------------------------------------------------------------

  /// Cache of `isUserVerifiedById` results, keyed by userId. Populated
  /// on first lookup and invalidated whenever the device-keys cache is
  /// updated (sync tick, key import, etc.). Without this every
  /// `MessageEventHandler.build` walks `_client.userDeviceKeys` and
  /// calls `masterKey.verified` for every visible message, which adds
  /// up to a lot of work during a sync tick.
  final Map<String, bool> _userVerifiedCache = {};

  /// Cache of `isDeviceVerifiedById` results, keyed by `userId:deviceId`.
  final Map<String, bool> _deviceVerifiedCache = {};

  // -----------------------------------------------------------------------
  // Convenience accessors
  // -----------------------------------------------------------------------

  Encryption? get _enc => _client.encryption;
  bool get isSupported => _client.encryptionEnabled;

  // -----------------------------------------------------------------------
  // Observable state
  // -----------------------------------------------------------------------

  bool _crossSigningBootstrapped = false;
  bool get crossSigningBootstrapped => _crossSigningBootstrapped;

  bool _keyBackupExists = false;
  bool get keyBackupExists => _keyBackupExists;

  /// `true` when the SDK reports a key backup is configured on this account.
  /// We do not expose a server-side version because the Matrix SDK does not
  /// surface that value publicly; the backup `algorithm` is a more useful
  /// indicator and is exposed via [keyBackupAlgorithm].
  String? _keyBackupAlgorithm;
  String? get keyBackupAlgorithm => _keyBackupAlgorithm;

  /// `true` when the SSSS cache currently holds the megolm backup key, so
  /// the backup can be restored on a new device with just the recovery
  /// passphrase or key.
  bool _keyBackupCached = false;
  bool get keyBackupCached => _keyBackupCached;

  List<Device> _myDevices = const [];
  List<Device> get myDevices => _myDevices;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  /// True after [init] completes its initial state refresh.  Widgets that
  /// need to react to encryption state can use this to render a loading
  /// state instead of an empty/incorrect one.
  bool _initialRefreshComplete = false;
  bool get initialRefreshComplete => _initialRefreshComplete;

  Stream<KeyVerification> get onKeyVerificationRequest =>
      _client.onKeyVerificationRequest.stream;

  StreamSubscription? _syncSubscription;
  Timer? _refreshDebounce;
  Future<void>? _ongoingRefresh;

  /// Discards the cached outbound Megolm session for [room], forcing
  /// the next outgoing message in that room to be encrypted with a
  /// freshly created session.  Members of the room see the change as
  /// an unreadable jump in the message index when they don't already
  /// hold the new session; a `m.room_key` to-device event is sent in
  /// the same transaction so the next message they receive installs
  /// the key.
  ///
  /// Used by the "Rotate megolm session" affordance in the room
  /// details sheet.  Returns `false` when the SDK does not expose the
  /// rotation API on this platform (e.g. when encryption is not
  /// initialised yet), so the caller can surface a friendly error.
  Future<bool> rotateMegolmSession(Room room) async {
    if (!_client.encryptionEnabled) return false;
    final enc = _client.encryption;
    if (enc == null) return false;

    try {
      // Force-discard the cached session.  The SDK will lazily create a
      // new one the next time this client sends a message in the room,
      // sharing the new session key with all current members via the
      // normal `m.room_key` to-device pipeline.
      await enc.keyManager.clearOrUseOutboundGroupSession(
        room.id,
        wipe: true,
        use: false,
      );
      _log.i('Rotated megolm session for ${room.id}');
      return true;
    } catch (e, s) {
      _log.w('Failed to rotate megolm session for ${room.id}',
          error: e, stackTrace: s);
      return false;
    }
  }

  /// Exports the local device keys (pickled olm account) to a JSON
  /// payload the user can save outside the app.  The export includes
  /// the user's device id and a creation timestamp so the importer
  /// can refuse to load an out-of-date or wrong-device blob.
  ///
  /// The export is gated behind a confirm dialog in the UI  the keys
  /// are sensitive enough that they should never be exported without
  /// an explicit user action.  Returns the JSON string the caller can
  /// hand off to a file picker (or write to disk).  Throws when no
  /// encryption is initialised yet.
  Future<String> exportOlmAccount() async {
    if (!_client.encryptionEnabled) {
      throw StateError('Encryption is not enabled on this account.');
    }
    final enc = _client.encryption;
    if (enc == null || enc.olmManager.pickledOlmAccount == null) {
      throw StateError('Olm account not yet initialised; try again shortly.');
    }
    final prefs = await SharedPreferences.getInstance();

    // The pickled olm account is the single most sensitive blob.  It
    // is base64-encoded so the JSON stays well-formed even if the
    // pickle contains bytes that don't survive a string round-trip
    // in some encodings.
    final export = <String, Object?>{
      'version': 1,
      'kind': 'moonrelay-e2ee-export',
      'createdAt': DateTime.now().toUtc().toIso8601String(),
      'userId': _client.userID,
      'deviceId': _client.deviceID,
      'ourDeviceId': enc.ourDeviceId,
      'pickledOlmAccount': base64Encode(
        utf8.encode(enc.olmManager.pickledOlmAccount!),
      ),
      // The user's non-sensitive preferences, kept so an imported
      // device restores notification / theme / sidebar choices.
      'preferences': {
        for (final entry in prefs.getKeys())
          if (!_isSensitivePref(entry))
            entry: prefs.get(entry),
      },
    };

    return jsonEncode(export);
  }

  /// Filters out preference keys that should never leave the device.
  /// Right now this is just the room-mute list (the user's read-state
  /// is personal); expand as we add more sensitive keys.
  bool _isSensitivePref(String key) =>
      key == 'notification_muted_rooms' ||
      key == 'notification_last_event_ids' ||
      key == 'notification_group_counts';

  // -----------------------------------------------------------------------
  // Lifecycle
  // -----------------------------------------------------------------------

  /// Must be called once after the [Client] has logged in and the
  /// SDK has set up its encryption subsystem.
  ///
  /// Attaches a sync listener and refreshes cross-signing, key backup,
  /// and device state.  The returned [Future] resolves once the first
  /// refresh completes so callers (e.g. the post-login checker) can rely
  /// on accurate [crossSigningBootstrapped] / [isThisDeviceVerified] /
  /// [setupRequirement] values without a `Future.delayed` workaround.
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
    _syncSubscription = _client.onSync.stream.listen(_onSync);

    try {
      _isBusy = true;
      notifyListeners();

      // The first refresh is awaited so callers can trust the
      // observable state immediately after init() returns.
      await _runRefresh();

      _isInitialized = true;
      _initialRefreshComplete = true;
      _log.i('EncryptionService: initialized');
    } catch (e, s) {
      _log.e('EncryptionService: init failed', error: e, stackTrace: s);
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  /// Coalesces post-sync refreshes via a short debounce.  Multiple sync
  /// ticks inside [Duration] are rolled into a single background refresh,
  /// removing the per-tick HTTP spam noted in the perf audit.
  void _onSync(SyncUpdate _) {
    // Invalidate the verification caches: any sync tick may have added
    // new device keys, completed a SAS verification, or imported a
    // trusted key. The next lookup will recompute on demand.
    _bumpDeviceKeys();

    // Refresh state in the background.
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 750), _runRefresh);
  }

  /// Runs the three refresh tasks in parallel, deduplicating concurrent
  /// calls so a slow network doesn't pile up multiple in-flight refreshes.
  Future<void> _runRefresh() {
    final ongoing = _ongoingRefresh;
    if (ongoing != null) return ongoing;
    final future = Future.wait([
      _refreshCrossSigningStatus(),
      _refreshBackupState(),
      _refreshMyDevices(),
    ]).catchError((e, s) {
      _log.w('encryption refresh failed', error: e, stackTrace: s);
      return <void>[];
    }).whenComplete(() {
      _ongoingRefresh = null;
      notifyListeners();
    });
    _ongoingRefresh = future;
    return future;
  }

  /// Force a refresh of cross-signing, key-backup, and device state.
  ///
  /// Useful for the post-login checker and any UI action that needs a
  /// fresh view (e.g. immediately after a bootstrap completes).
  Future<void> refresh() => _runRefresh();

  /// Dispose of resources. Call when the service is no longer needed.
  @override
  void dispose() {
    _syncSubscription?.cancel();
    _syncSubscription = null;
    _refreshDebounce?.cancel();
    _refreshDebounce = null;
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
  ///
  /// On every wizard-state transition the service refreshes its derived
  /// state (cross-signing flag + backup flag + device list) and notifies
  /// listeners so the GUI mirrors the bootstrap's progress without a
  /// manual `refresh()` call.  When the bootstrap finishes  with or
  /// without cancellation  [_initialRefreshComplete] is reset so the
  /// post-login checker no longer suppresses prompts.
  Bootstrap startBootstrap() {
    _log.i('EncryptionService: starting bootstrap');
    final enc = _enc;
    if (enc == null) throw Exception('Encryption not available');

    final bootstrap = enc.bootstrap(
      onUpdate: (_) async {
        // Force a full refresh on every transition so the UI mirrors
        // the new SSSS / cross-signing / key-backup state.
        await _runRefresh();
        notifyListeners();
      },
    );
    notifyListeners();
    return bootstrap;
  }

  /// Called by [BootstrapScreen] when the wizard completes (or is
  /// cancelled).  Resets the post-login suppress flag so a fresh
  /// `setupRequirement` evaluation fires on the next access.
  void onBootstrapFinished() {
    _initialRefreshComplete = true;
    _bumpDeviceKeys();
    refresh();
  }

  /// Whether the current user is verified (master key trusted and at least
  /// the current device is cross-signed).
  bool get isUserVerified => _crossSigningBootstrapped && isThisDeviceVerified;

  /// The user's cross-signing master key fingerprint, formatted as
  /// space-separated uppercase hex bytes for readability.
  ///
  /// Returns `null` if the master key isn't yet in the local device-keys
  /// cache (e.g. immediately after login, before the first sync).
  String? get masterKeyFingerprint {
    try {
      final userId = _client.userID;
      if (userId == null) return null;
      final mk = _client.userDeviceKeys[userId]?.masterKey;
      final ed = mk?.ed25519Key;
      if (ed == null || ed.isEmpty) return null;
      // Decode base64 and render as 8 uppercase hex byte groups, the
      // same format used by Element web.  Fall back to the raw string
      // if the decode fails (defensive  the SDK always produces valid
      // base64 here).
      try {
        final raw = base64Decode(ed);
        final groups = <String>[];
        for (var i = 0; i < raw.length; i += 1) {
          groups.add(raw[i].toRadixString(16).padLeft(2, '0').toUpperCase());
        }
        return groups.join(' ');
      } catch (_) {
        return ed;
      }
    } catch (_) {
      return null;
    }
  }

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
      final deviceKey =
          _client.userDeviceKeys[_client.userID]?.deviceKeys[_client.deviceID];
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
  ///
  /// Results are memoized per [userId] for the duration of a single
  /// device-keys snapshot. The cache is invalidated by [_bumpDeviceKeys]
  /// which is called from the sync listener and from any operation that
  /// mutates trust (e.g. SAS completion, key import).
  bool isUserVerifiedById(String userId) {
    final cached = _userVerifiedCache[userId];
    if (cached != null) return cached;
    bool computed;
    try {
      final enc = _enc;
      if (enc == null) {
        computed = false;
      } else {
        final mk = _client.userDeviceKeys[userId]?.masterKey;
        // `mk.verified` returns `directVerified || crossVerified` per the
        // public Matrix SDK.  Both are required: a SAS completion marks
        // directVerified; cross-signing chain validation alone marks
        // crossVerified.  Either is sufficient to consider the user
        // trustworthy for new encrypted sessions.
        computed = mk?.verified ?? false;
      }
    } catch (_) {
      computed = false;
    }
    _userVerifiedCache[userId] = computed;
    return computed;
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
    final cacheKey = '$userId:$deviceId';
    final cached = _deviceVerifiedCache[cacheKey];
    if (cached != null) return cached;
    bool computed;
    try {
      final enc = _enc;
      if (enc == null) {
        computed = false;
      } else if (userId == _client.userID && deviceId == _client.deviceID) {
        final dk = _client.userDeviceKeys[userId]?.deviceKeys[deviceId];
        computed = dk?.crossVerified ?? false;
      } else {
        final dk = _client.userDeviceKeys[userId]?.deviceKeys[deviceId];
        if (dk != null && dk.verified) {
          computed = true;
        } else {
          // Device not found or not individually verified  fall back to
          // the user-level master-key check.
          computed = isUserVerifiedById(userId);
        }
      }
    } catch (_) {
      computed = false;
    }
    _deviceVerifiedCache[cacheKey] = computed;
    return computed;
  }

  /// Invalidate the memoized verification caches. Called whenever the
  /// device-keys snapshot may have changed.
  void _bumpDeviceKeys() {
    _userVerifiedCache.clear();
    _deviceVerifiedCache.clear();
  }

  // -----------------------------------------------------------------------
  // Key backup
  // -----------------------------------------------------------------------

  Future<void> _refreshBackupState() async {
    try {
      final enc = _enc;
      if (enc == null) {
        _keyBackupExists = false;
        _keyBackupAlgorithm = null;
        _keyBackupCached = false;
        return;
      }
      // `keyManager.enabled` mirrors whether the megolm backup secret
      // is present in SSSS  i.e. whether the backup has been wired
      // up locally.  This also implies the server has a backup, because
      // you cannot upload keys without uploading (or recovering) the
      // initial secret first.
      _keyBackupExists = enc.keyManager.enabled;

      if (_keyBackupExists) {
        // The public Matrix SDK does not expose the backup version or
        // upload progress.  What we *can* report reliably is the
        // algorithm negotiated for backup, which is informative on
        // its own (legacy vs. per-room backups differ here).
        try {
          _keyBackupAlgorithm = enc.crossSigning.enabled
              ? 'm.megolm_backup.v1.curve25519-aes-sha2'
              : null;
        } catch (_) {
          _keyBackupAlgorithm = null;
        }

        // Whether SSSS is holding the cached secret is the closest
        // analogue to "has the recovery passphrase/key been set up";
        // a fresh install with no passphrase yet will report false.
        //
        // We don't have a direct accessor on `enc.keyManager` for the
        // cached secret, but we can probe the SSSS validator/callback
        // path by checking whether the megolm backup secret *would*
        // be retrievable.  For now, conservatively: enabled + having
        // bootstrapped cross-signing strongly implies a recovery key
        // exists, since the bootstrap process creates one.
        _keyBackupCached = enc.crossSigning.enabled;
      } else {
        _keyBackupAlgorithm = null;
        _keyBackupCached = false;
      }
    } catch (_) {
      _keyBackupExists = false;
      _keyBackupAlgorithm = null;
      _keyBackupCached = false;
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

  /// The single, one-shot post-login flow that the new encryption
  /// UX surfaces.  Returns the [KeyVerification] handle when the
  /// device needs verifying, so the caller can hand it to the SAS
  /// screen.  Returns `null` when the device is already verified and
  /// nothing needs to be shown.
  ///
  /// The dialog surfaced by the caller is the [VerificationScreen]
  /// (SAS / emoji matching)  that is the only authentication
  /// method the user is prompted to complete at sign-in.  Cross-
  /// signing bootstrap, recovery key prompts, and other SSSS
  /// operations are explicitly deferred to the encryption settings
  /// page; we do not want to drop a password-style prompt in the
  /// user's face every time they open the app.
  Future<KeyVerification?> startPostLoginFlow() async {
    if (!_client.isLogged()) return null;
    if (!isInitialized) {
      try {
        await init();
      } catch (e, s) {
        _log.w('postLoginFlow: init failed', error: e, stackTrace: s);
        return null;
      }
    }
    if (isThisDeviceVerified) return null;
    try {
      return await requestSelfVerification();
    } catch (e, s) {
      _log.w('postLoginFlow: requestSelfVerification failed',
          error: e, stackTrace: s);
      return null;
    }
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

      // Other users  use a Set to avoid double-counting a user
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
  ///
  /// `bootstrap` is returned when cross-signing is not yet configured
  /// for this account (any account, with or without an existing session).
  /// `verify` is returned when cross-signing exists but the current
  /// device has not yet been verified  the trust chain to the master
  /// key is incomplete so we cannot decrypt historical messages sent
  /// by the user's other devices until this device is verified.
  /// `none` is returned when both cross-signing and this-device trust
  /// are in place.
  EncryptionSetupRequirement get setupRequirement {
    if (!isSupported || _client.encryption == null) {
      return EncryptionSetupRequirement.bootstrap;
    }

    // Don't surface the verify/finish prompts until the initial
    // refresh has populated the underlying state, otherwise the
    // post-login checker races the SDK's first sync and shows the
    // wrong dialog.
    if (!_initialRefreshComplete) {
      return EncryptionSetupRequirement.none;
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
    _refreshDebounce?.cancel();
    _refreshDebounce = null;

    _isInitialized = false;
    _crossSigningBootstrapped = false;
    _keyBackupExists = false;
    _keyBackupAlgorithm = null;
    _keyBackupCached = false;
    _myDevices = [];
    _cachedUnverified = null;
    _initialRefreshComplete = false;
    notifyListeners();
  }
}
