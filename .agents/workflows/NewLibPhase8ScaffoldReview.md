# NewLibPhase8ScaffoldReview

## Purpose

Review the scaffold produced by `NewLibPhase7Scaffold.md` and decide whether the library is structurally ready to receive tests.

## Inputs

- `mojoakku/<lib>/<LIB>_DOCS.md` (single source of truth for the public API).
- `mojoakku/<lib>/API.mojo` and `mojoakku/<lib>/__init__.mojo`.
- `mojoakku/<lib>/_internal/` (scaffold placeholder).
- `mojoakku/<lib>/_tests/` (must exist and must not contain `__init__.mojo`).
- The scaffold report / git diff of the scaffold commit.

## Preconditions

- `NewLibPhase6DocsReview.md` completed with a go decision.
- Scaffold phase finished and the scaffold commit is available for inspection.
- Reviewer has read `<LIB>_DOCS.md` in full.

## Roles

- Reviewer: performs the structural verification and issues the go/no-go decision.
- Coder: responds to findings; does not edit files during review.

## Steps

1. Confirm the library directory contains exactly the agreed layout: `__init__.mojo`, `API.mojo`, `<LIB>_DOCS.md`, `_internal/`, `_tests/`.
2. Confirm `mojoakku/<lib>/_tests/` exists and contains no `__init__.mojo` (tests are plain files, not a package).
3. Build the library: run the Mojo package check/build for `mojoakku/<lib>` and confirm it compiles without errors.
4. Enumerate every public symbol declared in `<LIB>_DOCS.md` and verify a corresponding stub exists in `API.mojo` (name, parameter list, return type) — one by one.
5. Verify each stub raises the standard "not yet implemented" error and does not return fabricated values.
6. Confirm no real implementation leaked into `API.mojo`, `_internal/` or any stub (no working logic that would make tests pass prematurely).
7. Confirm `_internal/` contains no nested library structure (no nested `mojoakku/<lib>/<lib>/`) and no `_internal/API.mojo`.
8. Record findings as pass/fail per step with file:line references.

## Artifacts / Outputs

- Scaffold review report: per-symbol existence table, compilation result, leak check, and a list of blockers (if any).
- Explicit go/no-go decision for the Tests phase.

## Review Gate

- Go only if: the scaffold compiles, every public API from `<LIB>_DOCS.md` has a stub, all stubs raise the standard "not yet implemented" error, `_tests/` exists without `__init__.mojo`, and no implementation leaked.
- Any missing symbol, compilation error, silently faked return value or leaked implementation is a blocking finding and returns to `NewLibPhase7Scaffold.md`.

## Handoff: `NewLibPhase9Tests.md`
