# io research: Go

## 1. Standard library support

Go splits I/O across a small set of orthogonal packages:

- **`io`** — "Package io provides basic interfaces to I/O primitives" (`golang/go:src/io/io.go`, package doc). It defines the interface *family* (`Reader`, `Writer`, `Closer`, `Seeker`, `ReaderAt`, `WriterAt`, `ByteReader`, `RuneReader`, `StringWriter`, `ReaderFrom`, `WriterTo`) plus generic helpers (`Copy`, `CopyN`, `CopyBuffer`, `ReadAll`, `ReadFull`, `ReadAtLeast`, `LimitReader`, `MultiReader`, `MultiWriter`, `TeeReader`, `Pipe`, `NopCloser`) and the sentinel errors. All of this is interface-based; there is **no concrete stream type** in `io` except the adapters (`LimitedReader`, `SectionReader`, `OffsetWriter`, `teeReader`, `nopCloser`, `pipe`).
- **`bufio`** — "Package bufio implements buffered I/O. It wraps an io.Reader or io.Writer object, creating another object (Reader or Writer) that also implements the interface but provides buffering and some help for textual I/O" (`golang/go:src/bufio/bufio.go`, package doc). This is where textual reading lives (`ReadString`, `ReadBytes`, `ReadRune`, `ReadLine`, `Scanner`).
- **`os`** — concrete file I/O. `os.File` implements `io.Reader`, `io.Writer`, `io.Closer`, `io.Seeker`, `io.ReaderAt`, `io.WriterAt`, `io.ReaderFrom`, `io.WriterTo` (`golang/go:src/os/file.go`; documented by the concrete methods `File.Read`, `File.Write`, `File.ReadAt`, `File.WriteAt`, `File.Seek`, `File.ReadFrom`, `File.WriteTo`).
- **`bytes` / `strings`** — in-memory readers: `*bytes.Buffer`, `*bytes.Reader` and `*strings.Reader` implement the `io` interfaces; `strings.Builder` implements `io.Writer`/`io.StringWriter`.
- **`io/fs`** — a filesystem abstraction (`fs.FS`, `fs.File`) that `os.DirFS` implements; `os.ReadFile`/`os.WriteFile` are the whole-file convenience functions (`golang/go:src/os/file.go`, `ReadFile`/`WriteFile` docs).

Everything is standard library, BSD-3-Clause (`golang/go:LICENSE`). There is no standard async I/O layer; see §6.

## 2. Relevant community libraries

