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
