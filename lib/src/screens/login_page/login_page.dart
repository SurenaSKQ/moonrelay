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
import 'package:moonrelay/src/helpers/homeserver_url.dart';
import 'package:moonrelay/src/helpers/login_errors.dart';
import 'package:moonrelay/src/helpers/post_login.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/screens/login_page/login_mode.dart';
import 'package:moonrelay/src/screens/login_page/sso_token_capture.dart';
import 'package:moonrelay/src/screens/login_page/sso_widgets.dart';
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/form_field_label.dart';
import 'package:moonrelay/src/widgets/form_keyboard.dart';

/// Login page with password and SSO support.
///
/// This page discovers the homeserver's supported login flows and presents
/// the appropriate authentication options:
/// - Password login with homeserver, username, and password fields
/// - SSO login that automatically captures the token via a local HTTP
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

  final FocusNode _homeserverFocus = FocusNode(debugLabel: 'homeserver');
  final FocusNode _usernameFocus = FocusNode(debugLabel: 'username');
  final FocusNode _passwordFocus = FocusNode(debugLabel: 'password');
  final FocusNode _tokenFocus = FocusNode(debugLabel: 'token');

  /// The text fields currently on screen, in the order Tab and Enter walk
  /// them. Reassigned on every build, because the mode decides which fields
  /// exist.
  final FormFieldOrder _fieldOrder = FormFieldOrder();

  bool _loading = false;
  bool _syncing = false;

  /// Which sign-in form is showing.
  LoginMode _mode = LoginMode.password;

  /// Where the user is inside the SSO sub-flow.
  SsoStep _ssoStep = SsoStep.idle;

  /// Runs the automatic half of SSO: the local server that catches the
  /// browser redirect and hands back a token.
  ///
  /// Built in [initState] rather than as a field initializer because it
  /// needs a [Logger] from the provider tree, which does not exist yet when
  /// field initializers run.
  late final SsoTokenCapture _ssoCapture;

  @override
  void initState() {
    super.initState();
    _ssoCapture = SsoTokenCapture(log: context.read<Logger>());
  }

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
          _mode = LoginMode.sso;
          _ssoStep = SsoStep.idle;
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
    _ssoCapture.dispose();
    _homeserverFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _tokenFocus.dispose();
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
    final layers = MoonrelayThemeExtension.of(context).layers;

    // -- Full-screen syncing state after successful login --------------
    if (_syncing) {
      return _buildSyncingScreen(colors, theme, l10n);
    }

    // The field order is recomputed here because the mode decides which
    // fields are on screen: password shows username and password, the token
    // mode shows a token field, and the SSO manual fallback shows the same
    // token field. Enter advances through whichever of them are visible, so
    // the last one it reaches is the one that submits.
    _fieldOrder.nodes = switch (_mode) {
      LoginMode.password => [_homeserverFocus, _usernameFocus, _passwordFocus],
      LoginMode.sso || LoginMode.token => [
          _homeserverFocus,
          if (_ssoStep.showsManualTokenEntry) _tokenFocus,
        ],
    };

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FormKeyboard(
        onSubmit: _submitCurrentMode,
        enabled: !_loading && !_ssoStep.isAwaitingCallback,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              // A raised card with a hard shadow, on the app floor.
              //
              // This is the one place in the app where a shadow is the right
              // answer rather than a leftover: there is nothing else on
              // screen. The window is the page, so something has to say
              // "this is the form and that is the background", and on a flat
              // surface ramp a fill alone does not say it.
              //
              // It takes the shadow directly rather than `elevation:`,
              // because Material renders `elevation:` from a hardcoded black
              // map that no theme field reaches, and on a dark surface that
              // map is invisible. `shadowHigh` has a light rim, which does
              // show.
              child: Container(
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(t.radiusLg),
                  border: Border.all(color: layers.hairline),
                  boxShadow: t.shadowHigh,
                ),
                child: Padding(
                  padding: EdgeInsets.all(t.spaceXxl),
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
                            _mode == LoginMode.sso
                                ? l10n.ssoTitle
                                : _mode == LoginMode.token
                                    ? l10n.tokenLoginTitle
                                    : l10n.signInTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: t.spaceXl),

                      // Error banner
                      if (_error != null)
                        Padding(
                          padding: EdgeInsets.only(bottom: t.spaceLg),
                          child: Container(
                            padding: EdgeInsets.all(t.spaceMd),
                            decoration: BoxDecoration(
                              color: colors.errorContainer,
                              borderRadius:
                                  BorderRadius.circular(t.radiusMd),
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
                      buildFormFieldLabel(context, l10n.homeserverText),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _homeserverCtrl,
                        focusNode: _homeserverFocus,
                        textInputAction: _fieldOrder.getActionAt(0),
                        onSubmitted: _fieldOrder.submittedAt(
                          0,
                          onLast: _submitCurrentMode,
                        ),
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
                      if (_mode == LoginMode.sso)
                        ..._buildSsoSection(colors, l10n),

                      // -- Auto-SSO status (shown during automatic flow) --
                      if (_ssoStep.isAwaitingCallback)
                        ..._buildAutoSsoStatus(colors, l10n),

                      // -- Token mode --
                      if (_mode == LoginMode.token)
                        ..._buildTokenSection(colors, l10n),

                      // -- Password mode --
                      if (_mode.showsCredentialFields)
                        ..._buildPasswordSection(colors, l10n),

                      SizedBox(height: t.spaceXl),

                      // -- Primary action button --
                      if (_ssoStep.isAwaitingCallback)
                        _buildAutoSsoActionButton(colors, l10n)
                      else
                        switch (_mode) {
                          LoginMode.sso => _buildSsoActionButton(colors, l10n),
                          LoginMode.token =>
                            _buildTokenActionButton(colors, l10n),
                          LoginMode.password =>
                            _buildPasswordActionButton(colors, l10n),
                        },

                      // -- Mode switcher --
                      if (!_loading && !_ssoStep.isAwaitingCallback) ...[
                        SizedBox(height: t.spaceMd),
                        ..._buildModeLinks(l10n),
                      ],
                    ],
                  ),
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

  /// The action Enter triggers from the last visible field, and what the
  /// form-wide Enter shortcut runs when focus is not in a field.
  ///
  /// This is the same action the primary button performs, which is the
  /// point: keyboard-only sign-in has to reach the password request, the
  /// token request, and the SSO browser handoff, and each of those modes
  /// shows a different set of fields.
  void _submitCurrentMode() {
    switch (_mode) {
      case LoginMode.password:
        _doPasswordLogin();
      case LoginMode.token:
        _doTokenLogin();
      case LoginMode.sso:
        // The manual fallback pastes a token and completes, which is the
        // token request. Without this branch, Enter would open a browser
        // the user has already just come back from.
        if (_ssoStep.showsManualTokenEntry) {
          _doSsoComplete();
        } else {
          _doSsoOpenBrowser();
        }
    }
  }

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
      buildFormFieldLabel(context, l10n.usernameOrEmail),
      const SizedBox(height: 6),
      TextField(
        controller: _usernameCtrl,
        focusNode: _usernameFocus,
        textInputAction: _fieldOrder.getActionAt(1),
        onSubmitted: _fieldOrder.submittedAt(
          1,
          onLast: _submitCurrentMode,
        ),
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
      buildFormFieldLabel(context, l10n.passwordText),
      const SizedBox(height: 6),
      TextField(
        controller: _passwordCtrl,
        focusNode: _passwordFocus,
        obscureText: true,
        textInputAction: _fieldOrder.getActionAt(2),
        onSubmitted: _fieldOrder.submittedAt(
          2,
          onLast: _submitCurrentMode,
        ),
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
      const SsoAwaitingBanner(),
    ];
  }

  /// Builds the cancel / switch-to-manual button during automatic SSO.
  Widget _buildAutoSsoActionButton(ColorScheme colors, AppLocalizations l10n) {
    return SsoSwitchToManualButton(onPressed: _cancelAutoSso);
  }

  /// The links that move away from the current mode.
  ///
  /// Two of them sit side by side in password mode and only one fits in the
  /// other two, so this returns a list rather than a single widget.
  List<Widget> _buildModeLinks(AppLocalizations l10n) {
    return switch (_mode) {
      LoginMode.password => [
          _buildModeLink(
            l10n.useSsoInstead,
            () => setState(() {
              _mode = LoginMode.sso;
              _ssoStep = SsoStep.idle;
            }),
          ),
          _buildModeLink(
            l10n.useTokenInstead,
            () => setState(() => _mode = LoginMode.token),
          ),
        ],
      LoginMode.sso => [
          _buildModeLink(
            l10n.usePasswordInstead,
            () => setState(() => _mode = LoginMode.password),
          ),
        ],
      LoginMode.token => [
          _buildModeLink(
            l10n.backToPasswordLogin,
            () => setState(() => _mode = LoginMode.password),
          ),
        ],
    };
  }

  List<Widget> _buildSsoSection(ColorScheme colors, AppLocalizations l10n) {
    return [
      SsoUrlDisplay(url: _ssoUrl),
      // Why the automatic flow stopped, so the manual fallback is not a
      // dead end the user has to guess their way out of.
      if (_ssoStep.showsFailureNotice) const SsoFailureNotice(),
      // Token field: only shown when the user explicitly requests it.
      if (_ssoStep.showsManualTokenEntry)
        ..._buildManualTokenEntry(colors, l10n),
    ];
  }

  /// Builds the manual token-paste field (hidden behind a toggle by default).
  ///
  /// Shares the field itself with the token mode, because it is the same
  /// field reading the same controller; only the surrounding label and hint
  /// differ, to say that the token is pasted after the browser round trip.
  List<Widget> _buildManualTokenEntry(
      ColorScheme colors, AppLocalizations l10n) {
    return [
      const SizedBox(height: 16),
      buildFormFieldLabel(context, '${l10n.tokenLabel} (paste after authenticating)'),
      const SizedBox(height: 6),
      _buildTokenField(l10n.tokenHint, 1),
    ];
  }

  List<Widget> _buildTokenSection(ColorScheme colors, AppLocalizations l10n) {
    return [
      buildFormFieldLabel(context, l10n.tokenLabel),
      const SizedBox(height: 6),
      _buildTokenField('Paste your login token here…', 1),
    ];
  }

  /// The access-token input, used by both the token mode and the SSO
  /// manual fallback.
  ///
  /// [index] is where this field sits in the visible order. It is 1 in both
  /// modes that show it, since the homeserver field is the only one above
  /// it either way, but it is passed in rather than assumed so the two call
  /// sites state it.
  Widget _buildTokenField(String hint, int index) {
    return TextField(
      controller: _tokenCtrl,
      focusNode: _tokenFocus,
      textInputAction: _fieldOrder.getActionAt(index),
      onSubmitted: _fieldOrder.submittedAt(index, onLast: _submitCurrentMode),
      decoration: InputDecoration(
        hintText: hint,
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
    );
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
        if (!_ssoStep.showsManualTokenEntry)
          OutlinedButton.icon(
            onPressed: () => setState(() => _ssoStep = SsoStep.manualTokenEntry),
            icon: const Icon(LucideIcons.key, size: 18),
            label: Text(l10n.ssoPasteManually),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        // -- Manual entry visible: show "Complete Login" --
        if (_ssoStep.showsManualTokenEntry)
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

  /// Everything that happens between a successful `client.login` and the
  /// rooms screen, for every login method.
  ///
  /// The shared part lives in `completeSignIn`. What stays here is the
  /// syncing screen, which the register page has no equivalent of: after a
  /// sign-in the SDK runs its first sync in the background, and showing a
  /// full-screen progress state beats landing on an empty room list.
  Future<void> _onLoginSucceeded(
    BuildContext context,
    Client client,
    Logger log,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    setState(() {
      _statusMessage = l10n.syncingYourAccount;
      _loading = false; // allow the build method to show _syncing UI
      _syncing = true;
    });

    await completeSignIn(
      context,
      client,
      beforeNavigate: () async {
        final synced = await _waitForInitialSync(client, log);
        if (!synced) {
          log.w('Initial sync not yet complete, proceeding to rooms');
        }
      },
    );

    if (!mounted) return;
    setState(() => _syncing = false);
  }

  /// The shared opening half of every sign-in request: clear the previous
  /// session, check the homeserver is reachable, and confirm it advertises
  /// [type].
  ///
  /// [type] is one of the `AuthenticationTypes` constants, which are plain
  /// strings: the SDK keys both [Client.supportedLoginTypes] and
  /// [LoginFlow.type] off them.
  ///
  /// Returns the parsed homeserver when the request may proceed, or null
  /// after having set [_error] and cleared [_loading]. Returning null rather
  /// than taking a callback keeps every caller's early return in the same
  /// place, which is what stopped the three copies from drifting.
  Future<Uri?> _prepareLoginRequest(
    String type, {
    String? unsupportedMessage,
  }) async {
    final l10n = AppLocalizations.of(context)!;

    final client = Provider.of<Client>(context, listen: false);
    final log = Provider.of<Logger>(context, listen: false);
    final enc = context.read<EncryptionService>();

    // Invalidate any cached session data before a fresh login, so the SDK
    // doesn't carry over a stale Olm account or device keys from a previous
    // session (an unclean shutdown, or a failed logout).
    await _clearCachedSession(client, enc, log);

    client.supportedLoginTypes.add(type);

    final Uri? homeserverUri = parseHomeserverInput(_homeserverCtrl.text);
    if (homeserverUri == null) {
      setState(() {
        _error = l10n.ssoHomeserverInvalid;
        _loading = false;
      });
      return null;
    }

    final List<LoginFlow>? flows =
        await _tryCheckHomeserver(client, homeserverUri);
    if (flows == null || !mounted) {
      if (mounted) setState(() => _loading = false);
      return null;
    }

    if (unsupportedMessage != null &&
        !flows.any((f) => f.type == type)) {
      setState(() {
        _error = unsupportedMessage;
        _loading = false;
      });
      return null;
    }

    return homeserverUri;
  }

  /// Runs [attempt] with the retry and failure handling every sign-in type
  /// needs, then hands a success to [_onLoginSucceeded].
  ///
  /// [messageFor] builds the user-facing text from a failure and must not
  /// embed the error: pass it through [safeErrorMessage], since
  /// `MatrixHttpException.toString()` echoes the request body and with it
  /// the typed password or the pasted token. The log line is built here
  /// rather than by the callers for the same reason, so that a new call
  /// site cannot accidentally attach the exception object.
  Future<void> _runLoginRequest({
    required String label,
    required Future<void> Function(Client client) attempt,
    required String Function(AppLocalizations l10n, Object error) messageFor,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    final client = Provider.of<Client>(context, listen: false);
    final log = Provider.of<Logger>(context, listen: false);

    final result = await withRetry(
      () => attempt(client),
      maxRetries: 1,
      timeout: kLoginTimeout,
      log: log,
      label: label,
      retryOnAllErrors: true, // login errors are often transient
    );

    if (!mounted) return;

    switch (result) {
      case RetrySuccess():
        await _onLoginSucceeded(context, client, log);
      case RetryFailed(:final error, :final attempts):
        // Log the class only. Attaching the error object would put the
        // request body in the log file via toString.
        log.e('$label failed after $attempts attempt(s) (${error.runtimeType})');
        setState(() => _error = error is TimeoutException
            ? l10n.loginTimedOut
            : messageFor(l10n, error));
        if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _doPasswordLogin() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final l10n = AppLocalizations.of(context)!;

    if (await _prepareLoginRequest(
          AuthenticationTypes.password,
          unsupportedMessage: l10n.passwordLoginNotSupported,
        ) ==
        null) {
      return;
    }

    await _runLoginRequest(
      label: 'passwordLogin',
      messageFor: (l10n, error) => l10n.loginFailed(safeErrorMessage(error)),
      attempt: (client) => client.login(
        LoginType.mLoginPassword,
        password: _passwordCtrl.text,
        identifier:
            AuthenticationUserIdentifier(user: _usernameCtrl.text.trim()),
        initialDeviceDisplayName: 'Moonrelay',
      ),
    );
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

  /// Attempts SSO login using the automatic (local server callback) flow.
  /// Falls back to the manual copy-paste flow if the automatic approach fails.
  ///
  /// Deliberately does not go through [_prepareLoginRequest], because the
  /// order matters here in a way it does not for the other two types: the
  /// phishing guard and the user's confirmation both have to happen before
  /// anything contacts the server, and `_prepareLoginRequest` checks the
  /// homeserver first. The token half still does, via
  /// [_completeTokenLogin], once a token has been obtained by hand.
  Future<void> _doSsoOpenBrowser() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _loading = true;
      _error = null;
    });

    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);

    client.supportedLoginTypes.add(AuthenticationTypes.sso);

    final Uri? homeserverUri = parseHomeserverInput(_homeserverCtrl.text);
    if (homeserverUri == null) {
      setState(() {
        _error = l10n.ssoHomeserverInvalid;
        _loading = false;
      });
      return;
    }

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
    setState(() {
      _ssoStep = SsoStep.awaitingCallback;
      _loading = false;
      _ssoUrl = null;
    });

    final SsoAttempt attempt = await _ssoCapture.captureToken(homeserverUri);
    if (!mounted) return;

    switch (attempt) {
      case SsoTokenReceived(:final token):
        setState(() => _statusMessage = l10n.ssoTokenDetected);
        setState(() {
          _ssoStep = SsoStep.idle;
          _loading = true;
        });
        await _completeTokenLogin(token);
        return;
      case SsoAbandoned():
        setState(() {
          _ssoStep = SsoStep.idle;
          _loading = false;
        });
        return;
      case SsoAutomaticFailed(:final reason):
        log.w('Automatic SSO failed: $reason');
    }

    // -- Fallback: manual copy-paste flow -----------------------
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
      _ssoStep = SsoStep.automaticFailed;
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

  /// Cancels the automatic SSO flow and switches to the manual fallback.
  Future<void> _cancelAutoSso() async {
    await _ssoCapture.cancel();
    if (!mounted) return;
    setState(() {
      _ssoStep = SsoStep.automaticFailed;
      _loading = false;
      _ssoUrl = _ssoCapture.destination?.toString();
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
    setState(() {
      _loading = true;
      _error = null;
    });

    if (await _prepareLoginRequest(AuthenticationTypes.token) == null) return;

    await _runLoginRequest(
      label: 'tokenLogin',
      messageFor: (l10n, error) => l10n.tokenLoginFailed(
        safeErrorMessage(error),
      ),
      attempt: (client) => client.login(
        LoginType.mLoginToken,
        token: token,
        initialDeviceDisplayName: 'Moonrelay',
      ),
    );
  }
}
