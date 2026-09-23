# MissingMojo — version-stamped workaround ledger

## Purpose

Mojo is young. Some things MojoAkku needs are either not in Mojo yet, are
unstable, or are only reachable through a foreign boundary (C ABI, Python
interop). `MissingMojo` is the mechanism that keeps every such place **visible
and version-stamped**, so that when Mojo gains the feature, we find the sites to
upgrade instead of forgetting them.

One sentence: **a MissingMojo marker records where Mojo was not enough, at which
Mojo version that was last true, and what the optimal solution would look like.**

This replaces the idea of a buch page: the ledger lives in the code as comments
and is surfaced by the task `task missingMojo`.

## What a marker is

A marker is a comment block inside a Mojo source file. It marks the smallest
possible region — the exact function, expression or design decision that exists
only because Mojo lacks something.

```mojo
# MissingMojo - v1.0.0 - Start
# kind: FFI
# need: a stable Mojo event-loop / readiness API (epoll/kqueue wrappers)
# optimal: replace the C syscall shim with the native Mojo API
# track: https://mojolang.org/docs/roadmap/
# MissingMojo - End
```

The block is data, not prose. Every line except the first and last is a
`# <key>: <value>` pair. The scanner reads exactly these fields.

## Field reference

| Line | Required | Meaning |
| --- | --- | --- |
| `# MissingMojo - v<version> - Start` | yes | Opens the block. `<version>` is the Mojo version **at which this marker was last confirmed true**. Accepts `v1.0` or `v1.0.0`. |
| `# kind: <KIND>` | yes | One of `FFI`, `PythonInterop`, `UnstableAPI`, `Deferred` (see below). |
| `# need: <text>` | yes | What Mojo must provide to remove the workaround. |
| `# optimal: <text>` | yes | What the code looks like once `need` exists. |
| `# track: <ref>` | no | A roadmap/issue/source reference. |
| `# MissingMojo - End` | yes | Closes the block. |

`kind` values:

- **`FFI`** — the code crosses the C ABI (`external_call`, `OwnedDLHandle`,
  `@export`/`abi("C")`) because Mojo has no native equivalent.
- **`PythonInterop`** — the code crosses into CPython (`PythonObject`) on purpose.
- **`UnstableAPI`** — the code uses a documented-but-unstable Mojo API
  (`async`/`await`, a `std.*` symbol not marked stable).
- **`Deferred`** — the feature is deliberately not built yet (the library point
  is not started); the marker records what would be needed to start it.

Only `FFI`, `PythonInterop` and `UnstableAPI` are "upgrade candidates" in the
narrow sense — a workaround exists and can be replaced. `Deferred` is a
"start candidate" — nothing exists yet.

## The version rule

The version in the `Start` line is a **confirmation stamp**, not a claim about
the future:

- The scanner compares `stamp < installed Mojo version`.
- **If the stamp is older than the installed Mojo**, the marker is printed as
  needing review **at this version**.
- If the stamp equals or is newer than the installed version, the marker is
  hidden — it was already checked here.

Acting on a finding is always one of two things:

1. **Feature now exists** → remove the workaround *and* the marker; record the
   change in `.changes/` (category `INTERNAL`, or `NEW`/`PERFORMANCE` when it is
   user-visible).
2. **Feature still missing** → **bump the stamp** to the installed version
   (`# MissingMojo - v1.1.0 - Start`). That is the written record: "checked at
   1.1.0, still true." No code change.

So the semantics are self-documenting: a marker at `v1.0.0` that survives a jump
to `v1.1.0` is either upgraded or re-stamped `v1.1.0`.

## The task: `task missingMojo`

```
task missingMojo          # show markers older than the installed Mojo (info, exit 0)
task missingMojo -- all   # show every marker, regardless of version (info, exit 0)
task missingMojo -- check # STRICT: exit 1 if any marker is stale (the CI gate)
```

It resolves the **current** Mojo version from `mojo --version` when the binary
is available, otherwise from the `pixi.toml` pin (`mojo = "~=1.0.0"`). It scans
`mojoakku/**/*.mojo` for markers and prints, per stale marker: the file and line,
the recorded version, `kind`, `need`, `optimal` and `track`, followed by a
summary count.

## CI gate

`task ci` runs `task missingMojo -- check` as its final repository-level step. A
marker whose stamp is **older than the installed Mojo makes CI red** — the
workaround cannot silently survive a toolchain upgrade. To go green again you
must either upgrade the site (the feature now exists) or re-stamp the marker to
the installed version (the feature still does not exist). There is no third way.

This mirrors the Mojo `--warn-on-unstable-apis` idea, but as a hard gate scoped
to MojoAkku's own ledger.

## When to run it

- **CI** — `task ci` runs the strict `-- check` and fails on any stale marker.
- **Before a Mojo upgrade** — list what to re-check on the new version.
- **After a Mojo upgrade** — either upgrade the site or re-stamp it.
- **Before a release** — `task missingMojo` must be clean (nothing older than the
  installed version) or every finding must be consciously re-stamped. This is
  wired into `Release.md`.

## Placement rule

Put the marker **as close as possible to the workaround**, directly above the
function, expression or `@export` it explains. One marker per decision. Do not
mark a whole file when one function is the reason.

## Decision rule — FFI is a last resort, never a default

Before adding a marker with `kind: FFI`, apply this triage. It is the rule that
keeps MojoAkku a *Mojo* project.

1. **Can we defer it (YAGNI)?** → don't build it; write a `Deferred` marker.
   No FFI. This is the most common and the cheapest outcome.
2. **Is the gap at a boundary** — an OS syscall, the network, or an existing C
   library — with a small, stable ABI? → a **thin** FFI shim is acceptable. Mark
   it. Prefer calling the OS directly (e.g. `epoll_*`/`kqueue`) over embedding a
   whole third-party runtime (libuv/libev), so the library stays ours.
3. **Is the gap language semantics** — `async`/`await`, ownership, generics,
   traits — **never** shim it through an ABI. A C boundary cannot carry
   coroutines, ownership or parameterized types, and a mismatched declaration is
   a silently wrong answer, not a compile error. Design around it (keep the
   scheduler layer separate) or wait.

FFI is a **permanent liability**: the shared library must exist at run time and
the signature is unchecked. An honest `Deferred` marker is often better than a
shim.

## Review gate

`reviewer` checks, for any change that adds or edits a marker:

- (a) the block is syntactically valid (Start/End, required fields present);
- (b) `kind` matches reality (a C call is `FFI`, not `UnstableAPI`);
- (c) the triage rule above was applied — an `FFI` marker must justify why
  steps 1 and 3 do not apply;
- (d) a removed workaround also removed its marker and added a `.changes/` entry.

## Handoff

Markers are surfaced whenever Mojo is upgraded. If an upgrade leaves a marker in
place, `manager` re-stamps it and records the decision in the project log;
otherwise the site is upgraded through the normal library pipeline (research →
design → tests → implementation) before the stamp advances.
