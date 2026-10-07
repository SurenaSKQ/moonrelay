<div align="center">

<img src="https://raw.githubusercontent.com/SurenaSKQ/moonrelay/develop/assets/images/logo.png"
     alt="Moonrelay logo"
     width="120" height="120" />

# Moonrelay

**A Matrix client for the desktop. Linux and Windows, end-to-end encrypted, built with Flutter.**

[![License: AGPL-3.0-or-later](https://img.shields.io/badge/License-AGPL--3.0--or--later-blue.svg?style=for-the-badge&logo=gnu&logoColor=white)](https://www.gnu.org/licenses/agpl-3.0)
[![Version](https://img.shields.io/badge/version-0.6.0--alpha-6e3fbc?style=for-the-badge&logo=semver&logoColor=white)](https://github.com/SurenaSKQ/moonrelay/releases)
[![Platforms](https://img.shields.io/badge/platforms-Linux%20%7C%20Windows-2ea44f?style=for-the-badge&logo=linux&logoColor=white)](#installation)
[![CI](https://img.shields.io/github/actions/workflow/status/SurenaSKQ/moonrelay/tests.yml?branch=develop&label=CI&style=flat-square&logo=githubactions&logoColor=white)](https://github.com/SurenaSKQ/moonrelay/actions/workflows/tests.yml)

[Report a bug](CONTRIBUTING.md#reporting-bugs) &middot; [Request a feature](https://github.com/SurenaSKQ/moonrelay/issues/new?template=feature.yml) &middot; [Support space](https://matrix.to/#/#moonrelay-support:matrix.org)

</div>

## Status

Moonrelay is an early alpha. Expect breaking changes between releases, and
expect to lose local state now and then. One person maintains it, alongside a
day job.

This project originally started as a hobby; then morphed into my bachelor's project, and since then
has been sporadically updated over (at the time of writing) about two years.
This alpha is the first public push since then. Much of it works. Some parts are still rough, so be
prepared for issues.

It builds on [matrix-dart-sdk](https://github.com/famedly/matrix-dart-sdk) from
**Famedly GmbH** for the protocol, with Olm and Megolm supplied by
[Vodozemac](https://gitlab.com/vodolaz095/vodozemac) through
`flutter_vodozemac`. Moonrelay implements no cryptography of its own.

> **AI assistance.** Parts of this code were drafted with help from DeepSeek and
> small open-weight local models (namely: gemma, olmo, qwen), and this README was polished with AI assistance
> too. If you would rather not work with code written that way, this is probably
> not the project for you.
> Scope of AI Assistance:
> 1) Documentation
> 2) UI Sketching
> 3) Bug hunting (especially for vulnerabilities)

> **Logo.** The current logo is slop; one day I'll learn how to draw. one day that isn't today, evidently.

## Features

**Encryption**
: Full Olm and Megolm via Vodozemac, cross-signing between your own devices,
  interactive device verification, and encrypted key backup.

**Messaging**
: Formatted text, replies, edits, reactions, threads, polls, images, audio,
  video, and file sharing, with a gap marker wherever the timeline has a hole in
  it rather than pretending the messages were never sent.

**Rooms and spaces**
: Create, join, leave, browse and search rooms. Native Matrix spaces with a tree
  sidebar, the public room directory, user profiles, and multiple accounts
  against different homeservers.

**Appearance**
: Three message display modes (Modern, Bubbles, IRC), light and dark themes, a
  selectable accent colour, and a multi-pane layout with adjustable pane widths.

**Desktop integration**
: A drawn title bar, a system tray with its own actions, desktop notifications
  for mentions and direct messages, and registration as the system handler for
  `matrix://` links.

**Localisation**
: English and Persian ship. Other locales are welcome; see
  [Contributing](CONTRIBUTING.md#translations).

## Installation

### Pre-built packages

Every version tag produces packages. Take the latest from the
[releases page](https://github.com/SurenaSKQ/moonrelay/releases/latest).

| Platform | Format | Install |
|----------|--------|---------|
| Debian, Ubuntu | `.deb` | `sudo apt install ./moonrelay_*_amd64.deb` |
| Fedora, RHEL | `.rpm` | `sudo dnf install ./moonrelay-*.x86_64.rpm` |
| Windows | `.msix` | Double-click. Unsigned builds need sideloading enabled. |

(DO note that the RPM pipeline is basically theoretical right now)

Installing registers the `matrix://` URI scheme automatically, so links from a
browser or another app open Moonrelay.

If your distribution has no artifact, [open an issue](CONTRIBUTING.md#reporting-bugs).

### Building from source

You need:

- The [Flutter SDK](https://docs.flutter.dev/get-started/install). CI pins
  `3.44.6`; see [docs/RELEASING.md](docs/RELEASING.md) for the current state of
  that pin.
- A C++ toolchain: MSVC Build Tools on Windows, GCC or Clang on Linux.
- On Linux, the GTK 3 **development** headers. `flutter build linux` runs
  `pkg_check_modules` for `gtk+-3.0`, `glib-2.0` and `gio-2.0`, and those `.pc`
  files live in the `-dev` packages, not the runtime ones:

  ```bash
  # Debian, Ubuntu
  sudo apt install libgtk-3-dev libglib2.0-dev pkg-config cmake ninja-build clang
  # Fedora
  sudo dnf install gtk3-devel glib2-devel pkgconf-pkg-config cmake ninja-build clang
  ```

  Installing only `libgtk-3-0` gets you the shared library and leaves
  `pkg-config` unable to answer, so CMake stops with
  `The following required packages were not found: - gtk+-3.0`.
- A Rust toolchain. Vodozemac builds from Rust source, and a missing Rust
  install fails as a compile error in a C++ file with no mention of Rust. Install
  it before you spend an afternoon on that.

```bash
git clone https://github.com/SurenaSKQ/moonrelay.git
cd moonrelay
flutter pub get
flutter gen-l10n

flutter run -d linux
flutter run -d windows
```

`flutter gen-l10n` is required before the first run or the app has no
translations compiled in.

### Tests

```bash
flutter analyze
flutter test test/unit/ test/widget/
./tools/test.sh all          # everything CI runs
```

The `integration_test/` suite needs a real desktop session and does not run in
CI. [docs/TESTING.md](docs/TESTING.md) explains why and how to run it.

## Security

Moonrelay is alpha software. Do not rely on it for communications you cannot
afford to lose without verifying the claims independently.

**Do not file public issues for a security bug.** Contact the maintainer
directly instead:

- Matrix: [@sudo_halt:matrix.org](https://matrix.to/#/@sudo_halt:matrix.org)
- Support space: `!MFpGwhVEUITDRfTYrE:matrix.org`

A disclosure policy and a PGP key will arrive before 1.0.

## Support

| Where | Channel |
|-------|---------|
| Matrix support space | [#moonrelay-support:matrix.org](https://matrix.to/#/#moonrelay-support:matrix.org) |
| Bug reports | [GitHub issues](https://github.com/SurenaSKQ/moonrelay/issues) |
| Feature requests | [GitHub issues](https://github.com/SurenaSKQ/moonrelay/issues) |
| Direct | [@sudo_halt:matrix.org](https://matrix.to/#/@sudo_halt:matrix.org) |

The support space is the best place to get help. The About page in the app has a
button that joins it.

## Contributing

Read [CONTRIBUTING.md](CONTRIBUTING.md). Bug reports with logs, translations, and
packaging fixes are as welcome as code.

## Acknowledgements

- [Matrix.org Foundation](https://matrix.org) for the protocol.
- [Famedly GmbH](https://famedly.com) for the Matrix Dart SDK.
- [Vodozemac](https://gitlab.com/vodolaz095/vodozemac) for the Rust Olm and
  Megolm implementation.
- [Flutter](https://flutter.dev) and the Dart team.
- [Lucide](https://lucide.dev) for the icon set.
- DeepSeek and the small local models that helped when the author's brain was
  offline.

## License

Moonrelay is free software under the GNU Affero General Public License, version 3
or later. The full text ships with every release at
[`assets/agpl-3.0.txt`](assets/agpl-3.0.txt).

Copyright (C) 2025 Surena Karimpour Ghannadi

The in-app **Licenses** page under the hub lists the licences of the Apache,
BSD and MIT dependencies bundled at runtime.

---

<div align="center">

Made by [Surena Karimpour Ghannadi](https://github.com/SurenaSKQ)
In partial fulfillment for the degree of Bachelor's of Computer Science
University of Tabriz
Tabriz,
Iran.

</div>
