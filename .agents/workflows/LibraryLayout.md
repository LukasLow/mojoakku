# LibraryLayout — canonical MojoAkku library layout and documentation convention

This file is the single reference for how a MojoAkku library is laid out and
where its documentation lives. Every phase workflow and every task workflow
points here instead of repeating the layout. If the layout changes, change it
HERE first.

## Directory layout

```
mojoakku/<lib>/
  __init__.mojo        # package entry point + shared (whole-library) end-user docs
  <api_entry>.mojo     # ONE file per public API entry (see below)
  ...
  _internal/           # private shared code — ONLY if there is shared code
    <name>.mojo
  _dev/                # development folder — NOT shipped, NOT end-user docs
    README.md          # frozen run config (selected languages, question set)
    <lang>.md          # phase-1 research notes, one file per reference language
    DESIGN.md          # the design record (see below)
  _tests/              # tests, one file per concern; MUST NOT contain __init__.mojo
    test_<lib>_<concern>.mojo
  Taskfile.yml         # per-library test runner (task test)
```

Rules:

- **Flat, sibling libraries.** `mojoakku/<lib>/` is a flat sibling under
  `mojoakku/`. Libraries are never nested.
- **One file per public API entry, directly under `mojoakku/<lib>/`.** There is
  **no `api/` directory** and **no `API.mojo`** aggregator file. The entry name is
  the API name, lowercased: e.g. `encode.mojo`, `encode_into.mojo`,
  `decoded_len.mojo`, `padding_mode.mojo`, `base64_error.mojo`.
- **`__init__.mojo` is the package entry point.** It is required by Mojo and it
  (a) holds the whole-library end-user docs (see below) and (b) re-exports every
  public member from the per-entry files so `from <lib> import X` works.
- **No `src/` directory.** Private code lives under `_internal/` and only when
  there is genuinely shared code to factor out. If the library is small enough
  that each API file is self-contained, `_internal/` must not exist.
- **`_dev/` is the development folder.** It holds everything that is for the
  developer, not the end user: the phase-1 research (`<lang>.md` plus the frozen
  `README.md`) and the design record (`DESIGN.md`). It is part of the repo (so
  the reasoning is preserved and reviewable) but is never shipped and is never
  end-user documentation.
- **`_tests/` never contains `__init__.mojo`.** Tests are plain programs, each
  with its own `main()`; they are run with `mojo run`.

## Documentation lives WITH the code (there is no `<LIB>_DOCS.md`)

There is **no separate `<LIB>_DOCS.md`** file. The docs live inline with the
source. Documentation has exactly **two parts**, and they serve different
readers:

1. **API docs — for the END USER** (someone using the library). This is the part
   between `# API-DOCS-START` / `# API-DOCS-END` that a future automatic docs
   system will extract. It must answer "what is this, how do I call it, what does
   it give back, what can go wrong, show me an example" — in user-facing
   language, and it is allowed to be verbose.
2. **Maintainer notes — for the person editing the file.** These are ordinary
   `#` comments next to the code, and only where a non-obvious decision needs a
   word. The code itself is the documentation of *how*; do not restate it.

Everything that is neither of those — the design rationale, the reference-API
comparisons, the status bookkeeping — is **noise for the end user** and must NOT
appear in the API docs block or the shared block. It lives in the temporary
`<LIB>_DESIGN.md` (Phase 3-6) and in git history.

### 1. Per-API docs — in the API's own file, between markers, at the BOTTOM

Each `<api_entry>.mojo` carries the end-user documentation for exactly that one
API entry. The docs block sits at the **bottom of the file, after the code** (a
reader lands on the implementation first; the reference follows). The block uses
this field set, in this order:

```mojo
<the actual code: imports, declarations, bodies, sparse maintainer comments>

# API-DOCS-START
# <Name> — one-line summary.
# Signature:
#   <the exact Mojo declaration(s)>
# What it does:
#   <user-facing description: parameters and their meaning, defaults, the
#    compile-time options, ownership of input and output, and the stream-I/O /
#    flush contract where applicable>
# Returns:
#   <what the caller gets back and who owns it>
# Errors:
#   <every error the caller can see, and whether it is recoverable; "none" when
#    the API cannot fail>
# Example:
#   <one or more small, concrete usage examples (input -> result)>
# API-DOCS-END
```

