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
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/helpers/login_errors.dart';
import 'package:moonrelay/src/helpers/post_login.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';
import 'package:moonrelay/src/widgets/auth_surface.dart';
import 'package:moonrelay/src/widgets/form_keyboard.dart';

/// In-client registration page for creating a new Matrix account.
///
/// Provides a form with homeserver, username, password, and password
/// confirmation fields. Supports checking username availability and
/// handles the full registration flow including user-interactive auth
/// when required.
class RegisterInClientPage extends StatefulWidget {
  const RegisterInClientPage({super.key});

  @override
  State<RegisterInClientPage> createState() => _RegisterInClientPageState();
}

class _RegisterInClientPageState extends State<RegisterInClientPage> {
  final TextEditingController _homeserverCtrl =
      TextEditingController(text: 'matrix.org');
  final TextEditingController _usernameCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmPasswordCtrl = TextEditingController();

  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _agreeToTerms = false;
  String? _error;
  String? _usernameError;

  final FocusNode _homeserverFocus = FocusNode(debugLabel: 'homeserver');
  final FocusNode _usernameFocus = FocusNode(debugLabel: 'username');
  final FocusNode _passwordFocus = FocusNode(debugLabel: 'password');
  final FocusNode _confirmPasswordFocus =
      FocusNode(debugLabel: 'confirmPassword');

  /// The register form's fields are always all four, so the order is fixed
  /// and Enter on the last one submits.
  final FormFieldOrder _fieldOrder = FormFieldOrder();

