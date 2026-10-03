#!/bin/sh
# release-prepare.sh — fold the pending .changes/new files into CHANGELOG.md and
# compute the next 0.x.y version. Used by the main-push release workflow (and
# callable locally as `task release:prepare`).
#
# Input : .changes/new/*.md   (pending change files; .gitkeep is not a match)
# Output: .changes/archive/<tag>/  — CI-owned; the released files are MOVED here
#
# It groups the category lines into Keep-a-Changelog sections, prepends a
# `## <tag> - <date>` block to CHANGELOG.md, moves the released files to the
# archive folder, and prints `new=<tag>` for the workflow.
#
# With nothing pending it prints `new=none` and changes nothing (exit 0).
# Exit non-zero on a malformed file.
#
# Versioning: the next version (and whether there is one at all) comes from
# newversion.sh — the single source of the 0.x.y rule. This script only folds
# the pending files into the changelog and moves them to the archive.

set -eu

ROOT=$(cd "$(dirname "$0")/../.." && pwd)
cd "$ROOT"

NEW_DIR=.changes/new
ARCHIVE_DIR=.changes/archive
CHANGELOG=CHANGELOG.md

fail() { echo "release: error: $*" >&2; exit 1; }

# --- collect pending files ------------------------------------------------
pending=""
for f in "$NEW_DIR"/*.md; do
  [ -f "$f" ] || continue
  pending="$pending $f"
done

if [ -z "$pending" ]; then
  echo "new=none"
  exit 0
fi

# --- validate category lines and collect them ----------------------------
lines_file=$(mktemp)
trap 'rm -f "$lines_file"' EXIT

for f in $pending; do
  bad=$(awk '
    /^[[:space:]]*$/ { next }
    !/^(NEW|BREAKING|DEPRECATED|FIX|SECURITY|PERFORMANCE|INTERNAL|DOCS):/ { print }
  ' "$f")
  [ -z "$bad" ] || fail "$f: line without a valid category: '$bad'"
  awk '/^(NEW|BREAKING|DEPRECATED|FIX|SECURITY|PERFORMANCE|INTERNAL|DOCS):/ { print }' "$f" >> "$lines_file"
done

[ -s "$lines_file" ] || fail "pending files have no category lines"

# --- derive the next version (single source: newversion.sh) ---------------
# Capture stdout and the exit code separately: a pipe would mask newversion's
# failure (POSIX sh has no pipefail).
out=$(sh "$ROOT/.github/scripts/newversion.sh") || fail "newversion.sh failed"
new=$(printf '%s\n' "$out" | grep '^new=' | cut -d= -f2)
[ -n "$new" ] || fail "newversion.sh did not report a version"

# Only non-releasing categories (INTERNAL, DOCS) pending: nothing to tag. The
# files stay in new/ and are released together with the next real change.
if [ "$new" = "none" ]; then
  echo "new=none"
  exit 0
fi
version=$new

today=$(date +%Y-%m-%d)

# --- build the grouped changelog entry -----------------------------------
entry_file=$(mktemp)
trap 'rm -f "$lines_file" "$entry_file"' EXIT

awk -v ver="$version" -v day="$today" '
  function section(cat) {
    if (cat == "NEW") return "Added"
    if (cat == "FIX") return "Fixed"
    if (cat == "SECURITY") return "Security"
    if (cat == "DEPRECATED") return "Deprecated"
    return "Changed"   # BREAKING, PERFORMANCE, INTERNAL, DOCS
  }
  {
    split($0, p, ":")
    cat = p[1]
    text = substr($0, length(cat) + 3)
    sec = section(cat)
    if (!(sec in seen)) { order[++n] = sec; seen[sec] = 1 }
    body[sec] = body[sec] "- " text "\n"
  }
  END {
    print "## " ver " - " day
    for (i = 1; i <= n; i++) {
      print ""
      print "### " order[i]
      print ""
      printf "%s", body[order[i]]
    }
  }
' "$lines_file" > "$entry_file"

# --- prepend to CHANGELOG.md ---------------------------------------------
old_body=$(mktemp)
trap 'rm -f "$lines_file" "$entry_file" "$old_body"' EXIT
if [ -f "$CHANGELOG" ]; then
  awk 'BEGIN{emit=0} /^## /{emit=1} emit{print}' "$CHANGELOG" > "$old_body"
fi

{
  printf '# Changelog\n\n'
  printf 'All notable changes to MojoAkku are documented in this file.\n\n'
  printf 'The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).\n'
  printf 'Versions stay on `0.x.y`; major is never bumped.\n\n'
  cat "$entry_file"
  printf '\n'
  cat "$old_body"
} > "$CHANGELOG.new"
mv "$CHANGELOG.new" "$CHANGELOG"

# --- archive the released files (CI-owned output) ------------------------
archive="$ARCHIVE_DIR/$version"
mkdir -p "$archive"
for f in $pending; do
  mv "$f" "$archive/"
done

echo "new=$version"
