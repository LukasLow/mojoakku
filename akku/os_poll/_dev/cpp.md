# os_poll research: C++

Scope: synchronous file-descriptor readiness with **bounded** waits. C++ is
studied mainly for how it *wraps* the C/POSIX readiness primitives and how it
expresses timeouts and cancellation — the raw syscalls are the same C ones.

## 1. Standard library support

The **ISO C++ standard library has no file-descriptor readiness API**. There is
no `<poll>`, `<select>` or `<epoll>` header in the standard header list; the
concurrency support headers are `<atomic>`, `<barrier>`,
`<condition_variable>`, `<future>`, `<latch>`, `<mutex>`, `<semaphore>`,
`<shared_mutex>`, `<stop_token>`, `<thread>`, `<hazard_pointer>`, `<rcu>`.
Source: <https://en.cppreference.com/w/cpp/header>.

Consequences:

- On POSIX platforms C++ gets `::poll` by including the C header `<poll.h>`
  (and `::select` via `<sys/select.h>`). These are C/POSIX headers, not C++
  headers; the C++ standard only *tolerates* them as C-compatibility headers.
  Source: <https://en.cppreference.com/w/cpp/header> (C compatibility headers);
  POSIX `<poll.h>`
  <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/poll.h.html>.
- `<cerrno>` exposes `errno`; `<csignal>` exposes signal handling.
  Source: <https://en.cppreference.com/w/cpp/header>.
- What C++ *does* standardise is **bounded waiting on non-fd events**:
  `std::condition_variable::wait_for` / `wait_until`,
  `std::future::wait_for` / `wait_until`, `std::atomic::wait` (C++20), and
  `std::this_thread::sleep_for`. None of them waits on a file descriptor.

So for the domain, C++ is a **thin wrapper market**: either use POSIX directly,
or use a portable library (Boost.Asio, libevent, libuv). Assessment (derived):
the C++ standard library chose *concurrency primitives*, not *I/O readiness*,
and left fd readiness to the OS/libraries.

## 2. Relevant community libraries

| Library | Maintainer | Maturity | License | Model |
| --- | --- | --- | --- | --- |
| Boost.Asio | Christopher M. Kohlhoff (Boost) | mature, de-facto standard, header-mostly | Boost Software License 1.0 | proactor + reactor-style `wait`; abstracts select/poll/epoll/kqueue/IOCP |
| libevent | Nick Mathewson et al. | mature, widely deployed | BSD-3-Clause | C API, `event_base` + `event_new(fd, EV_READ/EV_WRITE)` |
| libuv | Node.js / libuv project | mature, widely deployed | MIT | C API, `uv_poll_t` handle |
| libev | Marc Lehmann | mature, smaller | BSD-2-Clause (GUESS: not re-verified) | `ev_io` watchers |

- Boost.Asio overview lists the relevant pieces: "Reactor-Style Operations",
  "Streams, Short Reads and Short Writes", "Per-Operation Cancellation",
  "Platform-Specific Implementation Notes", and "The Proactor Design Pattern:
  Concurrency Without Threads". The footer states it is "Distributed under the
  Boost Software License, Version 1.0."
  Sources: <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview.html>,
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio.html>.
- libevent and libuv as in `c.md` §2 (their C APIs are also the C++ fallback):
  <https://libevent.org/doc/event_8h.html>,
  <https://docs.libuv.org/en/v1.x/poll.html>.

## 3. Exposed APIs

### POSIX calls reused verbatim

`::poll`, `::select`/`::pselect`, `::ppoll`, `::epoll_*`, `::kqueue`/`::kevent`
have exactly the C signatures described in `c.md` §3. C++ adds no overloads and
no types. Sources as in `c.md` §3.

### Boost.Asio

Reactor-style wait on a socket (synchronous, bounded by the underlying poll):

```cpp
void wait(wait_type w);                          // throws on error
void wait(wait_type w, boost::system::error_code& ec);  // error_code overload
```

