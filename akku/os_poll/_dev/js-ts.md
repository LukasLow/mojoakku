# os_poll research: js-ts

Scope: synchronous file-descriptor readiness with **bounded** timeouts in
JavaScript/TypeScript (Node.js). Key fact: Node.js does **not** expose a
synchronous `poll(fds, timeout)` primitive. Readiness is an internal detail of
libuv's event loop; the closest synchronous primitives are timer-bounded blocking
helpers or native addons. This file explains the layers and the closest
synchronous surfaces.

## 1. Standard library support

- **No `poll`/`select` binding in the Node.js standard library.** There is no
  `node:select`, no `node:poll`. `net.Socket` exposes a numeric fd only for
  certain cases and the public API is event/callback based.
- `node:net` is documented as "an asynchronous network API for creating
  stream-based TCP or IPC servers and clients".
  Source: <https://nodejs.org/api/net.html>
- `node:dgram`, `node:net`, `node:tls` all use libuv handles; readiness is
  delivered as events (`'data'`, `'readable'`, `'connect'`), never synchronously.
- libuv itself has a poll handle, `uv_poll_t`, described as "used to watch file
  descriptors for readability, writability and disconnection similar to the
  purpose of poll(2)". It is a C API used internally by Node.js, not exposed to
  JS. Source: <https://docs.libuv.org/en/v1.x/poll.html>
- Timers (`setTimeout`, `setImmediate`, `setInterval`, `node:timers/promises`) are
  stdlib and are the only bounded-wait primitives, but they wait on the event
  loop's **time**, not on fd readiness directly.
  Source: <https://nodejs.org/api/timers.html>
- `node:fs` exposes synchronous, **blocking** file operations (e.g.
  `fs.readSync`), used with raw fds, but these block the whole thread and do not
  wait for readiness under a timeout.
  Source: <https://nodejs.org/api/fs.html> (referenced by the epoll example that
  combines `fs.openSync`/`fs.readSync` with an epoll addon:
  <https://github.com/fivdi/epoll>).

## 2. Relevant community libraries

