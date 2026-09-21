# NewLibPhase7Scaffold

## Purpose
Create the compile-ready skeleton for `mojoakku/<lib>/` from the approved docs, with public API stubs that raise "not yet implemented" and with no real implementation.

## Inputs
- `mojoakku/<lib>/<LIB>_DOCS.md` as the single source of truth (approved by `NewLibPhase6DocsReview.md`).
- The approved design and design review verdict.
- `AGENTS.md` and this workflow file.

## Preconditions
- `NewLibPhase6DocsReview.md` returned `APPROVED`.
- The public API member list and signatures are frozen in `<LIB>_DOCS.md`.
- No `mojoakku/<lib>/` implementation tree exists yet for this library, or it is being created fresh.
- The Manager starts no Manager subagent.

## Roles
- **Manager**: owns the phase, starts ONE `coder` to create the skeleton, delegates the compile gate to `coder`.
- **coder**: creates the files and stub bodies; runs the Mojo compile check for the scaffold; writes no real logic.
- **reviewer**: not started here; invoked by `NewLibPhase8ScaffoldReview.md`.

## Steps
1. Manager confirms the library directory `mojoakku/<lib>/` does not physically nest inside any other library and is a sibling under `mojoakku/`.
2. coder creates the library layout exactly:
   - `mojoakku/<lib>/__init__.mojo` — package entry point; re-exports the public API from the `api/` package so `from <lib> import ...` works.
   - `mojoakku/<lib>/api/` — the public API surface, **one file per API area** (e.g. `encode.mojo`, `decode.mojo`, or the area names from `<LIB>_DOCS.md`). There is **no** single `API.mojo` file. The `api/` package has its own `__init__.mojo` that re-exports every public member from the area files.
   - `mojoakku/<lib>/src/` — private implementation directory, empty of real logic (may contain a placeholder only if needed to keep the tree).
   - `mojoakku/<lib>/_tests/` — tests directory, and it MUST NOT contain an `__init__.mojo` (per the library layout convention).
   - `mojoakku/<lib>/<LIB>_DOCS.md` — the approved single source of truth, placed in the library root.
   - `mojoakku/<lib>/Taskfile.yml` — the per-library test runner (see Step 8).
3. Group the public API members from `<LIB>_DOCS.md` into areas and create one file per area under `api/`. Every public API member is declared with its exact documented signature, and every function/method carries an **inline doc comment directly above it** (the function's purpose, parameters, return value, raised errors and a one-line semantics summary). The authoritative full semantics stay in `<LIB>_DOCS.md`; the inline comment is the at-a-glance version next to the code.
4. Each function and each public method body must be a stub that does exactly:
   `raise Error("MojoAkku: this API is not yet implemented")`
   No other logic, no return of fake values, no partial implementation.
5. Ensure the `api/` files are syntactically valid and compile: use the documented types and signatures, import what is strictly needed, and keep the files free of implementation details.
6. In `__init__.mojo`, re-export the public API from `api/` so `from <lib> import ...` works, and nothing more.
7. Keep `src/` free of implementation. If the directory cannot be tracked empty, add only a minimal placeholder file without logic. `src/` is the private implementation area (the rename of the former `_internal/`).
8. Create `mojoakku/<lib>/Taskfile.yml`: a small Taskfile with a `test` task that runs every `_tests/*.mojo` file with `mojo run` (there is no `mojo test`; each test file is a program with its own `main()`), stops on the first failure, and exits non-zero when any test fails. It may also provide a `compile`/`check` task for the library. It uses the same portable shell style as the root `Taskfile.yml`.
9. Ensure each API-area file, `api/__init__.mojo` and `__init__.mojo` are syntactically valid and compile.
10. Manager runs the compile gate: delegate to `coder` to compile/check `mojoakku/<lib>/` (e.g. `mojo build` or `mojo check` on the package). The scaffold is only complete when it compiles with the stubs.
11. If compilation fails, coder fixes the straightforward syntax/signature errors and Step 10 is repeated. Unclear failures are routed by the Manager, not delegated as guesses.
12. Manager verifies that `_tests/` exists and has no `__init__.mojo`.
13. Manager logs the scaffold result and the compile evidence via `agentlog`.
14. Manager commits the phase with a message naming the phase (e.g. `base64 phase 7: scaffold`).
15. Manager hands the skeleton to review.

## Artifacts / Outputs
- `mojoakku/<lib>/__init__.mojo`
- `mojoakku/<lib>/api/` — one file per API area plus `api/__init__.mojo`, each public stub raising `Error("MojoAkku: this API is not yet implemented")`, each with an inline doc comment.
- `mojoakku/<lib>/src/`
- `mojoakku/<lib>/_tests/` (no `__init__.mojo`)
- `mojoakku/<lib>/<LIB>_DOCS.md`
- `mojoakku/<lib>/Taskfile.yml` — per-library `test` (and optional `compile`) task.
- A successful compile/check result as evidence.
- One `.agents/log.md` entry recording the phase result and the compile evidence.
- One git commit for the phase.

## Review Gate
- The agreed layout exists: `__init__.mojo`, `api/` (one file per area, no `API.mojo`), `src/`, `_tests/` (no `__init__.mojo`), `<LIB>_DOCS.md`, `Taskfile.yml`.
- Every public API member from `<LIB>_DOCS.md` exists as a stub with its documented signature, and each stub has an inline doc comment.
- Every stub raises the exact message `MojoAkku: this API is not yet implemented`.
- `Taskfile.yml` exists and its `test` task runs the `_tests/` files.
- The scaffold compiles.
- No real implementation exists in `api/`, `__init__.mojo` or `src/`.
- The phase is committed.

## Handoff: `NewLibPhase8ScaffoldReview.md`
