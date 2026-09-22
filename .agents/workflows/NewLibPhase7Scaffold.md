# NewLibPhase7Scaffold

## Purpose
Create the compile-ready skeleton for `mojoakku/<lib>/` from the approved design, with one file per public API entry carrying stub bodies that abort with "not yet implemented", and with no real implementation. This phase materialises the temporary `mojoakku/<lib>/<LIB>_DESIGN.md` into the tree and then deletes it.

## Inputs
- `mojoakku/<lib>/<LIB>_DESIGN.md` as the temporary design artifact (approved by `NewLibPhase6DocsReview.md`).
- The approved design review verdict.
- `AGENTS.md`, `.agents/workflows/LibraryLayout.md` and this workflow file.

## Preconditions
- `NewLibPhase6DocsReview.md` returned `APPROVED`.
- The public API member list and signatures are frozen in `<LIB>_DESIGN.md`.
- No `mojoakku/<lib>/` implementation tree exists yet for this library, or it is being created fresh.
- The Manager starts no Manager subagent.

## Roles
- **Manager**: owns the phase, starts ONE `coder` to create the skeleton, delegates the compile gate to `coder`.
- **coder**: creates the files and stub bodies; runs the Mojo compile check for the scaffold; writes no real logic.
- **reviewer**: not started here; invoked by `NewLibPhase8ScaffoldReview.md`.

## Steps
1. Manager confirms the library directory `mojoakku/<lib>/` does not physically nest inside any other library and is a sibling under `mojoakku/`.
2. coder creates the library layout exactly per `LibraryLayout.md`:
   - `mojoakku/<lib>/__init__.mojo` — package entry point. It holds the shared (whole-library) docs block and re-exports every public member from the API files so `from <lib> import ...` works.
   - `mojoakku/<lib>/<api_entry>.mojo` — **one file per public API entry**, directly under `mojoakku/<lib>/` (the entry name lowercased, e.g. `encode.mojo`, `padding_mode.mojo`, `base64_error.mojo`). There is **no `api/` directory** and **no `API.mojo`** aggregator file.
   - `mojoakku/<lib>/_internal/` — private shared implementation, **only if the design identified genuinely shared code**. If every API file is self-contained, `_internal/` must not exist. There is **no `src/` directory**.
   - `mojoakku/<lib>/_tests/` — tests directory, and it MUST NOT contain an `__init__.mojo`.
   - `mojoakku/<lib>/Taskfile.yml` — the per-library test runner (see Step 9).
   - `mojoakku/<lib>/<LIB>_DESIGN.md` is **deleted** once its content has been materialised (Step 4).
3. Materialise the design: for each API entry, create its file and place the design's API block into the file between the markers `# API-DOCS-START` and `# API-DOCS-END` (the seven fields `Status`, `Signature`, `Semantics`, `Errors`, `Tests`, `Implementation status`, `Rationale`). Place the design's shared sections into `__init__.mojo` between the same markers. Declare each public API member with its exact documented signature.
4. Delete `mojoakku/<lib>/<LIB>_DESIGN.md` after materialisation. The git history keeps the design record; from here on the inline `# API-DOCS` blocks are the authoritative docs.
5. Every public function/method in an API file carries, in the docs block directly above it, the seven documented fields, with `Implementation status: not implemented` in this phase.
6. Each function and each public method body must be a stub that does exactly:
   `abort("MojoAkku: this API is not yet implemented")`
   No other logic, no return of fake values, no partial implementation. `abort` is used instead of `raise`: `raise` does not compile in a non-raising function nor in a function declared `raises <Error>`, whereas `abort` compiles in both and halts with the message.
7. Ensure the API files are syntactically valid and compile: use the documented types and signatures, import what is strictly needed, and keep the files free of implementation details.
8. In `__init__.mojo`, re-export the public API from the API files so `from <lib> import ...` works, and nothing more.
9. Create `mojoakku/<lib>/Taskfile.yml`: a small Taskfile with a `test` task that runs every `_tests/*.mojo` file with `mojo run` (there is no `mojo test`; each test file is a program with its own `main()`), stops on the first failure, and exits non-zero when any test fails. It may also provide a `compile`/`check` task for the library (see Step 11 for the consumer-import pattern). It uses the same portable shell style as the root `Taskfile.yml`.
10. Manager verifies that `_tests/` exists and has no `__init__.mojo`, and that `<LIB>_DESIGN.md` no longer exists.
11. Manager runs the compile gate: delegate to `coder` to compile/check `mojoakku/<lib>/`. The container Mojo is the global `mojo` (no pixi), and `mojo precompile .` does not work here because `_tests/` contains its own `main()` inside the package. Instead use a **consumer import**: write a small check file that imports every public name and run `mojo run -I .. <checkfile>` (see the `compile` task in `mojoakku/base64/Taskfile.yml` as the template). The scaffold is only complete when this consumer import compiles with the stubs.
12. If compilation fails, coder fixes the straightforward syntax/signature errors and Step 11 is repeated. Unclear failures are routed by the Manager, not delegated as guesses.
13. Manager logs the scaffold result and the compile evidence via `agentlog`.
14. Manager commits the phase with a message naming the phase (e.g. `base64 phase 7: scaffold`).
15. Manager hands the skeleton to review.

## Artifacts / Outputs
- `mojoakku/<lib>/__init__.mojo` — package entry point with the shared docs block and the public re-exports.
- `mojoakku/<lib>/<api_entry>.mojo` — one file per public API entry, each stub aborting with `abort("MojoAkku: this API is not yet implemented")`, each with its `# API-DOCS` block.
- `mojoakku/<lib>/_internal/` — only when the design identified shared code.
- `mojoakku/<lib>/_tests/` (no `__init__.mojo`)
- `mojoakku/<lib>/Taskfile.yml` — per-library `test` (and optional `compile`) task.
- The deleted `<LIB>_DESIGN.md` (absent after this phase).
- A successful compile/check result as evidence.
- One `.agents/log.md` entry recording the phase result and the compile evidence.
- One git commit for the phase.

## Review Gate
- The agreed layout exists: `__init__.mojo`, one file per public API entry directly under `mojoakku/<lib>/` (no `api/`, no `API.mojo`), optional `_internal/`, `_tests/` (no `__init__.mojo`), `Taskfile.yml`.
- `<LIB>_DESIGN.md` has been materialised into the inline `# API-DOCS` blocks and deleted.
- Every public API member from the design exists as a stub with its documented signature and its seven-field docs block.
- Every stub aborts with the exact message `MojoAkku: this API is not yet implemented`.
- `Taskfile.yml` exists and its `test` task runs the `_tests/` files.
- The scaffold compiles via the consumer-import check.
- No real implementation exists in the API files or `__init__.mojo`.
- The phase is committed.

## Handoff: `NewLibPhase8ScaffoldReview.md`
