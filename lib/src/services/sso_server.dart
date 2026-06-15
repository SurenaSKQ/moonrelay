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

/// Manages a temporary local HTTP server that receives the SSO login token
/// callback from the browser.
///
/// After the user authenticates in their browser, the homeserver redirects
/// to `http://localhost:{port}/callback?loginToken={token}&state={nonce}`.
/// This server validates the `state` parameter against the nonce generated
/// at [start] time, then captures the token and makes it available via
/// [token].
///
/// Only GET requests from localhost are accepted; any other request method
/// or origin is rejected with a 403 response.
class SsoCallbackServer {
  HttpServer? _server;
  Completer<String>? _completer;
  int _port = 0;

  /// The randomly generated CSRF nonce that must appear in the callback.
  String? _expectedState;

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

    // Bind to any available port on localhost.
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _port = _server!.port;

    final Uri redirectUri = Uri(
      scheme: 'http',
      host: 'localhost',
      port: _port,
      path: '/callback',
      queryParameters: {'state': _expectedState},
    );

    // Listen for exactly one request — the SSO redirect.
    _server!.listen(_handleRequest);

    return redirectUri;
  }

  /// A future that completes with the login token once the browser redirects
  /// to the local server.
  Future<String> get token => _completer!.future;

  /// Stops the local server if it is running.
  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
    _port = 0;
    _expectedState = null;
    // Don't cancel the completer — callers may still await it.
    // If the token was never received, the future will never complete,
    // and the caller is responsible for a timeout.
  }

  void _handleRequest(HttpRequest request) {
    // ── Only accept GET ───────────────────────────────────────────
    if (request.method.toUpperCase() != 'GET') {
      _respondWithText(request, 405, 'Method Not Allowed');
      return;
    }

    final Uri uri = request.uri;

    // ── Validate the CSRF state parameter ─────────────────────────
    final String? receivedState = uri.queryParameters['state'];
    if (_expectedState == null ||
        receivedState == null ||
        receivedState != _expectedState) {
      _respondWithText(request, 403, 'Invalid or missing state parameter');
      return;
    }

    // ── Try to extract the login token ────────────────────────────
    final String? loginToken = uri.queryParameters['loginToken'];

    // Invalidate the state immediately — it's single-use.
    _expectedState = null;

    if (loginToken != null && loginToken.isNotEmpty) {
      // ── Success path ──
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
      // ── Fallback: show a page with the full URL so the user can
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
    }
  }

  void _respondWithText(HttpRequest request, int statusCode, String body) {
    request.response.statusCode = statusCode;
    request.response.headers.contentType = ContentType.text;
    request.response.write(body);
    request.response.close();
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
          Moonrelay — $title
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
