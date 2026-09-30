#!/bin/sh
# Run from the repository root; task namespace:test pins that directory.
set -eu

test -d akku
if test -e mojoakku || test -e mojoakku.mojo || test -e mojoakku.mojoc; then
  echo "namespace: FAIL — the removed source root or a compatibility alias exists."
  exit 1
fi

mojo run -I . .github/tests/test_namespace.mojo

output=$(mktemp)
trap 'rm -f "$output"' EXIT HUP INT TERM
if mojo run -I . .github/tests/legacy_namespace.mojo >"$output" 2>&1; then
  echo "namespace: FAIL — the removed import still resolves."
  exit 1
fi
if ! grep -q "unable to locate module 'mojoakku'" "$output"; then
  echo "namespace: FAIL — legacy fixture failed for an unexpected reason."
  cat "$output"
  exit 1
fi
echo "namespace: akku imports passed; removed namespace rejected."
