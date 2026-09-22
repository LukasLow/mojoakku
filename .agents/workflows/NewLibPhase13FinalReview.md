# NewLibPhase13FinalReview

## Purpose

Serve as the end-to-end gate proving that docs, API, tests and implementation for `mojoakku/<lib>` are consistent and releasable.

## Inputs

- The inline `# API-DOCS` blocks in `mojoakku/<lib>/*.mojo` and `mojoakku/<lib>/__init__.mojo`.
- `mojoakku/<lib>/*.mojo` API files.
- `mojoakku/<lib>/_internal/` (only if shared code exists) and `mojoakku/<lib>/_tests/`.
- `mojoakku/<lib>/Taskfile.yml`.
- All review reports from Research through Implementation (including `NewLibPhase12ImplementationReview.md`).
- Evidence: final test run output showing `X passed, 0 failed` with the exact command.
- Documented dependency edges used by the library.

## Preconditions

- `NewLibPhase12ImplementationReview.md` completed with a go decision.
- All prior phase reviews are stored and accessible.

## Roles

- Reviewer: performs the final cross-artifact consistency check and issues go/no-go.
- Manager: consumes the decision and routes to Release or back to a failed phase.

## Steps

1. Re-run the full library test suite (the per-library `Taskfile.yml test` task) and confirm the evidence: `X passed, 0 failed` with zero skips hidden as passes.
2. Cross-check every public symbol in the `mojoakku/<lib>/*.mojo` API files against their inline `# API-DOCS` blocks: no undocumented symbol, no documented symbol missing, no signature drift.
3. Cross-check every documented behavior against a test and against the implementation; confirm the three artifacts agree.
4. Verify test integrity across the whole history: `_tests/` matches the reviewed baseline, no post-review weakening.
5. Verify each dependency edge used by the library is documented and justified in the depending library's docs, and that no physical nesting exists.
6. Confirm the library directory layout is complete and independent: `__init__.mojo`, one `.mojo` file per public API entry directly under `mojoakku/<lib>/` (no `api/`, no `API.mojo`, no `src/`), optional `_internal/` only if shared code exists, `_tests/` (without `__init__.mojo`), `Taskfile.yml`.
7. Assemble the open follow-ups list (non-blocking defects, deferred APIs, doc gaps) with owner and severity.
8. Issue the explicit go/no-go decision.
9. If go, Manager commits the phase with a message naming the phase and decision (e.g. `base64 phase 13: final review GO`).

## Artifacts / Outputs

- Final review report: consistency matrix, test evidence (`X passed, 0 failed`), dependency-edge audit, layout audit.
- Explicit go/no-go decision and the list of open follow-ups.
- One git commit for the phase.

## Review Gate

- Go only if: docs, API, tests and implementation are consistent; test evidence shows `X passed, 0 failed`; every used dependency edge is documented; and no blocking findings remain.
- No-go returns to the specific failing phase (Design, Docs, Scaffold, Tests or Implementation) with the blocking findings attached.
- The phase is committed.

## Handoff: `CreatePR.md`
