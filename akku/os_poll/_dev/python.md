# os_poll research: Python

Scope: synchronous file-descriptor readiness (`select`/`poll`/`epoll`/`kqueue`/`devpoll`)
with **bounded** timeouts. Async frameworks (`asyncio`, `trio`, `curio`) are out of
scope except where they reveal a design decision.

## 1. Standard library support

Two stdlib modules are relevant:

- **`select`** — low-level access to `select()`, `poll()`, `devpoll()` (Solaris),
  `epoll()` (Linux ≥ 2.5.44) and `kqueue()` (most BSD, macOS). On Windows it only
  works for sockets; on Unix also pipes, but never regular files.
  Source: <https://docs.python.org/3/library/select.html>
- **`selectors`** — higher-level I/O multiplexing built on `select`, added in 3.4.
  It defines `BaseSelector` plus concrete `SelectSelector`, `PollSelector`,
  `EpollSelector`, `DevpollSelector`, `KqueueSelector`, and `DefaultSelector` as
  "the most efficient implementation available on the current platform".
  Docs explicitly recommend `selectors` over `select` unless you want direct
  control over the OS primitive.
  Source: <https://docs.python.org/3/library/selectors.html>

Relevant fact: neither module is available on WASI ("not WASI").
Source: <https://docs.python.org/3/library/select.html>

## 2. Relevant community libraries

- **`selectors2`** — Seth Michael Larson (SethMLarson); backported/portable
  `selectors` for Python 2.6+/Jython; drop-in replacement; adds PEP 475 handling
  and guards against platforms that advertise a selector without implementing it.
  License: dual MIT + PSF. Maturity: **archived 2020-07-22**, read-only.
  Sources: <https://github.com/sethmlarson/selectors2>
- **`pyuv`** — Saúl Ibarra Corretgé (saghul); Python CFFI bindings to libuv;
  exposes a `Poll` handle equivalent to `uv_poll_t`, backed by epoll/kqueue/IOCP/
  event ports. Maturity: legacy (last docs v1.4.0, docs © 2011–2013).
  `GUESS:` license (not re-verified in fetched sources; the pyuv project is
  commonly MIT — no source consulted here confirms it).
  Sources: <https://github.com/saghul/pyuv>, <https://pyuv.readthedocs.io/en/v1.x/poll.html>
- **`selectors34`** — mentioned by `selectors2` as the older backport; no PEP 475.
  Source: <https://github.com/sethmlarson/selectors2>

No other widely-used, maintained pure-readiness library surfaced; `asyncio` is the
de-facto consumer but is out of scope.

## 3. Exposed APIs

