# net_socket — Phase 9 test record

## Frozen contracts and coverage

Authoritative inputs: the Phase 8 approved inline API-DOCS in `__init__.mojo`,
`socket_address.mojo` and `socket.mojo`. No production implementation was added.
Tests use only public sibling APIs and independently observed kernel descriptors;
no private `Socket` fields or private sibling modules are imported.

| Concern | Program | Authored tests | Contract assertions |
| --- | --- | ---: | --- |
| Endpoint values | `test_net_socket_address.mojo` | 3 | IPv4/IPv6 accessors, independent copies, port 0/65535, equality including scope and port, brackets/numeric scope, IPv4 scope OTHER/op address |
| Connections | `test_net_socket_connection.mojo` | 7 | Both real loopbacks, local endpoint family/IP/assigned port, accepted lifetime independent of listener, wildcard bind, mismatch/backlog validation retains ownership (including successful positive backlog 1 << 40), native bind failure retains ownership, native failed connect consumes owner |
| Transfers | `test_net_socket_transfer.mojo` | 8 | Binary prefixes, short read without assuming TCP packets, untouched suffix/outside borrowed subspan, write accepted prefix, empty direct read/write, flush, read_exact/read_to_end/write_all, EOF repeatability, UNEXPECTED_EOF consumed prefix, empty closed helper contract, half-close idempotence and receiving replies |
| Ownership | `test_net_socket_ownership.mojo` | 5 | Creation and exactly released descriptor, idempotent close, forged family rejected without fd, move preserves sole owner, destructor native release, every direct closed operation including invalid/empty argument precedence and op labels |
| Native contracts | `test_net_socket_native.mojo` | 7 | Created/accepted FD_CLOEXEC, kernel IPv6-only flag, actual SIGPIPE-safe created and accepted socket writes with process default policy, real EBADF→CLOSED and failed close invalidation, real EAGAIN→WOULD_BLOCK with unchanged buffer/recovery, real signal-interrupted accept/read without hidden retry and usable owner |

Total: **30 authored test functions in 5 standalone programs**. No `_tests/__init__.mojo`.
FD snapshots use libc fcntl over descriptors 0–4095 and require exactly one new
observable descriptor. They never read a library field. Fixtures do not perform
parallel opens while comparing snapshots, and do not reallocate an externally
closed descriptor before calling public close. The failed-connect test targets loopback TCP port zero, which cannot name a
listener. Native Linux rejects it with ECONNREFUSED; native Darwin rejects it
with EADDRNOTAVAIL. Both exercise OTHER/op connect and consumed ownership without
waiting for platform-specific TCP retransmission timeouts.

The native nonblocking fixture changes only an independently observed kernel fd's
flags, induces an actual empty receive EAGAIN, then restores blocking flags and
verifies byte transfer recovery. It does not assert a public nonblocking API.

## Required edge cases and limits

- EOF: real peer write shutdown, repeated direct EOF and owned read_to_end.
- EINTR: SIGALRM handler is a thin C-ABI callback with no allocations or I/O;
  siginterrupt disables restart, alarm interrupts actual accept/read, and the
  test requires INTERRUPTED/op plus unchanged destination and retained ownership.
- EAGAIN/WOULD_BLOCK: actual kernel fixture described above, never injected error.
- Ownership/close: independent kernel fcntl observations, move, destructor,
  idempotence, closed-operation precedence, and failed native close.
- Invalid input: IPv4 scope, unknown family, cross-family endpoints, zero/negative
  backlog, empty read.
- Public nonblocking/deadline/cancellation configuration: **N/A**, deliberately
  deferred APIs recorded in TODO.md, not skipped tests. The outer test-process
  watchdog is harness protection, not a socket timeout API.
- ETIMEDOUT mapping: the first macOS CI observed TIMED_OUT after 75 seconds
  from the original non-listening-port fixture. No bounded deterministic timeout
  case is retained in the regular suite. Blocking API has
  no deadline configuration; mapping constants must receive implementation review.
  No external host, firewall manipulation or fake timeout shim is introduced.
- Positive short writes are permitted: test verifies actual returned prefix/count
  and bytes, without requiring the kernel to produce a short send on demand.
- EINTR retries of provided complete-transfer helpers are inherited from io_core;
  their existing sibling suite covers retry policy. Socket tests exercise each
  provided helper on real sockets and direct socket EINTR separately.
- macOS native ABI probe exists from scaffold, but this suite is run in the Linux
  smd container. It does not claim native Mojo macOS runtime certification.

## Observed failing baseline

Exact aggregate command from repository root:

```sh
smd -t '{task -t akku/net_socket/Taskfile.yml test}'
```

Raw output: `baseline.log`. Host command exits 1; smd reports task exit 201,
Task reports child exit 1. The runner stops at the first address stub abort.
**One test program abort is observed in this aggregate execution.**

All programs independently compiled and executed using:

```sh
smd -t '{for file in akku/net_socket/_tests/*.mojo; do echo "== $file"; timeout 30 mojo run -I . "$file"; code=$?; echo "PROGRAM_EXIT=$code"; done}'
```

Raw output: `baseline-programs.log`. **5/5 programs compile and then abort with
exit 1 at the expected unimplemented production constructor.** Zero syntax/type
errors or compiler warnings. The shell loop itself exits 0 because it deliberately
continues after recording each child exit.

This is **30 authored cases and 5 observed program failures**, not a claim that
30 case bodies all executed or individually failed. Abort terminates each process
before TestSuite can report remaining case results. No feature tests passed.

The library Taskfile uses `timeout 180` around its ordinary shared test dispatch.
The intended command runs in the pinned Linux container, where timeout exists.
Root dispatch/helpers, API signatures, docs and stubs were not modified by tests.

## Independent fixture verification

Before relying on stub-blocked native tests, a separate `.tmp/socket-signal-fixture.mojo`
probe was built from the same signal fixture without any production Socket import.
Raw output/environment: `native-test-fixture.log`: **Linux aarch64, Mojo 1.1.0 (8189361e)**, exit 0.

```sh
smd -t '{uname -s -m; mojo --version; timeout 15 mojo run -I . .tmp/socket-signal-fixture.mojo}'
```

It verifies actual pipe read interruption (errno EINTR = 4), unchanged buffer,
fcntl-controlled nonblocking empty pipe read (errno EAGAIN = 11), and restores
SIGPIPE default, proven by an independent child dying from signal 13 after writing
an unread pipe. No C compiler, Python runtime import or package is needed.
Signal return is represented as an erased optional pointer never dereferenced;
`signal(SIGPIPE, null)` uses the verified target SIG_DFL representation.
The standalone probe uses OwnedDLHandle for libc write because the compiler
rejects two external_call signatures for write when stdout's stdlib call is linked.
Socket tests use send/recv through public API and have no such symbol collision.

Initial Phase 9 compilation identified missing std.os.abort imports in scaffold.
Manager returned to scaffold/review and committed the correction before this
recorded runtime baseline. No production body was implemented to make tests pass.
