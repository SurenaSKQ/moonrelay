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

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:matrix/matrix.dart';
import 'package:moonrelay/src/helpers/matrix_uri_parser.dart';
import 'package:provider/provider.dart';

/// Handles incoming Matrix deep links (`matrix:` scheme and
/// `https://matrix.to/` URLs).
///
/// On desktop platforms this can process:
/// - Command-line arguments passed when the app is launched with a
///   registered protocol URL (e.g. `matrix:r/!roomid:domain`)
/// - URLs received via platform method channels from the native side
///
/// ## Platform registration
///
/// For the app to receive `matrix:` URIs, the protocol must be registered
/// at the OS level:
///
/// **Windows**: Add to the registry
/// ```
/// HKEY_CLASSES_ROOT\matrix\shell\open\command
///   (Default) = "path\to\moonrelay.exe" "%1"
/// HKEY_CLASSES_ROOT\MATRIX\URL Protocol
///   (Default) = ""
/// ```
///
/// **Linux**: Create or amend the `.desktop` file:
/// ```
/// MimeType=x-scheme-handler/matrix;
/// ```
///
/// **macOS**: Add `matrix` to `Info.plist` `CFBundleURLTypes`.
class DeepLinkService {
  DeepLinkService({
    required this.log,
  });

  final Logger log;

  /// The callback invoked when a matrix URI is received.
  /// The service processes the URI and passes the [MatrixUriResult] to this
  /// callback so the app can navigate accordingly.
  void Function(MatrixUriResult result)? onMatrixUri;

  /// Channel name for communicating with the native side.
  static const _channel = MethodChannel('moonrelay/deep_links');

  /// Initialises the service: listens for method channel calls from the
  /// native side and processes any command-line arguments.
  Future<void> init() async {
    // ── Listen for incoming deep links from the native side ─────
    _channel.setMethodCallHandler(_handleMethodCall);

    // ── Check command-line arguments for matrix: URIs ───────────
    // On Windows, when the app is registered as a protocol handler,
    // the OS launches the executable with the URL as the first argument.
    _processCommandLineArgs();

    log.i('DeepLinkService initialised');
  }

  /// Processes a matrix URI by parsing it and invoking the callback.
  ///
  /// Identical URIs delivered within [_dedupWindow] are coalesced so
  /// the OS-delivered duplicates (older Windows protocol handlers are
  /// known to call the executable twice) do not navigate twice.
  void processUri(String uri) {
    if (_isDuplicate(uri)) {
      log.d('Deep link suppressed as duplicate: $uri');
      return;
    }

    log.i('Processing deep link: $uri');
    final result = MatrixUriParser.parse(uri);
    if (result == null) {
      log.w('Unrecognised matrix URI: $uri');
      return;
    }

    onMatrixUri?.call(result);
  }

  /// Two delivery windows. OSes occasionally deliver the same protocol
  /// URI twice for the same launch; we suppress the duplicate.
  static const Duration _dedupWindow = Duration(milliseconds: 500);
  static String _lastUri = '';
  static DateTime _lastAt = DateTime.fromMillisecondsSinceEpoch(0);

  bool _isDuplicate(String uri) {
    final now = DateTime.now();
    final isDuplicate = uri == _lastUri &&
        now.difference(_lastAt) < _dedupWindow;
    _lastUri = uri;
    _lastAt = now;
    return isDuplicate;
  }

  /// Processes command-line arguments looking for `matrix:` URIs.
  ///
  /// The OS passes the deep-link URL as a positional argument when the
  /// registered protocol handler is invoked (Windows: as the trailing
  /// element of the command line; Linux: from `argv` exposed via
  /// [Platform.executableArguments]).  We do not rely on
  /// `Platform.environment` here — that only catches child-process env
  /// variables, not the arguments the app was launched with.
  void _processCommandLineArgs() {
    if (kIsWeb) return;
    try {
      // `Platform.executableArguments` covers the full argv in Flutter
      // 3.3+; on platforms that don't expose it (e.g. older Flutter
      // test mocks) we fall back to an empty list rather than reading
      // unrelated environment values.
      final List<String> args = _safeExecutableArgs();
      for (final arg in args) {
        final lower = arg.toLowerCase();
        if (lower.startsWith('matrix:') || lower.startsWith('matrix://')) {
          processUri(arg);
          return; // Process only the first relevant argument.
        }
      }
    } catch (e) {
      log.w('Could not read command-line arguments', error: e);
    }
  }

  /// Returns the OS-passed arguments for the current process, or an
  /// empty list when running on web or in a host that doesn't expose
  /// argv.
  ///
  /// Note: `Platform.executableArguments` is `@visibleForTesting` in
  /// the Flutter SDK. We still call it from production code because
  /// the alternative — losing command-line links on first launch — is
  /// a worse trade-off than the `@visibleForTesting` lint. Upstream
  /// has discussed promoting the field; track
  /// https://github.com/flutter/flutter/issues/142523.
  List<String> _safeExecutableArgs() {
    try {
      return Platform.executableArguments;
    } catch (_) {
      return const <String>[];
    }
  }

  /// Handles method channel calls from the native side. Anything that
  /// is not a string URI is logged and ignored, since the host-side
  /// contract is "always pass a string" and the previous code threw a
  /// `TypeError` on stray integer arguments.
  Future<void> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'openUri':
        if (call.arguments is String) {
          processUri(call.arguments as String);
        } else {
          log.w(
            'openUri: expected String argument, got ${call.arguments.runtimeType}',
          );
        }
        break;
      default:
        log.w('Unknown method: ${call.method}');
    }
  }

  /// Disposes the service, cleaning up the method channel handler.
  void dispose() {
    _channel.setMethodCallHandler(null);
  }
}

/// Navigates to a [MatrixUriResult] destination using [GoRouter] provided
/// via the context's provider tree.
///
/// Call this from the callback registered on [DeepLinkService.onMatrixUri].
void navigateToMatrixUri(
  BuildContext context,
  MatrixUriResult result,
) {
  // Import is at the bottom to avoid circular dependency issues.
  final client = Provider.of<Client>(context, listen: false);

  switch (result.entityType) {
    case MatrixUriEntity.room:
    case MatrixUriEntity.roomAlias:
      // Check if already joined.
      final room = client.getRoomById(result.entityId);
      if (room != null) {
        context.go('/main/rooms/${result.entityId}');
      } else {
        // Open room preview.
        context.go('/main/room_preview/${result.entityId}');
      }
    case MatrixUriEntity.user:
      // Navigate to a user profile.
      context.go('/main/rooms/${result.entityId}');
  }
}