`select` module (source: <https://docs.python.org/3/library/select.html>):

- `select.select(rlist, wlist, xlist, timeout=None) -> (r, w, x)` — triples of
  ready objects; objects are fds or anything with `fileno()`.
- `select.poll()` → polling object: `register(fd[, eventmask])`,
  `modify(fd, eventmask)`, `unregister(fd)`, `poll([timeout])`
  → list of `(fd, event)` tuples.
- `select.epoll(sizehint=-1, flags=0)` → `register(fd[, eventmask])`,
  `modify(fd, eventmask)`, `unregister(fd)`, `poll(timeout=None, maxevents=-1)`,
  `close()`, `closed`, `fileno()`, `fromfd(fd)`.
- `select.devpoll()` → `register/modify/unregister/poll` + fd accessors.
- `select.kqueue()` → `control(changelist, max_events[, timeout]) -> eventlist`,
  `close()`, `closed`, `fileno()`, `fromfd(fd)`.
- `select.kevent(ident, filter=KQ_FILTER_READ, flags=KQ_EV_ADD, fflags=0, data=0, udata=0)`.
- Constants: `POLLIN`, `POLLPRI`, `POLLOUT`, `POLLERR`, `POLLHUP`, `POLLRDHUP`,
  `POLLNVAL`; `EPOLLIN/OUT/PRI/ERR/HUP/ET/ONESHOT/EXCLUSIVE/RDHUP/...`;
  `KQ_FILTER_READ/WRITE/...`, `KQ_EV_ADD/DELETE/ENABLE/DISABLE/ONESHOT/...`;
  `PIPE_BUF`.

`selectors` module (source: <https://docs.python.org/3/library/selectors.html>):

- `EVENT_READ = 1 << 0`, `EVENT_WRITE = 1 << 1`
  (`Lib/selectors.py`, module level; source:
  <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>).
- `SelectorKey` namedtuple `(fileobj, fd, events, data)`; `data` is opaque user
  payload (`Lib/selectors.py`).
- `BaseSelector.register(fileobj, events, data=None) -> SelectorKey`,
  `unregister(fileobj) -> SelectorKey`, `modify(fileobj, events, data=None)`,
  `select(timeout=None) -> list[(key, events)]`, `close()`, `get_key(fileobj)`,
  `get_map()`, context-manager `__enter__`/`__exit__`.

## 4. Error representation

- `select.error` is a **deprecated alias of `OSError`** since 3.3 (PEP 3151).
  Source: <https://docs.python.org/3/library/select.html>
- `selectors.register`: `ValueError` for invalid event mask/fd, `KeyError` if
  already registered; `unregister`: `KeyError` if not registered.
  Source: <https://docs.python.org/3/library/selectors.html>
- `poll.modify` on an unregistered fd raises `OSError` with errno `ENOENT`;
  `poll.unregister` on an unregistered fd raises `KeyError`.
  Source: <https://docs.python.org/3/library/select.html>
- `epoll.unregister` no longer ignores `EBADF` since 3.9 (raises `OSError`).
  Source: <https://docs.python.org/3/library/select.html>
- The selector source also documents a subtlety: `register` "OSError if fileobj is
  closed or otherwise unacceptable"; `unregister` deliberately does **not** raise
  `OSError` if the fd was closed after registration
  (`Lib/selectors.py`, `_BaseSelectorImpl.unregister` / `_PollLikeSelector.unregister`
  swallows `OSError`; source:
  <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>).

Errors are **exceptions**, never sentinel return values. Errors on the polled fd
itself are surfaced as event bits (`POLLERR`/`POLLHUP`/`POLLNVAL`,
`EPOLLERR/EPOLLHUP`), not exceptions.

## 5. Ownership semantics

- The selector owns only its internal `dict[int, SelectorKey]` map (`_fd_to_key`)
  and (for poll/epoll/devpoll/kqueue) the underlying OS poll object; it does
  **not** own and never closes the registered file objects.
  Source: <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- Contract: "A file object shall be unregistered prior to being closed."
  Source: <https://docs.python.org/3/library/selectors.html>
- `BaseSelector.close()` "must be called to make sure that any underlying resource
  is freed"; after close `get_map()` returns `None` and `get_key` raises
  `RuntimeError('Selector is closed')` (`Lib/selectors.py`).
- epoll objects close their control fd; the new fd is non-inheritable; they
  support `with` so the control fd is closed at block exit.
  Sources: <https://docs.python.org/3/library/select.html>,
  <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- The selector never owns buffers — there are no buffers, only readiness events.
- `data` is an opaque reference held by the selector for the caller; ownership
  stays with the caller.

## 6. Blocking / non-blocking

- All readiness calls block by default; `timeout=0` polls without blocking; the
  readiness of the fd itself is independent of the fd's blocking mode.
- `select.select` blocks until one fd is ready unless timeout given.
  Source: <https://docs.python.org/3/library/select.html>
- `selectors.BaseSelector.select(timeout)`: `>0` max wait seconds, `<=0` never
  blocks, `None` blocks until ready.
  Source: <https://docs.python.org/3/library/selectors.html>
- `_PollLikeSelector.select` clamps: `None → None`, `<=0 → 0`, positive → rounded
  up to whole milliseconds with `math.ceil(timeout * 1e3)`.
  Source: <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- `EpollSelector.select` additionally converts the rounded value back to seconds
  (`math.ceil(timeout * 1e3) * 1e-3`) because `epoll.poll` takes seconds, while
  `poll.poll` takes integer milliseconds.
  Source: <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- Concurrency model: the selector itself is a blocking primitive; `asyncio` runs
  it on an event loop and integrates signals through a wakeup fd. The selector is
  not documented as thread-safe, and `close()`/registration from another thread
  while a `select` is blocked is not safe. `GUESS:` no source found that states
  selector thread-safety explicitly; the underlying `select()` call is not
  interruptible by another thread except via an fd/signal.

## 7. Kernel primitives and portability

- Backends: `select` (bitmap, O(highest fd)), `poll` (O(number of fds)),
  `devpoll` (O(active fds), Solaris), `epoll` (Linux), `kqueue` (BSD/macOS).
  Source: <https://docs.python.org/3/library/select.html>
- Portable abstraction: `selectors.DefaultSelector` picks, roughly,
  `epoll|kqueue|devpoll > poll > select`, and `_can_use()` actually instantiates
  and probes the object (calling `poll(0)` or `close()`) so a primitive that is
  absent at runtime falls back instead of crashing.
  Source: <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- `SelectSelector` maps the cross-platform `EVENT_READ/EVENT_WRITE` to the
  three-list `select` interface and, on Windows, folds the exception list into
  the writable list (`Lib/selectors.py`, `SelectSelector._select`).
- Windows: stdlib only supports sockets through WinSock `select`; `selectors`
  documents the same restriction.
  Sources: <https://docs.python.org/3/library/select.html>,
  <https://docs.python.org/3/library/selectors.html>
- Edge vs level trigger: epoll default is level-triggered; `EPOLLET` switches to
  edge. `selectors.EpollSelector` does not set `EPOLLET`, so it is level-triggered.
  Source: <https://docs.python.org/3/library/select.html>

## 8. Timeouts and cancellation

- Units are inconsistent across primitives:
  - `select.select`: seconds (float).
  - `poll.poll`: **milliseconds** (int); omitted/negative/`None` = block forever.
  - `epoll.poll`: seconds (float); `None` = block forever.
  - `kqueue.control`: seconds (float); default `None` = wait forever.
  - `devpoll.poll`: milliseconds.
  Sources: <https://docs.python.org/3/library/select.html>
- `selectors` normalizes to **seconds (float, `None` = infinite, `<=0` =
  non-blocking)** and converts per backend, rounding up to whole milliseconds so
  a positive timeout waits *at least* the requested time.
  Source: <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- Cancellation of a blocked `select` is **not** a parameter. The idiomatic
  mechanism is a self-pipe / wakeup fd: `signal.set_wakeup_fd()` writes the signal
  number into an fd which is registered with the poller; `asyncio` uses exactly
  this. Sources: PEP 475 <https://peps.python.org/pep-0475/>,
  <https://docs.python.org/3/library/signal.html#signal.set_wakeup_fd>
  (referenced from PEP 475).
- `selectors` has no external cancellation token/signal type; the only "cancellation"
  is closing the selector or the fd and letting `select` return with an fd marked
  ready (or, for Kqueue, unregistering).

## 9. Bounded vs unbounded waits, EINTR, overflow

- Unbounded wait is signalled differently per API: `None` (select/selectors),
  negative or omitted (poll/devpoll), `None` (epoll/kqueue). `0` means a
  non-blocking poll. Source: <https://docs.python.org/3/library/select.html>
- **EINTR**: PEP 475 (Python 3.5) makes stdlib wrappers retry interrupted calls
  and, crucially, **recompute the timeout**, unless the signal handler raises an
  exception (then that exception propagates). It explicitly lists
  `select.select()`, `select.poll.poll()`, `select.epoll.poll()`,
  `select.kqueue.control()`, `select.devpoll.poll()` as modified functions.
  Source: <https://peps.python.org/pep-0475/>
  The `selectors` source keeps explicit `except InterruptedError: return ready`
  fallbacks for pre-PEP-475 runtimes (`Lib/selectors.py`).
- Selector timeout recomputation is the notable design point: naive code must not
  restart the full timeout after an interrupt or a bounded wait becomes unbounded.
  Source: <https://peps.python.org/pep-0475/>
- **Overflow**: `poll.poll` takes a C `int` millisecond value and `selectors`
  computes `math.ceil(timeout * 1e3)`; a very large float timeout may overflow
  the C int (`OverflowError`). `GUESS:` no explicit overflow statement exists in
  the fetched docs; the C-level `poll` timeout is an `int` and CPython converts
  without saturating — reason: docs give no bound and the conversion is a plain
  int coercion. `epoll`'s millisecond resolution and `kqueue`'s max_events edge
  case are the documented precision limits.
- `KqueueSelector.select` uses `max_ev = self._max_events or 1` because "If max_ev
  is 0, kqueue will ignore the timeout" (bug python#29255); that is an explicit
  overflow/edge-case guard in the source.
  Source: <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- Empty-set select is platform-dependent: `select.select([], [], [])` "is known to
  work on Unix but not on Windows". Source: <https://docs.python.org/3/library/select.html>

## 10. Interesting design decisions

- **Two layers, one contract**: raw `select` primitives under a single
  `register/modify/unregister/select/close` contract that hides the backend.
  Source: <https://docs.python.org/3/library/selectors.html>
- **Runtime probing over static platform checks** (`_can_use()` instantiates and
  calls the primitive) to defeat platforms that advertise a syscall but fail at
  call time. Source: <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- **Timeout rounding away from zero** so a bounded wait never returns early due to
  integer truncation. Source: <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- **Opaque `data` payload** attached per fd (`SelectorKey.data`) — the selector
  stays policy-free and the user carries session state.
  Source: <https://docs.python.org/3/library/selectors.html>
- **Events are bitmasks**, errors are bits, not exceptions — keeps the hot path
  allocation-free. Source: <https://docs.python.org/3/library/select.html>
- **PEP 475 EINTR handling at the wrapper level** with timeout recomputation, so
  user code is simple and correct. Source: <https://peps.python.org/pep-0475/>
- **Self-pipe/wakeup fd** as the portable cancellation channel.
  Source: <https://peps.python.org/pep-0475/>

## 11. Decisions NOT to copy

- **Inconsistent timeout units** (seconds vs milliseconds per primitive). Copying
  this forces every caller to remember which backend is active. Use one unit.
  Source: <https://docs.python.org/3/library/select.html>
- **`None` = infinite, `0` = now, negative = infinite** overload. Three sentinels
  for two meanings is error-prone; prefer an explicit bounded type.
  Source: <https://docs.python.org/3/library/select.html>
- **Silent swallowing of `OSError` on unregister** for already-closed fds: hides
  real EBADF bugs. Source:
  <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- **Duck-typed `fileno()` protocol** — any object may masquerade as an fd; Mojo
  should take an explicit fd/handle type.
  Source: <https://docs.python.org/3/library/selectors.html>
- **`selectors` not thread-safe and not documented as such**; do not copy an
  implicit single-thread-only poller without stating it.
  Source: <https://docs.python.org/3/library/selectors.html> (no thread-safety
  guarantee given)
- **Backend-selected-by-default** hiding which syscall runs; for a low-level
  library the caller should know (or be able to pin) the backend.
  Source: <https://docs.python.org/3/library/selectors.html>
- **`select.error` alias** remains as deprecated API surface; do not replicate
  legacy aliases.

## 12. Ideas fitting Mojo

- **One timeout type**: e.g. a `PollTimeout` value type with `none()`/`zero()`/
  `millis(n)` constructors, or an enum, so the caller cannot confuse `None`/`0`/
  negative. (Adapts the PEP 475/`selectors` normalization.)
- **`raises` for setup, bits for readiness**: `register`/`modify` raise
  (`PollError`); `wait` returns event bits as values, no exceptions on the hot path.
  Mirrors the Python split (docs, `Lib/selectors.py`).
- **Ownership**: a `Poller` handle owns its OS poll object and is closed via a
  `Closeable`/`deinit`; registered fds are `borrowed` — the poller never closes
  them. Mirrors the documented unregister-before-close contract.
- **Per-registration opaque token as a value/`Optional[Move]` payload** replacing
  `SelectorKey.data`; explicit rather than untyped.
- **Comptime backend selection**: `comptime` choose epoll/kqueue/select per target,
  while still exposing a raw `poll`/`select` entry point for users who want the
  exact primitive. Complements `selectors`' runtime probe.
- **Explicit cancellation fd/event**: model the self-pipe as a first-class wakeup
  handle instead of relying on signal semantics.
- **Value-semantics event records** (fd, ready-read, ready-write, error, hangup)
  returned in a caller-owned buffer, avoiding heap allocation per wait.

## Sources

- Python `select` — <https://docs.python.org/3/library/select.html>
- Python `selectors` — <https://docs.python.org/3/library/selectors.html>
- CPython `Lib/selectors.py` (3.14) —
  <https://raw.githubusercontent.com/python/cpython/3.14/Lib/selectors.py>
- PEP 475 — <https://peps.python.org/pep-0475/>
- `selectors2` — <https://github.com/sethmlarson/selectors2>
- `pyuv` Poll handle — <https://pyuv.readthedocs.io/en/v1.x/poll.html>
- `pyuv` — <https://github.com/saghul/pyuv>
