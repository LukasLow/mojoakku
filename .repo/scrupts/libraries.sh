#!/bin/sh
# Shared mechanics only: the caller's directory determines the library.
set -eu

lib=$(basename "$PWD")
case "$lib" in
  ''|*[!a-z0-9_]*) echo "Invalid library directory: $lib" >&2; exit 1 ;;
esac
test -f __init__.mojo
root=$(cd ../.. && pwd)

case "${1:-}" in
  test)
    found=""
    for file in _tests/*.mojo; do
      [ -f "$file" ] || continue
      found=yes
      echo "== $file"
      mojo run -I "$root" "$file"
    done
    if [ -z "$found" ]; then
      echo "No tests yet in _tests/ (nothing to run)."
    else
      echo "All $lib tests passed."
    fi
    ;;
  compile)
    mkdir -p "$root/.tmp"
    checkdir=$(mktemp -d "$root/.tmp/${lib}.XXXXXX")
    trap 'rm -rf "$checkdir"' EXIT HUP INT TERM
    printf 'from akku.%s import *\n\ndef main():\n    pass\n' "$lib" > "$checkdir/check.mojo"
    mojo run -I "$root" "$checkdir/check.mojo"
    echo "$lib public API compiles."
    ;;
  *) echo "Unknown library command: ${1:-}" >&2; exit 2 ;;
esac
