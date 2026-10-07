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
import 'package:matrix/matrix.dart';
import 'package:window_manager/window_manager.dart';

import 'package:moonrelay/src/settings/settings_controller.dart';

/// Keeps the account's published presence in step with whether the user
/// is actually at the keyboard.
///
/// Matrix presence is the state other clients see for this account, and
/// the app had no owner for it. Two `setPresence` calls sat in the
/// profile screen, both of which reported success on failure (see the
/// commit that fixes them), and nothing tracked idleness at all.
///
/// ## What "away" means here, and what it does not
///
/// Away is a *presence* fact and nothing else. It is `m.presence` on the
/// wire, the same field a user sets by hand from the profile screen, and
/// it is the only thing this service changes. Going idle publishes
/// `PresenceType.offline`, or leaves the account where the user last put
/// it. There is no other effect, by design.
///
/// Specifically, going idle does **not** touch cryptographic state: no
/// megolm or olm keys are dropped, cleared, re-exported or evicted from
/// memory, no database is closed, and no lock screen appears. Those
/// actions were once implied by a setting called "auto-lock", which the
/// app could not honour anyway: the SDK's `Encryption` exposes only
/// `dispose()`, with no re-entry point, and `Client.dispose()` leaves the
/// client unusable. A setting named "lock" promised a guarantee the app could not deliver.
///
/// If a real local lock is ever wanted, it is a separate feature with its
/// own name and its own surface, and it belongs next to the encryption
/// controls rather than to presence. It should not be bolted onto this
/// service, whose only job is one field on the wire.
///
/// ## The constraint that shapes the design
///
/// `Client.syncPresence` must be pinned alongside any "appear offline"
/// choice. Per the Matrix spec, omitting `set_presence` on `/sync` tells
/// the server to mark the client online, so a user who taps "Appear
/// offline" would be flipped back within one long-poll interval. A
/// `setPresence` call alone is therefore decorative.
class PresenceService with WindowListener {
  PresenceService({
    required this.settings,
    required this.log,
    this.clock = DateTime.now,
    void Function(WindowListener listener)? addWindowListener,
    void Function(WindowListener listener)? removeWindowListener,
  })  : _addWindowListener = addWindowListener ?? _defaultAddWindowListener,
        _removeWindowListener =
            removeWindowListener ?? _defaultRemoveWindowListener;

  /// Live settings, read on every activity and on every timer tick so a
  /// change to the toggle or the idle window takes effect immediately.
  final SettingsController settings;
  final Logger log;

  /// Injectable wall clock, so tests can advance idle time without
  /// waiting in real seconds.
  final DateTime Function() clock;

  /// Injectable window-listener registration, for the same reason as
  /// [clock] and with the same shape.
  ///
  /// `windowManager` is a global singleton that throws when there is no
  /// platform window, which is precisely the environment a unit test runs in,
  /// so the registration path would otherwise be unreachable from a test and
  /// the leak it had could never be caught. Injecting it keeps the real
  /// global as the default and makes the bookkeeping assertable.
  final void Function(WindowListener listener) _addWindowListener;
  final void Function(WindowListener listener) _removeWindowListener;

  static void _defaultAddWindowListener(WindowListener listener) =>
      windowManager.addListener(listener);

  static void _defaultRemoveWindowListener(WindowListener listener) =>
      windowManager.removeListener(listener);

  Client? _client;
  Timer? _idleTimer;
  DateTime? _lastActivity;
  bool _windowFocused = true;
  bool _disposed = false;
  bool _isApplying = false;

  /// The presence this account last asked the server to publish, so a
  /// redundant call can be skipped and a user override is not clobbered
  /// by the idle logic.
  PresenceType? _published;

  /// The presence the user chose by hand, which the idle logic must not
  /// override. Null means "follow idleness", which is the default.
  PresenceType? _userChoice;

  /// The latest intent that arrived while a write was in flight, drained
  /// once the write settles. Latest-wins, so a burst of transitions
  /// collapses rather than queueing.
  PresenceType? _pending;

  /// True while the idle timer is running, meaning the account is
  /// currently published as offline because of inactivity.
  bool get isIdleOffline => _idleTimer != null;

  /// The presence the user last chose by hand, or null when following
  /// idleness.
  PresenceType? get userChoice => _userChoice;

