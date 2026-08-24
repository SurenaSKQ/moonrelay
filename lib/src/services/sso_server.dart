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
import 'dart:io';
import 'dart:math';

import 'package:logger/logger.dart';

/// Manages a temporary local HTTP server that receives the SSO login token
/// callback from the browser.
///
/// After the user authenticates in their browser, the homeserver redirects
/// to `http://127.0.0.1:{port}/callback?loginToken={token}&state={nonce}`.
/// This server validates the `state` parameter against the nonce generated
/// at [start] time, then captures the token and makes it available via
/// [token].
///
/// Only GET requests carrying a loopback Host header (127.0.0.1 or
/// localhost) on the server's own port are accepted; any other request
/// method or origin is rejected with a 403 response.
class SsoCallbackServer {
  HttpServer? _server;
  Completer<String>? _completer;
  int _port = 0;

  /// The randomly generated CSRF nonce that must appear in the callback.
  String? _expectedState;

  /// Timer that closes the server after 120 seconds if no callback arrives.
  Timer? _autoShutdownTimer;

  /// Logger for forensic logging of incoming requests.
  final Logger _log = Logger();

  /// The port the server is listening on, or 0 if not started.
  int get port => _port;

  /// Starts the local HTTP server on a random available port and returns
  /// the [Uri] the browser should be redirected to for SSO.
  ///
  /// The returned URI has the path `/callback` and includes a `state`
  /// parameter whose value must be echoed back by the homeserver in the
  /// redirect URI.
  Future<Uri> start() async {
    await stop(); // ensure any previous server is cleaned up

    _completer = Completer<String>();

    // Generate a 32-byte random nonce for CSRF protection.
    final nonceBytes =
        List<int>.generate(32, (_) => _secureRandom.nextInt(256));
    _expectedState = base64Url.encode(nonceBytes);

    // Bind to any available port on localhost (IPv4 loopback only).
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;

    // Use the literal loopback address rather than "localhost" in the
    // redirect.  Browsers may resolve "localhost" to ::1 (IPv6) first,
    // and the server only listens on 127.0.0.1, which made the callback
    // fail on systems that prefer IPv6.
    final Uri redirectUri = Uri(
      scheme: 'http',
      host: InternetAddress.loopbackIPv4.address,
      port: _port,
      path: '/callback',
      queryParameters: {'state': _expectedState},
    );

    // Listen for exactly one request: the SSO redirect.
    _server!.listen(_handleRequest);

    // Self-destruct timer: close server after 120 seconds even without callback.
    _autoShutdownTimer?.cancel();
    _autoShutdownTimer = Timer(const Duration(seconds: 120), () {
      _log.w('SSO callback server timed out after 120s');
      stop();
    });

    return redirectUri;
  }

  /// A future that completes with the login token once the browser redirects
  /// to the local server.
  Future<String> get token => _completer!.future;

  /// Stops the local server if it is running.
  Future<void> stop() async {
    _autoShutdownTimer?.cancel();
    _autoShutdownTimer = null;
    await _server?.close(force: true);
    _server = null;
    _port = 0;
    _expectedState = null;
    // Don't cancel the completer; callers may still await it.
    // If the token was never received, the future will never complete,
    // and the caller is responsible for a timeout.
  }

