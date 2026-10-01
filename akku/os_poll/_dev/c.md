# os_poll research: C

Scope: synchronous file-descriptor readiness with **bounded** waits via
`poll()` (and the neighbouring `select`/`pselect`/`ppoll`, plus the Linux
`epoll` and BSD `kqueue` primitives). Asynchronous I/O is out of scope.

## 1. Standard library support

C itself (ISO C) has **no readiness API**. Readiness multiplexing is POSIX, and
the relevant headers are POSIX headers, not ISO C headers:

- **`<poll.h>`** defines the `pollfd` structure and `poll()`:
  "The `<poll.h>` header shall define the `pollfd` structure, which shall
  include at least the following members: `int fd`, `short events`, `short
  revents`." It also defines `nfds_t` ("an unsigned integer type used for the
  number of file descriptors") and the event constants (see §3).
  Source: <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/poll.h.html>.
- **`<sys/select.h>`** defines the `select`/`pselect` API together with `fd_set`,
  `FD_SETSIZE`, `FD_CLR`/`FD_ISSET`/`FD_SET`/`FD_ZERO`, and the `timeval` /
  `timespec` / `sigset_t` types.
  Source: <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/sys_select.h.html>.
- Linux adds `<sys/epoll.h>` (`epoll_create`/`epoll_ctl`/`epoll_wait`, the
  `epoll_event` struct and `EPOLL*` flags).
  Source: <https://linux.die.net/man/7/epoll>.
- BSD/macOS add `<sys/event.h>` (`kqueue`/`kevent`).
  Source: <https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2&format=html>.
- The Windows equivalent is not a header-level POSIX API but the Win32
  **I/O completion port** family (`CreateIoCompletionPort`,
  `GetQueuedCompletionStatus`, `PostQueuedCompletionStatus`), which is
  overlapped/asynchronous rather than readiness-based.
  Source: <https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports>.

## 2. Relevant community libraries

Because the raw API is small and caller-managed, the community layer is
event-loop frameworks, not "poll wrappers":

| Library | Maintainer | Maturity | License | Readiness model |
| --- | --- | --- | --- | --- |
| libevent | Nick Mathewson et al. | mature, widely deployed | BSD-3-Clause | `event_base` + `event_new(base, fd, EV_READ/EV_WRITE, cb, arg)`, backend chosen among select/poll/epoll/kqueue |
| libuv | Node.js / libuv project | mature, widely deployed | MIT | `uv_poll_t` handle + callback, level-triggered |
| libev | Marc Lehmann | mature, smaller than libevent | BSD-2-Clause (GUESS: exact licence not re-verified in this pass) | `ev_io` watchers over select/poll/epoll/kqueue |

- libevent exposes the backend introspection `event_get_supported_methods()` and
  `event_base_get_method()`, i.e. the portable abstraction is explicit.
  Sources: <https://libevent.org/doc/event_8h.html> (functions
  `event_get_supported_methods`, `event_base_get_method`); licence BSD-3-Clause
  (`libevent/libevent:LICENSE`).
- libuv documents `uv_poll_t` as being for "integrating external libraries that
  rely on the event loop … like c-ares or libssh2", and explicitly warns that
  it is *not* the recommended path for its own sockets. Source:
  <https://docs.libuv.org/en/v1.x/poll.html>; licence MIT (`libuv/libuv:LICENSE`).

Assessment (derived from the sources above): the C ecosystem treats readiness as
a *loop* concern, and every framework re-invents the `pollfd` array, the
callback dispatch and the timeout wheel — the raw `poll()` is almost never used
directly in production code.

## 3. Exposed APIs

### `<poll.h>` (POSIX)

```c
struct pollfd {
    int   fd;       /* file descriptor */
    short events;   /* requested events  (input)  */
    short revents;  /* returned events   (output) */
};
int poll(struct pollfd fds[], nfds_t nfds, int timeout);
```

Source: <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/poll.h.html>.

