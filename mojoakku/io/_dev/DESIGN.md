<!--
Design record for mojoakku/io — NOT end-user documentation.
End-user documentation lives inline in the `*.mojo` files (the `# API-DOCS`
blocks) and in `__init__.mojo`. This file keeps the developer-facing reasoning:
status bookkeeping, tests, rationale, reference-API comparisons, non-goals and
open questions. It reflects the state after Phase 12 (implementation review; all
15 entries implemented, 75 tests green).
-->

# io — Design Record

## Purpose

`mojoakku/io` is the single source of truth for the MojoAkku `io` library — the
**byte stream layer** (and, in a later release, its text decode/encode adapters)
that every later networking library (`socket` → `tcp` → `http`) sits on. It
defines the public API, the full semantics of every entry, the error surface, the
ownership and lifecycle rules, and the conventions that the sibling libraries
copy.

It is designed for a low-vision user: one naming scheme, one option model, one
typed error, borrowed input, owned output, and an **explicit EOF outcome** that
cannot be confused with a short read or a failure.

The Mojo standard library already covers console I/O, files and the **write**
traits (`Writer`/`Writable`) — see `mojov1/stdlib/io` — but it has **no `Reader`
trait and no generic byte/text stream abstraction**. That gap is this library's
reason to exist; the write side is the stdlib-first case (wrap/extend).

**Scope of release 1: bytes.** Although the library's remit is "byte and text
streams", the first release ships the **byte** layer only. A text/UTF-8 decoding
adapter is deliberately deferred (see `## Non-Goals` and `## Open Questions`);
the `INVALID_UTF8` error kind reserves its place, so adding text later is
additive and does not change the byte API.

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 15 entries in this document are `implemented` after Phase 12, and every
entry's `Implementation status:` is `implemented`. They were `planned` /
`not implemented` from Phase 3 through Phase 10.

## Dependencies

`io` has **no dependency edge to any sibling MojoAkku library**. It is a leaf in
the dependency graph: it depends only on the Mojo standard library.

| Library | Edge | Justification |
| --- | --- | --- |
| (none) | — | The stream abstractions are pure in-process transforms over `Span[UInt8, _]`/`MutSpan[UInt8, _]`, `String`, `List` and `Int`. No signature mentions a socket, file, buffer, URL or other sibling concept, so no sibling edge can be technically justified. |

- **Why a leaf.** A dependency edge exists only when a library needs another
  library's public types or functions. `io` needs none: every parameter and
  return type comes from the Mojo standard library. Adding an edge would create
  coupling without a technical reason, which the dependency rules forbid.
- **No physical nesting.** `mojoakku/io/` is a flat sibling under `mojoakku/`.
- **The stdlib `Writer`/`Writable` relationship.** MojoAkku `io` does **not**
  reimplement the stdlib's text-formatting `Writer`/`Writable` traits; it is the
  **byte** layer plus the missing **read** side. In release 1 **no adapter
  wraps or extends the stdlib `Writer`** — the only stdlib touch is `Writable`
  conformance on `IoError`/`ReadResult`/`IoErrorKind` so they can be printed. A
  byte→text or byte→stdlib-`Writer` adapter is a future release. Where the
  stdlib already provides a concept MojoAkku wraps it; where it is silent
  (Reader, buffering, adapters), MojoAkku extends. This is recorded per API
  block under `Rationale`.
- **Direction of future edges.** Later libraries (`socket`, `tcp`, `http`) point
  *to* `io`, never the reverse.

## Overview

MojoAkku `io` is a pure, in-process stream library with **one uniform shape**
for the whole layer:

- **Two symmetric traits**, `Reader` and `ByteWriter`, each with a **single
  required buffer-oriented method** and a small set of provided helpers.
- **An explicit read result** (`ReadResult { count, eof }`) instead of a
  `0`/`-1`/`null` sentinel: "short read ≠ EOF ≠ error" is visible in the type.
- **One typed error** (`IoError`) with a small, **closed** `IoErrorKind`
  discriminant — no OS errno leaks into the API.
- **Borrowed buffers**: the caller owns the read/write buffer — a read target is
  the mutable span type `MutSpan[UInt8, _]`, a write input is the immutable
  `Span[UInt8, _]`; the library never retains either.
- **Value-semantics adapters** (`Cursor`, `SpanCursor`, `BufferedReader`,
  `BufferedWriter`, `LimitReader`, `TeeReader`, `MultiReader`) that compose over
  the traits; only the buffered adapters carry a compile-time buffer capacity
  (the others are thin pass-throughs).
- **Explicit, fallible flush** — no silent destructor flush.

The problem space is covered by every reference language, so the value of this
library is not "another stream API". It is a *predictable, consistent and
easy-to-read* surface for a low-vision user. The research shows that the
reference ecosystems each get one or two of these right and rarely all at once:

- Go has the cleanest one-method `io.Reader`/`io.Writer` interface family, but
  overloads the `(n, err)` return (a read can return data *and* an error), makes
  `0, nil` legal-but-undefined, and uses sentinel errors (`io.EOF`) compared with
  `==` (`go.md` §4, §9, §11).
- Rust has the strongest error model (`ErrorKind` + `Result`) and the
  `fill_buf`/`consume` zero-copy window, but `ErrorKind` is `#[non_exhaustive]`
  with ~45 OS-derived variants, `Ok(0)` doubles as "EOF" and "empty buffer", and
  `BufWriter`'s `Drop` flush **silently discards** errors (`rust.md` §4, §9, §11).
- Python has the richest layering (`RawIOBase`/`BufferedIOBase`/`TextIOBase`)
  but a three-valued read (`bytes | None | b''`), an unbounded `read(size=-1)`
  default, and buffered objects that leak a re-entrancy lock into semantics
  (`python.md` §7, §9, §11).
- Java has the most complete decorator set but checked exceptions on every
  method, an in-band `-1` EOF sentinel in an `int` (Okio: "one of 257 possible
  values"), `available()` (self-documented as "never correct to use"), and
  `mark`/`reset` hidden state (`java.md` §4, §9, §11).
- C and C++ expose the codec through `-1`+`errno`, sentinel `EOF` with a
  `feof`/`ferror` two-call probe, and (C++) a three-layer `streambuf`/`istream`
  model with `iostate` bits and a separate `gcount()` query (`c.md` §4, §9;
  `cpp.md` §4, §9).
- JS/TS has the loosest model: `read(size)` returns `null` for both "empty right
  now" and "ended", and two consumer modes can silently lose data (`js-ts.md`
  §9, §11).
- Elixir `IO` separates `:eof` from `{:error, _}` cleanly but collapses plain
  failures to bare atoms, and its full I/O Protocol is self-described as too
  complex (`elixir.md` §9, §11).

Mojo's own stdlib `io` (`mojov1/stdlib/io`) is the direct Mojo anchor: it has
`print`/`input`, `open`/`FileHandle`, and the `Writer`/`Writable` traits — and
**no `Reader` trait and no generic stream abstraction** — the gap this library
closes.

`io` depends on **no other MojoAkku library**. It needs no Python interpreter.

## Goals

1. **One consistent shape.** `Reader` and `ByteWriter` use the same method
   pattern (one required buffer method + provided helpers), so learning one
   teaches the other and every adapter looks the same. MojoAkku uses a single
   `read`/`write` surface because Go's symmetric `io.Reader`/`io.Writer` and the
   Mojo stdlib's own required-vs-provided `Writer` split show that a minimal,
   symmetric trait pair is the most learnable (`go.md` §10, §12;
   `mojov1/stdlib/io`).

2. **Explicit EOF, no sentinel.** A read returns `ReadResult { count, eof }`;
   EOF is never a `-1`/`0`/`null` overload. MojoAkku uses an explicit result
   because Java's `-1`, JS's `null`, Rust's `Ok(0)`-as-EOF-or-empty and C's
   `EOF`+`feof`/`ferror` all conflate "data", "end" and "error" (`java.md` §11;
   `js-ts.md` §9; `rust.md` §9; `c.md` §9).

3. **Errors as values, one closed taxonomy.** Failures raise `IoError` with a
   small, closed `IoErrorKind`; the OS errno never leaks. MojoAkku uses a closed
   enum because Rust's `#[non_exhaustive]` `ErrorKind` with ~45 OS-derived
   variants forces wildcard matches and leaks platform detail (`rust.md` §11).