- **`github.com/valyala/bytebufferpool`** — "An implementation of a pool of byte buffers with anti-memory-waste protection"; author is the fasthttp author valyala; used by fasthttp and quicktemplate; MIT licence (`valyala/bytebufferpool:LICENSE` — <https://github.com/valyala/bytebufferpool/blob/master/LICENSE>). (`https://github.com/valyala/bytebufferpool`). Maturity: long-lived, widely used in the fasthttp ecosystem.
- **`github.com/cloudwego/netpoll`** — "a high-performance non-blocking I/O networking framework, which focused on RPC scenarios, developed by ByteDance"; Apache-2.0 (`https://github.com/cloudwego/netpoll`, `netpoll/blob/main/LICENSE` = Apache License 2.0). Provides `LinkBuffer` "nocopy API for streaming reading and writing", an `EventLoop` server abstraction, `IsActive` liveness checks, TCP + Unix domain sockets, Linux/macOS only (README "Features"). Maturity: production, powers Kitex (RPC) and Hertz (HTTP) (README).
- **`github.com/panjf2000/gnet/v2`** — "an event-driven networking framework that is ultra-fast and lightweight … built from scratch by exploiting epoll and kqueue"; Apache-2.0 ("The source code of `gnet` should be distributed under the Apache-2.0 license", README §License); provides ring-buffer / linked-list-buffer / elastic-mixed-buffer memory buffers, lock-free event loops, TCP/UDP/Unix sockets; Windows support "should only be used in development" (README). Maturity: production (Tencent, ByteDance, JD, etc. listed as users) (README).
- **`golang.org/x/net`** — the Go team's extended networking package; relevant mostly as the home of protocol-level I/O (HTTP/2, WebSocket-like helpers), not a reader/writer design of its own (Assessment: derived from the x/net module scope, `https://pkg.go.dev/golang.org/x/net`).

(Assessment: the three listed libraries are all *networking frameworks on top of* the `io` interfaces, not replacements for them — Go's I/O model is unusually stdlib-settled.)

## 3. Exposed APIs

### The core interfaces (`golang/go:src/io/io.go`)

```go
type Reader interface {
    Read(p []byte) (n int, err error)
}
type Writer interface {
    Write(p []byte) (n int, err error)
}
type Closer interface { Close() error }
type Seeker interface { Seek(offset int64, whence int) (int64, error) }

type ReadWriter    interface { Reader; Writer }
type ReadCloser    interface { Reader; Closer }
type WriteCloser   interface { Writer; Closer }
type ReadWriteCloser interface { Reader; Writer; Closer }

type ReaderAt interface { ReadAt(p []byte, off int64) (n int, err error) }
type WriterAt interface { WriteAt(p []byte, off int64) (n int, err error) }
type ByteReader  interface { ReadByte() (byte, error) }
type ByteScanner interface { ByteReader; UnreadByte() error }
type ByteWriter  interface { WriteByte(c byte) error }
type RuneReader  interface { ReadRune() (r rune, size int, err error) }
type RuneScanner interface { RuneReader; UnreadRune() error }
type StringWriter interface { WriteString(s string) (n int, err error) }
type ReaderFrom interface { ReadFrom(r Reader) (n int64, err error) }
type WriterTo   interface { WriteTo(w Writer) (n int64, err error) }
```

Key documented contract of `Reader.Read`: "Read reads up to len(p) bytes into p. It returns the number of bytes read (0 <= n <= len(p)) and any error encountered. Even if Read returns n < len(p), it may use all of p as scratch space during the call. If some data is available but not len(p) bytes, Read conventionally returns what is available instead of waiting for more." (`io.go`, `Reader` doc). Also: "Implementations must not retain p." (`io.go`, `Reader` doc).

Constants and sentinel errors (`io.go`): `SeekStart = 0`, `SeekCurrent = 1`, `SeekEnd = 2`; `ErrShortWrite`, `ErrShortBuffer`, `EOF`, `ErrUnexpectedEOF`, `ErrNoProgress`, `ErrClosedPipe`.

Helpers: `WriteString(w, s)`, `ReadAtLeast(r, buf, min)`, `ReadFull(r, buf)`, `CopyN(dst, src, n)`, `Copy(dst, src)`, `CopyBuffer(dst, src, buf)`, `LimitReader(r, n)`, `NewSectionReader(r, off, n)`, `NewOffsetWriter(w, off)`, `TeeReader(r, w)`, `NopCloser(r)`, `ReadAll(r)`, `MultiReader(readers...)`, `MultiWriter(writers...)`, `Pipe()` (`io.go`, `io/multi.go`, `io/pipe.go`).

### `bufio` (`golang/go:src/bufio/bufio.go`, `scan.go`)

```go
const defaultBufSize = 4096
var ErrInvalidUnreadByte, ErrInvalidUnreadRune, ErrBufferFull, ErrNegativeCount error

func NewReaderSize(rd io.Reader, size int) *Reader
func NewReader(rd io.Reader) *Reader
func (b *Reader) Size() int
func (b *Reader) Reset(r io.Reader)
func (b *Reader) Peek(n int) ([]byte, error)
func (b *Reader) Discard(n int) (discarded int, err error)
func (b *Reader) Read(p []byte) (n int, err error)
func (b *Reader) ReadByte() (byte, error)
func (b *Reader) UnreadByte() error
func (b *Reader) ReadRune() (r rune, size int, err error)
func (b *Reader) UnreadRune() error
func (b *Reader) Buffered() int
func (b *Reader) ReadSlice(delim byte) (line []byte, err error)
func (b *Reader) ReadLine() (line []byte, isPrefix bool, err error)
func (b *Reader) ReadBytes(delim byte) ([]byte, error)
func (b *Reader) ReadString(delim byte) (string, error)
func (b *Reader) WriteTo(w io.Writer) (n int64, err error)

func NewWriter(w io.Writer) *Writer
func NewWriterSize(w io.Writer, size int) *Writer
func (b *Writer) Flush() error
func (b *Writer) Available() int
func (b *Writer) AvailableBuffer() []byte
func (b *Writer) Buffered() int
func (b *Writer) Write(p []byte) (nn int, err error)
func (b *Writer) WriteByte(c byte) error
func (b *Writer) WriteRune(r rune) (size int, err error)
func (b *Writer) WriteString(s string) (int, error)
func (b *Writer) ReadFrom(r io.Reader) (n int64, err error)

func NewReadWriter(r *Reader, w *Writer) *ReadWriter

type Scanner struct { ... }
func NewScanner(r io.Reader) *Scanner
func (s *Scanner) Scan() bool
func (s *Scanner) Bytes() []byte
func (s *Scanner) Text() string
func (s *Scanner) Err() error
func (s *Scanner) Buffer(buf []byte, max int)
func (s *Scanner) Split(split SplitFunc)
type SplitFunc func(data []byte, atEOF bool) (advance int, token []byte, err error)
var ScanBytes, ScanRunes, ScanLines, ScanWords SplitFunc
const MaxScanTokenSize = 64 * 1024
var ErrTooLong, ErrNegativeAdvance, ErrAdvanceTooFar, ErrBadReadCount error
var ErrFinalToken = errors.New("final token")
```

### `os.File` (`golang/go:src/os/file.go`)

`Open`, `Create`, `OpenFile`, `ReadFile`, `WriteFile`, `File.Read`, `File.ReadAt`, `File.Write`, `File.WriteAt`, `File.WriteString`, `File.Seek`, `File.ReadFrom`, `File.WriteTo`, `File.Close`, `File.Fd`, `File.SetDeadline`, `File.SetReadDeadline`, `File.SetWriteDeadline`, `File.SyscallConn`. `NewFile(fd, name)` wraps a raw descriptor. Open flags `O_RDONLY`/`O_WRONLY`/`O_RDWR`/`O_APPEND`/`O_CREATE`/`O_EXCL`/`O_SYNC`/`O_TRUNC`.

## 4. Error representation

Go has **no exceptions** for I/O. The `error` interface is a normal return value; the reader/writer convention is a **pair** `(n, err)`.

- **Sentinel error values** compared with `==` or `errors.Is`: `io.EOF`, `io.ErrUnexpectedEOF`, `io.ErrShortWrite`, `io.ErrShortBuffer`, `io.ErrNoProgress`, `io.ErrClosedPipe` (`golang/go:src/io/io.go`, symbol `EOF`; `golang/go:src/io/pipe.go`). `io.EOF` is explicitly a sentinel that must be returned itself: "Read must return EOF itself, not an error wrapping EOF, because callers will test for EOF using ==" (`io.go`, symbol `EOF`, doc comment).
- **`n > 0` together with an error is allowed**: "When Read encounters an error or end-of-file condition after successfully reading n > 0 bytes, it returns the number of bytes read. It may return the (non-nil) error from the same call or return the error (and n == 0) from a subsequent call." (`io.go`, `Reader` doc). Callers must always process `n` bytes before the error.
- **Structured wrapper errors** carry context: `*os.PathError` (op + path + err) for file operations, `*net.OpError` (op + net + source + addr + err) for network operations (`golang/go:src/net/net.go`, `OpError`), with `Unwrap()` for the chain.
- **Error classification by method/duck-typing, not codes**: `net.Error` is an interface `{ error; Timeout() bool; Temporary() bool }` (`net.go`); callers ask `err.(net.Error).Timeout()`. `errors.Is`/`errors.As`/`errors.AsType` walk `Unwrap()` trees (`golang/go:src/errors/wrap.go`).
- **`errors.Join`** (not shown above) and `Unwrap() []error` support multi-error trees (`errors/wrap.go`, `is`/`as` doc).
- **Partial output on failure**: `ReadFull`/`ReadAtLeast` return the count read plus `ErrUnexpectedEOF` if EOF arrives mid-buffer; `CopyN` returns `written` plus `ErrShortWrite` when the destination accepts fewer bytes (`io.go`, `CopyN`/`ReadAtLeast` docs).

## 5. Ownership semantics

Go is garbage-collected; there is no RAII/ownership transfer. The design pushes buffers onto the caller:

- **The caller allocates the read/write buffer.** `Read(p []byte)` writes into `p` and returns a count; the contract says "Implementations must not retain p" (`io.go`, `Reader` doc). Same for `Write` ("Write must not modify the slice data, even temporarily. Implementations must not retain p.", `io.go`, `Writer` doc).
- **The reader/writer owns its own internal buffered state.** `bufio.Reader` owns `buf []byte`, positions `r, w int`, a sticky `err` and `lastByte`/`lastRuneSize` (`bufio.go`, `Reader` struct). `bufio.Writer` owns `buf []byte`, `n int`, a sticky `err` and the wrapped `io.Writer` (`bufio.go`, `Writer` struct). `NewReaderSize` may *return the wrapped `*Reader` unchanged* if it already has a large enough buffer ("If the argument io.Reader is already a Reader with large enough size, it returns the underlying Reader.", `bufio.go`) — i.e. wrapping is not guaranteed to create a second owner of a buffer.
- **`os.File` owns an OS file descriptor**; it is closed by `File.Close` and may also be closed by a finalizer if garbage-collected (`os/file.go`, `File.Fd` doc: "If f is garbage collected, a finalizer may close the descriptor").
- **`io.Pipe` transfers slices by copy through channels**, with no internal buffering: "The data is copied directly from the Write to the corresponding Read (or Reads); there is no internal buffering." (`io/pipe.go`, `Pipe` doc).
- **`Copy` allocates its own staging buffer** (nil buffer → `make([]byte, 32*1024)`) unless either side implements `WriterTo`/`ReaderFrom`, in which case buffer ownership is delegated (`io.go`, `copyBuffer`).

## 6. Blocking / non-blocking

- **The `io` interfaces are blocking by contract.** `Read`/`Write` do not return "would block"; a socket read blocks until data arrives or the deadline fires. `io.Pipe` "blocks until a writer arrives or the write end is closed" (`io/pipe.go`, `PipeReader.Read` doc).
- **Concurrency model is goroutines, not `async`/`await`.** Blocking reads are cheap because the Go runtime parks the goroutine; the canonical pattern is one goroutine per connection (`net` package doc: the example does `go handleConnection(conn)`) (`net.go`).
- **Non-blocking I/O is an internal runtime detail**, exposed only via deadlines (`net.Conn.SetDeadline`, `os.File.SetDeadline`) — the implementation uses the runtime netpoller (`net.go`, `Conn` doc; `os/file.go`, `NewFile` doc about "pollable file"). `TcpStream`-style `set_nonblocking` does not exist in Go's user API.
- **A second, event-loop model exists in the community**: `netpoll` runs an `EventLoop` with no goroutine-per-connection (README), `gnet` is "non-blocking, event-driven" with "Lock-free during the entire runtime" (README). These replace `net`, not `io`.
- `io.Copy`/`bufio` are synchronous; blocking happens on whatever goroutine calls them (Assessment: derived from the `io`/`bufio` method signatures and docs quoted above).

## 7. Byte streams vs text streams

- **The primary abstraction is bytes-only.** `io.Reader.Read(p []byte)`, `io.Writer.Write(p []byte)`. There is no `TextReader`/`TextWriter` interface.
- **Text is an *optional capability* detected by type assertion, not a separate hierarchy.** `io.RuneReader` (`ReadRune`), `io.RuneScanner`, `io.StringWriter` (`WriteString`) are small interfaces; helpers probe for them: `WriteString` "If w implements StringWriter, StringWriter.WriteString is invoked directly. Otherwise, Writer.Write is called exactly once." (`io.go`).
- **Text decoding is layered on top of buffering.** `bufio.Reader.ReadRune` decodes UTF-8; invalid encodings "consume one byte and return unicode.ReplacementChar (U+FFFD) with a size of 1" (`bufio.go`, `ReadRune` doc). `bufio.Reader.ReadString(delim)` returns a `string` and allocates; `ReadLine` returns a borrowed slice plus `isPrefix` for over-long lines (`bufio.go`).
- **`Scanner` is a tokenizer, not a reader.** It takes a `SplitFunc` and default splits `ScanLines`/`ScanBytes`/`ScanRunes`/`ScanWords` (`scan.go`).
- **Buffering is explicit and additive**: `io.Reader` → `bufio.NewReader` → line/rune methods. The default buffer is 4096 bytes (`bufio.go`, `defaultBufSize`); `bufio` explicitly bypasses its buffer for large reads/writes to avoid an extra copy ("Large read, empty buffer. Read directly into p to avoid copy.", `bufio.go`, `Reader.Read`).
- **A partial read is reported as `n < len(p)` with `err == nil`** — it is *not* an error and *not* EOF. `bufio.Reader.Read` documents "The bytes are taken from at most one Read on the underlying Reader, hence n may be less than len(p). To read exactly len(p) bytes, use io.ReadFull(b, p)." (`bufio.go`). In contrast `ReaderAt.ReadAt` is stricter: "When ReadAt returns n < len(p), it returns a non-nil error explaining why more bytes were not returned. In this respect, ReadAt is stricter than Read." (`io.go`).

## 8. Timeouts

- **No timeout concept in `io` or `bufio`.** The interfaces have no deadline parameter and no cancellation; `Copy`, `ReadAll`, `ReadFull` will block forever on a stream that never ends (`io.go`, all signatures).
- **Timeouts belong to the concrete transport.** `net.Conn` exposes `SetDeadline`, `SetReadDeadline`, `SetWriteDeadline`, taking an *absolute* `time.Time`; "A deadline is an absolute time after which I/O operations fail instead of blocking. The deadline applies to all future and pending I/O, not just the immediately following call to Read or Write." (`net.go`, `Conn` doc). Deadline expiry yields an error wrapping `os.ErrDeadlineExceeded`, testable with `errors.Is` (`net.go`).
- **`os.File` also supports deadlines** "Only some kinds of files support setting a deadline… On most systems ordinary files do not support deadlines, but pipes do." (`os/file.go`, `File.SetDeadline` doc).
- **Cancellation of connection setup uses `context.Context`** (`Dialer.DialContext`, `Dial` with ctx): `net.mapErr` maps `context.Canceled`/`context.DeadlineExceeded` onto net errors (`net.go`, `mapErr`).
- **The deadline model is "arm a timer on the fd", not "wrap a future"**: an idle timeout is "implemented by repeatedly extending the deadline after successful Read or Write calls" (`net.go`).
- `timeoutError` renders "i/o timeout" and `Is(context.DeadlineExceeded)` returns true (`net.go`).

## 9. End-of-stream and error signalling

- **EOF is a sentinel *error value*, `io.EOF`** — returned in the `err` slot, not a separate return channel (`io.go`, `EOF` doc).
- **A read may return data and EOF together.** "An instance of this general case is that a Reader returning a non-zero number of bytes at the end of the input stream may return either err == EOF or err == nil. The next Read should return 0, EOF." (`io.go`, `Reader` doc).
- **A short read is not EOF and not an error.** `n < len(p)` with `err == nil` just means less data was available this call (`io.go`, `Reader` doc: "It is not an error if the returned value n is smaller than the buffer size, even when the reader is not at the end of the stream yet.").
- **A zero read with nil error is ambiguous and discouraged.** "Implementations of Read are discouraged from returning a zero byte count with a nil error, except when len(p) == 0. Callers should treat a return of 0 and nil as indicating that nothing happened; in particular it does not indicate EOF." (`io.go`, symbol `Reader`, doc comment). Repeated `0, nil` is what `io.ErrNoProgress` guards against (`io.go`, symbol `ErrNoProgress`); `bufio.Reader.fill` returns `io.ErrNoProgress` after `maxConsecutiveEmptyReads = 100` empty reads (`bufio.go`, symbol `fill`).
- **EOF is suppressed where it is not a failure**: `Copy` "does not treat an EOF from Read as an error to be reported"; `ReadAll`/`os.ReadFile` turn EOF into `err == nil` (`io.go`, `Copy`/`ReadAll` docs; `os/file.go`, `ReadFile` doc).
- **Premature EOF gets its own error**: `ReadFull`/`ReadAtLeast` return `ErrUnexpectedEOF` if EOF arrives after some but not all bytes (`io.go`); `os.File.ReadAt` "At end of file, that error is io.EOF." (`os/file.go`).
- **Writes signal failure via `ErrShortWrite`**: `Write` "must return a non-nil error if it returns n < len(p)"; `os.File.Write` maps a short write to `io.ErrShortWrite` (`io.go`; `os/file.go`, `File.Write` doc). `copyBuffer` synthesizes `ErrShortWrite` when `nr != nw` (`io.go`).
- **Pipe closure is distinguishable from EOF**: `ErrClosedPipe` is returned for read/write on a closed pipe; closing the write end yields EOF to readers (`io/pipe.go`).
- **Scanner swallows EOF**: "if it was io.EOF, Scanner.Err will return nil" (`scan.go`, `Scanner.Err` doc).

## 10. Interesting design decisions

- **Minimal interface, maximum composition.** `Reader` is one method; the rest of the ecosystem plugs together via type assertions and adapter types (`io.go`; `LimitReader`, `SectionReader`, `TeeReader`, `MultiReader`). (Assessment: derived from the `io.go` API surface.)
- **`(n, err)` dual return.** The count and the error are separate, so partial success is always representable without a `Result<T, Partial>` type. The cost is the "always process n before err" rule (`io.go`, `Reader` doc).
- **EOF designed as a sentinel, not an error kind.** `io.EOF` is compared by `==` and deliberately must not be wrapped; this makes the common loop cheap but is fragile with middleware (`io.go`, `EOF` doc).
- **Duck-typed optional capabilities.** `ReaderFrom`/`WriterTo` let *either* side of a copy take over the fast path without changing any signature (`io.go`, `copyBuffer`: "If the reader has a WriteTo method, use it to do the copy. Avoids an allocation and a copy."). This is a prototype of "specialization by interface assertion".
- **`ReadFull`/`ReadAtLeast` as *free functions*, not methods.** Exactly-once semantics are built on top of partial reads instead of being a separate primitive (`io.go`).
- **Buffered reader exposes its buffer.** `Peek`, `Buffered`, `ReadSlice`, `AvailableBuffer` return borrowed slices valid only until the next call, enabling zero-copy parsing (`bufio.go`).
- **`Scanner.SplitFunc` as an injectable tokenizer.** `(advance, token, err)` with `atEOF` is a clean, testable streaming-parse protocol with an `ErrFinalToken` escape hatch for a trailing token (`scan.go`, `SplitFunc` doc).
- **Synchronous in-memory `io.Pipe`.** Two goroutines rendezvous over channels with no buffer, giving backpressure for free (`io/pipe.go`).
- **Large operations bypass the buffer.** Both `bufio.Reader.Read` and `bufio.Writer.Write` detect oversized single operations and go straight to the underlying stream, avoiding a double copy (`bufio.go`).
- **`AvailableBuffer()` + `Write` contract.** The writer hands out its spare capacity so callers can append and hand it straight back, a deliberately unsafe-but-fast pattern (`bufio.go`, `AvailableBuffer` doc: "The buffer is only valid until the next write operation on b").

## 11. Decisions NOT to copy

- **Sentinel-based EOF and `==` comparison.** `io.EOF` must be returned unwrapped and compared by identity; any middleware that wraps it breaks callers. MojoAkku should make end-of-stream an explicit, typed outcome, not a magic error value (`io.go`, `EOF` doc).
- **`(value, error)` dual return is not expressible in Mojo.** Mojo has `raises` and no multiple returns; the partial-read case must be modelled as a count out-parameter plus a typed raise, not as two return slots (Go-specific; Assessment: derived from the `Reader` signature).
- **`nil` returned in an interface can be non-nil.** A typed nil pointer stored in an interface is `!= nil`, a classic Go trap; not a pattern to import (Assessment: known Go semantics, derived from `io`'s interface-returning helpers such as `NopCloser`).
- **Zero read with nil error is legal-but-undefined.** `0, nil` means "nothing happened", which forces `ErrNoProgress` heuristics (`bufio.go` `maxConsecutiveEmptyReads`). A predictable API should forbid or type this state (Assessment: derived from `io.go` `Reader` doc + `bufio.go` `fill`).
- **`panic` on a misbehaving implementation.** `bufio` panics on negative read counts ("bufio: reader returned negative count from Read") and on a full-buffer fill (`bufio.go`, `fill`, `errNegativeRead`). Mojo should raise, not abort (`bufio.go`).
- **Deadlines as mutable state on the stream.** `SetDeadline` mutates the connection and applies to all future *and pending* I/O; an absolute-time global mutation is hard to reason about in a value-semantics language. Prefer passing a timeout/cancellation per operation (Assessment: derived from `net.go` `Conn` doc).
- **`ReaderAt`'s stricter "error on short read" rule vs `Reader`'s lenient rule.** Two interfaces with subtly different short-read semantics for the same concept increase cognitive load (`io.go`, `ReaderAt` doc).
- **Goroutine-per-connection as the default model.** Cheap in Go, but it is a runtime property, not an API design; MojoAkku should not assume a green-thread runtime exists (`net.go`, package doc example).
- **`Read` may scribble on the whole buffer.** "Even if Read returns n < len(p), it may use all of p as scratch space during the call" (`io.go`) — surprising and hostile to `borrowed` reasoning; keep the read region well-defined.
- **Text as invisible duck-typing.** `WriteString` silently changes behavior depending on whether the writer implements `StringWriter` (`io.go`); explicit capability selection is preferable.

## 12. Ideas fitting Mojo

- **`Reader`/`Writer` as one-method traits mirror `mojov1`'s `Writer`/`Writable`.** The README notes the stdlib already has a write trait and no `Reader`; the natural Mojo shape is a symmetric `Reader` trait with a single required method, plus provided helpers — same required-vs-provided split the stdlib `Writer` uses (`mojov1/stdlib/io`, `format`).
- **Partial read as a `raises`-typed contract with an explicit count.** Modelled on `Reader.Read`: `fn read(mut self, buffer: Span[Byte]) raises ReadError -> Int` returning the number of bytes consumed; the count is the success value, the error is distinct, avoiding Go's two-slot return (Assessment: derived from `io.go` + Mojo `raises`).
- **`var`/`borrowed` express exactly Go's buffer contract.** "Implementations must not retain p" maps to taking a `borrowed`/mutable buffer and guaranteeing no escape; the caller stays the owner (`io.go`, `Reader` doc).
- **`ReadFull`/`ReadAtLeast` as free `fn`s over the `Reader` trait.** Keeps the trait minimal and pushes "exactly N" semantics into a testable helper (`io.go`).
- **`ReaderFrom`/`WriterTo` as compile-time specialization.** Go's duck-typed fast path becomes a Mojo `alias`/trait dispatch decided at compile time, with no runtime type assertion (`io.go`, `copyBuffer`).
- **Tokenizing via a split function is a good fit for `comptime`/generics.** `Scanner.SplitFunc` (advance, token, atEOF) is a small pure interface that can be a Mojo trait or a generic parameter (`scan.go`).
- **Buffering as a composable struct with fixed-capacity storage.** `bufio.Reader`'s state is just a byte buffer plus three ints; in Mojo that is a value-semantics struct with a fixed-size array, and `buffered`/`peek` map to `borrowed` returns (`bufio.go`, `Reader` struct).
- **EOF as a distinct typed signal, not a sentinel.** Model Go's three outcomes (data, end-of-stream, failure) as a small enum or as `raises EndOfStream` / `raises ReadError`, so "short read ≠ EOF ≠ error" is explicit (`io.go`; Assessment: derived from the Go EOF/`0,nil`/`ErrUnexpectedEOF` tangle).
- **Deadline/timeout as an explicit per-operation value.** Instead of Go's mutable `SetDeadline`, pass an optional timeout to a read/write call; Mojo value semantics make this cheap to copy and hard to leave stale (`net.go`).

## Sources

- Go stdlib `io`: https://raw.githubusercontent.com/golang/go/master/src/io/io.go (symbols `Reader`, `Writer`, `EOF`, `Copy`, `ReadFull`, `ReaderAt`, `ReaderFrom`, `WriterTo`, …)
- Go stdlib `io/multi.go`: https://raw.githubusercontent.com/golang/go/master/src/io/multi.go (`MultiReader`, `MultiWriter`)
- Go stdlib `io/pipe.go`: https://raw.githubusercontent.com/golang/go/master/src/io/pipe.go (`Pipe`, `PipeReader`, `PipeWriter`, `ErrClosedPipe`)
- Go stdlib `bufio`: https://raw.githubusercontent.com/golang/go/master/src/bufio/bufio.go (`Reader`, `Writer`, `defaultBufSize`, `maxConsecutiveEmptyReads`)
- Go stdlib `bufio` scanner: https://raw.githubusercontent.com/golang/go/master/src/bufio/scan.go (`Scanner`, `SplitFunc`, `ScanLines`, `ErrFinalToken`)
- Go stdlib `os`: https://raw.githubusercontent.com/golang/go/master/src/os/file.go (`File`, `ReadFile`, `WriteFile`, deadlines)
- Go stdlib `net`: https://raw.githubusercontent.com/golang/go/master/src/net/net.go (`Conn`, `OpError`, `SetDeadline`, `timeoutError`, `mapErr`)
- Go stdlib `errors`: https://raw.githubusercontent.com/golang/go/master/src/errors/wrap.go (`Is`, `As`, `AsType`, `Unwrap`)
- `valyala/bytebufferpool`: https://github.com/valyala/bytebufferpool
- `cloudwego/netpoll`: https://github.com/cloudwego/netpoll ; license https://github.com/cloudwego/netpoll/blob/main/LICENSE (Apache-2.0)
- `panjf2000/gnet`: https://github.com/panjf2000/gnet (README, license section)
- `golang.org/x/net`: https://pkg.go.dev/golang.org/x/net
- Mojo Akku `io` run config: `akku/io_core/_dev/README.md`
