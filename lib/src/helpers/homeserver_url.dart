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

/// Helpers for validating user-typed homeserver URLs before we send any
/// network traffic to them.
///
/// The username/homeserver field on the login page is freeform text, so
/// it's easy to mistype or paste a phishing link.  Calling
/// `isPlausibleHomeserverUrl(uri)` returns `false` for obvious phishing
/// payloads so we can refuse them before opening a browser window or
/// asking the user to enter credentials.
///
/// The check is *defence in depth*, not a firewall: anything that passes
/// this gate is still presented to the user with a confirmation dialog
/// before the browser is launched.
library;

/// Returns `true` when [uri] looks like a homeserver the user actually
/// intends to authenticate against (a public HTTP/HTTPS origin).
bool isPlausibleHomeserverUrl(Uri uri) {
  // Must be HTTP(S).  `javascript:`, `file:`, `data:`, and other schemes
  // are never legitimate homeserver URLs and are common phishing tricks.
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;

  // Must have a host.  `https:///path` parses with an empty host.
  final host = uri.host;
  if (host.isEmpty) return false;

  final lower = host.toLowerCase();

  // Refuse loopback destinations: no real homeserver runs there and a
  // user typing `localhost` is almost always going to land on their
  // own machine.  `Uri.host` returns IPv6 addresses without the
  // surrounding brackets (e.g. `[::1]` → `::1`), so we match on both.
  if (lower == 'localhost' ||
      lower == 'localhost.localdomain' ||
      lower.startsWith('127.') ||
      lower == '0.0.0.0' ||
      lower == '::1' ||
      lower.startsWith('::')) {
    return false;
  }

  // Refuse URLs that smuggle credentials into the location: phishing
  // pages occasionally use `https://user:pass@evil.example/` style URIs.
  if (uri.userInfo.isNotEmpty) return false;

  return true;
}
