# NewLibPhase1Research

## Purpose
Research the problem space for one new MojoAkku library across many reference languages so that API design later rests on sourced evidence rather than on cargo-cult copying.

## Inputs
- The library name `<lib>` (lowercase, e.g. `socket`, `tcp`, `http`, `json`).
- This workflow file.
- The language groups to cover (see Step 2).
- The standardized question set (see Step 3).
- Access to web research and to the reference implementations' source or documentation.
- The `mojov1` buch for the Mojo side.

## Preconditions
- The Manager has decided that a new MojoAkku library is the next sensible step and has named `<lib>`.
- `AGENTS.md` and `.agents/workflows/README.md` exist and this workflow is the active phase.
- No prior `mojoakku/<lib>/.research/` directory exists for this phase (fresh run), or it is explicitly being redone.
- The Manager starts NO Manager subagent; this workflow is executed by the Manager orchestrating `researcher` agents.

## Roles
- **Manager**: owns the phase, fixes the language groups for this run, starts at most **6** `researcher` agents (one per group), collects results, enforces the source rule.
- **researcher** (one agent per selected language group, **max 6**): answers the standardized question set for every language in its group and writes the findings **directly** into `mojoakku/<lib>/.research/<lang>.md`, one file per language. It does not use a `docs` materialization pass.
- **reviewer**: not started here; invoked by the next workflow `NewLibPhase2ResearchReview.md`.

## Steps
1. Manager confirms the library name `<lib>` and creates the directory `mojoakku/<lib>/.research/` in the repository.
2. Manager fixes the language groups for this run from the baseline roster below. The roster is a pool, not a mandate: the Manager selects the languages in which the concept `<lib>` actually exists and relevantly differs, and records the selection with a one-line reason per language in `mojoakku/<lib>/.research/README.md`. The selection is frozen for the run.
   - **Mojo** — always present in the list, but served by the `mojov1` buch and **not** by a `researcher`: Mojo facts are read from `mojov1` (and improved in place via `buch_update` if wrong), so **no `researcher` handles Mojo**.
   - **Mandatory languages (always selected, in every run):** C, C++, Go, Rust, JS/TS, Python — plus Mojo via the buch. These are never dropped; if a language genuinely cannot answer a domain, the Manager states why in `.research/README.md`.
   - The remaining languages form **6 groups**. The Manager starts **at most ONE `researcher` per group, so at most 6 researchers in total** — never one per language.
   1. Grouping (systems-lowlevel): C, C++
   2. Grouping (systems-modern): Go, Rust, C#, Zig, Odin, Swift
   3. Grouping (scripting-web): Python, Perl, JS/TS, PHP, Dart
   4. Grouping (managed-JVM): Java, Kotlin
   5. Grouping (functional/BEAM): Elixir, OCaml, F#, Haskell
   6. Grouping (data/science, optional): Julia, R
   - **Optional / on demand:** the data/science group is not selected by default; it is added only when the domain makes it valuable. The non-mandatory languages of the other groups (C#, Zig, Odin, Swift, Perl, PHP, Dart, Kotlin, OCaml, F#, Haskell) may be dropped per run with a one-line reason.
   - **Deliberately removed from the roster** (no longer part of the pool): Lua, Ruby, Gleam, Erlang, Scala, Clojure. Reasons: Lua/Ruby add no distinct API signal; Gleam is too niche; Elixir research already covers the BEAM/Erlang side; Scala and Clojure delegate to `java.util.Base64` and add nothing over Java/Kotlin.
   - The roster above is a pool, not a fixed mandate: no library has to cover all of it. The Manager selects per library and freezes the selection in `.research/README.md`. A group with no selected language is skipped, so fewer than 6 researchers is normal.
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
4. Manager starts at most ONE `researcher` agent per selected language group, in parallel where possible (**upper bound: 6 researchers total**), each with this prompt contract: "Research `<lib>` in the languages of your group: `<langs>`. Answer the standardized question set in the given order. Write your findings **directly** into `mojoakku/<lib>/.research/<lang>.md`, one file per language of your group. Every factual claim needs a source (URL or file:line in a reference repo). Mark any guess explicitly as `GUESS:`."
5. Each `researcher` writes one file per language of its group to `mojoakku/<lib>/.research/<lang>.md`, following exactly this structure:
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
7. Manager waits for all `researcher` agents, then verifies completeness against the frozen selection of this run from Step 2: Mojo is satisfied by the `mojov1` buch and every other selected language must have its `.research/<lang>.md` file present and non-empty, exactly one file per selected language.
8. Manager appends a status line to `.agents/log.md` via `agentlog` naming `<lib>`, the languages covered, and the research directory.
9. Manager commits the phase: stages `mojoakku/<lib>/.research/` and commits with a message naming the phase and the covered languages (e.g. `base64 phase 1: research corpus (9 languages + README)`).
10. Manager hands the aggregate to the next workflow, where a `reviewer` will check completeness, contradictions, missing sources, and evidence-based cross-language conclusions.

## Artifacts / Outputs
- `mojoakku/<lib>/.research/<lang>.md` — one file per language in the frozen selection, written directly by the `researcher` of the owning group. No `docs` materialization pass exists.
- Every file contains the 12 answer sections and a `Sources` section.
- All sources are real and traceable; all unsourced statements are marked `GUESS:`.
- The Mojo side of the research is covered by the `mojov1` buch rather than by a generated `.research/mojo.md`; if a `.research/mojo.md` is kept, it only links to the buch pages instead of duplicating them.
- One `.agents/log.md` entry recording the phase result.
- One git commit for the phase containing the research directory.

## Review Gate
- `NewLibPhase1Research.md` is complete when every language of the frozen selection of this run (recorded in `.research/README.md`) is covered — Mojo by the `mojov1` buch (optionally linked from `.research/mojo.md`) and each other language by a non-empty `.research/<lang>.md` — and every question is answered or explicitly marked `GUESS:`.
- At most 6 researchers were started, one per selected group.
- No design or API decision is made in this phase.
- The phase is committed.
- The phase is NOT approved here; approval happens in `NewLibPhase2ResearchReview.md`.

## Handoff: `NewLibPhase2ResearchReview.md`
