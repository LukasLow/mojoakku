# io research: Python

## 1. Standard library support

Python's stream abstraction is the `io` module — "Core tools for working with
streams". Source: <https://docs.python.org/3/library/io.html>.

`io` separates three categories of I/O — **text I/O**, **binary I/O** (also
"buffered I/O") and **raw I/O** (also "unbuffered I/O") — and calls any concrete
object in one of them a **file object**, also "stream" or "file-like object".
Independent of category a stream is read-only, write-only or read-write, and is
either randomly seekable or sequential-only "for example in the case of a socket
or pipe". Source: <https://docs.python.org/3/library/io.html>.

The class hierarchy is a three-layer ABC stack, with the in-memory and
OS-backed concrete classes hanging off it (Source:
<https://docs.python.org/3/library/io.html>):

- `IOBase` — "the abstract base class for all I/O classes"; "there is no
  separation between reading and writing to streams" here.
- `RawIOBase(IOBase)` — "Base class for raw binary streams"; `FileIO` subclasses
  it for OS files.
- `BufferedIOBase(IOBase)` — "Base class for binary streams that support some
  kind of buffering"; subclasses `BufferedWriter`, `BufferedReader`,
  `BufferedRWPair`, `BufferedRandom`, plus in-memory `BytesIO`.
- `TextIOBase(IOBase)` — "Base class for text streams"; subclasses
  `TextIOWrapper` and in-memory `StringIO`.

The module's own docstring states the layering explicitly: `TextIOWrapper` "is a
buffered text interface to a buffered raw stream (`BufferedIOBase`)". Source:
<https://raw.githubusercontent.com/python/cpython/3.14/Lib/io.py>.

High-level entry points (Source: <https://docs.python.org/3/library/io.html>):
`io.open()` (an alias for the builtin `open()`), `io.open_code(path)`,
`io.text_encoding(encoding, stacklevel=2, /)`, the constant
`io.DEFAULT_BUFFER_SIZE`, and the exceptions `io.BlockingIOError` (alias of
`BlockingIOError`) and `io.UnsupportedOperation`. The standard streams live in
`sys`: `sys.stdin`, `sys.stdout`, `sys.stderr`.

Since Python 3.14 the module also defines two **structural (PEP 544) protocols**
for typing, both `@typing.runtime_checkable` and both "only support blocking
I/O" (Source: <https://docs.python.org/3/library/io.html>,
<https://raw.githubusercontent.com/python/cpython/3.14/Lib/io.py>):

```python
class Reader(metaclass=abc.ABCMeta):
    @abc.abstractmethod
    def read(self, size=..., /): ...   # "at most size items (bytes/characters)"

class Writer(metaclass=abc.ABCMeta):
    @abc.abstractmethod
    def write(self, data, /): ...      # "return the number of items written"
```

(The excerpt above is transcribed from the 3.14 `Lib/io.py`; the docs describe
the same two names as "Generic protocol for reading/writing … `T` will usually
be `str` or `bytes`". Source: <https://docs.python.org/3/library/io.html>.)

Outside `io`, the stdlib offers two adjacent stream surfaces:

- **`asyncio.streams`** — "high-level async/await-ready primitives to work with
  network connections", in `asyncio.StreamReader` / `asyncio.StreamWriter`.
  Source: <https://docs.python.org/3/library/asyncio-stream.html>.
- **`socket.makefile()`** — "Other library modules may provide additional ways to
  create text or binary streams. See `socket.socket.makefile()` for example."
  Source: <https://docs.python.org/3/library/io.html>.

There is no `readall`-style generic *reader trait* in `io` beyond the 3.14
typing protocol above: `IOBase` "does not declare `read()` or `write()` because
their signatures will vary". Source:
<https://docs.python.org/3/library/io.html>.

## 2. Relevant community libraries

- **aiofiles** — file support for asyncio, author Tin Tvrtkovic
  (`github.com/Tinche/aiofiles`), license Apache-2.0, Development Status
  "5 - Production/Stable", latest 25.1.0 (2025-10-09). It "delegat[es]
  operations to a separate thread pool" and mirrors the builtin `open` API with
  coroutine versions of `read`, `read1`, `readinto`, `readline`, `write`, `seek`
  etc. Sources: <https://pypi.org/project/aiofiles/>.
- **anyio** — "an asynchronous networking and concurrency library that works on
  top of either asyncio or Trio", author Alex Grönholm, license MIT, Development
  Status "5 - Production/Stable", latest 4.15.1 (2026-09-05). It offers "a
  versatile API for byte streams and object streams" and splits streams into
  **byte streams** and **object streams**, with wrappers `BufferedByteReceiveStream`,
  `TextReceiveStream`/`TextSendStream`, `FileReadStream`/`FileWriteStream`,
  `StapledByteStream` and `TLSStream`. Sources:
  <https://pypi.org/project/anyio/>, <https://anyio.readthedocs.io/en/stable/streams.html>.
- **Trio** — the async library whose stream ABCs AnyIO mirrors: `SendStream`,
  `ReceiveStream`, `Stream`, `HalfCloseableStream`, plus `StapledStream` and
  `SSLStream`; the docs call it "a set of abstract base classes that define a
  standard interface for unidirectional and bidirectional byte streams".
  `GUESS:` Trio's license is not stated on the fetched `reference-io` page, so it
  is omitted here. Source: <https://trio.readthedocs.io/en/stable/reference-io.html>.
- **`selectors`** — stdlib, not community, but the readiness layer that sync
  non-blocking stream code is built on: "This module allows high-level and
  efficient I/O multiplexing … to wait for I/O readiness notification on multiple
  file objects." Source: <https://docs.python.org/3/library/selectors.html>.

The reference signal for Python streaming is dominated by stdlib `io` + the two
async frameworks: every other async file/stream package either wraps `io` (as
aiofiles does) or defines a parallel byte-stream ABC pair (as Trio/AnyIO do).
(Assessment: derived from the aiofiles PyPI page, the AnyIO docs and the Trio
reference.)

## 3. Exposed APIs

`open()` builtin / `io.open` (Source:
<https://docs.python.org/3/library/functions.html#open>):

```python
open(file, mode='r', buffering=-1, encoding=None, errors=None,
     newline=None, closefd=True, opener=None)
```

Modes are `r/w/x/a` plus `b` (binary), `t` (text, default) and `+` (read+write);
`buffering=0` means off (binary only), `1` means line buffering (text write
only), `>1` is a fixed-size chunk buffer in bytes. Sources:
<https://docs.python.org/3/library/functions.html#open>.

`IOBase` (Source: <https://docs.python.org/3/library/io.html>):
`close()`, `closed`, `fileno()`, `flush()`, `isatty()`, `readable()`,
`readline(size=-1, /)`, `readlines(hint=-1, /)`, `seek(offset, whence=SEEK_SET, /)`,
`seekable()`, `tell()`, `truncate(size=None, /)`, `writable()`,
`writelines(lines, /)`, `__iter__`/`__next__`, context-manager
`__enter__`/`__exit__`, and `__del__()` which "calls the instance's `close()`".

`RawIOBase` (Source: <https://docs.python.org/3/library/io.html>):

- `read(size=-1, /)` — "Attempts to make only one system call … fewer than *size*
  bytes may be returned"; `0` bytes at non-EOF means EOF; `None` when non-blocking
  and nothing is available.
- `readall()` — loops until EOF.
- `readinto(b, /)` — "Read bytes into a pre-allocated, writable bytes-like object
  *b*, and return the number of bytes read."
- `write(b, /)` — returns bytes written, "can be less than the length of *b*";
  `None` if non-blocking and no byte could be written.

`BufferedIOBase` (Source: <https://docs.python.org/3/library/io.html>):
`raw`, `detach()`, `read(size=-1, /)`, `read1(size=-1, /)`,
`readinto(b, /)`, `readinto1(b, /)`, `write(b, /)`. `read1`/`readinto1` make "at
most one call to the underlying raw stream"; `write` "return[s] the number of
bytes written (always equal to the length of *b*)".

`TextIOBase` (Source: <https://docs.python.org/3/library/io.html>): `encoding`,
`errors`, `newlines`, `buffer`, `detach()`, `read(size=-1, /)`,
`readline(size=-1, /)`, `seek(offset, whence=SEEK_SET, /)`, `tell()`,
`write(s, /)` (returns characters written).

`TextIOWrapper(buffer, encoding=None, errors=None, newline=None,
line_buffering=False, write_through=False)` — `newline` selects universal-newline
translation on read and `'\n'` translation on write; `line_buffering` flushes on
newline; `write_through` guarantees "any data written … is immediately handled to
its underlying binary *buffer*". Source:
<https://docs.python.org/3/library/io.html>.

`BytesIO(initial_bytes=b'')` adds `getbuffer()` (a read/write view over the
buffer "without copying them"), `getvalue()`, `read1`, `readinto1`. Source:
<https://docs.python.org/3/library/io.html>.

`BufferedReader` adds `peek(size=0, /)`; `BufferedWriter` flushes when the buffer
is full, on `flush()`, on `seek()` for `BufferedRandom`, and "when the
`BufferedWriter` object is closed or destroyed". Source:
<https://docs.python.org/3/library/io.html>.

`asyncio.StreamReader` / `StreamWriter` (Source:
<https://docs.python.org/3/library/asyncio-stream.html>):

- `StreamReader.read(n=-1)`, `readline()`, `readexactly(n)`,
  `readuntil(separator=b'\n')`, `at_eof()`, `feed_eof()`; async-iterable.
- `StreamWriter.write(data)` (sync, queues on failure), `writelines(data)`,
  `drain()` (flow control), `close()`, `wait_closed()`, `can_write_eof()`,
  `write_eof()`, `islosing()`, `transport`, `get_extra_info(name, default=None)`,
  `start_tls(...)`.

Factories: `asyncio.open_connection(...)`, `start_server(...)`,
`open_unix_connection(...)`, `start_unix_server(...)`, all with `limit=65536`
("buffer size limit used by the returned `StreamReader`"). Source:
<https://docs.python.org/3/library/asyncio-stream.html>.

AnyIO (Source: <https://anyio.readthedocs.io/en/stable/streams.html>):
`ByteStream` = `ByteReceiveStream` (`receive()`, `receive_exactly(n)`,
`receive_until(delimiter, max_bytes)`, `feed_data(...)`) +
`ByteSendStream` (`send(data)`, `send_eof()`); `TextReceiveStream` /
`TextSendStream`; `FileReadStream.from_path(p)` / `FileWriteStream.from_path(p)`;
`create_memory_object_stream[...](buffer_size)` (default buffer size 0, so
`send()` blocks until a receiver calls `receive()`).

## 4. Error representation

Errors on the stream layer are **exceptions**, never sentinel return codes
(Source: <https://docs.python.org/3/library/io.html>):

- `OSError` for I/O failures; `IOError` "is now an alias of `OSError`" since
  Python 3.3.
- `BlockingIOError` (aliased as `io.BlockingIOError`) for a would-block condition
  on a non-blocking stream; on write it carries
  `BlockingIOError.characters_written`.
- `UnsupportedOperation` — "An exception inheriting `OSError` and `ValueError`
  that is raised when an unsupported operation is called on a stream."
- `ValueError` "may be raised in this case" when any method is called on a closed
  stream.
- `TypeError` for a data-kind mismatch: "giving a `str` object to the `write()`
  method of a binary stream will raise a `TypeError`. So will giving a `bytes`
  object to the `write()` method of a text stream."

**EOF is not an error**: `read()` returns "an empty `bytes` object … if the
stream is already at EOF", an empty `str` for text. Source:
<https://docs.python.org/3/library/io.html>.

The raw layer deliberately uses a **partial-write count, not an exception**: the
docs carry a warning that `RawIOBase.write()` "does not ensure all bytes are
written or an exception is thrown"; the caller must loop. Source:
<https://docs.python.org/3/library/io.html>.

asyncio adds two stream-specific exceptions (Source:
<https://docs.python.org/3/library/asyncio-stream.html>):

- `IncompleteReadError` — raised by `readexactly(n)` "if EOF is reached before
  *n* can be read"; the partial data is on `.partial`. Also raised by
  `readuntil(separator)` when EOF arrives before the separator.
- `LimitOverrunError` — raised by `readuntil` "if the amount of data read exceeds
  the configured stream limit"; the data "is left in the internal buffer and can
  be read again".

Trio/AnyIO turn stream failure into three distinct exception types (Source:
<https://trio.readthedocs.io/en/stable/reference-io.html>):
`BrokenResourceError` ("something has gone wrong, and the stream is broken"),
`ClosedResourceError` ("you previously closed this stream object"), and
`BusyResourceError` ("another task is already executing a `send_all()` … on this
stream"). AnyIO's memory streams add `BrokenResourceError` when the peer end is
closed (<https://anyio.readthedocs.io/en/stable/streams.html>).

Cancellation is its own base exception: `asyncio.CancelledError` "directly
subclasses `BaseException`". Source:
<https://docs.python.org/3/library/asyncio-task.html#task-cancellation>.

## 5. Ownership semantics

Python is fully memory-managed, so there is no manual free of stream, buffer or
buffered state. Ownership questions reduce to *who may mutate which bytes* and
*when a handle is released*.

- **Read results are new owned objects.** `read()`/`readline()` on a binary
  stream return a fresh `bytes` (immutable); text streams return a fresh `str`.
  Source: <https://docs.python.org/3/library/io.html>.
- **Caller-owned output buffers.** `readinto(b, /)` writes into a
  "pre-allocated, writable bytes-like object *b*" (e.g. a `bytearray`) supplied
  by the caller and returns only the count. Source:
  <https://docs.python.org/3/library/io.html>.
- **The implementation may only touch input during the call.** For
  `RawIOBase.write(b)` and `BufferedIOBase.write(b)`: "The caller may release or
  mutate *b* after this method returns, so the implementation should only access
  *b* during the method call." Source: <https://docs.python.org/3/library/io.html>.
  (Assessment: this is the stdlib's explicit no-retained-reference contract.)
- **Handle ownership is caller-owned and explicit.** `FileIO` with an integer fd
  wraps an existing OS descriptor and "When the FileIO object is closed this fd
  will be closed as well, unless *closefd* is set to `False`." `open()`'s
  `closefd=False` gives the same escape hatch. Source:
  <https://docs.python.org/3/library/io.html>.
- **Release path.** `IOBase` is a context manager, so `with` closes on every exit
  path; `__del__()` "calls the instance's `close()`"; `close()` is idempotent
  ("only the first call … will have an effect"). Source:
  <https://docs.python.org/3/library/io.html>.
- **Buffer state is owned by the stream object.** `BufferedIOBase.detach()`
  "Separate[s] the underlying raw stream from the buffer"; "After the raw stream
  has been detached, the buffer is in an unusable state." Source:
  <https://docs.python.org/3/library/io.html>.
- **Zero-copy view pins the owner.** `BytesIO.getbuffer()` returns "a readable
  and writable view over the contents of the buffer without copying them"; "As
  long as the view exists, the `BytesIO` object cannot be resized or closed."
  Source: <https://docs.python.org/3/library/io.html>.
- **Async stream ownership transfer.** In asyncio, `open_connection`'s `sock`
  argument "transfers ownership of the socket to the `StreamWriter` created. To
  close the socket, call its `close()` method." Source:
  <https://docs.python.org/3/library/asyncio-stream.html>.

## 6. Blocking / non-blocking

The default is **blocking, synchronous** I/O. The `io.Reader`/`io.Writer` typing
protocols say it outright: "This protocol only supports blocking I/O." Source:
<https://raw.githubusercontent.com/python/cpython/3.14/Lib/io.py>.

Non-blocking is a property of the underlying raw stream, and the layer above
inherits a *mixed* contract (Source: <https://docs.python.org/3/library/io.html>):

- `RawIOBase.read()` "If the object is in non-blocking mode and no bytes are
  available, `None` is returned."
- `RawIOBase.write()` "`None` is returned if the raw stream is set not to block
  and no single byte could be readily written to it."
- `BufferedIOBase`: "if the underlying raw stream is in non-blocking mode, when
  the system returns would block `write()` will raise `BlockingIOError` … and
  `read()` will return data read so far or `None` if no data is available."
- Text I/O: "read operations on text I/O objects might raise a
  `BlockingIOError` if the stream cannot perform the operation immediately."
- `BlockingIOError` from a buffered write carries `BlockingIOError.characters_written`.

Readiness instead of polling is `selectors`: `BaseSelector.select(timeout=None)`
"Wait until some registered file objects become ready, or the timeout expires".
Source: <https://docs.python.org/3/library/selectors.html>.

Concurrency is a *separate* stack, not a mode of the stream object:

- **asyncio**: cooperative, single-threaded; `StreamReader.read()` etc. are
  coroutines; write-side flow control is explicit via `await writer.drain()`,
  which "blocks until the size of the buffer is drained down to the low
  watermark". Source: <https://docs.python.org/3/library/asyncio-stream.html>.
  `asyncio.to_thread()` moves blocking I/O off the loop.
- **aiofiles**: local files "cannot easily and portably be made asynchronous", so
  it transparently "delegat[es] operations to a separate thread pool". Source:
  <https://pypi.org/project/aiofiles/>.
- **AnyIO/Trio**: structured concurrency; AnyIO runs the same API on asyncio or
  Trio. Sources: <https://pypi.org/project/anyio/>,
  <https://trio.readthedocs.io/en/stable/reference-io.html>.

Thread-safety is layered (Source: <https://docs.python.org/3/library/io.html>):
`FileIO` is OS-call-thread-safe, binary buffered objects "protect their internal
structures using a lock", but `TextIOWrapper` "objects are not thread-safe".
Buffered objects are also **not reentrant**: re-entering from the same thread
raises `RuntimeError`.

## 7. Byte streams vs text streams

The distinction is **static, by class and by accepted type**, not by a flag
(Source: <https://docs.python.org/3/library/io.html>):

- Binary streams expect and produce `bytes`; text streams expect and produce
  `str`. Mixing them raises `TypeError`.
- Buffering is **layered**: raw (`RawIOBase`, unbuffered, one syscall) → buffered
  binary (`BufferedIOBase`, chunked reads/writes) → text (`TextIOBase`, codec +
  newline translation over a buffered binary stream). "A typical
  `BufferedIOBase` implementation should not inherit from a `RawIOBase`
  implementation, but wrap one, like `BufferedWriter` and `BufferedReader` do."
- The text layer's `buffer` attribute exposes the underlying binary stream;
  `detach()` unhooks it.

Partial reads are reported by **returning fewer bytes, never by a distinct
"partial" type** (Source: <https://docs.python.org/3/library/io.html>):

- `BufferedIOBase.read(size=-1)`: "Fewer bytes may be returned than requested.
  … Less than size bytes being returned does not imply that EOF is imminent."
  `size=-1`/`None`/negative means "read as much as possible".
- `read1(size=-1, /)` — "call[s] `readinto()` which may retry if `EINTR` is
  encountered"; "the implementation will choose an arbitrary value for *size*" if
  `-1`. It is the "at most one underlying read" primitive used to hand control
  back quickly (typical for socket layers).
- `readinto(b, /)` / `readinto1(b, /)` — report partial consumption as an
  integer count into a caller buffer.
- `RawIOBase.read`: "Attempts to make only one system call … fewer than *size*
  bytes may be returned if the operating system call returns fewer than *size*
  bytes."
- `BufferedReader.peek(size=0, /)` — "Return bytes from the stream without
  advancing the position. The number of bytes returned may be less or more than
  requested."
- asyncio `StreamReader.read(n)`: "return at most *n* available `bytes` as soon
  as at least 1 byte is available in the internal buffer"; `readexactly(n)` is
  the "give me exactly n or fail" variant that raises `IncompleteReadError`.
  Source: <https://docs.python.org/3/library/asyncio-stream.html>.

Text-mode partial/chunked **decoding** is handled inside `TextIOWrapper`'s
incremental decoder; the wrapper is not part of the byte-layer contracts above.
(Assessment: derived from the class hierarchy and the `TextIOWrapper` description
at <https://docs.python.org/3/library/io.html>.)

## 8. Timeouts

The `io` module itself has **no timeout and no cancellation parameter** anywhere;
there is no timeout argument on `open()`, `read()`, `write()` or `flush()`.
(Assessment: derived from the full API listing at
<https://docs.python.org/3/library/io.html> and the `open()` signature at
<https://docs.python.org/3/library/functions.html#open>.)

Timeouts live one layer down or one layer up:

- **Sockets**: `socket` supports non-blocking via `setblocking()` and timeouts
  via `settimeout()`; a timeout raises `socket.timeout`, which since 3.10 "was
  made an alias of `TimeoutError`" and is "a subclass of `OSError`". Source:
  <https://docs.python.org/3/library/socket.html>.
- **Multiplexing**: `selectors.BaseSelector.select(timeout=None)` — `timeout > 0`
  is "the maximum wait time, in seconds"; `<= 0` means "won't block". Source:
  <https://docs.python.org/3/library/selectors.html>.
- **asyncio**: `asyncio.timeout(delay)` is "an asynchronous context manager that
  can be used to limit the amount of time spent waiting"; on expiry it "cancel[s]
  the current task and handle[s] the resulting `asyncio.CancelledError`
  internally, transforming it into a `TimeoutError`". `asyncio.wait_for(aw,
  timeout)` cancels `aw` and raises `TimeoutError`. Source:
  <https://docs.python.org/3/library/asyncio-task.html#timeouts>.
- **Cancellation**: `Task.cancel()` "will cause the Task to throw a
  `CancelledError` exception into the wrapped coroutine"; `asyncio.shield(aw)`
  protects a task from caller cancellation. Source:
  <https://docs.python.org/3/library/asyncio-task.html>.
- **Trio/AnyIO**: cancellation is delivered at checkpoints; Trio documents that a
  low-level operation raising `trio.Cancelled` guarantees no effect — *except*
  `send_all()`, which "may have sent some, all, or none of the requested data,
  and there is no way to know which". Source:
  <https://trio.readthedocs.io/en/stable/reference-io.html>.
- **aiofiles** has no timeout parameter of its own; a timeout would have to be
  the surrounding `asyncio.timeout`. (Assessment: derived from the listed
  coroutine methods at <https://pypi.org/project/aiofiles/>.)

## 9. End-of-stream and error signalling

EOF is a **value**, an error is an **exception**, and "would block" is a **third
state (`None`)** — three distinct signals (Source:
<https://docs.python.org/3/library/io.html>):

| condition | signal |
| --- | --- |
| EOF | `b''` (binary) / `''` (text); `readline()` "an empty string is returned" |
| 0 bytes from `readinto` with `len(b) != 0` | "this indicates end of file" |
| non-blocking, no data | `None` ("io implementations return `None`") |
| would-block on a buffered write | `BlockingIOError` (+ `.characters_written`) |
| I/O failure | `OSError` / subclass |
| unsupported operation | `UnsupportedOperation` (is-a `OSError`, `ValueError`) |
| closed stream | `ValueError` "may" be raised on any operation |

Note that "a short read is not an error": `BufferedIOBase.read` explicitly says
"Less than size bytes being returned does not imply that EOF is imminent."
Source: <https://docs.python.org/3/library/io.html>.

asyncio makes the distinction sharper (Source:
<https://docs.python.org/3/library/asyncio-stream.html>):

- `read()` → empty `bytes` at EOF; `readline()` → "partially read data" if EOF
  without a newline, empty `bytes` if the buffer is empty.
- `at_eof()` is `True` only "if the buffer is empty and `feed_eof()` was called"
  — i.e. buffered EOF is not yet "at EOF" to the reader.
- A **truncated** expected read is an exception: `readexactly(n)` →
  `IncompleteReadError` with `.partial`; `readuntil` → `IncompleteReadError`
  (buffer reset) or `LimitOverrunError` (buffer kept).

Trio/AnyIO define the receive-side EOF the same way and are explicit that it must
be exact: "A return value of `b""` … indicates that the stream has reached
end-of-file. Implementations should be careful that they return `b""` if, and
only if, the stream has reached end-of-file!" Source:
<https://trio.readthedocs.io/en/stable/reference-io.html>.

## 10. Interesting design decisions

- **Three layers as three ABCs, not one class.** `RawIOBase` → `BufferedIOBase` →
  `TextIOBase`, each wrapping the one below, with `raw`/`buffer`/`detach()` to
  peel layers. Sources: <https://docs.python.org/3/library/io.html>,
  <https://raw.githubusercontent.com/python/cpython/3.14/Lib/io.py>.
- **ABCs ship partial default implementations.** "The abstract base classes also
  provide default implementations of some methods in order to help implementation
  of concrete stream classes. For example, `BufferedIOBase` provides unoptimized
  implementations of `readinto()` and `readline()`." Source:
  <https://docs.python.org/3/library/io.html>.
- **`read1`/`readinto1` as the explicit "one syscall, then yield" primitive.**
  This is the socket-friendly contract that separates "read what's cheap" from
  "read as much as possible". Source: <https://docs.python.org/3/library/io.html>.
- **Three-valued read result (bytes | `None` | `b''`).** `None` = would block,
  `b''` = EOF, data = progress. Source: <https://docs.python.org/3/library/io.html>.
- **Partial progress carried *inside* the exception.** `BlockingIOError.characters_written`
  lets a failed buffered write report how much made it out. Source:
  <https://docs.python.org/3/library/io.html>.
- **`detach()` makes the "buffer in an unusable state" explicit** rather than
  leaving a silently-shared buffer. Source: <https://docs.python.org/3/library/io.html>.
- **Structural typing protocols (`io.Reader[T]`/`io.Writer[T]`, 3.14)** — a
  nominal ABC hierarchy *plus* a duck-typed protocol for annotations. Sources:
  <https://docs.python.org/3/library/io.html>,
  <https://raw.githubusercontent.com/python/cpython/3.14/Lib/io.py>.
- **Newline policy as a first-class parameter** with four documented behaviours
  (`None`/`''`/`'\n'`/`'\r\n'`) instead of hard-coding platform newlines.
  Source: <https://docs.python.org/3/library/io.html>.
- **asyncio separates the halves**: reader owns the read buffer and `limit`,
  writer owns flow control (`drain`) and lifecycle (`close`/`wait_closed`).
  Source: <https://docs.python.org/3/library/asyncio-stream.html>.
- **AnyIO's byte-vs-object stream split** (bytes for sockets, objects/queues for
  producer-consumer) with a `buffer_size=0` default that makes `send()` a
  rendezvous. Source: <https://anyio.readthedocs.io/en/stable/streams.html>.
- **`receive_exactly`/`receive_until` as buffered decorators**, not methods on the
  raw stream — buffering is a wrapper. Source:
  <https://anyio.readthedocs.io/en/stable/streams.html>.

## 11. Decisions NOT to copy

- **One base class for read and write.** `IOBase` says "there is no separation
  between reading and writing to streams"; unsupported directions become runtime
  `UnsupportedOperation`. A compile-time-checked `Reader`/`Writer` split is
  better. Source: <https://docs.python.org/3/library/io.html>.
- **Exceptions as the only error channel, with `ValueError` for "closed stream"**
  — state errors, data errors and OS errors overlap and are ordered by a deep
  class hierarchy (`UnsupportedOperation` inherits both `OSError` *and*
  `ValueError`). Source: <https://docs.python.org/3/library/io.html>.
- **Mutable `bytearray`/`memoryview` as the `readinto` target.** Aliasing a
  caller buffer while the stream writes into it is a lifetime hazard a
  borrow-checked language should not reproduce unguarded. (Assessment: derived
  from the `readinto(b, /)` contract at
  <https://docs.python.org/3/library/io.html>.)
- **Newline translation in the core text wrapper.** Universal-newline magic in
  the lowest text layer surprises protocol code (e.g. HTTP) that must see bytes
  verbatim; MojoAkku's networking stack should keep translation opt-in and out of
  the byte path. (Assessment: derived from the `newline` semantics at
  <https://docs.python.org/3/library/io.html>.)
- **Locale-dependent default encoding.** "The default encoding … is
  locale-specific"; only Python 3.15 makes UTF-8 mode default. A predictable API
  should have no locale-dependent default. Sources:
  <https://docs.python.org/3/library/io.html>,
  <https://docs.python.org/3/library/functions.html#open>.
- **Overlapping entry points.** Builtin `open()` vs `io.open()`; `IOError` vs
  `OSError`; `socket.timeout` vs `TimeoutError` vs `BlockingIOError`. Pick one
  name per concept. Sources: <https://docs.python.org/3/library/io.html>,
  <https://docs.python.org/3/library/socket.html>.
- **`read(size=-1)` meaning "read everything until EOF"** as a default at the
  buffered layer — a memory-unbounded default. Source:
  <https://docs.python.org/3/library/io.html>.
- **`peek()` returning "less or more than requested"** — a non-obvious contract;
  if MojoAkku offers filling, make the guarantee exact. Source:
  <https://docs.python.org/3/library/io.html>.
- **Non-reentrancy of buffered objects** (`RuntimeError` on same-thread
  re-entry): the buffer lock is an implementation leak into observable semantics.
  Source: <https://docs.python.org/3/library/io.html>.

## 12. Ideas fitting Mojo

- **Two traits, `Read` and `Write`, mirroring the stdlib `Writer`/`Writable`
  pair.** Mojo's `io` already has `Writer` for text; add the missing `Read`
  counterpart with `read(mut self, ...)`. This directly closes the gap named in
  `_dev/README.md` ("no `Reader` trait and no generic byte/text stream
  abstraction"). (Assessment: derived from the Python trait split and the `mojov1`
  buch page `stdlib/io`, which records `Writer`/`Writable`.)
- **`raises`-typed errors instead of exceptions.** Model the Python taxonomy as
  distinct typed returns: an OS/IO error, a "stream is closed" error and an
  "unsupported direction" error, each declared with `raises`. Sources:
  <https://docs.python.org/3/library/io.html>, `mojov1` buch
  `appendix/cheat-sheet` ("Declare a typed error | `def f() raises MyError:`").
- **A three-valued read result rather than `None`/`b''` ambiguity.** A small
  `enum` or `struct` with `Read(n)`, `Eof`, `WouldBlock` replaces Python's
  bytes/`None`/`b''` triple; the result carries `nread` like
  `BlockingIOError.characters_written`. Source:
  <https://docs.python.org/3/library/io.html>.
- **`read_into(mut buffer)` with a caller-owned, `mut`-referenced buffer** —
  Mojo's ownership checker can enforce that the buffer is exclusively borrowed
  during the call, which Python's `readinto` cannot. (Assessment: derived from
  the `readinto` contract and the `imm`/`mut` conventions in `mojov1` buch
  `keyword-conventions/imm`.)
- **`imm`/`mut self` for the stream state.** A method advancing the cursor or
  filling a buffer declares `mut self`; pure inspection (`eof`, `is_closed`)
  takes bare `self` (= `imm`). Sources: `mojov1` buch `keyword-conventions/imm`
  and
  <https://docs.python.org/3/library/io.html>.
- **Layered stream structs with `comptime` buffer size.** Mirror
  raw/buffered/text as composable structs, and make the chunk size a `comptime`
  parameter so the common cases (unbuffered socket, fixed 4 KiB buffered) need no
  runtime branch. (Assessment: derived from the Python layer stack plus Mojo
  compile-time features noted in `mojov1` buch.)
- **EOF as an explicit value/typed sentinel, not an exception.** Mojo's error
  model should keep "the peer closed cleanly" separate from "the read failed",
  exactly as Python's empty-bytes does but without borrowing the bytes/`None`
  ambiguity. Source: <https://docs.python.org/3/library/io.html>.
- **An explicit `detach()`-style unwrap and a `close()` that is idempotent.**
  Python's `detach()` "buffer is in an unusable state" and `close()` "only the
  first call … will have an effect" are good lifecycle contracts to encode.
  Source: <https://docs.python.org/3/library/io.html>.
- **A bounded line reader with exact limits.** Copy the *intent* of
  `readuntil(separator)` + `LimitOverrunError` (data kept for retry) rather than
  the exception mechanics. Sources:
  <https://docs.python.org/3/library/asyncio-stream.html>.
- **Keep the byte layer free of encoding.** Follow Python's raw/buffered/text
  split but expose text strictly as a wrapper type, and never let newline
  translation default on in the byte path. Source:
  <https://docs.python.org/3/library/io.html>.

## Sources

- Python `io` docs: <https://docs.python.org/3/library/io.html>
- CPython `Lib/io.py` (3.14): <https://raw.githubusercontent.com/python/cpython/3.14/Lib/io.py>
- Builtin `open()`: <https://docs.python.org/3/library/functions.html#open>
- `asyncio` Streams: <https://docs.python.org/3/library/asyncio-stream.html>
- `asyncio` Coroutines and tasks (timeouts/cancellation):
  <https://docs.python.org/3/library/asyncio-task.html#timeouts>
- `selectors`: <https://docs.python.org/3/library/selectors.html>
- `socket`: <https://docs.python.org/3/library/socket.html>
- aiofiles on PyPI: <https://pypi.org/project/aiofiles/>
- anyio on PyPI: <https://pypi.org/project/anyio/>
- anyio Streams: <https://anyio.readthedocs.io/en/stable/streams.html>
- Trio I/O reference: <https://trio.readthedocs.io/en/stable/reference-io.html>
- Mojo side (not researched here): `mojov1` buch `stdlib/io`,
  `keyword-conventions/imm`, `appendix/cheat-sheet`
