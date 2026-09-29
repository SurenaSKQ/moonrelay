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

/// A user-facing description of a failed authentication request that
/// cannot leak the credentials it carried.
///
/// `MatrixHttpException.toString()` echoes the request body, so a homeserver
/// that returns a 4xx can put the submitted password or login token into
/// the exception's own text. The user reads that on screen and copies it
/// into a bug report, so any path that shows a login, token or register
/// error to the user must go through this rather than interpolating the
/// error.
///
/// The exception's public properties are used deliberately: nothing here
/// calls `toString()` on the error itself.
String safeErrorMessage(Object error) {
  if (error is TimeoutException) return 'request timed out';
  return error.runtimeType.toString();
}
