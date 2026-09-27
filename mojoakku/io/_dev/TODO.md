# io — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected end
state. Format and rules: `.agents/workflows/LibraryLayout.md`.

## Text layer

- `text Reader` — a byte → UTF-8 decoding reader adapter (the `INVALID_UTF8` kind reserves the place). (origin: `_dev/DESIGN.md` Open Questions; `java.md` §11)
- `text Writer` — the encoding counterpart of a text reader. (origin: `_dev/DESIGN.md` Non-Goals; `java.md` §11)
- `read_line` / `lines` over a buffered reader — line-oriented text reads. (origin: `rust.md` §3, `go.md` §3, `python.md` §3)

## Zero-copy windows

- `peek` — non-consuming lookahead returning a borrowed view of buffered bytes. (origin: `rust.md` §12, `go.md` §12)
- `fill_buf` / `consume` — the borrowed-buffer window protocol for zero-copy parsing. (origin: `rust.md` §12)

## Timeouts and kinds

- `per-operation timeout` — a `timeout: Optional[...]` argument on reads/writes (the `TIMED_OUT` kind reserves the place). (origin: `rust.md` §12, `go.md` §11)
- `NOT_SEEKABLE` error kind — a dedicated kind for a non-seekable source (release 1 uses `OTHER`). (origin: `_dev/DESIGN.md` Open Questions)

## Ergonomics

- `ReadResult.eof()` / `ReadResult.data(count)` — comptime constructors for readability. (origin: `_dev/DESIGN.md` Open Questions)
- `bytes → stdlib Writer adapter` — a bridge that formats bytes through the stdlib `Writer`/`Writable`. (origin: `_dev/DESIGN.md` Dependencies)

## Adapters not needed for the first release

- `bytes → text (non-UTF-8) codec adapters` — other encodings beyond UTF-8. (origin: `java.md` §11)
- `async stream surface` — an async read/write layer (Mojo `async` is unstable and a non-goal today). (origin: `java.md` §12, `rust.md` §11)
