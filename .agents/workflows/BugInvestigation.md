# BugInvestigation

## Purpose
Determine and evidence the root cause of a defect WITHOUT changing code, and deliver a recommendation for how it should be fixed.

## Inputs
- Bug report or anomaly: observed vs. expected behavior, environment, reproduction steps.
- Affected sibling library under `mojoakku/<lib>/`.
- Logs, traces, benchmark output or failing test output.
- `<LIB>_DOCS.md` of the affected library (intended behavior).

## Preconditions
- The defect is reproducible, or enough evidence exists to reason about it.
- Scope is read-only: no source, test or documentation file under `mojoakku/` may be modified.
- The investigation question is stated as a falsifiable hypothesis, not as "fix X".

## Roles
- `manager`: opens the task, enforces the read-only scope, routes findings. Manager starts NO Manager.
- `debug`: drives the root-cause analysis and owns the final report.
- `explore`: maps call paths and relevant file locations.
- `coder`: runs diagnostic build/test/profiling commands (via `smd`) and returns raw evidence.
- `reviewer`: verifies that conclusions follow from the evidence.

## Steps
1. `manager` opens the task, states the investigated question, and confirms the code-freeze/read-only scope.
2. `coder` reproduces the defect and captures raw output; every diagnostic artifact is written to a file, not held in chat.
3. `explore` maps the relevant call paths and data flow with `file:line` references.
4. `debug` forms explicit hypotheses and eliminates them one by one against the captured evidence.
5. `debug` isolates the root cause and states its confidence, the affected scope, and the blast radius.
6. `debug` writes a recommendation: the smallest fix, alternative fixes, risks and verification criteria — but no code change.
7. `reviewer` verifies that every conclusion is supported by a linked piece of evidence and that no file under `mojoakku/` was modified.

## Artifacts / Outputs
- Investigation report at `.agents/investigations/<task-id>-<slug>.md` containing: question, evidence (`file:line`), hypotheses, proven root cause, confidence, blast radius, recommendation, verification criteria.
- Raw logs / command output stored as separate files and referenced, never inlined.
- Task-log entry linking the report.

## Review Gate
`reviewer` verifies: (a) no source, test or docs file under `mojoakku/` was changed, (b) each conclusion maps to concrete evidence, (c) the recommendation is actionable and testable. Unsourced conclusions or any code change => reject.

## Handoff: BugFix.md when a fix is recommended; Refactor.md or NewLibPhase3Design.md if the cause is structural and requires a design change; otherwise close the task.
