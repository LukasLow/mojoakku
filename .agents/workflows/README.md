# MojoAkku Workflows — Index

Every workflow listed here lives in this directory (`.agents/workflows/`) and
is owned by the agent type named in it. This file is the entry point: pick the
phase you are in and follow the matching workflow.

## One subagent per agent type — reuse it across phases

Start **at most ONE subagent per agent type** for the whole task, and **reuse
that same subagent session** whenever its role is needed again later (resume it
instead of spawning a new one). One `coder`, one `researcher`, one `reviewer`,
one `debug`, and so on. Typical shape:

```
coder1  researcher1  reviewer1  debug1
```

- When a later phase needs the same role (e.g. `NewLibPhase4DesignReview` after
  `NewLibPhase2ResearchReview` both need a `reviewer`), **resume the existing
  `<role>1` session** rather than starting a fresh agent.
- Rationale: a reused session keeps the context it already built up (the library
  under construction, prior findings, the house conventions) and costs far less
  than a cold start. This also prevents a growing fleet of redundant agents.
- Exception: parallel work that is genuinely independent may briefly need more
  than one instance of a role (e.g. the at-most-6 `researcher` agents in
  `NewLibPhase1Research.md`, one per language group). Even there, reuse each
  group's researcher if that group must run again.
- Leaf agents that change nothing (`reviewer`, `compliance`, `idea-reviewer`,
  `debug`) are the clearest reuse candidates: they are read-only, so a resumed
  session is always safe.

## New library pipeline

The full path for a new library, in order. Each phase has a review gate before
the next phase starts, and each phase ends with a git commit naming the phase
(and, for a review phase, its verdict). All phases for a library commit to the
**library's own branch — `<libname>-library-new` for a new library,
`<libname>-library-patch` for a patch** (created in Phase 1); `main` is never
written directly — the library reaches `main` through exactly one PR at the end.

```
NewLibPhase1Research -> NewLibPhase2ResearchReview -> NewLibPhase3Design
  -> NewLibPhase4DesignReview -> NewLibPhase5Docs -> NewLibPhase6DocsReview
  -> NewLibPhase7Scaffold -> NewLibPhase8ScaffoldReview -> NewLibPhase9Tests
  -> NewLibPhase10TestsReview -> NewLibPhase11Implementation
  -> NewLibPhase12ImplementationReview -> NewLibPhase13FinalReview
  -> CreatePR (one PR per library) -> CI (task ci) -> merge -> Release
```

| Phase workflow | Purpose |
| --- | --- |
| `NewLibPhase1Research.md` | Research the problem space and prior art: at most 6 researchers, one per language group, each writes `_dev/<lang>.md` directly. |
| `NewLibPhase2ResearchReview.md` | Review the research for completeness, sources and relevance. |
| `NewLibPhase3Design.md` | Design the public API, justify every decision, and get explicit user approval of the API before review. |
| `NewLibPhase4DesignReview.md` | Review the API design against the research and the process rules. |
| `NewLibPhase5Docs.md` | Complete `_dev/DESIGN.md` (shared sections + one block per API entry); rationale and status live here, not in the end-user docs. |
| `NewLibPhase6DocsReview.md` | Review the design document for accuracy, completeness and justification. |
| `NewLibPhase7Scaffold.md` | Scaffold `akku/<lib>/` and materialise the design into inline end-user `# API-DOCS` blocks: `__init__.mojo` (shared docs + re-exports), one file per API entry, optional `_internal/`, `_dev/`, `_tests/`, `Taskfile.yml`. |
| `NewLibPhase8ScaffoldReview.md` | Review the scaffold against the agreed layout (`.agents/workflows/LibraryLayout.md`). |
| `NewLibPhase9Tests.md` | Write tests before any implementation exists. |
| `NewLibPhase10TestsReview.md` | Review the tests for coverage and correctness of intent. |
| `NewLibPhase11Implementation.md` | Implement against the API, docs and tests. |
| `NewLibPhase12ImplementationReview.md` | Review the implementation against all prior artifacts. |
| `NewLibPhase13FinalReview.md` | Final review and sign-off for the library. |

## Task workflows

Standalone workflows used whenever the matching situation occurs.

| Workflow | Purpose |
| --- | --- |
| `BugFix.md` | Fix a known bug, with a regression test. |
| `BugInvestigation.md` | Root-cause an unclear failure before changing code. |
| `Refactor.md` | Restructure code without changing behavior. |
| `DependencyReview.md` | Review a library dependency edge and justify it in the docs. |
| `APIReview.md` | Review an API change against the design rules. |
| `PerformanceInvestigation.md` | Investigate a performance problem and fix it. |
| `SecurityReview.md` | Security and hardening review. |
| `CreatePR.md` | Branch, `.changes/` entry, push and open the pull request. |
| `Release.md` | Turn `.changes/` into `CHANGELOG.md` and tag the release. |
| `MissingMojo.md` | The version-stamped workaround ledger: convention, `task missingMojo`, and the FFI triage rule. |
| `LibraryLayout.md` | Canonical library layout and documentation convention (reference). |
