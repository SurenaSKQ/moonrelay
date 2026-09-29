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

/// Which sign-in form the login page is showing.
///
/// This replaces a pair of booleans that the build method branched on
/// twenty-odd times. They were set independently, so the state where both
/// were true was representable and simply fell through every branch to the
/// password button, with the password fields still hidden because one of
/// the two was true. A single enum makes that combination impossible to
/// write rather than impossible to notice.
enum LoginMode {
  /// Homeserver, username and password fields, with a sign-in button.
  password,

  /// The SSO section, which is either waiting on a browser redirect or
  /// showing the manual token fallback.
  sso,

  /// A single access-token field, for homeservers whose interactive flow
  /// is not automated.
  token;

  /// Whether the form's own input fields should be visible.
  ///
  /// True for [password] only: the SSO and token forms are made of their
  /// own sections, and the token field is shared with the SSO manual
  /// fallback, so showing it twice would be confusing rather than helpful.
  bool get showsCredentialFields => this == LoginMode.password;
}

/// Where the user is inside the SSO sub-flow.
///
/// The automatic flow and the manual fallback are one journey, not two
/// independent flags, and every transition between them sets all three of
/// the booleans it used to use. Modelling it as one value is what makes the
/// unreachable combinations (running and failed at once, running and
/// showing the paste field at once) impossible.
enum SsoStep {
  /// Nothing started. The page shows the open-in-browser button.
  idle,

  /// The local callback server is up and the browser is open; waiting for
  /// the redirect back with a token.
  awaitingCallback,

  /// The automatic flow could not finish. The page shows the destination
  /// URL so the user can try again by hand, plus the reason it failed.
  automaticFailed,

  /// The user asked for the paste field and is typing a token by hand.
  manualTokenEntry;

  /// Whether the automatic flow is currently running, which is what
  /// suppresses the mode switcher and replaces the action button.
  bool get isAwaitingCallback => this == SsoStep.awaitingCallback;

  /// Whether to show the paste-token field.
  bool get showsManualTokenEntry => this == SsoStep.manualTokenEntry;

  /// Whether to show the "the automatic flow failed" notice.
  bool get showsFailureNotice => this == SsoStep.automaticFailed;
}
