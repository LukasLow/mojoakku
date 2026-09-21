# NewLibPhase11Implementation

## Purpose

Implement `mojoakku/<lib>/_internal/` and wire `API.mojo` until the baseline test suite from `NewLibPhase9Tests.md` reaches zero failing tests.

## Inputs

- `mojoakku/<lib>/<LIB>_DOCS.md` (authoritative semantics).
- `mojoakku/<lib>/API.mojo` (public surface from the scaffold).
- `mojoakku/<lib>/_tests/` (frozen baseline tests).
- Baseline log from the Tests phase.
- Documented dependency edges (e.g. `http -> tcp -> socket`) from the depending library's docs.

## Preconditions

- `NewLibPhase10TestsReview.md` completed with a go decision.
- Tests are frozen: no test edits are permitted during this phase.
- Any API not yet in `<LIB>_DOCS.md` is out of scope until documented and justified.

## Roles

- Coder: implements internals, wires the API and runs the loop.
- Reviewer (next phase): validates implementation against semantics.

## Steps

1. Start from the failing baseline: run the recorded test command and confirm the current failing count.
2. Implement the smallest documented behavior that removes a failing test, placing real logic in `mojoakku/<lib>/_internal/`.
3. Wire `API.mojo` to delegate to `_internal/`; replace stub bodies with real calls while keeping documented signatures.
4. Run the tests after each increment (`run tests -> fix -> run tests`) and track the failing count trending to zero.
5. Stop only when the run reports 0 failing tests; record the final passing count.
6. Implement documented edge-case handling explicitly: EOF, `EINTR`/`EAGAIN`, non-blocking, ownership/close, timeouts, invalid input.
7. If a needed API is missing from `<LIB>_DOCS.md`, do not silently invent it: return to `NewLibPhase3Design.md` / `NewLibPhase5Docs.md`, document and justify it, then resume here.
8. Keep dependency edges within the documented direction; never introduce a nested library structure under `mojoakku/<lib>/`.
9. Preserve `_tests/` unchanged; if a test seems wrong, return to `NewLibPhase9Tests.md` instead of editing it.
10. Commit implementation and the final green test log.

## Artifacts / Outputs

- `mojoakku/<lib>/_internal/` implementation files.
- Wired `mojoakku/<lib>/API.mojo`.
- Final test log showing 0 failing tests with the exact command.
- Notes on edge-case handling and any documented API additions.

## Review Gate

- Entry gate for `NewLibPhase12ImplementationReview.md`: baseline tests are green (0 failing) without test edits, all documented semantics are implemented, and no undocumented API was added.
- Weakening documented semantics or changing tests to pass is a blocking violation and returns to the Design workflow.

## Handoff: `NewLibPhase12ImplementationReview.md`