Rules:

- Field names and order are identical in every API file.
- The block is **user-facing**: no status bookkeeping, no test names, no
  "MojoAkku uses X because Y" rationale, no reference-API citations. Those are
  design history.
- Verbosity is welcome here; brevity in the code. The block is the one place
  that may explain at length.
- The markers are the contract: a docs generator extracts exactly the block
  between them.

### 2. Shared (whole-library) docs — in `__init__.mojo`, at the BOTTOM

Documentation that is not attributable to a single API entry, but to the library
as a whole, lives at the **bottom of `__init__.mojo`**, after the re-exports.
Keep it user-facing and lean:

```mojo
<the package entry: re-export statements>

# API-DOCS-START
# Purpose   — what the library is for, in a few sentences.
# Overview  — the shape of the API and the mental model a user needs.
# Dependencies — any sibling library edges (usually none), one line each.
# Public API — the ordered index of entries (one line per entry).
# Error Surface — the error type(s) and which API raises what.
# Conventions — the few cross-cutting rules a user must know (naming, defaults,
#   ownership).
# API-DOCS-END
```

### 3. Nothing else

There is no `<LIB>_DOCS.md`, no separate docs artifact in the shipped library.
The per-API blocks and the `__init__.mojo` block together are the end-user docs;
the design record lives in `<LIB>_DESIGN.md` and git history.

## The design record (lives in `_dev/DESIGN.md`)

Phases 3-6 (Design → Docs Review) operate before the code tree exists. They
produce ONE design document, `mojoakku/<lib>/_dev/DESIGN.md`. This is the
**design record**, and it is where all the developer-facing reasoning belongs —
the "noise" that must stay out of the end-user docs:

- the shared design sections: purpose, overview, goals, **non-goals** (decisions
  deliberately not copied), dependencies, **reference APIs**, public-API list,
  error surface, conventions, ownership and lifecycle, **open questions**;
- per API entry: its status, signature, semantics, errors, tests, implementation
  status and **rationale** (the `MojoAkku uses X because Y` justifications).

Unlike the earlier draft, the design record is **not deleted** at Phase 7. It is
the persistent development record and lives in `_dev/DESIGN.md` for the life of
the library (updated when the API changes).

At **Phase 7 (Scaffold)** the design is materialised into the *end-user* docs in
the tree (a projection, not a move):

- the shared user-facing sections (Purpose, Overview, Dependencies, Public API,
  Error Surface, Conventions) become the end-user docs block in `__init__.mojo`;
- each API's user-facing block (Signature, What it does, Returns, Errors,
  Example) becomes the end-user docs block in that API's file;
- the code stubs are added around the docs.

The design record in `_dev/DESIGN.md` keeps the full reasoning (status, tests,
rationale, non-goals, references, open questions); the inline end-user blocks
keep only what a user needs. From Phase 8 onward the authoritative end-user docs
are the inline blocks in `mojoakku/<lib>/*.mojo` and `__init__.mojo`; the
authoritative design reasoning is `mojoakku/<lib>/_dev/DESIGN.md`.

## Where an agent looks for "the docs"

| Question | Look at |
| --- | --- |
| How do I use the library? | the API docs blocks in `mojoakku/<lib>/*.mojo` and `__init__.mojo` |
| What is API `X` for? | `mojoakku/<lib>/<x>.mojo` docs block |
| The full ordered public API | `# Public API` in `__init__.mojo` docs block |
| Why was X designed this way? | `mojoakku/<lib>/_dev/DESIGN.md` |
| Prior art / why a decision was made | `mojoakku/<lib>/_dev/<lang>.md` and `_dev/DESIGN.md` |
| How do I compile/test? | `mojoakku/<lib>/Taskfile.yml` |