- **`epoll`** — fivdi (Dieter Oberkofler); low-level Node.js addon binding the
  Linux `epoll` API; callback-based; supports Node 10–20; originally written for
  GPIO `EPOLLPRI`. License: `GUESS:` MIT (npm/GitHub do not state it in the
  fetched page; fivdi's addons are typically MIT). Maturity: small (82 stars),
  Linux-only. Sources: <https://github.com/fivdi/epoll>,
  <https://www.npmjs.com/package/epoll>
- **`deasync`** — abbr fork of vkurchatkin/deasync; turns async calls synchronous
  by pumping the Node event loop inside a C++ `uv_run` loop while blocking JS;
  provides `loopWhile` and `sleep`. License: MIT. Maturity: 1k stars but niche and
  explicitly discouraged for general use. Source: <https://github.com/abbr/deasync>
- **`synckit`** — JounQin / un-ts; runs async work synchronously via
  `worker_threads` + `Atomics.wait`; MIT; very active (52.4M weekly downloads).
  Source: <https://www.npmjs.com/package/synckit>
- **`sync-threads`**, **`make-synchronized`** — alternatives benchmarked by
  `synckit`; same worker/`Atomics.wait` approach.
  Source: <https://www.npmjs.com/package/synckit>
- Built-in `worker_threads` + `Atomics.wait` + `receiveMessageOnPort` is the
  stdlib-level "synchronous bridge" pattern.
  Sources: <https://nodejs.org/api/worker_threads.html>,
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Atomics/wait>

## 3. Exposed APIs

- **libuv `uv_poll_t`** (C, internal to Node):
  - `int uv_poll_init(uv_loop_t*, uv_poll_t*, int fd)`
  - `int uv_poll_init_socket(uv_loop_t*, uv_poll_t*, uv_os_sock_t)`
  - `int uv_poll_start(uv_poll_t*, int events, uv_poll_cb cb)`
  - `int uv_poll_stop(uv_poll_t*)`
  - `enum uv_poll_event { UV_READABLE=1, UV_WRITABLE=2, UV_DISCONNECT=4, UV_PRIORITIZED=8 }`
  - callback `void (*uv_poll_cb)(uv_poll_t* handle, int status, int events)`
  Source: <https://docs.libuv.org/en/v1.x/poll.html>
- **libuv `uv_timer_t`** (the bounded-wait tool):
  `uv_timer_init`, `uv_timer_start(handle, cb, uint64_t timeout, uint64_t repeat)`
  (milliseconds), `uv_timer_stop`, `uv_timer_again`,
  `uv_timer_set_repeat`, `uv_timer_get_repeat`, `uv_timer_get_due_in`,
  `uint64_t uv_now(loop)`.
  Source: <https://docs.libuv.org/en/v1.x/timer.html>
- **Node.js `net.Socket` synchronous-ish surface**: `socket.fd`? Not documented as
  public on modern Node; the documented class exposes `socket.readyState`,
  `socket.connecting`, `socket.pause()/resume()`, events. `net.BoundSocket`
  (new) exposes `boundSocket.fd()` and `close()`.
  Source: <https://nodejs.org/api/net.html#class-netboundsocket>. Full async
  API surface: <https://nodejs.org/api/net.html>
- **`epoll` addon** API: `new Epoll(callback)` with callback
  `(err, fd, events)`; `add(fd, events)`, `remove(fd)`, `modify(fd, events)`,
  `close()`; constants `Epoll.EPOLLIN/OUT/RDHUP/PRI/ERR/HUP/ET/ONESHOT`.
  Source: <https://github.com/fivdi/epoll>
- **`deasync`** API: `deasync(fn)`, `loopWhile(predicate)`, `sleep(ms)`.
  Source: <https://github.com/abbr/deasync>
- **`synckit`** API: `createSyncFn(workerPath, options)`, `runAsWorker(fn)`,
  options `{ timeout, execArgv, transferList, tsRunner, globalShims }`.
  Source: <https://www.npmjs.com/package/synckit>
- **`Atomics`** API: `Atomics.wait(int32Array, index, value[, timeout])` →
  `"ok" | "not-equal" | "timed-out"`; `Atomics.notify`;
  `Atomics.waitAsync` (non-blocking, main thread allowed).
  Sources: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Atomics/wait>,
  <https://v8.dev/features/atomics>

## 4. Error representation

- libuv: positive `int` return codes for init/start; `UV_E*` negative constants
  for errors; in the poll callback `status < 0` maps to a `UV_E*` code, and
  `status == UV_EBADF` discontinues polling.
  Sources: <https://docs.libuv.org/en/v1.x/poll.html>,
  <https://docs.libuv.org/en/v1.x/errors.html>
- Node idioms are split: synchronous setup uses **thrown `Error`s** (e.g. invalid
  callback `TypeError`/`ERR_INVALID_ARG_TYPE`); asynchronous failures are emitted
  as `'error'` events or passed as the first callback argument.
  Sources: <https://nodejs.org/api/timers.html>, <https://nodejs.org/api/net.html>
- `epoll` addon: errors delivered to the callback as `(err, fd, events)`.
  Source: <https://github.com/fivdi/epoll>
- `synckit`: worker-thrown errors propagate as thrown exceptions; a `timeout`
  option exists (no default) and aborts the synchronous wait.
  Source: <https://www.npmjs.com/package/synckit>
- `Atomics.wait` uses **string sentinels** (`"ok"`, `"not-equal"`, `"timed-out"`),
  not exceptions — a notable outlier.
  Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Atomics/wait>

## 5. Ownership semantics

- libuv handle rules (apply to `uv_poll_t`): if `uv_*_init()` succeeds you must
  call `uv_close()`; the handle's memory can only be reclaimed/reused from inside
  or after `uv_close_cb`; only handles are closed, requests are auto-closed.
  Source: <https://docs.libuv.org/en/v1.x/design.html>
- `uv_poll_t` specifically: "The user should not close a file descriptor while it
  is being polled by an active poll handle" — it may report an error or start
  polling another socket; safe to close after `uv_poll_stop()`/`uv_close()`.
  Source: <https://docs.libuv.org/en/v1.x/poll.html>
- The loop owns handles for its lifetime; the loop is meant to be tied to a single
  thread and is **not thread-safe**. Source: <https://docs.libuv.org/en/v1.x/design.html>
- JS level: `net.Socket` owns its underlying handle; buffers are JS-owned
  (`Buffer`/`ArrayBuffer`); the `epoll`/`deasync` addons keep native state until
  `close()`.
- `synckit`: the user must ensure results are structured-clone serializable; the
  worker and its SharedArrayBuffer are owned by the library.
  Source: <https://www.npmjs.com/package/synckit>

## 6. Blocking / non-blocking

- Node's model is a single-threaded event loop; all network I/O is non-blocking and
  polled by libuv. Source: <https://nodejs.org/learn/asynchronous-work/event-loop-timers-and-nexttick>
- The event loop has a **poll phase**: when there are no timers it blocks in the
  poller; if the poll queue is empty and no `setImmediate` is pending, "the event
  loop will wait for callbacks to be added to the queue". A hard system-dependent
  maximum prevents starvation.
  Source: <https://nodejs.org/learn/asynchronous-work/event-loop-timers-and-nexttick>
- No synchronous wait-on-fd exists; every API is callback/Promise/EventEmitter.
  `uv_poll_start` is level-triggered per the docs (callback fires again while the
  fd stays readable/writable unless events are changed).
  Source: <https://docs.libuv.org/en/v1.x/poll.html>
- To get *synchronous* behavior you must either block the thread (`Atomics.wait`
  on a worker, or a native deasync-style `uv_run` pump) or avoid sync entirely.
  Sources: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Atomics/wait>,
  <https://github.com/abbr/deasync>
- `Atomics.wait` is only allowed on worker threads (not the main thread);
  `Atomics.waitAsync` works on the main thread but is asynchronous.
  Source: <https://v8.dev/features/atomics>

## 7. Kernel primitives and portability

- libuv picks the best mechanism: **epoll** (Linux), **kqueue** (macOS/BSD),
  **event ports** (SunOS), **IOCP** (Windows) — an explicitly portable abstraction.
  Sources: <https://docs.libuv.org/en/v1.x/design.html>,
  <https://docs.libuv.org/en/v1.x/>.
- `uv_poll_t` maps to the platform poller; on Windows **only sockets** can be
  polled; on Unix any fd accepted by `poll(2)`. `UV_DISCONNECT` unsupported on AIX.
  Source: <https://docs.libuv.org/en/v1.x/poll.html>
- Node.js does not expose this choice to JS; `epoll` addons are Linux-only and
  bypass libuv's abstraction.
  Source: <https://github.com/fivdi/epoll>
- libuv's model note: "While the polling mechanism is different, libuv makes the
  execution model consistent across Unix systems and Windows."
  Source: <https://docs.libuv.org/en/v1.x/design.html>

## 8. Timeouts

- libuv timers are **milliseconds** (`uint64_t timeout`, `uint64_t repeat`).
  Source: <https://docs.libuv.org/en/v1.x/timer.html>
- Node timers are **milliseconds**; `setTimeout`/`setInterval` clamp delay: "When
  delay is larger than 2147483647 or less than 1 or NaN, the delay will be set to
  1. Non-integer delays are truncated to an integer." — i.e. **overflow saturates
  to 1 ms**, not to a long wait.
  Source: <https://nodejs.org/api/timers.html>
- Cancellation: `clearTimeout`/`clearImmediate`; `Timeout`/`Immediate` objects with
  `ref()`, `unref()`, `refresh()`, `close()`; `Symbol.dispose`.
  Source: <https://nodejs.org/api/timers.html>
- `node:timers/promises` accepts an `AbortSignal`; on abort the promise rejects
  with `'AbortError'`. Source: <https://nodejs.org/api/timers.html>
- `synckit` exposes a `timeout` option and `SYNCKIT_TIMEOUT` env (no default):
  <https://www.npmjs.com/package/synckit>
- `Atomics.wait` timeout is milliseconds and returns `"timed-out"`.
  Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Atomics/wait>
- Poll-handle cancellation is `uv_poll_stop()`; it is immediate and cancels even a
  pending callback. Source: <https://docs.libuv.org/en/v1.x/poll.html>

## 9. Bounded vs unbounded waits, EINTR and overflow

- **Unbounded** at libuv/Node level is either "omit the timer" or an infinite
  poll; Node's poll phase blocks when there is nothing else to do, bounded by a
  system-dependent hard maximum.
  Source: <https://nodejs.org/learn/asynchronous-work/event-loop-timers-and-nexttick>
- **Bounded** waits are timer-bounded, not readiness-bounded: you cannot say
  "wait up to N ms for *this* fd" synchronously. You register a libuv poll handle
  and a timer; whichever fires first wins.
  Sources: <https://docs.libuv.org/en/v1.x/poll.html>,
  <https://docs.libuv.org/en/v1.x/timer.html>
- **EINTR**: not visible to JS. libuv/Node handle signal interruption internally;
  Node never surfaces `EINTR`. `GUESS:` no Node docs page describes EINTR; reason
  — the syscall layer is encapsulated in libuv and Node's public docs do not
  mention it.
- **Overflow**: `setTimeout`/`setInterval` clamp `> 2147483647` ms to `1` ms (an
  aggressive, surprising saturation), and non-integers truncate.
  Source: <https://nodejs.org/api/timers.html>
- libuv timers use `uint64_t` ms, so they do not overflow at 2^31; the JS timer
  layer is the one that clamps. Source: <https://docs.libuv.org/en/v1.x/timer.html>

## 10. Interesting design decisions

- **libuv's handle/request split**: long-lived handles vs short-lived requests,
  with a precise close/callback lifetime rule. Source: <https://docs.libuv.org/en/v1.x/design.html>
- **Portable poller behind one execution model** (epoll/kqueue/event ports/IOCP),
  with fd-level `uv_poll_t` for "integrate an external library" use cases —
  exactly the role MojoAkku's `os_poll` would play for a foreign event loop.
  Source: <https://docs.libuv.org/en/v1.x/poll.html>
- **Poll timeout calculation rules** (NOWAIT/stopping/idle/closing → 0; else
  nearest timer; else infinity). Source: <https://docs.libuv.org/en/v1.x/design.html>
- **Level-triggered by default** with explicit EPOLLET opt-in.
  Source: <https://docs.libuv.org/en/v1.x/poll.html>
- **`uv_poll_stop` cancels pending callbacks immediately** — clean cancellation
  semantics. Source: <https://docs.libuv.org/en/v1.x/poll.html>
- **`Atomics.wait` string-return protocol** instead of exceptions, and
  `waitAsync` for the main thread. Source: <https://v8.dev/features/atomics>
- **Worker + `Atomics.wait` + `receiveMessageOnPort`** as the portable way to make
  async work synchronous without native addons. Source: <https://www.npmjs.com/package/synckit>

## 11. Decisions NOT to copy

- **No synchronous readiness API at all.** Node's all-async model makes a
  bounded synchronous `poll` impossible without blocking the event loop or native
  code. MojoAkku should expose a real synchronous blocking poll.
  Source: <https://nodejs.org/api/net.html>
- **Callback-per-event delivery** (`uv_poll_cb`) instead of a returned event set;
  for a readiness primitive the return-value/buffer model is simpler and avoids
  inversion of control. Source: <https://docs.libuv.org/en/v1.x/poll.html>
- **Timer clamping `> 2^31` down to 1 ms** — silently turns a long wait into a
  near-busy-loop. Never copy this; reject or saturate correctly.
  Source: <https://nodejs.org/api/timers.html>
- **`deasync`'s re-entrant event-loop pump** (nested `uv_run` inside a blocking
  call) — documented as changing execution order and discouraged.
  Source: <https://github.com/abbr/deasync>
