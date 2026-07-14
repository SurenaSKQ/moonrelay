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

import 'package:logger/logger.dart';

/// Ordered registry of long-lived services that need to be torn down
/// during application shutdown.
///
/// Services are registered in dependency order (dependency first).  On
/// shutdown the registry iterates in reverse so dependents are disposed
/// before their dependencies.
///
/// ## Usage
///
/// During boot, create a [ServiceRegistry] and register each service
/// as it is initialised:
///
/// ```dart
/// final registry = ServiceRegistry();
/// registry.register(encryptionService, () => encryptionService.dispose());
/// registry.register(notificationService, () => notificationService.dispose());
/// ```
///
/// At shutdown, call [shutdownAll] with a [Logger] for error reporting:
///
/// ```dart
/// await registry.shutdownAll(log);
/// ```
///
/// Each entry is wrapped with a try/catch so a single failure does not
/// prevent later entries from being disposed.
class ServiceRegistry {
  final List<_ServiceEntry> _entries = <_ServiceEntry>[];

  /// Registers a service for ordered teardown.
  ///
  /// The [service] is stored only for logging. The [disposer] callback
  /// is invoked during shutdown in reverse registration order (last in,
  /// first out).
  void register(
    Object service, {
    required FutureOr<void> Function() disposer,
  }) {
    _entries.add(_ServiceEntry(service, disposer));
  }

  /// Tears down all registered services in reverse registration order.
  ///
  /// Each service's [disposer] is called inside a try/catch so errors
  /// from one service do not block the remainder. After completion the
  /// entry list is cleared.
  Future<void> shutdownAll(Logger log) async {
    for (int i = _entries.length - 1; i >= 0; i--) {
      final entry = _entries[i];
      try {
        final result = entry.disposer();
        if (result is Future) {
          await result;
        }
      } catch (e) {
        log.w('${entry.service.runtimeType} shutdown failed', error: e);
      }
    }
    _entries.clear();
  }
}

class _ServiceEntry {
  _ServiceEntry(this.service, this.disposer);
  final Object service;
  final FutureOr<void> Function() disposer;
}
