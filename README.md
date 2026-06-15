# Moonrelay (Alpha)

**A Matrix client for professionals — secure, cross-platform, and built with Flutter.**

Moonrelay is a Matrix chat client focused on professional usage and advanced
users. It prioritises stability, security, and a clean, intuitive interface.
This is an **Alpha** release — features are actively being built and refined.

---

## Features

- **Matrix Protocol** — Full Matrix chat support via the [Matrix Dart SDK](https://github.com/famedly/matrix-dart-sdk).
- **End-to-End Encryption** — Powered by Vodozemac (native Rust crypto) with
  cross-signing, device verification, and key backup.
- **Cross-Platform** — Natively targets **Linux** and **Windows** (macOS
  support is possible).
- **Rich Messages** — Send and receive text, images, audio, files, and
  formatted messages.
- **Customisable UI** — Three display modes (Modern, Bubbles, IRC),
  multiple colour themes, and adjustable sidebar layouts.
- **Theme Support** — Light, Dark, and System theme modes with a choice of
  seed colours.
- **Room Management** — Create, join, browse, and manage rooms efficiently.
- **User Profiles** — View and manage user profiles across the network.
- **Internationalisation** — Everything I can think of has proper l10n support, but only English language is done now
- **Open Source** — GNU AGPLv3 licensed

---

## Installation

Pre-built binaries are not yet available. You will need to build from source.

### Prerequisites

- [Flutter](https://flutter.dev) SDK (3.x or later)
- A C++ toolchain (MSVC on Windows, GCC/Clang on Linux)

### Build & Run

```bash
git clone https://codeberg.org/SurenaSKQ/moonrelay.git
cd moonrelay

# Windows
flutter run -d windows

# Linux
flutter run -d linux
```

---

## Project Status

This is **early Alpha** software. Many features are implemented but several
areas are still under active development (see [`WORK_NEEDED.md`](WORK_NEEDED.md)
for details). Expect breaking changes and the occasional rough edge.

---

## Contributing

Contributions are very welcome! Here's how to get involved:

1. **Fork** the repository on [Codeberg](https://codeberg.org/SurenaSKQ/moonrelay).
2. **Create a feature branch:** `git checkout -b my-feature`.
3. **Commit** your changes with clear, descriptive messages.
4. **Push** to your fork and open a **pull request**.

Please ensure your code passes `dart analyze` before submitting.

---

## Dependencies

Key dependencies are listed in [`pubspec.yaml`](pubspec.yaml). Major ones
include:

| Package | Purpose |
|---|---|
| [`matrix`](https://pub.dev/packages/matrix) | Matrix Dart SDK (networking, sync, crypto) |
| [`flutter_vodozemac`](https://pub.dev/packages/flutter_vodozemac) | Native Olm/Megolm crypto bindings |
| [`provider`](https://pub.dev/packages/provider) | State management |
| [`go_router`](https://pub.dev/packages/go_router) | Declarative routing |
| [`lucide_icons_flutter`](https://pub.dev/packages/lucide_icons_flutter) | Icon set |
| [`shared_preferences`](https://pub.dev/packages/shared_preferences) | Settings persistence |

---

## License

Copyright (C) 2025 Surena Karimpour Ghannadi

This program is free software: you can redistribute it and/or modify it under
the terms of the **GNU Affero General Public License** as published by the Free
Software Foundation, either version 3 of the License, or (at your option) any
later version.

This program is distributed in the hope that it will be useful, but **without
any warranty**; without even the implied warranty of **merchantability** or
**fitness for a particular purpose**. See the GNU Affero General Public License
for more details.

---

## Contact

- **Repository:** [https://codeberg.org/SurenaSKQ/moonrelay](https://codeberg.org/SurenaSKQ/moonrelay)
- **Issue Tracker:** [https://codeberg.org/SurenaSKQ/moonrelay/issues](https://codeberg.org/SurenaSKQ/moonrelay/issues)
- **Author:** Surena Karimpour Ghannadi (via Matrix at @sudo_halt:matrix.org or Codeberg)
