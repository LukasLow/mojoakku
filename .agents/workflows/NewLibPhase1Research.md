# NewLibPhase1Research

## Purpose
Research the problem space for one new MojoAkku library across many reference languages so that API design later rests on sourced evidence rather than on cargo-cult copying.

## Inputs
- The library name `<lib>` (lowercase, e.g. `socket`, `tcp`, `http`, `json`).
- This workflow file.
- The language list to cover (see Step 2).
- The standardized question set (see Step 3).
- Access to web research and to the reference implementations' source or documentation.

## Preconditions
- The Manager has decided that a new MojoAkku library is the next sensible step and has named `<lib>`.
- `AGENTS.md` and `.agents/workflows/README.md` exist and this workflow is the active phase.
- No prior `mojoakku/<lib>/research/` directory exists for this phase (fresh run), or it is explicitly being redone.
- The Manager starts NO Manager subagent; this workflow is executed by the Manager orchestrating `researcher` agents.

## Roles
- **Manager**: owns the phase, splits the work, starts one `researcher` agent per language, collects results, enforces the source rule.
- **researcher** (one agent per language): answers the standardized question set for exactly one language, writes `mojoakku/<lib>/research/<lang>.md`, cites sources.
- **reviewer**: not started here; invoked by the next workflow `NewLibPhase2ResearchReview.md`.

## Steps
1. Manager confirms the library name `<lib>` and creates the directory `mojoakku/<lib>/research/` in the repository.
2. Manager fixes the language list for this run. Baseline list, extendable by the Manager when a language is clearly relevant to `<lib>`:
   - Mojo — served by the `mojov1` buch, not by a `researcher`: Mojo facts are read from `mojov1` (and improved in place via `buch_update` if wrong), so **no `researcher` is started for Mojo**.
   Grouping (systems): C, C++, C#, Go, Rust, Zig, Odin, Swift
   - C
   - C++
   - C#
   - Go
   - Rust
   - Zig
   - Odin
   - Swift
   Grouping (scripting): Python, Ruby, Perl, Lua
   - Python
   - Ruby
   - Perl
   - Lua
   Grouping (managed/JVM): Java, Scala, Kotlin, Clojure
   - Java
   - Scala
   - Kotlin
   - Clojure
   Grouping (functional/BEAM): Elixir, Erlang, Gleam, OCaml, F#, Haskell
   - Elixir
   - Erlang
   - Gleam
   - OCaml
   - F#
   - Haskell
   Grouping (scripting/web): JS/TS, PHP, Dart
   - JS/TS
   - PHP
   - Dart
   Grouping (data/science): Julia, R
   - Julia
   - R
   The 28 languages above are the frozen baseline; further languages may be ADDED by the Manager (never removed), so results stay comparable. Plausible additions include Nim, Crystal, D, Ada, Fortran, Common Lisp, Tcl, Hare, V, Smalltalk, Prolog, Elm.
3. Manager freezes the SAME standardized question set for every language. Each `researcher` must answer every question in the same order:
   1. What does the language's standard library provide for this problem, and under which module/package names?
   2. Which relevant community libraries exist (name, maintainer, maturity, license)?
   3. Which public APIs do those stdlib/community implementations expose (functions, types, methods, constants)?
   4. How is an error represented (error codes, exceptions, `Result`/`Either`, sentinel values, out-parameters)?
   5. What are the ownership/lifetime semantics (who owns the buffer, who owns the handle/socket, who frees what)?
   6. Is the API blocking or non-blocking, and how are async/concurrency models handled?
   7. How are IPv4 and IPv6 handled, and can a single abstraction cover both?
   8. How are timeouts and cancellation represented and applied?
   9. How is TLS handled (integrated, layered, external)?
   10. Which interesting design decisions are worth studying?
   11. Which decisions should explicitly NOT be copied into MojoAkku, and why?
   12. Which ideas fit Mojo specifically (ownership model, `raises`, `var`/`borrowed`, value semantics, compile-time features)?
4. Manager starts ONE `researcher` agent per language, in parallel where possible, each with this prompt contract: "Research `<lib>` in `<lang>`. Answer the standardized question set in the given order. Write `mojoakku/<lib>/research/<lang>.md`. Every factual claim needs a source (URL or file:line in a reference repo). Mark any guess explicitly as `GUESS:`."
5. Each `researcher` investigates and writes exactly one file `mojoakku/<lib>/research/<lang>.md` using this structure:
   - `# <lib> research: <lang>`
   - `## 1. Standard library support`
   - `## 2. Relevant community libraries`
   - `## 3. Exposed APIs`
   - `## 4. Error representation`
   - `## 5. Ownership semantics`
   - `## 6. Blocking / non-blocking`
   - `## 7. IPv4 / IPv6`
   - `## 8. Timeouts`
   - `## 9. TLS`
   - `## 10. Interesting design decisions`
   - `## 11. Decisions NOT to copy`
   - `## 12. Ideas fitting Mojo`
   - `## Sources`
6. Each `researcher` marks every statement with a citation to a source (URL, RFC number, or `repo/path:line`). Where no source could be found, the statement is written as `GUESS:` and the reason no source exists is stated.
7. Manager waits for all `researcher` agents, then verifies completeness against all 28 baseline languages from Step 2: Mojo is satisfied by the `mojov1` buch and each of the other 27 languages must have a non-empty `mojoakku/<lib>/research/<lang>.md`.
8. Manager appends a status line to `.agents/log.md` via `agentlog` naming `<lib>`, the languages covered, and the research directory.
9. Manager hands the aggregate to the next workflow, where a `reviewer` will check completeness, contradictions, missing sources, and evidence-based cross-language conclusions.

## Artifacts / Outputs
- `mojoakku/<lib>/research/<lang>.md` — one file per language in the frozen list.
- Every file contains the 12 answer sections and a `Sources` section.
- All sources are real and traceable; all unsourced statements are marked `GUESS:`.
- The Mojo side of the research is covered by the `mojov1` buch rather than by a generated `research/mojo.md`; if a `research/mojo.md` is kept, it only links to the buch pages instead of duplicating them.
- One `.agents/log.md` entry recording the phase result.

## Review Gate
- `NewLibPhase1Research.md` is complete when all 28 baseline languages from Step 2 are covered — Mojo by the `mojov1` buch (optionally linked from `research/mojo.md`) and each of the other 27 by a non-empty `research/<lang>.md` — and every question is answered or explicitly marked `GUESS:`.
- No design or API decision is made in this phase.
- The phase is NOT approved here; approval happens in `NewLibPhase2ResearchReview.md`.

## Handoff: `NewLibPhase2ResearchReview.md`
