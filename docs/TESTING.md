# Testing Moonrelay

Three layers, run in increasing order of cost. CI
(`.github/workflows/tests.yml`) runs the first two plus a release-build smoke
test on every push.

## Layers

### Unit (`test/unit/`)

Pure Dart, no Flutter widgets. Parsers, helpers, and any logic that can be
expressed without a `WidgetTester`. The whole folder runs in a few seconds.

```bash
flutter test test/unit/
```

### Widget (`test/widget/`)

`flutter_test` widget tests. Each widget is mounted in a synthetic `MaterialApp`
with the providers it needs; `test/helpers/widget_test_utils.dart` builds the
standard tree.

```bash
flutter test test/widget/
```

### Integration (`integration_test/`)

Full-app tests through the `integration_test` package. Every Matrix request is
intercepted by the mock HTTP client in
`integration_test/helpers/mock_matrix_http_client.dart`, so no homeserver is
needed. Each test boots a real `Client` and `EncryptionService` and walks the
GUI.

```bash
flutter test integration_test/ -d linux
flutter test integration_test/ -d windows
```

These need a real desktop session and are not part of CI. See
[CONTRIBUTING.md](../CONTRIBUTING.md#integration-tests) for the reasoning.

## What the heavier tests pin

| File | Pins |
|------|------|
| `test/unit/log_redaction_test.dart` | The log redaction ruleset: `syt_...`, Matrix access tokens, bearer tokens, `device_id`, `session_id`, passwords and login tokens, plus a line containing every class at once. |
| `test/unit/markdown_round_trip_test.dart` | `MarkdownToHtml.convert` output for the supported subset, including tag stripping and XSS hardening. |
| `test/unit/matrix_uri_parser_test.dart` | Bare Matrix ID detection and `matrix.to` permalink parsing. |
| `test/unit/space_pinning_test.dart` | `SettingsService` round-trips for pinned spaces, space order, collapsed groups and space groups. The JSON encoding exists because the earlier comma and pipe delimiters broke on spaces in a display name. |
| `test/widget/encryption_overview_screen_test.dart` | The encryption overview layout: section count, Ready and Action-required badges, master key fingerprint, refresh button. |
| `test/widget/chat_box_test.dart` | That a reply written in Markdown keeps `formatted_body` in the event content. The formatting branch used to sit in the `else` of the reply branch, so replies lost their formatting. |
| `integration_test/login_test.dart` | Sign-in end to end: welcome screen, form, room list. |
| `integration_test/room_flow_test.dart` | Room list and opening a room to read its messages. |
| `integration_test/encryption_gui_test.dart` | Login, encryption handlers installed, GUI smoke. Depends on `configureEncryptionHandlers()` on the mock client. |

## The mock HTTP client

`MockMatrixHttpClient` is an `http.BaseClient` that dispatches on a regex. Each
test registers handlers with `mockHttp.on(...)`; an unmatched request gets a 404
with an `M_NOT_FOUND` errcode.

Two helpers cover most cases:

- `mockHttp.addRoom(...)` pre-populates a room in the sync response.
- `mockHttp.configureEncryptionHandlers()` installs the standard
  `/keys/upload`, `/keys/device_signing/upload` and `/keys/signatures/upload`
  routes plus one bootstrap device for `/devices`.

Register your own handlers before `buildTestApp` when you need a different state.

## Running everything at once

`./tools/test.sh` runs the same checks as CI. It takes `unit`, `widget`,
`integration` or `all` (the default), and detects the integration target platform
unless you pass `CI_PLATFORM`.

## Adding tests

1. **Unit**: a `*_test.dart` in `test/unit/`, using `group(...)`, `test(...)`
   and plain `expect`.
2. **Widget**: a `*_test.dart` in `test/widget/`. Use `wrapWithProviders(...)`
   from `test/helpers/widget_test_utils.dart`, or build a bare `MaterialApp` if
   the widget needs nothing.
3. **Integration**: a `*_test.dart` in `integration_test/`, using
   `buildTestApp(mockHttp: ...)` from `test_app_boot.dart`.

## Pitfalls

- `pumpAndSettle` deadlocks on the encryption overview. The sync stream keeps
  emitting forever, so the tree never goes idle. Pump a bounded number of times
  with an explicit duration instead.
- The mocks in `test/helpers/mocks.dart` use mocktail. Stub every getter the
  test touches, or the first `.userID` or `.deviceID` access throws
  `NoSuchMethodError`.
- `_textResponse` and `_jsonResponse` are file-local helpers in the integration
  tests. Copy one into your file, or move it to
  `integration_test/helpers/json_response.dart`.
- A test that builds its own stand-in for a real widget proves nothing about that
  widget. `test/unit/pane_bar_consistency_test.dart` existed in a form that
  compared two `SizedBox(height: h)` values to each other, which passes whatever
  the bar renders. Mount the real thing.