  /// Binds to [client], replacing any previous binding.
  ///
  /// Deliberately does not restore the previous account's presence: the
  /// server marks a user offline when their sessions stop syncing anyway,
  /// and a setPresence during a switch would race the new client's own
  /// sync loop.
  void bind(Client client) {
    if (identical(_client, client)) return;
    _cancelIdleTimer();
    _published = null;
    _userChoice = null;
    _lastActivity = clock();
    _client = client;
    // Registered unconditionally so onWindowFocus and onWindowBlur are
    // available for the noteActivity path, which is needed whether or not
    // the idle feature is on. The try/catch is for environments with no
    // window manager (tests, and any non-desktop target), where the
    // pointer and keyboard paths still work.
    //
    // Remove before add, not just add. `windowManager` keeps listeners in a
    // plain list and `removeListener` removes one entry, so adding without
    // removing accumulates a copy per bind. `bind` is documented as
    // replacing a previous binding and does return early for the same
    // client, but an account switch brings a new one every time; two
    // registrations then survive a `dispose` and keep creating timers on a
    // dead service. Removing first makes registration idempotent no matter
    // how often bind is called. `removeListener` is a no-op when absent, so
    // this is also the right call on a first bind.
    try {
      _removeWindowListener(this);
      _addWindowListener(this);
    } on Object catch (_) {
      // No platform window manager; activity is still tracked from the
      // in-app input hooks.
    }
    unawaited(_evaluate());
  }

  /// Applies the user's own choice, and stops following idleness.
  ///
  /// Choosing anything explicitly, including online, overrides the idle
  /// behaviour until the user changes the setting again, so a user who
  /// wants to stay visible can say so.
  Future<void> setUserPresence(PresenceType type, {String? statusMsg}) async {
    _cancelIdleTimer();
    _userChoice = type;
    await _publish(type, statusMsg: statusMsg);
  }

  /// Returns to following idleness, clearing any manual override.
  Future<void> clearUserChoice() async {
    _userChoice = null;
    await _evaluate();
  }

  /// Records user activity, cancelling a pending offline transition.
  ///
  /// Safe to call from any input handler and cheap when nothing has
  /// changed: it only does work when the account is currently published
  /// offline, and a burst of keystrokes restarts one timer rather than
  /// spawning many.
  void noteActivity() {
    _lastActivity = clock();
    if (_published != PresenceType.offline) return;
    if (_userChoice != null) return;
    _cancelIdleTimer();
    unawaited(_publish(PresenceType.online));
    // Re-arm, because the account should go offline again if the user
    // walks away once more.
    final window = Duration(minutes: settings.autoOfflinePresenceMinutes);
    if (settings.autoOfflinePresenceEnabled) _startIdleTimer(window);
  }

  // -- WindowListener ------------------------------------------------

  @override
  void onWindowFocus() {
    _windowFocused = true;
    noteActivity();
  }

  @override
  void onWindowBlur() {
    // Losing focus is not idleness. The user is still here, just
    // elsewhere, and Windows does not reliably deliver a focus event
    // when the workstation is locked. Focus loss cancels a pending
    // offline transition rather than starting one, and input inside the
    // app is what marks activity.
    _windowFocused = false;
    _lastActivity = clock();
    _cancelIdleTimer();
  }

  // -- Lifecycle -----------------------------------------------------

  /// Re-evaluates after a resume.
  ///
  /// A suspended machine's timers do not fire, so a laptop that slept
  /// past the idle window would keep showing online until something else
  /// woke it. Comparing wall-clock time at the resume is the only
  /// reliable measure, which is why [clock] is injectable.
  void onResumed() {
    // A manual choice outranks the idle logic, same as every other
    // transition. Checking it here rather than only in the timer is what
    // stops a resume from undoing a presence the user picked by hand.
    if (_userChoice != null) return;
    if (!settings.autoOfflinePresenceEnabled) return;
    final idleFor = clock().difference(_lastActivity ?? clock());
    final window = Duration(minutes: settings.autoOfflinePresenceMinutes);
    if (idleFor >= window) {
      // The sleep itself counts as idle time, so the account is offline
      // the moment the user comes back rather than after a fresh window.
      unawaited(_publish(PresenceType.offline));
    } else {
      _lastActivity = clock();
    }
  }

  /// Re-evaluates when the settings change, so toggling the feature on
  /// takes effect without a restart and toggling it off stops the timer.
  void onSettingsChanged() {
    if (settings.autoOfflinePresenceEnabled) {
      // Starting a fresh idle window on every settings change would be
      // wrong for the minutes slider, where dragging it would keep
      // pushing the deadline out. Only re-arm when switching on.
      if (!isIdleOffline) _lastActivity = clock();
      _cancelIdleTimer();
    } else {
      _cancelIdleTimer();
      unawaited(_returnToOnline());
    }
    _userChoice = null;
    unawaited(_evaluate());
  }

  /// Publishes offline on teardown so the account does not linger as
  /// online on other people's clients after a logout or an account
  /// switch.
  Future<void> markOfflineBeforeDisconnect() async {
    if (_client == null) return;
    if (_client!.isLogged()) {
      await _publish(PresenceType.offline);
    }
  }

  void dispose() {
    _disposed = true;
    _cancelIdleTimer();
    try {
      _removeWindowListener(this);
    } on Object catch (_) {
      // Never registered; see bind.
    }
    _client = null;
  }

  /// Drops the window-listener registration without tearing the service
  /// down, for tests.
  @visibleForTesting
  void detachWindowListener() {
    try {
      _removeWindowListener(this);
    } on Object catch (_) {
      // Never registered; see bind.
    }
  }

