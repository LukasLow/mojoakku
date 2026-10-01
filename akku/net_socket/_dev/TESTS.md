# net_socket — test record

## Frozen contracts and coverage

Authoritative inputs: the inline API-DOCS in `__init__.mojo`, `socket_address.mojo`
and `socket.mojo`. Tests use only public sibling APIs and independently observed
kernel descriptors; no private `Socket` fields or private sibling modules are
imported.

| Concern | Program | Tests | Contract assertions |
| --- | --- | ---: | --- |
| Endpoint values | `test_net_socket_address.mojo` | 3 | IPv4/IPv6 accessors, independent copies, port 0/65535, equality including scope and port, brackets/numeric scope, IPv4 scope OTHER/op address |
| Connections | `test_net_socket_connection.mojo` | 7 | Both real loopbacks, local endpoint family/IP/assigned port, accepted lifetime independent of listener, wildcard bind, mismatch/backlog validation retains ownership (including successful positive backlog 1 << 40), native bind failure retains ownership, native failed connect consumes owner |
| Transfers | `test_net_socket_transfer.mojo` | 8 | Binary prefixes, short read without assuming TCP packets, untouched suffix/outside borrowed subspan, write accepted prefix, empty direct read/write, flush, read_exact/read_to_end/write_all, EOF repeatability, UNEXPECTED_EOF consumed prefix, empty closed helper contract, half-close idempotence and receiving replies |
| Ownership | `test_net_socket_ownership.mojo` | 5 | Creation and exactly released descriptor, idempotent close, forged family rejected without fd, move preserves sole owner, destructor native release, every direct closed operation including invalid/empty argument precedence and op labels |
| Native contracts | `test_net_socket_native.mojo` | 7 | Created/accepted FD_CLOEXEC, kernel IPv6-only flag, actual SIGPIPE-safe created and accepted writes with process default policy, real EBADF→CLOSED and failed close invalidation, bounded read deadline TIMED_OUT with unchanged buffer and usable owner, bounded accept/read deadline under a real SIGALRM with EINTR absorbed |

Total: **30 test functions in 5 standalone programs**. No `_tests/__init__.mojo`.
FD snapshots use libc fcntl over descriptors 0–4095 and require exactly one new
observable descriptor. They never read a library field. Fixtures do not perform
parallel opens while comparing snapshots, and do not reallocate an externally
closed descriptor before calling public close. The failed-connect test targets
loopback TCP port zero, which cannot name a listener. Native Linux rejects it
with ECONNREFUSED; native Darwin rejects it with EADDRNOTAVAIL. Both exercise
OTHER/op connect and consumed ownership without waiting for platform-specific TCP
retransmission timeouts.

## Bounded-wait semantics (the shipped model)

Every descriptor is non-blocking from creation. A call that would block instead
waits on `os_poll.wait` under an optional `time_clock` deadline:

- **EAGAIN/EWOULDBLOCK and EINTR are absorbed.** `read`, `write`, `accept` and
  `connect` wait for the readiness they need and retry; they do not surface
  WOULD_BLOCK or INTERRUPTED while the owner stays usable.
- **A reached deadline raises TIMED_OUT** (`op` names the call) and leaves the
  owner usable. Deadlines are absolute monotonic instants.
- **No deadline set** means the wait repeats until readiness: ordinary blocking
  semantics, but only ever via bounded poll slices.
- A closed or invalid descriptor surfaces as CLOSED; the SIGPIPE path is bounded
  by a write deadline, so it no longer depends on OS packet timing.

## Required edge cases and limits

- EOF: real peer write shutdown, repeated direct EOF and owned read_to_end.
- Bounded waits: real empty-receive deadline on read; real deadline on accept.
- Signals: a SIGALRM handler (thin C-ABI callback, no allocations) interrupts an
  actual accept/read; the test requires the wait to absorb EINTR and report the
  deadline (TIMED_OUT), never a surfaced INTERRUPTED, with unchanged destination
  and retained ownership.
- SIGPIPE: default process policy; created and accepted sockets both survive a
  write after the peer's `shutdown`, mapping EPIPE to OTHER or reaching TIMED_OUT.
- Ownership/close: independent kernel fcntl observations, move, destructor,
  idempotence, closed-operation precedence, and failed native close.
- Invalid input: IPv4 scope, unknown family, cross-family endpoints, zero/negative
  backlog, empty read.
- Positive short writes are permitted: the test verifies the actual returned
  prefix/count and bytes, without requiring the kernel to produce a short send.
- Windows is not a target yet (needs a Winsock backend); tests run on Linux in the
  smd container and do not claim native Mojo macOS runtime certification.

## Running the suite

The library Taskfile runs each program with the shared runner and **no external
`timeout` watchdog** — the waits are bounded in code, so the suite needs no GNU
coreutils:

```sh
smd -t '{task -t akku/net_socket/Taskfile.yml ci}'
```

Latest result: **30 passed, 0 failed, 0 skipped** across the five programs.
