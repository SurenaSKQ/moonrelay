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

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:moonrelay/src/theme/design_tokens.dart';
import 'package:moonrelay/src/theme/moonrelay_theme_extension.dart';

/// Full-screen splash shown while the application initialises.
///
/// This widget is shown as the `home` of a single MaterialApp before
/// the main [MoonrelayApp] is swapped in.  It shows a progress spinner
/// with a status message and, when [_status] is `null`, the building
/// animation.
///
/// The splash also handles the error state: when [_done] is `false`,
/// it shows a descriptive error with an Exit button.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  SplashScreenState createState() => SplashScreenState();
}

class SplashScreenState extends State<SplashScreen> {
  /// `null` → still running; `true` → success; `false` → error.
  bool? _done;

  /// Status message shown under the spinner.
  String _status = 'Starting…';

  String _errorTitle = '';
  String _errorBody = '';

  /// `true` once the local init pipeline finishes but the first
  /// Matrix sync has not delivered any rooms yet.  We keep the splash
  /// visible during this window so the user does not see an empty
  /// rooms pane flicker in and out as the first sync lands.
  bool _waitingForFirstSync = false;

  /// Called by [main] to kick off the init pipeline.
  ///
  /// Must be called exactly once, after the widget tree has been built.
  Future<void> start() async {
    // The actual init logic lives outside this widget so we can keep
    // the widget tree lean.  main.dart calls back into us to update
    // the UI.
    setState(() {
      _done = null;
      _status = 'Starting…';
      _waitingForFirstSync = false;
    });
  }

  /// Update the status message (called from the init pipeline in main).
  void updateStatus(String msg) {
    if (mounted) setState(() => _status = msg);
  }

  /// Signal that init succeeded (called from the init pipeline in main).
  void markDone() {
    if (mounted) {
      setState(() {
        _done = true;
        // If we are swapping in the main app, do not flip the
        // "waiting for sync" flag; the splash will be torn down
        // almost immediately.  This branch is for the rare case
        // where we want to keep showing the splash until the first
        // sync arrives.
        _waitingForFirstSync = false;
      });
    }
  }

  /// Signal that init succeeded and we are now waiting for the first
  /// Matrix sync.  The splash stays visible until [markDone] is
  /// called, preventing an empty rooms pane from flashing on screen.
  void markWaitingForSync() {
    if (mounted) {
      setState(() {
        _done = true;
        _waitingForFirstSync = true;
        _status = 'Fetching your rooms and messages…';
      });
    }
  }

  /// True while the splash is still waiting for the first sync.
  bool get waitingForFirstSync => _waitingForFirstSync;

  /// Signal that init failed (called from the init pipeline in main).
  void markError(String title, String body) {
    if (mounted) {
      setState(() {
        _done = false;
        _errorTitle = title;
        _errorBody = body;
      });
    }
  }

  // ── Build ───────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = MoonrelayThemeExtension.of(context).tokens;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: _done == false
            ? _buildError(scheme, t)
            : _buildLoading(scheme, t),
      ),
    );
  }

  Widget _buildLoading(ColorScheme scheme, MoonrelayDesignTokens t) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(LucideIcons.moon, size: 64, color: scheme.primary),
        SizedBox(height: t.spaceXxl),
        SizedBox(
          width: t.spaceXl,
          height: t.spaceXl,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          _status,
          style: TextStyle(
            fontSize: 15,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildError(ColorScheme scheme, MoonrelayDesignTokens t) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.spaceXxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.alertOctagon, size: 56, color: scheme.error),
          SizedBox(height: t.spaceXl),
          Text(
            _errorTitle,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: t.spaceMd),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SelectableText(
              _errorBody,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurfaceVariant,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 36),
          FilledButton.icon(
            onPressed: () => exit(0),
            icon: const Icon(LucideIcons.logOut, size: 18),
            label: const Text('Exit'),
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
            ),
          ),
        ],
      ),
    );
  }
}
