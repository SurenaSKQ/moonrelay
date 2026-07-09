<div align="center">

<!-- ── Logo ────────────────────────────────────────────────────── -->
<img src="https://raw.githubusercontent.com/SurenaSKQ/moonrelay/develop/assets/images/logo.png"
     alt="Moonrelay logo"
     width="120" height="120" />

# Moonrelay

**A Matrix client for professionals — secure, cross-platform, and built with Flutter.**

[![License: AGPL-3.0-or-later](https://img.shields.io/badge/License-AGPL--3.0--or--later-blue.svg?style=for-the-badge&logo=gnu&logoColor=white)](https://www.gnu.org/licenses/agpl-3.0)
[![Version](https://img.shields.io/badge/version-0.6.0--alpha-6e3fbc?style=for-the-badge&logo=semver&logoColor=white)](https://github.com/SurenaSKQ/moonrelay/releases)
[![Platforms](https://img.shields.io/badge/platforms-Linux%20%7C%20Windows-2ea44f?style=for-the-badge&logo=linux&logoColor=white)](#-installation)
[![Built with Flutter](https://img.shields.io/badge/built%20with-Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)

[![CI](https://img.shields.io/github/actions/workflow/status/SurenaSKQ/moonrelay/tests.yml?branch=develop&label=CI&style=flat-square&logo=githubactions&logoColor=white)](https://github.com/SurenaSKQ/moonrelay/actions/workflows/tests.yml)
[![Linux Packaging](https://img.shields.io/github/actions/workflow/status/SurenaSKQ/moonrelay/package-linux.yml?label=Linux%20pkg&style=flat-square&logo=debian&logoColor=white)](https://github.com/SurenaSKQ/moonrelay/actions/workflows/package-linux.yml)
[![Windows MSIX](https://img.shields.io/github/actions/workflow/status/SurenaSKQ/moonrelay/package-windows.yml?label=MSIX&style=flat-square&logo=windows&logoColor=white)](https://github.com/SurenaSKQ/moonrelay/actions/workflows/package-windows.yml)
[![Latest Release](https://img.shields.io/github/v/release/SurenaSKQ/moonrelay?include_prereleases&style=flat-square&logo=github)](https://github.com/SurenaSKQ/moonrelay/releases/latest)
[![Downloads](https://img.shields.io/github/downloads/SurenaSKQ/moonrelay/total?style=flat-square&logo=github)](https://github.com/SurenaSKQ/moonrelay/releases)
[![Stars](https://img.shields.io/github/stars/SurenaSKQ/moonrelay?style=flat-square&logo=github)](https://github.com/SurenaSKQ/moonrelay/stargazers)
[![Issues](https://img.shields.io/github/issues/SurenaSKQ/moonrelay?style=flat-square&logo=github)](https://github.com/SurenaSKQ/moonrelay/issues)

[Report Bug](https://github.com/SurenaSKQ/moonrelay/issues/new?template=bug.yml) · [Request Feature](https://github.com/SurenaSKQ/moonrelay/issues/new?template=feature.yml) · [Get Support](#-support) · [Documentation](docs/)

</div>

---

## 📑 Table of Contents

- [⚠️ Project Status](#%EF%B8%8F-project-status)
- [✨ Features](#-features)
- [📦 Installation](#-installation)
  - [Pre-built Binaries](#pre-built-binaries)
  - [Building from Source](#building-from-source)
- [🖼️ Screenshots](#%EF%B8%8F-screenshots)
- [🚀 Roadmap & Known Gaps](#-roadmap--known-gaps)
- [🤝 Contributing](#-contributing)
- [🛠️ Architecture & Tech Stack](#%EF%B8%8F-architecture--tech-stack)
- [🔒 Security](#-security)
- [📝 License](#-license)
- [💬 Support & Contact](#-support--contact)
- [🙏 Acknowledgements](#-acknowledgements)

---

## ⚠️ Project Status

> **Early Alpha.** Expect breaking changes, rough edges, and
> the occasional crash dump. Built mostly by one person who also
> works a day job.

Moonrelay started as a hobby project, became a bachelor's project,
and then sat on a hard drive for two years while life did its
thing. This alpha is the first public push after that long pause,
many features already work, but several subsystems (see
[`WORK_NEEDED.md`](WORK_NEEDED.md)) are still under construction.

The current alpha uses [matrix-dart-sdk](https://github.com/famedly/matrix-dart-sdk)
by **Famedly GmbH**, with a custom native crypto stack via
[Vodozemac](https://pub.dev/packages/flutter_vodozemac). A
from-scratch Matrix SDK remains on the long-term roadmap, but
realistically that lands between the final release of GNU HURD
and the heat death of the universe.

> **AI usage note:** Some code was drafted with assistance from
> DeepSeek and small FOSS local models. If you have a hard line
> against AI-generated code, this probably isn't the project for
> you.

> **Logo note:** It's a placeholder. A real one will arrive when
> the author learns 1337 vector art skillz.

---

## ✨ Features

### 🔐 Crypto & Protocol
- **Matrix Protocol** — full homeserver sync via the Matrix Dart SDK.
- **End-to-End Encryption** — Olm/Megolm via Vodozemac (native Rust).
- **Cross-Signing** — establish trust across your devices.
- **Device Verification** — interactive emoji/QR flows.
- **Key Backup** — encrypted backup of session keys.

### 💬 Messaging
- **Rich Messages** — text, HTML, formatted text, replies, edits.
- **Media** — images, audio recordings, video playback, file sharing.
- **Threads** — read and reply inside threads.
- **Reactions & Edits** — inline modifications and reactions.

### 🎨 Customisation
- **Three Display Modes** — Modern, Bubbles, IRC.
- **Theme Modes** — Light, Dark, or follow System.
- **Seed Colours** — pick a Material 3 seed; the rest derives.
- **Sidebar Layouts** — adjustable widths, multi-pane desktop layout.

### 🚪 Rooms & Spaces
- **Room Management** — create, join, leave, browse, and search.
- **Spaces** — native Matrix space support with a tree sidebar.
- **Room Directory** — discover public rooms.
- **User Profiles** — view any user's profile and devices.
- **Multi-Account** — sign in to multiple homeservers.

### 🌍 Platform
- **Desktop-First** — Linux (deb/rpm) and Windows (MSIX).
- **Deep Linking** — register as the system handler for `matrix://`
  URIs on both Linux and Windows.
- **Notification Support** — desktop notifications for mentions and DMs.
- **Internationalisation** — full `flutter gen-l10n` plumbing; English
  ships, more locales are welcome.

### 📜 Licensing
- **AGPL-3.0-or-later** — copyleft open source, source available
  for any service that runs it.

---

## 📦 Installation

### Pre-built Binaries

The CI/CD pipeline packages Moonrelay on every version tag.
Grab the latest from the **Releases** page:

[![GitHub release](https://img.shields.io/github/v/release/SurenaSKQ/moonrelay?include_prereleases)](https://github.com/SurenaSKQ/moonrelay/releases/latest)

| Platform | Format | Install |
|----------|--------|---------|
| **Debian / Ubuntu** | `.deb` | `sudo apt install ./moonrelay_*_amd64.deb` |
| **Fedora / RHEL** | `.rpm` | `sudo dnf install ./moonrelay-*.x86_64.rpm` |
| **Windows** | `.msix` | Double-click; sideload-enable for unsigned builds |

After installation, the `matrix://` URI scheme is auto-registered
(deb/rpm via `postinst`, Windows via the bundled `.reg`).

If a release artifact is missing for your distro, please
[open an issue](https://github.com/SurenaSKQ/moonrelay/issues).

### Building from Source

#### Prerequisites

- **[Flutter SDK](https://docs.flutter.dev/get-started/install)**
  (3.24+ recommended; pin via the CI workflow's `FLUTTER_VERSION`)
- **C++ Toolchain** — MSVC Build Tools on Windows, GCC or Clang on Linux
- **Rust Toolchain** — required for Vodozemac; a missing Rust
  install surfaces as a **cryptic build failure** with no obvious
  cause, so install it before debugging anything else.

#### Steps

```bash
git clone https://github.com/SurenaSKQ/moonrelay.git
cd moonrelay
flutter pub get
flutter gen-l10n

# Run on Linux
flutter run -d linux

# Run on Windows
flutter run -d windows
```

#### Tests

```bash
flutter analyze                          # static analysis
flutter test test/unit/ test/widget/    # pure Dart + widget tests
flutter test integration_test/ -d linux # E2E (mock Matrix client)
```

---

## 🖼️ Screenshots

> Placeholder screenshots. Real ones will be added in the
> [`docs/screenshots/`](docs/) directory once stable UI milestones
> are hit.

| Modern mode | Bubbles mode | IRC mode |
|-------------|--------------|----------|
| *coming soon* | *coming soon* | *coming soon* |

Want to help? Capture one in your favourite display mode and
[open a PR](CONTRIBUTING.md).

---

## 🚀 Roadmap & Known Gaps

The full punch list lives in
[`WORK_NEEDED.md`](WORK_NEEDED.md) (auto-generated audit; expect
some inaccuracy). High-level priorities:

- [x] Alpha release cut from `pubspec.yaml` `0.6.0`
- [x] CI/CD pipeline + Linux/Windows packaging
- [ ] Reply + thread send wired through `m.relates_to` (`ChatBox` UI
      preview is in place; the wire format isn't yet)
- [ ] Stable 1.0.0 with full E2EE trust UX polished
- [ ] macOS target (currently buildable but unmaintained)
- [ ] Optional integration with native calendar / notifications
- [ ] Replace `matrix-dart-sdk` with a home-grown SDK
      *(see GNU HURD disclaimer above)*

---

## 🤝 Contributing

Contributions are very welcome — both code and non-code.

### Workflow

1. **Fork** the repo on
   [GitHub](https://github.com/SurenaSKQ/moonrelay/fork).
2. **Branch from `develop`:**
   ```bash
   git checkout develop
   git checkout -b feature/your-thing
   ```
3. **Make your changes.** Keep `flutter analyze` clean and add
   tests under `test/unit/` or `test/widget/` where applicable.
4. **Open a PR** against `develop`. The CI must pass before merge.
5. **For releases** — see [`docs/RELEASING.md`](docs/RELEASING.md).
   Don't cut tags unless you're a maintainer.

### What helps most

- **Issues** — bug reports with logs from `~/.local/share/Moonrelay/logs/`
  (Linux) or `%APPDATA%/Moonrelay/logs/` (Windows).
- **Translations** — fill in keys in
  [`lib/src/localization/app_en.arb`](lib/src/localization/app_en.arb)
  for your locale and open a PR.
- **Code** — open an issue first on anything non-trivial so we can
  agree on the approach.
- **Packaging** — `.deb`/`.rpm`/`.msix` bugs or new distro requests.

### Code style

- 2-space indent, 80-column guides (`dart format`).
- `flutter_lints` (already configured in `analysis_options.yaml`).
- Doc comments (`///`) on every public API.
- No untracked `print()` — use the `Logger` from
  [`log_service.dart`](lib/src/helpers/log_service.dart).

---

## 🛠️ Architecture & Tech Stack

```
Flutter 3.24+ (Dart >=3.2.6 <4.0)
├── matrix (Dart Matrix SDK)
├── flutter_vodozemac (native E2EE)
├── provider (state management)
├── go_router (declarative routing)
├── shared_preferences (settings persistence)
├── sqflite + sqflite_common_ffi (local database)
├── window_manager + flutter_acrylic (desktop chrome)
├── just_audio / video_player / record (media)
├── flutter_local_notifications (desktop notifications)
├── tray_manager (system tray)
├── lucide_icons_flutter (icon set)
└── intl + flutter_localizations (i18n)
```

Built with **[Provider](https://pub.dev/packages/provider)** for
state management (no Riverpod / Bloc — opinionated choice).
Routing via **GoRouter** with `ShellRoute` nesting for the
hub/main/welcome flows.

For the deep dive, see:

- [`AGENTS.md`](AGENTS.md) — authoritative architecture guide for AI
  agents and humans alike.
- [`docs/RELEASING.md`](docs/RELEASING.md) — versioning, CI, and
  packaging pipeline.
- [`docs/TESTING.md`](docs/TESTING.md) — test setup, mocking,
  in-app boot pipeline for E2E.

---

## 🔒 Security

Moonrelay is alpha software. **Do not rely on it for life-critical
communications without independent verification.**

### Reporting vulnerabilities

Please **do not file public GitHub issues for security bugs.**
Instead, contact the maintainer privately:

- **Matrix DM:** `@sudo_halt:matrix.org`
- **Matrix support space:** `!MFpGwhVEUITDRfTYrE:matrix.org`

A disclosure policy and PGP key will land before the 1.0 release.

### Cryptographic audit

The actual crypto lives in the upstream
[Vodozemac](https://gitlab.com/vodolaz095/vodozemac) library (Rust)
via `flutter_vodozemac`. Moonrelay itself does not implement
primitives — it composes them.

---

## 📝 License

```
Moonrelay — a Matrix chat client for professionals.
Copyright (C) 2025 Surena Karimpour Ghannadi

This program is free software: you can redistribute it and/or
modify it under the terms of the GNU Affero General Public License
as published by the Free Software Foundation, either version 3 of
the License, or (at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public
License along with this program.  If not, see
<https://www.gnu.org/licenses/>.
```

The full license text ships with every release:
[`assets/agpl-3.0.txt`](assets/agpl-3.0.txt).

For Apache/BSD/MIT dependencies shipped at runtime, see the in-app
**Licenses** page under the hub.

---

## 💬 Support & Contact

| Channel | Where |
|---------|-------|
| **💬 Matrix Support Space** | [`#moonrelay-support:matrix.org`](https://matrix.to/#/#moonrelay-support:matrix.org) |
| **🐛 Bug Reports** | [GitHub Issues](https://github.com/SurenaSKQ/moonrelay/issues) |
| **💡 Feature Requests** | [GitHub Issues](https://github.com/SurenaSKQ/moonrelay/issues) |
| **📨 Direct** | [@sudo_halt:matrix.org](https://matrix.to/#/@sudo_halt:matrix.org) |

The Matrix support space is the recommended channel for getting
help — the in-app About page has a one-tap "Join Support Space"
button.

---

## 🙏 Acknowledgements

- **[Matrix.org Foundation](https://matrix.org)** — for the protocol.
- **[Famedly GmbH](https://famedly.com)** — for the Matrix Dart SDK.
- **[Vodozemac](https://gitlab.com/vodolaz095/vodozemac)** — for the
  Olm/Megolm Rust implementation.
- **[Sven Moheit / The Flutter Authors](https://flutter.dev)** — for
  Flutter and its ecosystem.
- **[Lucide](https://lucide.dev)** — for the icon set.
- All the small FOSS local models and DeepSeek that occasionally
  helped when the author's brain was offline.

---

<div align="center">

Made with ☕ and 🦀 by [Surena Karimpour Ghannadi](https://github.com/SurenaSKQ)

</div>
