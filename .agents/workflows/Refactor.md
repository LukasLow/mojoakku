# Refactor

## Purpose
Restructure code without changing behavior, keeping the test suite green before and after.

## Inputs
- Target scope in `mojoakku/<lib>/` (`API.mojo`, `_internal/`, or tests).
- `<LIB>_DOCS.md` of the affected library (defines the behavior that must not change).
- Current test suite in `mojoakku/<lib>/_tests/`.
- The motivation: readability, duplication, dead code, naming or structure.

## Preconditions
- The full `_tests/` suite of the affected library is green before any edit (baseline evidence captured).
- The refactoring changes no public behavior, no public API and no semantics.
- Any desired semantics change is out of scope and must go through `NewLibPhase3Design.md` first.
- Scope is limited to one coherent restructuring goal.

## Roles
- `manager`: opens the task, approves scope, routes to agents. Manager starts NO Manager.
- `coder`: performs the restructuring and runs the baseline and post-refactor test/benchmark commands (via `smd`) as evidence.
- `reviewer`: owns the review gate.
- `docs`: updates `<LIB>_DOCS.md` only if internal structure references changed (public docs must already match).
- `idea-reviewer`: consulted when the refactoring touches an abstraction boundary.

## Steps
1. `manager` opens the task, bounds the scope, and delegates the baseline to `coder`.
2. `coder` records the green baseline: full test suite output and, when performance matters, a benchmark baseline.
3. `coder` performs the restructuring in small steps; each step keeps the suite green.
4. `coder` runs the full `_tests/` suite after every meaningful step and returns the result.
5. `idea-reviewer` verifies that no abstraction boundary, public API or documented behavior was silently altered.
6. `coder` re-runs the benchmark and compares against the baseline; a performance regression must be justified or fixed.
7. `docs` updates `<LIB>_DOCS.md` only for internal references; public docs are unchanged.
8. `reviewer` applies the review gate.

## Artifacts / Outputs
- Refactored files under `mojoakku/<lib>/`.
- Baseline and post-refactor test output (both green) stored as evidence files.
- Benchmark before/after comparison when performance was in scope.
- Task-log entry naming the restructuring goal and the files touched.

## Review Gate
`reviewer` verifies: (a) tests were green before and after, (b) no public API or semantics changed, (c) the restructuring is behavior-preserving, (d) any performance delta is explained. A missing baseline or changed semantics => reject and route to `NewLibPhase3Design.md`.

## Handoff: APIReview.md if the refactor changes a public signature (which requires a design decision), otherwise NewLibPhase13FinalReview.md or close the task.
