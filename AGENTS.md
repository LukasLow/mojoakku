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
  __init__.mojo      # public package entry point; re-exports from api/
  api/               # public API surface, ONE file per API area (no API.mojo)
    __init__.mojo    # re-exports every public member
    <area>.mojo      # e.g. encode.mojo, decode.mojo — stubs + inline doc comments
  src/               # private implementation details
  <LIB>_DOCS.md      # single source of truth (e.g. SOCKET_DOCS.md)
  _tests/            # tests, one file per concern (no __init__.mojo)
  Taskfile.yml       # per-library test runner (task test)
  .research/         # phase-1 research notes, one file per reference language
```

## Library independence rules

- Libraries **MUST NOT** be structurally nested. The directory tree stays flat
  under `mojoakku/`.
- A library **MAY** depend on another library as a **graph edge**, e.g.
  `http -> tcp -> socket`.
- Every dependency edge **must** be technically justified and documented in the
  depending library's `<LIB>_DOCS.md`.
- Dependency edges **MUST NOT** determine directory nesting. A dependency is a
  conceptual edge, never a physical parent/child relationship.

## Core process rules

- **No implementation before research + API + scaffold + tests exist.**
- `<LIB>_DOCS.md` is the **single source of truth** for a library.
- Every API decision must be **justified in the docs**.
- The public API lives in `api/` (one file per API area), never in a single
  `API.mojo`; private logic lives in `src/`; every public function carries an
  inline doc comment next to it.
- Each library ships its own `Taskfile.yml` with a `test` task for its `_tests/`.
- **The API design is approved by the user** before the design review runs
  (`NewLibPhase3Design.md`, user review gate).
- **Every workflow phase ends with a git commit** naming the phase (and, for a
  review phase, its verdict), so each phase boundary is visible in history.
- The **Manager starts NO Manager**.

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
- `NewLibPhase5Docs.md` — write `<LIB>_DOCS.md` as source of truth.
- `NewLibPhase6DocsReview.md` — review the docs.
- `NewLibPhase7Scaffold.md` — create the library skeleton.
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
- `Release.md` — prepare and cut a release.
