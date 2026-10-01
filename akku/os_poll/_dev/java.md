# os_poll research: java

Scope: **synchronous** file-descriptor readiness with **bounded** waits — the
select/poll-style readiness query, not async I/O. In Java the reference is
`java.nio.channels.Selector` / `SelectorProvider`, whose concrete
implementations sit directly on `epoll`, `kqueue`, `poll` and Windows `select`
(JDK 21 sources, `openjdk/jdk21u`). Where a statement could not be sourced it
is marked `GUESS:` with the reason.

## 1. Standard library support

- The readiness API is **`java.nio.channels`** (module `java.base`): abstract
  class **`Selector`**, abstract class **`SelectableChannel`**, abstract class
  **`SelectionKey`**. `Selector` is the "multiplexor of `SelectableChannel`
  objects" and implements `Closeable`/`AutoCloseable`. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/Selector.html>
- Channel registration returns a **`SelectionKey`** token; a selector keeps
  three key sets: *key set* (`keys()`), *selected-key set* (`selectedKeys()`)
  and the internal *cancelled-key set*. All three are empty on a new selector.
  Source: same Selector javadoc.
- The **provider SPI** is `java.nio.channels.spi`: `SelectorProvider`
  (`SelectorProvider.provider()` = system-wide default), `AbstractSelector`,
  `AbstractSelectableChannel`, `AbstractSelectionKey`. Channels created by
  `Selector.open()` come from `SelectorProvider.openSelector()`. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/spi/SelectorProvider.html>
- `Selector.open()` creates the selector via the default provider and throws
  `IOException`; `provider()` returns the provider that created it. Source:
  Selector javadoc (above).
- The older, unrelated API `java.nio.file.WatchService` also offers a blocking
  readiness-style queue (`poll()`, `poll(long, TimeUnit)`, `take()`) but it is
  for filesystem events, not fd readiness. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/file/WatchService.html>
- There is **no separate `poll()`/`select()` free function** in the Java
  standard library for arbitrary integer fds below the `Selector` abstraction:
  `Selector` only multiplexes `SelectableChannel`s. Source: Selector javadoc
  ("A multiplexor of `SelectableChannel` objects").

## 2. Relevant community libraries

