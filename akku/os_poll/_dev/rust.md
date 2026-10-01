# os_poll research: rust

Scope: **synchronous file-descriptor readiness with a bounded timeout** — `select`/`poll`/`epoll`/`kqueue`, one thread waits, a `Duration`/`Instant` deadline ends the wait. Explicitly **not async**.

> **Rust's mio is async/event-driven — do not confuse it with this scope.**
> `mio::Poll` is a non-blocking, edge/oneshot readiness *event loop*: you register `event::Source`s, call `Poll::poll(&mut events, Some(Duration))` and iterate `Events` to drive many sockets — it is the I/O reactor underneath Tokio. That is the *opposite* of "call `poll(2)` on my `pollfd` array with a timeout and get control back." The **synchronous subset** in Rust is:
> - the raw `libc::poll` / `libc::ppoll` / `libc::select` FFI (unsafe), and
> - the safe wrappers `nix::poll::{poll, ppoll, PollFd, PollFlags, PollTimeout}` and `rustix::event::{poll, select, PollFd, PollFlags}` — ordinary blocking calls on the calling thread.
> `mio` and `polling` are included for contrast and for the design lessons in their timer/registration APIs, but the library targets the nix/rustix-style synchronous subset.

## 1. Standard library support

- **There is no `poll`/`select` in `std`.** Rust's standard library intentionally leaves fd readiness to crates; it provides the *fd handle* and *time* types only:
  - `std::os::fd`: `trait AsFd { fn as_fd(&self) -> BorrowedFd<'_>; }` (since 1.63), `trait AsRawFd`, `OwnedFd`, `BorrowedFd`, `RawFd` (https://doc.rust-lang.org/std/os/fd/trait.AsFd.html).
  - `std::time::Duration`, `Instant`; `std::io::Error` with `ErrorKind::WouldBlock` / `TimedOut`.
- Raw syscalls are reachable only through the **`libc`** crate: `libc::poll(fds: *mut pollfd, nfds: nfds_t, timeout: c_int) -> c_int`, `libc::ppoll`, `libc::select`, the `pollfd`/`poll()` `POLL*` constants, `epoll_*`, `kevent`.
- Consequence: a synchronous readiness API in Rust is always either `unsafe` FFI or a third-party crate.

## 2. Relevant community libraries

| Crate | Maintainer | Maturity | License | Notes |
| --- | --- | --- | --- | --- |
| `nix` | nix-rust team (owners incl. carllerche) | 0.31.3, 2026-05-11, widely used | MIT | Safe POSIX wrappers; `nix::poll` is the canonical synchronous `poll`/`ppoll`. (https://docs.rs/nix/latest/nix/poll/) |
| `rustix` | Dan Gohman / bytecodealliance | 1.1.5, active | Apache-2.0 WITH LLVM-exception OR Apache-2.0 OR MIT | Safe syscalls with a raw-linux fast path; `rustix::event::poll`/`select`. (https://docs.rs/rustix/latest/rustix/event/) |
| `mio` | tokio-rs (owners carllerche, mio-core) | 1.2.3, active | MIT | **Async** readiness reactor over epoll/kqueue/IOCP/event-ports; not synchronous poll, valuable as a contrast. (https://docs.rs/mio/latest/mio/struct.Poll.html) |
| `polling` | smol-rs (owner taiki-e) | 3.11.0, 2026-07-25, active | Apache-2.0 OR MIT | Portable oneshot/level/edge poller (epoll/kqueue/event-ports/poll/IOCP); async-ish but exposes `PollMode` and `wait_deadline` design. (https://docs.rs/polling/latest/polling/) |
| `libc` | rust-lang | active, foundational | MIT OR Apache-2.0 | Raw FFI including `poll`/`ppoll`/`select`. (dependency of nix/rustix) |

## 3. Exposed APIs

**`nix::poll` (feature `poll`):**
- `pub fn poll<T: Into<PollTimeout>>(fds: &mut [PollFd<'_>], timeout: T) -> Result<c_int>` (https://docs.rs/nix/latest/nix/poll/fn.poll.html).
- `pub fn ppoll(fds: &mut [PollFd<'_>], timeout: Option<TimeSpec>, sigmask: Option<SigSet>) -> Result<c_int>` (feature `poll`+`signal`); `ppoll` differs from `poll` "only in the precision of the timeout argument" and the optional signal mask (https://docs.rs/nix/latest/nix/poll/fn.ppoll.html).
- `pub struct PollFd<'fd>` wrapping `libc::pollfd`; `PollFd::new(fd: BorrowedFd<'fd>, events: PollFlags)`, `.revents() -> Option<PollFlags>`, `.any() -> Option<bool>`, `.all() -> Option<bool>`, `.events()`, `.set_events(...)`, `AsFd` (https://docs.rs/nix/latest/nix/poll/struct.PollFd.html).
- `pub struct PollFlags` (bitflags): `POLLIN`, `POLLPRI`, `POLLOUT`, `POLLRDNORM`, `POLLWRNORM`, `POLLRDBAND`, `POLLWRBAND`, `POLLERR`, `POLLHUP`, `POLLNVAL`; methods `empty()`, `all()`, `bits()`, `from_bits`, `contains`, `insert`, … (https://docs.rs/nix/latest/nix/poll/struct.PollFlags.html).
- `pub struct PollTimeout` (newtype): constants `NONE` (block indefinitely, negative), `ZERO` (return immediately), `MAX` (`i32::MAX` ms); `is_none()`, `is_some()`, `as_millis() -> Option<u32>`, `duration() -> Option<Duration>`; `From<u8/u16>`, `TryFrom<Duration>`, `TryFrom<i32/u32/u64/i64/...>` (https://docs.rs/nix/latest/nix/poll/struct.PollTimeout.html).

**`rustix::event` (feature `event`):**
- `pub fn poll(fds: &mut [PollFd<'_>], timeout: Option<&Timespec>) -> Result<usize>`; documentedly "Some platforms (those that don't support `ppoll`) don't support timeouts greater than `c_int::MAX` milliseconds; if an unsupported timeout is passed, this function fails with `io::Errno::INVAL`." Also notes macOS `poll` does not work on `/dev/tty` or `/dev/null` where `select` does (https://docs.rs/rustix/latest/rustix/event/fn.poll.html).
- `pub fn select(nfds, readfds, writefds, exceptfds, timeout: Option<&Timespec>) -> Result<c_int>` (marked ⚠).
- `pub struct PollFd<'fd>`: `new(&'fd Fd, events)`, `from_borrowed_fd(BorrowedFd, events)`, `set_fd`, `clear_revents`, `revents() -> PollFlags` (https://docs.rs/rustix/latest/rustix/event/struct.PollFd.html).
- `pub struct PollFlags` (bitflags, `u16`): `IN`, `PRI`, `OUT`, `RDNORM`, `WRNORM`, `RDBAND`, `WRBAND`, `ERR`, `HUP`, `NVAL`, `RDHUP` (https://docs.rs/rustix/latest/rustix/event/struct.PollFlags.html).
- `pub struct Timespec`; type aliases `Nsecs`, `Secs`; helpers `fd_set_insert`, `fd_set_remove`, `fd_set_bound`, `fd_set_num_elements`.
- Feature-gated `rustix::event::epoll` (Linux/illumos/Redox).

**`mio` (contrast, async):** `Poll::new()`, `Poll::poll(&mut self, &mut Events, Option<Duration>) -> io::Result<()>`, `Poll::registry() -> &Registry`; `Registry::{register, reregister, deregister}`; `Events::with_capacity(n)`, `Iter`; `Interest::{READABLE, WRITABLE, AIO}`, `Token`, `Waker` (https://docs.rs/mio/latest/mio/struct.Poll.html, .../struct.Registry.html, .../struct.Interest.html, .../event/struct.Events.html).

**`polling` (contrast):** `Poller::{new, add, add_with_mode, modify, modify_with_mode, delete, wait(&mut Events, Option<Duration>), wait_deadline(&mut Events, Instant), notify, supports_level, supports_edge}`; `PollMode::{Oneshot, Level, Edge, EdgeOneshot}` (non_exhaustive); `Event`, `Events`; `AsRawSource`/`AsSource` (https://docs.rs/polling/latest/polling/struct.Poller.html, .../enum.PollMode.html).

## 4. Error representation

- **`Result<T>`** = `std::io::Result` / `rustix::io::Result`, i.e. `Result<T, io::Error>` / `Result<T, Errno>`; `?` propagates. `nix` returns `nix::Result<T>` (alias for `Result<T, Errno>`).
- `nix::poll::PollFd::revents()` returns `Option<PollFlags>` and returns `None` "only if the kernel provides status flags that Nix does not know about" — an unusual choice that pushes unknown bits into `Option` (https://docs.rs/nix/latest/nix/poll/struct.PollFd.html).
- `PollTimeout::try_from(Duration)` has a dedicated error type `PollTimeoutTryFromError` — the **overflow of a duration into the poll timeout unit is a typed, catchable error**, not a silent wrap (https://docs.rs/nix/latest/nix/poll/struct.PollTimeout.html).
- `rustix::event::poll` returns `io::Errno::INVAL` for an unsupported (too large) timeout as documented above (https://docs.rs/rustix/latest/rustix/event/fn.poll.html).
- `WouldBlock` is the conventional non-blocking "nothing ready" signal: `std::io::ErrorKind::WouldBlock`; mio documents that "If operation fails with `WouldBlock`, then the caller should not treat this as an error" (https://docs.rs/mio/latest/mio/struct.Poll.html).

## 5. Ownership semantics

- **Lifetimes encode the borrow.** `nix::PollFd<'fd>` and `rustix::event::PollFd<'fd>` hold a `BorrowedFd<'fd>` / `&'fd Fd`. You cannot drop or close the fd while a `PollFd` borrowing it is alive — the compiler enforces "fd outlives the poll array" (https://docs.rs/nix/latest/nix/poll/struct.PollFd.html, https://docs.rs/rustix/latest/rustix/event/struct.PollFd.html).
- `poll(fds: &mut [PollFd])` mutably borrows the slice for the call; `poll(2)`'s in/out `revents` array is thus expressed without any unsafe aliasing. `rustix` explicitly notes it "does not use the `Buffer` trait because the `fds` list is both an input and output buffer" (https://docs.rs/rustix/latest/rustix/event/fn.poll.html).
- Ownership of the **fd itself** stays with the owner of the `OwnedFd`/file/socket; `PollFd` only borrows. `AsFd`/`BorrowedFd` (std) is the shared vocabulary (https://doc.rust-lang.org/std/os/fd/trait.AsFd.html).
- `mio::Poll` *owns* the OS selector fd and drops/cleans up on `Drop`; `polling::Poller` likewise. `polling` documents a manual safety contract: "The source must be `delete()`d from this `Poller` before it is dropped" (`Poller::add` is `unsafe`) (https://docs.rs/polling/latest/polling/struct.Poller.html).
- mio documents that dropping `Poll` "may cancel in-flight operations for the registered event sources" and the user "must keep the `Poll` instance alive while registered event sources are being used" (https://docs.rs/mio/latest/mio/struct.Poll.html).

## 6. Blocking / non-blocking

- `nix::poll` / `rustix::event::poll` / `select` **block the calling thread** — the synchronous subset. The call returns when an fd is ready, the timeout expires, or (for `poll`) a signal interrupts it.
- mio/polling/mio-based runtimes are **non-blocking**: fds must be set `O_NONBLOCK` by the user (examples call `set_nonblocking(true)`), and the poller only reports readiness; actual I/O returns `WouldBlock` when drained (https://docs.rs/polling/latest/polling/).
- `polling` is explicit: "By default, polling is done in oneshot mode, which means interest in I/O events needs to be re-enabled after an event is delivered"; "Only one thread can be waiting for I/O events at a time" (https://docs.rs/polling/latest/polling/).
- mio is oneshot for `Poll` (readiness must be drained until `WouldBlock`, then re-armed); it warns about spurious events and false negatives for `read_closed`/`write_closed`/`error` (https://docs.rs/mio/latest/mio/struct.Poll.html).

## 7. Kernel primitives and portability

- **`nix::poll` / `rustix::event::poll`** call `poll(2)`/`ppoll(2)` — portable across Unix but **not Windows** (Windows has `WSAPoll`, with documented differences, and no `ppoll`).
- **`mio`** abstracts: epoll (Android, illumos, Linux), kqueue (DragonFly/FreeBSD/iOS/NetBSD/OpenBSD/macOS), event ports (Solaris), IOCP (Windows). IOCP is a *completion* model, so "`Poll` must adapt the completion model" and copying data through an intermediate buffer is the expensive part (https://docs.rs/mio/latest/mio/struct.Poll.html).
- **`polling`** abstracts epoll / kqueue / event ports / `poll` (VxWorks, Fuchsia, HermitOS, other Unix) / IOCP (Windows, Wine ≥7.13); it supports oneshot, level and edge modes *where the OS supports them* and exposes `supports_level()`/`supports_edge()` (https://docs.rs/polling/latest/polling/).
- Portable wrapper caveats: macOS `poll` fails on `/dev/tty` and `/dev/null` where `select` works; platforms without `ppoll` cannot take timeouts above `c_int::MAX` ms (https://docs.rs/rustix/latest/rustix/event/fn.poll.html). mio notes WASI polling without registered sources has unspecified behaviour (Wasmtime returns `EINVAL`).

## 8. Timeouts

- `nix::poll` takes `T: Into<PollTimeout>` (milliseconds); `PollTimeout::NONE` = block indefinitely, `ZERO` = return immediately, `MAX` = at most `i32::MAX` ms; `TryFrom<Duration>` converts and raises `PollTimeoutTryFromError` on overflow; `as_millis() -> Option<u32>` (https://docs.rs/nix/latest/nix/poll/struct.PollTimeout.html).
- `nix::ppoll` takes `Option<TimeSpec>` (**nanosecond precision**), and `rustix::event::poll` takes `Option<&Timespec>`; `None` = block indefinitely (https://docs.rs/nix/latest/nix/poll/fn.ppoll.html, https://docs.rs/rustix/latest/rustix/event/fn.poll.html).
- mio's `Poll::poll` takes `Option<Duration>`; "A timeout of `Duration::ZERO` is not affected by this rounding", whereas a nonzero timeout "will be rounded up to the system clock granularity (usually 1ms)". On timeout mio currently returns `Ok(())` with no events, but "we're not guaranteeing this behaviour as this depends on the OS" (https://docs.rs/mio/latest/mio/struct.Poll.html).
- `polling::Poller::wait` takes `Option<Duration>`; `wait_deadline` takes an absolute `Instant` — the deadline form avoids recomputing remaining time across a loop and is the cleaner abstraction for cancellation/elapsed handling (https://docs.rs/polling/latest/polling/struct.Poller.html).

## 9. Bounded vs unbounded waits, EINTR

- Unbounded: `PollTimeout::NONE` / `None` timeout. Bounded: any `Duration`/`Timespec`. Zero = non-blocking probe.
- **EINTR:** mio explicitly documents "This returns any errors without attempting to retry, previous versions of Mio would automatically retry the poll call if it was interrupted (if `EINTR` was returned)." — the retry was deliberately removed (https://docs.rs/mio/latest/mio/struct.Poll.html). `nix::poll`/`ppoll` are thin wrappers and likewise return the `Errno` to the caller.
- **Timeout-unit overflow:** this is the standout Rust lesson. nix makes conversion from `Duration` *fallible* via `TryFrom`, and `rustix` fails with `INVAL` when a timeout exceeds what a platform's non-`ppoll` path can express in `c_int` milliseconds (https://docs.rs/nix/latest/nix/poll/struct.PollTimeout.html, https://docs.rs/rustix/latest/rustix/event/fn.poll.html). Overflow is surfaced, never silently truncated.
- Note the kernel rounding caveat shared by all wrappers: the interval "will be rounded up to the system clock granularity, and kernel scheduling delays mean that the blocking interval may overrun by a small amount" (https://docs.rs/nix/latest/nix/poll/fn.poll.html).

## 10. Interesting design decisions

- **Lifetime-typed `PollFd<'fd>`.** The borrow checker proves the fd outlives the array; this eliminates a whole class of use-after-close bugs statically, without runtime checks.
- **`PollTimeout` as a newtype with a fallible `Duration` conversion.** It unifies the three sentinel cases (negative/infinite, zero, finite ms) into one type and turns unit overflow into a typed error. This is a clean model for a Mojo API.
- **`revents() -> Option<PollFlags>`** deliberately signals "unknown kernel bits present" instead of silently masking them (nix).
- **`rustix`'s `clear_revents` + explicit `set_fd`/`from_borrowed_fd`** acknowledge that the poll array is reused across iterations and must be reset, avoiding a fresh allocation per loop.
- **`polling::wait_deadline(Instant)`** — absolute deadline instead of relative timeout, avoiding elapsed-time drift when the loop wakes spuriously.
- **`PollMode` is `#[non_exhaustive]` and capability-queried** (`supports_level`/`supports_edge`); an API does not pretend every platform supports every trigger mode.
- **mio's honest portability documentation**: spurious events, draining readiness, false-negative readiness flags, and the "polling without registering sources sleeps forever" caveat. The docs state the *actual* portability contract, not an idealized one.
- **`polling`'s `notify()` + `Poller: AsFd`** allow thread wake-up and integration as an event source into another loop, without exposing raw syscalls.

## 11. Decisions NOT to copy

- **`unsafe fn add` with a manual "must delete before drop" contract** (`polling`). It offloads a memory-safety obligation onto the caller; a Mojo API should make the invalid state unrepresentable (registry owns the mapping) or raise at runtime instead.
- **`revents` as `Option` conflating "unknown bits" with absence.** A distinct `unknown` flag/bits value is clearer than `None`.
- **Dynamic-interface errors (`Box<dyn Error>` / `io::Error`)**. Mojo's typed `raises` gives better signatures than a boxed trait object.
- **`#[non_exhaustive]` as the forward-compat tool.** Useful in Rust, but in Mojo a `comptime`-selected capability enum or explicit feature query reads better.
- **Global/thread-local pollers and `register`/`reregister` state machines (`mio`).** That is the async event-loop model the library explicitly excludes; it also requires the user to remember to drain and re-arm.
- **Platform-specific `IOCP` completion bridging** (mio's intermediate buffer copy). Out of scope for a synchronous readiness library; mixing readiness and completion models behind one API is expensive and confusing.
- **Silently returning `Ok(())` on timeout with an empty event list** (mio) — the caller cannot cleanly distinguish "timed out" from "spurious wakeup with nothing". A synchronous `poll` should return a ready count / a distinct timeout outcome.
- **Non-retry of `EINTR` as an undocumented trait.** If the library returns `EINTR`, document and provide a policy (retry or surface) — do not leave it implicit.
- **Separate `libc` unsafe path as the public API.** Keep unsafe FFI internal.

## 12. Ideas fitting Mojo

- **Borrowed fd parameter** (`fs`/`BorrowedFd`-like) so the compiler/runtime enforces "fd outlives the `PollFd` array"; mirrors nix's `PollFd<'fd>` without lifetimes in the type spelling (Mojo `borrowed` + origin).
- **`PollTimeout` value type with three constructors** (`PollTimeout.infinite()`, `.zero()`, `.after(Duration)`) and a `raises` conversion that catches unit overflow — directly models nix's newtype in Mojo's type system.
- **`PollFd` as a value-semantics struct** (`fd: Int32`, `events: PollEvents`, `revents: PollEvents`) stored in a `List`, passed `var` (in/out) — matches `poll(2)` and avoids hidden ownership.
- **`PollEvents` as `comptime` bitflags** (`POLLIN | POLLOUT | POLLRDHUP`) selected/checked at compile time per platform.
- **`raises` for `PollError`** (`Interrupted`, `InvalidTimeout`, `SyscallErrno`) instead of `io::Error`/`Errno` dynamic dispatch.
- **Explicit `Instant`/deadline overload** (`wait_until(Instant)`) alongside `wait(Duration)`, learning from `polling::wait_deadline` to avoid drift; expose `Duration` as the primary user-facing unit and convert internally to `Timespec`/ms.
- **Platform capability as `comptime`** (`os_poll` portable core over `poll`; `epoll`/`kqueue` as separate opt-in API entries with `comptime` selection), rather than a runtime `supports_level()` query.
- **Ownership of the result** stays with the caller's `List[PollFd]`; the function returns the ready count (`Int`) and raises on error — no hidden retention, no separate `Events` container needed for the synchronous subset.

## Sources

- https://docs.rs/nix/latest/nix/poll/ — module overview, `poll`, `ppoll`, `PollFd`, `PollFlags`, `PollTimeout`, `PollTimeoutTryFromError`.
- https://docs.rs/nix/latest/nix/poll/fn.poll.html — signature, timeout semantics, return value, rounding.
- https://docs.rs/nix/latest/nix/poll/fn.ppoll.html — `Option<TimeSpec>`, signal mask, precision.
- https://docs.rs/nix/latest/nix/poll/struct.PollFd.html — `'fd` lifetime, `new`, `revents`/`any`/`all`.
- https://docs.rs/nix/latest/nix/poll/struct.PollTimeout.html — `NONE`/`ZERO`/`MAX`, `TryFrom<Duration>`, typed overflow error.
- https://docs.rs/nix/latest/nix/poll/struct.PollFlags.html — `POLL*` constants.
- https://docs.rs/rustix/latest/rustix/event/ — module, `poll`, `select`, `PollFd`, `PollFlags`, epoll.
- https://docs.rs/rustix/latest/rustix/event/fn.poll.html — `Result<usize>`, `INVAL` on oversized timeout, macOS `/dev/tty` caveat, input/output buffer note.
- https://docs.rs/rustix/latest/rustix/event/struct.PollFd.html — `'fd`, `clear_revents`, `from_borrowed_fd`.
- https://docs.rs/rustix/latest/rustix/event/struct.PollFlags.html — `IN/OUT/ERR/HUP/NVAL/RDHUP`.
- https://docs.rs/mio/latest/mio/struct.Poll.html — async reactor, OS selector table, spurious events, draining, EINTR non-retry, timeout rounding.
- https://docs.rs/mio/latest/mio/struct.Registry.html — `register`/`reregister`/`deregister`, lifetime binding to the `Poll`.
- https://docs.rs/mio/latest/mio/struct.Interest.html — `READABLE`/`WRITABLE`/`AIO`.
- https://docs.rs/mio/latest/mio/event/struct.Events.html — `with_capacity`, `iter`, `clear`.
- https://docs.rs/polling/latest/polling/ — portable poller, oneshot default, platforms, single-waiter rule.
- https://docs.rs/polling/latest/polling/struct.Poller.html — `add`/`modify`/`delete`/`wait`/`wait_deadline`/`notify`, `unsafe add` contract.
- https://docs.rs/polling/latest/polling/enum.PollMode.html — `Oneshot`/`Level`/`Edge`/`EdgeOneshot`, non_exhaustive.
- https://doc.rust-lang.org/std/os/fd/trait.AsFd.html — `AsFd`, `BorrowedFd`, `OwnedFd` (std has no poll).
