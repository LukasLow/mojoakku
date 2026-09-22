# NewLibPhase8ScaffoldReview

## Purpose

Review the scaffold produced by `NewLibPhase7Scaffold.md` and decide whether the library is structurally ready to receive tests.

## Inputs

- The inline `# API-DOCS` blocks in `mojoakku/<lib>/*.mojo` and `mojoakku/<lib>/__init__.mojo` (authoritative docs; the design document is gone).
- `mojoakku/<lib>/*.mojo` (one file per public API entry) and `mojoakku/<lib>/__init__.mojo`.
- `mojoakku/<lib>/_internal/` (only if shared code exists).
- `mojoakku/<lib>/_tests/` (must exist and must not contain `__init__.mojo`).
- `mojoakku/<lib>/Taskfile.yml` (per-library test runner).
- The scaffold report / git diff of the scaffold commit.

## Preconditions

- `NewLibPhase6DocsReview.md` completed with a go decision.
- Scaffold phase finished and the scaffold commit is available for inspection.
- Reviewer has read the inline `# API-DOCS` blocks in full.

## Roles

- Reviewer: performs the structural verification and issues the go/no-go decision.
- Coder: responds to findings; does not edit files during review.

## Steps

1. Confirm the library directory contains exactly the agreed layout: `__init__.mojo`, one `.mojo` file per public API entry directly under `mojoakku/<lib>/` (no `api/` directory, no `API.mojo`), optional `_internal/` only if shared code exists, `_tests/`, `Taskfile.yml`; and that `<LIB>_DESIGN.md` no longer exists.
2. Confirm `mojoakku/<lib>/_tests/` exists and contains no `__init__.mojo` (tests are plain files, not a package).
3. Compile the library via the consumer-import check (`mojo run -I .. <checkfile>` importing every public name) and confirm it compiles without errors.
4. Enumerate every public symbol documented in the inline `# API-DOCS` blocks and verify a corresponding stub exists in the API files (name, parameter list, return type) — one by one. The docs block of API `X` lives in `mojoakku/<lib>/<x>.mojo`.
5. Verify each stub aborts with the standard "not yet implemented" message and does not return fabricated values.
6. Confirm every API file carries its `# API-DOCS` block (the seven fields) and that `__init__.mojo` carries the shared docs block.
7. Confirm no real implementation leaked into the API files or any stub (no working logic that would make tests pass prematurely).
8. Confirm `_internal/` contains no nested library structure (`mojoakku/<lib>/<lib>/`), keeping the sibling rule intact. (If a private implementation file is later placed there, it is not part of the public surface.)
9. Confirm `Taskfile.yml` exists and its `test` task actually runs the files under `_tests/`.
10. Record findings as pass/fail per step with file:line references.

## Artifacts / Outputs

- Scaffold review report: per-symbol existence table, compilation result, leak check, inline-doc check, Taskfile check, and a list of blockers (if any).
- Explicit go/no-go decision for the Tests phase.
- One git commit for the phase recording the verdict.

## Review Gate

- Go only if: the scaffold compiles, every public API from the inline `# API-DOCS` blocks has a stub with its docs block, all stubs abort with the standard "not yet implemented" message, `_tests/` exists without `__init__.mojo`, `Taskfile.yml` runs the tests, `<LIB>_DESIGN.md` is gone, and no implementation leaked.
- Any missing symbol, compilation error, missing docs block, silently faked return value or leaked implementation is a blocking finding and returns to `NewLibPhase7Scaffold.md`.
- The phase is committed.

## Handoff: `NewLibPhase9Tests.md`
