#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────────────
# Moonrelay release script
#
# Usage:
#   ./tools/release.sh patch       0.6.0 -> 0.6.1
#   ./tools/release.sh minor       0.6.0 -> 0.7.0
#   ./tools/release.sh major       0.6.0 -> 1.0.0
#   ./tools/release.sh set 0.7.0-rc.1
#   ./tools/release.sh tag         (commit + push the current version)
#   ./tools/release.sh alpha|beta|stable
#
# Single source of truth: `pubspec.yaml`. This script only edits that
# file, and `pkg-locking` is left to Flutter tooling. CI rebuilds
# artifacts from the committed `pubspec.yaml`, never from the tag.
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

cwd="$(cd "$(dirname "$0")/.." && pwd)"
cd "$cwd"

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
err()  { printf '\033[31mERROR:\033[0m %s\n' "$*" >&2; }
ok()   { printf '\033[32mOK:\033[0m %s\n' "$*"; }

# ── Helpers ──────────────────────────────────────────────────────────────
read_version() {
  awk -F': *' '/^version:/{print $2; exit}' pubspec.yaml | tr -d '"' | cut -d'+' -f1
}

write_version() {
  local v="$1"
  python3 - "$v" <<'PY' 2>/dev/null || perl -i -pe "s|^version: .*|version: $v|" pubspec.yaml
import re, sys
v = sys.argv[1]
src = open('pubspec.yaml').read()
new = re.sub(r'^version: .*$', f'version: {v}', src, count=1, flags=re.M)
open('pubspec.yaml', 'w').write(new)
PY
}

check_clean_tree() {
  if ! git diff --quiet -- pubspec.yaml; then
    err "pubspec.yaml has uncommitted changes. Commit or stash first."
    exit 1
  fi
}

ensure_main_branch() {
  local br; br="$(git rev-parse --abbrev-ref HEAD)"
  if [ "$br" != "main" ] && [ "$br" != "master" ] && [ "$br" != "develop" ]; then
    err "On branch '$br'. Switch to main/master/develop first."
    exit 1
  fi
}

# ── Commands ─────────────────────────────────────────────────────────────
cmd="${1:-help}"
case "$cmd" in
  patch|minor|major)
    ensure_main_branch
    cur="$(read_version)"
    semver=( ${cur//./ } )
    # Drop pre-release suffix for arithmetic.
    base="${cur%%-*}"
    IFS='.' read -r ma mi pa <<<"$base"
    case "$cmd" in
      patch) pa=$((pa+1)) ;;
      minor) mi=$((mi+1)); pa=0 ;;
      major) ma=$((ma+1)); mi=0; pa=0 ;;
    esac
    new="$ma.$mi.$pa"
    write_version "$new"
    ok "Bumped $cur -> $new"
    bold "Next: review, then ./tools/release.sh tag"
    ;;
  set)
    [ -n "${2:-}" ] || { err "usage: release.sh set X.Y.Z[ -pre ]"; exit 1; }
    ensure_main_branch
    cur="$(read_version)"
    new="$2"
    write_version "$new"
    ok "Set $cur -> $new"
    ;;
  alpha|beta|stable)
    ensure_main_branch
    cur="$(read_version)"
    base="${cur%%-*}"
    pre="${cur#*-}"
    case "$cmd" in
      alpha) new="${base%.*}.$((10#${base##*.}+1))-alpha.0" ;;
      beta)  new="$base-beta.1" ;;
      stable) new="$base" ;;
    esac
    write_version "$new"
    ok "Stage $cur -> $new"
    ;;
  tag)
    ensure_main_branch
    v="$(read_version)"
    [ -n "$v" ] || { err "No version found in pubspec.yaml"; exit 1; }
    git diff --quiet -- pubspec.yaml || git add pubspec.yaml
    git commit -m "release: v$v" || true
    git tag -a "v$v" -m "v$v"
    bold "Pushing tag (you can --set-upstream once if needed)..."
    git push origin HEAD || true
    git push origin "v$v" || true
    ok "Tagged v$v — release workflow should fire momentarily."
    ;;
  help|--help|-h|*)
    cat <<EOF
Moonrelay release helpers

  patch                  -> bump patch (0.6.0 -> 0.6.1)
  minor                  -> bump minor (0.6.0 -> 0.7.0)
  major                  -> bump major (0.6.0 -> 1.0.0)
  set <X.Y.Z[-pre]>      -> set explicit version
  alpha | beta | stable  -> cycle pre-release stage
  tag                    -> commit + push tag vX.Y.Z (fires release.yml)

The version lives in \`pubspec.yaml\`. CI reads it directly — never
edit windows/Runner.rc, debian/changelog, or .spec by hand.
EOF
    ;;
esac
