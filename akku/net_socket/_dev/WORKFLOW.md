# net_socket workflow record

Session API approval waiver recorded; 13 phases remain mandatory.
Research in progress. No implementation exists.

## Phase 1 — research corpus

Six mandatory reference languages completed by three language-group researchers;
Mojo supplied by the local buch. All twelve questions have answers and citations.
Optional languages omitted for the pragmatic first release. Backlog seeded.

## Runner correction — Markdown blacklist

Independent reviewer APPROVED: exclude .md globally, keep other file extensions
relevant. Container regression suite: 41 tests passed. Changing this shared runner
necessarily makes this library PR select full suites until a new full-tested tag.

## Phase 2 — research review APPROVED

Independent reviewer confirmed six languages, all twelve questions, primary
sources, reconciled blocking/runtime differences and complete candidate backlog.
No required findings. IPv6 scope/flowinfo must be decided explicitly in design.
Markdown regression reproduced against v0.9.0 in an isolated temporary copy.

## Phase 3 — API design

Two public entries, SocketAddress and Socket, with justified io_core/net_ip edges.
Session user waiver replaces the API presentation/approval gate; no new approval
requested. Scope IDs included, flowinfo deferred, empty Reader buffers rejected,
connect failure consumes owner, close never retried, SIGPIPE/CLOEXEC policies
explicit. Native platform ABI must be verified before support claims.
Buch structs.md move signature corrected from its exact documented Movable trait.

## Phase 4 — design review APPROVED

Independent reviewer approved complete semantics, existing trait compatibility,
sole ownership, public sibling dependencies and accurate live backlog. Native
macOS ABI/close/SIGPIPE verification remains an implementation acceptance gate.

## Phase 5 — complete documentation

Coder verified seven ordered fields for both public entries and expanded exact
inherited helper signatures, operation/error names and named planned tests.
No implementation or tests created; approved semantics unchanged.

## Phase 6 — documentation review APPROVED

Independent reviewer verified two entries, seven ordered fields, exact approved
semantics, justified siblings, planned real interruption/security/lifecycle tests,
and no implementation claims or signature drift. No required findings.

## Phase 7 — compile-ready scaffold

Two public API files and exactly two root exports; private aliases keep imports
out of the public root. All twenty own method bodies are the exact abort stub.
Taskfile derives the shared library runner with method:none; no registration or
shared helper change. Consumer import: `smd -t '{task net_socket::compile}'`
passed, raw output in scaffold.log. No implementation or tests yet.

### Phase 8 rework — public error contract

Reviewer found a dangling developer-only Error Surface reference. Scaffold
comments now include the full errno mapping, immediate capture/numeric opaque
detail, EOF distinction, helper/direct retry and recovery policies. No code or
tests changed; returned to scaffold before repeating the review.

## Phase 8 — scaffold review APPROVED, GO

Independent reviewer confirmed the only blocker resolved. Two public entries and
all twenty own stubs, inherited helpers, layout, exact aborts, root exports and
generic Taskfile pass. Independent consumer compilation passed. Rework was only
comments, so compile evidence remains valid. No implementation introduced.

### Phase 7/8 rework — instantiated abort import

Phase 9 compile revealed std.os.abort had not been explicitly imported: the
consumer import did not instantiate method bodies. Added that import to both API
files without changing any body, signature or contract. Tests are paused until
an independent scaffold re-check. No implementation is allowed yet.

### Phase 8 — instantiated scaffold recheck APPROVED

Independent reviewer executed the address test program: compiler succeeded and
runtime reached the exact not-yet-implemented abort, exit 1. All twenty bodies
remain abort-only; no implementation leaked. Tests may resume.

## Phase 9 — tests and observed red baseline

Thirty authored behavioral functions in five programs, bounded test dispatch.
Each program compiles then aborts at an unimplemented constructor (5 observed
program failures, not 30 individually executed case failures); aggregate stops
at the first abort. Raw logs and concern/edge-case matrix in TESTS.md.
Independent native signal fixture proves real EINTR/EAGAIN and default SIGPIPE
behavior on Linux aarch64, Mojo 1.1.0. No production implementation added.

## Phase 10 — tests review APPROVED

Fresh independent reviewer froze f609d1e, reproduced the exact aggregate abort
(task 201/host 1), and separately all five compile-success/runtime-abort programs
(exit 1 each). Thirty authored tests correctly counted. Public success paths,
EOF, actual EINTR/EAGAIN, accepted/client SIGPIPE, CLOEXEC, IPv6-only, ownership,
closed precedence and invalid inputs are non-tautological. No private imports.
Real ETIMEDOUT induction remains unproven; Phase 12 must inspect the exact mapping
and target constants. No tests changed. Implementation is now permitted.
