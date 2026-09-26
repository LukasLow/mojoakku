# io research: Rust

## 1. Standard library support

Rust's I/O lives in one module, **`std::io`**, re-exported from `core::io` + `alloc::io` to support `no_std` partially:

- `std::io` — "Traits, helpers, and type definitions for core I/O functionality. The most core part of this module is the `Read` and `Write` traits" (`rust-lang/rust:library/std/src/io/mod.rs`, module doc). It re-exports `BufRead`, `BufReader`, `BufWriter`, `Bytes`, `Chain`, `Cursor`, `Empty`, `Error`, `ErrorKind`, `IntoInnerError`, `LineWriter`, `Lines`, `Read`, `Repeat`, `Result`, `Seek`, `SeekFrom`, `Sink`, `Split`, `Take`, `Write`, `copy`, `empty`, `repeat`, `sink`, plus `IoSlice`/`IoSliceMut` and the std-only `PipeReader`/`PipeWriter`/`pipe`, stdio handles and `IsTerminal` (`std/src/io/mod.rs`, the `pub use` block).
- **`core::io`** holds the trait/type definitions so `no_std` can name them; it is still feature-gated (`#![unstable(feature = "core_io", issue = "154046")]`) at time of writing (`rust-lang/rust:library/core/src/io/mod.rs`, `core/src/io/error.rs`).
- **`alloc::io`** holds the allocation-dependent parts (`BufReader`/`BufWriter`/`read_to_string`/`copy`) (`rust-lang/rust:library/alloc/src/io/mod.rs`).
- **Text** is handled by the same module: `Read::read_to_string`, `BufRead::read_line`, `BufRead::lines`, and `std::io::read_to_string` free function (`alloc/src/io/read.rs`, `alloc/src/io/buf_read.rs`).
- **Concrete streams** live elsewhere but implement these traits: `std::fs::File`, `std::net::TcpStream`, `std::os::unix::net::UnixStream`, `std::process::ChildStdout`, and in-memory `Vec<u8>`, `&[u8]`, `Cursor<T>` (`std/src/io/mod.rs` doc examples; `std/src/net/tcp.rs` `impl Read for TcpStream`).
- Everything is standard library; Rust is dual MIT/Apache-2.0 (`rust-lang/rust` LICENSE-MIT / LICENSE-APACHE).

## 2. Relevant community libraries

