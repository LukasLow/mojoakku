#!/bin/sh
# Phase-9 red baseline for mojoakku/base64.
# Runs every _tests/*.mojo with `mojo run`. In the red phase every file fails,
# but the failure reason matters: a stub abort (`ABORT: … not yet implemented`)
# is the expected pre-implementation state, while a compile/import error means
# the test file does not even type-check. Each failing file therefore reports a
# classified reason (stub abort vs compile/import error vs other) plus the
# captured message, so a later green run can be told apart from a broken one.
set -u
cd "$(dirname "$0")/../../.." || exit 1
total=0
failed=0
passed=0
stub_aborts=0
compile_errors=0
other_failures=0
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
for f in mojoakku/base64/_tests/test_*.mojo; do
  total=$((total + 1))
  echo "== mojo run -I mojoakku $f"
  # Capture combined stdout+stderr and the exit code. The informative abort
  # line goes to stdout, compile/import diagnostics go to stderr, so combined
  # capture classifies reliably.
  if mojo run -I mojoakku "$f" >"$tmp" 2>&1; then
    passed=$((passed + 1))
    echo "   result: PASS"
  else
    rc=$?
    failed=$((failed + 1))
    if grep -q "not yet implemented" "$tmp"; then
      reason="stub abort"
      stub_aborts=$((stub_aborts + 1))
      detail="$(grep -m1 "ABORT:" "$tmp")"
    elif grep -q "error:" "$tmp"; then
      reason="compile/import error"
      compile_errors=$((compile_errors + 1))
      detail="$(grep -m1 "error:" "$tmp")"
    else
      reason="other failure"
      other_failures=$((other_failures + 1))
      detail="$(head -n 1 "$tmp")"
    fi
    if [ -z "$detail" ]; then
      detail="(no message; exit $rc)"
    fi
    echo "   result: FAIL (exit $rc) [$reason] $detail"
  fi
done
echo "--------"
echo "baseline: $total files, $passed passed, $failed failed"
echo "  failures: $stub_aborts stub abort, $compile_errors compile/import error, $other_failures other"
exit 0