- **String sentinels** from `Atomics.wait` (`"ok"/"not-equal"/"timed-out"`) rather
  than a typed status. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Atomics/wait>
- **Global thread-pool file I/O** (libuv runs blocking fs work on a shared,
  size-limited thread pool) — an implementation detail that leaks into behavior;
  a synchronous poll library should not depend on a hidden pool.
  Source: <https://docs.libuv.org/en/v1.x/design.html>
- **Non-thread-safe loop with no compile-time guard** — Mojo can encode
  single-thread/send constraints instead of documenting them in prose.
  Source: <https://docs.libuv.org/en/v1.x/design.html>

## 12. Ideas fitting Mojo

- **fd readiness as a returned value set** (readable/writable/error/hangup) with a
  caller-owned buffer, replacing libuv's per-event callback. Models the
  ready-list of `poll(2)` / `uv_poll_event` bits.
- **A single bounded-wait type in milliseconds** (`uint64`), with explicit
  constructors for "now", "bounded(n)" and "infinite" — avoids Node's clamp and
  Python's multi-sentinel mess.
- **`raises` for registration/backend errors; plain values for readiness**;
  `deinit`/close for the poller owning its OS object (epoll fd / kqueue fd).
- **`borrowed` fds**: the poller observes but never owns or closes registered fds,
  matching the documented libuv "do not close while polled" + unregister-first
  contract.
