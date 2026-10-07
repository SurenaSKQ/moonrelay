# Releases, versioning and packaging

`pubspec.yaml` holds the version. Everything else derives from it, and CI fails
the release if a tag disagrees with it.

## Versioning

| Field | Rule |
|-------|------|
| `MAJOR` | Breaking changes: schema, settings, removed features. |
| `MINOR` | New features, backward compatible. |
| `PATCH` | Bug fixes only. |
| `-pre.alpha.N` | Internal builds. Not expected to work for users. |
| `-pre.beta.N` | Preview ahead of a stable `MINOR`. |

Stored as Flutter's `X.Y.Z+B` in `pubspec.yaml`. The `+B` build suffix is
reserved for store-style auto-incrementing if mobile ever happens.

```
$ grep ^version pubspec.yaml
version: 0.6.0+0
```

`.deb`, `.rpm` and `.msix` forbid `+` and `-`, so the packages derive their own:

| Format | Version used |
|--------|--------------|
| `.deb` | `0.6.0-1` |
| `.rpm` | `0.6.0-1%{?dist}` |
| MSIX | `0.6.0.0`, with the release becoming the revision field |

`package-windows.yml` resolves the four-quadrant MSIX version itself: a
pre-release label such as `0.7.0-rc.1` becomes `0.7.0.0`, and the human label is
kept as `<Identity>.DisplayVersion`.

## Branches and tags

```
master   stable; pull requests land here after develop is promoted
develop   integration; the default branch today
tag vX.Y.Z   immutable, triggers release.yml
```

Before tagging, set `pubspec.yaml` on `master` to the version you are shipping.
The release workflow compares the two and refuses to continue if they differ.

## Cutting a release

```bash
# 1. Bump the version on the stable branch.
./tools/release.sh minor      # 0.6.0 becomes 0.7.0
git add pubspec.yaml
git commit -m "release: v0.7.0"
git push origin HEAD

# 2. Tag once CI is green. This starts the release workflow.
./tools/release.sh tag        # creates v0.7.0
```

`release.yml` then re-verifies the version against `pubspec.yaml`, calls
`package-linux.yml` (ubuntu-jammy and fedora-39 in parallel) and
`package-windows.yml`, collects the `.deb`, `.rpm` and `.msix` artifacts, and
creates a **draft** GitHub Release with notes from `gh release notes`. The draft
is deliberate: the release blurb is usually worth writing by hand.

To exercise packaging without cutting a tag, dispatch `package-linux.yml`
manually from the Actions tab. It takes a `version_override` input for testing a
version that is not in `pubspec.yaml`.

## CI workflows

| File | Runs on | Purpose |
|------|---------|---------|
| `tests.yml` | push and pull request to `main`, `master`, `develop` | analyze, unit, widget, integration, release-build smoke |
| `package-linux.yml` | tag, manual, `workflow_call` | `.deb` and `.rpm` |
| `package-windows.yml` | tag, manual, `workflow_call` | MSIX via `makeappx.exe` |
| `release.yml` | tag, manual | orchestrates the above, drafts the release |
| `deps.yml` | weekly cron, Monday 06:00 UTC | dependency probes |

The Flutter pin is currently inconsistent. `tests.yml` and
`package-windows.yml` use `3.44.6`; `package-linux.yml` still says `3.24.5`.
Bring them to one value before the next release. A major Flutter bump has broken
the build before, so treat the change as deliberate rather than routine.

### Branch protection on `master`

- Require status checks before merging: `analyze-linux`, `analyze-windows`,
  `unit-linux`, `unit-windows`, `integration-linux`, `integration-windows`,
  `build-linux`, `build-windows`.
- Require linear history, so the version in `pubspec.yaml` only ever moves
  forward.
- Disallow force pushes, including for administrators.

## Packaging internals

### Linux

Two containers run in parallel. `ghcr.io/jonathangjert/ubuntu-jammy` builds the
`.deb` with `dpkg-deb` and `fakeroot`; `ghcr.io/jonathangjert/fedora-39` builds
the `.rpm` with `rpmbuild`.

Both lay out the same tree:

```
/usr/lib/moonrelay/...    the Flutter build bundle
/usr/bin/moonrelay         symlink to ../lib/moonrelay/moonrelay
/usr/share/applications/moonrelay.desktop
/usr/share/icons/hicolor/256x256/apps/moonrelay.png
/usr/share/metainfo/io.github.surenaskq.moonrelay.appdata.xml
```

System library dependencies come from the Flutter engine and its Material Linux
plugins. When a plugin starts needing a system library, add it to both
`linux/packaging/control` (`Depends`) and `linux/packaging/moonrelay.spec`
(`Requires`).

### Windows MSIX

`package-windows.yml` runs `flutter build windows --release`, stages the output
under `stage/msix/VFS/ProgramFilesX64/Moonrelay/`, substitutes `@VERSION@` and
friends into `windows/packaging/AppxManifest.xml.in`, and calls
`makeappx pack /p out.msix /d stage/msix /v`.

The PowerShell script looks for the Windows 10 SDK through chocolatey and winget.
If neither yields `makeappx.exe`, as on a self-hosted runner without admin, the
job logs a warning and stops. Packing by hand from Visual Studio still works
using the same `AppxManifest.xml.in`.

**Signing.** Once there is a certificate, add a `makeappx sign` step and pass
the certificate in as a secret. Until then CI produces unsigned MSIX packages,
and the install machine has to have sideloading enabled.

## When `pubspec.yaml` drifts from the tag

The `preflight` step in `release.yml` runs:

```bash
PUB_VERSION="$(awk -F': *' '/^version:/{print $2; exit}' pubspec.yaml | cut -d'+' -f1 | tr -d '"')"
if [ "$PUB_VERSION" != "$VERSION" ]; then
  echo "::error::pubspec.yaml has '$PUB_VERSION', tag implies '$VERSION'"
  exit 1
fi
```

This is a hard stop, so a tag that points at the wrong commit fails loudly
rather than publishing a mislabelled package. Fix `pubspec.yaml`, push, and
re-tag.

## Repository settings

Settings in the GitHub UI, none of which can be set from the repository:

- **Settings, then Actions, then General, then Workflow permissions**: set "Read
  and write permissions". `release.yml` cannot draft a release without it.
- **Settings, then Branches**: protect `master`, as above.
- **Settings, then Rules, then Tags**: protect `v*.*.*` against force-pushes.
- **Settings, then Environments**: create `production` with required reviewers
  before switching `release.yml` from `draft: true` to `published`.
- **Settings, then Secrets**: add `MOONRELAY_CERT_PFX_BASE64` once there is a
  signing certificate.

## Coming back after a few months

1. Read the open issues for the current state of the work.
2. Run `flutter pub outdated` and check the majors: `matrix`, `go_router`,
   `provider`.
3. Run `./tools/release.sh patch && git push` and let the pipeline produce
   artifacts. This catches toolchain drift before you plan a real release.
4. Promote `develop` to `master` once it is stable.