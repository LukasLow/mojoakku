# MojoUpdate — per-version language + stdlib adoption pass

## Purpose

MojoAkku exists **beside** the Mojo standard library, not as a permanent
replacement for it. The long-term goal is that MojoAkku **shrinks** as the
standard library grows: every capability the stdlib gains turns one of our
implementations into a thin wrapper and eventually removes it entirely.

`MojoUpdate` is the recurring per-version pass that finds exactly those places.
For every new Mojo version it checks **two** things, not one:

1. the **language** — new syntax, types, ownership/lifecycle, error model,
   compile-time features, decorators, tooling;
2. the **standard library** — new or newly-stable `std.*` APIs, package
   renames, signature changes.

Anything the stdlib now provides is **adopted**: MojoAkku calls the stdlib and
keeps only a wrapper (or deletes its own code). A place where Mojo *still* lacks
the capability stays a documented divergence and is re-stamped in the
`MissingMojo` ledger.

One sentence: **on every Mojo version, adopt what the language and stdlib now
provide — wrapper first, delete second — so MojoAkku keeps getting smaller.**

## Inputs

- The previous Mojo version and the new (installed) Mojo version.
- The Mojo 1.x release notes / version log and the stdlib docs for the new
  version.
- The `mojov1` buch (`versions/` change record, `stdlib/` pages) for the Mojo
  side — Mojo facts come from the buch, never from memory or the open internet.
- Every library under `mojoakku/<lib>/`: the inline `# API-DOCS` blocks, the
  `_internal/` code, the `_dev/DESIGN.md` rationale, and the `MissingMojo`
  markers.
- `task missingMojo -- all` (the current workaround ledger).
- `pixi.toml` (the pinned Mojo version) and `smd.toml`.

## Preconditions

- A new Mojo version is available or pinned for adoption (or the user requests a
  check without a bump).
- `task ci` is green on the **current** version before the pass starts, so any
  red signal afterwards is attributable to the update.
- The Manager starts NO Manager subagent.

## Roles

- **Manager**: owns the pass, resolves the version delta, decides per finding
  whether to adopt (wrapper), delete, defer or re-stamp, and commits.
- **researcher** (optional): web research for **stdlib release notes and API
  changes** of the new Mojo version. Mojo *facts* still come from the `mojov1`
  buch, not the web.
- **explore** (optional): scan `mojoakku/**` for the sites a finding touches.
- **coder**: performs an adoption (wrapper around a stdlib symbol) or a deletion,
  with tests.
- **reviewer**: reviews an adoption/deletion like any code change (correctness,
  tests, docs, no behavior regression).
- **debug**: only if an adoption breaks behaviour or tests.

## Steps

1. Manager records the version delta: previous version, new version, and the
   `pixi.toml` pin. If `pixi.toml` changes, that is part of this pass.
2. Manager reads the `mojov1` buch for the new version: the `versions/<new>`
   change record (what changed), and `stdlib/overview` plus the `stdlib/*` pages
   the libraries touch. **Mojo facts are looked up in `mojov1`, not recalled or
   web-researched**; a missing or wrong buch page is fixed in place with
   `buch_update` and that fix is part of the pass.
3. Manager builds the **two changelists** for the new version:
   - **language** — new syntax, ownership/lifecycle, error model, compile-time
     features, decorators, tooling;
   - **stdlib** — new, newly-stable or renamed `std.*` APIs and signature
     changes.
   Every entry gets a source (buch page, release note, or stdlib doc URL).
4. Manager maps each changelist entry onto the MojoAkku tree: which
   `mojoakku/<lib>/` API entries or `_internal/` sites implement a concept the
   stdlib now provides? For that, scan `mojoakku/**` and read the relevant
   `# API-DOCS` blocks and `_dev/DESIGN.md` rationales. Also list
   `task missingMojo -- all` markers whose `need` the new version satisfies.
5. For every **stdlib finding**, Manager classifies the site (this is the
   stdlib-first rule in its per-version form):
   - **ADOPT (wrapper)** — the stdlib now exposes the concept. Replace our
     implementation with a wrapper that calls the stdlib symbol. Keep the
     MojoAkku signature, docs and typed error; the body forwards. Record the
     forwarded stdlib symbol in the API entry's `# API-DOCS`. This is the
     default outcome.
   - **DELETE** — if our wrapper adds nothing over the stdlib (the stdlib
     already has our exact shape), remove the entry, its tests, its docs and any
     re-export. Update the library's `# Public API` index. This is the
     preferred end state: MojoAkku shrinks.
   - **KEEP (extension)** — our entry adds alphabet/policy/typed-error/streaming
     behaviour the stdlib lacks. It stays a deliberate divergence, and the
     reason is stated in the `# API-DOCS`. If only *part* overlaps, wrap the
     overlapping part and keep the extension.
   - **RE-STAMP** — the `need` is still missing in the new version. Bump the
     `MissingMojo` marker's confirmation stamp to the new version (see
     `MissingMojo.md`). No code change.
