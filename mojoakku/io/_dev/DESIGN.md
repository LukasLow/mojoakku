<!--
Design record for mojoakku/io — NOT end-user documentation.
End-user documentation lives inline in the `*.mojo` files (the `# API-DOCS`
blocks) and in `__init__.mojo`. This file keeps the developer-facing reasoning:
status bookkeeping, tests, rationale, reference-API comparisons, non-goals and
open questions. It reflects the state after Phase 3 (API design; **approved by
the user**; pending the Phase-4 design review).
-->

# io — Design Record

## Purpose

`mojoakku/io` is the single source of truth for the MojoAkku `io` library — the
**byte and text stream layer** that every later networking library
(`socket` → `tcp` → `http`) sits on. It defines the public API, the full
semantics of every entry, the error surface, the ownership and lifecycle rules,
and the conventions that the sibling libraries copy.

It is designed for a low-vision user: one naming scheme, one option model, one
typed error, borrowed input, owned output, and an **explicit EOF outcome** that
cannot be confused with a short read or a failure.

The Mojo standard library already covers console I/O, files and the **write**
traits (`Writer`/`Writable`) — see `mojov1/stdlib/io` — but it has **no `Reader`
trait and no generic byte/text stream abstraction**. That gap is this library's
reason to exist; the write side is the stdlib-first case (wrap/extend).

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 14 entries in this document are `planned` after Phase 3, and every entry's
`Implementation status:` is `not implemented`.

## Dependencies

`io` has **no dependency edge to any sibling MojoAkku library**. It is a leaf in
the dependency graph: it depends only on the Mojo standard library.

| Library | Edge | Justification |
| --- | --- | --- |
| (none) | — | The stream abstractions are pure in-process transforms over `Span[UInt8]`, `String`, `List` and `Int`. No signature mentions a socket, file, buffer, URL or other sibling concept, so no sibling edge can be technically justified. |

- **Why a leaf.** A dependency edge exists only when a library needs another
  library's public types or functions. `io` needs none: every parameter and
  return type comes from the Mojo standard library. Adding an edge would create
  coupling without a technical reason, which the dependency rules forbid.
- **No physical nesting.** `mojoakku/io/` is a flat sibling under `mojoakku/`.
- **The stdlib `Writer`/`Writable` relationship.** MojoAkku `io` does **not**
  reimplement the stdlib's text-formatting `Writer`/`Writable` traits; it is the
  **byte** layer plus the missing **read** side, and it may *extend* the write
  story with a byte-oriented `ByteWriter`. Where the stdlib already provides the
  concept, MojoAkku wraps; where it is silent (Reader, buffering, adapters),
  MojoAkku extends. This is recorded per API block under `Rationale`.
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
- **Borrowed buffers**: the caller owns the read/write buffer as a
  `mut Span[UInt8]`; the library never retains it.
- **Value-semantics adapters** (`Cursor`, `BufferedReader`, `BufferedWriter`,
  `LimitReader`, `TeeReader`, `MultiReader`) that compose over the traits, with
  compile-time buffer sizing.
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

4. **Borrowed buffers, owned output.** Read/write take the caller's
   `mut Span[UInt8]`; the library never retains or allocates the buffer. This
   makes C's "implementations must not retain p" a compiler-checked rule
   (`go.md` §5, §12; `c.md` §5).

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
  by making leftover buffered bytes impossible to lose (`rust.md` §11).
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
  easy to leave stale; a timeout is a per-operation value (`go.md` §11;
  `java.md` §11).
