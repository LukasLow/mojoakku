# MojoAkku — Project Map

This file is a **map**, not a rulebook. It tells you where things live and
where to go for the process. Detailed process steps live in
`.agents/workflows/`.

## What MojoAkku is

MojoAkku is a collection of independent Mojo libraries that live *beside* the
official Mojo standard library. It focuses on sockets, TCP, HTTP and closely
related layers, and is built agentically for a low-vision user — so APIs,
naming and docs are designed to be predictable, consistent and easy to read.

## Repository architecture

```
repo root/
  AGENTS.md
  README.md
  TODO.md
  LICENSE
  Taskfile.yml        <-- task commands, reads the _todos/ catalogue
  _todos/             <-- flat catalogue: one YAML file per planned library
  .agents/workflows/*.md
  mojoakku/
    socket/    <-- SIBLING library
    tcp/       <-- SIBLING library
    udp/       <-- SIBLING library
    http/      <-- SIBLING library
    websocket/ <-- SIBLING library
    json/      <-- SIBLING library
    url/       <-- SIBLING library
    html/      <-- SIBLING library
    template/  <-- SIBLING library
    markdown/  <-- SIBLING library
    ...
```

Every library under `mojoakku/<lib>/` is a **sibling**. Libraries are **never
nested** inside each other. The expected libraries are `socket`, `tcp`, `udp`,
`http`, `websocket`, `json`, `url`, `html`, `template`, `markdown` and other
names added later; this list is illustrative, not exhaustive.

## Layout of one library

```
mojoakku/<lib>/
  __init__.mojo      # package entry point + shared (whole-library) docs block; re-exports every public name
  <api_entry>.mojo   # ONE file per public API entry, name = API name lowercased
                     #   e.g. encode.mojo, padding_mode.mojo, base64_error.mojo
  _internal/         # private shared code — ONLY if there is genuinely shared code
  _tests/            # tests, one file per concern (no __init__.mojo)
  Taskfile.yml       # per-library test runner (task test)
  .research/         # phase-1 research notes, one file per reference language
```

There is **no `api/` directory**, **no `API.mojo`** aggregator and **no `src/`
directory**. Documentation lives **inline with the code** between the markers
`# API-DOCS-START` / `# API-DOCS-END`: the shared whole-library docs in
`__init__.mojo`, and one seven-field docs block per API in that API's own file.
The canonical reference is `.agents/workflows/LibraryLayout.md`.

## Library independence rules

- Libraries **MUST NOT** be structurally nested. The directory tree stays flat
  under `mojoakku/`.
- A library **MAY** depend on another library as a **graph edge**, e.g.
  `http -> tcp -> socket`.
- Every dependency edge **must** be technically justified and documented in the
  depending library's inline `# API-DOCS` shared block (`__init__.mojo`).
- Dependency edges **MUST NOT** determine directory nesting. A dependency is a
  conceptual edge, never a physical parent/child relationship.

## Core process rules

- **No implementation before research + API + scaffold + tests exist.**
- The **inline `# API-DOCS` blocks** (`__init__.mojo` for the whole library, one
  block per API in that API's file) are the **single source of truth** for a library.
- Every API decision must be **justified in the docs**.
- The public API lives in **one file per API entry** directly under
  `mojoakku/<lib>/`, never in a single `API.mojo`; private shared logic lives in
  `mojoakku/<lib>/_internal/` (only if genuinely shared); every public function
  carries its seven-field docs block next to it.
- Each library ships its own `Taskfile.yml` with a `test` task for its `_tests/`.
- **The API design is approved by the user** before the design review runs
  (`NewLibPhase3Design.md`, user review gate).
- **Every workflow phase ends with a git commit** naming the phase (and, for a
  review phase, its verdict), so each phase boundary is visible in history.
- **CI runs one command: `task ci`.** The root `Taskfile.yml` auto-discovers
  every `mojoakku/*/Taskfile.yml` and runs each library's `test` (and optional
  `ci`) task; no library is registered anywhere. Each library owns how it tests.
  Two GitHub workflows drive it: `pull-request-check.yml` (PR: `task ci` + require
  exactly one new `.changes/new/` file) and `main-push.yml` (main: `task ci`, then
  release when `.changes/new/` is non-empty).
