# os_poll research: go

Scope: **synchronous file-descriptor readiness with a bounded timeout** — `select`/`poll`/`epoll`/`kqueue`, one thread waits, a `Duration`/millisecond limit ends the wait. Explicitly **not async**.

> **Go's netpoller and Rust's mio are async/event-driven — do not confuse them with this scope.**
> Go's standard `net` package is *blocking-looking* but built on an asynchronous runtime network poller: every goroutine blocked in `net.Conn.Read` is actually parked and woken by an `epoll`/`kqueue` loop inside the runtime (`runtime/netpoll.go`). That is the opposite architecture from "call `poll()` with a timeout and get control back." The **synchronous subset** in Go is:
> - `golang.org/x/sys/unix.Poll` / `unix.Ppoll` / `unix.Select` — a direct, blocking `poll(2)`/`ppoll(2)`/`select(2)` wrapper that runs on the calling thread; and
> - `syscall.Select` on Unix (the frozen legacy package).
> `os.File.SetReadDeadline` / `SetWriteDeadline` sit in between: the deadline itself is implemented by the async runtime poller, not by a synchronous `poll` syscall.

## 1. Standard library support

- **`syscall` (standard library, Unix):** provides `Select(nfd int, r, w, e *FdSet, timeout *Timeval) (n int, err error)` and, on Linux, `EpollCreate`, `EpollCreate1`, `EpollCtl`, `EpollWait`. `syscall` is documented as legacy: "The primary use of syscall is inside other packages that provide a more portable interface… Use those packages rather than this one if you can." and "NOTE: Most of the functions, types, and constants defined in this package are also available in the golang.org/x/sys package… most new code should prefer that package." (https://pkg.go.dev/syscall ; https://pkg.go.dev/syscall#Select).
- **No `poll(2)` in `syscall`** — only `Select` and the Linux `epoll*` family. Portable `poll` lives in the sub-repository.
- **`golang.org/x/sys/unix`** (BSD-3-Clause, official `golang.org/x/sys` sub-repository): the real home of synchronous readiness. Exposes `Poll(fds []PollFd, timeout int) (n int, err error)`, `Ppoll(fds []PollFd, timeout *Timespec, sigmask *Sigset_t) (n int, err error)`, `Select(...)`, the Linux `EpollCreate1/EpollCtl/EpollWait`, `EpollEvent`, `FdSet`, `PollFd`, and the `kqueue` syscalls on BSD/macOS. (https://pkg.go.dev/golang.org/x/sys/unix — index lists `Poll`, `Ppoll`, `Pselect`, `Epoll*`, `FdSet`, `EpollEvent`.)
- **`os` / `net`**: readiness is hidden behind `SetDeadline`/`SetReadDeadline`/`SetWriteDeadline` on `*os.File` and `net.Conn` (https://pkg.go.dev/os#File.SetReadDeadline). Under the hood `internal/poll` calls `runtime_pollOpen`/`runtime_pollWait`, i.e. the asynchronous runtime poller (`src/internal/poll/fd_poll_runtime.go`).
- The runtime poller interface (`netpollinit`, `netpollopen`, `netpollclose`, `netpoll(delta)`, `netpollBreak`) is **internal** (`src/runtime/netpoll.go`), not a public API.

## 2. Relevant community libraries

| Library | Maintainer | Maturity | License | Notes |
| --- | --- | --- | --- | --- |
| `github.com/panjf2000/gnet/v2` | Andy Pan (panjf2000) | v2.10.0, active, widely used | Apache-2.0 | Event-driven (epoll/kqueue), multi-loop, non-blocking — async, not synchronous poll, but its `Conn`/`Engine` API and edge-trigger option are instructive. (https://pkg.go.dev/github.com/panjf2000/gnet/v2) |
| `github.com/cloudwego/netpoll` | ByteDance CloudWeGo | v0.7.5, active, RPC-focused | Apache-2.0 | Non-blocking I/O framework for RPC; uses `EpollCreate/EpollCtl/EpollWait` and an `EventLoop`. (https://pkg.go.dev/github.com/cloudwego/netpoll) |
| `github.com/tidwall/evio` | Josh Baker (tidwall) | v1.0.8, last release 2020, effectively unmaintained | MIT | Event loop over raw epoll/kqueue; simple `Events` struct API. Predecessor of gnet. (https://pkg.go.dev/github.com/tidwall/evio) |
| `golang.org/x/sys/unix` | Go team | active sub-repository | BSD-3-Clause | The canonical synchronous `Poll`/`Ppoll`/`Select` bindings. (https://pkg.go.dev/golang.org/x/sys/unix) |

## 3. Exposed APIs

**`golang.org/x/sys/unix` (synchronous, the relevant subset):**
- `func Poll(fds []PollFd, timeout int) (n int, err error)` — `timeout` in **milliseconds**; negative means block indefinitely.
- `func Ppoll(fds []PollFd, timeout *Timespec, sigmask *Sigset_t) (n int, err error)` — nanosecond `Timespec`, optional signal mask.
- `type PollFd struct { Fd int32; Events int16; Revents int16 }` (`struct pollfd`).
- `type FdSet` with methods `Set(fd)`, `IsSet(fd) bool`, `Clear(fd)`, `Zero()`; `func Select(nfd int, r, w, e *FdSet, timeout *Timeval)`.
- Linux: `EpollEvent{ Events uint32; Fd int32; Pad int32 }`, `EpollCreate1(flag)`, `EpollCtl(epfd, op, fd, event)`, `EpollWait(epfd, events []EpollEvent, msec int)`, constants `EPOLLIN/EPOLLOUT/EPOLLERR/EPOLLHUP/EPOLLRDHUP/EPOLLET/EPOLL_CTL_ADD…`.
- Constants: `POLLIN`, `POLLPRI`, `POLLOUT`, `POLLERR`, `POLLHUP`, `POLLNVAL`, `POLLRDNORM`, `POLLWRNORM`, `POLLRDBAND`, `POLLWRBAND`, `POLLRDHUP`.
- Helpers: `SetNonblock(fd int, nonblocking bool) error` (fcntl `O_NONBLOCK`), `NsecToTimespec(int64) Timespec`, `TimespecToNsec(Timespec) int64`.

**`syscall`:** `Select(nfd int, r, w, e *FdSet, timeout *Timeval) (n int, err error)`; `FdSet`; `Timeval{Sec, Usec}`; Linux `EpollEvent`/`EpollCreate1`/`EpollCtl`/`EpollWait` (https://pkg.go.dev/syscall#Select).

**`os`:** `(*File).SetDeadline(t time.Time) error`, `SetReadDeadline`, `SetWriteDeadline` (https://pkg.go.dev/os#File.SetReadDeadline).

## 4. Error representation

- Go has **no `Result` type**. Readiness calls follow the language convention: `(value, error)`; `err == nil` means success, non-nil is an `error` interface value. `syscall`'s overview: "These calls return err == nil to indicate success; otherwise err is an operating system error describing the failure." (https://pkg.go.dev/syscall).
- The concrete error is usually `syscall.Errno`, which implements `error`, plus `Is`, `Temporary`, `Timeout` methods (https://pkg.go.dev/syscall#Errno). Callers test with `errors.Is(err, syscall.EINTR)` / `EAGAIN`.
- `unix.Poll` returns `n == -1` and `err != nil` on failure; `n == 0` means timeout; `n > 0` counts ready fds (POSIX `poll` semantics; source `unix/syscall_linux.go` `Poll` wraps `Ppoll`: `return Ppoll(fds, ts, nil)`).
- Higher-level `os` uses sentinels: `os.ErrDeadlineExceeded` ("i/o timeout"), `os.ErrNoDeadline`, `os.ErrClosed` (https://pkg.go.dev/os — Variables).
- Internally, readiness errors are plain **int codes**: `pollNoError=0`, `pollErrClosing=1`, `pollErrTimeout=2`, `pollErrNotPollable=3`, mapped to errors by `convertErr` (`src/internal/poll/fd_poll_runtime.go`; `src/runtime/netpoll.go`).

## 5. Ownership semantics

- The `[]PollFd` slice is **caller-allocated, caller-owned and GC-managed**; `unix.Poll` fills `Revents` in place and does not retain it. It does not close or dup the `Fd` — file-descriptor ownership stays with whatever `*os.File`/raw fd the caller owns (`unix/syscall_linux.go` `Poll`/`Ppoll`).
- In the **runtime netpoller**, ownership is deliberately different: each fd gets a `pollDesc` allocated in **non-GC, persistent memory** because "No heap pointers" and it "can be referenced only from epoll/kqueue internals" (`src/runtime/netpoll.go`). It is recycled through `pollCache`; `fdseq` protects against stale events after close/reuse.
- The runtime explicitly documents the lifetime contract: notifications can arrive *after* a descriptor is closed, so stale ones are detected via `seq`: "PollDesc objects must be type-stable, because we can get ready notification from epoll/kqueue after the descriptor is closed/reused. Stale notifications are detected using seq." (`src/runtime/netpoll.go`).
- `os.File` owns its fd and closes it; deadlines are attached to the runtime `pollDesc`, not to a user-visible object.

## 6. Blocking / non-blocking

- `unix.Poll`/`unix.Ppoll`/`unix.Select` are **blocking on the calling thread** (the syscall blocks) — this is the synchronous subset.
- `os.File`/`net.Conn` look blocking to the user but are **async behind a goroutine**: reads call `runtime_pollWait`, which parks the goroutine and lets the runtime's netpoll loop wake it (`src/internal/poll/fd_poll_runtime.go`).
- The runtime poller runs on a dedicated M and can be woken by `netpollBreak` (on Linux via an `eventfd` registered in the epoll set) (`src/runtime/netpoll_epoll.go`).
- Concurrency model: goroutines + `GOMAXPROCS`; the netpoller avoids one-thread-per-connection for sockets. gnet/netpoll/evio instead use explicit event loops over epoll/kqueue.
- **Non-blocking fd setup** is separate: `unix.SetNonblock(fd, true)` via `fcntl(O_NONBLOCK)` (`unix/syscall_unix.go`).

## 7. Kernel primitives and portability

- Go's runtime netpoller abstracts: **epoll** (Linux, illumos), **kqueue** (macOS, iOS, FreeBSD, NetBSD, OpenBSD, DragonFly), **event ports** (Solaris), **IOCP** (Windows), and a level-triggered path on Solaris/illumos/AIX/wasip1 (`src/runtime/netpoll.go`: "As for now only Solaris, illumos, AIX and wasip1 use level-triggered IO").
- Linux uses **edge-triggered** epoll: `ev.Events = EPOLLIN | EPOLLOUT | EPOLLRDHUP | EPOLLET` (`src/runtime/netpoll_epoll.go`).
- `golang.org/x/sys/unix` exposes the platform primitives directly and does **not** unify them: `Poll` exists on Unix (Winsock has `WSAPoll`, but Go's Windows path is IOCP, not poll). There is no user-facing portable `Poll` across Windows+Unix in std; the portable abstraction is the internal netpoller.
- The abstraction boundary is the five runtime hooks: `netpollinit`, `netpollopen`, `netpollclose`, `netpoll(delta)`, `netpollBreak`, `netpollIsPollDescriptor` (`src/runtime/netpoll.go`).

## 8. Timeouts

- `unix.Poll` takes `timeout int` in **milliseconds**: negative = infinite, `0` = return immediately. Source: `func Poll(fds []PollFd, timeout int) (n int, err error)`; `if timeout >= 0 { ts = new(Timespec); *ts = NsecToTimespec(int64(timeout) * 1e6) }; return Ppoll(fds, ts, nil)` (`unix/syscall_linux.go`).
- `unix.Ppoll` takes `*Timespec` (**seconds + nanoseconds**), enabling sub-millisecond precision (`unix/syscall_linux.go`).
- `unix.Select` takes `*Timeval` (seconds + microseconds); `nil` usually means block indefinitely (POSIX).
- `os.File` deadlines use `time.Time`; internally converted to an absolute nanosecond deadline. `setDeadlineImpl`: `d = int64(time.Until(t))`, and `if d == 0 { d = -1 } // don't confuse deadline right now with no deadline` (`src/internal/poll/fd_poll_runtime.go`).
- **Overflow handling:** the Linux netpoll caps the wait: `delay > 0` maps to `waitms = int32(delay / 1e6)`, but `delay >= 1e15` is clamped to `waitms = 1e9` ms "~11.5 days" (`src/runtime/netpoll_epoll.go`). Deadline arithmetic also saturates: `if d <= 0 { d = 1<<63 - 1 }` (`src/runtime/netpoll.go`).
- Note the rounding caveat, which Go inherits from the kernel: `poll` will "round up to the system clock granularity, and kernel scheduling delays mean that the blocking interval may overrun by a small amount." (POSIX/`poll(2)`; the same wording appears in nix/rustix docs).

## 9. Bounded vs unbounded waits, EINTR and overflow

- Unbounded: negative timeout (`Poll`) / `nil` timeout (`ppoll`, `select`). Bounded: `>= 0`.
- **EINTR:** `unix.Poll`/`Ppoll` do **not** retry; the syscall returns `-1, EINTR` and the caller must loop if desired (they are thin syscall wrappers, `unix/syscall_linux.go`).
- The **runtime netpoller retries EINTR** on the indefinite path: `if errno != _EINTR { … throw }`; `if waitms > 0 { return … }` (recompute remaining time), else `goto retry` (`src/runtime/netpoll_epoll.go`). So the async path is EINTR-robust, the synchronous wrapper is not.
- Timeout-unit overflow: `Poll` converts with `NsecToTimespec(int64(timeout) * 1e6)`; the `int64(timeout)` widening means the multiplication happens in `int64`, so a 32-bit `int` timeout cannot overflow at this conversion step — the bound is the `int64` product itself (overflow only above ~9.2e12 ms, ≈292 years) and the `Timespec` handed to the platform's `ppoll`. `unix.Poll` performs no explicit guard (`unix/syscall_linux.go`). The runtime netpoller separately caps its own wait at `1e9` ms (`src/runtime/netpoll_epoll.go`).

## 10. Interesting design decisions

- **Stale-event protection via `fdseq`.** Because epoll/kqueue can deliver readiness for an fd number that has since been closed and reused, the runtime tags the epoll `Data` field with a `taggedPointer` of `(pollDesc, fdseq)` and compares on delivery (`src/runtime/netpoll_epoll.go`, `netpollPackData`/`netpollUnpackData`). This is a robust answer to a real race that a naïve `pollfd` array ignores.
- **Timer-per-descriptor with sequence numbers.** Deadlines are independent read/write timers on the `pollDesc`; `rseq`/`wseq` invalidate stale timer callbacks after reuse (`src/runtime/netpoll.go`).
- **Two-semaphore state machine** (`pdNil`, `pdReady`, `pdWait`, goroutine pointer) rather than a condition variable, to avoid missed wakeups between "check error" and "park" (`netpollblock`/`netpollunblock`).
- **Wakeup channel:** a dedicated `eventfd` in the epoll set lets other threads interrupt `epoll_wait` (`netpollBreak`, `netpollEventFd`).
- **`pollCache` recycles `pollDesc` from a fixed 4 KiB block of non-GC memory**, keeping the hot path allocation-free (`pollBlockSize = 4 * 1024`).
- **Level vs edge trigger is platform-conditional**, hidden from callers; Solaris/AIX/wasip1 need an explicit re-arm (`netpollarm`), Linux does not.

## 11. Decisions NOT to copy

- **Coupling to a global runtime scheduler.** `runtime_pollWait` reaches through `go:linkname` into the runtime and parks goroutines. A MojoAkku library must not depend on an invisible global event loop — the synchronous contract ("this call returns when an fd is ready or the timeout elapses") must be explicit.
- **Non-GC / persistent memory for descriptor state.** `pollDesc` is placed outside the GC with `sys.NotInHeap`. That is a Go-runtime-specific trick; copying it into Mojo would fight the language's ownership model.
- **Tagged pointers** (`taggedPointerPack` embedding a 20-bit `fdseq` in `unsafe.Pointer`/`EpollEvent.Data`) — unportable and unsafe; Mojo should use an explicit handle/id, not pointer tagging.
- **`go:linkname` / `internal/poll` as an API boundary** — undocumented and version-fragile.
- **Milliseconds-as-`int` timeout** on the convenient `Poll` wrapper; it silently loses sub-ms precision and is overflow-prone. Prefer a typed duration.
- **Error-as-dynamic-interface** (`error` holding `Errno`), which forces `errors.Is`/type assertions; a `raises`/typed-error design is clearer.
- **Silent EINTR non-retry** in `unix.Poll` while the runtime *does* retry — inconsistent semantics that surprise callers. Pick one, document it.
- **Reusing one fd number as identity** (needing `fdseq` at all). Prefer a generation-tagged handle at the API level.

## 12. Ideas fitting Mojo

- **`PollFd` as a value-semantics struct** (`Fd`, `Events`, `Revents` as `Int32/Int16`) held in a `List[PollFd]`; the list is passed `var`/`mut` and mutated in place (matching `poll(2)`'s in/out array) — no heap handle, no lifetime puzzle.
- **`raises` instead of `(n, error)`:** `poll(fds: List[PollFd], timeout: PollTimeout) raises -> Int` returning the ready count; errors (`EINTR`, `EINVAL`) as raised values.
- **A dedicated `PollTimeout` type** mirroring nix's newtype: an enum/struct with `infinite`, `zero`, and `Duration` variants plus a checked conversion that raises on unit overflow — removes the millisecond/int ambiguity.
- **`comptime` bitflags** for `POLLIN`/`POLLOUT`/`POLLERR`/`POLLHUP`/`POLLNVAL`/`POLLRDHUP`, so flags compose in the type system and platform-specific flags can be selected at compile time.
- **`borrowed` fd handles** to encode "the fd must outlive the poll array" (nix's `PollFd<'fd>` does this with a lifetime; Mojo can express the same with a borrowed parameter).
- **Explicit platform selection with `comptime`** (`@parameter if os_is_linux …`) rather than a runtime global; keep the synchronous `poll`/`ppoll` subset as the portable core and expose epoll/kqueue only as separate, opt-in API entries.
- **Explicit ownership of the result array**: return only the count and let the caller read `Revents` from its own list — no hidden retention, no GC.

## Sources

- https://pkg.go.dev/syscall — package overview, `Select`, `Errno`, `EpollEvent`, `FdSet`.
- https://pkg.go.dev/golang.org/x/sys/unix — index: `Poll`, `Ppoll`, `Pselect`, `Select`, `EpollCreate1/EpollCtl/EpollWait`, `PollFd`, `FdSet`, `EpollEvent`.
- https://raw.githubusercontent.com/golang/sys/master/unix/syscall_linux.go — `Poll`, `Ppoll`, `EpollCreate` implementations.
- https://raw.githubusercontent.com/golang/sys/master/unix/syscall_unix.go — `SetNonblock`, `errnoErr`, `Sockaddr` family.
- https://raw.githubusercontent.com/golang/go/master/src/runtime/netpoll.go — poller interface, `pollDesc`, `fdseq`, codes, `netpollblock`/`unpollUnblock`, deadline saturation.
- https://raw.githubusercontent.com/golang/go/master/src/runtime/netpoll_epoll.go — edge-triggered epoll, `EPOLLET`, `eventfd` break, EINTR retry, `waitms` cap.
- https://raw.githubusercontent.com/golang/go/master/src/internal/poll/fd_poll_runtime.go — `setDeadlineImpl`, `convertErr`, runtime linknames.
- https://pkg.go.dev/os#File.SetReadDeadline — public deadline API, `ErrDeadlineExceeded`, `ErrNoDeadline`.
- https://pkg.go.dev/github.com/panjf2000/gnet/v2 — gnet v2.10.0, Apache-2.0.
- https://pkg.go.dev/github.com/cloudwego/netpoll — netpoll v0.7.5, Apache-2.0.
- https://pkg.go.dev/github.com/tidwall/evio — evio v1.0.8, MIT.
- https://pkg.go.dev/golang.org/x/sys/unix?tab=licenses — BSD-3-Clause.
