# CreatePR

## Purpose
Take a finished, reviewed change set on the library branch and open its single
pull request: record the change in `.changes/`, push the `<lib>-library` branch,
and open the PR with `gh`. This is the hand-off from a finished library (or task)
to CI and review. For a library this happens **once** — after Phase 13 — and is
the only way the library reaches `main`.

## Inputs
- The reviewed, committed change set on the `<lib>-library` branch (a library
  after Phase 13, or a task workflow result).
- The target repository and its default branch (`main`).
- `.changes/README.md` (the change-file format and the versioning rule).
- The `.github/pull_request_template.md` checklist.
- Test evidence: a green `task ci` run.

## Preconditions
- The relevant review gate passed (for a library: `NewLibPhase13FinalReview.md`
  returned GO; for a task: the matching workflow's gate passed).
- All phase commits are on the library branch `<lib>-library`; nothing is
  committed directly to `main`.
- `task ci` is green locally (it auto-discovers every library and runs its
  tests).
- There is at least one `.changes/new/<yyyy-mm-dd>-<slug>.md` file for the change.
- For a library, `akku/<lib>/_dev/TODO.md` exists and is accurate (shipped
  items removed, remaining candidates listed).
- The Manager starts no Manager subagent.

## Roles
- **manager**: owns the PR: confirms the library branch, writes the change file,
  pushes, opens the PR and reports the URL. Uses direct host git for all git
  commands.
- **docs**: writes/refines the `.changes/` entry and the PR description when the
  change needs prose.
- **reviewer**: may run a PR-scoped review; reports findings to the Manager.

## Steps
1. Manager confirms the change set is committed on the **library branch** and `task ci` is green.
2. Manager confirms the branch for the library already exists — one long-lived branch named `<lib>-library`, created at Phase 1 and used for every phase commit. If for some reason it does not exist yet, Manager creates it off `main` now (`git checkout -b <lib>-library`). `main` is never written directly.
3. Manager ensures a `.changes/new/<yyyy-mm-dd>-<slug>.md` file exists, with one
   category line per change (`NEW:` / `FIX:` / `SECURITY:` / `PERFORMANCE:` /
   `BREAKING:` / `DEPRECATED:` / `INTERNAL:`). If it is missing, `docs` writes it.
4. Manager verifies the next version with `task changes:version` (always
   `0.x.y`; a break is a minor bump, never major) and states it in the PR body.
5. Manager pushes the branch to the remote.
6. Manager opens the PR with `gh pr create`, using the repository's PR template:
   a title naming the change, a body that fills the checklist (CI green, change
   file present, inline `# API-DOCS` current, version derived).
7. Manager reports the PR URL.
8. CI runs on the PR (`.github/workflows/pull-request-check.yml` → `task ci`). A red CI blocks
   merge; the Manager routes the failure to the owning workflow (`BugFix.md`,
   `BugInvestigation.md`, or back to the phase).
9. On a green CI and an accepted review, the PR is merged (by the user or the
   Manager when authorized). Exactly **one PR per library** reaches `main`; the
   library's catalogue entry was already flipped to `done` at Phase 13.
10. Manager records the PR in the task log with its URL and number.

## Artifacts / Outputs
- A branch and a pull request with a filled template and a `.changes/` entry.
- The reported PR URL.
- A green CI run on the PR.
- A task-log entry with the PR number/URL.

## Review Gate
The PR is mergeable only if: CI is green (`task ci`), a `.changes/` file exists
with valid category lines, the PR template checklist is complete, and the
relevant review gate (Phase 13 for a library) passed. A missing change file, a
red CI, or a stale `# API-DOCS` block blocks the merge.

## Handoff
- Success (merged): close the task; the next release starts at `Release.md`
  (it turns the `.changes/` files into `CHANGELOG.md` and the tag).
- Failure (red CI or review rejected): the Manager routes to the owning workflow
  and returns here.