- **Comptime backend + runtime fallback**: a `comptime`-selected epoll/kqueue/
  select implementation, with a runtime capability probe like libuv's poller
  selection; `os_poll` can also expose the raw primitive for embedding.
- **Explicit wakeup handle** (self-pipe/eventfd) as the cancellation channel,
  mirroring libuv's use of an async handle rather than signal semantics.
- **Value-semantics event bitmask / enum** so `EPOLLET`-style modes are typed
  constants, not loose integers.
- **Single-thread ownership marker**: encode libuv's "loop/handle not thread-safe"
  rule in Mojo's type system (move/borrow) instead of documentation.

## Sources

- Node.js event loop — <https://nodejs.org/learn/asynchronous-work/event-loop-timers-and-nexttick>
- Node.js timers — <https://nodejs.org/api/timers.html>
- Node.js net — <https://nodejs.org/api/net.html>
- Node.js worker_threads — <https://nodejs.org/api/worker_threads.html>
- libuv `uv_poll_t` — <https://docs.libuv.org/en/v1.x/poll.html>
- libuv `uv_timer_t` — <https://docs.libuv.org/en/v1.x/timer.html>
- libuv design overview — <https://docs.libuv.org/en/v1.x/design.html>
- libuv error handling — <https://docs.libuv.org/en/v1.x/errors.html>
- `epoll` npm addon — <https://github.com/fivdi/epoll>, <https://www.npmjs.com/package/epoll>
- `deasync` — <https://github.com/abbr/deasync>
- `synckit` — <https://www.npmjs.com/package/synckit>
- Atomics.wait (MDN) — <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Atomics/wait>
- Atomics (V8) — <https://v8.dev/features/atomics>
