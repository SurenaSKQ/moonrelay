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

/// Parses freeform homeserver text from the login field into a [Uri].
///
/// The field accepts both `matrix.org` and `https://matrix.org` because
/// that is what people type, so a bare host is promoted to HTTPS rather
/// than rejected. Returns `null` when the text is empty or will not parse,
/// which is what the callers want to be able to report: the login page has
/// to tell the user their address is unusable, and `Uri.parse` throwing
/// inside a `setState` is not a way to do that.
///
/// The result is not yet trusted; pass it through [isPlausibleHomeserverUrl]
/// before opening a browser or sending credentials anywhere.
Uri? parseHomeserverInput(String input) {
  final String trimmed = input.trim();
  if (trimmed.isEmpty) return null;
  final Uri parsed;
  try {
    parsed = trimmed.contains('://')
        ? Uri.parse(trimmed)
        : Uri.https(trimmed, '');
  } on FormatException {
    return null;
  }
  // `Uri.parse('https://')` succeeds and yields an empty host, so parsing
  // alone is not enough to call the text a URL the user could have meant.
  if (parsed.host.isEmpty) return null;
  return parsed;
}

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
  // surrounding brackets (e.g. `[::1]` -> `::1`), so we match on both.
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
