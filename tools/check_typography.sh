#!/usr/bin/env bash
# Part of Moonrelay, a matrix protocol client.
# Copyright (C) 2025 Surena Karimpour Ghannadi

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as
# published by the Free Software Foundation, either version 3 of the
# License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.

# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

# Fails when forbidden typography sneaks back into the tree: em dashes,
# en dashes, non-breaking hyphens, UTF-8 BOMs, comment banner rules, and
# stray control characters. The dash lookalikes break search and copy in
# ways that are invisible to review.
#
# Usage: ./tools/check_typography.sh

set -uo pipefail

cd "$(dirname "$0")/.."

fail=0

check() {
  local label="$1" pattern="$2"
  shift 2
  local hits
  hits=$(grep -rnP "$pattern" "$@" 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "FAIL: $label found:"
    echo "$hits"
    fail=1
  else
    echo "OK: $label"
  fi
}

DART_DIRS=(lib test integration_test)
DOCS=(README.md CONTRIBUTING.md)
YAML=(.github/workflows)

check "em dash (U+2014)"      '\x{2014}'              "${DART_DIRS[@]}" "${DOCS[@]}" "${YAML[@]}"
check "en dash (U+2013)"      '\x{2013}'              "${DART_DIRS[@]}" "${DOCS[@]}" "${YAML[@]}"
check "nb hyphen (U+2010/11)" '[\x{2010}\x{2011}]'    "${DART_DIRS[@]}" "${DOCS[@]}" "${YAML[@]}"
check "arrow (U+2192)"        '\x{2192}'              "${DART_DIRS[@]}" "${DOCS[@]}" "${YAML[@]}"
check "BOM"                   '^\xEF\xBB\xBF'         "${DOCS[@]}"

# Box-drawing banners. One deliberate exception: html_tag_parser.dart
# emits U+2502 as a blockquote tree marker in rendered message HTML.
box_hits=$(grep -rnP '[\x{2500}-\x{257F}]' "${DART_DIRS[@]}" 2>/dev/null \
  | grep -vP "html_tag_parser\.dart:\d+:.*'\x{2502} '" || true)
if [ -n "$box_hits" ]; then
  echo "FAIL: box-drawing glyph found:"
  echo "$box_hits"
  fail=1
else
  echo "OK: box drawing (U+2500-257F)"
fi

# Section banner rules: a comment line made only of a repeated rule character.
# They carry no information and go stale silently when the section changes.
check "banner rule" '^\s*(//|\*)\s*[-=~_*\.]{6,}\s*$' "${DART_DIRS[@]}" "${DOCS[@]}"

# Stray C0 control characters and DEL. A past edit replaced the first letter
# of four identifiers with these, leaving `addTearDown` reading as
# `<BEL>ddTearDown`. They are invisible in review and in most editors.
check "control char" '[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]' "${DART_DIRS[@]}" "${DOCS[@]}" "${YAML[@]}"

exit "$fail"