- **Async/await in the core.** MojoAkku rejects pulling `async`/`await` into the
  stream surface because Mojo's `async` is documented unstable and listed as a
  non-goal today; the core is blocking and synchronous (`java.md` §12;
  `mojov1/concurrency/async-and-parallelism`, `mojov1/keyword-conventions/async-await`).

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| Minimal one-method reader trait | Go `io.Reader` (`Read(p []byte) (n int, err error)`); Rust `Read::read`; Mojo stdlib `Writer` (one required method) | `go.md` §3; `rust.md` §3; `mojov1/stdlib/io` |
| Minimal one-method writer trait | Go `io.Writer`; Rust `Write::write`; Mojo `Writer.write_string` | `go.md` §3; `rust.md` §3; `mojov1/stdlib/io` |
| Explicit result vs sentinel | Java `-1` in `int`; JS `null`; Rust `Ok(0)`; C `EOF`+`feof`/`ferror`; Python `bytes|None|b''` | `java.md` §9; `js-ts.md` §9; `rust.md` §9; `c.md` §9; `python.md` §9 |
| Closed error taxonomy | Rust `ErrorKind` (`#[non_exhaustive]`, ~45 variants); Go sentinels; Java checked `IOException`; cppcodec `parse_error`/`symbol_error` | `rust.md` §4; `go.md` §4; `java.md` §4; `cpp.md` §4 |
| Borrowed buffer, no retention | Go "Implementations must not retain p"; Rust `&mut [u8]`; C `restrict` (unenforceable) | `go.md` §5; `rust.md` §5; `c.md` §5 |
| Buffered wrapper as a value struct | Rust `BufReader<R>`/`BufWriter<W>`; Go `bufio.Reader` (buffer + ints) | `rust.md` §7, §12; `go.md` §7, §12 |
| Zero-copy borrow window | Rust `BufRead::fill_buf`/`consume`; Go `bufio.Peek`/`ReadSlice` | `rust.md` §12; `go.md` §12 |
| In-memory cursor | Rust `Cursor<T>`; Go `bytes.Reader`; C `open_memstream` | `rust.md` §3; `go.md` §3; `c.md` §3 |
| Limit / tee / multi adapters | Go `io.LimitReader`, `io.TeeReader`, `io.MultiReader` | `go.md` §3, §12 |
| Copy pump | Go `io.Copy`; Rust `io::copy` (specialized) | `go.md` §3; `rust.md` §12 |
| Seek | Rust `Seek::seek`/`SeekFrom`; Go `io.Seeker`; C `fseek`/`SEEK_*` | `rust.md` §3; `go.md` §3; `c.md` §3 |
| Explicit fallible flush | Rust `Write::flush`/`BufWriter::into_inner`; Go `bufio.Writer.Flush` | `rust.md` §11; `go.md` §11 |
| Compile-time buffer size | Mojo `comptime` value parameters; `basic_spanbuf` fixed buffer | `mojov1/functions/parameters-and-generics`; `cpp.md` §12 |
| Mojo language anchors | `Span`/`StringSpan` borrowed views; `List`/`String` owned; `comptime` value parameters; typed `raises`; `mut self`; `with` | `mojov1/types/collections`; `mojov1/functions/parameters-and-generics`; `mojov1/errors/error-model`; `mojov1/keywords/with` |

## Public API

Every entry below is listed here with its one-line meaning and is fully
specified in `## Semantics`. Names are stable: Phase 5 documents them and
Phase 7 stubs them, in this order.

**Option, error and result types**

1. `IoErrorKind` — compile-time discriminant for `IoError`: `INTERRUPTED`,
   `WOULD_BLOCK`, `CLOSED`, `TIMED_OUT`, `INVALID_UTF8`, `OTHER`.
2. `IoError` — the one typed error: `kind: IoErrorKind`, `op: String`,
   `detail: String`.
3. `ReadResult` — explicit read outcome: `count: Int`, `eof: Bool`.
4. `SeekFrom` — where a seek starts: `START`, `CURRENT`, `END` with an `Int`
   offset.

**Traits**

5. `Reader` — one required `read(mut self, buf: Span[UInt8]) raises IoError ->
   ReadResult`; provided `read_exact`, `read_to_end`.
6. `ByteWriter` — one required `write(mut self, data: Span[UInt8]) raises
   IoError -> Int`; provided `write_all`, `flush`.
7. `Seeker` — one required `seek(mut self, from: SeekFrom) raises IoError ->
   Int`.

**Adapters and functions**

8. `Cursor` — in-memory reader+writer over a caller-provided buffer.
9. `BufferedReader[R: Reader]` — buffered wrapper with an inline,
   compile-time-sized buffer.
