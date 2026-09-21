# SecurityReview

## Purpose
Review a sibling library or change for security weaknesses in input validation, memory/ownership safety, TLS, secrets and unsafe/interop boundaries.

## Inputs
- Scope: the library or change under `mojoakku/<lib>/`.
- `<LIB>_DOCS.md` and the `api/` files for the intended trust boundaries.
- Any `unsafe`/FFI/interop code in `src/`.
- TLS, socket and HTTP configuration if in scope.
- Threat-relevant tests in `mojoakku/<lib>/_tests/`.

## Preconditions
- The scope compiles and its test suite is runnable.
- The review is scoped: either a full library or a specific change; the scope is stated.
- No security-relevant behavior change ships without this review passing.

## Roles
- `manager`: opens the task, bounds the scope, routes findings. Manager starts NO Manager.
- `reviewer`: owns the security review and the gate.
- `explore`: maps input entry points, trust boundaries and `unsafe` sites with `file:line`.
- `coder`: applies hardening fixes and runs sanitizers/tests (via `smd`) as evidence.
- `compliance`: consulted for data protection and user-data implications.

## Steps
1. `manager` opens the task and states scope and trust boundaries.
2. `explore` lists every input entry point, every network-facing boundary and every `unsafe`/interop site with `file:line`.
3. `reviewer` checks input validation: bounds, lengths, parsing, encoding, injection and malformed-input handling at each entry point.
4. `reviewer` checks memory/ownership safety: lifetimes, ownership transfer, aliasing and buffer handling, with special attention to `unsafe` blocks.
5. `reviewer` checks transport security when in scope: TLS verification, certificate handling, downgrade paths, and plaintext exposure of sensitive data.
6. `reviewer` checks secret handling: no hardcoded credentials, no secrets in logs, errors or test fixtures, secure default configuration.
7. `reviewer` checks the unsafe/interop boundary: each `unsafe` block has a stated safety invariant, and FFI input is validated before crossing.
8. `coder` applies required hardening fixes with tests proving each fix, then runs the suite and any sanitizers.
9. `reviewer` re-checks the fixes and applies the review gate.
10. `manager` commits the hardening fixes with a message naming the findings addressed.

## Artifacts / Outputs
- Security review report: findings with severity, `file:line`, affected trust boundary, and required fix.
- Hardening diff with accompanying tests.
- Re-check confirmation for each fixed finding.
- Compliance note when user data is affected.
- Task-log entry referencing the report.
- One git commit carrying the hardening fixes.

## Review Gate
`reviewer` verifies: (a) every entry point and `unsafe` site was examined, (b) findings are mapped to `file:line` and severity, (c) every high/critical finding is fixed with a test, (d) TLS and secret handling meet the documented expectations. An unexamined trust boundary or an outstanding high finding => reject.

## Handoff: BugFix.md for confirmed defects, Refactor.md for structural hardening, DependencyReview.md when a dependency is implicated; otherwise close the task.
