#!/usr/bin/env bash
# Read one flat top-level key from a profile yaml (profiles-yaml/*.yaml are
# always flat "key: value" lines, never nested — this is not a general YAML
# parser). Handles a value that's unquoted, double- or single-quoted, and an
# optional trailing `# comment` — checking for quotes first so a comment
# stripped from an unquoted value can't eat a quoted value's own `#rrggbb`
# hex digits.
#
# Usage: yaml-field.sh FILE KEY
set -euo pipefail

file="$1" key="$2"
raw="$(sed -n "s/^${key}:[[:space:]]*//p" "$file" | head -1)"
case "$raw" in
  \"*)
    raw="${raw#\"}"
    raw="${raw%%\"*}"
    ;;
  \'*)
    raw="${raw#\'}"
    raw="${raw%%\'*}"
    ;;
  *)
    raw="${raw%%#*}"
    raw="${raw%"${raw##*[![:space:]]}"}"
    ;;
esac
printf '%s' "$raw"
