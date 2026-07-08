# Moonrelay — releases, versioning, and packaging

This document explains how Moonrelay is versioned, how CI builds
artifacts, and how to cut a new release. The goal is **one source of
truth** (`pubspec.yaml`) and **everything else is derived**.

## 1. Versioning

We use a deliberately small, opinionated scheme:

| Field            | Rule                                                          |
|------------------|---------------------------------------------------------------|
| `MAJOR`          | Breaking changes (schema, settings, removed features).       |
| `MINOR`          | New features, backward compatible.                           |
| `PATCH`          | Bug fixes only.                                               |
| `-pre.alpha.N`   | Internal alphas; never expected to work for users.            |
| `-pre.beta.N`    | Public-ish preview before a stable MINOR.                     |

Stored as Flutter's standard `X.Y.Z+B` in `pubspec.yaml`. The `+B`
build suffix is kept for store-style auto-incrementing once we ship
mobile. For now `pubspec.yaml` shows `version: 0.6.0+0`.

```
$ grep ^version pubspec.yaml
version: 0.6.0+0
```

The build suffix is **never** used inside the .deb/.rpm/.msix package
because those formats forbid `+` and `-`. They're derived into:

| Format | Uses                            |
|--------|---------------------------------|
| .deb   | `0.6.0-1` (Release=1 for the rpm/dist tag)            |
| .rpm   | `0.6.0-1%{?dist}`                                            |
| MSIX   | `0.6.0.0` (always four parts; revision becomes the suffix)   |

The MSIX four-quad handling is documented in `package-windows.yml`
`Resolve version from pubspec.yaml` — pre-release labels like
`0.7.0-rc.1` resolve to `0.7.0.0` and the human label is preserved as
`<Identity>.DisplayVersion`.

## 2. Branches and tags

```
main (stable; PRs land here)         ── protected, requires CI green
└── feature/...                       ── short-lived
develop (integration)                 ── default branch in the repo today
└── feature/...
tag vX.Y.Z                            ── immutable, triggers release.yml
```

When `develop` is promoted to `main`, we make sure the merged commit
on `main` has `pubspec.yaml` set to the version we want to ship, then
tag `main`. **Never** tag a commit whose `pubspec.yaml` differs from
the tag — the release workflow enforces this via a hard check.

## 3. Cutting a release

The whole flow is two commands:

```bash
# 1. Bump the version in pubspec.yaml (on a stable branch).
./tools/release.sh minor      # 0.6.0 -> 0.7.0
git add pubspec.yaml
git commit -m "release: v0.7.0"
git push origin HEAD

# 2. Tag once CI is green. This triggers the release workflow.
./tools/release.sh tag        # creates v0.7.0
```

`release.yml` then:

1. Re-verifies `pubspec.yaml` matches the tag.
2. Calls `package-linux.yml` (matrix: ubuntu-jammy + fedora-39) in
   parallel.
3. Calls `package-windows.yml`.
4. Downloads the resulting `.deb`, `.rpm`, and `.msix` artifacts.
5. Creates a **draft** GitHub Release using
   `softprops/action-gh-release@v2` with auto-generated notes from
   `gh release notes`.

The release is created as `draft: true` because authors typically
want to write a changelog blurb before publishing. To also test
packaging without touching a tag:

```bash
# Manual dispatch from the Actions tab -> "Linux packaging"
#  -> enter "version_override" if you want to bypass pubspec.yaml.
```

## 4. CI matrix

`.github/workflows/`:

| File                  | Runs when                              | Purpose |
|-----------------------|----------------------------------------|---------|
| `tests.yml` (`ci`)    | push/PR to `main`, `master`, `develop` | analyze, unit, widget, integration, release-build smoke |
| `package-linux.yml`   | tag, manual, workflow_call             | .deb + .rpm via `package-linux.yml` matrixed containers |
| `package-windows.yml` | tag, manual, workflow_call             | MSIX via `makeappx.exe` |
| `release.yml`         | tag, manual                            | orchestrate + draft release |
| `deps.yml`            | weekly cron Mon 06:00 UTC + manual     | periodic dependency probes |

The CI uses Flutter `3.24.5` (pinned in env vars at the top of each
workflow). Bump it consciously; SDK-level regressions from a major
Flutter update are real.

### Branch protection — recommended (UI setting)

Set on `main`:

- "Require status checks to pass before merging" -> include
  `analyze-linux`, `analyze-windows`, `unit-linux`, `unit-windows`,
  `integration-linux`, `integration-windows`,
  `build-linux`, `build-windows`.
- "Require linear history" so squash/merge fast-forward keeps the
  pubspec monotonic.
- "Do not allow force pushes", "include administrators".

## 5. Packaging internals

### Linux

Two parallel containers in `package-linux.yml`:

| Container                  | Native tooling           | Output                       |
|----------------------------|--------------------------|------------------------------|
| `ghcr.io/jonathangjert/ubuntu-jammy`  | `dpkg-deb`, `fakeroot` | `moonrelay_<ver>_amd64.deb`  |
| `ghcr.io/jonathangjert/fedora-39`     | `rpmbuild`              | `moonrelay-<ver>-1.x86_64.rpm`|

Layout for both:

```
/usr/lib/moonrelay/...    # flutter build bundle
/usr/bin/moonrelay         # symlink -> ../lib/moonrelay/moonrelay
/usr/share/applications/moonrelay.desktop
/usr/share/icons/hicolor/256x256/apps/moonrelay.png
/usr/share/metainfo/io.github.surenaskq.moonrelay.appdata.xml
```

Dependency hints (libcurl, sqlite3, gtk3, jsoncpp) come from the
Flutter engine + Material ForwadingUI plugins. If a new plugin needs
a system lib, add it to both `linux/packaging/control` (Depends) and
`linux/packaging/moonrelay.spec` (Requires).

### Windows MSIX

`package-windows.yml`:

1. Run `flutter build windows --release`.
2. Stage under `stage/msix/VFS/ProgramFilesX64/Moonrelay/`.
3. Substitute `@VERSION@`, `@PUBLISHER@`, etc. into
   `windows/packaging/AppxManifest.xml.in`.
4. Call `makeappx pack /p out.msix /d stage/msix /v`.

The PowerShell script tries chocolatey and winget for the Windows 10
SDK. If neither path produces `makeappx.exe` (e.g. self-hosted
runners without admin), the job short-circuits with a warning —
manual repackaging with Visual Studio is still possible using the
provided `AppxManifest.xml.in`. The warning path is also what you
want for short-lived forks where MSIX signing isn't set up.

> **Signing**: Once a certificate is configured, add a `makeappx
> sign` step and provide the cert as a secret. Until then, MSIXs
> from CI are unsigned and will require "sideload" mode on the
> install machine.

## 6. When `pubspec.yaml` version drifts from a tag

`release.yml`'s `preflight` step runs:

```bash
PUB_VERSION="$(awk -F': *' '/^version:/{print $2; exit}' pubspec.yaml | cut -d'+' -f1 | tr -d '"')"
if [ "$PUB_VERSION" != "$VERSION" ]; then
  echo "::error::pubspec.yaml has '$PUB_VERSION', tag implies '$VERSION'"
  exit 1
fi
```

This is a hard guard. Bumping a tag without updating pubspec makes
the release fail loudly. Update pubspec first, push, then re-tag.

## 7. Maintenance cadence (suggested)

| Cadence       | Action                                                           |
|---------------|------------------------------------------------------------------|
| Weekly        | Merge `flutter_lints`, `flutter` SDK bumps.                      |
| Per feature   | `feature/x` → `develop`. CI green required.                       |
| Per release   | `release.sh {patch,minor,major}`, run, draft, publish.            |
| Per year      | Bump Flutter SDK floor in `pubspec.yaml` and pin `FLUTTER_VERSION` in workflows. |

### Where to spend time when you return after months away

1. Look at `WORK_NEEDED.md` (existing) — feature debt.
2. Run `flutter pub outdated` and check the major deps (`matrix`, `go_router`, `provider`).
3. Run `./tools/release.sh patch && git push` to make sure the
   pipeline still produces artifacts end-to-end; this catches SDK
   rot before you commit to a real release.
4. Promote `develop -> main` once stable.

## 8. Repository settings to flip on (UI)

- **Actions → General → Workflow permissions**: "Read and write
  permissions" (required so `release.yml` can draft releases).
- **Branch protection** on `main` (see section 4).
- **Tag protection** on `v*.*.*` to forbid force-pushes.
- **Environments**: create `production` with required reviewers
  before flipping `release.yml` from `draft: true` to `published`.
- **Secret**: `MOONRELAY_CERT_PFX_BASE64` for MSIX signing (when you
  get a code-signing cert).
