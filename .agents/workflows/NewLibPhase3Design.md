# NewLibPhase3Design

## Purpose
Derive the Mojo public API for `<lib>` from the reviewed research and record every decision with its justification and reference API in `mojoakku/<lib>/<LIB>_DOCS.md`.

## Inputs
- `mojoakku/<lib>/.research/<lang>.md` for all languages.
- The approved research review verdict.
- `AGENTS.md` and this workflow file.
- The Mojo language constraints (ownership, `raises`, `var`/`borrowed`, no hidden global state, compile-time metaprogramming).

## Preconditions
- `NewLibPhase2ResearchReview.md` returned `APPROVED`.
- The research directory for `<lib>` exists and is complete.
- The Manager has not started any Manager subagent.

## Roles
- **Manager**: owns the phase, starts ONE `coder` or `designer` (as appropriate) to write the design into the docs, starts `explore`/`researcher` when a fact must be checked.
- **coder / designer**: writes the design sections into `mojoakku/<lib>/<LIB>_DOCS.md`, documenting semantics and justifications.
- **reviewer**: not started here; invoked by `NewLibPhase4DesignReview.md`.

## Steps
1. Manager opens `mojoakku/<lib>/<LIB>_DOCS.md` and adds (or completes) the design section set:
   - `## Overview`
   - `## Goals`
   - `## Non-Goals`
   - `## Reference APIs`
   - `## Public API`
   - `## Semantics`
   - `## Error Surface`
   - `## Ownership and Lifecycle`
   - `## Open Questions`
2. For every proposed API entry, write the signature and, below it, the full semantics — not only the type:
   - meaning and preconditions of every parameter and return value;
   - EOF behavior (what a read returns at end of stream);
   - EINTR / interruption behavior (retry, propagate, or surface a recoverable error);
   - EAGAIN / would-block behavior (how partial progress is reported);
   - ownership of buffers and of the socket/handle (who allocates, who frees, who may move it);
   - close/shutdown behavior and what happens to in-flight or subsequent operations;
   - the error surface (which errors are raised, which are returned, which are unrecoverable);
   - which errors are recoverable and how the caller is expected to retry.
3. For every non-obvious choice, write an explicit justification in the form `MojoAkku uses <name> because <reason>.` Name the reference APIs for the decision (from the research files), e.g. `MojoAkku uses \`recv\` because POSIX/C, Rust and Python all expose it and it maps directly onto a single syscall; Go's `Read` is rejected because ...`.
4. Explicitly document decisions NOT to copy (referencing the `Decisions NOT to copy` section of the research files) and why they do not fit Mojo.
5. Validate the design against Mojo language constraints: value vs. reference semantics, `raises` vs. error values, `var`/`borrowed`/`inout` usage, no hidden global state, and whether the design can be implemented in pure Mojo without a Python dependency.
6. List every API entry in the `## Public API` section with a stable name that `NewLibPhase5Docs.md` will later document and `NewLibPhase7Scaffold.md` will stub.
7. Record unresolved questions in `## Open Questions`; each must be answered before `NewLibPhase4DesignReview.md` can approve.
8. Manager logs the design draft via `agentlog`.
9. **User review gate (mandatory).** Manager presents the proposed public API to the user for discussion and approval before any review runs. The presentation must be readable for the low-vision user: the `## Public API` list with each signature and its one-line meaning, plus the decisions NOT to copy. The Manager uses the `question`/`show` tooling to collect the user's verdict. Only after the user explicitly approves (or the requested changes are applied and re-approved) does the phase continue. The user's decision and any requested changes are recorded in the `.agents/log.md` entry.
10. Manager commits the phase: stages `mojoakku/<lib>/<LIB>_DOCS.md` and commits with a message naming the phase (e.g. `base64 phase 3: API design`).
11. Manager hands the design to review.

## Artifacts / Outputs
- `mojoakku/<lib>/<LIB>_DOCS.md` containing the derived design: goals, non-goals, reference APIs, public API list, full semantics, error surface, ownership/lifecycle, and per-decision justifications.
- An explicit list of decisions NOT copied from other languages.
- A `## Open Questions` list, ideally empty at handoff.
- A recorded user verdict on the public API (approved / changes requested and applied).

## Review Gate
- Every public API entry has semantics and not just a signature.
- Every non-obvious decision has a `MojoAkku uses X because Y` justification naming a reference API.
- No API is invented "silently": every choice traces to the research.
- The design is implementable under Mojo language constraints.
- The user has explicitly approved the public API (Step 9), or requested changes were applied and re-approved.
- No code is written in this phase.
- The phase is committed.

## Handoff: `NewLibPhase4DesignReview.md`
