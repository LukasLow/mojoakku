# BugFix

## Purpose
Restore correct behavior for a confirmed defect through reproduce (failing test) -> root cause -> fix -> verify -> review.

## Inputs
- Bug report or issue: observed vs. expected behavior, environment, reproduction hints.
- Affected sibling library under `mojoakku/<lib>/` (`__init__.mojo`, the API files `mojoakku/<lib>/*.mojo`, optional `_internal/`, `_tests/`, `Taskfile.yml`).
- Existing tests in `mojoakku/<lib>/_tests/`.
- The inline `# API-DOCS` blocks in `mojoakku/<lib>/*.mojo` and `__init__.mojo` (single source of truth for intended behavior).
- Logs, core dumps or traces attached to the report.

## Preconditions
- The affected `<lib>` builds and its existing `_tests/` suite is runnable.
- The defect is reported but not yet diagnosed; no fix is started before a failing test reproduces it.
- The work is scoped to one defect; unrelated cleanup is not part of this workflow.

## Roles
- `manager`: opens the task, assigns scope, routes to agents, records status. Manager starts NO Manager.
- `coder`: writes the failing test, applies the fix, and runs build and test commands (via `smd`) as evidence.
- `debug`: root-cause analysis when the cause is not evident from the reproduction.
- `reviewer`: owns the review gate.
- `docs`: updates the inline `# API-DOCS` blocks when observable behavior or API documentation changes.

## Steps
1. `manager` opens the task, captures the report, names the affected `mojoakku/<lib>/`, and delegates reproduction to `coder`.
2. `coder` writes one failing test in `mojoakku/<lib>/_tests/` that encodes the expected behavior (not the buggy behavior).
3. `coder` runs that test and returns evidence that it fails for the reported reason; if it already passes, the report is not a defect and investigation moves to `BugInvestigation`.
4. `coder` determines the root cause. If the cause is not evident, `manager` routes to `debug` for root-cause analysis (evidence-only, per `BugInvestigation`).
5. `coder` fixes the minimal root cause in the API files `mojoakku/<lib>/*.mojo` or in `mojoakku/<lib>/_internal/`; no unrelated refactoring, no API shape change.
6. `coder` runs the full `_tests/` suite of the affected library (via `task -t mojoakku/<lib>/Taskfile.yml test`) plus the tests of sibling libraries that depend on it; all must be green and the new test must pass.
7. `docs` updates the inline `# API-DOCS` blocks only if the fix changes documented behavior or error surface.
8. `reviewer` applies the review gate and returns `APPROVED` or `NEEDS_DEBUG` / `NEEDS_COMPLIANCE`.
9. `manager` commits the fix with a message naming the defect and the affected library.

## Artifacts / Outputs
- Regression test added to `mojoakku/<lib>/_tests/` (path recorded in the task log).
- Minimal fix diff in `mojoakku/<lib>/`.
- Failing-before / passing-after test output as evidence.
- Updated inline `# API-DOCS` blocks when behavior or errors changed.
- Task-log entry with root cause in one sentence and the fix reference.
- One git commit carrying the fix and the regression test.

## Review Gate
`reviewer` verifies: (a) a failing test demonstrably preceded the fix, (b) the root cause is addressed and not just the symptom, (c) the full affected test suite is green, (d) no scope creep or API change, (e) docs are synced. Missing reproduction or red tests => reject.

## Handoff: Refactor.md if the fix introduced structural debt, otherwise Release.md when the fix is user-visible; otherwise close the task.
