# os_poll — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected end
state. Format and rules: `.agents/workflows/LibraryLayout.md`.

## Timeout and result shapes

- `PollTimeout.infinite()` — an explicit unbounded wait constructor (out of scope: `os_poll` ships bounded waits only). (origin: `rust.md` §3, `c.md` §12)
- `wait_until(deadline)` — absolute-deadline wait to avoid loop drift across spurious wakeups. (origin: `rust.md` §10)
- `timeout remainder out-param` — report how much of the timeout was left after an EINTR retry. (origin: `python.md` §9)
- `ReadySet` / `poll_into` — a no-alloc caller-buffer variant returning ready records rather than an in-place `revents`. (origin: `c.md` §12, `java.md` §12)
- `poll_until(predicate)` — interruptible bounded wait that returns once a caller predicate holds. (origin: `cpp.md` §12)
- `PollOutcome` (ready/timeout/interrupted) — one shared result type replacing per-primitive status enums. (origin: `cpp.md` §12)

## Kernel-primitive entry points

- `epoll` backend — Linux scalable level/edge-triggered API as an opt-in entry. (origin: `c.md` §7, `java.md` §7)
- `kqueue` backend — BSD/macOS filter/notification API as an opt-in entry. (origin: `c.md` §7, `java.md` §7)
- `select` fallback — the fixed `fd_set` primitive where `poll` is unavailable. (origin: `c.md` §7, `python.md` §7)
- `ppoll` / `pselect` — atomic signal-mask wait variants. (origin: `c.md` §9, `rust.md` §3)
- `backend()` query — report which kernel primitive the build selected. (origin: `c.md` §10)
- Windows support — `WSAPoll`/IOCP-backed readiness. (origin: `c.md` §7, `rust.md` §7)

## Registration/stateful poller (event-loop shaped)

- `Poller` with register/modify/unregister — a stateful selector owning its OS poll object, closed in deinit. (origin: `python.md` §3, `java.md` §3)
- `wakeup` handle — self-pipe/eventfd to interrupt a blocked wait from another thread. (origin: `java.md` §9, `python.md` §10)
- opaque per-fd token/payload — user data carried through the readiness result. (origin: `java.md` §3, `python.md` §10)

## Async (explicitly a non-goal today)

- `async readiness surface` — callback/event-loop integration (Mojo `async` is unstable and a non-goal today). (origin: `js-ts.md` §11, `go.md` §11, `rust.md` §11)
