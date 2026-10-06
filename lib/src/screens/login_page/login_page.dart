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
import 'package:moonrelay/src/widgets/auth_surface.dart';
import 'package:moonrelay/src/widgets/moonrelay_mark.dart';
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

    // -- Full-screen syncing state after successful login --------------
    if (_syncing) {
      return _buildSyncingScreen(l10n);
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
            padding: EdgeInsets.symmetric(
              horizontal: MoonrelayThemeExtension.of(context).tokens.spaceXl,
              vertical: MoonrelayThemeExtension.of(context).tokens.spaceXl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kAuthFormWidth),
                // The raised card, from `auth_surface.dart`. It used to be a
                // decorated `Container` written out here, with a comment
                // explaining at length why the shadow is right here; the
                // explanation belongs with the primitive now that three screens
                // share it, and the register form gets the same card for free
                // instead of a Material `Card` whose elevation renders from a
                // hardcoded black map and is invisible on the dark ramp.
                child: AuthCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AuthCardHeader(
                        title: switch (_mode) {
                          LoginMode.sso => l10n.ssoTitle,
                          LoginMode.token => l10n.tokenLoginTitle,
                          LoginMode.password => l10n.signInTitle,
                        },
                        onBack: () => context.pop(),
                        backTooltip: l10n.cancel,
                      ),
                      const SizedBox(height: 24),

                      // A failure the user has to read, not a decoration.
                      if (_error != null) ...<Widget>[
                        AuthNotice(
                          message: _error!,
                          icon: LucideIcons.alertCircle,
                        ),
                        const SizedBox(height: 16),
                      ],

                      AuthField(
                        caption: l10n.homeserverText,
                        controller: _homeserverCtrl,
                        focusNode: _homeserverFocus,
                        hintText: l10n.registerHomeserverHint,
                        icon: LucideIcons.server,
                        textInputAction: _fieldOrder.getActionAt(0),
                        onSubmitted: _fieldOrder.submittedAt(
                          0,
                          onLast: _submitCurrentMode,
                        ),
                        autofillHints: const <String>[AutofillHints.url],
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 16),

                      if (_mode == LoginMode.sso) ..._buildSsoSection(l10n),

                      if (_ssoStep.isAwaitingCallback)
                        const SsoAwaitingBanner(),

                      if (_mode == LoginMode.token) ..._buildTokenSection(l10n),

                      if (_mode.showsCredentialFields)
                        ..._buildPasswordSection(l10n),

                      const SizedBox(height: 24),

                      if (_ssoStep.isAwaitingCallback)
                        SsoSwitchToManualButton(onPressed: _cancelAutoSso)
                      else
                        ..._buildPrimaryActions(l10n),

                      if (!_loading && !_ssoStep.isAwaitingCallback) ...[
                        const SizedBox(height: 12),
                        _buildModeLinks(l10n),
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

  /// The screen between a successful sign-in and the dashboard.
  ///
  /// The one screen in this segment that is not a form, and it had none of the
  /// form's structure: no card, no padding from the ramp, a moon glyph from the
  /// icon set rather than the brand mark, a 22pt bold heading where every other
  /// heading in the app is 18 or 20 at w600, and `0.7` alpha over
  /// `onSurfaceVariant` instead of the muted token. So the moment a user reaches
  /// after doing the hard thing looked like a different application.
  ///
  /// It is a card now like the forms were, because it is the same window and the
  /// same job: say what is happening until something else takes over.
  Widget _buildSyncingScreen(AppLocalizations l10n) {
    final ext = MoonrelayThemeExtension.of(context);
    final t = ext.tokens;
    final scheme = Theme.of(context).colorScheme;
    final display = Theme.of(context).textTheme.titleMedium?.fontFamily;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(t.spaceXl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: kAuthFormWidth),
            child: AuthCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  // The real mark, in the accent, the same as the lockup on the
                  // welcome screen. Coming from the form to this and finding a
                  // different glyph is the kind of thing a person notices
                  // without being able to say what.
                  MoonrelayMark(size: 48, color: scheme.primary),
                  SizedBox(height: t.spaceXl),
                  Text(
                    l10n.welcomeToApp,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: display,
                      fontSize: 20,
                      height: 1.2,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: t.spaceLg),
                  SizedBox(
                    width: t.iconSizeLarge,
                    height: t.iconSizeLarge,
                    child: CircularProgressIndicator(
                      strokeWidth: t.borderWidthThick,
                      color: scheme.primary,
                    ),
                  ),
                  SizedBox(height: t.spaceLg),
                  Text(
                    _statusMessage ?? l10n.loading,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: scheme.onSurface,
                    ),
                  ),
                  SizedBox(height: t.spaceXs),
                  Text(
                    l10n.fetchingRooms,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // -- Build helpers -----------------------------------------------------

  /// The links that move away from the current mode.
  ///
  /// A `Wrap` rather than a column, because two of them fit on one line and one
  /// alone was centred in a stack that looked like it had lost an item.
  Widget _buildModeLinks(AppLocalizations l10n) {
    return AuthLinks(
      links: switch (_mode) {
        LoginMode.password => <(String, VoidCallback)>[
            (
              l10n.useSsoInstead,
              () => setState(() {
                    _mode = LoginMode.sso;
                    _ssoStep = SsoStep.idle;
                  }),
            ),
            (
              l10n.useTokenInstead,
              () => setState(() => _mode = LoginMode.token),
            ),
          ],
        LoginMode.sso => <(String, VoidCallback)>[
            (
              l10n.usePasswordInstead,
              () => setState(() => _mode = LoginMode.password),
            ),
          ],
        LoginMode.token => <(String, VoidCallback)>[
            (
              l10n.backToPasswordLogin,
              () => setState(() => _mode = LoginMode.password),
            ),
          ],
      },
    );
  }

  /// The username and password, as two [AuthField]s.
  ///
  /// The gap between them is 16 and the gap between the homeserver and the
  /// username is also 16, because they are one column of inputs rather than two
  /// groups. It used to be 20 in one place and 16 in the other, which drew a
  /// rule between the homeserver and the username that nothing else on the
  /// screen agreed with.
  List<Widget> _buildPasswordSection(AppLocalizations l10n) {
    return <Widget>[
      AuthField(
        caption: l10n.usernameOrEmail,
        controller: _usernameCtrl,
        focusNode: _usernameFocus,
        hintText: l10n.usernameHint,
        icon: LucideIcons.user,
        textInputAction: _fieldOrder.getActionAt(1),
        onSubmitted: _fieldOrder.submittedAt(
          1,
          onLast: _submitCurrentMode,
        ),
        autofillHints: const <String>[AutofillHints.username],
        enabled: !_loading,
      ),
      const SizedBox(height: 16),
      AuthField(
        caption: l10n.passwordText,
        controller: _passwordCtrl,
        focusNode: _passwordFocus,
        obscureText: true,
        icon: LucideIcons.lock,
        textInputAction: _fieldOrder.getActionAt(2),
        onSubmitted: _fieldOrder.submittedAt(
          2,
          onLast: _submitCurrentMode,
        ),
        autofillHints: const <String>[AutofillHints.password],
        enabled: !_loading,
      ),
    ];
  }

  List<Widget> _buildSsoSection(AppLocalizations l10n) {
    return <Widget>[
      SsoUrlDisplay(url: _ssoUrl),
      // Why the automatic flow stopped, so the manual fallback is not a
      // dead end the user has to guess their way out of.
      if (_ssoStep.showsFailureNotice) const SsoFailureNotice(),
      // Token field: only shown when the user explicitly requests it.
      if (_ssoStep.showsManualTokenEntry) ..._buildManualTokenEntry(l10n),
    ];
  }

  /// The manual token-paste field, hidden behind a toggle by default.
  ///
  /// Shares the field with the token mode, because it is the same field reading
  /// the same controller; only the caption differs, to say the token is pasted
  /// after the browser round trip. That difference used to be an English
  /// suffix concatenated onto a localized label, so a Persian user saw a
  /// Persian label followed by `(paste after authenticating)`.
  List<Widget> _buildManualTokenEntry(AppLocalizations l10n) {
    return <Widget>[
      const SizedBox(height: 16),
      AuthField(
        caption: l10n.tokenPasteAfterAuthLabel,
        controller: _tokenCtrl,
        focusNode: _tokenFocus,
        hintText: l10n.tokenHint,
        icon: LucideIcons.key,
        textInputAction: _fieldOrder.getActionAt(1),
        onSubmitted: _fieldOrder.submittedAt(
          1,
          onLast: _submitCurrentMode,
        ),
        enabled: !_loading,
      ),
    ];
  }

  List<Widget> _buildTokenSection(AppLocalizations l10n) {
    return <Widget>[
      AuthField(
        caption: l10n.tokenLabel,
        controller: _tokenCtrl,
        focusNode: _tokenFocus,
        hintText: l10n.tokenPasteHint,
        icon: LucideIcons.key,
        textInputAction: _fieldOrder.getActionAt(1),
        onSubmitted: _fieldOrder.submittedAt(
          1,
          onLast: _submitCurrentMode,
        ),
        enabled: !_loading,
      ),
    ];
  }

  /// Everything the current mode offers as its way forward.
  ///
  /// A list because SSO shows two controls at once, one before the browser
  /// round trip and one after it. It used to build its own `Column` for that and
  /// a single button for the other two modes, so the three modes had three
  /// different shapes of action area and three different button radii.
  List<Widget> _buildPrimaryActions(AppLocalizations l10n) {
    switch (_mode) {
      case LoginMode.password:
        return <Widget>[
          AuthButton(
            label: _loading ? l10n.signingIn : l10n.loginButton,
            icon: LucideIcons.logIn,
            busy: _loading,
            onPressed: _loading ? null : _doPasswordLogin,
          ),
        ];
      case LoginMode.token:
        return <Widget>[
          AuthButton(
            label: _loading ? l10n.signingIn : l10n.signInWithToken,
            icon: LucideIcons.key,
            busy: _loading,
            onPressed: _loading ? null : _doTokenLogin,
          ),
        ];
      case LoginMode.sso:
        return <Widget>[
          AuthButton(
            label: _loading ? l10n.preparing : l10n.openInBrowser,
            icon: LucideIcons.externalLink,
            busy: _loading,
            filled: false,
            onPressed: _loading ? null : _doSsoOpenBrowser,
          ),
          const SizedBox(height: 12),
          // Before the round trip: a way to get the token without a browser.
          // After it: the only way forward.
          if (!_ssoStep.showsManualTokenEntry)
            AuthButton(
              label: l10n.ssoPasteManually,
              icon: LucideIcons.key,
              filled: false,
              onPressed: () =>
                  setState(() => _ssoStep = SsoStep.manualTokenEntry),
            )
          else
            AuthButton(
              label: l10n.completeLogin,
              icon: LucideIcons.check,
              onPressed: _loading ? null : _doSsoComplete,
            ),
        ];
    }
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

    if (unsupportedMessage != null && !flows.any((f) => f.type == type)) {
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
        log.e(
            '$label failed after $attempts attempt(s) (${error.runtimeType})');
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
