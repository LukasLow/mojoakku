# NewLibPhase4DesignReview

## Purpose
Verify that the derived Mojo API design for `<lib>` is semantically complete, consistent with Mojo language constraints, and justified decision by decision.

## Inputs
- `mojoakku/<lib>/<LIB>_DOCS.md` containing the design section from `NewLibPhase3Design.md`.
- `mojoakku/<lib>/research/<lang>.md` for all languages.
- The approved research review verdict.
- This workflow file.

## Preconditions
- `NewLibPhase3Design.md` is complete: design sections exist, every API entry has semantics, and justifications are present.
- The `## Open Questions` section is resolved or each open item has a written interim answer.
- The Manager starts no Manager subagent.

## Roles
- **Manager**: starts ONE `reviewer`, routes findings, decides whether design goes back to `NewLibPhase3Design.md`.
- **reviewer**: performs the review, returns `APPROVED` or `NEEDS_WORK` with findings. Changes nothing.
- **coder / designer** (only on rework): fixes the specific findings; review is repeated.

## Steps
1. Manager starts ONE `reviewer` with: "Review the design in `mojoakku/<lib>/<LIB>_DOCS.md`. Check semantic completeness, consistency with Mojo language constraints, and that every decision is justified with a named reference API. Report `APPROVED` or `NEEDS_WORK` with findings."
2. reviewer checks semantic completeness: for every public API entry, EOF, EINTR, EAGAIN, buffer/socket ownership, close behavior, error surface and recoverable-vs-unrecoverable errors are all documented. Missing items are listed per API entry.
3. reviewer checks consistency with Mojo constraints: ownership and lifetime claims match Mojo's value/reference model, `raises` usage is coherent, no Python dependency is required by the design, and no hidden global state is relied upon.
4. reviewer checks justification: every non-obvious decision carries a `MojoAkku uses X because Y` statement and names at least one reference API from the research files; unsourced or circular justifications are flagged.
5. reviewer checks for silent invention: any API whose shape cannot be traced back to the research files is flagged as an invented API.
6. reviewer checks that the documented `Decisions NOT to copy` match the research and are reasoned, not arbitrary.
7. reviewer checks that all `## Open Questions` are resolved or consciously accepted with a written rationale.
8. reviewer returns `APPROVED` or `NEEDS_WORK` with a numbered findings list, each finding with `file:line` and the required fix.
9. If `NEEDS_WORK`, Manager sends the findings back into `NewLibPhase3Design.md`, then repeats this review once.
10. If `APPROVED`, Manager logs the verdict via `agentlog` and hands off to docs.

## Artifacts / Outputs
- A written review verdict (`APPROVED` / `NEEDS_WORK`) with a findings list tied to `file:line` in `<LIB>_DOCS.md`.
- Corrected design sections when a rework pass was required.
- One `.agents/log.md` entry recording the verdict.

## Review Gate
- Every public API entry has complete semantics.
- Every decision is justified and names a reference API.
- The design is consistent with Mojo language constraints and implementable in pure Mojo.
- All open questions are answered or consciously accepted.
- Verdict `APPROVED` before the docs phase starts.

## Handoff: `NewLibPhase5Docs.md`