10. `BufferedWriter[W: ByteWriter]` — buffered wrapper with an explicit,
    fallible `flush`.
11. `LimitReader[R: Reader]` — reads at most `n` bytes.
12. `TeeReader[R: Reader, W: ByteWriter]` — mirrors everything read into a
    writer.
13. `MultiReader[*Rs: Reader]` — concatenates readers.
14. `copy` — pumps a reader into a writer until EOF.

## Semantics

#### Terminology

- **Stream** — a `Reader`, `ByteWriter` or `Seeker` implementation.
- **Short read** — a `read` that fills fewer bytes than the buffer holds; it is
  normal and is **not** EOF and **not** an error.
- **EOF** — the end of the input; reported as `ReadResult { count, eof: True }`,
  never as an error and never as a magic `-1`/`0`/`null`.
- **Buffer borrow** — the caller's `mut Span[UInt8]` is borrowed for the call
  only; the library must not retain it.

All lengths are in bytes/symbols, not codepoints. All inputs are treated as raw
bytes; the library never performs UTF-8 conversion unless an explicit text
adapter does so.

---

### `IoErrorKind`

Status: planned

Signature:

```mojo
struct IoErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    comptime INTERRUPTED   = IoErrorKind(0)
    comptime WOULD_BLOCK   = IoErrorKind(1)
    comptime CLOSED        = IoErrorKind(2)
    comptime TIMED_OUT     = IoErrorKind(3)
    comptime INVALID_UTF8  = IoErrorKind(4)
    comptime OTHER         = IoErrorKind(5)

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `IoError.kind`; never passed by a
  caller to a stream. The type is **opaque**: the six `comptime` members are the
  complete public set; `_id` and its `@doc_hidden` initializer are
  implementation details (Mojo has no access control; `mojov1/decorators/doc-hidden`).
- **Return / meaning:** the machine-testable reason for a stream failure.
  `INTERRUPTED` — the operation was interrupted and may be retried;
  `WOULD_BLOCK` — the operation would block (non-blocking handle);
  `CLOSED` — the stream or its underlying handle is closed;
  `TIMED_OUT` — a deadline expired; `INVALID_UTF8` — a text adapter saw invalid
  UTF-8; `OTHER` — any other condition (the opaque `IoError.detail` carries it).
- **Ownership:** value type; compile-time constants copied into the error value.
- **Stream I/O:** not applicable.

Errors: none.

Tests:

- `test_io_error.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a **closed** six-value discriminant because Rust's
`#[non_exhaustive]` `ErrorKind` with ~45 OS-derived variants is explicitly
"intended to grow over time" and forces wildcard matches, leaking platform
detail (`rust.md` §4, §11); Go's sentinel errors compared with `==` and Java's
checked-exception hierarchy are rejected for the same reason (`go.md` §4;
`java.md` §4). The set matches the *stream outcomes* a caller can act on, not OS
errno categories.

---

### `IoError`

Status: planned

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

Errors: it **is** the error. All stream failures are recoverable data errors:
the caller may retry (`INTERRUPTED`/`WOULD_BLOCK`), reopen (`CLOSED`), or
re-encode (`INVALID_UTF8`). No condition is fatal or unrecoverable.

Tests:

- `test_io_error.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a struct with `kind`+`op`+`detail` because Rust's
`io::Error` carries a kind plus context and cppcodec's `symbol_error` shows the
operation must be named, while Java's checked `IOException` and Go's
`(n, err)`-both-populated return show how *not* to type the failure
(`rust.md` §4; `cpp.md` §4; `java.md` §4, §11; `go.md` §11).

---

### `ReadResult`

Status: planned

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
  A `count = 0, eof = False` result is **discouraged** (see Errors): an
  implementation must not spin returning "nothing happened"
  (`go.md` §11).
- **Ownership:** value type; returned by value, owned by the caller.
- **Stream I/O:** the type *is* the EOF representation.

Errors: none (it is a value). The `count = 0, eof = False` state is legal but
discouraged; an implementation that would produce it must instead make progress
or set `eof`, because Go's documented "nothing happened" state forced
`ErrNoProgress` heuristics (`go.md` §9, §11).

Tests:

- `test_io_reader.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses an explicit `{count, eof}` result because Java's in-band
`-1`, JS's `null`, Rust's `Ok(0)`-as-EOF-or-empty, C's `EOF`+`feof`/`ferror` and
Python's `bytes|None|b''` all conflate data, end and error in one value
(`java.md` §9, §11; `js-ts.md` §9; `rust.md` §9; `c.md` §9; `python.md` §9).
C++'s separate `gcount()` query is rejected because it is reset by
`putback`/`unget`/`peek` (`cpp.md` §12).

