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

/// Default timeout for Matrix network operations.
///
/// The Matrix SDK's sync uses a 10s default.  We use a slightly longer
/// window so our wrapper timeout doesn't preempt the SDK's own timeout.
const Duration kDefaultTimeout = Duration(seconds: 30);

/// Default timeout specifically for login/registration flows.
const Duration kLoginTimeout = Duration(seconds: 45);

/// Default timeout for file uploads.
const Duration kUploadTimeout = Duration(minutes: 5);

/// Result of a retryable operation.
sealed class RetryResult<T> {
  const RetryResult();
}

/// The operation succeeded.
class RetrySuccess<T> extends RetryResult<T> {
  const RetrySuccess(this.value);
  final T value;
}

/// All retry attempts were exhausted.
class RetryFailed<T> extends RetryResult<T> {
  const RetryFailed(this.error, this.attempts);
  final Object error;
  final int attempts;
}

/// Runs [fn] with a [timeout].  If the timeout fires, the result is a
/// [TimeoutException] in the catch handler.
///
/// This is intentionally a thin wrapper so callers can decide how to
/// surface the error.
Future<T> withTimeout<T>(
  Future<T> Function() fn, {
  Duration timeout = kDefaultTimeout,
}) {
  return fn().timeout(timeout);
}

/// Runs [fn] and retries up to [maxRetries] times with [delay] between
/// attempts.  Non-timeout errors are not retried by default  set
/// [retryOnAllErrors] to `true` to retry on any exception.
///
/// Returns a [RetryResult] so callers can inspect the final error and
/// number of attempts made.
Future<RetryResult<T>> withRetry<T>(
  Future<T> Function() fn, {
  int maxRetries = 2,
  Duration delay = const Duration(seconds: 2),
  Duration timeout = kDefaultTimeout,
  bool retryOnAllErrors = false,
  Logger? log,
  String label = 'operation',
}) async {
  int attempts = 0;
  Object? lastError;

  while (attempts <= maxRetries) {
    attempts++;
    try {
      final result = await fn().timeout(timeout);
      return RetrySuccess(result);
    } on TimeoutException catch (e) {
      lastError = e;
      log?.w('[$label] timeout on attempt $attempts/$maxRetries: $e');
    } catch (e) {
      lastError = e;
      if (!retryOnAllErrors) {
        log?.e('[$label] non-retryable error on attempt $attempts: $e');
        return RetryFailed(e, attempts);
      }
      log?.w('[$label] error on attempt $attempts/$maxRetries: $e');
    }

    if (attempts <= maxRetries) {
      await Future.delayed(delay);
    }
  }

  return RetryFailed(lastError!, attempts);
}

/// Runs [fn] with a timeout, catches the error, and returns a user-friendly
/// fallback.  This is useful for non-critical UI data that can degrade
/// gracefully.
Future<T> withTimeoutOrFallback<T>(
  Future<T> Function() fn, {
  Duration timeout = kDefaultTimeout,
  required T fallback,
  Logger? log,
  String label = 'operation',
}) async {
  try {
    return await fn().timeout(timeout);
  } on TimeoutException {
    log?.w('[$label] timed out, using fallback');
    return fallback;
  } catch (e) {
    log?.w('[$label] error, using fallback', error: e);
    return fallback;
  }
}
