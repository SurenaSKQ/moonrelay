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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

/// Login page with password and SSO support.
///
/// This page discovers the homeserver's supported login flows and presents
/// the appropriate authentication options:
/// - Password login with homeserver, username, and password fields
/// - SSO login that opens the browser and accepts a login token callback
/// - Token-based login for advanced flows
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _homeserverCtrl =
      TextEditingController(text: 'matrix.org');
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _tokenCtrl = TextEditingController();

  bool _loading = false;
  bool _ssoMode = false;
  bool _tokenMode = false;

  String? _error;
  String? _ssoUrl;

  @override
  void dispose() {
    _homeserverCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context)!;
    final ThemeData theme = Theme.of(context);
    final ColorScheme colors = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(LucideIcons.arrowLeft),
                        onPressed: () => context.pop(),
                        tooltip: l10n.cancel,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _ssoMode
                            ? 'Single Sign-On'
                            : _tokenMode
                                ? 'Token Login'
                                : 'Sign In',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                          color: colors.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Error banner
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colors.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Icon(LucideIcons.alertCircle,
                                size: 18, color: colors.error),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _error!,
                                style: TextStyle(
                                  color: colors.onErrorContainer,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // ── Homeserver field ──
                  _buildLabel(colors, 'Homeserver'),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _homeserverCtrl,
                    decoration: InputDecoration(
                      hintText: 'matrix.org',
                      prefixIcon: const Icon(LucideIcons.server, size: 18),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: const TextStyle(fontSize: 14),
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 20),

                  // ── SSO mode ──
                  if (_ssoMode) ..._buildSsoSection(colors),

                  // ── Token mode ──
                  if (_tokenMode) ..._buildTokenSection(colors),

                  // ── Password mode ──
                  if (!_ssoMode && !_tokenMode)
                    ..._buildPasswordSection(colors),

                  const SizedBox(height: 24),

                  // ── Primary action button ──
                  if (_ssoMode)
                    _buildSsoActionButton(colors)
                  else if (_tokenMode)
                    _buildTokenActionButton(colors)
                  else
                    _buildPasswordActionButton(colors, l10n),

                  // ── Mode switcher ──
                  if (!_loading) ...[
                    const SizedBox(height: 12),
                    if (!_ssoMode && !_tokenMode)
                      _buildModeLink(
                        'Use Single Sign-On instead',
                        () => setState(() => _ssoMode = true),
                      ),
                    if (_ssoMode && !_tokenMode)
                      _buildModeLink(
                        'Use password instead',
                        () => setState(() => _ssoMode = false),
                      ),
                    if (!_ssoMode && !_tokenMode)
                      _buildModeLink(
                        'Use login token instead',
                        () => setState(() => _tokenMode = true),
                      ),
                    if (_tokenMode)
                      _buildModeLink(
                        'Back to password login',
                        () => setState(() => _tokenMode = false),
                      ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Build helpers ─────────────────────────────────────────────────────

  Widget _buildLabel(ColorScheme colors, String text) {
    return Text(
      text,
      style: TextStyle(
        fontWeight: FontWeight.w500,
        fontSize: 13,
        color: colors.onSurfaceVariant,
      ),
    );
  }

  Widget _buildModeLink(String text, VoidCallback onTap) {
    return Align(
      alignment: Alignment.center,
      child: TextButton(
        onPressed: onTap,
        child: Text(
          text,
          style: const TextStyle(fontSize: 13),
        ),
      ),
    );
  }

  List<Widget> _buildPasswordSection(ColorScheme colors) {
    return [
      _buildLabel(colors, 'Username or email'),
      const SizedBox(height: 6),
      TextField(
        controller: _usernameCtrl,
        decoration: InputDecoration(
          hintText: '@user:matrix.org',
          prefixIcon: const Icon(LucideIcons.user, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(fontSize: 14),
        enabled: !_loading,
      ),
      const SizedBox(height: 16),
      _buildLabel(colors, 'Password'),
      const SizedBox(height: 6),
      TextField(
        controller: _passwordCtrl,
        obscureText: true,
        decoration: InputDecoration(
          hintText: '••••••••',
          prefixIcon: const Icon(LucideIcons.lock, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(fontSize: 14),
        enabled: !_loading,
      ),
    ];
  }

  List<Widget> _buildSsoSection(ColorScheme colors) {
    return [
      _buildLabel(colors, 'SSO Login URL'),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _ssoUrl ?? 'Click "Open in Browser" to start.',
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
      const SizedBox(height: 16),
      _buildLabel(colors, 'Login Token (paste after authenticating)'),
      const SizedBox(height: 6),
      TextField(
        controller: _tokenCtrl,
        decoration: InputDecoration(
          hintText: 'Paste your login token here…',
          prefixIcon: const Icon(LucideIcons.key, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(fontSize: 14),
        enabled: !_loading,
      ),
    ];
  }

  List<Widget> _buildTokenSection(ColorScheme colors) {
    return [
      _buildLabel(colors, 'Login Token'),
      const SizedBox(height: 6),
      TextField(
        controller: _tokenCtrl,
        decoration: InputDecoration(
          hintText: 'Paste your login token here…',
          prefixIcon: const Icon(LucideIcons.key, size: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: const TextStyle(fontSize: 14),
        enabled: !_loading,
      ),
    ];
  }

  Widget _buildPasswordActionButton(
    ColorScheme colors,
    AppLocalizations l10n,
  ) {
    return FilledButton.icon(
      onPressed: _loading ? null : _doPasswordLogin,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.logIn, size: 18),
      label: Text(_loading ? 'Signing in…' : l10n.loginButton),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSsoActionButton(ColorScheme colors) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _loading ? null : _doSsoOpenBrowser,
          icon: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(LucideIcons.externalLink, size: 18),
          label: Text(_loading ? 'Preparing…' : 'Open in Browser'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _doSsoComplete,
          icon: const Icon(LucideIcons.check, size: 18),
          label: const Text('Complete Login'),
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildTokenActionButton(ColorScheme colors) {
    return FilledButton.icon(
      onPressed: _loading ? null : _doTokenLogin,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.key, size: 18),
      label: Text(_loading ? 'Signing in…' : 'Sign in with Token'),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // ── Login actions ────────────────────────────────────────────────────

  Future<List<LoginFlow>?> _tryCheckHomeserver(
    Client client,
    Uri homeserverUri,
  ) async {
    final Logger log = Provider.of<Logger>(context, listen: false);

    final result = await withRetry(
      () => client.checkHomeserver(
        homeserverUri,
        checkWellKnown: true,
      ),
      maxRetries: 1,
      timeout: kLoginTimeout,
      log: log,
      label: 'checkHomeserver',
    );

    return switch (result) {
      RetrySuccess(:final value) => value.$3,
      RetryFailed(:final error) =>
        _handleTimeoutError(error, 'Could not connect to homeserver'),
    };
  }

  /// Checks whether [error] is a timeout and sets a user-facing message.
  /// Returns `null` to signal the caller to abort.
  List<LoginFlow>? _handleTimeoutError(Object error, String prefix) {
    if (error is TimeoutException) {
      setState(() => _error =
          '$prefix: The server did not respond in time. Please check your connection and try again.');
    } else {
      setState(() => _error = '$prefix: $error');
    }
    return null;
  }

  Future<void> _doPasswordLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);

    // Ensure supported login types includes password
    client.supportedLoginTypes.add(AuthenticationTypes.password);

    final String hs = _homeserverCtrl.text.trim();
    final Uri homeserverUri =
        hs.contains('://') ? Uri.parse(hs) : Uri.https(hs, '');

    final List<LoginFlow>? flows =
        await _tryCheckHomeserver(client, homeserverUri);
    if (flows == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!flows.any((f) => f.type == AuthenticationTypes.password)) {
      setState(() {
        _error = 'This homeserver does not support password login.';
        _loading = false;
      });
      return;
    }

    final result = await withRetry(
      () => client.login(
        LoginType.mLoginPassword,
        password: _passwordCtrl.text,
        identifier:
            AuthenticationUserIdentifier(user: _usernameCtrl.text.trim()),
      ),
      maxRetries: 1,
      timeout: kLoginTimeout,
      log: log,
      label: 'passwordLogin',
      retryOnAllErrors: true, // login errors are often transient
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess():
        {
          context.go('/main/rooms');
        }
      case RetryFailed(:final error, :final attempts):
        {
          log.e('Login failed after $attempts attempt(s)', error: error);
          setState(() => _error = error is TimeoutException
              ? 'Login timed out. The server may be overloaded. Please try again.'
              : 'Login failed: $error');
        }
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _doSsoOpenBrowser() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);

    client.supportedLoginTypes.add(AuthenticationTypes.sso);

    final String hs = _homeserverCtrl.text.trim();
    final Uri homeserverUri =
        hs.contains('://') ? Uri.parse(hs) : Uri.https(hs, '');

    final List<LoginFlow>? flows =
        await _tryCheckHomeserver(client, homeserverUri);
    if (flows == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!flows.any((f) => f.type == AuthenticationTypes.sso)) {
      setState(() {
        _error = 'This homeserver does not support SSO login.';
        _loading = false;
      });
      return;
    }

    // Build the SSO redirect URL.
    // Use an OOB redirect URI so the browser shows the token after auth.
    final Uri ssoUrl = homeserverUri.replace(
      path: '/_matrix/client/v3/login/sso/redirect',
      queryParameters: {
        'redirectUrl': 'urn:ietf:wg:oauth:2.0:oob',
      },
    );

    setState(() {
      _ssoUrl = ssoUrl.toString();
      _loading = false;
    });

    try {
      await launchUrl(ssoUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      log.e('Could not open browser', error: e);
      if (!mounted) return;
      setState(() => _error = 'Could not open browser. Use the URL above.');
    }
  }

  Future<void> _doSsoComplete() async {
    final String token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(
          () => _error = 'Please paste the login token from your browser.');
      return;
    }
    await _completeTokenLogin(token);
  }

  Future<void> _doTokenLogin() async {
    final String token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Please enter a login token.');
      return;
    }
    await _completeTokenLogin(token);
  }

  Future<void> _completeTokenLogin(String token) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);

    client.supportedLoginTypes.add(AuthenticationTypes.token);

    final String hs = _homeserverCtrl.text.trim();
    final Uri homeserverUri =
        hs.contains('://') ? Uri.parse(hs) : Uri.https(hs, '');

    final List<LoginFlow>? flows =
        await _tryCheckHomeserver(client, homeserverUri);
    if (flows == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    final result = await withRetry(
      () => client.login(
        LoginType.mLoginToken,
        token: token,
      ),
      maxRetries: 1,
      timeout: kLoginTimeout,
      log: log,
      label: 'tokenLogin',
      retryOnAllErrors: true,
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess():
        {
          context.go('/main/rooms');
        }
      case RetryFailed(:final error, :final attempts):
        {
          log.e('Token login failed after $attempts attempt(s)', error: error);
          setState(() => _error = error is TimeoutException
              ? 'Login timed out. The server may be overloaded. Please try again.'
              : 'Token login failed: $error');
        }
    }

    if (mounted) setState(() => _loading = false);
  }
}