---

### `SeekFrom`

Status: planned

Signature:

```mojo
struct SeekFrom(Equatable, ImplicitlyCopyable, Deinitable):
    var _id: UInt8
    var offset: Int

    @doc_hidden
    def __init__(out self, id: UInt8, offset: Int)

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
  signed so `end(-1)` is expressible.
- **Ownership:** value type; copied by value.
- **Stream I/O:** the seek *origin*; the resulting position is returned by
  `Seeker.seek` as an `Int`.

Errors: none.

Tests:

- `test_io_seek.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a named origin plus a signed offset because C's
`fseek`/`SEEK_*`, Go's `io.Seeker` and Rust's `SeekFrom` all take exactly an
origin plus an offset, and this is the smallest complete shape (`c.md` §3;
`go.md` §3; `rust.md` §3).

---

### `Reader`

Status: planned

Signature:

```mojo
trait Reader:
    def read(mut self, buf: Span[UInt8]) raises IoError -> ReadResult: ...

    def read_exact(mut self, buf: Span[UInt8]) raises IoError
    def read_to_end(mut self) raises IoError -> List[UInt8]
```

Semantics:

- **Parameters / preconditions:** `buf` is the caller-owned destination, borrowed
  mutably for the call only. The implementation writes at most `len(buf)` bytes
  and must **not** touch bytes outside the region it reports in `count`
  (rejecting Go's "may use all of p as scratch space", `go.md` §11).
- **Return / meaning:** `read` returns a `ReadResult`; a **short read is normal**
  and is neither EOF nor an error (`rust.md` §9; `python.md` §9). `read_exact`
  fills `buf` completely or raises `IoError` (kind `OTHER`, "unexpected EOF") if
  the stream ends first — Rust's `UnexpectedEof`, the explicit form rather than
  Java's `EOFException`. `read_to_end` reads until `eof`, appending to a fresh
  `List[UInt8]` and returning it.
- **Ownership:** `mut self` — the reader owns its own cursor; the buffer is
  borrowed and never retained. `read_to_end` returns an owned `List[UInt8]`.
- **Stream I/O / interruption:** on `INTERRUPTED` the caller may retry the same
  call; the provided `read_exact`/`read_to_end` retry `INTERRUPTED`
  internally — Rust's central retry policy, not a per-call-site decision
  (`rust.md` §12). `WOULD_BLOCK` is surfaced, not hidden.

Errors: `raises IoError` — `INTERRUPTED`, `WOULD_BLOCK`, `CLOSED`, `TIMED_OUT`,
`OTHER`. All recoverable.

Tests:

- `test_io_reader.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses **one required buffer method plus provided helpers**
because Go's `io.Reader` (one `Read`) and Rust's `Read` (one `read` with ~15
provided operations) are the minimal-contract lesson, and the Mojo stdlib's own
`Writer` already uses exactly this required-vs-provided split (`go.md` §3, §12;
`rust.md` §3, §12; `mojov1/stdlib/io`). It closes the gap named in `_dev/README.md`
("no `Reader` trait"). Go's `(n, err)` both-populated return is rejected
(`go.md` §11).

---

### `ByteWriter`

Status: planned

Signature:

```mojo
trait ByteWriter:
    def write(mut self, data: Span[UInt8]) raises IoError -> Int: ...

    def write_all(mut self, data: Span[UInt8]) raises IoError
    def flush(mut self) raises IoError
```

Semantics:

- **Parameters / preconditions:** `data` is borrowed immutably for the call.
  `write` accepts a prefix `0 <= n <= len(data)` and returns `n`.
- **Return / meaning:** `write` returns the number of bytes accepted; a short
  write is normal and is **not** an error. `write_all` loops until every byte is
  written or raises. `flush` pushes any buffered bytes to the underlying sink;
  it is **explicit and fallible** (see Rationale).
- **Ownership:** `mut self`; `data` borrowed and never retained.
- **Stream I/O / interruption:** `write_all` retries `INTERRUPTED`; `flush`
  reports errors instead of swallowing them.

Errors: `raises IoError`. `write`'s short return is not an error; `write_all`
raises `OTHER` ("write zero") if `write` returns `0` without error.

Tests:

- `test_io_byte_writer.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a **byte**-writer trait named `ByteWriter` (not
`Writer`) to avoid colliding with the stdlib's text `Writer`, and shapes it as
one required `write` plus provided `write_all`/`flush`, because Go's
`io.Writer` and Rust's `Write` are exactly this and the stdlib `Writer` uses the
same split (`go.md` §3; `rust.md` §3; `mojov1/stdlib/io`). `flush` is explicit
because Rust's `BufWriter` `Drop` flush "ignores" errors — a documented footgun
(`rust.md` §11).

---

### `Seeker`

Status: planned

Signature:

```mojo
trait Seeker:
    def seek(mut self, from: SeekFrom) raises IoError -> Int: ...
```

Semantics:

- **Parameters / preconditions:** `from` names the origin and offset (see
  `SeekFrom`).
- **Return / meaning:** the new absolute position from the start of the stream.
  A negative resulting position raises `IoError` (kind `OTHER`).
- **Ownership:** `mut self`; the reader/writer owns its position.
- **Stream I/O:** seeking past the end may be allowed (the resulting position is
  returned); behaviour on a non-seekable stream is a `CLOSED`/`OTHER` error.

Errors: `raises IoError` — `OTHER` for an invalid target, `CLOSED` on a
non-seekable/closed stream.

Tests:

- `test_io_seek.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a separate `Seeker` trait because Go's `io.Seeker`,
Rust's `Seek` and C's `fseek` are all *optional* capabilities kept apart from the
read/write traits, and folding seek into `Reader` would force every source to
implement it (`go.md` §3; `rust.md` §3; `c.md` §3).

---

### `Cursor`

Status: planned

Signature:

```mojo
struct Cursor(Reader, ByteWriter, Seeker):
    var _buffer: List[UInt8]
    var _pos: Int

    def __init__(out self, var buffer: List[UInt8])
    def __init__(out self, borrowed buffer: Span[UInt8])

    def read(mut self, buf: Span[UInt8]) raises IoError -> ReadResult
    def write(mut self, data: Span[UInt8]) raises IoError -> Int
    def seek(mut self, from: SeekFrom) raises IoError -> Int
```

Semantics:

- **Parameters / preconditions:** constructed either from an owned
  `List[UInt8]` (written by `write`) or from a borrowed `Span[UInt8]` (read-only
  view; `write` raises `OTHER`). `_pos` is the current cursor.
- **Return / meaning:** `read`/`write` move `_pos`; `read` at `_pos == length`
  returns `{0, eof: True}`.
- **Ownership:** owns its `List` in the owned form, borrows in the view form;
  the borrowed form proves the "does not own the underlying buffer" contract of
  C++ `basic_spanbuf` is compiler-checked (`cpp.md` §12).
- **Stream I/O:** in-memory; no descriptors.

Errors: `raises IoError` — `OTHER` when writing to a view-formed cursor or on an
out-of-range seek.

Tests:

- `test_io_cursor.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a `Cursor` over an owned-or-borrowed buffer because
Rust's `Cursor<T>`, Go's `bytes.Reader` and C's `open_memstream` all provide an
in-memory stream, and it is the simplest `Reader`/`ByteWriter`/`Seeker` triple
(`rust.md` §3; `go.md` §3; `c.md` §3).

---

### `BufferedReader`

Status: planned

Signature:

```mojo
struct BufferedReader[capacity: Int = 4096](Reader):
    var _inner: ...
    var _buf: Array[UInt8, capacity]
    var _start: Int
    var _end: Int

    def read(mut self, buf: Span[UInt8]) raises IoError -> ReadResult
```

Semantics:

- **Parameters / preconditions:** wraps any `Reader`; `capacity` is a
  compile-time value parameter with a default of 4096 bytes (Go's
  `defaultBufSize`, `go.md` §7).
- **Return / meaning:** serves reads from the internal buffer, refilling from
  `_inner` only when empty; a short read from `_inner` is normal. EOF is
  reported only when `_inner` reports EOF **and** the buffer is drained.
- **Ownership:** owns its inline `Array` buffer and its inner reader;
  value-semantics struct, no heap beyond the inner stream.
- **Stream I/O:** `INTERRUPTED` is retried on refill; `WOULD_BLOCK` is surfaced.

Errors: `raises IoError` — passed through from `_inner`; `OTHER` if `_inner`
reports a zero-length non-EOF read (`ErrNoProgress` analogue).

Tests:

- `test_io_buffered_reader.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a value-semantics wrapper with an inline,
compile-time-sized buffer because Rust's `BufReader<R>` (a buffer + inner) and
Go's `bufio.Reader` (a byte buffer + three ints) show buffering is a composable
struct, and the compile-time size removes Node's platform-dependent default and
its `setEncoding()` unit swap (`rust.md` §7, §12; `go.md` §7, §12; `js-ts.md` §11).
Rust's "contents … will be discarded … data loss" is rejected by keeping the
buffer owned and drained deterministically (`rust.md` §11).

---

### `BufferedWriter`

Status: planned

Signature:

```mojo
struct BufferedWriter[capacity: Int = 4096](ByteWriter):
    var _inner: ...
    var _buf: Array[UInt8, capacity]
    var _len: Int

    def write(mut self, data: Span[UInt8]) raises IoError -> Int
    def write_all(mut self, data: Span[UInt8]) raises IoError
    def flush(mut self) raises IoError
```

Semantics:

- **Parameters / preconditions:** wraps any `ByteWriter`; `capacity` is a
  compile-time value parameter (default 4096).
- **Return / meaning:** `write` appends into the buffer and flushes when full;
  it returns the number of bytes accepted. `flush` writes the buffered bytes to
  `_inner` and calls `_inner.flush`; it is explicit and fallible. There is **no
  destructor flush**.
- **Ownership:** owns its inline buffer and inner writer. A caller that forgets
  `flush` loses nothing silently **only if** the type is used with `with` /
  explicit close in the future file layer; in this pure layer `flush` is the
  documented terminal call and the buffer is dropped visibly (the type does not
  pretend to have flushed).
- **Stream I/O:** `INTERRUPTED` is retried on flush; `WOULD_BLOCK` surfaced.

Errors: `raises IoError` — from `_inner`; `OTHER` ("write zero").

Tests:

- `test_io_buffered_writer.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses an **explicit, fallible `flush` and no destructor
flush** because Rust's `BufWriter` `Drop` "attempt[s] to flush … any errors …
will be ignored" is a documented footgun, while Go's `bufio.Writer.Flush` is
explicit (`rust.md` §11; `go.md` §11). The buffered struct mirrors `BufferedReader`
(`rust.md` §7, §12).

---

### `LimitReader`

Status: planned

Signature:

```mojo
struct LimitReader[R: Reader](Reader):
    var _inner: R
    var _remaining: Int

    def __init__(out self, var inner: R, limit: Int)
    def read(mut self, buf: Span[UInt8]) raises IoError -> ReadResult
```

Semantics:

- **Parameters / preconditions:** `limit` is the maximum total bytes this reader
  will ever return; it must be `>= 0`.
- **Return / meaning:** reads from `_inner` but never beyond `_remaining`; when
  `_remaining` hits 0 it reports `{0, eof: True}` without touching `_inner`.
- **Ownership:** owns `_inner`; `limit` is a plain `Int`.
- **Stream I/O:** as `_inner`.

Errors: `raises IoError` — as `_inner`.

Tests:

- `test_io_limit_reader.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a composable `LimitReader` because Go's
`io.LimitReader` shows a byte cap is a small, reusable wrapper over any reader
(`go.md` §3, §12).

---

### `TeeReader`

Status: planned

Signature:

```mojo
struct TeeReader[R: Reader, W: ByteWriter](Reader):
    var _inner: R
    var _sink: W

    def __init__(out self, var inner: R, var sink: W)
    def read(mut self, buf: Span[UInt8]) raises IoError -> ReadResult
```

Semantics:

- **Parameters / preconditions:** every byte read from `_inner` is also written
  to `_sink`.
- **Return / meaning:** returns the `ReadResult` from `_inner` after mirroring
  the bytes; a sink write failure raises `IoError` (the read is not delivered).
- **Ownership:** owns both `_inner` and `_sink`; `buf` borrowed.
- **Stream I/O:** as `_inner`; sink errors surface.

Errors: `raises IoError` — from `_inner` or `_sink`.

Tests:

- `test_io_tee_reader.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a composable `TeeReader` because Go's `io.TeeReader`
shows read-mirroring is a small wrapper, useful for hashing/logging as a stream
is consumed (`go.md` §3, §12).

---

### `MultiReader`

Status: planned

Signature:

```mojo
struct MultiReader[*Rs: Reader](Reader):
    ...
    def read(mut self, buf: Span[UInt8]) raises IoError -> ReadResult
```

Semantics:

- **Parameters / preconditions:** holds an ordered sequence of readers; reads
  from the first, moving to the next when the current reports `eof`.
- **Return / meaning:** concatenates the readers' bytes; reports `{0, eof: True}`
  only after the last reader ends.
- **Ownership:** owns the readers; `buf` borrowed.
- **Stream I/O:** as the active reader.

Errors: `raises IoError` — from the active reader.

Tests:

- `test_io_multi_reader.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a variadic `MultiReader` because Go's `io.MultiReader`
shows concatenation is a core composition, and Mojo's variadic type parameters
express the homogeneous reader pack directly (`go.md` §3, §12;
`mojov1/functions/parameters-and-generics`).

---

### `copy`

Status: planned

Signature:

```mojo
def copy[R: Reader, W: ByteWriter](mut reader: R, mut writer: W) raises IoError -> Int
```

Semantics:

- **Parameters / preconditions:** both arguments are mutable references; the
  reader is drained into the writer.
- **Return / meaning:** the total number of bytes copied, until the reader
  reports `eof`. Short reads/writes are handled internally (loop until done).
- **Ownership:** borrows both stream handles for the call; allocates only its own
  small internal transfer buffer.
- **Stream I/O:** retries `INTERRUPTED`; surfaces other errors with `op` naming
  which side failed.

Errors: `raises IoError` — from either side.

Tests:

- `test_io_copy.mojo`

Implementation status: not implemented

Rationale: MojoAkku uses a free generic `copy` because Go's `io.Copy` and
Rust's `io::copy` both express the pump as a function over the traits, keeping
the traits minimal; Mojo's generics can specialize the transfer for known stream
types at compile time, replacing Go's runtime `ReaderFrom`/`WriterTo` duck-typing
(`go.md` §3, §12; `rust.md` §12).

## Error Surface

There is exactly **one** error type: `IoError`, declared with `raises IoError`
on every fallible stream operation. It carries:

| Field | Type | Meaning |
| --- | --- | --- |
| `kind` | `IoErrorKind` | `INTERRUPTED`, `WOULD_BLOCK`, `CLOSED`, `TIMED_OUT`, `INVALID_UTF8` or `OTHER`. |
| `op` | `String` | Short operation name (`"read"`, `"write"`, `"flush"`, `"seek"`). |
| `detail` | `String` | Opaque, human-readable context (never parsed). |

Which API can raise:

| API | Raises | Kinds |
| --- | --- | --- |
| `Reader.read` | yes | any |
| `Reader.read_exact` | yes | any; `OTHER` on premature EOF |
| `Reader.read_to_end` | yes | any |
| `ByteWriter.write` | yes | any (a short return is not an error) |
| `ByteWriter.write_all` | yes | any; `OTHER` on zero-write |
| `ByteWriter.flush` | yes | any |
| `Seeker.seek` | yes | `OTHER`, `CLOSED` |
| `Cursor.*`, `BufferedReader.*`, `BufferedWriter.*`, `LimitReader.*`, `TeeReader.*`, `MultiReader.*` | yes | as the wrapped trait method |
| `copy` | yes | any |

Rules:

- **One error type per function.** Mojo allows at most one error type per
  signature; `IoError` is it.
- **EOF is not an error.** It is `ReadResult.eof`. A `raises` path never means
  "the stream ended normally".
- **Recoverable vs not.** Every kind is a *data/stream* error and is
  recoverable: retry (`INTERRUPTED`/`WOULD_BLOCK`), reopen (`CLOSED`), adjust the
  deadline (`TIMED_OUT`), or change the decode (`INVALID_UTF8`). No condition is
  fatal.
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
- **Tests names the test file that covers the entry.** Present for every entry;
  the field is never removed.
- **Rationale is a `MojoAkku uses X because Y` statement** naming the reference
  API and its research section.
- **Status and implementation status are honest.** All entries are `planned` /
  `not implemented` after Phase 3.
- **Terminology is shared.** Stream, short read, EOF and buffer borrow are
  defined once in `## Semantics ## Terminology`.
- **Markdown tables use `|`.** Sources are cited as `<lang>.md §<section>`.

## Ownership and Lifecycle

**Borrowed buffers, owned streams.** Every read/write takes the caller's
`mut Span[UInt8]` by mutable reference and never copies or retains it; the stream
owns its own cursor/buffer. This makes Go's "Implementations must not retain p"
and C's unenforceable `restrict` into a compiler-checked rule (`go.md` §5;
`c.md` §5, §11).

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
The following remain genuinely open and must be answered or consciously accepted
before `NewLibPhase4DesignReview.md` can approve.

