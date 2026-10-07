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
import 'dart:io';

import 'package:logger/logger.dart';
import 'package:moonrelay/src/services/sso_server.dart';
import 'package:url_launcher/url_launcher.dart';

/// The outcome of an attempt to capture the SSO token automatically.
///
/// The flow has two ways to finish and one way to stall, and the caller
/// needs to tell them apart: a token can be signed in with, while a
/// failure has to fall back to the user pasting a token by hand. Returning
/// a sealed set of those three outcomes means the fallbacks cannot be
/// forgotten at a call site, which is what happened while this lived as a
/// `throw SsoAutomaticException` plus a side channel on the widget.
sealed class SsoAttempt {
  const SsoAttempt();

  /// The browser came back with a token.
  factory SsoAttempt.token(String token) = SsoTokenReceived;

  /// The automatic route did not work, and the user has to finish by hand.
  ///
  /// [reason] is for the log, not for the user: the page shows a single
  /// generic notice, because the failure detail is a local server or
  /// browser-launch problem that says nothing actionable about what the
  /// user should do next.
  factory SsoAttempt.failed(String reason) = SsoAutomaticFailed;

  /// The page went away mid-flow, or the user cancelled.
  factory SsoAttempt.abandoned() = SsoAbandoned;
}

/// A token arrived at the local callback server.
final class SsoTokenReceived extends SsoAttempt {
  const SsoTokenReceived(this.token);

  final String token;
}

/// The automatic flow could not complete.
final class SsoAutomaticFailed extends SsoAttempt {
  const SsoAutomaticFailed(this.reason);

  final String reason;
}

/// Nothing came back and nobody is waiting any more.
final class SsoAbandoned extends SsoAttempt {
  const SsoAbandoned();
}

/// Runs the automatic half of SSO: a local HTTP server that catches the
/// browser's redirect back with a login token.
///
/// The manual paste-a-token flow is the page's job, not this one's. What
/// belongs here is the part that touches the network and the loopback
/// socket, because that is the part with the lifecycle: a server that has
/// to be started, waited on, and stopped on every exit path including the
/// ones where the page is disposed halfway through.
///
/// The caller drives it with [captureToken] and calls [cancel] or
/// [dispose] to unwind. Both are idempotent, because the page can be
/// disposed while a capture is in flight and the two callers will then
/// race to stop the same server.
class SsoTokenCapture {
  SsoTokenCapture({required Logger log, Duration timeout = _defaultTimeout})
      : _log = log,
        _timeout = timeout;

  static const Duration _defaultTimeout = Duration(minutes: 3);

  /// Short pause after the token lands, so the "token detected" status is
  /// actually on screen long enough to be read.
  static const Duration _settleDelay = Duration(milliseconds: 600);

  final Logger _log;
  final Duration _timeout;

  SsoCallbackServer? _server;

  /// The URL the browser was last opened with, kept so the page can display
  /// it while a capture is in flight.
  Uri? _destination;

  /// Whether a capture is currently in flight, which is what the page shows
  /// its waiting indicator from.
  bool get isCapturing => _server != null;

  /// The redirect URL the browser is currently pointed at, or null when no
  /// capture is running.
  ///
  /// The page shows this so a user whose automatic flow is stuck can see
  /// where their browser went, and copy it into another window by hand.
  Uri? get destination => _server == null ? null : _destination;

  /// Starts the local server, opens the browser, and waits for the token.
  ///
  /// Returns [SsoTokenReceived] with the token, [SsoAutomaticFailed] with a
  /// reason for the log, or [SsoAbandoned] if the page went away. Every
  /// failure path stops the server before returning, so the caller never
  /// has to clean up after a failed attempt.
  Future<SsoAttempt> captureToken(Uri homeserver) async {
    // SECURITY: a hostile homeserver URL would still let it issue a login
    // token to the browser tab. We cannot fully prevent that, but logging
    // the destination keeps the record of where a token was just sent.
    _log.w('Opening SSO redirect for homeserver: $homeserver');

    final server = SsoCallbackServer();
    final Uri callbackUri;
    try {
      callbackUri = await server.start();
    } on SocketException catch (e) {
      await server.stop();
      return SsoAttempt.failed('Failed to bind local server: $e');
    }

    _server = server;

    final Uri ssoUrl = _ssoRedirect(homeserver, callbackUri.toString());
    _destination = ssoUrl;

    try {
      await launchUrl(ssoUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      await _stopServer();
      return SsoAttempt.failed('Could not open browser: $e');
    }

    final String token;
    try {
      token = await server.token.timeout(_timeout);
    } on TimeoutException {
      await _stopServer();
      return SsoAttempt.failed('Timed out waiting for browser redirect');
    }

    // Let the caller show that the token arrived before it navigates away.
    await Future.delayed(_settleDelay);

    // Shut the server down before the login call, so the token is not
    // sitting in a future that outlives the page.
    await _stopServer();

    return SsoAttempt.token(token);
  }

  /// Abandons an in-flight capture and returns the page to the manual
  /// fallback. Safe to call when nothing is running.
  Future<void> cancel() => _stopServer();

  /// Releases the server if the page is disposed mid-capture.
  void dispose() {
    // Deliberately not awaited: dispose is synchronous, and the token
    // future being abandoned is exactly the point.
    _server?.stop();
    _server = null;
  }

  Future<void> _stopServer() async {
    final server = _server;
    _server = null;
    // The destination stays readable after a failure on purpose: it is what
    // the manual fallback shows the user so they can retry the same URL.
    await server?.stop();
  }
}

/// The homeserver's SSO redirect endpoint, pointed at [redirectUrl].
Uri _ssoRedirect(Uri homeserver, String redirectUrl) {
  return homeserver.replace(
    path: '/_matrix/client/v3/login/sso/redirect',
    queryParameters: {'redirectUrl': redirectUrl},
  );
}