  Future<void> _handleRequest(HttpRequest request) async {
    // -- Reject anything that isn't the SSO callback path ----------
    // A misbehaving browser tab that hits `/` or any other path would
    // otherwise keep the connection open until the auto-shutdown fires.
    // Returning a 404 closes the request promptly and surfaces the
    // wrong-port / wrong-host origin to the user.
    if (request.uri.path != '/callback') {
      _log.w('SSO: rejected non-callback request to "${request.uri.path}"');
      request.response.statusCode = 404;
      request.response.headers.contentType = ContentType.html;
      request.response.write(
        '<!doctype html><html><body>'
        '<h1>404 Not Found</h1>'
        '<p>This server only accepts SSO callbacks at <code>/callback</code>.</p>'
        '<p>Please return to Moonrelay and retry the sign-in flow.</p>'
        '</body></html>',
      );
      await request.response.close();
      return;
    }

    // -- Validate the Host header ----------------------------
    // The browser navigates to whatever the redirect URI host was.
    // Accept both loopback spellings (the redirect uses 127.0.0.1, but
    // a homeserver or proxy may echo `localhost` instead) while still
    // pinning the exact port so no other origin can reach the callback.
    final host = request.headers.value('host');
    final expectedHosts = {'localhost:$_port', '127.0.0.1:$_port'};
    if (host == null || !expectedHosts.contains(host)) {
      _log.w('SSO: rejected request with Host header "$host"');
      _respondWithError(
        request,
        'Invalid Request',
        'This server only accepts SSO callbacks on its own port. '
        'Please restart the sign-in flow in Moonrelay.',
      );
      if (!_completer!.isCompleted) {
        _completer!.completeError(
          const FormatException('SSO callback rejected: bad host header'),
        );
      }
      stop();
      return;
    }

    // -- Only accept GET -------------------------------------------
    if (request.method.toUpperCase() != 'GET') {
      _respondWithError(
        request,
        'Method Not Allowed',
        'Only the browser redirect (GET) is supported. '
        'Return to the application and try again.',
      );
      return;
    }

    final Uri uri = request.uri;

    // -- Validate the CSRF state parameter -------------------------
    final String? receivedState = uri.queryParameters['state'];
    if (_expectedState == null ||
        receivedState == null ||
        receivedState != _expectedState) {
      _respondWithError(
        request,
        'Invalid State',
        'The SSO callback did not include a valid state parameter. '
        'This can happen if the request is replayed or the state '
        'expired. Please return to the application and try again.',
      );
      if (!_completer!.isCompleted) {
        _completer!.completeError(
          const FormatException('SSO callback rejected: bad state'),
        );
      }
      stop();
      return;
    }

    // -- Invalidate state immediately + close server (single-use) --
    _expectedState = null;
    stop();

    // -- Try to extract the login token ----------------------------
    final String? loginToken = uri.queryParameters['loginToken'];

    if (loginToken != null && loginToken.isNotEmpty) {
      // -- Success path --
      _respondWithPage(
        request,
        200,
        'Authentication Complete',
        '''
        <p style="font-size:18px;color:#16a34a;">
          ✓ Authentication successful!
        </p>
        <p>You may close this window and return to the application.</p>
        ''',
      );

      if (!_completer!.isCompleted) {
        _completer!.complete(loginToken);
      }
    } else {
      // -- Fallback: show a page with the full URL so the user can
      // manually copy the token if the automatic extraction failed.
      // The URL in the error page omits the token to avoid leaking it.
      _respondWithPage(
        request,
        200,
        'SSO Callback Received',
        '''
        <p style="font-size:16px;color:#f59e0b;">
          ⚠ The login token could not be extracted automatically.
        </p>
        <p>Please check the address bar for a <code>loginToken</code>
        parameter and copy it into the application manually.</p>
        ''',
      );
      if (!_completer!.isCompleted) {
        // Signal failure to the login flow so the UI can abort cleanly
        // instead of waiting forever for a token.
        _completer!.completeError(
          const FormatException('SSO callback had no login token'),
        );
      }
    }
  }

  /// Sends a styled error page so the browser tab doesn't hang waiting
  /// for a result that the application never receives.
  void _respondWithError(
    HttpRequest request,
    String title,
    String bodyHtml,
  ) {
    _respondWithPage(
      request,
      400,
      title,
      '''
      <p style="font-size:16px;color:#dc2626;">
        ⚠ $title
      </p>
      <p>$bodyHtml</p>
      ''',
    );
  }

  void _respondWithPage(
    HttpRequest request,
    int statusCode,
    String title,
    String bodyHtml,
  ) {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.html;
    request.response.headers.set(
      'Content-Security-Policy',
      "default-src 'none'; style-src 'unsafe-inline';",
    );
    request.response.write('''
    <!DOCTYPE html>
    <html>
    <head><meta charset="utf-8"><title>$title</title></head>
    <body style="
      font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto,
                   Oxygen, Ubuntu, Cantarell, sans-serif;
      display:flex;justify-content:center;align-items:center;
      min-height:100vh;margin:0;background:#f9fafb;color:#111827;">
      <div style="text-align:center;max-width:500px;padding:2rem;
                  background:white;border-radius:12px;box-shadow:0 4px 6px
                  rgba(0,0,0,0.1);">
        <h1 style="font-size:22px;margin-bottom:16px;">
          Moonrelay  $title
        </h1>
        $bodyHtml
      </div>
    </body>
    </html>
    ''');
    request.response.close();
  }

  /// A cryptographically secure random number generator for nonces.
  static final Random _secureRandom = Random.secure();
}
