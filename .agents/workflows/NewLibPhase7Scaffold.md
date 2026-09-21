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
- **Manager**: owns the phase, starts ONE `coder` to create the skeleton, verifies the compile gate via `shell`.
- **coder**: creates the files and stub bodies; writes no real logic.
- **shell**: runs the Mojo compile check for the scaffold.
- **reviewer**: not started here; invoked by `NewLibPhase8ScaffoldReview.md`.

## Steps
1. Manager confirms the library directory `mojoakku/<lib>/` does not physically nest inside any other library and is a sibling under `mojoakku/`.
2. coder creates the library layout exactly:
   - `mojoakku/<lib>/__init__.mojo` — package entry point, importing the public API from `API.mojo`.
   - `mojoakku/<lib>/API.mojo` — the public API surface only, one stub per API member.
   - `mojoakku/<lib>/_internal/` — private implementation directory, empty of real logic (may contain a placeholder only if needed to keep the tree).
   - `mojoakku/<lib>/_tests/` — tests directory, and it MUST NOT contain an `__init__.mojo` (per the library layout convention).
   - `mojoakku/<lib>/<LIB>_DOCS.md` — the approved single source of truth, placed in the library root.
3. In `API.mojo`, declare every public API member from `<LIB>_DOCS.md` with its exact documented signature.
4. Each function and each public method body must be a stub that does exactly:
   `raise Error("MojoAkku: this API is not yet implemented")`
   No other logic, no return of fake values, no partial implementation.
5. Ensure `API.mojo` is syntactically valid and compiles: use the documented types and signatures, import what is strictly needed, and keep the file free of implementation details.
6. In `__init__.mojo`, re-export the public API so `from <lib> import ...` works, and nothing more.
7. Keep `_internal/` free of implementation. If the directory cannot be tracked empty, add only a minimal placeholder file without logic.
8. Manager runs the compile gate: delegate to `shell` to compile/check `mojoakku/<lib>/` (e.g. `mojo build` or `mojo check` on `API.mojo`). The scaffold is only complete when it compiles with the stubs.
9. If compilation fails, coder fixes the straightforward syntax/signature errors and Step 8 is repeated. Unclear failures are routed by the Manager, not delegated as guesses.
10. Manager verifies that `_tests/` exists and has no `__init__.mojo`.
11. Manager logs the scaffold result and the compile evidence via `agentlog`.
12. Manager hands the skeleton to review.

## Artifacts / Outputs
- `mojoakku/<lib>/__init__.mojo`
- `mojoakku/<lib>/API.mojo` — public API stubs, each raising `Error("MojoAkku: this API is not yet implemented")`.
- `mojoakku/<lib>/_internal/`
- `mojoakku/<lib>/_tests/` (no `__init__.mojo`)
- `mojoakku/<lib>/<LIB>_DOCS.md`
- A successful compile/check result as evidence.
- One `.agents/log.md` entry recording the phase result and the compile evidence.

## Review Gate
- The exact five-element layout exists and `_tests/` has no `__init__.mojo`.
- Every public API member from `<LIB>_DOCS.md` exists as a stub with its documented signature.
- Every stub raises the exact message `MojoAkku: this API is not yet implemented`.
- The scaffold compiles.
- No real implementation exists in `API.mojo`, `__init__.mojo` or `_internal/`.

## Handoff: `NewLibPhase8ScaffoldReview.md`
