# Contributing to Moonrelay

Thanks for your interest in making Moonrelay better!
Please read the
[Contributing section in the README](README.md#-contributing)
first it covers workflow, code style, and what kinds of
contributions are most useful.

## Quick links

- 🐛 [Report a bug](https://github.com/SurenaSKQ/moonrelay/issues/new?template=bug.yml)
- 💡 [Request a feature](https://github.com/SurenaSKQ/moonrelay/issues/new?template=feature.yml)
- 💬 [Matrix support space](https://matrix.to/#/#moonrelay-support:matrix.org)
- 📦 [Release process](docs/RELEASING.md)
- 🧪 [Testing guide](docs/TESTING.md)

## Integration tests

The tests in `integration_test/` need a real desktop session (they boot
the actual Flutter app and drive it with `IntegrationTestWidgetsFlutterBinding`).
They are **not** run in CI — the hosted Windows runner can't reliably attach
the debug VM, and the Linux runner only runs them under Xvfb.

If your change touches login, sync, navigation, the chat box, or any screen
under `lib/src/screens/`, please run the integration suite on your own
machine before opening the PR:

```bash
flutter test integration_test/ -d linux    # Linux
flutter test integration_test/ -d windows  # Windows
```

You only need a working Flutter SDK and the build deps already listed in
`docs/TESTING.md` — no Matrix homeserver required, the suite uses the
mock HTTP client in `integration_test/helpers/mock_matrix_http_client.dart`.

## Developer Certificate of Origin

By submitting a contribution (patch, pull request, issue, comment,
or any other material) to this project, you agree to the following
**Developer Certificate of Origin 1.1**:

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

(DCO 1.1, adapted from the Linux kernel project.)

## Code of Conduct

Be kind. Don't be rude. Disagree on the merits, not the people.
The maintainer reserves the right to close unproductive threads.
