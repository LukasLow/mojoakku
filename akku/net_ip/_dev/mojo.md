# ip research: Mojo (buch pointer)

The Mojo side of the research is covered by the `mojov1` buch, not by a
researcher-written file. This note records what the buch answers and which parts
of the question set it does **not**, because those unanswered parts are the
library's gap premise.

## What the buch answers

- **Q1 — standard library support: nothing for IP.** The stdlib overview lists
  **37 top-level packages**: `algorithm, atomic, base64, benchmark, bit, builtin,
  collections, compile, complex, documentation, ffi, format, gpu, hashlib, io,
  iter, itertools, logger, math, memory, origin, os, pathlib, prelude, pwd,
  python, random, reflection, runtime, stat, subprocess, sys, tempfile, testing,
  time, traits, utils`. There is **no `net`, `socket`, `ip` or `inet` package**.
  Source: `mojov1/stdlib/overview`.

- **Q5 — ownership/lifecycle is the language's value model.** Mojo is
  value-semantic by default; a small struct of integers is `Copyable`/`Movable`
  and trivially destructible. Sources: `mojov1/memory/value-semantics`,
  `mojov1/lifecycle/life`, `mojov1/lifecycle/death`.

- **Q4 — errors are return values.** Functions are non-raising by default;
  `raises` advertises failure, typed `raises ParseError` carries a struct error,
  and `Optional`/`try_...` is the idiomatic non-throwing path. Source:
  `mojov1/errors/error-model`, `mojov1/errors/raising-and-propagation`.

- **Q6 — blocking is explicit.** Async/`await` is unstable; the reliable
  concurrency primitives are `std.atomic` and locks. A pure address library has
  no I/O at all. Sources: `mojov1/concurrency/async-and-parallelism`.

- **Q12 — language anchors.** Fixed-width integers (`UInt32`, `UInt128`),
  `Array[UInt8, N]`/`Array[UInt16, 8]` inline storage, `Span`/`MutSpan` views,
  `Optional`, `comptime` members, typed `raises`, `mut self`, and `struct`
  value semantics are all available. Sources: `mojov1/types/overview`,
  `mojov1/types/collections`, `mojov1/keywords/struct`.

- **C-FFI is available but not required.** `std.ffi external_call` can reach
  libc, and the capability ledger marks `net-sockets` as `have` — but address
  parsing/formatting is pure integer and text work, so `net_ip` needs **no FFI**
  and **no socket**. Sources: `mojov1/interop/calling-c`, `mojo.yml`.

## What the buch does not answer (the gap premise)

- No IP address type, no parse/format, no classification, no address arithmetic:
  the entire surface `net_ip` must provide.
- No standard textual format helper for RFC 5952 (compressed IPv6) — the
  implementation must own that.

## Mojo positioning

`net_ip` is a **pure, in-process, allocation-light value library**: two concrete
`isbits`-like address structs behind a family-tagged API, with typed parse
errors, a predicate set, and explicit mapped-address handling. It depends on no
sibling MojoAkku library and is the address foundation for `net_socket` and the
rest of the `net_`/`proto_`/`web_` chain.

## Sources

- Buch `mojov1/stdlib/overview`, `mojov1/interop/calling-c`,
  `mojov1/errors/error-model`, `mojov1/memory/value-semantics`,
  `mojov1/types/overview`, `mojov1/keywords/struct`.
- `mojo.yml` (capability ledger, `net-sockets: have`).