  @override
  void dispose() {
    _homeserverFocus.dispose();
    _usernameFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _homeserverCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = MoonrelayThemeExtension.of(context).tokens;

    _fieldOrder.nodes = <FocusNode>[
      _homeserverFocus,
      _usernameFocus,
      _passwordFocus,
      _confirmPasswordFocus,
    ];

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: FormKeyboard(
        onSubmit: _doRegister,
        enabled: !_loading,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: t.spaceXl,
              vertical: t.spaceXl,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: kAuthFormWidth),
                // The same `AuthCard` the sign-in form uses. This was a Material
                // `Card` with `elevation: 2`, which renders from
                // `kElevationToShadow`, a hardcoded black map no theme field
                // reaches, so on the dark ramp the register form had no elevation
                // at all while the sign-in form beside it had a real shadow. Two
                // forms, one journey, two different materials.
                child: AuthCard(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: <Widget>[
                      AuthCardHeader(
                        title: l10n.registerTitle,
                        onBack: () => context.pop(),
                        backTooltip: l10n.back,
                      ),
                      const SizedBox(height: 24),

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
                          onLast: _doRegister,
                        ),
                        autofillHints: const <String>[AutofillHints.url],
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 16),

                      AuthField(
                        caption: l10n.usernameText,
                        controller: _usernameCtrl,
                        focusNode: _usernameFocus,
                        hintText: l10n.registerUsernameHint,
                        icon: LucideIcons.user,
                        errorText: _usernameError,
                        textInputAction: _fieldOrder.getActionAt(1),
                        onSubmitted: _fieldOrder.submittedAt(
                          1,
                          onLast: _doRegister,
                        ),
                        autofillHints: const <String>[
                          AutofillHints.newUsername,
                        ],
                        enabled: !_loading,
                        onChanged: (_) {
                          // Clearing the message the moment the user starts
                          // fixing it is the difference between a form that is
                          // helping and one that is nagging.
                          if (_usernameError != null) {
                            setState(() => _usernameError = null);
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      AuthField(
                        caption: l10n.passwordText,
                        controller: _passwordCtrl,
                        focusNode: _passwordFocus,
                        obscureText: _obscurePassword,
                        icon: LucideIcons.lock,
                        suffix: _RevealToggle(
                          revealed: !_obscurePassword,
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        textInputAction: _fieldOrder.getActionAt(2),
                        onSubmitted: _fieldOrder.submittedAt(
                          2,
                          onLast: _doRegister,
                        ),
                        autofillHints: const <String>[
                          AutofillHints.newPassword,
                        ],
                        enabled: !_loading,
                      ),
                      const SizedBox(height: 16),

                      AuthField(
                        caption: l10n.confirmPasswordLabel,
                        controller: _confirmPasswordCtrl,
                        focusNode: _confirmPasswordFocus,
                        obscureText: _obscureConfirm,
                        icon: LucideIcons.lock,
                        suffix: _RevealToggle(
                          revealed: !_obscureConfirm,
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                        // Deliberately not `AutofillHints.newPassword`: a
                        // password manager filling the confirmation field would
                        // defeat the one thing the confirmation field is for.
                        textInputAction: _fieldOrder.getActionAt(3),
                        onSubmitted: _fieldOrder.submittedAt(
                          3,
                          onLast: _doRegister,
                        ),
                        enabled: !_loading,
                      ),

                      const SizedBox(height: 20),

                      // Laid out rather than borrowed. `CheckboxListTile` brings
                      // the list's own 48px minimum height and its own padding,
                      // so the consent row was a 56px band with a small box in
                      // it, and it did not match the gap rhythm of the four
                      // fields above it.
                      _ConsentRow(
                        label: l10n.agreeToTerms,
                        value: _agreeToTerms,
                        enabled: !_loading,
                        onChanged: (bool? v) => setState(() {
                          _agreeToTerms = v ?? false;
                          // Ticking the box is the user telling us they have
                          // dealt with whatever the notice is complaining about.
                          // Leaving the complaint up after they have answered it
                          // is the form arguing with a question already settled,
                          // and it is the same reason the username field clears
                          // its error on the first keystroke.
                          if (_error != null &&
                              _error == l10n.mustAgreeToTerms) {
                            _error = null;
                          }
                        }),
                      ),

                      const SizedBox(height: 20),

                      AuthButton(
                        label: _loading
                            ? l10n.creatingAccount
                            : l10n.createAccount,
                        icon: LucideIcons.userPlus,
                        busy: _loading,
                        onPressed: _loading ? null : _doRegister,
                      ),

                      const SizedBox(height: 12),

                      AuthLinks(
                        links: <(String, VoidCallback)>[
                          (
                            l10n.alreadyHaveAccount,
                            () => context.push('/welcome/login'),
                          ),
                        ],
                      ),
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

  // -- Registration logic ------------------------------------------------

  String? _validateForm() {
    final l10n = AppLocalizations.of(context)!;
    final String username = _usernameCtrl.text.trim();
    final String password = _passwordCtrl.text;
    final String confirm = _confirmPasswordCtrl.text;

    if (username.isEmpty) return l10n.usernameRequired;
    if (username.contains('@')) {
      return l10n.usernameNoAt;
    }
    if (username.length < 3) {
      return l10n.usernameTooShort;
    }
    if (password.isEmpty) return l10n.passwordRequired;
    if (password.length < 8) {
      return l10n.passwordTooShort;
    }
    if (password != confirm) return l10n.passwordsDoNotMatch;
    if (!_agreeToTerms) {
      return l10n.mustAgreeToTerms;
    }
    return null; // valid
  }

  Future<void> _doRegister() async {
    final l10n = AppLocalizations.of(context)!;
    final String? validationError = _validateForm();
    if (validationError != null) {
      setState(() => _error = validationError);
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    final Client client = Provider.of<Client>(context, listen: false);
    final Logger log = Provider.of<Logger>(context, listen: false);

    final String hs = _homeserverCtrl.text.trim();
    final Uri homeserverUri =
        hs.contains('://') ? Uri.parse(hs) : Uri.https(hs, '');

    final hsResult = await withRetry(
      () => client.checkHomeserver(homeserverUri, checkWellKnown: true),
      maxRetries: 1,
      timeout: kLoginTimeout,
      log: log,
      label: 'registerCheckHS',
    );

    if (hsResult case RetryFailed(:final error)) {
      if (!mounted) return;
      setState(() {
        _error = error is TimeoutException
            ? l10n.registerHomeserverTimeout
            : l10n.registerHomeserverError('$error');
        _loading = false;
      });
      return;
    }

    final regResult = await withRetry(
      () => client.register(
        username: _usernameCtrl.text.trim(),
        password: _passwordCtrl.text,
      ),
      maxRetries: 1,
      timeout: kLoginTimeout,
      log: log,
      label: 'register',
      retryOnAllErrors: true,
    );

    if (!mounted) return;

    switch (regResult) {
      case RetrySuccess(:final value):
        {
          log.i('Registration successful for ${value.userId}');
          await completeSignIn(context, client);
        }
      case RetryFailed(:final error):
        {
          if (error is MatrixException) {
            // Handle user-interactive authentication (e.g. terms of service)
            if (error.raw.containsKey('flows') &&
                error.raw.containsKey('session')) {
              setState(() {
                _error = l10n.registerRequiresAdditionalSteps;
                _loading = false;
              });
              return;
            }
            setState(() {
              _error = error.errorMessage;
              _loading = false;
            });
          } else {
            setState(() {
              _error = error is TimeoutException
                  ? l10n.registerTimedOut
                  : l10n.registerFailed(safeErrorMessage(error));
              _loading = false;
            });
          }
        }
    }
  }
}

/// The eye beside a password field.
///
/// Its own tiny widget because there are two of them and an inline
/// `IconButton` inside `InputDecoration.suffixIcon` is thirty lines each time.
/// It is an `IconButton` and not a `GestureDetector`, so it is reachable by Tab
/// and announces itself, which a bare detector does not.
class _RevealToggle extends StatelessWidget {
  const _RevealToggle({required this.revealed, required this.onPressed});

  final bool revealed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: Icon(
        revealed ? LucideIcons.eyeOff : LucideIcons.eye,
        size: t.iconSizeMedium,
      ),
      onPressed: onPressed,
      // It had no tooltip at all, so the control's purpose was carried by its
      // glyph alone, which is the one thing a glyph cannot do for a screen
      // reader.
      tooltip: revealed ? l10n.hidePassword : l10n.showPassword,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// The consent checkbox above the register button.
class _ConsentRow extends StatelessWidget {
  const _ConsentRow({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final t = MoonrelayThemeExtension.of(context).tokens;
    final scheme = Theme.of(context).colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        // A fixed width, so the label starts at the same x on every line of a
        // wrapped sentence rather than drifting with the box's own size.
        SizedBox(
          width: t.iconSizeLarge + t.spaceSm,
          child: Checkbox(
            value: value,
            onChanged: enabled ? onChanged : null,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: enabled
                  ? scheme.onSurfaceVariant
                  : scheme.onSurfaceVariant
                      .withValues(alpha: t.opacityDisabled),
            ),
          ),
        ),
      ],
    );
  }
}