6. For every **language finding**, Manager decides whether it simplifies an
   existing site (e.g. a cleaner ownership form, a new keyword). Such a change
   is handled as a normal `Refactor.md` task and reviewed, not silently bundled.
7. Manager routes adoptions/deletions:
   - a **wrapper** adoption that only changes a function body → `coder`, then
     `reviewer` (correctness + full test suite);
   - a **deletion** or any change to the public API surface → the relevant
     library pipeline (Phase 3 design → design review → docs → tests →
     implementation → reviews) because the public surface changed;
   - a **behaviour-affecting** adoption with unclear failure → `debug` first.
8. `coder` performs each adoption: the body forwards to the stdlib, all existing
   tests stay green **unchanged** (a wrapper must be behaviour-preserving), and
   the API entry's `# API-DOCS` names the stdlib symbol it forwards to. A
   missing stdlib page in `mojov1` is added or corrected via `buch_update`.
9. Manager records every decision in a `.changes/` file for the pass:
   - an adoption that is user-visible (behaviour or performance) → `NEW`/`PERFORMANCE`;
   - a deletion of a MojoAkku API because the stdlib now covers it → `BREAKING`
     (with migration note: "use `std.<symbol>`");
   - a pure internal delegation with no user-visible change → `INTERNAL`.
   One pass, one change file (`<yyyy-mm-dd>-mojo-update-<version>.md`).
10. Manager runs `task ci` on the new version: every library's tests green and
    `task missingMojo -- check` clean (every stale marker upgraded or re-stamped).
    If `pixi.toml` moved, the version bump commits together with the pass.
11. Manager commits the pass with a message naming the version and the outcome,
    e.g. `mojo 1.2.0 update: adopt std.base64 in base64 (wrapper), re-stamp 3 markers`.
12. Manager repeats until the changelists are empty: every stdlib entry is
    ADOPT, DELETE or explicitly KEEP with a reason; every language entry is
    either unused or handled.

## The shrink principle (why this workflow exists)

MojoAkku is deliberately **not** a permanent standard-library alternative. The
desired direction is:

```
own implementation  ->  thin wrapper over std  ->  deleted (use std directly)
```

- The stdlib is the **first** place to look; MojoAkku fills the gap only while
  the gap exists.
- Every adoption is a **win**, not a loss: less code to carry, less to test,
  less to document.
- A wrapper keeps MojoAkku's promise (uniform, low-vision-friendly surface, one
  option model, one typed error) while the **behaviour** comes from the stdlib.
- An extension stays only while the stdlib lacks the capability; the moment the
  stdlib gains it, this workflow turns the extension into a wrapper and then
  deletes it if it adds nothing.

MojoAkku may currently be smaller than many reference ecosystems, but that is
the starting point, not the goal: MojoAkku should grow where the stdlib is
silent and shrink wherever the stdlib speaks.

## Artifacts / Outputs

- The two changelists (language, stdlib) for the new version, each entry with a
  source.
- A classification table: every touched site as ADOPT / DELETE / KEEP / RE-STAMP,
  with the reason.
- Adoptions/deletions as code changes with green, unchanged tests (wrappers are
  behaviour-preserving).
- `# API-DOCS` updated to name the forwarded stdlib symbol for every wrapper.
- `_dev/DESIGN.md` updated: a former "own implementation" rationale becomes a
  "wrapper over `std.<symbol>`" rationale (this is design history, not end-user
  docs).
- Re-stamped or removed `MissingMojo` markers (`task missingMojo -- check`
  clean).
- Buch pages added/corrected in `mojov1` for any stdlib fact the pass needed.
- Exactly one `.changes/` file for the pass.
- One git commit naming the version and outcome.

## Review Gate

- Every stdlib changelist entry is classified ADOPT / DELETE / KEEP / RE-STAMP;
  none is ignored silently.
- Every ADOPT is a wrapper that forwards to a named stdlib symbol, with the
  symbol recorded in the `# API-DOCS`; behaviour is unchanged and tests are
  green **without weakening**.
- Every DELETE removes the entry, its tests, its docs, its re-export and its
  `# Public API` line, and ships a `BREAKING` change file with a migration note
  to the stdlib symbol.
- Every KEEP states, in the `# API-DOCS`, the capability the stdlib still lacks.
- `task missingMojo -- check` is clean (upgraded or re-stamped).
- No wrapper is committed without a green suite on the new version.
- One `.changes/` file; one commit.

## Handoff

Adoptions and deletions follow the normal task flows: `coder` implements,
`reviewer` reviews, `debug` on any failure, and — when the public API surface
changes — the NewLib phase pipeline (Design → DesignReview → Docs → Tests →
Implementation → Reviews). The pass closes with a `CreatePR.md` (or the Release
flow) like any other change.
