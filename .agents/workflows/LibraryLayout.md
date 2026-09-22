# LibraryLayout — canonical MojoAkku library layout and documentation convention

This file is the single reference for how a MojoAkku library is laid out and
where its documentation lives. Every phase workflow and every task workflow
points here instead of repeating the layout. If the layout changes, change it
HERE first.

## Directory layout

```
mojoakku/<lib>/
  __init__.mojo        # package entry point + shared (whole-library) docs
  <api_entry>.mojo     # ONE file per public API entry (see below)
  ...
  _internal/           # private shared code — ONLY if there is shared code
    <name>.mojo
  _tests/              # tests, one file per concern; MUST NOT contain __init__.mojo
    test_<lib>_<concern>.mojo
  Taskfile.yml         # per-library test runner (task test)
  .research/           # phase-1 research notes, one file per reference language
```

Rules:

- **Flat, sibling libraries.** `mojoakku/<lib>/` is a flat sibling under
  `mojoakku/`. Libraries are never nested.
- **One file per public API entry, directly under `mojoakku/<lib>/`.** There is
  **no `api/` directory** and **no `API.mojo`** aggregator file. The entry name is
  the API name, lowercased: e.g. `encode.mojo`, `encode_into.mojo`,
  `decoded_len.mojo`, `padding_mode.mojo`, `base64_error.mojo`.
- **`__init__.mojo` is the package entry point.** It is required by Mojo and it
  (a) holds the whole-library "shared" docs (see below) and (b) re-exports every
  public member from the per-entry files so `from <lib> import X` works.
- **No `src/` directory.** Private code lives under `_internal/` and only when
  there is genuinely shared code to factor out. If the library is small enough
  that each API file is self-contained, `_internal/` must not exist.
- **`_tests/` never contains `__init__.mojo`.** Tests are plain programs, each
  with its own `main()`; they are run with `mojo run`.

## Documentation lives WITH the code (there is no `<LIB>_DOCS.md`)

There is **no separate `<LIB>_DOCS.md`** file. The docs live inline with the
source, split by ownership:

### 1. Per-API docs — in the API's own file, between markers

Each `<api_entry>.mojo` carries the full documentation for exactly that one API
entry, wrapped in machine-readable markers so the block is unambiguous:

```mojo
# API-DOCS-START
# <Name> — one-line meaning.
# Status: planned | scaffolded | tested | implemented | benchmarked
# Signature: the exact Mojo declaration
# Semantics: full behavioural description (parameters/preconditions, return
#   meaning, ownership, stream-I/O/flush contract as applicable)
# Errors: every raised or returned error, and whether it is recoverable
# Tests: the test-file/test name(s) that prove this API
# Implementation status: not implemented | implemented
# Rationale: MojoAkku uses X because Y (naming the reference API)
# API-DOCS-END
```

Field names and their order are identical in every API file. The markers are the
contract: a reader (or agent) can extract exactly one API's docs by reading
between them.

### 2. Shared (whole-library) docs — in `__init__.mojo`, between markers

Documentation that is not attributable to a single API entry, but to the library
as a whole, lives in `__init__.mojo`:

```mojo
# API-DOCS-START
# Purpose
# Status legend
# Dependencies (graph edges to sibling libraries, each justified)
# Overview
# Goals
# Non-Goals (decisions deliberately NOT copied, each justified)
# Reference APIs
# Public API (the ordered list of entries)
# Error Surface
# Conventions
# Ownership and Lifecycle
# Open Questions
# API-DOCS-END
```

### 3. Nothing else

There is no `BASE64_DOCS.md`, no `<LIB>_DOCS.md`, no separate docs artifact in
the shipped library. The per-API blocks and the `__init__.mojo` block together
are the single source of truth.

## The design-time artifact (temporary)

Phases 3-6 (Design → Docs Review) operate before the code tree exists. They
produce ONE design document, `mojoakku/<lib>/<LIB>_DESIGN.md`, which contains the
shared sections (as they will appear in `__init__.mojo`) and one block per API
entry (as it will appear in that entry's file, using the same `# API-DOCS-START` /
`# API-DOCS-END` field set).

At **Phase 7 (Scaffold)** the design document is *materialised into the tree*:

- the shared sections become the docs block in `__init__.mojo`;
- each API block becomes the docs block in that API's file;
- the code stubs are added around the docs;

and then `<LIB>_DESIGN.md` is **removed** (its content now lives with the code;
git history keeps the design record).

From Phase 8 onward the authoritative docs are the inline blocks in
`mojoakku/<lib>/*.mojo` and `__init__.mojo` — never a separate file.

## Where an agent looks for "the docs"

| Question | Look at |
| --- | --- |
| What is the whole library for? deps? goals? conventions? | `mojoakku/<lib>/__init__.mojo` docs block |
| What does API `X` do, exactly? | `mojoakku/<lib>/<x>.mojo` docs block |
| What is the full ordered public API? | `## Public API` in `__init__.mojo` docs block |
| How do I compile/test? | `mojoakku/<lib>/Taskfile.yml` |