  // -- Internals -----------------------------------------------------

  void _cancelIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = null;
  }

  /// Decides what the presence should be and applies it.
  ///
  /// Called on bind, on resume, and on a settings change. Not called on a
  /// timer: the deadline is a timer, but the decision is made when the timer
  /// fires, which keeps a suspended machine from drifting.
  ///
  /// The invariant this owns is "enabled, and nothing chosen by hand, implies
  /// an armed deadline". It is the reason the arming lives here rather than in
  /// the callers. Every caller resets `_lastActivity` before arriving, because
  /// each of them genuinely is a fresh moment, so each of them lands in the
  /// `idleFor < window` branch; a version of this method that only armed on
  /// the `>=` branch therefore armed nothing at all for all three, and the
  /// countdown silently never started. Arming with the *remaining* time here
  /// makes the invariant true by construction for current and future callers.
  Future<void> _evaluate() async {
    if (_disposed) return;
    if (_client == null) return;
    if (!settings.autoOfflinePresenceEnabled) return;
    if (_userChoice != null) return;

    final window = Duration(minutes: settings.autoOfflinePresenceMinutes);
    final idleFor = clock().difference(_lastActivity ?? clock());
    if (idleFor < window) {
      // Only publish if we are currently published as offline. Binding
      // and a settings change both land here, and a redundant "online"
      // PUT on every account switch would be noise the server does not
      // need: the sync loop already marks the client online.
      if (_published == PresenceType.offline) {
        await _publish(PresenceType.online);
      }
      _startIdleTimer(window - idleFor);
    } else {
      _startIdleTimer(Duration.zero);
    }
  }

  void _startIdleTimer(Duration delay) {
    _cancelIdleTimer();
    _idleTimer = Timer(delay, () async {
      _idleTimer = null;
      if (_disposed) return;
      // Re-check at fire time rather than trusting the timer: the window
      // may have been shortened or the setting switched off while the
      // timer was pending.
      if (!settings.autoOfflinePresenceEnabled) return;
      if (_userChoice != null) return;
      await _publish(PresenceType.offline);
    });
  }

  /// Returns to online immediately and re-arms the idle deadline.
  Future<void> _returnToOnline() async {
    _cancelIdleTimer();
    _lastActivity = clock();
    if (_disposed) return;
    await _publish(PresenceType.online);
  }

  /// Publishes [type] for [client], pinning [Client.syncPresence] so the
  /// choice survives the next `/sync`.
  ///
  /// Static so a caller with no bound service, such as the profile
  /// screen in a tree where nothing is bound, still publishes correctly
  /// rather than reverting to the decorative `setPresence`-only call this
  /// replaced. Throws on failure, so the caller's own error handling
  /// decides what the user is told; [PresenceService._publish] is the
  /// wrapper that swallows and logs.
  static Future<void> publishTo(
    Client client, {
    required PresenceType type,
    String? statusMsg,
  }) async {
    if (!client.isLogged() || client.userID == null) return;
    // Pinned before the PUT so a long-poll racing this call cannot undo
    // it. Null means "let the server decide", which is what online and
    // unavailable both want.
    client.syncPresence = type == PresenceType.online ? null : type;
    await client.setPresence(client.userID!, type, statusMsg: statusMsg);
  }

  Future<void> _publish(PresenceType type, {String? statusMsg}) async {
    final client = _client;
    if (_disposed || client == null || !client.isLogged()) return;
    if (_published == type) {
      // Already published this state; the server has nothing to update
      // and a redundant PUT on every keystroke would be noise.
      if (statusMsg == null) return;
    }
    if (_isApplying) {
      // A write is already in flight. Record the newer intent rather
      // than dropping it: dropping meant an idle transition that landed
      // while an online write was in flight was silently discarded, and
      // the account stayed online for the rest of the idle window.
      _pending = type;
      return;
    }

    _isApplying = true;
    try {
      await publishTo(client, type: type, statusMsg: statusMsg);
      _published = type;
      log.d('Presence published: $type');
    } on Object catch (e, s) {
      // Never throws past here: a presence write failing is not worth
      // taking down the caller's action, and the next tick retries.
      log.w('Could not publish presence $type', error: e, stackTrace: s);
    } finally {
      _isApplying = false;
    }

    // Drain anything that arrived while the write was in flight. Bounded
    // to one step: a coalesced "latest intent wins" is enough, and a
    // loop here could spin while a caller keeps the service busy.
    final pending = _pending;
    _pending = null;
    if (pending != null && pending != _published) {
      await _publish(pending);
    }
  }

  /// Test seam: whether an idle transition is currently scheduled.
  @visibleForTesting
  bool get hasPendingIdleTransition => _idleTimer != null;

  /// Test seam: whether the window is currently focused.
  @visibleForTesting
  bool get isWindowFocused => _windowFocused;
}
