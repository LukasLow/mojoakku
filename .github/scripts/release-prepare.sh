#!/bin/sh
# release-prepare.sh — fold the pending .changes/new files into CHANGELOG.md and
# compute the next 0.x.y version. Used by the main-push release workflow (and
# callable locally as `task release:prepare`).
#
# Input : .changes/new/*.md   (pending; NOT .gitkeep, NOT README)
# Output: .changes/archive/<tag>/  — CI-owned; the released files are MOVED here
#
# It groups the category lines into Keep-a-Changelog sections, prepends a
# `## <tag> - <date>` block to CHANGELOG.md, moves the released files to the
# archive folder, and prints `new=<tag>` for the workflow.
#
# With nothing pending it prints `new=none` and changes nothing (exit 0).
# Exit non-zero on a malformed file.
#
# Versioning: MojoAkku stays on 0.x.y; major is never bumped.
#   NEW / BREAKING / DEPRECATED present -> minor (0.(x+1).0)
#   only FIX/SECURITY/PERFORMANCE/INTERNAL -> patch (0.x.(y+1))

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
  case "$f" in
    "$NEW_DIR"/README.md) continue ;;
  esac
  pending="$pending $f"
done

if [ -z "$pending" ]; then
  echo "new=none"
  exit 0
fi

# --- validate category lines and collect them ----------------------------
lines_file=$(mktemp)
trap 'rm -f "$lines_file"' EXIT

bump=patch
for f in $pending; do
  bad=$(awk '
    /^[[:space:]]*$/ { next }
    !/^(NEW|BREAKING|DEPRECATED|FIX|SECURITY|PERFORMANCE|INTERNAL):/ { print }
  ' "$f")
  [ -z "$bad" ] || fail "$f: line without a valid category: '$bad'"
  if grep -qE '^(NEW|BREAKING|DEPRECATED):' "$f"; then
    bump=minor
  fi
  awk '/^(NEW|BREAKING|DEPRECATED|FIX|SECURITY|PERFORMANCE|INTERNAL):/ { print }' "$f" >> "$lines_file"
done

[ -s "$lines_file" ] || fail "pending files have no category lines"

# --- compute the next version --------------------------------------------
current=$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n1)
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
    return "Changed"   # BREAKING, PERFORMANCE, INTERNAL
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