"Wait for the socket to become ready to read, ready to write, or to have pending
error conditions." `wait_type` is `wait_read` / `wait_write` / `wait_error`
(enum `socket_base::wait_type`). The async counterpart is `async_wait(wait_type,
handler)`. Source:
<https://www.boost.org/doc/libs/1_85_0/doc/html/boost_asio/reference/basic_socket/wait.html>;
reactor usage example and `wait_read`/`wait_write` in
<https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/reactor.html>.

Boost.Asio reactor example: "socket.non_blocking(true); … socket.async_wait(
ip::tcp::socket::wait_read, read_handler);" — i.e. Asio *itself* turns fd
readiness into a callback. Source:
<https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/reactor.html>.

### C++ concurrency timed waits

```cpp
// <condition_variable>
std::cv_status condition_variable::wait_for(std::unique_lock<std::mutex>& lock,
                                            const std::chrono::duration<Rep,Period>& rel_time);
template<class Rep, class Period, class Predicate>
bool condition_variable::wait_for(std::unique_lock<std::mutex>& lock,
                                  const std::chrono::duration<Rep,Period>& rel_time,
                                  Predicate pred);

// <future>
template<class Rep, class Period>
std::future_status future<T>::wait_for(const std::chrono::duration<Rep,Period>& timeout_duration) const;

// <stop_token> (C++20)
class stop_token { bool stop_requested() const noexcept; bool stop_possible() const noexcept; };
```

Sources:
<https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>,
<https://en.cppreference.com/w/cpp/thread/future/wait_for>,
<https://en.cppreference.com/w/cpp/thread/stop_token>.

## 4. Error representation

C++ layers **three** error channels on top of the C syscalls:

1. **`std::error_code` / `boost::system::error_code`** — a value-carrying,
   non-throwing channel. Asio offers a throwing overload and an `error_code&`
   overload of `wait`; "The `ec` parameter is set to indicate what error
   occurred, if any." Source:
   <https://www.boost.org/doc/libs/1_85_0/doc/html/boost_asio/reference/basic_socket/wait.html>.
   C++11 `<system_error>` "Defines `std::error_code`, a platform-dependent error
   code." Source: <https://en.cppreference.com/w/cpp/header>.
2. **Exceptions** (`std::system_error`, `boost::system::system_error`) — the
   throwing overloads. Source: same wait page.
3. **Status enums** for timed waits:
   - `std::cv_status::timeout` / `cv_status::no_timeout`.
     Source: <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>.
   - `std::future_status::deferred` / `ready` / `timeout`.
     Source: <https://en.cppreference.com/w/cpp/thread/future/wait_for>.

`std::errc` provides portable errno-like enumerators (`std::errc::interrupted`,
`std::errc::invalid_argument`, …); GUESS (assessment): `std::errc` is the
`<system_error>` enumerator mapping errno values, but this research pass did not
re-fetch the `std::errc` page, so the exact enumerator list is not quoted here.

Key difference from C: C++ *standardised* the errno value into a typed, copyable
`error_code`, while `poll` itself still returns `-1`/`errno` underneath.

## 5. Ownership semantics

- **RAII** replaces manual close: POSIX fds wrapped in a C++ type are closed in
  the destructor; Asio `basic_socket` is a move-only, RAII I/O object.
  Source: <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/cpp2011/move_objects.html>.