| Library | Maintainer | Maturity | License |
| --- | --- | --- | --- |
| **Netty** (`io.netty.channel.nio.NioEventLoopGroup`, `io.netty.channel.epoll.EpollEventLoopGroup`, `kqueue`) | The Netty Project | Very mature (4.1.x line; API docs 4.1.138.Final) | Apache-2.0 (<https://github.com/netty/netty>, header in `NioEventLoop.java`) |
| **XNIO** (`org.jboss.xnio`, NIO worker/selector layer used by Undertow) | JBoss / Red Hat | Mature, used by Undertow | Apache-2.0 (`GUESS:` license not fetched in this run; repo states Apache-2.0 — reason: not fetched to keep the source set to primary API docs). Repo: <https://github.com/xnio/xnio> |
| **JNA** | java-native-access | Very mature (8.9k stars, 5.19.1) | LGPL-2.1-or-later or Apache-2.0 (from 4.0) — <https://github.com/java-native-access/jna> |
| **jnr-posix** | jnr project | Mature (923 commits, 252 stars) | `GUESS:` Apache-2.0 (LICENSE.txt not fetched); repo: <https://github.com/jnr/jnr-posix> — note: its `POSIX` interface has **no** `poll`/`select`/`epoll` binding (<https://raw.githubusercontent.com/jnr/jnr-posix/master/src/main/java/jnr/posix/POSIX.java>) |

- Netty's `NioEventLoopGroup` is explicitly "used for NIO `Selector` based
  `Channel`s" and takes an optional `SelectorProvider`
  (<https://netty.io/4.1/api/io/netty/channel/nio/NioEventLoopGroup.html>).
  `EpollEventLoopGroup` "uses epoll under the covers … only works on linux"
  (<https://netty.io/4.1/api/io/netty/channel/epoll/EpollEventLoopGroup.html>).
- jnr-posix is listed here only to record that the obvious "POSIX syscall
  access" library does **not** expose readiness; its `POSIX` interface does
  expose `socketpair`, `read`/`write` and `errno`, but no `poll`/`select`
  (source above).

## 3. Exposed APIs

### `Selector` (java.nio.channels.Selector)
- `static Selector open() throws IOException`
- `abstract boolean isOpen()`
- `abstract SelectorProvider provider()`
- `abstract Set<SelectionKey> keys()` (unmodifiable, thread-safe; `UnsupportedOperationException` on modification)
- `abstract Set<SelectionKey> selectedKeys()` (removal allowed, addition not; **not** thread-safe)
- `abstract int selectNow() throws IOException` (non-blocking)
- `abstract int select(long timeout) throws IOException` (blocking up to timeout **milliseconds**)
- `abstract int select() throws IOException` (block indefinitely)
- `int select(Consumer<SelectionKey> action)` / `int select(Consumer<SelectionKey> action, long timeout)` / `int selectNow(Consumer<SelectionKey> action)` (Java 11+)
- `abstract Selector wakeup()`
- `abstract void close() throws IOException`
- Sources: Selector javadoc (above).

### `SelectionKey` (java.nio.channels.SelectionKey)
- Constants: `OP_READ`, `OP_WRITE`, `OP_CONNECT`, `OP_ACCEPT` — all
  `static final int`, the "operation-set bits".
- Methods: `channel()`, `selector()`, `isValid()`, `cancel()`,
  `interestOps()`, `interestOps(int)`, `interestOpsOr(int)`,
  `interestOpsAnd(int)`, `readyOps()`, `isReadable()`, `isWritable()`,
  `isConnectable()`, `isAcceptable()`, `attach(Object)`, `attachment()`.
- The interest set is "initialized with the value given when the key is
  created"; the ready set "is initialized to zero … cannot be updated
  directly". Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/SelectionKey.html>
- `OP_READ` is also set on **end-of-stream / remote shutdown / pending error**;
  `OP_WRITE` on remote read-shutdown or pending error; `OP_CONNECT` on
  "ready to complete its connection sequence, or has an error pending". Source:
  SelectionKey javadoc, field details.
- `readyOps()` is "a hint, but not a guarantee", and is "likely to be made
  inaccurate by external events and by I/O operations". Source: SelectionKey
  javadoc.

### `SelectableChannel` / `AbstractSelectableChannel`
- `configureBlocking(boolean)`, `isBlocking()`, `validOps()`,
  `isRegistered()`, `keyFor(Selector)`, `register(Selector,int)`,
  `register(Selector,int,Object)`, `blockingLock()`, `provider()`. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/SelectableChannel.html>
- `validOps()` returns the operation bits a concrete channel supports
  (`SocketChannel`: read/write/connect; `ServerSocketChannel`: accept;
  `DatagramChannel`: read/write). Source: SelectionKey javadoc ("Each subclass
  of `SelectableChannel` defines a `validOps()` method").

### `SelectorProvider`
- `provider()`, `openSelector()` → `AbstractSelector`,
  `openSocketChannel()`, `openServerSocketChannel()`,
  `openDatagramChannel()`, `openPipe()`, `inheritedChannel()`. Source:
  SelectorProvider javadoc (above).

### `AbstractSelector` (spi)
- `protected final void begin()` / `protected final void end()` — mark "the
  beginning/end of an I/O operation that might block indefinitely" and wire
  `Thread.interrupt()` to `wakeup()`. `cancelledKeys()`, `deregister(...)`,
  `implCloseSelector()`. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/spi/AbstractSelector.html>

## 4. Error representation

- All blocking entry points throw the **checked** `java.io.IOException`
  (`select`, `select(long)`, `selectNow`, `Selector.open`, `close`). Source:
  Selector javadoc.
- Bad arguments/exceptions are **unchecked runtime** exceptions:
  `IllegalArgumentException` for a **negative timeout** and for interest bits
  not supported by the channel (`(ops & ~channel().validOps()) != 0`);
  `CancelledKeyException` from `interestOps`/`readyOps`/`isReadable`…;
  `ClosedSelectorException` after `close()`;
  `ClosedChannelException` / `IllegalBlockingModeException` /
  `IllegalSelectorException` from `register`; `UnsupportedOperationException`
  when modifying the key sets. Sources: Selector and SelectionKey javadoc.
- Reentrant selection throws `IllegalStateException("select in progress")` in
  the base implementation (`SelectorImpl.lockAndDoSelect`). Source:
  `openjdk/jdk21u/src/java.base/share/classes/sun/nio/ch/SelectorImpl.java`
  (<https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/share/classes/sun/nio/ch/SelectorImpl.java>).
- A **timeout is not an error**: `select(long)` returns `0` on expiry. Source:
  Selector javadoc ("Returns: The number of keys, possibly zero").
- `register` failures are also surfaced as exceptions, not return values.
  Source: SelectableChannel javadoc.

## 5. Ownership / lifetime semantics

- **Caller owns the selector and every channel**; both are `Closeable`
  (`Selector` implements `Closeable`/`AutoCloseable`). Source: Selector javadoc.
- Registration ownership: a channel "must first be *registered*" with a
  selector; the returned `SelectionKey` "represents the channel's registration".
  A channel can be registered **at most once per selector**; `keyFor(sel)`
  returns the existing key (or `null`). Source: SelectableChannel javadoc.
- Deregistration is **not direct**: the key must be *cancelled*
  (`SelectionKey.cancel()` or closing the channel); the channel is then
  deregistered during the **next selection operation**. Source: SelectableChannel
  and SelectionKey javadoc.
- Closing the **selector** invalidates all uncancelled keys, deregisters all
  channels and releases resources. Source: Selector javadoc (`close()`).
- Closing a **channel** cancels all of its keys. Source: SelectableChannel
  javadoc.
- `SelectionKey` is **not** `Closeable`; it has no resources of its own. The
  only per-registration state is the single **attachment** object
  (`attach`/`attachment`), which is the intended place for protocol/handler
  state. Source: SelectionKey javadoc.
- `keys()` is an unmodifiable view over live state; keys can be removed only by
  cancellation. `selectedKeys()` is a live set the application must
  `remove()` from. Source: Selector javadoc.
- The `Consumer<SelectionKey>` select variants do **not** populate
  `selectedKeys()`, so there is no set for the caller to own/clean. Source:
  Selector javadoc ("These methods do not add to the selected-key set").

## 6. Blocking / non-blocking

- A channel starts in **blocking mode** and "must be placed into non-blocking
  mode before being registered with a selector, and may not be returned to
  blocking mode until it has been deregistered". Source: SelectableChannel
  javadoc.
- `selectNow()` is non-blocking (returns immediately, `0` if nothing ready);
  `select(long)` blocks up to the timeout; `select()` blocks indefinitely.
  Source: Selector javadoc.
- **Concurrency:** "A `Selector` and its key set are safe for use by multiple
  concurrent threads. Its selected-key set and cancelled-key set, however, are
  not." Selection operations synchronize on the selector, then on the
  selected-key set. Source: Selector javadoc.
- A thread blocked in selection can be woken by `wakeup()`, `close()`, or
  `Thread.interrupt()` (the last sets the interrupt flag and invokes
  `wakeup()`). Source: Selector javadoc.
- The core is **thread-blocking**, not async/callback; event loops are built on
  top by libraries (Netty `NioEventLoop` runs a single-threaded
  `for(;;) { select; processSelectedKeys; runAllTasks }` loop). Sources:
  `openjdk/.../SelectorImpl.java`; Netty `NioEventLoop.run()` in
  <https://raw.githubusercontent.com/netty/netty/4.1/transport/src/main/java/io/netty/channel/nio/NioEventLoop.java>.

## 7. Kernel primitives and portability

The public abstraction is `Selector`/`SelectionKey`; the JDK selects an
implementation per platform, each documented in its class comment:

- Linux: **`EPollSelectorImpl`** — "Linux epoll based Selector implementation",
  using `EPoll.ctl` (`EPOLL_CTL_ADD/DEL/MOD`) and `EPoll.wait(epfd, …, int
  timeout)`, plus an **eventfd** registered for wakeups.
  `openjdk/jdk21u/src/java.base/linux/classes/sun/nio/ch/EPollSelectorImpl.java`
  and `…/EPoll.java`
  (<https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/linux/classes/sun/nio/ch/EPollSelectorImpl.java>,
  <https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/linux/classes/sun/nio/ch/EPoll.java>).
- macOS/BSD: **`KQueueSelectorImpl`** — "KQueue based Selector implementation
  for macOS", using `KQueue.register(..., EVFILT_READ/EVFILT_WRITE, EV_ADD/
  EV_DELETE)` and `KQueue.poll(..., long timeout)`, with a self-pipe for
  wakeups. `openjdk/jdk21u/src/java.base/macosx/classes/sun/nio/ch/`
  (<https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/macosx/classes/sun/nio/ch/KQueueSelectorImpl.java>,
  <https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/macosx/classes/sun/nio/ch/KQueue.java>).
- Generic Unix fallback: **`PollSelectorImpl`** — "Selector implementation based
  on poll", building a native `pollfd` array (`SIZE_POLLFD = 8`, fields
  fd/event/revent) and calling native `poll(long pollAddress, int numfds, int
  timeout)`. It also uses a self-pipe (`IOUtil.makePipe`) as the wakeup fd.
  `openjdk/jdk21u/src/java.base/unix/classes/sun/nio/ch/PollSelectorImpl.java`
  (<https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/unix/classes/sun/nio/ch/PollSelectorImpl.java>).
- Windows: **`WindowsSelectorImpl`** — "A multi-threaded implementation of
  Selector for Windows" built on WinSock `select()` with a fixed
  `MAX_SELECTABLE_FDS = 1024` per `FD_SET` and **helper threads** (one per extra
  1024 fds), plus a wakeup pipe. `openjdk/jdk21u/src/java.base/windows/classes/sun/nio/ch/WindowsSelectorImpl.java`
  (<https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/windows/classes/sun/nio/ch/WindowsSelectorImpl.java>).
- Portability is achieved through the **`SelectorProvider` SPI**: the
  system-default provider is chosen by (1) the
  `java.nio.channels.spi.SelectorProvider` system property, (2)
  `META-INF/services/java.nio.channels.spi.SelectorProvider`, else (3) the
  platform default class. Source: SelectorProvider javadoc.
- Netty additionally exposes **native** backends (`EpollEventLoopGroup`,
  kqueue) to bypass the portable `Selector` for performance; `NioEventLoopGroup`
  stays on the portable path. Sources: Netty API pages (above).

## 8. Timeouts

- `Selector.select(long timeout)`: **milliseconds**; "if positive, block for up
  to `timeout` milliseconds …; if zero, block indefinitely; must not be
  negative". Negative raises `IllegalArgumentException`. Source: Selector
  javadoc.
- `selectNow()` is the `timeout == 0` non-blocking case. Source: Selector
  javadoc.
- Internally the base class normalises `select(0)` to `-1` ("wait
  indefinitely") and `selectNow()` to `0` before calling the platform
  `doSelect(action, timeout)`, whose doc says: "timeout in milliseconds to
  wait, 0 to not wait, -1 to wait indefinitely". Source:
  `…/share/classes/sun/nio/ch/SelectorImpl.java`.
- `select(long)` "does not offer real-time guarantees: It schedules the timeout
  as if by invoking `Object.wait(long)`". Source: Selector javadoc.
- **Cancellation** is explicit: `wakeup()` causes the pending/first selection
  operation to return immediately; calling it while blocked returns the blocked
  call. `close()` behaves as `wakeup()` for a blocked selector.
  `Thread.interrupt()` on a blocked thread also triggers `wakeup()` and sets
  the interrupt status. Sources: Selector javadoc; `AbstractSelector.begin()`
  javadoc.
- Contrast (same JVM, different API): `WatchService.poll(long, TimeUnit)`
  carries an explicit `TimeUnit`, `poll()` is non-blocking and `take()` is
  unbounded — a design that makes the unit part of the call instead of
  hard-coding milliseconds. Source: WatchService javadoc.

## 9. Bounded vs unbounded waits, EINTR and overflow

- **Bounded:** `select(long)` (ms), `select(Consumer,long)`,
  `WatchService.poll(long, TimeUnit)`. **Unbounded:** `select()`,
  `select(Consumer)`, `WatchService.take()`. **Immediate:** `selectNow()`,
  `WatchService.poll()`. Source: Selector / WatchService javadoc.
- **EINTR / interruption is handled inside the JDK loop**, not exposed to the
  caller: each platform `doSelect` loops `while (numEntries == IOStatus.
  INTERRUPTED)`, and for a *timed* poll subtracts the elapsed time from the
  remaining timeout so the caller still gets approximately the requested bound:
  `adjust = System.nanoTime() - startTime; to -= (int)
  TimeUnit.NANOSECONDS.toMillis(adjust); if (to <= 0) numEntries = 0;`.
  Sources: `EPollSelectorImpl.doSelect`, `KQueueSelectorImpl.doSelect`,
  `PollSelectorImpl.doSelect` (above).
- **Timeout-unit overflow is clamped, not rejected**: `epoll_wait`, `kevent`
  and `poll` take an `int`/native timeout, so `doSelect` computes
  `int to = (int) Math.min(timeout, Integer.MAX_VALUE);` (epoll/poll) before
  passing it down. `Integer.MAX_VALUE` ms ≈ 24.8 days. Sources:
  `EPollSelectorImpl.java`, `PollSelectorImpl.java`; KQueue uses
  `long to = Math.min(timeout, Integer.MAX_VALUE)`. The Windows implementation
  keeps a `long timeout` field and passes it to native `poll0(...)`.
  Source: `WindowsSelectorImpl.java`.
- `Object.wait(long)`-style scheduling means the effective bound can exceed the
  requested one ("more or less"). Source: Selector javadoc.

## 10. Interesting design decisions

- **One portable readiness vocabulary**: a single `int` bitmask
  (`OP_READ|OP_WRITE|OP_CONNECT|OP_ACCEPT`) maps onto epoll events, kqueue
  filters (`EVFILT_READ`/`EVFILT_WRITE`), `poll` events and WinSock
  `FD_*` sets. Sources: SelectionKey javadoc; `EPoll.java`, `KQueue.java`.
- **Three key sets with deferred cancellation**: cancel requests are queued and
  processed at the *start* of the next selection (`processDeregisterQueue`), so
  a key can still appear invalid in the meantime — callers must check
  `isValid()`. Source: Selector javadoc; `SelectorImpl.java`.
- **Self-pipe / eventfd wakeup registered inside the same poll set**: epoll uses
  an `eventfd`, kqueue/poll/Windows a pipe; `wakeup()` writes a byte and
  `processEvents` drains it. This is the classic "wake a blocked poll from
  another thread" idiom. Sources: `EPollSelectorImpl.java`, `KQueueSelectorImpl.java`,
  `PollSelectorImpl.java`, `WindowsSelectorImpl.java`.
- **`begin()`/`end()` bracket the blocking call** so `Thread.interrupt()` is
  converted into a selector `wakeup()`. Source: `AbstractSelector.java` javadoc;
  `SelectorImpl.begin/end`.
- **Clamp the timeout at the native boundary** instead of rejecting an
  over-large `long`. Sources: the three Unix selectors above.
- **Consumer-based selection (Java 11)** avoids materialising a
  `selectedKeys()` set per iteration; it invokes `action` for each ready key
  with an exactly-set `readyOps`. Source: Selector javadoc.
- **Reentrancy is detected and rejected** (`IllegalStateException`), and the
  callback variant warns it runs while synchronized on the selector and its
  selected-key set. Sources: `SelectorImpl.java`; Selector javadoc.
- **Windows `select()` 1024-fd limit** is worked around with dynamically
  started "SelectorHelper" threads rather than an fd-count failure. Source:
  `WindowsSelectorImpl.java`.
- **`interestOpsOr`/`interestOpsAnd` (Java 11)** give atomic read-modify-write
  of interests, with `interestOpsAnd` deliberately not validating removed bits
  so `interestOpsAnd(~OP_READ)` works. Source: SelectionKey javadoc.

## 11. Decisions NOT to copy

- **Sentinel timeout semantics (`0` = infinite).** In Mojo a bare `0` meaning
  "wait forever" is a trap; prefer an explicit optional/bounded/blocking
  API shape. (Java evidence: Selector javadoc; `SelectorImpl` maps 0 → -1.)
- **Deferred cancellation with stale `readyOps`.** Requiring `isValid()` checks
  because a cancelled key survives until the next select is error-prone; Mojo
  can make cancellation immediate/invalid by construction. (Selector javadoc.)
- **Mutable shared key sets with partial thread-safety** (`keys()` thread-safe,
  `selectedKeys()` not; fail-fast iterators). Mojo should return owned value
  results rather than expose live mutable sets. (Selector javadoc.)
- **`register` with unchecked mode traps** (`IllegalBlockingModeException`,
  `IllegalSelectorException`, bits validated at runtime against `validOps()`).
  Prefer compile-time-checked readiness masks. (SelectableChannel/SelectionKey
  javadoc.)
- **Callback-while-holding-lock** (`select(Consumer, long)` invokes user code
  synchronized on the selector). Deadlock bait; do not copy. (Selector javadoc.)
- **A service-loader provider SPI** for platform choice; Mojo can select the
  kernel primitive at compile time. (SelectorProvider javadoc.)
- **Multiple overlapping exception types** for one conceptual failure (closed
  vs cancelled vs illegal mode). Mojo's typed `raises` can collapse these.
  (Selector/SelectionKey javadoc.)
- **`long` ms timeout silently clamped** loses the caller's intent without
  telling them; Mojo should either accept a wider native unit or report the
  clamp. (EPollSelectorImpl/PollSelectorImpl.)

## 12. Ideas fitting Mojo

- **Value readiness record instead of a mutable key.** A bounded query could
  return an owned `List`/`InlineArray` of `(fd, readiness_flags)` values, so no
  live set needs `remove()` and no `isValid()` dance is required. (Java
  contrast: `selectedKeys()` must be cleared by the caller — Selector javadoc.)
- **`raises` for I/O errors, typed errors for lifecycle.** `def poll(...) raises
  IoError` and a distinct error for a closed poller, instead of checked
  `IOException` plus four runtime types. (Java: Selector/SelectionKey javadoc;
  Mojo: `raises` / `raises MyErr` — `mojov1/appendix/cheat-sheet`.)
- **`comptime` readiness constants.** `OP_READ`/`OP_WRITE`/`OP_CONNECT`/
  `OP_ACCEPT` map naturally to `comptime` constants (or a `comptime`-parameterised
  mask), keeping the bit layout compile-time. (Mojo: `comptime NAME = value` —
  `mojov1/appendix/cheat-sheet`.)
- **Ownership of the OS handle.** A `Poller` struct owns the epoll/kqueue/poll
  fd, closes it in `__del__` (deinit), and query methods take a borrowed
  (`imm`) self; results are owned values. (Mojo: `imm`/`mut`, `__del__` —
  `mojov1/keyword-conventions/imm`.)
- **Explicit timeout type, no sentinel.** A small timeout type with a unit,
  plus a distinct `block_forever()`/`try_now()` constructor, avoids Java's
  `0`-means-infinite rule. (Java contrast: Selector javadoc.)
- **Platform at compile time.** Use `comptime if` to pick epoll/kqueue/poll/
  select rather than a runtime `SelectorProvider`; Mojo's C-FFI (`mojoNeeds:
  c-ffi`) is the layer. (`mojo.yml`/`.repo/todo/os_poll.yml`; Java contrast:
  SelectorProvider javadoc.)
- **No async in scope.** Keep the API a pure synchronous bounded query; Java's
  `Selector` is already the synchronous reference, and async is explicitly out
  of scope for `os_poll` (`.repo/todo/os_poll.yml` summary).

## Sources

- Java SE 21 `Selector`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/Selector.html>
- Java SE 21 `SelectionKey`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/SelectionKey.html>
- Java SE 21 `SelectableChannel`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/SelectableChannel.html>
- Java SE 21 `SelectorProvider`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/spi/SelectorProvider.html>
- Java SE 21 `AbstractSelector`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/channels/spi/AbstractSelector.html>
- Java SE 21 `WatchService`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/file/WatchService.html>
- OpenJDK 21u `SelectorImpl.java`: <https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/share/classes/sun/nio/ch/SelectorImpl.java>
- OpenJDK 21u `EPollSelectorImpl.java`: <https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/linux/classes/sun/nio/ch/EPollSelectorImpl.java>
- OpenJDK 21u `EPoll.java`: <https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/linux/classes/sun/nio/ch/EPoll.java>
- OpenJDK 21u `KQueueSelectorImpl.java`: <https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/macosx/classes/sun/nio/ch/KQueueSelectorImpl.java>
- OpenJDK 21u `KQueue.java`: <https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/macosx/classes/sun/nio/ch/KQueue.java>
- OpenJDK 21u `PollSelectorImpl.java`: <https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/unix/classes/sun/nio/ch/PollSelectorImpl.java>
- OpenJDK 21u `WindowsSelectorImpl.java`: <https://raw.githubusercontent.com/openjdk/jdk21u/master/src/java.base/windows/classes/sun/nio/ch/WindowsSelectorImpl.java>
- Netty `NioEventLoopGroup`: <https://netty.io/4.1/api/io/netty/channel/nio/NioEventLoopGroup.html>
- Netty `EpollEventLoopGroup`: <https://netty.io/4.1/api/io/netty/channel/epoll/EpollEventLoopGroup.html>
- Netty `NioEventLoop.java`: <https://raw.githubusercontent.com/netty/netty/4.1/transport/src/main/java/io/netty/channel/nio/NioEventLoop.java>
- JNA: <https://github.com/java-native-access/jna>
- jnr-posix: <https://github.com/jnr/jnr-posix> and `POSIX.java`: <https://raw.githubusercontent.com/jnr/jnr-posix/master/src/main/java/jnr/posix/POSIX.java>
- XNIO: <https://github.com/xnio/xnio>
- Mojo: `mojov1/appendix/cheat-sheet` (`comptime`, `raises`), `mojov1/keyword-conventions/imm` (`imm`/`mut`/`__del__`)
- Project context: `.repo/todo/os_poll.yml`
