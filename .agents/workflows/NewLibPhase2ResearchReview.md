# NewLibPhase2ResearchReview

## Purpose
Verify that the per-language research for `<lib>` is complete, contradiction-free and evidence-based before any API design begins.

## Inputs
- `mojoakku/<lib>/.research/<lang>.md` for every language in the frozen language list.
- The frozen standardized question set from `NewLibPhase1Research.md`.
- This workflow file.

## Preconditions
- `NewLibPhase1Research.md` has been executed for `<lib>` and all research files exist.
- A `reviewer` agent can be started; the Manager starts no Manager.
- The research files are treated as frozen during review; the reviewer reads, it does not rewrite them.

## Roles
- **Manager**: starts ONE `reviewer` for this phase, routes findings, decides whether to send the phase back.
- **reviewer**: performs the review, returns a verdict and a concrete findings list. Changes nothing.
- **researcher** (only if the Manager sends the phase back): fixes the specific findings and the review is repeated.

## Steps
1. Manager confirms the frozen language list and checks that exactly one `mojoakku/<lib>/.research/<lang>.md` exists per listed language.
2. Manager starts ONE `reviewer` with: "Review the research for `<lib>` in `mojoakku/<lib>/.research/`. Check completeness against the standardized question set, contradictions between languages, missing sources, and whether cross-language conclusions are evidence-based. Report `APPROVED` or `NEEDS_WORK` with a concrete findings list."
3. reviewer checks completeness: every one of the 12 questions is answered for every language; missing answers are listed per file and per question.
4. reviewer checks contradictions: statements that conflict across files (e.g. one file says `recv` is non-blocking, another says blocking) are listed with both `file:line` references and asked to be reconciled with evidence.
5. reviewer checks sources: every non-`GUESS` statement has a citation (URL, RFC, or `repo/path:line`); unreachable, invented or circular sources are flagged.
6. reviewer checks the cross-language conclusions: any conclusion of the form "language X does it this way" must be directly supported by that language's file and its sources.
7. reviewer checks that guesses are explicitly marked `GUESS:` and are not treated as facts anywhere.
8. reviewer returns `APPROVED` or `NEEDS_WORK` plus a numbered findings list, each finding with `file:line` and the required fix.
9. If `NEEDS_WORK`, Manager starts targeted `researcher` agents to fix only the listed findings, then returns to Step 1 with one new reviewer pass.
10. If `APPROVED`, Manager logs the verdict via `agentlog` and hands off to design.

## Artifacts / Outputs
- A written review verdict (`APPROVED` / `NEEDS_WORK`) with a findings list, each finding tied to `file:line`.
- Corrected research files when a rework pass was required.
- One `.agents/log.md` entry recording the verdict.

## Review Gate
- All findings are closed or explicitly deferred with a written reason.
- No contradiction across language files is left unresolved without evidence.
- The review verdict is `APPROVED` before design starts.

## Handoff: `NewLibPhase3Design.md`
