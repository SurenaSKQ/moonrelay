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
import 'package:moonrelay/src/encryption/encryption_service.dart';
import 'package:moonrelay/src/helpers/account_manager.dart';
import 'package:moonrelay/src/helpers/async_utils.dart';
import 'package:moonrelay/src/localization/app_localizations.dart';

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

  @override
  void dispose() {
    _homeserverCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                        tooltip: l10n.back,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        l10n.registerTitle,
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
                  _buildLabel(colors, l10n.homeserverText),
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

                  // ── Username field ──
                  _buildLabel(colors, l10n.usernameText),
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
                      errorText: _usernameError,
                    ),
                    style: const TextStyle(fontSize: 14),
                    enabled: !_loading,
                    onChanged: (_) {
                      if (_usernameError != null) {
                        setState(() => _usernameError = null);
                      }
                    },
                  ),
                  const SizedBox(height: 16),

                  // ── Password field ──
                  _buildLabel(colors, l10n.passwordText),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(LucideIcons.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          size: 18,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
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

                  // ── Confirm Password field ──
                  _buildLabel(colors, l10n.confirmPasswordLabel),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _confirmPasswordCtrl,
                    obscureText: _obscureConfirm,
                    decoration: InputDecoration(
                      hintText: '••••••••',
                      prefixIcon: const Icon(LucideIcons.lock, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureConfirm
                              ? LucideIcons.eyeOff
                              : LucideIcons.eye,
                          size: 18,
                        ),
                        onPressed: () =>
                            setState(() => _obscureConfirm = !_obscureConfirm),
                      ),
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

                  // ── Terms of service checkbox ──
                  CheckboxListTile(
                    value: _agreeToTerms,
                    onChanged: !_loading
                        ? (v) => setState(() => _agreeToTerms = v ?? false)
                        : null,
                    title: Text(
                      l10n.agreeToTerms,
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                  ),
                  const SizedBox(height: 20),

                  // ── Register button ──
                  FilledButton.icon(
                    onPressed: _loading ? null : _doRegister,
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(LucideIcons.userPlus, size: 18),
                    label: Text(
                        _loading ? l10n.creatingAccount : l10n.createAccount),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.center,
                    child: TextButton(
                      onPressed: _loading
                          ? null
                          : () => context.push('/welcome/login'),
                      child: Text(
                        l10n.alreadyHaveAccount,
                        style: const TextStyle(fontSize: 13),
                      ),
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

  // ── Registration logic ────────────────────────────────────────────────

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

          // ── Save this account for multi-account support ─────────
          if (mounted) {
            final accountManager = context.read<AccountManager>();
            await accountManager.addOrUpdateAccount(
              StoredAccount(
                userId: client.userID!,
                homeserver: client.homeserver?.toString() ?? '',
              ),
              client: client,
              encryptionService: context.read<EncryptionService>(),
            );
          }

          context.go('/main/rooms');
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
                  : l10n.registerFailed('$error');
              _loading = false;
            });
          }
        }
    }
  }
}
