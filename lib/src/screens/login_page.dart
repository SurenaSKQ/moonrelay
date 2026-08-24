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

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logger/logger.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:matrix/matrix.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/homeserver_url.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/services/sso_server.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/screens/encryption/verification_screen.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Login page with password and SSO support.
///
/// This page discovers the homeserver's supported login flows and presents
/// the appropriate authentication options:
/// - Password login with homeserver, username, and password fields
/// - SSO login that **automatically** captures the token via a local HTTP
///   server (falling back to manual copy-paste if the automatic flow fails)
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
  bool _syncing = false;
  bool _ssoMode = false;
  bool _tokenMode = false;

  /// Tracks whether we are running the automatic (local-server) SSO flow.
  bool _autoSsoActive = false;

  /// Set to `true` when the automatic SSO flow fails so we show the manual
  /// fallback UI instead.
  bool _autoSsoFailed = false;

  /// The local HTTP server used to capture the SSO login token.
  SsoCallbackServer? _ssoServer;

  /// A timer that can cancel the automatic SSO wait if it takes too long.
  Timer? _autoSsoTimer;

  /// Whether the manual token-paste field is visible in the fallback SSO UI.
  bool _showManualTokenEntry = false;

  String? _error;
  String? _ssoUrl;
  String? _statusMessage;

  bool _didCheckExtra = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didCheckExtra) {
      _didCheckExtra = true;
      final Object? extra = GoRouterState.of(context).extra;
      if (extra == 'sso') {
        setState(() {
          _ssoMode = true;
          _showManualTokenEntry = false;
        });
      } else if (extra is Map<String, String>) {
        final hs = extra['homeserver'];
        final username = extra['username'];
        if (hs != null && hs.isNotEmpty) {
          _homeserverCtrl.text = hs;
        }
        if (username != null && username.isNotEmpty) {
          _usernameCtrl.text = username;
        }
      }
    }
  }

  @override
  void dispose() {
    _autoSsoTimer?.cancel();
    _ssoServer?.stop();
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
    final t = MoonrelayThemeExtension.of(context).tokens;

    // -- Full-screen syncing state after successful login --------------
    if (_syncing) {
      return _buildSyncingScreen(colors, theme, l10n);
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                elevation: t.elevationMedium,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusLg),
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
                          SizedBox(width: t.spaceSm),
                          Text(
                            _ssoMode
                                ? l10n.ssoTitle
                                : _tokenMode
                                    ? l10n.tokenLoginTitle
                                    : l10n.signInTitle,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 20,
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: t.spaceXl),

                      // Error banner
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            padding: EdgeInsets.all(t.spaceMd),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius: BorderRadius.circular(t.radiusSm),
                            ),
                            child: Row(
                              children: [
                                Icon(LucideIcons.alertCircle,
                                    size: 18, color: colors.error),
                                SizedBox(width: t.spaceSm),
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

                      // -- Homeserver field --
                      _buildLabel(colors, l10n.homeserverText),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _homeserverCtrl,
                        decoration: InputDecoration(
                          hintText: 'matrix.org',
                          prefixIcon: const Icon(LucideIcons.server, size: 18),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(t.radiusMd),
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

                      // -- SSO mode --
                      if (_ssoMode) ..._buildSsoSection(colors, l10n),

                      // -- Auto-SSO status (shown during automatic flow) --
                      if (_autoSsoActive) ..._buildAutoSsoStatus(colors, l10n),

                      // -- Token mode --
                      if (_tokenMode) ..._buildTokenSection(colors, l10n),

                      // -- Password mode --
                      if (!_ssoMode && !_tokenMode)
                        ..._buildPasswordSection(colors, l10n),

                      SizedBox(height: t.spaceXl),

                      // -- Primary action button --
                      if (_autoSsoActive)
                        _buildAutoSsoActionButton(colors, l10n)
                      else if (_ssoMode)
                        _buildSsoActionButton(colors, l10n)
                      else if (_tokenMode)
                        _buildTokenActionButton(colors, l10n)
                      else
                        _buildPasswordActionButton(colors, l10n),

                      // -- Mode switcher --
                      if (!_loading && !_autoSsoActive) ...[
                        SizedBox(height: t.spaceMd),
                        if (!_ssoMode && !_tokenMode)
                          _buildModeLink(
                            l10n.useSsoInstead,
                            () => setState(() {
                              _ssoMode = true;
                              _showManualTokenEntry = false;
                            }),
                          ),
                        if (_ssoMode && !_tokenMode)
                          _buildModeLink(
                            l10n.usePasswordInstead,
                            () => setState(() => _ssoMode = false),
                          ),
                        if (!_ssoMode && !_tokenMode)
                          _buildModeLink(
                            l10n.useTokenInstead,
                            () => setState(() => _tokenMode = true),
                          ),
                        if (_tokenMode)
                          _buildModeLink(
                            l10n.backToPasswordLogin,
                            () => setState(() => _tokenMode = false),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -- Syncing screen ---------------------------------------------------

  Widget _buildSyncingScreen(
      ColorScheme colors, ThemeData theme, AppLocalizations l10n) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.moon,
              size: 48,
              color: colors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              l10n.welcomeToApp,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: colors.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: colors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _statusMessage ?? l10n.loading,
              style: TextStyle(
                fontSize: 15,
                color: colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.fetchingRooms,
              style: TextStyle(
                fontSize: 13,
                color: colors.onSurfaceVariant.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // -- Build helpers -----------------------------------------------------

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

  List<Widget> _buildPasswordSection(
      ColorScheme colors, AppLocalizations l10n) {
    return [
      _buildLabel(colors, l10n.usernameOrEmail),
      const SizedBox(height: 6),
      TextField(
        controller: _usernameCtrl,
        decoration: InputDecoration(
          hintText: l10n.usernameHint,
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
      _buildLabel(colors, l10n.passwordText),
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

  /// Builds the status UI shown during the automatic (local-server) SSO flow.
  List<Widget> _buildAutoSsoStatus(ColorScheme colors, AppLocalizations l10n) {
    return [
      const SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colors.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: colors.primary.withValues(alpha: 0.3),
          ),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: colors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                l10n.ssoWaitingForBrowser,
                style: TextStyle(
                  fontSize: 14,
                  color: colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }

  /// Builds the cancel / switch-to-manual button during automatic SSO.
  Widget _buildAutoSsoActionButton(ColorScheme colors, AppLocalizations l10n) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: _cancelAutoSso,
          icon: const Icon(LucideIcons.arrowLeft, size: 18),
          label: Text(l10n.ssoSwitchToManual),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (_autoSsoFailed)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.ssoAutomaticFailed,
              style: TextStyle(
                fontSize: 13,
                color: colors.error,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  List<Widget> _buildSsoSection(ColorScheme colors, AppLocalizations l10n) {
    return [
      _buildLabel(colors, l10n.ssoUrlLabel),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _ssoUrl ?? l10n.ssoStartingHint,
          style: TextStyle(
            fontFamily: 'SpaceMono',
            fontSize: 12,
            color: colors.onSurfaceVariant,
          ),
        ),
      ),
      // Token field: only shown when the user explicitly requests it.
      if (_showManualTokenEntry) ...[..._buildManualTokenEntry(colors, l10n)],
    ];
  }

  /// Builds the manual token-paste field (hidden behind a toggle by default).
  List<Widget> _buildManualTokenEntry(
      ColorScheme colors, AppLocalizations l10n) {
    return [
      const SizedBox(height: 16),
      _buildLabel(colors, '${l10n.tokenLabel} (paste after authenticating)'),
      const SizedBox(height: 6),
      TextField(
        controller: _tokenCtrl,
        decoration: InputDecoration(
          hintText: l10n.tokenHint,
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

  List<Widget> _buildTokenSection(ColorScheme colors, AppLocalizations l10n) {
    return [
      _buildLabel(colors, l10n.tokenLabel),
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
      label: Text(_loading ? l10n.signingIn : l10n.loginButton),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildSsoActionButton(ColorScheme colors, AppLocalizations l10n) {
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
          label: Text(_loading ? l10n.preparing : l10n.openInBrowser),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 12),
        // -- "Paste token manually" toggle --
        if (!_showManualTokenEntry)
          OutlinedButton.icon(
            onPressed: () => setState(() => _showManualTokenEntry = true),
            icon: const Icon(LucideIcons.key, size: 18),
            label: Text(l10n.ssoPasteManually),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        // -- Manual entry visible: show "Complete Login" --
        if (_showManualTokenEntry)
          FilledButton.icon(
            onPressed: _loading ? null : _doSsoComplete,
            icon: const Icon(LucideIcons.check, size: 18),
            label: Text(l10n.completeLogin),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
      ],
    );
  }

  Widget _buildTokenActionButton(ColorScheme colors, AppLocalizations l10n) {
    return FilledButton.icon(
      onPressed: _loading ? null : _doTokenLogin,
      icon: _loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(LucideIcons.key, size: 18),
      label: Text(_loading ? l10n.signingIn : l10n.signInWithToken),
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  // -- Login actions ----------------------------------------------------

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
    final l10n = AppLocalizations.of(context)!;
    if (error is TimeoutException) {
      setState(() => _error = '$prefix: ${l10n.loginHomeserverTimeout}');
    } else {
      setState(() => _error = '$prefix: $error');
    }
    return null;
  }

  Future<void> _doPasswordLogin() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });

    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);
    final enc = context.read<EncryptionService>();

    // -- Invalidate any cached session data before a fresh login --
    // This ensures the SDK doesn't carry over a stale Olm account,
    // stale device keys, or any other cached state from a previous
    // session (e.g. after an unclean shutdown or a failed logout).
    await _clearCachedSession(client, enc, log);

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
        _error = l10n.passwordLoginNotSupported;
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
        initialDeviceDisplayName: 'Moonrelay',
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
          // -- Transition to syncing state ----------------------------
          // Login succeeded; the Matrix SDK is now running its first sync
          // in the background.  Show a full-screen loading state so the
          // user sees progress instead of a blank room list.
          setState(() {
            _statusMessage = l10n.syncingYourAccount;
            _loading = false; // allow the build method to show _syncing UI
            _syncing = true;
          });

          // -- Enable encryption now that we're logged in ----------
          // Capture all provider reads before any await so the analyzer
          // doesn't see [context] used across the async gap.
          final encryptionService = context.read<EncryptionService>();
          final accountManager = context.read<AccountManager>();
          final homeserverSnapshot = client.homeserver?.toString() ?? '';
          final userIdSnapshot = client.userID!;
          await encryptionService.init();

          // -- Save this account for multi-account support ---------
          await accountManager.addOrUpdateAccount(
            StoredAccount(
              userId: userIdSnapshot,
              homeserver: homeserverSnapshot,
            ),
            client: client,
            encryptionService: encryptionService,
          );

          final syncResult = await _waitForInitialSync(client, log);

          if (!mounted) return;

          switch (syncResult) {
            case true:
              context.go('/main/rooms');
            case false:
              log.w('Initial sync not yet complete, proceeding to rooms');
              context.go('/main/rooms');
          }

          // -- Post-login encryption: SAS verification only ---------
          // The new encryption flow surfaces a one-shot emoji
          // verification prompt immediately after sign-in.  Cross-
          // signing bootstrap, recovery key flows, and other SSSS
          // prompts are intentionally deferred to the encryption
          // settings page so the user is not ambushed by password-
          // style dialogs every time they open the app.
          await _maybePromptDeviceVerification(encryptionService);
        }
      case RetryFailed(:final error, :final attempts):
        {
          // SECURITY: never pass the raw error to either the logger or the
          // UI  `MatrixHttpException.toString()` echoes the request body,
          // which the homeserver can echo back the typed password in 4xx
          // responses. Log only the class and rethrow; the user-facing
          // message is a static copy that omits the offending field.
          log.e(
              'Login failed after $attempts attempt(s) (${error.runtimeType})');
          setState(() => _error = error is TimeoutException
              ? l10n.loginTimedOut
              : l10n.loginFailed(_safeErrorMessage(error)));
          if (mounted) setState(() => _loading = false);
        }
    }
  }

  /// Returns a user-facing error string that does not leak credentials.
  ///
  /// The Matrix SDK's `MatrixHttpException.toString()` echoes the request
  /// body, so a homeserver that returns the password field in a 4xx
  /// response would surface it in the UI and in redacted logs.  This
  /// helper maps known error types to friendly copy and falls back to a
  /// generic message that exposes only the exception's class name.
  String _safeErrorMessage(Object error) {
    if (error is TimeoutException) return 'request timed out';
    // Strip the request body by relying on the exception's public
    // properties; never touch `.toString()`.
    return error.runtimeType.toString();
  }

  /// Clears any cached session data from the SDK and EncryptionService
  /// so a fresh login starts with a clean slate.
  ///
  /// This prevents stale Olm accounts, cached device keys, and other
  /// encrypted state from leaking across sessions (e.g. after a crash
  /// before [Client.logout] completed, or when re-logging into a
  /// different account on the same client instance).
  Future<void> _clearCachedSession(
    Client client,
    EncryptionService enc,
    Logger log,
  ) async {
    try {
      // If there's an active session, shut it down properly.
      if (client.isLogged()) {
        await enc.onLogout();
        await client.logout();
        log.i('Cleared previous session before login');
        return;
      }
    } catch (_) {
      // Ignore logout errors; we'll still clear caches below.
    }

    // Even without an active session, clear any cached state that
    // the SDK may have loaded from the database on init().
    try {
      await client.clearCache();
    } catch (_) {
      // best-effort
    }

    await enc.onLogout();
    log.i('Cleared cached client state before login');
  }

  /// Waits for the first [Client.onSync] event, which indicates that the
  /// initial sync has delivered room data.  Returns `true` if sync completed
  /// within the timeout, `false` otherwise.
  Future<bool> _waitForInitialSync(Client client, Logger log) async {
    try {
      await client.onSync.stream.first.timeout(
        const Duration(seconds: 20),
      );
      return true;
    } on TimeoutException {
      log.w('Initial sync timed out but continuing to room list');
      return false;
    } catch (e) {
      log.w('Initial sync error but continuing', error: e);
      return false;
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  /// Drives the new post-login encryption prompt.  When the device
  /// is not yet verified, requests an SAS / emoji verification and
  /// shows the verification screen so the user can match the emoji
  /// sequence against another signed-in device.
  ///
  /// The check is best-effort: any failure (encryption not ready,
  /// the other device does not respond, the user cancels) is logged
  /// and swallowed so a stuck verification handshake can never
  /// prevent the user from reaching the room list.
  Future<void> _maybePromptDeviceVerification(
    EncryptionService encryptionService,
  ) async {
    if (!mounted) return;
    final log = Provider.of<Logger>(context, listen: false);
    KeyVerification? kv;
    try {
      kv = await encryptionService.startPostLoginFlow();
    } catch (e) {
      log.w('post-login encryption flow failed', error: e);
      return;
    }
    if (kv == null) return;
    if (!mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => VerificationScreen(
          request: kv!,
          isIncoming: false,
        ),
      ),
    );
  }

  /// Attempts SSO login using the automatic (local server callback) flow.
  /// Falls back to the manual copy-paste flow if the automatic approach fails.
  Future<void> _doSsoOpenBrowser() async {
    final l10n = AppLocalizations.of(context)!;
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

    // -- Phishing guard ----------------------------------------
    // The homeserver address is user-supplied. Before we point the user's
    // browser at it, refuse URLs that obviously are not homeservers and
    // make the destination explicit so a phisher pointing at a look-alike
    // domain is harder to miss. Failures here short-circuit before any
    // network call.
    if (!isPlausibleHomeserverUrl(homeserverUri)) {
      log.w('Refusing SSO login: homeserver URL looks invalid: $homeserverUri');
      setState(() {
        _error = l10n.ssoHomeserverInvalid;
        _loading = false;
      });
      return;
    }

    // -- Confirmation prompt ----------------------------------
    // Surface the destination so the user can abort a phishing attempt
    // before the browser is opened and SSO credentials are sent.
    final bool? proceed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.ssoConfirmHomeserverTitle),
        content: Text(
          l10n.ssoConfirmHomeserverBody(homeserverUri.host),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.ssoConfirmHomeserverSwitch),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.ssoConfirmHomeserverContinue),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (proceed != true) {
      setState(() => _loading = false);
      return;
    }

    final List<LoginFlow>? flows =
        await _tryCheckHomeserver(client, homeserverUri);
    if (flows == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    if (!flows.any((f) => f.type == AuthenticationTypes.sso)) {
      setState(() {
        _error = l10n.ssoNotSupported;
        _loading = false;
      });
      return;
    }

    // -- Try the automatic (local-server) SSO flow --------------
    try {
      await _doAutomaticSso(client, log, l10n, homeserverUri);
      return; // success, we are done
    } on SsoAutomaticException catch (e) {
      log.w('Automatic SSO failed: ${e.message}');
      // Fall through to manual flow below
    } catch (e) {
      log.w('Automatic SSO failed with unexpected error: $e');
    }

    // -- Fallback: manual copy-paste flow -----------------------
    if (!mounted) return;

    // Build the SSO redirect URL with OOB redirect URI so the browser
    // shows the token after auth.
    final Uri ssoUrl = homeserverUri.replace(
      path: '/_matrix/client/v3/login/sso/redirect',
      queryParameters: {
        'redirectUrl': 'urn:ietf:wg:oauth:2.0:oob',
      },
    );

    setState(() {
      _ssoUrl = ssoUrl.toString();
      _autoSsoFailed = true;
      _autoSsoActive = false;
      _loading = false;
    });

    try {
      await launchUrl(ssoUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      log.e('Could not open browser', error: e);
      if (!mounted) return;
      setState(() => _error = l10n.couldNotOpenBrowser);
    }
  }

  /// Attempts the automatic SSO flow by:
  ///   1. Starting a local HTTP server on a random port.
  ///   2. Building the SSO redirect URL pointing to that local server.
  ///   3. Opening the browser.
  ///   4. Waiting for the browser to redirect back with the login token.
  ///   5. Completing the login.
  ///
  /// Throws [SsoAutomaticException] if any step fails, letting the caller
  /// fall back to the manual flow.
  Future<void> _doAutomaticSso(
    Client client,
    Logger log,
    AppLocalizations l10n,
    Uri homeserverUri,
  ) async {
    // -- 1. Start the local callback server ----------------------
    final SsoCallbackServer server = SsoCallbackServer();
    late Uri redirectUri;

    try {
      redirectUri = await server.start();
    } on SocketException catch (e) {
      await server.stop();
      throw SsoAutomaticException(
        'Failed to bind local server: $e',
      );
    }

    _ssoServer = server;

    if (!mounted) {
      await server.stop();
      return;
    }

    setState(() {
      _autoSsoActive = true;
      _autoSsoFailed = false;
      _loading = false;
      _ssoUrl = null;
    });

    // -- 2. Build the SSO URL with our local redirect -----------
    final Uri ssoUrl = homeserverUri.replace(
      path: '/_matrix/client/v3/login/sso/redirect',
      queryParameters: {
        'redirectUrl': redirectUri.toString(),
      },
    );

    // SECURITY: a hostile homeserver URL would still let it issue a
    // login token to the browser tab.  We can't fully prevent that,
    // but we can surface the destination so the user is aware that
    // they are about to authenticate against an unexpected server.
    log.w('Opening SSO redirect for homeserver: $homeserverUri');

    // -- 3. Open the browser ------------------------------------
    try {
      await launchUrl(ssoUrl, mode: LaunchMode.externalApplication);
    } catch (e) {
      await server.stop();
      _ssoServer = null;
      if (!mounted) return;
      setState(() => _autoSsoActive = false);
      throw SsoAutomaticException('Could not open browser: $e');
    }

    if (!mounted) {
      await server.stop();
      return;
    }

    // -- 4. Wait for the token (with timeout) -------------------
    String token;
    try {
      token = await server.token.timeout(
        const Duration(minutes: 3),
      );
    } on TimeoutException {
      await server.stop();
      _ssoServer = null;
      if (!mounted) return;
      setState(() => _autoSsoActive = false);
      throw SsoAutomaticException('Timed out waiting for browser redirect');
    } finally {
      _autoSsoTimer?.cancel();
    }

    if (!mounted) {
      await server.stop();
      return;
    }

    // -- 5. Token received: complete the login -----------------
    setState(() {
      _statusMessage = l10n.ssoTokenDetected;
    });

    // Small delay so the user sees the status update.
    await Future.delayed(const Duration(milliseconds: 600));

    // Shut down the server before the token login call.
    await server.stop();
    _ssoServer = null;

    if (!mounted) return;

    setState(() => _autoSsoActive = false);

    await _completeTokenLogin(token);
  }

  /// Cancels the automatic SSO flow and switches to the manual fallback.
  void _cancelAutoSso() {
    _autoSsoTimer?.cancel();
    _ssoServer?.stop();
    _ssoServer = null;
    setState(() {
      _autoSsoActive = false;
      _autoSsoFailed = true;
      _loading = false;
    });
  }

  Future<void> _doSsoComplete() async {
    final l10n = AppLocalizations.of(context)!;
    final String token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _error = l10n.pleasePasteToken);
      return;
    }
    await _completeTokenLogin(token);
  }

  Future<void> _doTokenLogin() async {
    final l10n = AppLocalizations.of(context)!;
    final String token = _tokenCtrl.text.trim();
    if (token.isEmpty) {
      setState(() => _error = l10n.pleaseEnterToken);
      return;
    }
    await _completeTokenLogin(token);
  }

  Future<void> _completeTokenLogin(String token) async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });

    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);
    final enc = context.read<EncryptionService>();

    // -- Invalidate any cached session data before a fresh login --
    await _clearCachedSession(client, enc, log);

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
        initialDeviceDisplayName: 'Moonrelay',
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
          setState(() {
            _statusMessage = l10n.syncingYourAccount;
            _loading = false;
            _syncing = true;
          });

          // -- Enable encryption now that we're logged in ----------
          // Capture all provider reads before any await so the analyzer
          // doesn't see [context] used across the async gap.
          final encryptionService = context.read<EncryptionService>();
          final accountManager = context.read<AccountManager>();
          final homeserverSnapshot = client.homeserver?.toString() ?? '';
          final userIdSnapshot = client.userID!;
          await encryptionService.init();

          // -- Save this account for multi-account support ---------
          await accountManager.addOrUpdateAccount(
            StoredAccount(
              userId: userIdSnapshot,
              homeserver: homeserverSnapshot,
            ),
            client: client,
            encryptionService: encryptionService,
          );

          final syncResult = await _waitForInitialSync(client, log);

          if (!mounted) return;

          if (syncResult) {
            context.go('/main/rooms');
          } else {
            log.w('Initial sync not yet complete, proceeding to rooms');
            context.go('/main/rooms');
          }
        }
      case RetryFailed(:final error, :final attempts):
        {
          log.e('Token login failed after $attempts attempt(s)', error: error);
          setState(() => _error = error is TimeoutException
              ? l10n.loginTimedOut
              : l10n.tokenLoginFailed('$error'));
          if (mounted) setState(() => _loading = false);
        }
    }
  }
}

/// Thrown when the automatic SSO flow fails, so the caller can fall back
/// to the manual token-paste flow.
class SsoAutomaticException implements Exception {
  SsoAutomaticException(this.message);
  final String message;

  @override
  String toString() => 'SsoAutomaticException: $message';
}