**Open**

- **`Seeker.seek` return value on a non-seekable stream.** The design says
  `CLOSED`/`OTHER`; whether a dedicated `NOT_SEEKABLE` kind is warranted (vs
  folding into `OTHER`) is deferred — folding keeps the closed set at six, and a
  caller who needs to branch can add a kind later without breaking the closed
  enum's *use* (a new member is additive). Decision needed in Phase 4/7.
- **`ReadResult` construction ergonomics.** Whether the implementation should
  expose a `comptime ReadResult.eof()` / `.data(count)` constructor pair for
  readability is deferred to Phase 7; it affects only construction, not the
  public shape.
- **`MultiReader` storage shape.** Whether `*Rs: Reader` (variadic parameters)
  is the right spelling, or a `List`-of-a-boxed-reader is needed for a runtime
  number of readers, is deferred. The variadic form is preferred (no boxing) and
  is what the brief selected; a heterogeneous/runtime count is out of scope for
  the first release.
- **Text adapter scope.** A text `Reader`/`TextReader` (byte → UTF-8 decode) is
  deliberately **not** in this first release (the `INVALID_UTF8` kind reserves
  the place). Whether the sibling `string`/`unicode` libraries should own text
  decoding instead is deferred to Phase 4.
- **Timeout representation.** A per-operation `timeout: Optional[...]` is
  recorded as the intended direction (`rust.md` §12; `go.md` §11) but no timeout
  argument is in the first-release signatures; `TIMED_OUT` reserves the kind.
  Whether to add the argument now or in a follow-up is deferred.

**Closed**

- `Reader`/`ByteWriter` as one-required-method traits with provided helpers.
- `ReadResult { count, eof }` as the explicit EOF representation (no sentinel).
- `IoErrorKind` as a closed six-value discriminant; no OS errno leak.
- Borrowed `mut Span[UInt8]` buffers; owned streams.
- Explicit, fallible `BufferedWriter.flush`; no destructor flush.
- Compile-time buffer capacity via value parameters.
- Blocking, synchronous core; no `async`/`await` (unstable, non-goal today).
- The Mojo side (stdlib `io`) provides `Writer`/`Writable` and no `Reader`; the
  `ByteWriter` name avoids the collision.
- No dependency edge to any sibling library.
