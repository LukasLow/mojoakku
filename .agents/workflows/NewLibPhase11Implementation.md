# NewLibPhase11Implementation

## Purpose

Implement the real bodies in the `mojoakku/<lib>/*.mojo` API files (and, only when there is genuinely shared code, `mojoakku/<lib>/_internal/`) until the baseline test suite from `NewLibPhase9Tests.md` reaches zero failing tests.

## Inputs

- The inline `# API-DOCS` blocks in `mojoakku/<lib>/*.mojo` and `mojoakku/<lib>/__init__.mojo` (authoritative semantics).
- `mojoakku/<lib>/*.mojo` API files (public surface from the scaffold).
- `mojoakku/<lib>/_tests/` (frozen baseline tests).
- `mojoakku/<lib>/Taskfile.yml` (per-library test runner).
- Baseline log from the Tests phase.
- Documented dependency edges (e.g. `http -> tcp -> socket`) from the depending library's docs.

## Preconditions

- `NewLibPhase10TestsReview.md` completed with a go decision.
- Tests are frozen: no test edits are permitted during this phase.
- Any API not yet documented in the inline `# API-DOCS` blocks is out of scope until documented and justified.

## Roles

- Coder: implements internals, wires the API and runs the loop.
- Reviewer (next phase): validates implementation against semantics.

## Steps

1. Start from the failing baseline: run the recorded test command (the per-library `Taskfile.yml test` task) and confirm the current failing count.
2. Implement the smallest documented behavior that removes a failing test, placing real logic in the API file that owns that API entry; factor genuinely shared code into `mojoakku/<lib>/_internal/` only when it is shared across entries.
3. Replace stub bodies with real calls while keeping documented signatures and the inline `# API-DOCS` blocks intact and up to date (set `Implementation status` to `implemented` once an API works).
4. Run the tests after each increment (`run tests -> fix -> run tests`) and track the failing count trending to zero.
5. Stop only when the run reports 0 failing tests; record the final passing count.
6. Implement documented edge-case handling explicitly: EOF, `EINTR`/`EAGAIN`, non-blocking, ownership/close, timeouts, invalid input.
7. If a needed API is missing from the inline `# API-DOCS` blocks, do not silently invent it: return to `NewLibPhase3Design.md` / `NewLibPhase5Docs.md`, document and justify it, then resume here.
8. Keep dependency edges within the documented direction; never introduce a nested library structure under `mojoakku/<lib>/`.
9. Preserve `_tests/` unchanged; if a test seems wrong, return to `NewLibPhase9Tests.md` instead of editing it.
10. Commit implementation and the final green test log with a message naming the phase (e.g. `base64 phase 11: implementation, 0 failing`).

## Artifacts / Outputs

- Implemented `mojoakku/<lib>/*.mojo` API files (real bodies + docs blocks preserved).
- `mojoakku/<lib>/_internal/` implementation files only if shared code was factored out.
- Final test log showing 0 failing tests with the exact command.
- Notes on edge-case handling and any documented API additions.
- One git commit for the phase.

## Review Gate

- Entry gate for `NewLibPhase12ImplementationReview.md`: baseline tests are green (0 failing) without test edits, all documented semantics are implemented, and no undocumented API was added.
- Weakening documented semantics or changing tests to pass is a blocking violation and returns to the Design workflow.
- The phase is committed.

## Handoff: `NewLibPhase12ImplementationReview.md`
