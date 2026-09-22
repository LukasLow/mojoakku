#!/bin/sh
# Phase-9 red baseline for mojoakku/base64.
# Runs every _tests/*.mojo with `mojo run`; stubs abort, so each file exits
# non-zero. Prints the exact command and the pass/fail counts.
set -u
cd "$(dirname "$0")/../../.." || exit 1
total=0
failed=0
passed=0
for f in mojoakku/base64/_tests/test_*.mojo; do
  total=$((total + 1))
  echo "== mojo run -I mojoakku $f"
  if mojo run -I mojoakku "$f" >/dev/null 2>&1; then
    passed=$((passed + 1))
    echo "   result: PASS"
  else
    failed=$((failed + 1))
    echo "   result: FAIL (non-zero exit)"
  fi
done
echo "--------"
echo "baseline: $total files, $passed passed, $failed failed"
exit 0