Event constants (OR-able into `events`, returned in `revents`): `POLLIN`,
`POLLRDNORM`, `POLLRDBAND`, `POLLPRI`, `POLLOUT`, `POLLWRNORM`, `POLLWRBAND`,
plus the **output-only** `POLLERR`, `POLLHUP`, `POLLNVAL` ("This flag is only
valid in the *revents* bitmask; it shall be ignored in the *events* member").
Source: <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/poll.h.html>.

Semantics from POSIX `poll()`:

- "A value of 0 indicates that the call timed out and no file descriptors have
  been selected. Upon failure, `poll()` shall return -1 and set `errno`."
- "If the value of *timeout* is 0, `poll()` shall return immediately. If the
  value of *timeout* is -1, `poll()` shall block until a requested event occurs
  or until the call is interrupted."
- "If the value of *fd* is less than 0, *events* shall be ignored, and
  *revents* shall be set to 0" — the documented way to skip one entry.
- `POLLERR`/`POLLHUP`/`POLLNVAL` are set in `revents` "even if the application
  did not set the corresponding bit in *events*".
- "The `poll()` function shall not be affected by the `O_NONBLOCK` flag."
- "Regular files shall always poll TRUE for reading and writing."

Source: <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>.

`ppoll()` (Linux/GNU, nanosecond timeout + atomic signal mask):

```c
int ppoll(struct pollfd *fds, nfds_t nfds,
          const struct timespec *timeout_ts, const sigset_t *sigmask);
```

"The relationship between `poll()` and `ppoll()` is analogous to the
relationship between `select()` and `pselect()`: like `pselect()`, `ppoll()`
allows an application to safely wait until either a file descriptor becomes
ready or until a signal is caught." `ppoll()` is Linux-specific; glibc hides the
fact that the raw syscall modifies `timeout_ts`. Source:
<https://linux.die.net/man/2/ppoll>.

### `<sys/select.h>` (POSIX)

```c
int select(int nfds, fd_set *readfds, fd_set *writefds,
           fd_set *exceptfds, struct timeval *timeout);
int pselect(int nfds, fd_set *restrict readfds, fd_set *restrict writefds,
            fd_set *restrict errorfds, const struct timespec *restrict timeout,
            const sigset_t *restrict sigmask);
void FD_CLR(int fd, fd_set *set);
int  FD_ISSET(int fd, fd_set *set);
void FD_SET(int fd, fd_set *set);
void FD_ZERO(fd_set *set);
```

`fd_set` is "a fixed size buffer"; `FD_SETSIZE` is the maximum number of fds.
The sets are **modified in place** to report readiness; `nfds` is "the
highest-numbered file descriptor in any of the three sets, plus 1". A NULL
`timeout` blocks indefinitely; a zero `timeval` polls once. Sources:
POSIX `pselect`/`select`
(<https://pubs.opengroup.org/onlinepubs/9699919799/functions/select.html>),
`<sys/select.h>`
(<https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/sys_select.h.html>),
Linux `select(2)` (<https://linux.die.net/man/2/select>).

### Linux `<sys/epoll.h>`

```c
int epoll_create(int size);
int epoll_create1(int flags);
int epoll_ctl(int epfd, int op, int fd, struct epoll_event *event);
int epoll_wait(int epfd, struct epoll_event *events, int maxevents, int timeout);

struct epoll_event { uint32_t events; epoll_data_t data; };  /* data is a union {void*; int; u32; u64} */
```

`op` ∈ `EPOLL_CTL_ADD`/`EPOLL_CTL_MOD`/`EPOLL_CTL_DEL`; flags include
`EPOLLIN`, `EPOLLOUT`, `EPOLLET` (edge-triggered), `EPOLLONESHOT`. "The `epoll`
API can be used either as an edge-triggered or a level-triggered interface and
scales well to large numbers of watched file descriptors." Level-triggered is
"the default, when `EPOLLET` is not specified" and is "simply a faster `poll()`".
Sources: <https://linux.die.net/man/7/epoll>,
<https://linux.die.net/man/2/epoll_wait>.

### BSD/macOS `<sys/event.h>`

```c
int kqueue(void);
int kevent(int kq, const struct kevent *changelist, int nchanges,
           struct kevent *eventlist, int nevents, const struct timespec *timeout);
EV_SET(kev, ident, filter, flags, fflags, data, udata);
```

`struct kevent` fields: `ident`, `filter`, `flags`, `fflags`, `data`, `udata`,
`ext[4]`. Flags include `EV_ADD`, `EV_DELETE`, `EV_ENABLE`/`EV_DISABLE`,
`EV_ONESHOT`, `EV_CLEAR`. Filters include `EVFILT_READ` and `EVFILT_WRITE`.
"When *nevents* is zero, `kevent()` will return immediately even if there is a
*timeout* specified"; a NULL timeout waits indefinitely. Source:
<https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2&format=html>.

### Windows IOCP

`CreateIoCompletionPort` "creates an I/O completion port and associates one or
more file handles with that port"; a worker calls
`GetQueuedCompletionStatus` instead of waiting directly on I/O. The port has a
**concurrency value** (best set to the CPU count). This is a completion model,
not a readiness set. Source:
<https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports>.

## 4. Error representation

C has no exceptions and no `Result`: `poll`/`select`/`epoll_wait`/`kevent` use
the classic **sentinel return + `errno`** pair.

- `poll`: "Upon failure, `poll()` shall return -1 and set `errno`." Errors:
  `EAGAIN` (internal allocation failed, "a subsequent request may succeed"),
  `EINTR` (signal caught), `EINVAL` (`nfds` > `{OPEN_MAX}`).
  Source: <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>.
- Linux `poll(2)` adds `EFAULT`, `EINVAL` (`nfds` exceeds `RLIMIT_NOFILE`),
  `ENOMEM`. Source: <https://linux.die.net/man/2/poll>.
- `select`/`pselect`: return -1 with `EBADF`, `EINTR`, `EINVAL`, `ENOMEM`.
  Sources: <https://linux.die.net/man/2/select>,
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/pselect.html>.
- `epoll_wait`: -1 with `EBADF`, `EFAULT`, `EINTR`, `EINVAL` (e.g. `maxevents`
  ≤ 0). Source: <https://linux.die.net/man/2/epoll_wait>.
- `kevent`: -1 with `EACCES`, `EFAULT`, `EBADF`, `EINTR`, `EINVAL`, `ENOENT`,
  `ENOMEM`, `ESRCH`; per-event errors are delivered in-band via `EV_ERROR` set
  in `flags` with the error in `data` when the eventlist has room.
  Source: <https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2&format=html>.

Three-valued returns are the norm: `poll` returns a **count** (≥0) on success
and -1 on failure, so 0 and a positive number are both *successful*; the caller
must distinguish "timed out" (0) from "N ready" (>0). `kevent` returns 0 on
timeout and the number of events otherwise. `errno` "is significant only when
the return value of the call indicated an error" and must be saved immediately,
because any intervening call may clobber it. Sources:
<https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>,
<https://man7.org/linux/man-pages/man3/errno.3.html>.

## 5. Ownership semantics

The readiness API is **entirely caller-owned with no hidden allocation**:

- The caller owns the `pollfd` array for the whole call. POSIX guarantees
  "the value of the *fd* and *events* members of each element of *fds* shall not
  be modified by `poll()`"; only `revents` is written.
  Source: <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>.
- `select` writes back into the caller's `fd_set` buffers in place and *may*
  modify the caller's `timeval` on success ("the `select` function may modify
  the object pointed to by the *timeout* argument"), so on Linux "consider
  *timeout* to be undefined after `select()` returns". Sources:
  POSIX `pselect`,
  <https://linux.die.net/man/2/select>.
- `epoll` separates ownership: the kernel owns the epoll interest set inside the
  `epfd` (removed on `close`/`EPOLL_CTL_DEL`), and the caller owns the
  `epoll_event` output array. "A file descriptor is removed from an `epoll` set
  only after all the file descriptors referring to the underlying open file
  description have been closed." Source: <https://linux.die.net/man/7/epoll>.
- `kqueue` follows the same split: the kernel owns registered kevents, the
  caller owns `changelist` and `eventlist`; "Calling `close()` on a file
  descriptor will remove any kevents that reference the descriptor", and
  "kqueues are destroyed upon `close()`". Source:
  <https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2&format=html>.
- There is **no fd ownership transfer**: `poll` never closes a descriptor; the
  caller that opened the fd must close it. `kevent` even removes events
  automatically on last close. Sources as above.

## 6. Blocking / non-blocking

- `poll`/`select`/`epoll_wait`/`kevent` are **blocking waits by default**, made
  bounded by the timeout argument. `poll` "blocks until one of the events
  occurs" when no timeout is given; `epoll_wait` blocks when `timeout` > 0 with
  no ready events.
  Sources: <https://linux.die.net/man/2/poll>,
  <https://linux.die.net/man/2/epoll_wait>,
  <https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2&format=html>.
- **The readiness call ignores `O_NONBLOCK`** ("The `poll()` function shall not
  be affected by the `O_NONBLOCK` flag"). The non-blocking flag matters only for
  the *subsequent* `read`/`write`; the canonical pattern is non-blocking fds +
  `poll`. Source:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>.
- Edge-triggered `epoll` explicitly requires non-blocking fds: "An application
  that employs the `EPOLLET` flag should use nonblocking file descriptors to
  avoid having a blocking read or write starve a task that is handling multiple
  file descriptors." Source: <https://linux.die.net/man/7/epoll>.
- Concurrency is **not part of the API**: `poll` watches fds, not threads. The
  only concurrency interaction is that closing an fd from another thread while
  it is being polled is unspecified ("any application that relies on a
  particular behavior in this scenario must be considered buggy").
  Sources: <https://linux.die.net/man/2/select>,
  <https://linux.die.net/man/2/poll>.
- The event-loop frameworks invert this into callbacks: libevent's
  `event_new(base, fd, EV_READ|EV_WRITE, cb, arg)` + `event_base_loop()`; libuv's
  `uv_poll_start(handle, events, cb)` "as soon as an event is detected the
  callback will be called". Sources: <https://libevent.org/doc/event_8h.html>,
  <https://docs.libuv.org/en/v1.x/poll.html>.

## 7. Kernel primitives and portability

Four families, historically layered:

- **`select`** — fixed-size `fd_set`, `nfds` = highest fd + 1, O(n) scan,
  `FD_SETSIZE` cap, three separate sets (read/write/except).
  <https://linux.die.net/man/2/select>.
- **`poll`** — variable-length `pollfd[]`, no per-fd bit cap (only the `nfds`
  argument), still O(n) scan, single array. <https://linux.die.net/man/2/poll>.
- **`epoll`** (Linux) — scalable, level- or edge-triggered;
  `epoll_create` + `epoll_ctl` + `epoll_wait`. Note "Some other systems provide
  similar mechanisms, for example, FreeBSD has *kqueue*, and Solaris has
  */dev/poll*." <https://linux.die.net/man/7/epoll>.
- **`kqueue`** (BSD/macOS) — generic filter/notification mechanism; more general
  than readiness (timers, signals, process events, vnode changes).
  <https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2&format=html>.

Portable abstraction is provided only by libraries, never by the OS:

- libevent picks a backend at runtime and exposes it:
  `event_get_supported_methods()`, `event_base_get_method()`; feature flags
  distinguish `EV_FEATURE_ET`, `EV_FEATURE_O1`, `EV_FEATURE_FDS`,
  `EV_FEATURE_EARLY_CLOSE`. Source: <https://libevent.org/doc/event_8h.html>.
- libuv layers its own event loop and exposes `uv_poll_t` over whatever the
  platform provides (epoll/kqueue/IOCP/…). Source:
  <https://docs.libuv.org/en/v1.x/poll.html>.
- **Windows is the odd one out**: IOCP is a *completion* model (proactor), not a
  readiness model. The documented way to combine it with synchronous-ish waiting
  is `GetQueuedCompletionStatus` with a timeout, and the port's *concurrency
  value* is the key tuning knob. Source:
  <https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports>.

## 8. Timeouts

Three different units and sentinels coexist:

| API | Timeout type | Unit | Infinite sentinel | "poll once" sentinel |
| --- | --- | --- | --- | --- |
| `poll` | `int timeout` | milliseconds | negative (`-1`) | `0` |
| `ppoll` | `const struct timespec *` | seconds + nanoseconds | `NULL` | zero-valued `timespec` |
| `select` | `struct timeval *` | seconds + microseconds | `NULL` | zero-valued `timeval` |
| `pselect` | `const struct timespec *` | seconds + nanoseconds | `NULL` | zero-valued `timespec` |
| `epoll_wait` | `int timeout` | milliseconds | `-1` | `0` |
| `kevent` | `const struct timespec *` | seconds + nanoseconds | `NULL` | zero-valued `timespec` |

Sources: <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>,
<https://linux.die.net/man/2/ppoll>, <https://linux.die.net/man/2/select>,
<https://linux.die.net/man/2/epoll_wait>,
<https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2&format=html>.

Facts worth recording:

- The granularity is a *lower bound*: "This interval will be rounded up to the
  system clock granularity, and kernel scheduling delays mean that the blocking
  interval may overrun by a small amount." (poll)
  <https://linux.die.net/man/2/poll>.
- `select` may **write back** the remaining time into the caller's `timeval`;
  Linux does, most others do not, and POSIX permits either — so the value is
  only safe to read on Linux and "undefined" in general.
  <https://linux.die.net/man/2/select>.
- A nonstandard `INFTIM` constant with value -1 is defined by *some* systems for
  `poll`, but "This constant is not provided in glibc."
  <https://linux.die.net/man/2/ppoll>.
- `ppoll` with a NULL `sigmask` "differs from `poll()` only in the precision of
  the *timeout* argument." <https://linux.die.net/man/2/ppoll>.

## 9. Bounded vs unbounded waits, EINTR and overflow

- **Unbounded waits are always representable**, by a magic sentinel, never by an
  explicit flag: negative `int` for `poll`/`epoll_wait`, `NULL` pointer for the
  `*select`/`kevent` variants. This means an all-zero or nonnegative timeout is
  *always* bounded. Sources as in §8.
- **EINTR is the cancellation/interruption mechanism.** "A signal occurred
  before any requested event." POSIX `poll` lists `[EINTR] A signal was caught
  during poll()`. Crucially, signal(7) states that `epoll_wait`, `poll`,
  `ppoll`, `select`, `pselect` "are never restarted after being interrupted by a
  signal handler, regardless of the use of `SA_RESTART`; they always fail with
  the error `EINTR`." So callers must loop on `EINTR` themselves. Sources:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>,
  <https://linux.die.net/man/7/signal>.
- **Atomic wait+signal** is the whole point of `pselect`/`ppoll`/`epoll_pwait`:
  they let the caller block a signal, test a flag and wait without the
  lost-wakeup race; the pre-pselect workaround is the **self-pipe trick**.
  Sources: <https://linux.die.net/man/2/select>,
  <https://linux.die.net/man/2/ppoll>,
  <https://linux.die.net/man/2/epoll_wait>.
- **Timeout-unit overflow is real.** `poll`'s timeout is `int` milliseconds →
  ~24.8 days maximum, and `epoll_wait` had a documented kernel bug: "In kernels
  before 2.6.37, a *timeout* value larger than approximately `LONG_MAX / HZ`
  milliseconds is treated as -1 (i.e., infinity)." That silently converts a very
  large *bounded* wait into an *unbounded* one. Source:
  <https://linux.die.net/man/2/epoll_wait>.
- **Spurious readiness** is documented: Linux `select` "may report a socket file
  descriptor as 'ready for reading', while nevertheless a subsequent read
  blocks"; the advice is to use `O_NONBLOCK` anyway. Source:
  <https://linux.die.net/man/2/select>. libuv repeats the warning for its poll
  handles: "It is possible that poll handles occasionally signal that a file
  descriptor is readable or writable even when it isn't." Source:
  <https://docs.libuv.org/en/v1.x/poll.html>.

## 10. Interesting design decisions

- **`revents` as a separate output field** keeps `events` read-only and makes
  the same struct re-usable across calls without rebuilding it; POSIX even
  guarantees `fd`/`events` are not modified.
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>.
- **Negative `fd` = skip** is a zero-cost way to mask one slot for a single call
  without copying the array. <https://linux.die.net/man/2/poll>.
- **`POLLERR`/`POLLHUP`/`POLLNVAL` are unconditional outputs**: they are
  reported even if not requested, so a caller can never fail to notice a broken
  fd. <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>.
- **`pselect`/`ppoll` atomic signal-mask swap** is the textbook fix for the
  lost-wakeup race; the same idea appears as `kevent` `udata`/signal filters.
  <https://linux.die.net/man/2/select>.
- **Level- vs edge-triggered as a per-fd registration flag** (`EPOLLET`),
  changing the *meaning* of a notification; edge mode forces the "drain until
  EAGAIN" discipline. <https://linux.die.net/man/7/epoll>.
- **`udata`/`data` opaque passthrough** in `kevent`/`epoll_event` lets a
  framework carry its own pointer through the kernel, which is what enables
  callback dispatch without a lookup table.
  <https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2&format=html>,
  <https://linux.die.net/man/2/epoll_wait>.
- **Backend introspection as public API** (`event_get_supported_methods`,
  `EV_FEATURE_*`) lets an application degrade gracefully instead of assuming
  epoll. <https://libevent.org/doc/event_8h.html>.

## 11. Decisions NOT to copy

- **Three timeout representations and three sentinels** (`int` ms vs `timespec`
  vs `timeval`; `-1`/negative vs `NULL` vs zero). A modern API should have one
  timeout type and one "no timeout" representation.
  Sources: §8 above.
- **The `select` write-back of `timeout`** making it "undefined after return" on
  most platforms — a pure footgun. <https://linux.die.net/man/2/select>.
- **`int`-millisecond timeouts** with the resulting ~24.8-day cap and the
  `epoll_wait` truncate-to-infinity bug. <https://linux.die.net/man/2/epoll_wait>.
- **`fd_set` + `FD_SETSIZE` + `nfds = max fd + 1`** — a fixed bitmask with a
  low, compile-time cap and O(n) scans; `pollfd[]` already fixed it.
  <https://linux.die.net/man/2/select>.
- **In-place mutation of caller buffers** (`fd_set`, `select`'s `timeout`).
  Returning a fresh result set is safer.
- **`errno` as a global side channel** that must be read immediately and can be
  clobbered. <https://man7.org/linux/man-pages/man3/errno.3.html>.
- **Unconditional output bits mixed into the same field as requested bits**
  (`revents` carries `POLLERR`/`POLLHUP`/`POLLNVAL` the caller never asked for):
  a typed result (ready / error / hangup) is clearer.
- **The completion-vs-readiness split leaking into the API** (IOCP vs
  poll): a new library should pick one model and hide the OS difference.

## 12. Ideas fitting Mojo

- **A typed `PollFd` value struct** mirroring `pollfd` but without the
  `void*`/`int` free-for-all: `fd: Int32`, `events: PollMask`, `revents:
  PollMask`, passed as a mutable `Span[PollFd]` or `List[PollFd]`. Mojo's value
  semantics make "clear `revents`, keep `events`" explicit. Source for
  `Span`/`List`: `mojov1/types/collections`.
- **`PollMask` as a bitmask type** (e.g. a `UInt32` newtype with `POLLIN`,
  `POLLRDHUP`, …) instead of bare `short` macros; `comptime` constants replace
  the C macros. Source: `mojov1/keywords/comptime`.
- **One timeout parameter of one type** with explicit constructors rather than
  three sentinels: `PollTimeout.Infinite`, `PollTimeout.None` (poll once),
  `PollTimeout.millis(n)`. C shows the cost of sentinel overloads (§9).
- **Typed `raises` error instead of `-1` + `errno`**: a `PollError` carrying the
  errno value; and a *success* result type that names the outcomes explicitly —
  `timeout`, `ready(count)` — rather than a bare count. Source:
  `mojov1/errors/error-model`. The C design conflates 0-with-success and
  N-with-success.
- **EINTR as a first-class, expected outcome**, not an exception: a
  `poll` that loops internally on `EINTR` unless the caller opts out maps the
  C idiom (`while (poll(...) == -1 && errno == EINTR)`) into the library.
  Sources: §9.
- **Ownership: the fd is borrowed, the array is owned.** A `poll` signature that
  takes `mut Span[PollFd]` (caller-owned array) and never takes ownership of the
  `fd` mirrors C's contract exactly, and Mojo can enforce the "fd not modified"
  guarantee by writing only the `revents` field. Sources: §5;
  `mojov1/memory/ownership-and-lifetimes`.
- **`comptime`-selected backend** (epoll on Linux, kqueue on macOS, poll
  fallback) with a single public API — the libevent `event_get_supported_methods`
  idea expressed as compile-time `where`/`comptime if` rather than a runtime
  string. Sources: <https://libevent.org/doc/event_8h.html>;
  `mojov1/keywords/comptime`, `mojov1/interop/calling-c` (`platform_map`).
- **A `poll_into` (no-alloc, caller buffer) plus an allocating convenience
  returning a `List[ReadyFd]`**, matching the `encode_into`/allocating split
  used elsewhere in MojoAkku.
- **Expose the C FFI boundary honestly**: `external_call["poll", c_int](...)`
  with `Pointer(to=...)` for the array, `c_int` timeout, and `errno` read via a
  dedicated accessor — the `std.ffi` aliases (`c_int`, `c_short`, `c_size_t`)
  are the correct mapping. Source: `mojov1/interop/calling-c`.

## Sources

- POSIX `<poll.h>`:
  <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/poll.h.html>
- POSIX `poll()`:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>
- POSIX `<sys/select.h>`:
  <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/sys_select.h.html>
- POSIX `pselect`/`select`:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/select.html>
- Linux `poll(2)`/`ppoll(2)`:
  <https://linux.die.net/man/2/poll>, <https://linux.die.net/man/2/ppoll>
- Linux `select(2)`:
  <https://linux.die.net/man/2/select>
- Linux `epoll(7)`:
  <https://linux.die.net/man/7/epoll>
- Linux `epoll_wait(2)`:
  <https://linux.die.net/man/2/epoll_wait>
- Linux `signal(7)` (EINTR / no-restart list):
  <https://linux.die.net/man/7/signal>
- Linux `errno(3)`:
  <https://man7.org/linux/man-pages/man3/errno.3.html>
- FreeBSD `kqueue(2)`:
  <https://man.freebsd.org/cgi/man.cgi?query=kqueue&sektion=2&format=html>
- libevent `event.h` (core API, backends, features):
  <https://libevent.org/doc/event_8h.html>
- libuv `uv_poll_t`:
  <https://docs.libuv.org/en/v1.x/poll.html>
- Microsoft Learn, I/O completion ports:
  <https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports>
- Mojo `mojov1` buch: `interop/calling-c`, `errors/error-model`,
  `types/collections`, `memory/ownership-and-lifetimes`, `keywords/comptime`.
