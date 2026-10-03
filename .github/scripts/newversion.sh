#!/bin/sh
# newversion.sh — the single source of version derivation. Every consumer
# (release-prepare.sh, `task changes:version`) calls this script instead of
# repeating the rule.
#
# Input : the current highest `vX.Y.Z` tag and the categories in
#         `.changes/new/*.md` (pending change files).
# Output (stdout, exactly one line):
#   new=vX.Y.Z   the next version
#   new=none     nothing releasable (no files, or only INTERNAL/DOCS)
#
# Rules: MojoAkku stays on 0.x.y; major is never bumped.
#   any NEW / BREAKING / DEPRECATED                  -> minor (0.(x+1).0)
#   only FIX / SECURITY / PERFORMANCE                -> patch (0.x.(y+1))
#   only INTERNAL / DOCS, or no pending file         -> none
# Exit non-zero on a current tag that is not v0.x.y.

set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

NEW_DIR=.changes/new

fail() { echo "newversion: error: $*" >&2; exit 1; }

# --- decide the bump from the pending change files ------------------------
bump=none
found=0
for f in "$NEW_DIR"/*.md; do
  [ -f "$f" ] || continue
  found=1
  if grep -qE '^(NEW|BREAKING|DEPRECATED):' "$f"; then
    bump=minor
  elif [ "$bump" != "minor" ] && grep -qE '^(FIX|SECURITY|PERFORMANCE):' "$f"; then
    bump=patch
  fi
done

if [ "$found" -eq 0 ] || [ "$bump" = "none" ]; then
  echo "new=none"
  exit 0
fi

# --- compute the next version from the current tag ------------------------
current=$(git for-each-ref --format='%(refname:short)' --sort=-version:refname \
  'refs/tags/v[0-9]*.[0-9]*.[0-9]*' | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | head -n1 || true)
[ -n "$current" ] || current=v0.0.0
version=$(printf '%s\n' "$current" | awk -v bump="$bump" -F. '
  {
    major = $1; sub(/^v/, "", major)
    minor = $2; patch = $3
    if (major != 0) { print "ERROR_MAJOR_NOT_ZERO" > "/dev/stderr"; exit 1 }
    if (bump == "minor") { minor = minor + 1; patch = 0 }
    else { patch = patch + 1 }
    printf "v%d.%d.%d\n", major, minor, patch
  }') || fail "current tag must be v0.x.y, got '$current'"

echo "new=$version"