- **The caller owns the `pollfd`/`epoll_event`/buffer arrays**, exactly as in C.
  Asio owns its own `io_context` and the internal reactor state.
  Sources: `c.md` §5; Boost.Asio overview
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview.html>.
- **Callbacks/ownership transfer in async mode**: an async operation's handler
  becomes the owner of the buffers until completion; Asio documents movable
  handlers (C++11) so ownership can be transferred into the operation.
  Source: <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview.html>
  ("Movable Handlers"), and
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/buffers.html>.
- **`std::unique_lock` binds the mutex lifetime to the wait call**; after
  `wait_for` returns the lock is re-held ("Right after `wait_for` returns,
  `lock.owns_lock()` is `true`"). Source:
  <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>.
- **`std::stop_token` is an unowned view** of a shared stop-state owned by a
  `std::stop_source`/`std::jthread`; the token itself owns nothing.
  Source: <https://en.cppreference.com/w/cpp/thread/stop_token>.

## 6. Blocking / non-blocking

- Asio offers **both**: synchronous blocking ops (including `basic_socket::wait`)
  and asynchronous ops dispatched by an `io_context`. The design is explicitly
  the **Proactor pattern**: "The Proactor Design Pattern: Concurrency Without
  Threads". Source:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/async.html>.
- The reactor path exists precisely "to facilitate … integration with a
  third-party library that wants to perform the I/O operations itself"; Asio
  includes "synchronous and asynchronous operations that may be used to wait for
  a socket to become ready". Source:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/reactor.html>.
- `io_context::run()` blocks the calling thread until the loop stops; the
  loop-per-thread count determines concurrency. Source (overview, "Threads and
  Boost.Asio"): <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/threads.html>.
- `std::condition_variable::wait_for` blocks the current thread "until the
  condition variable is notified, the given duration has been elapsed, or a
  **spurious wakeup** occurs". Source:
  <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>.
- C++20 `std::jthread` couples a thread to a `stop_source`: "The destructor of
  jthread calls `request_stop()` and `join()`." Source:
  <https://en.cppreference.com/w/cpp/thread/stop_token>.

## 7. Kernel primitives and portability

- Asio is the canonical C++ **portable abstraction**: it implements the proactor
  over epoll/kqueue/select (POSIX) and IOCP (Windows), with a documented
  "Platform-Specific Implementation Notes" page.
  Source: <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/implementation.html>
  (linked from the overview).
- The reactor-style `wait` is explicitly "supported for sockets on all platforms,
  and for the POSIX stream-oriented descriptor classes" — i.e. fd-based waiting
  is a POSIX-only feature, Windows is served by the proactor.
  Source: <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/reactor.html>.
- Underlying primitives (select/poll/epoll/kqueue/IOCP) are those listed in
  `c.md` §7. Windows IOCP is completion-based:
  <https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports>.

## 8. Timeouts

C++ **fixes the unit/sentinel problem** of C:

- Timeouts are `std::chrono::duration` / `time_point`, so the unit is encoded in
  the **type** (`milliseconds`, `microseconds`, `seconds`, …) and cannot be
  silently misread. Sources:
  <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>,
  <https://en.cppreference.com/w/cpp/thread/future/wait_for>.
- There is **no `-1`/`NULL` sentinel**: "no timeout" is expressed by a very large
  duration (e.g. `duration::max()`) or by the untimed `wait()` overload, and
  "poll once" by `duration::zero()`. Assessment: this is the direct improvement
  over C's three sentinels (`c.md` §8).
- `wait_for(rel_time)` is defined in terms of `wait_until(steady_clock::now() +
  rel_time)`; the standard "recommends that a steady clock is used to measure the
  duration". Source:
  <https://en.cppreference.com/w/cpp/thread/future/wait_for>.
- Timed waits may **overrun**: "This function may block for longer than
  `timeout_duration` due to scheduling or resource contention delays." Source:
  <https://en.cppreference.com/w/cpp/thread/future/wait_for>.

## 9. Bounded vs unbounded waits, EINTR and overflow

- **Bounded** is the default mental model: `wait_for`/`wait_until`.
  **Unbounded** is the plain `wait()` (no duration). Sources:
  <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>,
  <https://www.boost.org/doc/libs/1_85_0/doc/html/boost_asio/reference/basic_socket/wait.html>.
- **EINTR** surfaces as `std::errc::interrupted` inside the `error_code`
  (GUESS: the mapping errno `EINTR` → `std::errc::interrupted` is standard
  `<system_error>` behaviour but was not re-fetched this pass). Asio's `error_code`
  overload reports it rather than throwing; the caller decides whether to retry.
- **Spurious wakeups** are explicit in the standard: `wait_for` "may wake
  spuriously"; the `Predicate` overload exists "to ignore spurious awakenings".
  Source: <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>.
- **Cooperative cancellation (C++20)**: `std::stop_token` is "a thread-safe
  'view' of the associated stop-state"; it "can be passed to the interruptible
  waiting functions of `std::condition_variable_any`, to interrupt the condition
  variable's wait if stop is requested." Source:
  <https://en.cppreference.com/w/cpp/thread/stop_token>.
- **Per-operation cancellation (Asio)**: Asio documents "Per-Operation
  Cancellation" and a "Cancellation" section in the async model.
  Source: <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/model/cancellation.html>.
- **No timeout-unit overflow** in the chrono model: durations are typed and
  range-checked at compile time as far as the representation allows, unlike
  C's `int` ms (`c.md` §9).

## 10. Interesting design decisions

- **Proactor over reactor**: Asio's async model decouples "wait for readiness"
  from "perform I/O" and hides the difference between readiness-based POSIX and
  completion-based Windows IOCP.
  Source: <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/async.html>.
- **Two overloads for every operation** — throwing (`void wait(wait_type)`) and
  non-throwing (`void wait(wait_type, error_code&)`) — let the caller choose the
  error channel per call site. Source:
  <https://www.boost.org/doc/libs/1_85_0/doc/html/boost_asio/reference/basic_socket/wait.html>.
- **`wait_type` as a scoped enum** replaces C's separate `POLLIN`/`POLLOUT`
  bitmask for the high-level wait; the bitmask only survives at the fd layer.
  Source: <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/reactor.html>.
- **Typed, unit-carrying timeouts** (`chrono`) remove the "is this ms or ns?"
  class of bugs. Source: <https://en.cppreference.com/w/cpp/thread/future/wait_for>.
- **Predicate-based wait** folds the "test the condition, then sleep" loop into
  the standard library and documents spurious wakeups as normal. Source:
  <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>.
- **Stop tokens** make cancellation a first-class, composable, thread-safe value
  rather than a signal delivered into a syscall. Source:
  <https://en.cppreference.com/w/cpp/thread/stop_token>.
- **Move-only I/O objects** (C++11) let a socket be transferred into an async
  operation without a reference count. Source:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/cpp2011/move_objects.html>.

## 11. Decisions NOT to copy

- **Throwing as the default** for a low-level readiness wait: Asio needs a
  second overload for the `error_code` path, and in a hot event loop exceptions
  are the wrong channel. The non-throwing channel should be primary.
- **Callbacks / inversion of control at the bottom layer**: the Proactor model
  pushes all I/O into `io_context.run()`, which makes the simple "wait for one fd
  with a deadline" case heavy. A Mojo library scoped to synchronous readiness
  should keep a plain bounded-wait call (as libuv's `uv_poll_t` is explicitly
  only a bridge for foreign loops). Source:
  <https://docs.libuv.org/en/v1.x/poll.html>.
- **`std::cv_status` / `std::future_status` as separate enums** — each timed
  primitive invents its own status type; one shared result type would be better.
  Sources: cppreference `wait_for` pages.
- **Spurious wakeups as a documented, unavoidable condition** in the
  condition-variable model; a readiness API should report a definite outcome.
  Source: <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>.
- **"No timeout = a huge duration"**: relying on `duration::max()` instead of an
  explicit `Infinite` variant is a sentinel in disguise.
- **The C++ standard library's omission**: leaving fd readiness entirely to
  POSIX/libraries is exactly the gap a Mojo library can fill with one API.

## 12. Ideas fitting Mojo

- **`chrono`-style typed timeouts without the template weight**: a Mojo
  `PollTimeout` value type with explicit cases (`infinite`, `none`,
  `millis(n)`) gives the type-level clarity of `wait_for` while avoiding C++'s
  duration-template soup. Sources:
  <https://en.cppreference.com/w/cpp/thread/future/wait_for>; `c.md` §8.
- **One result type instead of `cv_status`/`future_status`/`errc`**: a Mojo
  `PollOutcome` (ready / timeout / interrupted) with a typed error for real
  failures mirrors the C++ enum lesson but unifies it. Source: cppreference
  `wait_for` pages.
- **Two conventions for error handling** is idiomatic in Mojo via `raises`
  vs. returning an `Optional`/result: expose one non-raising `poll(...)`
  (primary) and optionally a `raises PollError` variant — C++ shows why the
  non-throwing path must exist. Source: `mojov1/errors/error-model`.
- **Cancellation as a value, not a signal**: C++20's `stop_token` is the right
  precedent — a Mojo `PollCancellation`/`stop` flag checked between bounded
  waits avoids EINTR entirely, while still allowing the OS `EINTR` to be treated
  as a retry internally. Sources:
  <https://en.cppreference.com/w/cpp/thread/stop_token>; `c.md` §9.
- **Move-only fd handle wrapper** (`@explicit_destroy`/`deinit`) to make fd
  ownership explicit, mirroring Asio's movable I/O objects; `poll` borrows the
  handle, never owns it. Sources:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/cpp2011/move_objects.html>;
  `mojov1/memory/ownership-and-lifetimes`.
- **`Span[PollFd]`/`Span[ReadyEvent]` for the arrays**, with the no-alloc path
  primary and an allocating convenience secondary (C++ `std::vector` usage
  confirms the demand for the allocating form).
- **`comptime` backend selection** replaces Asio's runtime
  platform-abstraction and libuv's compile-time backend pick: `comptime if
  os == "linux": epoll` … with a `poll` fallback. Sources:
  `mojov1/keywords/comptime`; <https://libevent.org/doc/event_8h.html>.
- **Interruptible bounded wait with a predicate** is a good Mojo idiom: a
  `poll_until` that takes a thin predicate avoids the "loop + sleep + spurious
  wakeup" boilerplate C++ keeps in user code. Source:
  <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>.

## Sources

- C++ standard library headers (no poll/select header; concurrency headers):
  <https://en.cppreference.com/w/cpp/header>
- `std::condition_variable::wait_for` (cv_status, spurious wakeups, predicate):
  <https://en.cppreference.com/w/cpp/thread/condition_variable/wait_for>
- `std::future::wait_for` (future_status, chrono, overrun):
  <https://en.cppreference.com/w/cpp/thread/future/wait_for>
- `std::stop_token` (C++20 cooperative cancellation):
  <https://en.cppreference.com/w/cpp/thread/stop_token>
- Boost.Asio overview (proactor, reactor, buffers, cancellation, implementation):
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview.html>
- Boost.Asio `basic_socket::wait` (throwing + error_code overloads):
  <https://www.boost.org/doc/libs/1_85_0/doc/html/boost_asio/reference/basic_socket/wait.html>
- Boost.Asio reactor-style operations:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/reactor.html>
- Boost.Asio proactor / async model:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/async.html>
- Boost.Asio threads:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/core/threads.html>
- Boost.Asio movable I/O objects:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/cpp2011/move_objects.html>
- Boost.Asio cancellation:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/overview/model/cancellation.html>
- POSIX `<poll.h>` / `poll()` (the underlying C API):
  <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/poll.h.html>,
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/poll.html>
- libevent core API:
  <https://libevent.org/doc/event_8h.html>
- libuv `uv_poll_t`:
  <https://docs.libuv.org/en/v1.x/poll.html>
- Windows I/O completion ports:
  <https://learn.microsoft.com/en-us/windows/win32/fileio/i-o-completion-ports>
- Mojo `mojov1` buch: `errors/error-model`, `memory/ownership-and-lifetimes`,
  `keywords/comptime`, `types/collections`, `interop/calling-c`.