4. **Borrowed buffers, owned output.** Read/write take the caller's buffer — a
   read target is `MutSpan[UInt8, _]`, a write input is `Span[UInt8, _]`; the
   library never retains or allocates the buffer. This makes C's "implementations
   must not retain p" a compiler-checked rule (`go.md` §5, §12; `c.md` §5). A
   bare `Span` is `imm` (read-only), so a write destination must be `MutSpan`
   (`mojov1/types/collections`, `mojov1/versions/1.0.0`).

5. **Composable value-semantics adapters.** Buffering and limiting are ordinary
   structs over the traits, with a compile-time buffer size — no virtual
   dispatch, no class tree (`rust.md` §12; `java.md` §11).

6. **Explicit, fallible `flush`.** No destructor performs a silent flush.
   MojoAkku uses a named `flush` because Rust's `BufWriter` `Drop` "attempt[s] to
   flush … any errors … will be ignored" — a documented footgun (`rust.md` §11).

7. **Readability for a low-vision user.** Stable names, one option model, one
   error type, identical field names in every documented entry.

8. **Pure Mojo.** No hidden global state, no Python dependency, no `unsafe` in
   the public surface.

## Non-Goals

Decisions the library deliberately does **not** copy, taken from the research
`## 11` sections. Each is a `MojoAkku rejects … because …` statement.

- **In-band EOF sentinels.** MojoAkku rejects Java's `-1` ("one of 257 possible
  values"), JS's `null`, and Rust's `Ok(0)`-as-EOF-or-empty because a single
  value must not carry "data", "end" and "error" (`java.md` §11; `js-ts.md` §9;
  `rust.md` §9).
- **Sentinel errors compared with `==`.** MojoAkku rejects Go's `io.EOF`
  sentinel-and-`==` test because it makes end-of-stream a special error value
  rather than a typed outcome (`go.md` §9, §11).
- **A read that returns data *and* an error.** MojoAkku rejects Go's `(n, err)`
  both-populated return, and Go's "may use all of p as scratch space" licence,
  because they make the read region and the failure ambiguous (`go.md` §11).
- **Open / OS-derived error taxonomies.** MojoAkku rejects Rust's
  `#[non_exhaustive]` ~45-variant `ErrorKind` because matching OS errno
  categories leaks platform detail into the API (`rust.md` §11).
- **`0, nil` as a legal read result.** MojoAkku rejects Go's documented
  "nothing happened" state because it forces `ErrNoProgress` heuristics; a
  well-formed read either makes progress, ends, or names a condition
  (`go.md` §11).
- **Error-losing destructor flush.** MojoAkku rejects Rust's `BufWriter` `Drop`
  flush (errors ignored) because a flush failure must be reportable; `flush` is
  explicit and fallible (`rust.md` §11).
- **Silent data loss in buffered wrappers.** MojoAkku rejects Rust's
  `BufReader` "contents of its buffer will be discarded … can cause data loss"
  by keeping the **read** buffer owned and drained deterministically; for the
  **write** side it requires an explicit, fallible `flush`/`close` and documents
  drop-without-flush as an accepted loss rather than pretending a flush happened
  (`rust.md` §11).
- **`mark`/`reset` hidden stream state.** MojoAkku rejects Java's
  `mark`/`reset` because it makes behaviour depend on hidden history and is
  "unsafe-to-compose" (`java.md` §11).
- **`available()` as a size predictor.** MojoAkku rejects Java's `available()`
  because it is self-documented as "never correct to use … to allocate a buffer"
  (`java.md` §11).
- **Checked exceptions on every method.** MojoAkku rejects Java's
  `throws IOException` discipline because it forces `throws` up the call graph
  and pushes callers to unchecked wrappers; Mojo's `raises` is in the signature
  without a forced catch (`java.md` §11).
- **The `-1`/`0`/`EOFException`/`null` inconsistency.** MojoAkku rejects the
  four different encodings of one condition across the Java read family because
  one condition must have one representation (`java.md` §11).
- **Exception-swallowing default loops.** MojoAkku rejects Java's
  `InputStream.read(b,off,len)` converting a mid-stream `IOException` into "end
  of file" because it silently truncates data (`java.md` §11).
- **Byte-for-character silent swaps.** MojoAkku rejects Node's
  `highWaterMark` changing unit after `setEncoding()` and the `read()`-after-end
  `null` because byte and character accounting must not silently swap meaning
  (`js-ts.md` §11).
- **Two consumer modes with data loss.** MojoAkku rejects Node's
  flowing/paused duality ("data will be lost" with no consumer) because the
  consumption style must be chosen once (`js-ts.md` §11).
- **Buffer detach on a BYOB read.** MojoAkku rejects the ArrayBuffer detach
  ("invalidating all existing views … disastrous consequences") because a
  borrowed buffer must remain valid for the call (`js-ts.md` §11).
- **Unbounded `read(size=-1)` defaults.** MojoAkku rejects Python's "read
  everything until EOF" default at the buffered layer because it is
  memory-unbounded and hides the allocation (`python.md` §11).
- **Re-entrancy locks leaking into semantics.** MojoAkku rejects Python's
  buffered-object `RuntimeError` on same-thread re-entry because a lock is an
  implementation detail, not observable semantics (`python.md` §11).
- **The full BEAM I/O Protocol surface.** MojoAkku rejects Elixir's
  `getopts`/`setopts`/`{requests, …}`/`get_geometry` protocol because it is
  self-described as too complex for a first release (`elixir.md` §11).
- **Text mode that returns the wrong result on a byte call.** MojoAkku rejects
  Elixir's `IO.binread`-on-a-Unicode-device footgun because a typed API must make
  that impossible by construction (`elixir.md` §11).
- **Global mutable cwd.** MojoAkku rejects Elixir's `File.cd/1` global state
  because it races across processes (`elixir.md` §11).
- **Class inheritance as the extension mechanism.** MojoAkku rejects Java's
  `Filter*` subclassing because Mojo traits compose without single-inheritance
  limits (`java.md` §11).
- **GC/finalizer-based resource release.** MojoAkku rejects Java's GC-reliance
  because it is not available in Mojo and is a documented leak risk
  (`java.md` §11).
- **`gcount()`-style separate byte-count queries.** MojoAkku rejects C++'s
  `gcount()` because a separate query is reset by `putback`/`unget`/`peek`; the
  count is returned by the read (`cpp.md` §12).
- **Two parallel sync/async hierarchies.** MojoAkku rejects Rust's unrelated
  `std::io::Read` and `tokio::io::AsyncRead` with duplicated adapters; one
  stream concept with an execution policy is smaller (`rust.md` §11).
- **Deadlines as mutable stream state.** MojoAkku rejects Go's `SetDeadline` and
  Java's `setSoTimeout(0 == infinite)` because a mutable, storable deadline is
  easy to leave stale; a timeout is a per-operation value (`go.md` §8, §11;
  `java.md` §8).
- **Async/await in the core.** MojoAkku rejects pulling `async`/`await` into the
  stream surface because Mojo's `async` is documented unstable and listed as a
  non-goal today; the core is blocking and synchronous (`java.md` §12;
  `mojov1/concurrency/async-and-parallelism`, `mojov1/keyword-conventions/async-await`).