- **`.changes/` drives the changelog and the tag.** `.changes/new/` holds pending
  change files (`<date>-<slug>.md`, category lines `NEW`, `FIX`, `SECURITY`,
  `PERFORMANCE`, `BREAKING`, `DEPRECATED`, `INTERNAL`, `DOCS`); CI moves released
  files to `.changes/archive/<tag>/` (CI-only). Versions stay on `0.x.y` and
  **major is never bumped**: `NEW`/`BREAKING`/`DEPRECATED` → minor,
  `FIX`/`SECURITY`/`PERFORMANCE` → patch, `INTERNAL`/`DOCS` → none (no tag;
  they fold into the next real release). `task changes:version` previews it.
  See `.changes/README.md`.
- **The Manager starts NO Manager**.

## Mojo knowledge: the buch tool

- Mojo facts **MUST** be looked up in the `mojov1` buch — not researched from the
  internet and not recalled from memory.
- Tools: `buch_search` (find a page), `buch_read` (read `buch/page` or
  `buch/page#section`), `buch_list` (list buch and pages), `buch_update` (write a
  page).
- Goal: **a Mojo research pass must no longer be necessary.** `mojov1` is the
  self-sufficient Mojo 1.x reference and the single lookup point for keywords,
  syntax, types, ownership/lifecycle, errors, interop, stdlib and tooling.
- Write access is allowed and wanted: any agent that finds an error, an outdated
  statement, a missing page or an improvable fact **MUST** fix it in `mojov1` via
  `buch_update` instead of working around it. Improving the buch is part of
  normal work, not a special exception.
- Buch authoring constraints that updates **must** respect: content comes from the
  official Mojo 1.x documentation (never invented); where the official docs are
  silent or contradictory, write an explicit **"Open question"** marker rather
  than guessing; legacy pre-1.x spellings belong only in the `versions/` change
  record, never as taught syntax; pages stay short and one topic per page;
  headings are anchors and therefore API — add a heading rather than renaming a
  used one.
- Location fact: `mojov1` is a local (writable) buch under
  `/Users/lukas/home/repos/buch-lib/.buch/mojov1.buch/`; the same-named remote
  library entry is a read-only shadow.

## Workflows

The process lives in `.agents/workflows/`. Start at the index:
`.agents/workflows/README.md`.

- `NewLibPhase1Research.md` — research the problem space per language.
- `NewLibPhase2ResearchReview.md` — review the research output.
- `NewLibPhase3Design.md` — design the public API.
- `NewLibPhase4DesignReview.md` — review the API design.
- `NewLibPhase5Docs.md` — complete `_dev/DESIGN.md` (shared sections + one block per API entry).
- `NewLibPhase6DocsReview.md` — review the design document.
- `NewLibPhase7Scaffold.md` — create the library skeleton and materialise the design into inline end-user docs.
- `NewLibPhase8ScaffoldReview.md` — review the scaffold.
- `NewLibPhase9Tests.md` — write tests before implementation.
- `NewLibPhase10TestsReview.md` — review the tests.
- `NewLibPhase11Implementation.md` — implement against API, docs and tests.
- `NewLibPhase12ImplementationReview.md` — review the implementation.
- `NewLibPhase13FinalReview.md` — final review and sign-off.
- `BugFix.md` — fix a known bug with a test.
- `BugInvestigation.md` — root-cause an unclear failure.
- `Refactor.md` — restructure without changing behavior.
- `DependencyReview.md` — review and justify dependency edges.
- `APIReview.md` — review an API change.
- `PerformanceInvestigation.md` — investigate and fix performance.
- `SecurityReview.md` — security and hardening review.
- `CreatePR.md` — branch, `.changes/` entry, push and open the pull request.
- `Release.md` — turn `.changes/` into `CHANGELOG.md` and tag the release.

## Toolchain and CI

- **Mojo runs in the smd container** (global `mojo`, version pinned by
  `pixi.toml` via smd.toml). Use `smd` for commands; never bare `bash`.
- **CI** (`.github/workflows/`) runs `task ci` on push and PR; on `main` it also
  auto-releases when `.changes/new/` is non-empty (`main-push.yml`).
- **Changes** are recorded in `.changes/` and drive the version tag; see
  `.changes/README.md`.
