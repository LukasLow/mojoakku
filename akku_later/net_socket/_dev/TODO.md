# net_socket backlog

## Handoff — why this code lives in `akku_later/`

The working implementation that was released as `v0.10.0` was **deferred on
2026-10-01**: it was moved here, out of `akku/`, so the test pool no longer runs
it (its macOS CI run was flaky). Nothing below is deleted — this is a clean
parking spot, not the end of the library.

`akku_later/` is **not discovered** by the test/CI tooling (only `akku/*` is).
The catalogue entry `.repo/todo/net_socket.yml` is `status: todo` with the new
dependency closure.

### What the current code does (keep as reference)

- Owned **blocking** IPv4/IPv6 stream socket (`Socket`) plus a numeric
  `SocketAddress`. libc via `std.ffi external_call`. Targets Linux + macOS.
- No timeouts, no readiness wait. Blocking calls can wait indefinitely.

### Why it was deferred

1. **No timeouts.** Because the API is purely blocking, the test runner needed an
   external watchdog (`timeout 180` in the Taskfile). GNU `timeout` does not
   exist on macOS → the suite could not run locally there.
2. **Flaky macOS test.** `test_sigpipe_safe_with_default_process_signal_policy`
   forces an EPIPE by `shutdown(SHUT_RDWR)` then a blocking write loop; Darwin
   may buffer the first write, so no error is raised within the loop. Linux
   always raised → green on Linux, flaky on macOS. CI run evidence:
   https://github.com/LukasLow/mojoakku/actions/runs/36815005873

Both have the **same root cause**: the blocking I/O model. The reference design
that avoids it is `xlib/_internal/socket.mojo` (non-blocking + `poll` + deadlines
+ error-as-value). The best target is **timeout-bounded blocking**: a blocking
public API, non-blocking internally, driven by `poll` with a deadline.

### What net_socket must wait for (the dependency closure)

| Dependency | State | What it supplies |
| --- | --- | --- |
| `io_core` | done | Reader/ByteWriter, ReadResult, IoError/Kind |
| `net_ip` | done | AddressFamily, IpAddress, Ipv4/Ipv6 |
| `time_clock` | to build | Deadline, Duration, monotonic clock |
| `os_poll` | to build | synchronous fd readiness (`poll`) with bounded waits |

Only when `time_clock` and `os_poll` are `done` may the rewrite start. The
rewrite should then make `net_socket`'s waits bounded in-code, so **no external
GNU `timeout`** and **no OS-timing-dependent test** remain.

### Rebuild notes for the rewrite owner

- Public API stays blocking and simple; move `O_NONBLOCK` + `poll` behind it.
- Every wait must be bounded by a caller-supplied `timeout_ms` (connect, read,
  write, accept, shutdown).
- Tests must never depend on how fast the OS delivers EPIPE/RST; assert on a
  bounded-wait outcome instead.
- Remove the `timeout 180` wrapper from the library Taskfile once waits are
  bounded; the runner must not require GNU coreutils.

## Researched but unshipped candidates (keep)

- nonblocking — readiness-based low-level transfers — c.md §6.
- deadlines — bounded connect/read/write — go.md §8.
- cancellation — explicit interruption mechanism — go.md §8.
- UDP datagrams — preserve message boundaries — python.md §3.
- Unix-domain sockets — local IPC addresses — python.md §1.
- socket options — narrowly scoped option controls — c.md §3.
- peer_address — inspect remote numeric endpoint — rust.md §3.
- duplicate/adopt/release — explicit native descriptor interoperability — rust.md §5.
- readiness/async — event loop integration when stable Mojo supports it — js_ts.md §6.
- name resolution — hostname-to-address lookup in a later layer — go.md §7.
- TLS streams — encrypted transport in a sibling layer — python.md §9.
- vectored I/O — scatter/gather transfers — rust.md §3.
- shutdown_read/both — disable other stream directions — python.md §3.
- IPv6 flowinfo — explicit traffic flow metadata — rust.md §7.
- Windows sockets — native Windows transport — rust.md §8.
- queued writes — buffered backpressure in a later stream layer — js_ts.md §12.
- framed messaging — explicit message boundaries in a sibling layer — js_ts.md §12.