- **`tokio`** (tokio-rs) — "An event-driven, non-blocking I/O platform for writing asynchronous I/O backed applications"; MIT license; current docs.rs version 1.53.1, dated 2026-07-20; owners `carllerche`, `Darksonn`, `github:tokio-rs:core` (`https://docs.rs/tokio/latest/tokio/io/trait.AsyncRead.html`, `https://raw.githubusercontent.com/tokio-rs/tokio/master/LICENSE`). Provides `AsyncRead`/`AsyncWrite`/`AsyncSeek`/`AsyncBufRead`, `BufReader`/`BufWriter`/`BufStream`, `ReadBuf`, `split`, `Take`/`Chain` async adapters (AsyncRead docs, "Implementors"/"Implementations on Foreign Types").
- **`bytes`** (tokio-rs) — "A utility library for working with bytes"; MIT; provides `Bytes`, `BytesMut`, `Buf`, `BufMut` (`https://github.com/tokio-rs/bytes`, README + license section). This is the zero-copy buffer type the async ecosystem builds on.
- **`futures`** (rust-lang) — the original async I/O traits (`futures::io::AsyncRead`); largely superseded by tokio's traits in practice, but the source of the `Poll`-based I/O model (Assessment: derived from tokio's AsyncRead doc "analogous to the std::io::Read trait, but integrates with the asynchronous task system").
- **`mio`** (tokio-rs) — low-level non-blocking/evented I/O (epoll/kqueue/IOCP) underlying tokio (`https://docs.rs/mio`; tokio lists `mio ^1.2.0` as a dependency, AsyncRead docs.rs dependency list).
- **`async-std`** — a competing async runtime with its own `io` traits; not the de-facto standard (Assessment: derived from the ecosystem split; it does not appear in tokio's dependency set).

(Assessment: unlike Go, Rust's std I/O is synchronous and complete for blocking use; async I/O is deliberately *out* of std and owned by the ecosystem — a clear layering separation.)

## 3. Exposed APIs

### Traits (`library/core/src/io/write.rs`, `library/alloc/src/io/read.rs`, `buf_read.rs`, `core/src/io/seek.rs`)

```rust
pub trait Read {
    fn read(&mut self, buf: &mut [u8]) -> Result<usize>;
    fn read_vectored(&mut self, bufs: &mut [IoSliceMut<'_>]) -> Result<usize>;
    fn is_read_vectored(&self) -> bool;                       // unstable
    fn read_to_end(&mut self, buf: &mut Vec<u8>) -> Result<usize>;
    fn read_to_string(&mut self, buf: &mut String) -> Result<usize>;
    fn read_exact(&mut self, buf: &mut [u8]) -> Result<()>;
    fn read_buf(&mut self, buf: BorrowedCursor<'_, u8>) -> Result<()>;   // unstable
    fn read_buf_exact(&mut self, cursor: BorrowedCursor<'_, u8>) -> Result<()>; // unstable
    fn by_ref(&mut self) -> &mut Self where Self: Sized;
    fn bytes(self) -> Bytes<Self> where Self: Sized;
    fn chain<R: Read>(self, next: R) -> Chain<Self, R> where Self: Sized;
    fn take(self, limit: u64) -> Take<Self> where Self: Sized;
    fn read_array<const N: usize>(&mut self) -> Result<[u8; N]>;  // unstable
    fn read_le<T>(&mut self) -> Result<T>;  fn read_be<T>(&mut self) -> Result<T>; // unstable
}

pub trait Write {
    fn write(&mut self, buf: &[u8]) -> Result<usize>;
    fn write_vectored(&mut self, bufs: &[IoSlice<'_>]) -> Result<usize>;
    fn is_write_vectored(&self) -> bool;                      // unstable
    fn flush(&mut self) -> Result<()>;
    fn write_all(&mut self, buf: &[u8]) -> Result<()>;
    fn write_all_vectored(&mut self, bufs: &mut [IoSlice<'_>]) -> Result<()>; // unstable
    fn write_fmt(&mut self, args: fmt::Arguments<'_>) -> Result<()>;
    fn by_ref(&mut self) -> &mut Self where Self: Sized;
}

pub trait BufRead: Read {
    fn fill_buf(&mut self) -> Result<&[u8]>;
    fn consume(&mut self, amount: usize);
    fn has_data_left(&mut self) -> Result<bool>;              // unstable
    fn read_until(&mut self, byte: u8, buf: &mut Vec<u8>) -> Result<usize>;
    fn skip_until(&mut self, byte: u8) -> Result<usize>;
    fn read_line(&mut self, buf: &mut String) -> Result<usize>;
    fn split(self, byte: u8) -> Split<Self> where Self: Sized;
    fn lines(self) -> Lines<Self> where Self: Sized;
}

pub trait Seek {
    fn seek(&mut self, pos: SeekFrom) -> Result<u64>;
    fn rewind(&mut self) -> Result<()>;
    fn stream_len(&mut self) -> Result<u64>;                  // unstable
    fn stream_position(&mut self) -> Result<u64>;
    fn seek_relative(&mut self, offset: i64) -> Result<()>;
}

pub enum SeekFrom { Start(u64), End(i64), Current(i64) }
```

`Read` is marked `#[rustc_must_implement_one_of(read_buf, read)]` — implement either `read` or `read_buf`, the rest have defaults (`alloc/src/io/read.rs`).

### Concrete types & free functions

- `BufReader<R>`: `new`, `with_capacity`, `peek` (unstable), `get_ref`, `get_mut`, `buffer`, `capacity`, `into_inner`, `seek_relative`; impls `Read`, `BufRead`, `Seek`, `Debug` (`alloc/src/io/buffered/bufreader.rs`).
- `BufWriter<W>`: `new`, `with_capacity`, `into_inner() -> Result<W, IntoInnerError<BufWriter<W>>>`, `into_parts() -> (W, Result<Vec<u8>, WriterPanicked>)`, `get_ref`, `get_mut`, `buffer`, `capacity`; impls `Write`, `Seek`, `Drop` (`alloc/src/io/buffered/bufwriter.rs`).
- `LineWriter`/`LineWriterShim`: line-buffered writing used by stdio (`alloc/src/io/buffered/linewritershim.rs`).
- `Cursor<T>`, `Empty`, `Repeat`, `Sink`, `Chain<A,B>`, `Take<R>`, `Bytes<R>`, `Lines<B>`, `Split<B>`, `IoSlice`, `IoSliceMut`, `BorrowedBuf`, `BorrowedCursor` (`std/src/io/mod.rs` re-exports).
- `pub fn copy<R,W>(reader: &mut R, writer: &mut W) -> Result<u64>` (`alloc/src/io/copy.rs`).
- `pub fn read_to_string<R: Read>(reader: R) -> Result<String>` (`alloc/src/io/read.rs`).
- `io::Result<T> = result::Result<T, Error>` (`core/src/io/error.rs`).
- `io::Error`: `new`, `last_os_error()`, `from_raw_os_error(code)`, `raw_os_error() -> Option<RawOsError>`, `get_ref`, `get_mut`, `kind() -> ErrorKind`; `Error::INVALID_UTF8`, `READ_EXACT_EOF`, `WRITE_ALL_EOF`, `ZERO_TIMEOUT` etc. (`core/src/io/error.rs`; `std/src/io/error.rs`).
- `std::io::pipe()` (since 1.87) → `(PipeReader, PipeWriter)` (`std/src/io/mod.rs`).
- `IsTerminal` trait (since 1.70), stdio `stdin`/`stdout`/`stderr` + lock types (`std/src/io/mod.rs`).
- `TcpStream` (implements both `Read for TcpStream` and `Read for &TcpStream`): `connect`, `connect_timeout`, `set_read_timeout`, `set_write_timeout`, `read_timeout`, `write_timeout`, `set_nonblocking`, `shutdown`, `peek`, `try_clone`, `nodelay`/`set_nodelay`, `take_error` (`std/src/net/tcp.rs`).

## 4. Error representation

- **One error type, not exceptions**: `io::Result<T>` is `Result<T, io::Error>`; every fallible I/O call returns it (`core/src/io/error.rs`, `Result` alias).
- **`Error` is a compact enum-of-variants wrapper**: internally `ErrorData::{Os(RawOsError), Simple(ErrorKind), SimpleMessage(&'static SimpleMessage), Custom(C)}`, with a bit-packed repr on 64-bit platforms and an unpacked repr on UEFI/32-bit (`core/src/io/error.rs`, `ErrorData`, `repr` module selection). `Error` is `Send + Sync` (`_assert_error_is_sync_send`).
- **`ErrorKind` is a `#[non_exhaustive]` enum** of ~45 variants (`NotFound`, `PermissionDenied`, `ConnectionRefused`, `ConnectionReset`, `WouldBlock`, `InvalidInput`, `InvalidData`, `TimedOut`, `WriteZero`, `UnexpectedEof`, `Interrupted`, `OutOfMemory`, …). The doc explicitly warns: "This list is intended to grow over time and it is not recommended to exhaustively match against it" and "use `match` for the ErrorKind values you are expecting; use `_` to match 'all other errors'". (`core/src/io/error.rs`, `ErrorKind` doc.)
- **Recoverable interruptions are a kind, not an exception**: `ErrorKind::Interrupted` — "Interrupted operations can typically be retried." (`core/src/io/error.rs`). All convenience methods (`read_to_end`, `read_exact`, `write_all`, `copy`) skip `Interrupted` and retry (`alloc/src/io/read.rs`, `core/src/io/write.rs`, `alloc/src/io/copy.rs`: "All instances of ErrorKind::Interrupted are handled by this function and the underlying operation is retried.").
- **Structured errors**: `BufWriter::into_inner` returns `Result<W, IntoInnerError<BufWriter<W>>>` (error holds the writer back so you can retry/salvage); `into_parts` returns `WriterPanicked` for the buffered bytes if the inner writer panicked (`alloc/src/io/buffered/bufwriter.rs`).
- **Error conversion is explicit**: `impl From<ErrorKind> for Error`, `Error::from_raw_os_error`, `Error::last_os_error()`; the `?` operator propagates without conversion when the error type already matches (`core/src/io/error.rs`).
- **Allocation-aware construction**: `const_error!(ErrorKind, "msg")` macro and `from_static_message` create non-allocating errors in `const` context (unstable, `core/src/io/error.rs`).

## 5. Ownership semantics

- **The caller owns the buffer; reads borrow it mutably, writes borrow it immutably.** `fn read(&mut self, buf: &mut [u8]) -> Result<usize>` and `fn write(&mut self, buf: &[u8]) -> Result<usize>` (`core/src/io/write.rs`, `alloc/src/io/read.rs`). No I/O call retains the buffer — the borrow checker enforces what Go documents ("Implementations must not retain p").
- **The stream owns its OS handle and, by drop, frees it.** "A type that owns its file descriptor should usually close it in its `drop` function. Types like `File` own their file descriptor. … file descriptors can be *borrowed*, granting the temporary right to perform operations … this indicates that the file descriptor will not be closed for the lifetime of the borrow, but it does *not* imply any right to close this file descriptor" (`std/src/io/mod.rs`, "I/O Safety" section). `OwnedFd` is likened to `Arc`, `BorrowedFd<'a>` to `&'a Arc` (`std/src/io/mod.rs`, I/O Safety).
- **I/O safety is a safety discipline, not just a convention**: "a safe function that takes a regular integer, treats it as a file descriptor, and acts on it, is *unsound*" (`std/src/io/mod.rs`, I/O Safety).
- **Buffered wrappers own their buffer and the inner stream**: `BufReader<R> { buf: Buffer, inner: R }`, `BufWriter<W> { buf: Vec<u8>, panicked: bool, inner: W }` (`alloc/src/io/buffered/bufreader.rs`/`bufwriter.rs`, struct definitions).
- **`BufWriter` flushes on drop, but errors are lost**: "It is critical to call flush before BufWriter<W> is dropped. Though dropping will attempt to flush the contents of the buffer, any errors that happen in the process of dropping will be ignored." (`alloc/src/io/buffered/bufwriter.rs`, type doc; `impl Drop` does `let _r = self.flush_buf();`). `into_parts`/`IntoInnerError` exist to recover when the drop-flush is not enough.
- **`BufReader` data can be silently lost**: "When the BufReader<R> is dropped, the contents of its buffer will be discarded. Creating multiple instances of a BufReader<R> on the same stream can cause data loss. Reading from the underlying reader after unwrapping … can also cause data loss." (`alloc/src/io/buffered/bufreader.rs`, type doc).
- **`TcpStream` can be split by shared reference**: `impl Read for &TcpStream` and `impl Write for &TcpStream`, so one connection can be read and written from two borrowed halves without cloning the fd (`std/src/net/tcp.rs`).
- **`Read`/`Write` take `&mut self`, enabling stateful readers** — the cursor is part of the reader, not an external offset (`core/src/io/write.rs`, `alloc/src/io/read.rs`).

## 6. Blocking / non-blocking

- **std I/O is blocking by default.** `Read::read` is a synchronous call; `Read`'s doc: "This function does not provide any guarantees about whether it blocks waiting for data, but if an object needs to block for a read and cannot, it will typically signal this via an `Err` return value." (`alloc/src/io/read.rs`).
- **There is no async in std.** The async traits live in `tokio::io` (and `futures::io`). `tokio::io::AsyncRead::poll_read(self: Pin<&mut Self>, cx, buf: &mut ReadBuf) -> Poll<Result<()>>`; `AsyncWrite::poll_write(...) -> Poll<Result<usize>>` plus `poll_flush`/`poll_shutdown` (`tokio/src/io/async_read.rs`, `tokio/src/io/async_write.rs`).
- **The async model is readiness-based `Poll`, not blocking**: "the poll_read method, unlike Read::read, will automatically queue the current task for wakeup and return if data is not yet available, rather than blocking the calling thread" (`tokio/src/io/async_read.rs`). Outcomes: `Poll::Ready(Ok(()))` with data placed in `buf`, `Poll::Pending` (task waker registered), `Poll::Ready(Err(e))`.
- **`Pin` in the signature** — async I/O objects must be pinned because their futures can self-reference (`tokio/src/io/async_read.rs`: `self: Pin<&mut Self>`).
- **Non-blocking std sockets exist**: `TcpStream::set_nonblocking(true)` — "If the IO operation could not be completed and needs to be retried, an error with kind `io::ErrorKind::WouldBlock` is returned." (`std/src/net/tcp.rs`). `WouldBlock` is the std-level "not ready" signal (`core/src/io/error.rs`, `ErrorKind::WouldBlock`: "The operation needs to block to complete, but the blocking operation was requested to not occur").
- **`ErrorKind::Interrupted` is the other non-fatal, retryable condition** and is auto-retried by all `_all`/`to_end` helpers (`core/src/io/write.rs`, `alloc/src/io/read.rs`).
- **Async I/O can be layered on blocking I/O** via `tokio::io::BufReader`/`BufWriter` over any `AsyncRead`/`AsyncWrite` (AsyncRead docs, implementors list).

## 7. Byte streams vs text streams

- **Bytes are the primitive; text is a method on top, not a separate trait.** `Read::read(&mut [u8])` and `Write::write(&[u8])`; text enters via `read_to_string(&mut String)`, `read_line(&mut String)`, `lines()`, `BufWriter::write_fmt` (`alloc/src/io/read.rs`, `alloc/src/io/buf_read.rs`, `core/src/io/write.rs`).
- **Text validity is checked, not assumed**: "If the data in this stream is *not* valid UTF-8 then an error is returned and `buf` is unchanged" (`alloc/src/io/read.rs`, `read_to_string` doc). Internally `append_to_string` uses an RAII `DropGuard` that truncates the `String` to its prior length unless the appended bytes validate as UTF-8, and maps failure to `Error::INVALID_UTF8` (`alloc/src/io/read.rs`, `append_to_string`).
- **`&str`/`String` are byte readers too**: `&[u8]` implements `Read`, so `"text".as_bytes()` reads like a file (`alloc/src/io/read.rs` doc example). `std::io::Cursor` wraps `Vec<u8>`/`&[u8]`/`Box<[u8]>` (`std/src/io/mod.rs`).
- **Buffering is a separate, composable layer**: `BufReader<R>` implements `Read`, `BufRead` and `Seek`; `BufRead` gives `fill_buf`/`consume` (a zero-copy window) on top of which `read_until`/`read_line`/`lines`/`split` are built (`alloc/src/io/buf_read.rs`, `BufRead` trait). `Bytes<R>`, `Lines<B>`, `Split<B>` are iterator adapters (`std/src/io/mod.rs`).
- **`BufRead`'s borrow-window protocol**: `fill_buf() -> Result<&[u8]>` returns the internal slice, `consume(n)` marks bytes read — the caller must not hold the slice across `consume` (`alloc/src/io/buf_read.rs`).
- **Line buffering exists as `LineWriter`** used for `Stdout` when it is a terminal: flush on every `\n` (`alloc/src/io/buffered/linewritershim.rs`, doc: "if any newlines are present in the data, the data up to the last newline is sent directly to the underlying writer, and data after it is buffered").
- **A partial read is `Ok(n)` with `n < buf.len()` and is explicitly not an error**: "It is not an error if the returned value n is smaller than the buffer size, even when the reader is not at the end of the stream yet. This may happen for example because fewer bytes are actually available right now (e. g. being close to end-of-file) or because read() was interrupted by a signal." (`alloc/src/io/read.rs`, `read` doc). Callers who need exactly N use `read_exact` (`ErrorKind::UnexpectedEof` otherwise).
- **Zero-length buffer special case**: `Ok(0)` also results when the buffer was 0 bytes long (`alloc/src/io/read.rs`, `read` doc, listed as scenario 2).

## 8. Timeouts

- **No timeouts in `std::io` itself.** The traits have no deadline parameter; there is no `context`/cancellation type in `std::io` (`core/src/io/write.rs`, `alloc/src/io/read.rs` signatures).
- **Timeouts are set on the concrete stream**: `TcpStream::set_read_timeout(Some(Duration))` / `set_write_timeout(Some(Duration))`; `None` means block indefinitely; a zero `Duration` is rejected with `ErrorKind::InvalidInput` — "An Err is returned if the zero Duration is passed to this method." (`std/src/net/tcp.rs`). Getters `read_timeout()`/`write_timeout()` return `io::Result<Option<Duration>>`.
- **The timeout surfaces as a platform-dependent `ErrorKind`**: "Platforms may return a different error code whenever a read times out as a result of setting this option. For example Unix typically returns an error of the kind WouldBlock, but Windows may return TimedOut." (`std/src/net/tcp.rs`, `set_read_timeout` doc). `ErrorKind::TimedOut` = "The I/O operation's timeout expired, causing it to be canceled." (`core/src/io/error.rs`).
- **Connect has its own timeout**: `TcpStream::connect_timeout(addr, timeout)` — "Unlike other methods on TcpStream, this does not correspond to a single system call. It instead calls connect in nonblocking mode and then uses an OS-specific mechanism to await the completion of the connection request." (`std/src/net/tcp.rs`).
- **Async cancellation is a different mechanism**: in tokio a pending operation is a `Future` that can be dropped; `AsyncWrite::poll_shutdown` is the explicit graceful-shutdown hook ("Invocation of a shutdown implies an invocation of flush", `tokio/src/io/async_write.rs`). Timeouts are implemented in tokio via `tokio::time` combinators, not in the I/O trait (Assessment: derived from the trait signatures containing no time value).
- **There is no `ErrorKind::Cancelled`; the closest std kinds are `TimedOut`/`Interrupted`** (`core/src/io/error.rs`, `ErrorKind` variants).

## 9. End-of-stream and error signalling

- **EOF is `Ok(0)` — success, not an error.** "If n is 0, then it can indicate one of two scenarios: 1. This reader has reached its 'end of file' … 2. The buffer specified was 0 bytes in length." (`alloc/src/io/read.rs`, `read` doc). This is the opposite of Go's `io.EOF` in the `err` slot.
- **The doc is careful that `Ok(0)` may be temporary**: "Note that this does not mean that the reader will *always* no longer be able to produce bytes. As an example, on Linux, this method will call the recv syscall for a TcpStream, where returning zero indicates the connection was shut down correctly. While for File, it is possible to reach the end of file and get zero as result, but if more data is appended to the file, future calls to `read` will return more data." (`alloc/src/io/read.rs`, `read` doc).
- **An error must not accompany partial data**: "If this function encounters any form of I/O or other error, an error variant will be returned. If an error is returned then it must be guaranteed that no bytes were read." (`alloc/src/io/read.rs`, `read` doc). (Contrast Go's `n>0` + error.)
- **Short read ≠ EOF ≠ error**: `Ok(n)` with `0 < n < buf.len()` is normal and non-error; `Ok(0)` is EOF-or-empty-buffer; `Err` is failure (`alloc/src/io/read.rs`).
- **Helpers turn premature EOF into a distinct error**: `read_exact` returns `ErrorKind::UnexpectedEof` ("failed to fill whole buffer", `Error::READ_EXACT_EOF`) if EOF hits before the buffer is full; `read_to_end` returns early and keeps what it has (`alloc/src/io/read.rs`, `default_read_exact`, `default_read_to_end`).
- **Write-side end signalling is `Ok(0)` too**: "A return value of Ok(0) typically means that the underlying object is no longer able to accept bytes… or that the buffer provided is empty." `write_all` converts a mid-write `Ok(0)` into `ErrorKind::WriteZero` ("failed to write whole buffer", `Error::WRITE_ALL_EOF`) (`core/src/io/write.rs`; `alloc/src/io/buffered/bufwriter.rs`, `flush_buf` maps `Ok(0)` to `WriteZero`).
- **EOF is a non-event for copies**: `copy`/`read_to_end` treat `Ok(0)` as completion and return the byte count, not an error (`alloc/src/io/copy.rs`, `alloc/src/io/read.rs`).
- **`Interrupted` must be retried, all other errors abort** (`alloc/src/io/read.rs`, `default_read_to_end`; `core/src/io/write.rs`, `write_all`).
- **`BufRead::read_line` returns `Ok(0)` at EOF**, otherwise the number of bytes appended including the newline (`alloc/src/io/buf_read.rs`, `read_line` doc).

## 10. Interesting design decisions

- **Failure and end-of-stream live in different channels.** Success (`Ok(n)`, with `n = 0` meaning EOF) vs failure (`Err`). This removes Go's "read n bytes *and* an error" ambiguity and makes the error-free hot loop trivial (`alloc/src/io/read.rs`).
- **The `Interrupted` idiom.** Rather than retrying inside every syscall wrapper, `ErrorKind::Interrupted` is a named, retryable category and the convenience methods encode the retry policy once (`core/src/io/write.rs`, `alloc/src/io/read.rs`).
- **`#[non_exhaustive] ErrorKind` + "match with a wildcard".** The error taxonomy is explicitly *open*; new kinds will not break existing `match`es (`core/src/io/error.rs`, `ErrorKind` doc).
- **Default-method richness with `must_implement_one_of`.** Implementing one of `read`/`read_buf` unlocks ~15 derived operations (`read_to_end`, `read_exact`, `bytes`, `chain`, `take`, …); the compiler enforces at least one (`alloc/src/io/read.rs`, `#[rustc_must_implement_one_of(read_buf, read)]`).
- **The `fill_buf`/`consume` window.** A buffered reader lends out its internal slice and lets the caller declare how much was used — zero-copy parsing without exposing the buffer's lifetime (`alloc/src/io/buf_read.rs`, `BufRead`).
- **I/O safety modelled like memory safety.** `OwnedFd` / `BorrowedFd<'a>` distinguish "may close" from "may operate but not close", and the doc argues unsoundness of raw-integer fds (`std/src/io/mod.rs`, I/O Safety). This is the closest mainstream analogue to an ownership model in an I/O API.
- **`BufWriter`'s drop-flush is best-effort and deliberately error-losing**, so there is an explicit `into_parts()`/`IntoInnerError` escape hatch for callers who need the error (`alloc/src/io/buffered/bufwriter.rs`).
- **`ReadBuf`'s double cursor for async reads.** It tracks `filled`, `initialized` and `capacity` so a `poll_read` can hand an *uninitialized* buffer to an I/O object safely — solving "don't zero 8 KiB per read" without `unsafe` in every implementor (`tokio/src/io/read_buf.rs`).
- **Copy specialization.** `io::copy` first tries a specialized copy (`SpecCopyInner`) and reports `CopyState::Ended(copied)` or `Fallback(copied)`, falling back to the generic loop only when needed; on Linux it uses `copy_file_range`/`sendfile`/`splice` where possible (`alloc/src/io/copy.rs`).
- **Vectored I/O is first-class.** `read_vectored`/`write_vectored` with `IoSlice`/`IoSliceMut` and `is_*_vectored()` capability probes avoid coalescing copies (`core/src/io/write.rs`, `alloc/src/io/read.rs`).
- **Line buffering is a shim over `BufWriter`, not a separate buffer** — `LineWriterShim` reuses `BufWriter`'s internals and is applied conditionally to `Stdout` (`alloc/src/io/buffered/linewritershim.rs`).
- **`Seek` is a separate trait with sane defaults**; `stream_len` is implemented via seeks and restores the position unless it was already at the end (`core/src/io/seek.rs`, `stream_len_default`).
- **The same trait is implemented for `TcpStream` and `&TcpStream`**, enabling split read/write halves by shared reference (`std/src/net/tcp.rs`).

## 11. Decisions NOT to copy

- **`Pin` in the I/O trait signature.** Needing `Pin<&mut Self>` for async I/O is a Rust-specific consequence of self-referential futures; Mojo should not expose pinning (`tokio/src/io/async_read.rs`).
- **`ErrorKind` as a `#[non_exhaustive]` enum with ~45 OS-derived variants.** Matching on OS errno categories leaks platform detail into the API and forces wildcard matches. Prefer a small closed set of *stream* outcomes (end-of-stream, interrupted, timeout, closed, other) (`core/src/io/error.rs`, `ErrorKind`).
- **Platform-dependent timeout error kinds.** A timeout reporting `WouldBlock` on Unix and `TimedOut` on Windows makes portable handling awkward; MojoAkku should normalise it (`std/src/net/tcp.rs`, `set_read_timeout` doc).
- **Error-losing `Drop` flush.** `BufWriter`'s drop silently discards flush errors; a predictable API should require an explicit, fallible close/flush, as Go's `bufio.Writer.Flush` does (`alloc/src/io/buffered/bufwriter.rs`; Assessment derived from the two).
- **Silent data loss when a buffered reader is dropped or unwrapped.** `BufReader` discards its buffer and documents data loss; a Mojo design should make leftover buffered bytes impossible to lose (`alloc/src/io/buffered/bufreader.rs`, type doc).
- **`Ok(0)` doubling as both "EOF" and "empty buffer".** Two very different meanings share one value; the caller must know `buf.len()` to disambiguate (`alloc/src/io/read.rs`, `read` doc).
- **`BorrowedBuf`/`BorrowedCursor` uninitialized-buffer machinery.** The initialized/filled double-cursor is a Rust `MaybeUninit` workaround; Mojo's `UnsafePointer`/initialization story differs and the concept should not be transplanted wholesale (`tokio/src/io/read_buf.rs`, `core/src/io/borrowed_buf.rs`).
- **Separate sync and async trait hierarchies with no bridge.** `std::io::Read` and `tokio::io::AsyncRead` are unrelated traits with duplicated adapters (`BufReader`, `Take`, `Chain` exist in both). MojoAkku should aim for one stream concept with a blocking/async execution policy, not two parallel worlds (`tokio/src/io/async_read.rs`; `std/src/io/mod.rs`).
- **`write_fmt` on the core `Write` trait.** Coupling byte output to the formatting machinery bloats the trait; Go keeps `fmt` outside `io` (`core/src/io/write.rs`; Assessment derived from the trait surface).
- **`Vec`/`String` as the only accumulation targets of `read_to_end`/`read_to_string`.** The trait methods hardcode allocator types; an explicit-buffer design is more honest about allocation (`alloc/src/io/read.rs`).

## 12. Ideas fitting Mojo

- **`Read`/`Write` as minimal one-method traits with provided defaults.** Exactly the shape the Mojo stdlib already uses for `Writer` (`write_string` required, `write` provided); a `Reader` trait with `read` required and `read_exact`/`read_to_end` provided is the symmetric move (`mojov1/stdlib/io`; `alloc/src/io/read.rs`).
- **End-of-stream as a distinct, typed outcome.** Rust's core insight — EOF is *not* failure — maps well to Mojo as either `raises EndOfStream` or an enum return, while failures stay in `raises` (`alloc/src/io/read.rs`).
- **A named `Interrupted` classification with a central retry policy.** Mojo can express Rust's retry idiom as an error value in the `raises` set plus provided helpers that swallow it (`core/src/io/write.rs`, `alloc/src/io/read.rs`).
- **`fill_buf`/`consume` as a `borrowed`-returning window.** A buffered reader can lend a `borrowed` byte span and take back a consumed count; ownership stays with the reader and the borrow's end is compile-time enforced (`alloc/src/io/buf_read.rs`).
- **Owned-vs-borrowed stream handles mirroring Mojo's own ownership.** Rust's `OwnedFd`/`BorrowedFd` distinction is a direct analogue of owning vs `borrowed` a handle; MojoAkku can make "may close" vs "may only operate" a type-level distinction (`std/src/io/mod.rs`, I/O Safety).
- **Buffering as a composable, value-semantics wrapper.** `BufReader<R>`/`BufWriter<W>` are ordinary structs holding a buffer and an inner stream — a natural Mojo `struct` parameterised over the stream, with the buffer inline (fixed capacity) or explicitly supplied (`alloc/src/io/buffered/bufreader.rs`).
- **A small closed error taxonomy instead of OS errno categories.** Rust's `ErrorKind` shows both the value (machine-matchable errors) and the cost (non-exhaustive, platform-dependent). Mojo should keep a short, stable enum and put the OS code in an opaque detail field (`core/src/io/error.rs`).
- **Explicit `flush`/`close` with a reported error, replacing `Drop` flush.** Mojo's `with`/`close` idiom gives a place to surface flush failures the way Rust's `Drop` cannot (`mojov1/stdlib/io` `with open(...) as f`; `alloc/src/io/buffered/bufwriter.rs`).
- **Provided helpers for exact reads and copies.** `read_exact`, `read_to_end`, `copy` as free/comptime-generic functions over the `Reader` trait keep the trait minimal (`alloc/src/io/read.rs`, `alloc/src/io/copy.rs`).
- **Compile-time specialization of `copy`.** Rust resolves fast paths at runtime via trait specialization; Mojo can choose a `comptime`/`alias`-driven copy strategy for known stream types (`alloc/src/io/copy.rs`, `SpecCopyInner`).
- **Timeout as a per-operation parameter rather than stream state.** Rust's per-stream `Duration` is mutable global-ish state with platform-dependent reporting; a `comptime`-optional `timeout: Optional[Duration]` argument per call fits Mojo value semantics (`std/src/net/tcp.rs`).

## Sources

- Rust std `io` module docs & re-exports: https://raw.githubusercontent.com/rust-lang/rust/master/library/std/src/io/mod.rs (I/O Safety, `stdin`/`stdout`, `pipe` since 1.87)
- Rust `core::io` module: https://raw.githubusercontent.com/rust-lang/rust/master/library/core/src/io/mod.rs
- Rust `alloc::io` module (Read, BufRead, BufReader/Writer, copy, read_to_string): https://raw.githubusercontent.com/rust-lang/rust/master/library/alloc/src/io/mod.rs
- Rust `Read` trait: https://raw.githubusercontent.com/rust-lang/rust/master/library/alloc/src/io/read.rs (EOF `Ok(0)`, short read, `read_exact`, `Interrupted`, `append_to_string`/`INVALID_UTF8`)
- Rust `Write` trait: https://raw.githubusercontent.com/rust-lang/rust/master/library/core/src/io/write.rs (`write_all`, `WriteZero`, `write_fmt`, vectored)
- Rust `BufRead` trait: https://raw.githubusercontent.com/rust-lang/rust/master/library/alloc/src/io/buf_read.rs (`fill_buf`/`consume`, `read_until`, `read_line`, `lines`)
- Rust `Seek` trait: https://raw.githubusercontent.com/rust-lang/rust/master/library/core/src/io/seek.rs (`SeekFrom`, `stream_len`)
- Rust `io::Error` / `ErrorKind`: https://raw.githubusercontent.com/rust-lang/rust/master/library/core/src/io/error.rs ; std extension https://raw.githubusercontent.com/rust-lang/rust/master/library/std/src/io/error.rs (`last_os_error`, `from_raw_os_error`)
- Rust `BufReader`: https://raw.githubusercontent.com/rust-lang/rust/master/library/alloc/src/io/buffered/bufreader.rs (data-loss doc, `peek`, `Read`/`BufRead`/`Seek` impls)
- Rust `BufWriter`: https://raw.githubusercontent.com/rust-lang/rust/master/library/alloc/src/io/buffered/bufwriter.rs (`into_inner`, `into_parts`, `WriterPanicked`, `Drop`)
- Rust `LineWriterShim`: https://raw.githubusercontent.com/rust-lang/rust/master/library/alloc/src/io/buffered/linewritershim.rs
- Rust `io::copy`: https://raw.githubusercontent.com/rust-lang/rust/master/library/alloc/src/io/copy.rs (`CopyState`, specialization)
- Rust `TcpStream`/`TcpListener`: https://raw.githubusercontent.com/rust-lang/rust/master/library/std/src/net/tcp.rs (`set_read_timeout`, `set_nonblocking`, `impl Read/Write for &TcpStream`)
- tokio `AsyncRead`: https://raw.githubusercontent.com/tokio-rs/tokio/master/tokio/src/io/async_read.rs ; rendered docs https://docs.rs/tokio/latest/tokio/io/trait.AsyncRead.html
- tokio `AsyncWrite`: https://raw.githubusercontent.com/tokio-rs/tokio/master/tokio/src/io/async_write.rs (`poll_write`, `poll_flush`, `poll_shutdown`)
- tokio `ReadBuf`: https://raw.githubusercontent.com/tokio-rs/tokio/master/tokio/src/io/read_buf.rs (filled/initialized/capacity double cursor)
- tokio license (MIT): https://raw.githubusercontent.com/tokio-rs/tokio/master/LICENSE
- `bytes` crate: https://github.com/tokio-rs/bytes (README, MIT license)
- Mojo Akku `io` run config: `mojoakku/io/_dev/README.md`
