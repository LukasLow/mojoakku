# NewLibPhase5Docs

## Purpose
Turn the approved design into the complete `mojoakku/<lib>/<LIB>_DESIGN.md` design document, with one fully specified block per API entry (seven fields) and the shared (whole-library) sections, ready to be materialised into the tree by `NewLibPhase7Scaffold.md`.

## Inputs
- `mojoakku/<lib>/<LIB>_DESIGN.md` containing the approved design sections.
- The approved design review verdict from `NewLibPhase4DesignReview.md`.
- `mojoakku/<lib>/.research/<lang>.md` for reference names and rationale.
- This workflow file.

## Preconditions
- `NewLibPhase4DesignReview.md` returned `APPROVED`.
- Every public API entry in the design has complete semantics.
- The Manager starts no Manager subagent.

## Roles
- **Manager**: owns the phase, starts ONE `coder` to expand the docs, tracks progress with `agentlog`.
- **coder**: writes the full `<LIB>_DESIGN.md` shared sections and per-API blocks; changes only this file and the design is not reconsidered.
- **reviewer**: not started here; invoked by `NewLibPhase6DocsReview.md`.

## Steps
1. Manager confirms the list of public API members from the approved design's `## Public API` section.
2. For each API member, write one block with exactly the field set defined by `LibraryLayout.md` (same order in every block):
   - `Status:` one of `planned`, `scaffolded`, `tested`, `implemented`, `benchmarked` (default `planned` in this phase).
   - `Signature:` the exact Mojo declaration.
   - `Semantics:` full behavioral description (EOF, EINTR, EAGAIN, ownership, close, concurrency, IPv4/IPv6 where relevant).
   - `Errors:` every raised or returned error and whether it is recoverable.
   - `Tests:` the list of test names that will prove this API (names may be empty but the field must exist; tests are written in a later phase).
   - `Implementation status:` the current state, explicitly `not implemented` in this phase.
   - `Rationale:` the `MojoAkku uses X because Y` justification carried over from design.
3. Write the document's shared top-matter sections so the design is self-contained (these become the `__init__.mojo` docs block in Phase 7):
   - `## Purpose`
   - `## Status legend`
   - `## Dependencies` (graph edges to sibling MojoAkku libraries, each with the technical justification)
   - `## Overview`
   - `## Goals`
   - `## Non-Goals` (decisions deliberately NOT copied, each justified)
   - `## Reference APIs`
   - `## Public API` (the ordered list of entries from Step 2)
   - `## Error Surface`
   - `## Conventions`
   - `## Ownership and Lifecycle`
   - `## Open Questions`
4. Keep every field name and order identical across all API blocks so later agents and the low-vision user can navigate predictably.
5. Ensure no API from the design is missing and no API appears that is not in the design. Newly discovered APIs are not added here; they go back through design.
6. For every dependency edge, state the justification (e.g. `http -> tcp -> socket`) and confirm the dependency does not imply physical nesting.
7. Manager logs the completed docs via `agentlog`.
8. Manager commits the phase: stages `mojoakku/<lib>/<LIB>_DESIGN.md` and commits with a message naming the phase (e.g. `base64 phase 5: docs`).
9. Manager hands the docs to review.

## Artifacts / Outputs
- `mojoakku/<lib>/<LIB>_DESIGN.md` in the final format: shared sections plus one fully specified block per API member, and a documented dependency section. The design document is temporary; `NewLibPhase7Scaffold.md` materialises it into the tree and deletes it.
- Every API block carries Status, Signature, Semantics, Errors, Tests, Implementation status and Rationale.
- One `.agents/log.md` entry recording the phase result.
- One git commit for the phase.

## Review Gate
- Every public API member from the approved design has exactly one documented block.
- Every block uses the same seven-field set and order.
- Every dependency edge has a written justification.
- Status defaults to `planned`; implementation status is `not implemented`.
- No implementation or tests are written in this phase.
- The phase is committed.

## Handoff: `NewLibPhase6DocsReview.md`
