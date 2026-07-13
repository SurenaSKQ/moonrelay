# Testing Moonrelay

This document is a short orientation for the test pyramid and how to
run each layer locally.  The CI workflow (`.github/workflows/tests.yml`)
runs the same commands on every push.

## Layers

### 1. Unit tests (`test/unit/`)

Pure-Dart tests that don't pull in Flutter widgets.  Cover parsers,
helper utilities, and any logic that can be expressed without
`WidgetTester`.  These run fastest  typically < 5 s for the entire
folder.

```bash
flutter test test/unit/
```

### 2. Widget tests (`test/widget/`)

`flutter_test` widget tests.  Each widget is mounted in a synthetic
`MaterialApp` with the providers it actually needs (see
`test/helpers/widget_test_utils.dart`).

```bash
flutter test test/widget/
```

### 3. Integration tests (`integration_test/`)

Full-app smoke tests run with the `integration_test` package.  All
Matrix API calls are intercepted by the mock HTTP client in
`integration_test/helpers/mock_matrix_http_client.dart`  no live
homeserver is required.  Each test boots a real `Client` + an
`EncryptionService` and walks the GUI.

```bash
flutter test integration_test/ -d linux   # or windows / macos
```

## What's pinned by tests

| Test file | Pins | Notes |
| --- | --- | --- |
| `test/unit/log_redaction_test.dart` | The redaction ruleset.  14 cases covering `syt_…`, `MDA…`, Bearer, `device_id`/`session_id`, password, loginToken, and a chaos line with every class.  **New in this rev  the redaction pipeline had three real bugs that these tests now prevent.** |
| `test/unit/markdown_round_trip_test.dart` | The `MarkdownToHtml.convert` output for the supported subset.  20 cases that pin tags, XSS hardening, and edge cases.  **New.** |
| `test/unit/matrix_uri_parser_test.dart` | Bare-Matrix-ID detection and matrix.to permalink parsing.  41 cases.  Already shipped. |
| `test/unit/space_pinning_test.dart` | SettingsService JSON round-trip for pinned spaces / space order / collapsed groups / space groups.  9 cases.  Already shipped; the JSON encoding was added in a previous rev after the `,`/`|` splitting bug. |
| `test/widget/encryption_overview_screen_test.dart` | Encryption overview layout (4 sections, Ready/Action-required badges, master-key fingerprint, refresh button, "Why set up?" checklist).  6 cases.  **New.** |
| `test/widget/chat_box_test.dart` | Reply-with-markdown keeps `formatted_body` in the event content (regression for the bug where the markdown branch lived in the `else` branch of the reply branch).  8 cases total.  **New cases.** |
| `integration_test/login_test.dart` | Login flow end-to-end (welcome → form → room list).  4 cases.  Already shipped. |
| `integration_test/room_flow_test.dart` | Room interaction (list, tap to view messages).  2 cases.  Already shipped. |
| `integration_test/encryption_gui_test.dart` | Encryption flow end-to-end (login + encryption handlers installed + GUI smoke).  **New in this rev  the new `configureEncryptionHandlers()` helper on `MockMatrixHttpClient` makes the encryption flow testable in CI.** |

## Mock HTTP client

`MockMatrixHttpClient` in `integration_test/helpers/` is a `http.BaseClient`
that intercepts requests by regex.  Each test calls `mockHttp.on(...)` to
register a handler; the default returns a 404 with an `M_NOT_FOUND`
errcode.  Two convenience helpers ship:

- `mockHttp.addRoom(...)`  pre-populate a room in the sync response.
- `mockHttp.configureEncryptionHandlers()`  install standard
  `/keys/upload`, `/keys/device_signing/upload`,
  `/keys/signatures/upload` handlers and a single bootstrap device
  for `/devices`.  Tests that need a non-default state can register
  their own handlers before calling `buildTestApp`.

## Pre-flight (CI) vs dev

For local development, `tools/test.sh all` runs the same checks as CI
in one shot.  The script auto-detects your platform for the
integration test target, or you can override with `CI_PLATFORM=…`.

## Adding new tests

1. **Unit**  drop a new `test_*.dart` in `test/unit/`.  Use the existing
   pattern of `group(...)` + `test(...)` + plain `expect` assertions.
2. **Widget**  drop a new `*_test.dart` in `test/widget/`.  Use
   `wrapWithProviders(...)` from `test/helpers/widget_test_utils.dart`
   for the standard provider tree, or build a one-off `MaterialApp`
   if the widget is self-contained.
3. **Integration**  drop a new `*_test.dart` in
   `integration_test/`.  Use `buildTestApp(mockHttp: ...)` from
   `test_app_boot.dart`.  All Matrix API calls go through the mock.

## Common pitfalls

- `pumpAndSettle` **deadlocks** on the encryption overview screen
  because the sync stream keeps emitting events forever.  Use a
  bounded number of `await tester.pump(const Duration(...))` calls
  to settle FutureBuilder state.
- `MockClient`/`MockRoom` from `test/helpers/mocks.dart` use
  mocktail.  Stub every getter the test reads or `NoSuchMethodError`
  will be thrown at the first `.userID`/`.deviceID` access.
- The shared `_textResponse`/`_jsonResponse` helpers in the
  integration test files are local.  If you need the helper in a
  new file, copy the helper or move it to
  `integration_test/helpers/json_response.dart`.