- **A text/UTF-8 codec in release 1.** MojoAkku defers text decoding/encoding
  adapters to a later release so the byte contract is settled first; the
  `INVALID_UTF8` kind and this note reserve the space, and a text layer can be
  added additively. Java's two parallel byte/char hierarchies and the
  `InputStreamReader`/`CharsetDecoder` bridge zoo are the anti-pattern avoided
  (`java.md` §11).

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| Minimal one-method reader trait | Go `io.Reader` (`Read(p []byte) (n int, err error)`); Rust `Read::read`; Mojo stdlib `Writer` (one required method) | `go.md` §3; `rust.md` §3; `mojov1/stdlib/io` |
| Minimal one-method writer trait | Go `io.Writer`; Rust `Write::write`; Mojo `Writer.write_string` | `go.md` §3; `rust.md` §3; `mojov1/stdlib/io` |
| Explicit result vs sentinel | Java `-1` in `int`; JS `null`; Rust `Ok(0)`; C `EOF`+`feof`/`ferror`; Python `bytes|None|b''` | `java.md` §9; `js-ts.md` §9; `rust.md` §9; `c.md` §9; `python.md` §9 |
| Closed error taxonomy | Rust `ErrorKind` (`#[non_exhaustive]`, ~45 variants); Go sentinels + `OpError`/`PathError` (`op` field); Java checked `IOException` | `rust.md` §4; `go.md` §4; `java.md` §4 |
| Borrowed buffer, no retention | Go "Implementations must not retain p"; Rust `&mut [u8]`; C `restrict` (unenforceable) | `go.md` §5; `rust.md` §5; `c.md` §5 |
| Buffered wrapper as a value struct | Rust `BufReader<R>`/`BufWriter<W>`; Go `bufio.Reader` (buffer + ints) | `rust.md` §7, §12; `go.md` §7, §12 |
| Zero-copy borrow window | Rust `BufRead::fill_buf`/`consume`; Go `bufio.Peek`/`ReadSlice` | `rust.md` §12; `go.md` §12 |
| In-memory cursor | Rust `Cursor<T>`; Go `bytes.Reader`; C `open_memstream` | `rust.md` §3; `go.md` §3; `c.md` §3 |
| Limit / tee / multi adapters | Go `io.LimitReader`, `io.TeeReader`, `io.MultiReader` | `go.md` §3, §12 |
| Copy pump | Go `io.Copy`; Rust `io::copy` (specialized) | `go.md` §3; `rust.md` §12 |
| Seek | Rust `Seek::seek`/`SeekFrom`; Go `io.Seeker`; C `fseek`/`SEEK_*` | `rust.md` §3; `go.md` §3; `c.md` §3 |
| Explicit fallible flush | Rust `Write::flush`/`BufWriter::into_inner`; Go `bufio.Writer.Flush` | `rust.md` §11; `go.md` §11 |
| Compile-time buffer size | Mojo `comptime` value parameters; `basic_spanbuf` fixed buffer | `mojov1/functions/parameters-and-generics`; `cpp.md` §12 |
| Mojo language anchors | `Span`/`MutSpan`/`StringSpan` views; `List`/`String` owned; `comptime` value parameters; typed `raises`; `mut self`; `with` | `mojov1/types/collections`; `mojov1/functions/parameters-and-generics`; `mojov1/errors/error-model`; `mojov1/keywords/with` |

## Public API

Every entry below is listed here with its one-line meaning and is fully
specified in `## Semantics`. Names are stable: Phase 5 documents them and
Phase 7 stubs them, in this order.

**Option, error and result types**

1. `IoErrorKind` — compile-time discriminant for `IoError`: `INTERRUPTED`,
   `WOULD_BLOCK`, `CLOSED`, `TIMED_OUT`, `INVALID_UTF8`, `UNEXPECTED_EOF`,
   `OTHER`.
2. `IoError` — the one typed error: `kind: IoErrorKind`, `op: String`,
   `detail: String`.
3. `ReadResult` — explicit read outcome: `count: Int`, `eof: Bool`.
4. `SeekFrom` — where a seek starts: `START`, `CURRENT`, `END` with an `Int`
   offset.

**Traits**

5. `Reader` — one required `read(mut self, buf: MutSpan[UInt8, _]) raises
   IoError -> ReadResult`; provided `read_exact`, `read_to_end`.
6. `ByteWriter` — one required `write(mut self, data: Span[UInt8, _]) raises
   IoError -> Int`; provided `write_all`, `flush`.
7. `Seeker` — one required `seek(mut self, whence: SeekFrom) raises IoError ->
   Int`.

**Adapters and functions**

8. `Cursor` — in-memory reader+writer+seeker over an **owned** `List[UInt8]`.
9. `SpanCursor` — read+seek only over a **borrowed** `Span[UInt8, _]` (the
   read-only counterpart of `Cursor`; the two are distinct types because a
   struct field has one concrete type).
10. `BufferedReader[R: Stream]` — buffered wrapper with an inline,
    compile-time-sized buffer.
11. `BufferedWriter[W: Sink]` — buffered wrapper with an explicit, fallible
    `flush`/`close`.
12. `LimitReader[R: Stream]` — reads at most `n` bytes.
13. `TeeReader[R: Stream, W: Sink]` — mirrors everything read into a writer.
14. `MultiReader[R: Stream]` — concatenates a homogeneous set of readers (stored
    in a `List`).
15. `copy` — pumps a reader into a writer until EOF.

(`comptime Stream = Reader & Movable & Deinitable` and
`comptime Sink = ByteWriter & Movable & Deinitable` are the bounds every stored
stream type parameter satisfies.)

## Semantics

#### Terminology

- **Stream** — a `Reader`, `ByteWriter` or `Seeker` implementation.
- **Short read** — a `read` that fills fewer bytes than the buffer holds; it is
  normal and is **not** EOF and **not** an error.
- **EOF** — the end of the input; reported as `ReadResult { count, eof: True }`,
  never as an error and never as a magic `-1`/`0`/`null`.
- **Buffer borrow** — the caller's `MutSpan[UInt8, _]` (read target) or
  `Span[UInt8, _]` (write input) is borrowed for the call only; the library must
  not retain it.

All lengths are in bytes/symbols, not codepoints. All inputs are treated as raw
bytes; the library never performs UTF-8 conversion unless an explicit text
adapter does so.

---

### `IoErrorKind`

Status: implemented

Signature:

```mojo
struct IoErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    def __eq__(self, other: Self) -> Bool

    comptime INTERRUPTED    = IoErrorKind(0)
    comptime WOULD_BLOCK    = IoErrorKind(1)
    comptime CLOSED         = IoErrorKind(2)
    comptime TIMED_OUT      = IoErrorKind(3)
    comptime INVALID_UTF8   = IoErrorKind(4)
    comptime UNEXPECTED_EOF = IoErrorKind(5)
    comptime OTHER          = IoErrorKind(6)

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `IoError.kind`; never passed by a
  caller to a stream. The type is **opaque**: the seven `comptime` members are
  the complete public set; `_id` and its `@doc_hidden` initializer are
  implementation details (Mojo has no access control; `mojov1/decorators/doc-hidden`).
  `__eq__` is written explicitly as an intentional override that mirrors the
  `Sentiment` comptime-member pattern (`mojov1/functions/parameters-and-generics`,
  `mojov1/types/operator-support`); `Equatable` would otherwise synthesize a
  field-wise default. `err.kind == IoErrorKind.INTERRUPTED` works.
- **Return / meaning:** the machine-testable reason for a stream failure.
  `INTERRUPTED` — the operation was interrupted and may be retried;
  `WOULD_BLOCK` — the operation would block (non-blocking handle);
  `CLOSED` — the stream or its underlying handle is closed;
  `TIMED_OUT` — a deadline expired; `INVALID_UTF8` — a text adapter saw invalid
  UTF-8; `UNEXPECTED_EOF` — an exact-read (`read_exact`) hit end of stream before
  filling the buffer (Rust's `UnexpectedEof`, `rust.md` §4); `OTHER` — any other
  condition, including a non-seekable stream and an invalid seek target (the
  opaque `IoError.detail` carries it).
- **Ownership:** value type; compile-time constants copied into the error value.
- **Stream I/O:** not applicable.

Errors: none.

Tests:

- `test_io_error.mojo`
  - `test_error_kind_eq`
  - `test_error_kind_all_members_distinct`
  - `test_error_kind_write_to_names_kind`
  - `test_error_kind_unexpected_eof_write_to`

Implementation status: implemented

Rationale: MojoAkku uses a **closed** seven-value discriminant because Rust's
`#[non_exhaustive]` `ErrorKind` with ~45 OS-derived variants is explicitly
"intended to grow over time" and forces wildcard matches, leaking platform
detail (`rust.md` §4, §11); Go's sentinel errors compared with `==` and Java's
checked-exception hierarchy are rejected for the same reason (`go.md` §4;
`java.md` §4). `UNEXPECTED_EOF` is included as a distinct kind rather than folded
into `OTHER` because Rust separates `UnexpectedEof` precisely so a caller can
tell a *lossy* truncation from a generic failure (`rust.md` §4). A dedicated
`NOT_SEEKABLE` is deliberately **not** added: a non-seekable stream is an
`OTHER` condition (see `Seeker`); keeping the set closed and small is preferred,
and a new member is additive when the need is proven.

---

### `IoError`

Status: implemented

Signature:

```mojo
@fieldwise_init
struct IoError(Copyable, Deinitable, Writable):
    var kind: IoErrorKind
    var op: String
    var detail: String

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** constructed by the library; callers read the
  three fields in an `except`/`try` block. `op` is a short operation name
  (`"read"`, `"write"`, `"flush"`, `"seek"`), so the caller can tell which call
  failed. `detail` is an opaque, human-readable string (it must **not** be
  parsed; it is not the API surface).
- **Return / meaning:** the single typed error every fallible stream operation
  declares via `raises IoError`. **EOF is not an `IoError`** — it is
  `ReadResult.eof`.
- **Ownership:** value type; `Copyable` and `Deinitable`, so it can be bound and
  inspected. It is deliberately **not** `ImplicitlyCopyable`, so a re-raise must
  transfer with `raise e^` (`mojov1/errors/raising-and-propagation`).
- **Stream I/O:** EOF/EINTR/EAGAIN/close are *represented* here as
  `INTERRUPTED`/`WOULD_BLOCK`/`CLOSED`; the type carries no descriptor itself.

Errors: it **is** the error. Stream failures are data errors: the caller may
retry (`INTERRUPTED`/`WOULD_BLOCK`), reopen (`CLOSED`), adjust the deadline
(`TIMED_OUT`), re-encode (`INVALID_UTF8`). `UNEXPECTED_EOF` is **lossy** (the
consumed prefix of an exact read is gone) but not fatal. No condition is fatal to
the process or unrecoverable in the "cannot proceed" sense.

Tests:

- `test_io_error.mojo`
  - `test_error_fields_kind_op_detail`
  - `test_error_write_to_includes_op`
  - `test_error_copyable_and_deinitable`
  - `test_error_not_implicitly_copyable`

Implementation status: implemented

Rationale: MojoAkku uses a struct with `kind`+`op`+`detail` because Rust's
`io::Error` carries a kind plus context and Go's `*os.PathError`/`*net.OpError`
carry an `op` field naming the operation, while Java's checked `IOException` and
Go's `(n, err)`-both-populated return show how *not* to type the failure
(`rust.md` §4; `go.md` §4; `java.md` §4, §11).

---

### `ReadResult`

Status: implemented

Signature:

```mojo
@fieldwise_init
struct ReadResult(Copyable, Deinitable, Writable):
    var count: Int
    var eof: Bool

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** returned by every `Reader.read`; constructed by
  the implementation. `count` is the number of bytes written into the caller's
  buffer (`0 <= count <= len(buf)`); `eof` marks the logical end of input.
- **Return / meaning:** exactly one of three shapes:
  - `count > 0, eof = False` — a normal (possibly short) read; more data may
    follow.
  - `count > 0, eof = True` — the final bytes, and the source ended in the same
    call.
  - `count = 0, eof = True` — end of input, no bytes.
  A `count = 0, eof = False` result is **not allowed** (see Errors): an
  implementation must not spin returning "nothing happened"; the provided helpers
  treat it as an error rather than looping (`go.md` §11).
- **Ownership:** value type; returned by value, owned by the caller.
- **Stream I/O:** the type *is* the EOF representation.

Errors: none (it is a value). The `count = 0, eof = False` state is **not** part
of the contract: a conforming `read` must never return it. It is rejected the way
Go's documented "0, nil means nothing happened" is rejected (Non-Goals); an
implementation that would otherwise produce it must make progress, set `eof`, or
raise a condition (`go.md` §9, §11). The provided `read_exact`/`read_to_end`
guard against a non-conforming reader by treating a repeated `0, false` as an
`OTHER` error rather than spinning — Go's `ErrNoProgress` (`go.md` §9). (This
matches the write side, where a zero-length `write` without error is `OTHER`.)

Tests:

- `test_io_reader.mojo`
  - `test_read_result_data_then_eof`
  - `test_read_result_zero_count_is_eof`
  - `test_read_result_short_read_is_not_eof`
  - `test_read_result_zero_false_is_rejected_by_helpers`
  - `test_read_result_write_to_reports_count_and_eof`

Implementation status: implemented

Rationale: MojoAkku uses an explicit `{count, eof}` result because Java's in-band
`-1`, JS's `null`, Rust's `Ok(0)`-as-EOF-or-empty, C's `EOF`+`feof`/`ferror` and
Python's `bytes|None|b''` all conflate data, end and error in one value
(`java.md` §9, §11; `js-ts.md` §9; `rust.md` §9; `c.md` §9; `python.md` §9).
C++'s separate `gcount()` query is rejected because it is reset by
`putback`/`unget`/`peek` (`cpp.md` §12).

---

### `SeekFrom`

Status: implemented

Signature:

```mojo
struct SeekFrom(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8
    var offset: Int

    @doc_hidden
    def __init__(out self, id: UInt8, offset: Int)

    def __eq__(self, other: Self) -> Bool

    comptime START   = SeekFrom(0, 0)
    comptime CURRENT = SeekFrom(1, 0)
    comptime END     = SeekFrom(2, 0)

    @staticmethod
    def start(offset: Int) -> SeekFrom
    @staticmethod
    def current(offset: Int) -> SeekFrom
    @staticmethod
    def end(offset: Int) -> SeekFrom
```

Semantics:

- **Parameters / preconditions:** used as the argument of `Seeker.seek`. The
  three `comptime` bases name the reference point; a non-zero `offset` is
  supplied through the `start`/`current`/`end` constructors.
- **Return / meaning:** identifies the seek origin and the signed byte offset,
  mirroring C `SEEK_SET`/`SEEK_CUR`/`SEEK_END` and Rust `SeekFrom`. `offset` is
  signed so `end(-1)` is expressible. `__eq__` compares **both** `_id` and
  `offset`, so `SeekFrom.start(5) == SeekFrom.START` is `False`; the explicit
  override is a deliberate deviation from the field-wise default only in that it
  is written out, not in its result (`mojov1/types/operator-support`).
- **Ownership:** value type; copied by value.
- **Close behavior:** not applicable (it is a value, not a stream).
- **Stream I/O:** the seek *origin*; the resulting position is returned by
  `Seeker.seek` as an `Int`.

Errors: none.

Tests:

- `test_io_seek.mojo`
  - `test_seek_from_comptime_bases`
  - `test_seek_from_start_with_offset`
  - `test_seek_from_end_negative_offset`
  - `test_seek_from_eq_compares_offset`

Implementation status: implemented

Rationale: MojoAkku uses a named origin plus a signed offset because C's
`fseek`/`SEEK_*`, Go's `io.Seeker` and Rust's `SeekFrom` all take exactly an
origin plus an offset, and this is the smallest complete shape (`c.md` §3;
`go.md` §3; `rust.md` §3).

---

### `Reader`

Status: implemented

Signature:

```mojo
trait Reader:
    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult: ...

    def read_exact(mut self, buf: MutSpan[UInt8, _]) raises IoError
    def read_to_end(mut self) raises IoError -> List[UInt8]
```

Semantics:

- **Parameters / preconditions:** `buf` is the caller-owned destination, borrowed
  mutably for the call only. The implementation writes at most `len(buf)` bytes
  and must **not** touch bytes outside the region it reports in `count`
  (rejecting Go's "may use all of p as scratch space", `go.md` §11).
- **Return / meaning:** `read` returns a `ReadResult`; a **short read is normal**
  and is neither EOF nor an error (`rust.md` §9; `python.md` §9). `read_exact`
  fills `buf` completely or raises `IoError` (kind `UNEXPECTED_EOF`) if the
  stream ends first — Rust's `UnexpectedEof`, the explicit form rather than
  Java's `EOFException`. `read_to_end` reads until `eof`, appending to a fresh
  `List[UInt8]` and returning it; when it raises, the partially-read bytes are
  **lost by design** (the `List` is a local) — a caller who needs the partial
  data uses `read` into a caller-owned `MutSpan[UInt8, _]` explicitly instead
  (see `## Error Surface`,
  partial-progress rule).
- **Ownership:** `mut self` — the reader owns its own cursor; the buffer is
  borrowed and never retained. `read_to_end` returns an owned `List[UInt8]`.
- **Close behavior:** this layer defines **no `close`**; a `Reader` is a value,
  not an owned handle. The `CLOSED` kind is reserved for the future file/socket
  layer that owns a descriptor (`mojov1/stdlib/io` `FileHandle` is that layer).
- **Stream I/O / interruption:** on `INTERRUPTED` the caller may retry the same
  call; the provided `read_exact`/`read_to_end` retry `INTERRUPTED`
  internally — Rust's central retry policy, not a per-call-site decision
  (`rust.md` §12). `WOULD_BLOCK` is surfaced, not hidden.

Errors: `raises IoError` — `INTERRUPTED` and `WOULD_BLOCK` are retryable;
`CLOSED` and `TIMED_OUT` are conditions the caller resolves by reopening/adjusting;
`UNEXPECTED_EOF` (from `read_exact` only) means the requested bytes were not
available and the already-consumed prefix cannot be recovered — it is a
**lossy** outcome, not a transient one. All are recoverable in the sense that no
condition is fatal to the process.

Tests:

- `test_io_reader.mojo`
  - `test_read_short_read_is_not_eof`
  - `test_read_fills_at_most_len_buf`
  - `test_read_exact_raises_unexpected_eof`
  - `test_read_exact_retries_interrupted`
  - `test_read_exact_does_not_retry_would_block`
  - `test_read_to_end_reads_until_eof`
  - `test_read_to_end_raises_other_on_no_progress`

Implementation status: implemented

Rationale: MojoAkku uses **one required buffer method plus provided helpers**
because Go's `io.Reader` (one `Read`) and Rust's `Read` (one `read` with ~15
provided operations) are the minimal-contract lesson, and the Mojo stdlib's own
`Writer` already uses exactly this required-vs-provided split (`go.md` §3, §12;
`rust.md` §3, §12; `mojov1/stdlib/io`). It closes the gap named in `_dev/README.md`
("no `Reader` trait"). Go's `(n, err)` both-populated return is rejected
(`go.md` §11).

---

### `ByteWriter`

Status: implemented

Signature:

```mojo
trait ByteWriter:
    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int: ...

    def write_all(mut self, data: Span[UInt8, _]) raises IoError
    def flush(mut self) raises IoError
```

Semantics:

- **Parameters / preconditions:** `data` is borrowed immutably for the call.
  `write` accepts a prefix `0 <= n <= len(data)` and returns `n`.
- **Return / meaning:** `write` returns the number of bytes accepted; a short
  write is normal and is **not** an error. `write_all` loops until every byte is
  written or raises. `flush` pushes any buffered bytes to the underlying sink;
  it is **explicit and fallible**. The trait provides a **default no-op `flush`**
  (a plain unbuffered sink has nothing to flush); buffered/adapter sinks override
  it.
- **Ownership:** `mut self`; `data` borrowed and never retained.
- **Close behavior:** no `close` (this trait is not an owned handle); `CLOSED` is
  raised only when a wrapped handle (future file/socket layer) is closed.
- **Stream I/O / interruption:** `write_all` retries `INTERRUPTED`; `flush`
  reports errors instead of swallowing them.

Errors: `raises IoError`. `write`'s short return is not an error; `write_all`
raises `OTHER` ("write zero") if `write` returns `0` without error.

Tests:

- `test_io_byte_writer.mojo`
  - `test_write_short_write_is_not_error`
  - `test_write_all_loops_until_written`
  - `test_write_all_raises_other_on_zero_write`
  - `test_write_all_retries_interrupted`
  - `test_write_all_does_not_retry_would_block`
  - `test_flush_reports_error`

Implementation status: implemented

Rationale: MojoAkku uses a **byte**-writer trait named `ByteWriter` because the
stdlib already owns the name `Writer` for the *text* formatting trait
(`write_string`), and Go's `io.Writer` and Rust's `Write` are both the minimal
one-required-method byte shape. The name is chosen deliberately over Go's own
`io.ByteWriter` (which means `WriteByte(c byte)`, a *single-byte* writer — a
different concept, `go.md` §3): MojoAkku's trait writes a buffer, so the
collision is a name overlap only, and the API doc block states the meaning
explicitly to avoid confusion (`go.md` §3; `rust.md` §3; `mojov1/stdlib/io`).
`flush` is a provided method **on this trait** (contrast Go, which deliberately
keeps `Flush` out of `io.Writer` and puts it on `bufio.Writer`, `go.md` §10, §11)
because MojoAkku prefers one write abstraction whose terminal flush is always
available and always fallible, rather than a separate buffered-only capability;
Rust's `Write::flush` is the precedent (`rust.md` §10). `flush` is explicit
because Rust's `BufWriter` `Drop` flush "ignores" errors — a documented footgun
(`rust.md` §11).

---

### `Seeker`

Status: implemented

Signature:

```mojo
trait Seeker:
    def seek(mut self, whence: SeekFrom) raises IoError -> Int: ...
```

Semantics:

- **Parameters / preconditions:** `whence` names the origin and offset (see
  `SeekFrom`). (The parameter is named `whence`, not `from`, because `from` is a
  reserved Mojo keyword; `whence` matches `mojov1/stdlib/tempfile`
  `seek(offset, whence)`.)
- **Return / meaning:** the new absolute position from the start of the stream.
  A negative resulting position raises `IoError` (kind `OTHER`).
- **Ownership:** `mut self`; the reader/writer owns its position.
- **Close behavior:** this layer defines no `close`; `CLOSED` is reserved for the
  future file/socket layer.
- **Stream I/O:** seeking past the end may be allowed (the resulting position is
  returned). A stream that cannot seek at all raises `IoError` with kind `OTHER`
  (an open-but-unseekable stream is **not** `CLOSED`; the two are distinct).
  `CLOSED` is only produced by a stream whose underlying handle is closed.

Errors: `raises IoError` — `OTHER` for an invalid target **and** for a
non-seekable stream; `CLOSED` only when the underlying handle is closed. Both
recoverable (adjust the target / reopen). Release-1 test scope: the non-seekable
(`OTHER`) and closed-handle (`CLOSED`) contracts are expressed by the trait
itself and have **no release-1 library target to test** — `CLOSED` belongs to the
future file/socket layer that owns a descriptor, and a non-seekable source does
not exist in this byte-only release; a test-local `Seeker` asserting those kinds
would only echo the fixture's own hard-coded kind (a tautology), so those two
cases are deliberately not tested.

Tests:

- `test_io_seek.mojo`
  - `test_seek_returns_new_absolute_position`
  - `test_seek_negative_target_raises_other`
  - `test_seek_past_end_allowed`

Implementation status: implemented

Rationale: MojoAkku uses a separate `Seeker` trait because Go's `io.Seeker`,
Rust's `Seek` and C's `fseek` are all *optional* capabilities kept apart from the
read/write traits, and folding seek into `Reader` would force every source to
implement it (`go.md` §3; `rust.md` §3; `c.md` §3). A non-seekable stream is an
`OTHER` condition rather than a dedicated kind, keeping the closed error set
small; a `NOT_SEEKABLE` member can be added additively if a caller needs to
branch on it.

---

### `Cursor`

Status: implemented

Signature:

```mojo
struct Cursor(Reader, ByteWriter, Seeker):
    var _buffer: List[UInt8]
    var _pos: Int

    def __init__(out self, var buffer: List[UInt8])

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int
    def seek(mut self, whence: SeekFrom) raises IoError -> Int
```

Semantics:

- **Parameters / preconditions:** `Cursor` is constructed from an **owned**
  `List[UInt8]` and supports reading, writing and seeking. (The read-only,
  borrowed counterpart is `SpanCursor`, a separate type — see its own block.)
- **Return / meaning:** `read`/`write` move `_pos`; `read` at `_pos == length`
  returns `{0, eof: True}`.
- **Ownership:** owns its `List`.
- **Close behavior:** none (in-memory value).
- **Stream I/O:** in-memory; no descriptors.

Errors: `raises IoError` — `OTHER` on an out-of-range seek.

Tests:

- `test_io_cursor.mojo`
  - `test_cursor_read_moves_position`
  - `test_cursor_read_at_end_reports_eof`
  - `test_cursor_write_moves_position`
  - `test_cursor_seek_out_of_range_raises_other`
  - `test_cursor_owns_buffer`

Implementation status: implemented

Rationale: MojoAkku uses an owned `Cursor` because C's `open_memstream` is the
owned, writable in-memory stream and Rust's `Cursor<T>` over an owned `T` is the
closest reference (`c.md` §3; `rust.md` §3). It is split from `SpanCursor`
because a Mojo struct field has one concrete type, so the owned-vs-borrowed
distinction cannot live in one type (`mojov1/types/collections`).

---

### `SpanCursor`

Status: implemented

Signature:

```mojo
struct SpanCursor[origin: Origin[mut=False]](Reader, Seeker):
    var _buffer: Span[UInt8, Self.origin]
    var _pos: Int

    def __init__(out self, buffer: Span[UInt8, Self.origin])

    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
    def seek(mut self, whence: SeekFrom) raises IoError -> Int
```

Semantics:

- **Parameters / preconditions:** constructed from a **borrowed**
  `Span[UInt8, _]` — a read-only view of someone else's data. It supports only
  reading and seeking; **there is no `write`**, so "read-only" is a type-level
  property, not a runtime error.
- **Return / meaning:** `read` moves `_pos`; `read` at `_pos == length` returns
  `{0, eof: True}`.
- **Ownership:** borrows its `Span`; it never owns or mutates the data. It is
  parameterized on the source's `origin` (an immutable origin), so the lifetime
  checker ties the cursor's validity to the borrowed data — the "does not own the
  underlying buffer" contract of C++ `basic_spanbuf` becomes compiler-checked and
  the span cannot outlive its owner (`cpp.md` §12; `mojov1/memory/origin-and-borrowing`).
  (A struct field needs a concrete origin, hence the `origin: Origin[mut=False]`
  parameter with `Self.origin` in the field; a bare `Span[UInt8, _]` field is
  rejected by the compiler.)
- **Close behavior:** none (in-memory value).
- **Stream I/O:** in-memory; no descriptors.

Errors: `raises IoError` — `OTHER` on an out-of-range seek. It cannot raise a
"write to a read-only buffer" error because it has no `write` method.

Tests:

- `test_io_cursor.mojo`
  - `test_span_cursor_read_moves_position`
  - `test_span_cursor_read_at_end_reports_eof`
  - `test_span_cursor_has_no_write`
  - `test_span_cursor_seek_out_of_range_raises_other`
  - `test_span_cursor_borrows_buffer`

Implementation status: implemented

Rationale: MojoAkku uses a separate borrowed `SpanCursor` because Go's
`bytes.Reader` is exactly a read-only view over a caller's byte slice, and Mojo
cannot express "owned or borrowed" in one struct field type
(`go.md` §3; `mojov1/types/collections`).

---

### `BufferedReader`

Status: implemented

Signature:

```mojo
struct BufferedReader[R: Stream, capacity: Int = 4096](Reader):
    var _inner: Self.R
    var _buf: Array[UInt8, Self.capacity]
    var _start: Int
    var _end: Int

    def __init__(out self, var inner: Self.R)
    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
```

(where `comptime Stream = Reader & Movable & Deinitable`, the bound needed for a
stored, owned type parameter.)

Semantics:

- **Parameters / preconditions:** wraps any `Reader`; `capacity` is a
  compile-time value parameter with a default of 4096 bytes (Go's
  `defaultBufSize`, `go.md` §7).
- **Return / meaning:** serves reads from the internal buffer, refilling from
  `_inner` only when empty; a short read from `_inner` is normal. EOF is
  reported only when `_inner` reports EOF **and** the buffer is drained.
- **Ownership:** owns its inline `Array` buffer and its inner reader;
  value-semantics struct, no heap beyond the inner stream.
- **Close behavior:** no `close`; on drop the buffer is released with the value
  (any unread buffered bytes are dropped — the value is being discarded).
- **Stream I/O:** `INTERRUPTED` is retried on refill; `WOULD_BLOCK` is surfaced.

Errors: `raises IoError` — passed through from `_inner`; `OTHER` if `_inner`
reports a zero-length non-EOF read (`ErrNoProgress` analogue).

Tests:

- `test_io_buffered_reader.mojo`
  - `test_buffered_reader_serves_from_buffer`
  - `test_buffered_reader_refills_when_empty`
  - `test_buffered_reader_short_inner_read_is_normal`
  - `test_buffered_reader_eof_only_after_drain`
  - `test_buffered_reader_retries_interrupted_on_refill`
  - `test_buffered_reader_raises_other_on_no_progress`

Implementation status: implemented

Rationale: MojoAkku uses a value-semantics wrapper with an inline,
compile-time-sized buffer because Rust's `BufReader<R>` (a buffer + inner) and
Go's `bufio.Reader` (a byte buffer + three ints) show buffering is a composable
struct, and the compile-time size removes Node's platform-dependent default and
its `setEncoding()` unit swap (`rust.md` §7, §12; `go.md` §7, §12; `js-ts.md` §11).
Rust's "contents … will be discarded … data loss" is rejected by keeping the
buffer owned and drained deterministically (`rust.md` §11).

---

### `BufferedWriter`

Status: implemented

Signature:

```mojo
struct BufferedWriter[W: Sink, capacity: Int = 4096](ByteWriter):
    var _inner: Self.W
    var _buf: Array[UInt8, Self.capacity]
    var _len: Int

    def __init__(out self, var inner: Self.W)
    def write(mut self, data: Span[UInt8, _]) raises IoError -> Int
    def flush(mut self) raises IoError
    def close(mut self) raises IoError
```

(where `comptime Sink = ByteWriter & Movable & Deinitable`; `write_all` is the
provided method inherited from `ByteWriter` and is **not** re-declared.)

Semantics:

- **Parameters / preconditions:** wraps any `ByteWriter`; `capacity` is a
  compile-time value parameter (default 4096).
- **Return / meaning:** `write` appends into the buffer and flushes when full;
  it returns the number of bytes accepted. `flush` writes the buffered bytes to
  `_inner` and calls `_inner.flush`; it is explicit and fallible. `close` flushes
  **and** marks the writer closed so later calls raise `CLOSED`; it is idempotent.
- **Ownership:** owns its inline buffer and inner writer.
- **Terminal call / data-loss rule:** `flush` (or `close`) is the **terminal,
  explicit** call. There is **no destructor flush**. Dropping a `BufferedWriter`
  with unflushed bytes is a **documented, accepted loss** — the buffer cannot be
  silently discarded *as if flushed*, and the type never reports success it did
  not achieve. This is the honest trade: Mojo has no error-reporting destructor,
  so the choice is (a) require an explicit fallible `flush`/`close` and document
  the drop as lossy, rather than (b) Rust's `Drop` flush that pretends to flush
  and swallows the error (`rust.md` §11). The precise distinction from
  `BufferedReader` is not "read vs write" but **owned-and-drained while live**:
  `BufferedReader` serves its buffered bytes deterministically through `read`,
  so no read data is silently dropped by a normal use; a `BufferedWriter` that is
  dropped before its terminal call has written nothing further and reports
  nothing — the loss is the caller's, at the terminal call. Both adapters, then,
  behave the same way: the buffer belongs to the value, and a terminal call
  (`read` drains / `flush` writes) is what makes the data observable.
- **Close behavior:** `close` flushes and marks the writer closed (idempotent);
  after it, `write`/`flush` raise `CLOSED`. On drop without `close`/`flush` the
  buffer is released (accepted loss; see the Terminal-call rule).
- **Stream I/O:** `INTERRUPTED` is retried on flush; `WOULD_BLOCK` surfaced.

Errors: `raises IoError` — from `_inner`; `OTHER` ("write zero"); `CLOSED` from
`write`/`flush` after `close`.

Tests:

- `test_io_buffered_writer.mojo`
  - `test_buffered_writer_flushes_when_full`
  - `test_buffered_writer_flush_writes_to_inner`
  - `test_buffered_writer_flush_reports_inner_error`
  - `test_buffered_writer_close_flushes_and_marks_closed`
  - `test_buffered_writer_close_is_idempotent`
  - `test_buffered_writer_after_close_raises_closed`

Implementation status: implemented

Rationale: MojoAkku uses an **explicit, fallible `flush`/`close` and no destructor
flush** because Rust's `BufWriter` `Drop` "attempt[s] to flush … any errors …
will be ignored" is a documented footgun, while Go's `bufio.Writer.Flush` is
explicit (`rust.md` §11; `go.md` §11). The drop-without-flush case is documented
as an accepted loss rather than hidden (see the Terminal-call rule above). The
buffered struct mirrors `BufferedReader` (`rust.md` §7, §12). A stored inner
writer needs the `Movable & Deinitable` bound (`Self.W` in the field), verified
against Mojo 1.x (`mojov1/functions/parameters-and-generics`).

---

### `LimitReader`

Status: implemented

Signature:

```mojo
struct LimitReader[R: Stream](Reader):
    var _inner: Self.R
    var _remaining: Int

    def __init__(out self, var inner: Self.R, limit: Int)
    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
```

Semantics:

- **Parameters / preconditions:** `limit` is the maximum total bytes this reader
  will ever return; a negative `limit` is a caller programming error and is
  **defined to behave as `limit = 0`** (the reader immediately reports EOF),
  consistent with the total-function style used elsewhere in MojoAkku — not a
  trap.
- **Return / meaning:** reads from `_inner` but never beyond `_remaining`. The
  call that returns the last permitted bytes reports that count with
  `eof = False`; only the **next** read (when no bytes remain) reports
  `{0, eof: True}` without touching `_inner` again.
- **Ownership:** owns `_inner`; `limit` is a plain `Int`.
- **Close behavior:** no `close` (value type); delegates no close to `_inner`.
- **Stream I/O:** as `_inner`.

Errors: `raises IoError` — as `_inner`.

Tests:

- `test_io_limit_reader.mojo`
  - `test_limit_reader_reads_at_most_limit`
  - `test_limit_reader_exhausted_reports_eof`
  - `test_limit_reader_negative_limit_behaves_as_zero`
  - `test_limit_reader_never_touches_inner_after_limit`

Implementation status: implemented

Rationale: MojoAkku uses a composable `LimitReader` because Go's
`io.LimitReader` shows a byte cap is a small, reusable wrapper over any reader
(`go.md` §3, §12).

---

### `TeeReader`

Status: implemented

Signature:

```mojo
struct TeeReader[R: Stream, W: Sink](Reader):
    var _inner: Self.R
    var _sink: Self.W

    def __init__(out self, var inner: Self.R, var sink: Self.W)
    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
```

Semantics:

- **Parameters / preconditions:** every byte read from `_inner` is also written
  to `_sink`.
- **Return / meaning:** returns the `ReadResult` from `_inner` after mirroring
  the bytes. If the sink write fails, the bytes are already in the caller's
  `buf` (the read from `_inner` succeeded) but the `ReadResult` is withheld: the
  call raises `IoError` from the `_sink` (`op == "write"`).
- **Ownership:** owns both `_inner` and `_sink`; `buf` borrowed.
- **Close behavior:** no `close` (value type); no close is delegated.
- **Stream I/O:** as `_inner`; sink errors surface.

Errors: `raises IoError` — from `_inner` or `_sink`.

Tests:

- `test_io_tee_reader.mojo`
  - `test_tee_reader_mirrors_read_bytes_to_sink`
  - `test_tee_reader_returns_inner_read_result`
  - `test_tee_reader_sink_error_surfaces`
  - `test_tee_reader_inner_error_surfaces`

Implementation status: implemented

Rationale: MojoAkku uses a composable `TeeReader` because Go's `io.TeeReader`
shows read-mirroring is a small wrapper, useful for hashing/logging as a stream
is consumed (`go.md` §3, §12).

---

### `MultiReader`

Status: implemented

Signature:

```mojo
struct MultiReader[R: Stream](Reader):
    var _readers: List[Self.R]
    var _index: Int

    def __init__(out self, var *readers: Self.R)
    def read(mut self, buf: MutSpan[UInt8, _]) raises IoError -> ReadResult
```

Semantics:

- **Parameters / preconditions:** constructed from one or more readers; the
  constructor is variadic (`MultiReader(r1, r2, r3)`) but the readers are
  **homogeneous** (all the same type `R`) and are moved into a `List[Self.R]`,
  so the count is a runtime value and there is no boxing. The pack parameter is
  `var *readers` (an owned transfer) because a `Movable`-but-not-`Copyable`
  reader cannot be copied into the list. A heterogeneous set of readers is out of
  scope for the first release (it would need `Variant`).
  (The `List`-backed form was verified to compile; a variadic type-pack stored
  directly in a `Tuple` does **not** compile in Mojo 1.x and is rejected. The
  `List[Self.R](*readers^, __list_literal__=None)` construction relies on the
  internal `__list_literal__` keyword — a documented `MissingMojo` `UnstableAPI`
  workaround carried in `multi_reader.mojo`.)
- **Return / meaning:** reads from the current reader; when it reports `eof`,
  advances `_index` to the next and retries; reports `{0, eof: True}` only after
  the last reader ends.
- **Ownership:** owns all readers (`List` storage); `buf` borrowed.
- **Close behavior:** no `close` (value type); no close is delegated.
- **Stream I/O:** as the active reader.

Errors: `raises IoError` — from the active reader.

Tests:

- `test_io_multi_reader.mojo`
  - `test_multi_reader_concatenates_in_order`
  - `test_multi_reader_advances_on_inner_eof`
  - `test_multi_reader_eof_only_after_last_reader`
  - `test_multi_reader_variadic_construct`
  - `test_multi_reader_active_reader_error_surfaces`

Implementation status: implemented

Rationale: MojoAkku uses a `MultiReader` because Go's `io.MultiReader` shows
concatenation is a core composition (`go.md` §3, §12). Storage is a
`List[Self.R]` (a verified Mojo 1.x shape) rather than a variadic type-pack
`Tuple[*Rs]`, because the pack-to-`Tuple` conversion does not compile; the
homogeneous `R` bound still allows any single reader type, and Go's own
`MultiReader` takes a plain `...Reader` slice (`go.md` §3).

---

### `copy`

Status: implemented

Signature:

```mojo
def copy[R: Stream, W: Sink](mut reader: R, mut writer: W) raises IoError -> Int
```

Semantics:

- **Parameters / preconditions:** both arguments are mutable references; the
  reader is drained into the writer.
- **Return / meaning:** the total number of bytes copied, until the reader
  reports `eof`. Short reads/writes are handled internally (loop until done).
  When it raises mid-copy, the count of bytes **already written** is **not**
  returned (the error propagates instead); a caller who needs the partial
  progress compares the writer's observed length before and after, or drives the
  loop with `read`/`write` directly. This mirrors Go's `Copy` returning
  `(written, err)` in spirit while keeping the success return type simple
  (`go.md` §4, §9).
- **Ownership:** borrows both stream handles for the call; allocates only its own
  small internal transfer buffer.
- **Close behavior:** no `close` (free function); `CLOSED` surfaces if a stream's
  underlying handle is closed.
- **Stream I/O:** retries `INTERRUPTED`; surfaces other errors with `op` naming
  which side failed.

Errors: `raises IoError` — from either side. Partial progress is not returned;
see the return rule above.

Tests:

- `test_io_copy.mojo`
  - `test_copy_pumps_until_eof`
  - `test_copy_returns_total_bytes`
  - `test_copy_handles_short_reads_and_writes`
  - `test_copy_retries_interrupted`
  - `test_copy_does_not_retry_would_block`
  - `test_copy_partial_progress_writer_keeps_first_chunk`
  - `test_copy_error_op_names_failing_side`

Implementation status: implemented

Rationale: MojoAkku uses a free generic `copy` because Go's `io.Copy` and
Rust's `io::copy` both express the pump as a function over the traits, keeping
the traits minimal; Mojo's generics can specialize the transfer for known stream
types at compile time, replacing Go's runtime `ReaderFrom`/`WriterTo` duck-typing
(`go.md` §3, §12; `rust.md` §12). Go's partial `(written, err)` return is
deliberately simplified to a success-only `Int`; the partial-loss rule is
documented rather than hidden (`go.md` §4).

## Error Surface

There is exactly **one** error type: `IoError`, declared with `raises IoError`
on every fallible stream operation. It carries:

| Field | Type | Meaning |
| --- | --- | --- |
| `kind` | `IoErrorKind` | `INTERRUPTED`, `WOULD_BLOCK`, `CLOSED`, `TIMED_OUT`, `INVALID_UTF8`, `UNEXPECTED_EOF` or `OTHER`. |
| `op` | `String` | Short operation name (`"read"`, `"write"`, `"flush"`, `"seek"`). |
| `detail` | `String` | Opaque, human-readable context (never parsed). |

Which API can raise:

| API | Raises | Kinds |
| --- | --- | --- |
| `Reader.read` | yes | any |
| `Reader.read_exact` | yes | any; `UNEXPECTED_EOF` on premature EOF |
| `Reader.read_to_end` | yes | any |
| `ByteWriter.write` | yes | any (a short return is not an error) |
| `ByteWriter.write_all` | yes | any; `OTHER` on zero-write |
| `ByteWriter.flush` | yes | any |
| `Seeker.seek` | yes | `OTHER` (incl. non-seekable), `CLOSED` |
| `Cursor.*`, `SpanCursor.*`, `BufferedReader.*`, `BufferedWriter.*`, `LimitReader.*`, `TeeReader.*`, `MultiReader.*` | yes | as the wrapped trait method |
| `copy` | yes | any |

Rules:

- **One error type per function.** Mojo allows at most one error type per
  signature; `IoError` is it.
- **EOF is not an error.** It is `ReadResult.eof`. A `raises` path never means
  "the stream ended normally".
- **Recoverable vs not.** Most kinds are transient and recoverable: retry
  (`INTERRUPTED`/`WOULD_BLOCK`), reopen (`CLOSED`), adjust the deadline
  (`TIMED_OUT`), re-encode (`INVALID_UTF8`). `UNEXPECTED_EOF` is **lossy** (the
  consumed prefix of an exact read is gone) but not fatal. No condition is fatal
  to the process.
- **Partial progress.** A raising operation does not return its partial count:
  `read_to_end` and `copy` lose the bytes/`List` accumulated before the raise.
  A caller who needs partial progress uses `read` into a caller-owned
  `MutSpan[UInt8, _]` (which accumulates the bytes in that caller-owned buffer)
  or drives the loop directly (`rust.md` §4; `go.md` §4). For `read_to_end` the
  `List` is a local, so the accumulated bytes are unreachable after the raise:
  this loss is consciously accepted and **not separately testable** (the value
  cannot be observed). For `copy`, the partial progress *is* observable in the
  writer and is covered by `test_copy_partial_progress_writer_keeps_first_chunk`.
- **No OS errno leak.** `detail` may contain an OS message, but the *kind* is the
  closed set; callers branch on `kind`, never on strings (`rust.md` §11).
- **Diagnostics.** `IoError` implements `Writable`, so `print(e)` yields a
  readable message including the kind, the operation and the detail.

## Conventions

These are the rules every entry in this document follows, and the rules every
sibling MojoAkku library copies.

- **One entry per public API member, in design order.** Names are stable; the
  `## Public API` list and the `## Semantics` entries are in the same order.
- **Identical field names and order in every entry.** Each entry uses exactly:
  `Status:`, `Signature:`, `Semantics:`, `Errors:`, `Tests:`,
  `Implementation status:`, `Rationale:`. No field is omitted, even when its
  value is `none` or empty.
- **Signature is the exact Mojo declaration.** It is copied verbatim by Phase 7.
- **Semantics is complete.** It covers parameters/preconditions,
  return/meaning, ownership, and the stream-I/O / flush contract as applicable.
- **Errors names every raised error and says whether it is recoverable.** Pure
  functions say `none`.
- **Tests names the test file that covers the entry and its planned
  test-function names.** Present for every entry; the field is never removed.
- **Rationale is a `MojoAkku uses X because Y` statement** naming the reference
  API and its research section.
- **Status and implementation status are honest.** All entries were `planned` /
  `not implemented` from Phase 3 through Phase 10, and are `implemented` from
  Phase 11/12.
- **Terminology is shared.** Stream, short read, EOF and buffer borrow are
  defined once in `## Semantics ## Terminology`.
- **Markdown tables use `|`.** Sources are cited as `<lang>.md §<section>`.

## Ownership and Lifecycle

**Borrowed buffers, owned streams.** Every read target is `MutSpan[UInt8, _]` and
every write input is `Span[UInt8, _]`; the library borrows the buffer for the
call only, never copies or retains it, and the stream owns its own cursor/buffer.
This makes Go's "Implementations must not retain p" and C's unenforceable
`restrict` into a compiler-checked rule (`go.md` §5; `c.md` §5, §11). A bare
`Span` is `imm` and cannot be written through, which is why read destinations
must be `MutSpan` (`mojov1/types/collections`).

**Adapter ownership.** `BufferedReader`/`BufferedWriter` own an inline
fixed-size `Array` plus their inner stream; `LimitReader`/`TeeReader`/
`MultiReader` own their inner stream(s). All are **value-semantics structs**; no
hidden global state, so two threads/fibers using separate streams share nothing
(`rust.md` §7, §12).

**Explicit terminal calls.** `BufferedWriter.flush` is the terminal write call;
it is explicit and fallible. No destructor performs a silent flush, because
Rust's `Drop` flush discards errors (`rust.md` §11).

**No hidden global state.** There are no mutable globals: error kinds and buffer
capacities are `comptime` constants/parameters.

**Pure Mojo.** The design uses only `Span`, `StringSpan`, `String`, `List`,
`Array`, `Bool`, `Int`, `UInt8`, `comptime` parameters and typed `raises`. It
requires no Python interpreter, no `unsafe_*` in the public surface, and no C
dependency. `unsafe_ptr` would only appear in a caller's own construction of a
`Span` over foreign memory, never inside this library (`mojov1/types/collections`).

**Lifecycle summary.**

| API | Consumes input? | Owns output? | Can be abandoned? |
| --- | --- | --- | --- |
| `Reader.read` / `ByteWriter.write` | no (borrow buffer) | no (writes into caller buffer) | yes (ordinary return) |
| `Reader.read_to_end` | no (borrow) | caller owns `List` | yes |
| `BufferedWriter.flush` | no (borrow) | no | **no** — the terminal call |
| `Cursor` / adapters | own inner stream(s) | own inner state | yes (value semantics) |

## Open Questions

Most decisions are closed against the reviewed research and the `mojov1` buch.
The items below are the remaining open points; each is **consciously accepted**
for release 1 (deferred with a written reason), so none blocks the Phase-4
approval.

**Closed (decided in the Phase-4 rework)**

- **Non-seekable stream → `OTHER`, not `CLOSED`.** `CLOSED` is reserved for a
  closed handle; a dedicated `NOT_SEEKABLE` kind is not added (keeps the set
  closed and small; additive later if proven). See `Seeker`.
- **`Cursor` vs `SpanCursor` are two types.** A struct field has one concrete
  type, so the owned and borrowed forms cannot share one type; the split makes
  "read-only" a type-level property. See `Cursor`.
- **`MultiReader` is `List`-backed and homogeneous** (`MultiReader[R: Stream]`,
  readers appended into a `List[Self.R]`), verified to compile; the variadic
  type-pack→`Tuple` form does **not** compile and is rejected; heterogeneous
  readers are out of scope.

**Open**

- **`ReadResult` construction ergonomics.** Whether the implementation should
  expose a `comptime ReadResult.eof()` / `.data(count)` constructor pair for
  readability is deferred to Phase 7; it affects only construction, not the
  public shape.
- **Text adapter scope.** A text `Reader`/`TextReader` (byte → UTF-8 decode) is
  deliberately **not** in release 1 (the `INVALID_UTF8` kind reserves the place;
  see `## Non-Goals`). **Resolved for release 1: bytes only.** Whether a future
  text layer lives here or in the sibling `string`/`unicode` libraries is a
  separate, later decision — not a blocker for this design.
- **Timeout representation.** A per-operation `timeout: Optional[...]` is
  recorded as the intended direction (`rust.md` §12; `go.md` §11) but no timeout
  argument is in the first-release signatures; `TIMED_OUT` reserves the kind.
  Whether to add the argument now or in a follow-up is deferred.

**Closed**

- `Reader`/`ByteWriter` as one-required-method traits with provided helpers.
- `ReadResult { count, eof }` as the explicit EOF representation (no sentinel);
  `count = 0, eof = False` is not part of the contract.
- `IoErrorKind` as a closed seven-value discriminant (incl. `UNEXPECTED_EOF`);
  no OS errno leak.
- Read targets are `MutSpan[UInt8, _]`, write inputs `Span[UInt8, _]`; owned
  streams. (`Span` alone is `imm` and cannot be a write destination.)
- Explicit, fallible `BufferedWriter.flush`; no destructor flush.
- Compile-time buffer capacity via value parameters.
- Blocking, synchronous core; no `async`/`await` (unstable, non-goal today).
- The Mojo side (stdlib `io`) provides `Writer`/`Writable` and no `Reader`; the
  `ByteWriter` name avoids the collision.
- No dependency edge to any sibling library.
