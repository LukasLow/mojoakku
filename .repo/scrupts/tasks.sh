#!/bin/sh
# Shell bodies extracted from Taskfiles; run in the calling task directory.
set -e
case "${1:-}" in
  changes:version)
    tag=$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' --sort=-v:refname | head -n1)
    [ -n "$tag" ] || tag=v0.0.0
    ver=${tag#v}
    minor=$(printf '%s' "$ver" | cut -d. -f2)
    patch=$(printf '%s' "$ver" | cut -d. -f3)
    [ -n "$minor" ] || minor=0
    [ -n "$patch" ] || patch=0
    bump=none
    any=""
    for f in .changes/new/*.md; do
      [ -f "$f" ] || continue
      any="yes"
      if grep -qE '^(NEW|BREAKING|DEPRECATED):' "$f"; then
        bump=minor
      elif [ "$bump" != "minor" ] && grep -qE '^(FIX|SECURITY|PERFORMANCE):' "$f"; then
        bump=patch
      fi
    done
    if [ -z "$any" ] || [ "$bump" = "none" ]; then
      echo "none"
    elif [ "$bump" = "minor" ]; then
      echo "0.$((minor + 1)).0"
    else
      echo "0.${minor}.$((patch + 1))"
    fi
    ;;
  todo)
    mode="${REPO_TODO_MODE:-}"
    [ -n "$mode" ] || mode="${REPO_CLI_ARGS:-}"
    case "$mode" in
      all|--all|reasons) mode=all ;;
      *) mode=strict ;;
    esac

    files=""
    for f in .repo/todo/*.yml; do
      [ -f "$f" ] || continue
      files="$files $f"
    done
    if [ -z "$files" ]; then
      echo "No catalogue files found yet (no .repo/todo/*.yml)."
      exit 0
    fi
    if [ ! -f mojo.yml ]; then
      echo "error: mojo.yml (capability ledger) is missing; cannot check mojoNeeds."
      exit 1
    fi

    # awk reads mojo.yml first (capability key -> state) and then every
    # catalogue file. A capability key is a 2-space-indented line ending in
    # ":"; the following "    state: <x>" line is its state. Comments and
    # blank lines are ignored.
    # The catalogue pass prints "<id>\t<name>[\t<reason>]": strict mode
    # prints only fully buildable libraries; all mode prints every
    # dependency-clear todo library with its reason.
    out=$(awk -v mode="$mode" '
      function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t\r]+$/, "", s); return s }
      function flush() {
        if (id != "") {
          order[++n] = id; name_of[id] = name; status_of[id] = status
          deps_of[id] = deps; needs_of[id] = needs
        }
        id = ""; name = ""; status = ""; deps = ""; needs = ""
      }
      # ---- phase 1: capability ledger ----
      FILENAME == "mojo.yml" {
        if ($0 ~ /^  [a-z][a-z0-9-]*:[ \t]*$/) {
          key = $0; sub(/^  /, "", key); sub(/:[ \t]*$/, "", key); cur = key; next
        }
        if ($0 ~ /^    state:/) {
          line = $0; sub(/^    state:[ \t]*/, "", line); state_of[cur] = trim(line); next
        }
        next
      }
      # ---- phase 2: catalogue files ----
      FNR == 1 { flush() }
      /^id:/         { line = $0; sub(/^id:[ \t]*/,         "", line); id     = trim(line) }
      /^name:/       { line = $0; sub(/^name:[ \t]*/,       "", line); name   = trim(line) }
      /^status:/     { line = $0; sub(/^status:[ \t]*/,     "", line); status = trim(line) }
      /^depends_on:/ { line = $0; sub(/^depends_on:[ \t]*/, "", line); deps   = trim(line) }
      /^mojoNeeds:/  { line = $0; sub(/^mojoNeeds:[ \t]*/,  "", line); needs  = trim(line) }
      END {
        flush()
        for (i = 1; i <= n; i++) {
          id = order[i]
          if (status_of[id] != "todo") continue
          # condition 2: every dependency done
          raw = deps_of[id]; gsub(/^\[/, "", raw); gsub(/\]$/, "", raw)
          cnt = split(raw, parts, ",")
          deps_ok = 1
          for (j = 1; j <= cnt; j++) {
            dep = trim(parts[j])
            if (dep == "") continue
            if (status_of[dep] != "done") deps_ok = 0
          }
          if (!deps_ok) continue
          # condition 3: every mojoNeeds key is state have
          raw = needs_of[id]; gsub(/^\[/, "", raw); gsub(/\]$/, "", raw)
          cnt = split(raw, parts, ",")
          caps_ok = 1; missing = ""
          for (j = 1; j <= cnt; j++) {
            need = trim(parts[j])
            if (need == "") continue
            st = state_of[need]
            if (st != "have") {
              caps_ok = 0
              label = need " (" (st == "" ? "unknown" : st) ")"
              missing = (missing == "" ? label : missing ", " label)
            }
          }
          if (mode == "all") {
            print id "\t" name_of[id] "\t" (caps_ok ? "ready" : "needs " missing)
          } else if (caps_ok) {
            print id "\t" name_of[id]
          }
        }
      }
    ' mojo.yml $files | sort | awk -F'\t' '{ if ($1 == "") next; if (NF >= 3 && $3 != "") printf "%s  %s  -> %s\n", $1, $2, $3; else printf "%s  %s\n", $1, $2 }')
    if [ "$mode" = "all" ]; then
      if [ -z "$out" ]; then
        echo "Nothing to show: no library is clear of its dependencies yet."
      else
        printf '%s\n' "$out"
      fi
    elif [ -z "$out" ]; then
      echo "Nothing is ready to build yet."
      echo "Every remaining library waits for a dependency that is not done, or a Mojo capability that is not 'have'."
      echo "Run 'task todo -- --all' to see the dependencies-clear libraries and their blocking reason."
    else
      printf '%s\n' "$out"
    fi
    ;;
  mojoHave)
    if [ ! -f mojo.yml ]; then
      echo "error: mojo.yml not found."
      exit 1
    fi
    awk '
      /^  [a-z][a-z0-9-]*:[ \t]*$/ { key = $0; sub(/^  /, "", key); sub(/:[ \t]*$/, "", key); cur = key; next }
      /^    state:/ { line = $0; sub(/^    state:[ \t]*/, "", line); gsub(/[ \t\r]+$/, "", line); if (line == "have") print cur }
    ' mojo.yml | sort
    ;;
  current)
    files=""
    for f in .repo/todo/*.yml; do
      [ -f "$f" ] || continue
      files="$files $f"
    done
    if [ -z "$files" ]; then
      echo "No catalogue files found yet (no .repo/todo/*.yml)."
      exit 0
    fi
    awk '
      function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t\r]+$/, "", s); return s }
      function flush() {
        if (id != "") { order[++n] = id; name_of[id] = name; status_of[id] = status }
        id = ""; name = ""; status = ""
      }
      FNR == 1 { flush() }
      /^id:/     { line = $0; sub(/^id:[ \t]*/,     "", line); id     = trim(line) }
      /^name:/   { line = $0; sub(/^name:[ \t]*/,   "", line); name   = trim(line) }
      /^status:/ { line = $0; sub(/^status:[ \t]*/, "", line); status = trim(line) }
      END {
        flush()
        for (i = 1; i <= n; i++) if (status_of[order[i]] == "current") print order[i] "\t" name_of[order[i]]
      }
    ' $files | sort | awk -F'\t' 'NF > 0 { printf "%s  %s\n", $1, $2 }'
    ;;
  all)
    files=""
    for f in .repo/todo/*.yml; do
      [ -f "$f" ] || continue
      files="$files $f"
    done
    if [ -z "$files" ]; then
      echo "No catalogue files found yet (no .repo/todo/*.yml)."
      exit 0
    fi
    awk '
      function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t\r]+$/, "", s); return s }
      function flush() {
        if (id != "") print id "\t" status "\t" name
        id = ""; name = ""; status = ""
      }
      FNR == 1 { flush() }
      /^id:/     { line = $0; sub(/^id:[ \t]*/,     "", line); id     = trim(line) }
      /^name:/   { line = $0; sub(/^name:[ \t]*/,   "", line); name   = trim(line) }
      /^status:/ { line = $0; sub(/^status:[ \t]*/, "", line); status = trim(line) }
      END { flush() }
    ' $files | sort | awk -F'\t' '{ printf "%s  %s  %s\n", $1, $2, $3 }'
    ;;
  count)
    files=""
    for f in .repo/todo/*.yml; do
      [ -f "$f" ] || continue
      files="$files $f"
    done
    if [ -z "$files" ]; then
      echo "No catalogue files found yet (no .repo/todo/*.yml)."
      exit 0
    fi
    awk '
      function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t\r]+$/, "", s); return s }
      function flush() {
        if (id != "") print status
        id = ""; status = ""
      }
      FNR == 1 { flush() }
      /^id:/     { line = $0; sub(/^id:[ \t]*/,     "", line); id     = trim(line) }
      /^status:/ { line = $0; sub(/^status:[ \t]*/, "", line); status = trim(line) }
      END { flush() }
    ' $files | awk '
      { if ($0 != "") { c[$0]++; total++ } }
      END {
        printf "MojoAkku catalogue: %d libraries\n\n", total
        printf "%-10s %d\n", "todo:", c["todo"] + 0
        printf "%-10s %d\n", "current:", c["current"] + 0
        printf "%-10s %d\n", "done:", c["done"] + 0
        printf "%-10s %d\n", "total:", total + 0
      }
    '
    ;;
  waiting)
    files=""
    for f in .repo/todo/*.yml; do
      [ -f "$f" ] || continue
      files="$files $f"
    done
    if [ -z "$files" ]; then
      echo "No catalogue files found yet (no .repo/todo/*.yml)."
      exit 0
    fi
    out=$(awk '
      function trim(s) { gsub(/^[ \t]+/, "", s); gsub(/[ \t\r]+$/, "", s); return s }
      function flush() {
        if (id != "") { order[++n] = id; name_of[id] = name; status_of[id] = status; deps_of[id] = deps }
        id = ""; name = ""; status = ""; deps = ""
      }
      FNR == 1 { flush() }
      /^id:/         { line = $0; sub(/^id:[ \t]*/,         "", line); id     = trim(line) }
      /^name:/       { line = $0; sub(/^name:[ \t]*/,       "", line); name   = trim(line) }
      /^status:/     { line = $0; sub(/^status:[ \t]*/,     "", line); status = trim(line) }
      /^depends_on:/ { line = $0; sub(/^depends_on:[ \t]*/, "", line); deps   = trim(line) }
      END {
        flush()
        for (i = 1; i <= n; i++) {
          id = order[i]
          if (status_of[id] == "done") continue
          raw = deps_of[id]
          gsub(/^\[/, "", raw); gsub(/\]$/, "", raw)
          cnt = split(raw, parts, ",")
          missing = ""
          for (j = 1; j <= cnt; j++) {
            dep = trim(parts[j])
            if (dep == "") continue
            if (status_of[dep] != "done") {
              label = dep
              if (!(dep in status_of)) label = dep " (no file)"
              missing = (missing == "" ? label : missing ", " label)
            }
          }
          if (missing != "") print id "\t" status_of[id] "\t" name_of[id] "\t" missing
        }
      }
    ' $files | sort | awk -F'\t' '{ printf "%s  %s  %s  -> waiting for: %s\n", $1, $2, $3, $4 }')
    if [ -z "$out" ]; then
      echo "No library is waiting for a dependency."
    else
      printf '%s\n' "$out"
    fi
    ;;
  show)
    id="${REPO_CLI_ARGS:-}"
    if [ -z "$id" ]; then
      echo "error: no library id given."
      echo "usage: task show -- <id>"
      exit 1
    fi
    file=".repo/todo/${id}.yml"
    if [ ! -f "$file" ]; then
      echo "error: no catalogue file for id '${id}' (looked for ${file})."
      echo "Run 'task all' to see every known id."
      exit 1
    fi
    awk '{ print }' "$file"
    ;;
  missingMojo)
    allmode=0
    checkmode=0
    case "${REPO_CLI_ARGS:-}" in
      all) allmode=1 ;;
      check) checkmode=1 ;;
    esac

    # --- resolve the installed Mojo version (binary first, pin second) ---
    cur=$(mojo --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    if [ -z "$cur" ] && [ -f pixi.toml ]; then
      cur=$(grep -E '^[[:space:]]*mojo[[:space:]]*=' pixi.toml | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -n1)
    fi
    [ -n "$cur" ] || cur=0.0.0
    curN=$(printf '%s' "$cur" | awk -F. '{ printf "%d", ($1*1000+$2)*1000+$3 }')

    files=$(find akku -name '*.mojo' -type f 2>/dev/null | sort)
    if [ -z "$files" ]; then
      echo "No Mojo sources under akku/ (nothing to scan)."
      exit 0
    fi

    out=$(printf '%s\n' "$files" | while IFS= read -r f; do
      [ -f "$f" ] || continue
      awk -v allmode="$allmode" -v curN="$curN" '
        function norm(v,   n, a, i, s) {
          sub(/^v/, "", v)
          n = split(v, a, ".")
          s = 0
          for (i = 1; i <= 3; i++) s = s * 1000 + (a[i] + 0)
          return s
        }
        function flush() {
          if (curfile != "") printf "@@COUNT@ %d %d\n", found, (stale + 0)
        }
        FNR == 1 { flush(); curfile = FILENAME; inblock = 0; found = 0 }
        /MissingMojo/ && /- *v[0-9]/ && /Start/ {
          inblock = 1
          startln = FNR
          ver = ""
          if (match($0, /v[0-9]+(\.[0-9]+)*/)) { ver = substr($0, RSTART, RLENGTH); sub(/^v/, "", ver) }
          kind = ""; need = ""; optimal = ""; track = ""
          next
        }
        /MissingMojo/ && /End/ {
          if (inblock) {
            found++
            if (allmode == 1 || norm(ver) < curN) {
              printf "%s:%d  v%s  kind=%s\n", FILENAME, startln, ver, kind
              printf "    need:    %s\n", need
              printf "    optimal: %s\n", optimal
              if (track != "") printf "    track:   %s\n", track
              printf "\n"
              stale++
            }
          }
          inblock = 0
          next
        }
        inblock && /^[[:space:]]*#/ {
          line = $0
          sub(/^[[:space:]]*#[[:space:]]*/, "", line)
          p = index(line, ":")
          if (p > 0) {
            key = substr(line, 1, p - 1)
            val = substr(line, p + 1)
            gsub(/^[[:space:]]+/, "", key); gsub(/[[:space:]]+$/, "", key)
            gsub(/^[[:space:]]+/, "", val); gsub(/[[:space:]]+$/, "", val)
            if (key == "kind") kind = val
            else if (key == "need") need = val
            else if (key == "optimal") optimal = val
            else if (key == "track") track = val
          }
        }
        END { flush() }
      ' "$f"
    done)

    total=$(printf '%s\n' "$out" | grep -E '^@@COUNT@ ' | awk '{s += $2} END {print s + 0}' || true)
    stale=$(printf '%s\n' "$out" | grep -E '^@@COUNT@ ' | awk '{s += $3} END {print s + 0}' || true)
    body=$(printf '%s\n' "$out" | grep -vE '^@@COUNT@ ' || true)

    if [ "$allmode" -eq 1 ]; then
      echo "MissingMojo: all ${total} marker(s) (installed Mojo ${cur}):"
    elif [ "$stale" -eq 0 ]; then
      echo "MissingMojo: clean. ${total} marker(s), none older than installed Mojo ${cur}."
      exit 0
    else
      echo "MissingMojo: ${stale} of ${total} marker(s) older than installed Mojo ${cur}:"
    fi
    echo ""
    printf '%s\n' "$body"
    echo "Action: upgrade the site if the feature now exists, or re-stamp the"
    echo "version to v${cur} if it is still missing. See .agents/workflows/MissingMojo.md."

    # Strict gate: `task missingMojo -- check` fails (exit 1) when any marker
    # is stale. This is what `task ci` runs, so CI turns red instead of
    # silently keeping a workaround whose feature may already exist.
    if [ "$checkmode" -eq 1 ] && [ "$stale" -ne 0 ]; then
      echo ""
      echo "missingMojo: FAIL — ${stale} marker(s) older than installed Mojo ${cur}."
      echo "Upgrade each site, or re-stamp it to v${cur} if Mojo still lacks the feature."
      exit 1
    fi
    ;;
  *) echo "Unknown script command: ${1:-}" >&2; exit 2 ;;
esac
