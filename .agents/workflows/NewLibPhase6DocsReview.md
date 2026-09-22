# NewLibPhase6DocsReview

## Purpose
Verify that every designed API for `<lib>` has a complete, consistent block in `mojoakku/<lib>/<LIB>_DESIGN.md` and that the design matches the approved design exactly.

## Inputs
- `mojoakku/<lib>/<LIB>_DESIGN.md`.
- The approved design sections and the design review verdict.
- The list of public API members from `NewLibPhase3Design.md`.
- This workflow file.

## Preconditions
- `NewLibPhase5Docs.md` is complete.
- The design is frozen; this phase compares docs against it but does not redesign.
- The Manager starts no Manager subagent.

## Roles
- **Manager**: starts ONE `reviewer`, routes findings, decides whether the docs phase is repeated.
- **reviewer**: performs the review, returns `APPROVED` or `NEEDS_WORK` with findings. Changes nothing.
- **coder** (only on rework): fixes the specific docs findings; review is repeated.

## Steps
1. Manager starts ONE `reviewer` with: "Review `mojoakku/<lib>/<LIB>_DESIGN.md`. Check that every designed API has a documented block, that each block has Status, Signature, Semantics, Errors, Tests and Implementation status (plus Rationale), and that the design matches the approved design. Report `APPROVED` or `NEEDS_WORK` with findings."
2. reviewer builds the set of designed API members and the set of documented blocks and diffs them in both directions: missing blocks and undocumented extra blocks are both findings.
3. reviewer checks every block for the required fields: `Status`, `Signature`, `Semantics`, `Errors`, `Tests`, `Implementation status` (and `Rationale`). Any missing field is a finding with `file:line`.
4. reviewer checks field consistency: identical field names and order across all blocks; predictable navigation for a low-vision reader.
5. reviewer checks docs-vs-design consistency: signatures, semantics, error surface and rationale match the approved design; divergences without an approved design change are findings.
6. reviewer checks that the `Status` values are valid (`planned` / `scaffolded` / `tested` / `implemented` / `benchmarked`) and that no block claims `implemented` in this phase.
7. reviewer checks the `## Dependencies` section: every edge has a written technical justification and no physical nesting is implied.
8. reviewer returns `APPROVED` or `NEEDS_WORK` with a numbered findings list, each with `file:line` and the required fix.
9. If `NEEDS_WORK`, Manager sends the findings back into `NewLibPhase5Docs.md` and repeats this review once.
10. If `APPROVED`, Manager logs the verdict via `agentlog`.
11. Manager commits the phase with a message naming the phase and verdict (e.g. `base64 phase 6: docs review APPROVED`).
12. Manager hands off to scaffold.

## Artifacts / Outputs
- A written review verdict (`APPROVED` / `NEEDS_WORK`) with a findings list tied to `file:line`.
- Corrected `mojoakku/<lib>/<LIB>_DESIGN.md` when a rework pass was required.
- One `.agents/log.md` entry recording the verdict.
- One git commit for the phase.

## Review Gate
- The designed API set and the documented block set are identical.
- Every block has all required fields in the fixed order.
- Docs and approved design agree, and every dependency edge is justified.
- Verdict `APPROVED` before the scaffold phase starts.

## Handoff: `NewLibPhase7Scaffold.md`
