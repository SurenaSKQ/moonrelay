# Contributing to Moonrelay

Bug reports, translations and packaging fixes are as welcome as code. This
document covers what to expect from each and how to get a change merged.

## Reporting bugs

A report with logs attached gets fixed faster than one without. Logs live in the
application support directory:

- Linux: `~/.local/share/Moonrelay/logs/`
- Windows: `%APPDATA%/Moonrelay/logs/`

The app can be told to wipe its logs on logout, so grab them before you log out
again. Include your platform, your Flutter version if you built from source, and
the steps that reproduce the problem.

## Translations

Strings live in `lib/src/localization/`. English is `app_en.arb` and Persian is
`app_fa.arb`; both are generated into the app by `flutter gen-l10n`.

To add a locale, copy `app_en.arb`, translate the values, and open a pull
request. Leave the keys alone and translate the values only, since keys are
referenced from Dart.

## Workflow

1. Fork the repository on GitHub.
2. Branch from `develop`, not from `master`:

   ```bash
   git checkout develop
   git checkout -b feature/your-thing
   ```

3. Make your change. Keep `flutter analyze` clean and add tests under
   `test/unit/` or `test/widget/` where the change is testable.
4. Open a pull request against `develop`. CI has to pass before it merges.

For anything larger than a bug fix, open an issue first so the approach can be
agreed on before you write it.

## Code style

- `dart format` defaults: two-space indent, 80 columns.
- `flutter_lints`, already configured in `analysis_options.yaml`.
- A doc comment on every public API.
- Use the `Logger` from `lib/src/helpers/log_service.dart` instead of `print`.

There is also a typography guard. `./tools/check_typography.sh` fails on em
dashes, en dashes, non-breaking hyphens, box-drawing characters, and a handful
of other lookalikes that break search and copy in ways review does not catch. Run
it before you open a pull request.

## Integration tests

The tests in `integration_test/` boot the real app and drive it, so they need a
desktop session. They do not run in CI: the hosted Windows runner cannot attach
the debug VM reliably, and the Linux runner only manages them under Xvfb.

If your change touches login, sync, navigation, the chat box, or anything under
`lib/src/screens/`, run the suite yourself first:

```bash
flutter test integration_test/ -d linux
flutter test integration_test/ -d windows
```

No Matrix homeserver is needed. The suite drives the mock HTTP client in
`integration_test/helpers/mock_matrix_http_client.dart`. [docs/TESTING.md](docs/TESTING.md)
covers the test layers and the pitfalls.

## Releases

Only maintainers cut tags. The process is written up in
[docs/RELEASING.md](docs/RELEASING.md).

## Developer Certificate of Origin

By submitting a contribution (patch, pull request, issue, comment, or any other
material) to this project, you agree to the following **Developer Certificate of
Origin 1.1**:

```
By making a contribution to this project, I certify that:

(a) The contribution was created in whole or in part by me and I
    have the right to submit it under the open source license
    indicated in the file; or

(b) The contribution is based upon previous work that, to the best
    of my knowledge, is covered under an appropriate open source
    license and I have the right to submit that work with
    modifications, whether created in whole or in part by me, under
    the same open source license as the previous work; or

(c) The contribution was provided directly to me by some other
    person who certified (a) or (b) and I have not modified it.

(d) I understand and agree that this project and the contribution
    are public and that a record of the contribution, including any
    personal information I submit with it, is maintained
    indefinitely and may be redistributed consistent with this
    project and the open source license indicated in the file.
```

DCO 1.1, adapted from the Linux kernel project.

## Code of conduct

Be kind. Disagree on the merits, not the person. The maintainer closes threads
that go nowhere.