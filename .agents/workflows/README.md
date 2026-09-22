# MojoAkku Workflows — Index

Every workflow listed here lives in this directory (`.agents/workflows/`) and
is owned by the agent type named in it. This file is the entry point: pick the
phase you are in and follow the matching workflow.

## New library pipeline

The full path for a new library, in order. Each phase has a review gate before
the next phase starts, and each phase ends with a git commit naming the phase
(and, for a review phase, its verdict).

```
NewLibPhase1Research -> NewLibPhase2ResearchReview -> NewLibPhase3Design
  -> NewLibPhase4DesignReview -> NewLibPhase5Docs -> NewLibPhase6DocsReview
  -> NewLibPhase7Scaffold -> NewLibPhase8ScaffoldReview -> NewLibPhase9Tests
  -> NewLibPhase10TestsReview -> NewLibPhase11Implementation
  -> NewLibPhase12ImplementationReview -> NewLibPhase13FinalReview
```

| Phase workflow | Purpose |
| --- | --- |
| `NewLibPhase1Research.md` | Research the problem space and prior art: at most 6 researchers, one per language group, each writes `.research/<lang>.md` directly. |
| `NewLibPhase2ResearchReview.md` | Review the research for completeness, sources and relevance. |
| `NewLibPhase3Design.md` | Design the public API, justify every decision, and get explicit user approval of the API before review. |
| `NewLibPhase4DesignReview.md` | Review the API design against the research and the process rules. |
| `NewLibPhase5Docs.md` | Write `<LIB>_DESIGN.md` (shared sections + one seven-field block per API entry) as the design document to be materialised in Phase 7. |
| `NewLibPhase6DocsReview.md` | Review the design document for accuracy, completeness and justification. |
| `NewLibPhase7Scaffold.md` | Scaffold `mojoakku/<lib>/` from `<LIB>_DESIGN.md`: `__init__.mojo` (shared docs + re-exports), one file per API entry, optional `_internal/`, `_tests/`, `Taskfile.yml`; then delete `<LIB>_DESIGN.md`. |
| `NewLibPhase8ScaffoldReview.md` | Review the scaffold against the agreed layout. |
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
| `Release.md` | Prepare and cut a release. |
