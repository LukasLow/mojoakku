# io research: C++

## 1. Standard library support

C++ has **three overlapping stream systems** in the standard library, all in
the `<io>` family of headers:

- **`std::basic_streambuf`** — the raw device abstraction. "The class
  `basic_streambuf` controls input and output to a character sequence. It
  includes and provides access to (1) the *controlled character sequence*,
  also called the *buffer* ... and (2) the *associated character sequence*,
  also called *source* (for input) or *sink* (for output)."
  Source: <https://en.cppreference.com/w/cpp/io/basic_streambuf>.
  Concrete buffers: `basic_filebuf` (`<fstream>`), `basic_stringbuf`
  (`<sstream>`), `basic_spanbuf` (C++23, `<spanstream>`), `basic_syncbuf`
  (C++20, `<syncstream>`). Source: same page.
- **`std::basic_istream` / `basic_ostream` / `basic_iostream`** — the
  formatted and unformatted interface. "The I/O stream objects ... as well as
  all objects derived from them ... are implemented entirely in terms of
  `std::basic_streambuf`." Source:
  <https://en.cppreference.com/w/cpp/io/basic_streambuf>.
  Derived convenience classes: `ifstream`/`ofstream`/`fstream`,
  `istringstream`/`ostringstream`/`stringstream`, `spanstream` (C++23),
  `osyncstream` (C++20). Source: <https://en.cppreference.com/w/cpp/io>.
- **The C layer `<cstdio>`/`<cwchar>`** — everything from the C survey is
  available unchanged: `std::FILE`, `std::fread`, `std::fopen`, `std::EOF`.
  "The C I/O subset of the C++ standard library implements C-style stream
  input/output operations." Source:
  <https://en.cppreference.com/w/cpp/io/c>.

C++23 adds a fourth, formatting-oriented entry point `<print>`:
`std::print(FILE*, fmt, args...)`, `std::println(...)`,
`std::vprint_unicode`, `std::vprint_nonunicode`.
Source: <https://en.cppreference.com/w/cpp/header/print>. Note that `print`
takes the *C* `FILE*`, not an `ostream` — the two systems meet there.

(Assessment: derived from the sources above: C++ does not remove the C layer;
it adds an object-oriented buffering abstraction (`streambuf`) plus a formatted
facade (`istream`/`ostream`) on top, so a C++ program has three genuinely
different stream models in one process.)

## 2. Relevant community libraries

| Library | Maintainer | Maturity | License | Stream model |
| --- | --- | --- | --- | --- |
| Boost.Iostreams | Boost / Jonathan Turkanis | mature, part of Boost | BSL-1.0 | `Source`/`Sink`/`Filter` concepts + `filtering_stream` |
| Boost.Asio | Boost / Christopher Kohlhoff | mature, widely used | BSL-1.0 | `SyncReadStream`/`AsyncReadStream` type requirements |
| Poco (Streams) | POCO Project | mature | Boost-1.0 | `istream`/`ostream` on Poco::Foundation |
| OpenSSL BIO | OpenSSL Foundation | ubiquitous | Apache-2.0 | `BIO` source/sink + filter chain, usable from C++ |
| zlib / libdeflate | Gailly/Adler et al. | ubiquitous | zlib / MIT | `z_stream` pointer state machine |
| libcurl | Daniel Stenberg | ubiquitous | MIT-like | easy/multi handles + callbacks |

Sources:
- Boost.Iostreams purpose ("To make it easy to create standard C++ streams and
  stream buffers for accessing new Sources and Sinks ... a framework for
  defining Filters ... a collection of ready-to-use Filters, Sources and
  Sinks") and license: <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/home.html>
  ("Distributed under the Boost Software License, Version 1.0").
- Boost.Asio stream requirements: <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/streams.html>
  (SyncReadStream/AsyncReadStream/…; license footer BSL-1.0).
- Boost.Asio per-operation cancellation: <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/cancellation.html>.
- OpenSSL BIO (Apache-2.0): <https://docs.openssl.org/master/man7/bio/>.
- zlib stream state: <https://zlib.net/manual.html>.
- libcurl easy interface: <https://curl.se/libcurl/c/libcurl-easy.html>.

(Assessment: derived from the sources above: C++'s distinguishing community
contribution is the **concept-based stream framework** — Boost.Iostreams
defines Device/Source/Sink/Filter as named requirements that the library then
adapts into a standard `streambuf`/`stream`. This is the closest existing
design to what "one `Reader` trait, many backends" would mean.)

## 3. Exposed APIs

### `std::basic_streambuf` (the device layer)

Core protected virtuals that a backend implements
(Source: <https://en.cppreference.com/w/cpp/io/basic_streambuf>):

```cpp
protected:
  virtual int_type underflow();                       // make ≥1 char available, return it or eof()
  virtual int_type uflow();                           // underflow + advance
  virtual std::streamsize xsgetn(char_type* s, std::streamsize count);   // bulk read
  virtual int_type overflow(int_type ch = Traits::eof()); // flush put area / accept one char
  virtual std::streamsize xsputn(const char_type* s, std::streamsize count);
  virtual int_type pbackfail(int_type ch = Traits::eof());
  virtual pos_type seekoff(off_type, seekdir, openmode);
  virtual pos_type seekpos(pos_type, openmode);
  virtual int sync();
  virtual std::streamsize showmanyc();
```

Public get area / put area / putback
(Source: <https://en.cppreference.com/w/cpp/io/basic_streambuf>):
`in_avail()`, `sgetc()`, `sbumpc()`, `snextc()`, `sgetn(s, n)`,
`sputc(ch)`, `sputn(s, n)`, `sputbackc(ch)`, `sungetc()`, `pubsync()`,
`pubseekoff`, `pubseekpos`, `pubsetbuf`, `pubimbue`, `getloc`.
Protected pointer management: `setg(eback, gptr, egptr)`, `gbump(n)`,
`gptr()`, `egptr()`, `eback()`, `setp(pbase, pptr, epptr)`, `pbump(n)`,
`pptr()`, `epptr()`, `pbase()`.

Key `underflow` semantics: "Ensures that at least one character is available in
the input area ... Returns the value of that character ... on success or
`Traits::eof()` on failure." Source:
<https://en.cppreference.com/w/cpp/io/basic_streambuf/underflow>.

Key `overflow` semantics: "The intent of this function is to transmit
characters from the put area ... to the associated character sequence ...
If the function succeeds, returns some value other than `Traits::eof()` ...
If the function fails, returns `Traits::eof()` or throws an exception."
Source: <https://en.cppreference.com/w/cpp/io/basic_streambuf/overflow>.

`sgetn`/`xsgetn` contract: "Reads `count` characters ... The number of
characters successfully read. **If it is less than `count` the input sequence
has reached the end.**" The note adds that derived classes may optimize bulk
I/O — "that's how `std::ifstream::read` simply passes the pointer to the POSIX
`read()` system call in some implementations." Source:
<https://en.cppreference.com/w/cpp/io/basic_streambuf/sgetn>.

`in_avail`: "Returns the number of characters available for non-blocking read
... or `-1` if no characters are available in the associated sequence as far as
`showmanyc()` can tell." Source:
<https://en.cppreference.com/w/cpp/io/basic_streambuf/in_avail>.

### `std::basic_istream` / `basic_ostream`

Unformatted input (Source:
<https://en.cppreference.com/w/cpp/io/basic_istream>):
`read(char_type* s, streamsize count)`, `readsome`, `get`, `getline`, `peek`,
`unget`, `putback`, `ignore`, `gcount`, `tellg`, `seekg`, `sync`.
`read` semantics: "Characters are extracted and stored until any of the
following conditions occurs: `count` characters were extracted ...; end of file
condition occurs ... (in which case, `setstate(failbit|eofbit)` is called).
The number of successfully extracted characters can be queried using
`gcount()`." Source:
<https://en.cppreference.com/w/cpp/io/basic_istream/read>.

`gcount`: "Returns the number of characters extracted by the last unformatted
input operation." Source:
<https://en.cppreference.com/w/cpp/io/basic_istream/gcount>.

Unformatted output: `write(const char_type* s, streamsize count)`, `put`,
`flush`, `seekp`, `tellp`. `write` returns `*this`; "unlike the formatted
output functions, this function does not set the failbit on failure."
Source: <https://en.cppreference.com/w/cpp/io/basic_ostream/write>.

Formatted: `operator<<` (ostream), `operator>>` (istream).

### State and error API (`basic_ios`)

`good()`, `eof()`, `fail()`, `bad()`, `operator bool`, `operator!`,
`rdstate()`, `setstate(iostate)`, `clear(...)`, `exceptions()`,
`exceptions(iostate)`, `rdbuf()`, `tie()`, `imbue(locale)`, `fill(ch)`,
`narrow`/`widen`. Source: <https://en.cppreference.com/w/cpp/io/basic_ios>.
The state type `ios_base::iostate` is a bitmask with `goodbit = 0`,
`badbit`, `failbit`, `eofbit`. Source:
<https://en.cppreference.com/w/cpp/io/ios_base/iostate>.

### Concrete buffers

- `std::basic_stringbuf` (`<sstream>`): memory-resident sequence; adds
  `str()`, `view()` (C++20), `overflow`/`underflow`/`seekoff`/`seekpos`.
  Source: <https://en.cppreference.com/w/cpp/io/basic_stringbuf>.
- `std::basic_spanbuf` (C++23, `<spanstream>`): "performs I/O on a fixed
  buffer, and therefore it does not attempt to obtain a new buffer when the
  underlying buffer is exhausted." Source:
  <https://en.cppreference.com/w/cpp/io/basic_spanbuf>. **"does not own the
  underlying buffer"** — same source, Notes.
- `std::basic_filebuf` (`<fstream>`): associated sequence is a file; input and
  output share one file position; `open`, `close`, `is_open`, `native_handle`
  (C++26). Source: <https://en.cppreference.com/w/cpp/io/basic_filebuf>.
- `std::basic_syncbuf` (C++20, `<syncstream>`): "accumulates output in its own
  internal buffer, and atomically transmits its entire contents to the wrapped
  buffer on destruction and when explicitly requested"; `emit()`,
  `set_emit_on_sync(bool)`, `get_wrapped()`. Source:
  <https://en.cppreference.com/w/cpp/io/basic_syncbuf>.

### Boost.Iostreams concepts

(Source: <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/concepts/source.html>,
<https://www.boost.org/doc/libs/latest/libs/iostreams/doc/concepts/sink.html>)
- `Source`: `std::streamsize read(char* s, std::streamsize n);` returning
  "the number of characters read, **or -1 to indicate end-of-sequence**";
  or `input_sequence()` returning `std::pair<Ch*,Ch*>`.
- `Sink`: `std::streamsize write(const char* s, std::streamsize n);` returning
  "the number of characters written"; or `output_sequence()`.
- Must model `Blocking` to be usable with the library's streams.
- `filtering_stream`/`filtering_streambuf` hold "chains of Filters and Devices
  accessed with an interface similar to that of `std::stack`."

### Boost.Asio stream requirements

(Source: <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/streams.html>)
- `SyncReadStream`: `read_some()`; `AsyncReadStream`: `async_read_some()`;
  likewise `write_some`/`async_write_some`.
- "Read or write operations may transfer fewer bytes than requested. This is
  referred to as a short read or short write."
- Generic helpers `read()`, `async_read()`, `write()`, `async_write()` loop
  until the exact count is transferred.

## 4. Error representation

C++ offers **four coexisting mechanisms**, and the standard library's own
choice is the most unusual of them:

1. **A sticky state bitmask, not an exception and not a return code.**
   `ios_base::iostate` with `goodbit`/`badbit`/`failbit`/`eofbit`; `rdstate`,
   `setstate`, `clear`, and the accessors `good`/`eof`/`fail`/`bad`.
   Source: <https://en.cppreference.com/w/cpp/io/ios_base/iostate>.
   The design is *deliberately non-raising by default*: a failed extraction
   sets a bit and leaves the stream in a failed state; the caller checks
   `if (!stream)`.
2. **Opt-in exceptions via `exceptions(iostate)`.** "The exception mask
   determines which error states trigger exceptions of type `failure` ... If
   the stream has an error state covered by the exception mask when called, an
   exception is immediately triggered." Source:
   <https://en.cppreference.com/w/cpp/io/basic_ios/exceptions>. The type is
   `std::ios_base::failure` (a `system_error` since C++11, carrying
   `std::io_errc::stream`). Source:
   <https://en.cppreference.com/w/cpp/io/ios_base/failure>.
   Only **one** required error code exists: `enum class io_errc { stream = 1 };`
   — "Only one error code (`std::io_errc::stream`) is required, although the
   implementation may define additional error codes." Source:
   <https://en.cppreference.com/w/cpp/io/io_errc>.
3. **Sentinel returns** in the C layer (`EOF`, `NULL`, -1 + `errno`) — see the
   C file. Source: <https://en.cppreference.com/w/cpp/io/c>.
4. **`std::expected` (C++23)** — the modern vocabulary type for value-or-error,
   available but not used by iostreams. Source:
   <https://en.cppreference.com/w/cpp/header/expected>.

Community shape: Boost.Iostreams reports errors **by throwing** — "Errors
which occur during the execution of member functions `read` or
`input_sequence` are indicated by throwing exceptions. Reaching the end of the
sequence is not an error." Source:
<https://www.boost.org/doc/libs/latest/libs/iostreams/doc/concepts/source.html>.
Boost.Asio uses an **`error_code` out-parameter** (`void(boost::system::error_code e, std::size_t n)`)
plus `boost::system::error_code` values. Source:
<https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/cancellation.html>.

(Assessment: derived from the sources above: C++ iostreams chose *state bits*
over both return codes and exceptions in order to support formatted extraction
compositions; the cost is that "an error happened" and "the previous operation
failed" are indistinguishable except by clearing/checking state, and the typed
reason is essentially absent — `io_errc` has one value.)

## 5. Ownership semantics

C++ layers ownership onto the same `streambuf` model in several explicit ways:

- **The stream object owns its `streambuf` (or borrows it).** `basic_ios`
  holds a `streambuf*` obtained via `rdbuf()`; `basic_ios::init(streambuf*)`
  "when called to initialize a stream with a null pointer for `rdbuf()`" sets
  `badbit`. Source: <https://en.cppreference.com/w/cpp/io/ios_base/iostate>.
  The user-facing streams (`ifstream`, `stringstream`) own their buffer member;
  a hand-built `std::ostream stream(&mybuf)` borrows it, and the caller must
  keep `mybuf` alive.
- **`basic_spanbuf` explicitly does not own its buffer.** "`std::basic_spanbuf`
  does not own the underlying buffer. It is the responsibility of programmers
  to ensure the underlying buffer is in its lifetime when used by a
  `std::basic_spanbuf` object." Source:
  <https://en.cppreference.com/w/cpp/io/basic_spanbuf>.
- **`basic_filebuf` owns the OS file handle and closes it in its destructor**
  ("destructs a `basic_filebuf` object and closes the file if it is open").
  Source: <https://en.cppreference.com/w/cpp/io/basic_filebuf>.
- **The buffer can be replaced, but the replacement is borrowed.** `pubsetbuf`
  /`setbuf(char*, n)` "replaces the buffer with user-defined array, if
  permitted"; `basic_filebuf::setbuf` "provides user-supplied buffer or turns
  this filebuf unbuffered." Sources:
  <https://en.cppreference.com/w/cpp/io/basic_streambuf>,
  <https://en.cppreference.com/w/cpp/io/basic_filebuf>. As in C, the
  supplied array must outlive the stream (the type system does not say so).
- **Boost.Iostreams warns explicitly about this borrow.**
  "The Iostreams library stores streams and stream buffers by reference;
  consequently, streams and stream buffers must outlive any filter chain to
  which they are added." Source:
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/faq.html>.
  A `Source`/`Sink` is likewise referenced, and "the array must not be
  destroyed as long as the Devices are to be used" for
  `array_source`/`array_sink`.
- **Boost.Asio is the cautionary case: lifetimes must be kept alive by hand.**
  For `uv_write`-style async writes the memory must stay valid until the
  callback; Asio's own docs require the same for buffers, and the examples use
  `enable_shared_from_this` to keep a session alive across async ops. Source:
  <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/streams.html>
  and the cancellation example.
- **`std::FILE*` in `<cstdio>` keeps C's rule** (caller frees via `fclose`,
  no ownership in the type). Source: <https://en.cppreference.com/w/cpp/io/c>.

(Assessment: derived from the sources above: C++ *can* express ownership in
types (`unique_ptr`, value members) but the stream library mostly does not —
the `streambuf` is passed as a raw pointer, replacement buffers are borrowed,
and the lifetime rule is documentation. Boost.Iostreams and Asio therefore both
carry explicit "must outlive" warnings.)

## 6. Blocking / non-blocking

- **Iostreams are blocking and single-threaded by default.** There is no
  non-blocking mode; a read from an empty device blocks. The only hint of
  partial availability is `in_avail()` / `showmanyc()` and `readsome()`.
  (Assessment: derived from the absence of any non-blocking iostream mode in the
  standard; the `streambuf` virtuals `showmanyc`/`underflow` are the only
  partial-availability hooks — <https://en.cppreference.com/w/cpp/io/basic_streambuf>.)
- **`readsome` is the explicit "non-blocking-ish" call and it is documented as
  unreliable.** "Extracts up to `count` immediately available characters ...
  If `rdbuf()->in_avail() == 0`, extracts no characters." And the Notes warn:
  "The behavior of this function is highly implementation-specific. For
  example, using `readsome()` with `std::ifstream` leads to significant,
  implementation-specific outcomes. Some library implementations fill the
  underlying `filebuf` with data as soon as `std::ifstream` opens a file ...
  With other implementations, `std::ifstream` only reads from a file when an
  input operation is invoked ... Similarly, calling `std::cin.readsome()` may
  return all pending, unprocessed console input or may always return zero."
  Source: <https://en.cppreference.com/w/cpp/io/basic_istream/readsome>.
- **Thread-safety is delegated and opt-in.** C++17 gives `FILE` a reentrant
  lock, and `basic_syncbuf` (C++20) provides synchronized output:
  "It guarantees that there are no data races and no interleaving of characters
  sent to the wrapped buffer as long as all other outputs made to the same
  buffer are made through ... instances of `std::basic_syncbuf`."
  Sources: <https://en.cppreference.com/w/cpp/io/c/FILE>,
  <https://en.cppreference.com/w/cpp/io/basic_syncbuf>.
- **Asynchrony lives outside the standard library**, in Boost.Asio:
  `async_read_some`/`async_write_some` with completion handlers, plus generic
  `async_read`/`async_write` that loop until the exact count is reached.
  Source: <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/streams.html>.
- **`<print>` (C++23) is thread-safety-aware**: `vprint_unicode_locking` vs
  the non-locking variants are separate functions. Source:
  <https://en.cppreference.com/w/cpp/header/print>.
- **`std::stop_token` (C++20)** is the standard cooperative-cancellation
  vocabulary: `stop_requested()`, `stop_possible()`, `stop_callback`,
  usable with `condition_variable_any`. Source:
  <https://en.cppreference.com/w/cpp/thread/stop_token>.

(Assessment: derived from the sources above: C++ moved *asynchrony and
cancellation out of the stream abstraction entirely* and left iostreams
synchronous; the only bridge between them (`readsome`) is explicitly documented
as non-portable in behaviour.)

## 7. Byte streams vs text streams

C++ distinguishes them along **two orthogonal axes that the library mostly
conflates**:

1. **Element type is a template parameter**, so text-ness is structural, not a
   mode flag: `basic_streambuf<CharT, Traits>` with `char_type = CharT`.
   `std::streambuf = basic_streambuf<char>` (bytes) and
   `std::wstreambuf = basic_streambuf<wchar_t>` (wide/text).
   Source: <https://en.cppreference.com/w/cpp/io/basic_streambuf>.
2. **Encoding conversion is a locale facet.** "The character representation
   and encoding in the controlled sequence may be different from the character
   representations in the associated sequence, in which case a
   `std::codecvt` locale facet is typically used to perform the conversion.
   Common examples are UTF-8 (or other multibyte) files accessed through
   `std::wfstream` objects: the controlled sequence consists of `wchar_t`
   characters, but the associated sequence consists of bytes." Source:
   <https://en.cppreference.com/w/cpp/io/basic_streambuf>.

So C++ distinguishes byte vs text by **which width you instantiate** and by
**whether a codecvt facet is imbued**, not by two separate hierarchies.

**Buffering is layered by the buffer class, not by a stack of filters.** There
is exactly one controlled sequence per streambuf; layering is achieved by
composing *streambufs* externally (e.g. Boost.Iostreams `filtering_stream`
chains filters over a device — see §3) or by wrapping a `BIO` chain.

**Partial reads are reported exactly like C**: through the count.
`sgetn`/`read`: "The number of characters successfully read. If it is less
than `count` the input sequence has reached the end." Source:
<https://en.cppreference.com/w/cpp/io/basic_streambuf/sgetn>.
`basic_istream::read` sets `failbit|eofbit` if it cannot fill the request,
and `gcount()` gives the short count. Sources:
<https://en.cppreference.com/w/cpp/io/basic_istream/read>,
<https://en.cppreference.com/w/cpp/io/basic_istream/gcount>.
Boost.Asio names the concept explicitly ("short read or short write") and
provides looping helpers. Source:
<https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/streams.html>.

Boost.Iostreams makes buffering *composable by design*: a `filtering_stream`
is "a chain of zero or more Filters followed by an optional Device, accessed
with an interface similar to that of `std::stack`" (push to prepend); this is
C++'s answer to layered buffering, done at the streambuf level rather than
inside one stream. Source:
<https://www.boost.org/doc/libs/latest/libs/iostreams/doc/home.html>.

(Assessment: derived from the sources above: C++'s byte/text distinction is
*instantiation-time* (`char` vs `wchar_t`) with conversion hidden in the
locale; that is more flexible than C's open-mode flag but also more implicit —
the same `wfilebuf` silently converts based on the imbued facet.)

## 8. Timeouts

The **standard library has no timeout API for streams at all.** No member of
`basic_istream`, `basic_ostream` or `basic_streambuf` accepts a timeout or
deadline. Sources:
<https://en.cppreference.com/w/cpp/io/basic_istream>,
<https://en.cppreference.com/w/cpp/io/basic_streambuf>.

What exists:

- **C-level `poll`/`ppoll`** (from `<poll.h>`) remain available and take a
  timeout in milliseconds / a `timespec`. Source:
  <https://man7.org/linux/man-pages/man2/poll.2.html> (see the C file §8).
- **Boost.Asio timers and per-operation cancellation.** `cancellation_signal`
  /`cancellation_slot` deliver a cancellation request with an explicit
  guarantee level (`terminal`, `partial`, `total`); "`total` = The operation had
  no side effects that are observable through the API", "`partial` = ... the
  completion handler ... indicates what these side effects were."
  Source: <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/cancellation.html>.
  Timers combine with async ops to implement deadlines at the application level.
- **`std::stop_token` (C++20) is the standard cancellation primitive**, but it
  is *not wired into iostreams*; it must be checked by the code performing the
  I/O. Sources: <https://en.cppreference.com/w/cpp/thread/stop_token>.
- **Boost.Iostreams `Blocking` requirement**: Sources must model Blocking to
  work with the library's streams; there is a separate non-blocking mechanism
  documented in the Asynchronous section but per-stream timeouts are not part
  of the `Source`/`Sink` concept. Sources:
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/concepts/source.html>,
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/home.html>.

(Assessment: derived from the sources above: C++ keeps timeouts entirely out of
the stream types. The best available vocabulary is Asio's cancellation
signals plus a timer, i.e. an application-level composition, not a stream
property.)

## 9. End-of-stream and error signalling

C++ has **the most baroque EOF/error story of the surveyed languages**: EOF is
a *state bit* that is almost always accompanied by `failbit`, and the two are
distinguished only by consulting the bitmask.

- `read` on EOF: "end of file condition occurs on the input sequence (in which
  case, `setstate(failbit|eofbit)` is called)." Source:
  <https://en.cppreference.com/w/cpp/io/basic_istream/read>.
- The `iostate` page warns: "Note that in nearly all situations, if `eofbit` is
  set, the `failbit` is set as well." Source:
  <https://en.cppreference.com/w/cpp/io/ios_base/iostate>.
- The accessor truth table is the practical API: `good()` is false if *any* of
  eofbit/failbit/badbit is set; `fail()` is true when failbit or badbit is set;
  `bad()` only for badbit; `eof()` only for eofbit. Source:
  <https://en.cppreference.com/w/cpp/io/ios_base/iostate>.
- **Which operations set which bit** is enumerable but large: the `iostate`
  page lists separately which functions set eofbit, failbit and badbit.
  Notably `read` sets `failbit` when "the end-of-file condition occurs ...
  before all requested characters could be extracted", whereas `write` "does
  not set the `failbit` on failure" and sets `badbit` instead. Sources:
  <https://en.cppreference.com/w/cpp/io/ios_base/iostate>,
  <https://en.cppreference.com/w/cpp/io/basic_ostream/write>.
- **`operator bool` is the idiomatic probe**: "checks if no error has occurred
  (synonym of `!fail()`)". Because eofbit implies failbit in practice, a
  normal `while (in >> x)` loop terminates on EOF exactly as if it were an
  error. Sources: <https://en.cppreference.com/w/cpp/io/ios_base/iostate>,
  <https://en.cppreference.com/w/cpp/io/basic_ios>.
- **Exceptions are opt-in and carry almost no type**: `exceptions(failbit)`
  makes the stream throw `ios_base::failure` whose `code()` is
  `io_errc::stream`. Source:
  <https://en.cppreference.com/w/cpp/io/basic_ios/exceptions>,
  <https://en.cppreference.com/w/cpp/io/io_errc>.
- **`gcount()` is the only per-call byte count**, and it is reset by every
  subsequent unformatted operation. Source:
  <https://en.cppreference.com/w/cpp/io/basic_istream/gcount>.

Community improvements: Boost.Iostreams states plainly that **"Reaching the
end of the sequence is not an error"** and reports it with `read` returning
`-1`, errors via exceptions. Source:
<https://www.boost.org/doc/libs/latest/libs/iostreams/doc/concepts/source.html>.
Boost.Asio makes EOF a first-class error: "An EOF error may be used to
distinguish the end of a stream from a successful read of size 0", and it lists
"Why EOF is an Error" as a design heading. Source:
<https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/streams.html>.

(Assessment: derived from the sources above: C++ iostreams make EOF a *state*
and force a flag combination (`failbit|eofbit`) that conflates it with a
failed extraction; users are trained to test only `operator bool`, so EOF and
error become indistinguishable in ordinary code. Asio and Boost.Iostreams both
move to an explicit EOF signal — a strong hint that the state-bit design is the
wrong one.)

## 10. Interesting design decisions

- **Three-layer factoring: buffer / formatting / device.** `streambuf` handles
  characters and buffering; `istream`/`ostream` handle formatting;
  concrete classes (`ifstream`, `stringstream`, `spanstream`) bind a device.
  This is a genuine layering that C lacks and that a Mojo `Reader`/`Writer`
  design can copy conceptually. Source:
  <https://en.cppreference.com/w/cpp/io/basic_streambuf>.
- **The get/put area as three pointers (`begin`, `next`, `end`).** The buffer
  is a movable window; `setg`/`gbump`/`setp`/`pbump` are the whole mechanism.
  "The controlled character sequence is an array of `CharT` which, at all
  times, represents ... a 'window' into the associated character sequence."
  Source: <https://en.cppreference.com/w/cpp/io/basic_streambuf>.
- **`underflow`/`overflow` as the *only* two virtuals a backend really must
  implement** (plus `xsgetn`/`xsputn` for bulk). A single-character refill and
  a single-character flush are enough to make a full stream — a remarkably
  small required surface. Sources:
  <https://en.cppreference.com/w/cpp/io/basic_streambuf/underflow>,
  <https://en.cppreference.com/w/cpp/io/basic_streambuf/overflow>.
- **`in_avail()`/`showmanyc()` as an optional non-blocking hint.** A backend
  may say "N chars are ready without touching the device, or -1 if unknown" —
  a clean separation of *availability* from *read*. Source:
  <https://en.cppreference.com/w/cpp/io/basic_streambuf/in_avail>.
- **`readsome`'s documented non-portability** is itself instructive: the
  standard shipped an API whose semantics are explicitly
  implementation-defined, which is a warning about designing non-blocking
  reads into a synchronous interface. Source:
  <https://en.cppreference.com/w/cpp/io/basic_istream/readsome>.
- **`basic_spanbuf` (C++23): a fixed, non-owning buffer stream.** "does not
  attempt to obtain a new buffer when the underlying buffer is exhausted" — an
  explicit, standard "borrow a caller buffer" device with a documented
  lifetime caveat. Source: <https://en.cppreference.com/w/cpp/io/basic_spanbuf>.
- **`basic_syncbuf` (C++20): atomic emission as the synchronization model.**
  Output is staged and then transmitted atomically; the interleaving guarantee
  is conditional on everyone using `syncbuf`. Source:
  <https://en.cppreference.com/w/cpp/io/basic_syncbuf>.
- **`tie()`: chaining an output stream to an input stream so one flushes
  before the other reads.** "flush() is called on the tied stream before any
  input/output operation on `*this`"; `cout` is tied to `cin`/`cerr` by
  default. Source: <https://en.cppreference.com/w/cpp/io/basic_ios/tie>.
- **Boost.Iostreams' four concepts as *named requirements*, adaptable to any
  `streambuf`/`stream`.** A `Source` can be implemented either as a `read()`
  method *or* as a direct `input_sequence()` pointer pair — two distinct
  performance/ownership profiles behind one concept. Source:
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/concepts/source.html>.
- **Boost.Asio's short-read/short-write vocabulary and looping helpers.** The
  library names the phenomenon, documents that a stream has "no message
  boundaries", and ships `read`/`write` that retry to the exact count.
  Source: <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/streams.html>.
- **Asio cancellation with *strong/weak guarantee levels*** (`total`,
  `partial`, `terminal`) rather than a boolean cancel. Source:
  <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/cancellation.html>.
- **`std::ios_base::failure` inherits `std::system_error` and carries
  `error_code`** — the standard tried to retrofit typed errors onto stream
  failures, but defined only one enum value. Sources:
  <https://en.cppreference.com/w/cpp/io/ios_base/failure>,
  <https://en.cppreference.com/w/cpp/io/io_errc>.

## 11. Decisions NOT to copy

- **The `failbit|eofbit` conflation.** Because EOF nearly always sets failbit,
  the ordinary `if (!stream)` idiom cannot tell "no more data" from "broken
  stream", and users must consult `eof()` separately. Sources:
  <https://en.cppreference.com/w/cpp/io/ios_base/iostate>,
  <https://en.cppreference.com/w/cpp/io/basic_istream/read>.
- **Sticky stream state that leaks across calls.** `rdstate` persists until
  `clear()`; every operation after a failure is a no-op unless state is reset,
  and the *reason* is only one `io_errc` value. Sources:
  <https://en.cppreference.com/w/cpp/io/basic_ios> (clear/setstate),
  <https://en.cppreference.com/w/cpp/io/io_errc>.
- **Exceptions as an opt-in mask (`exceptions(failbit)`).** This makes the
  *caller* responsible for turning a state into an exception and produces two
  control-flow styles over one library, with no compile-time enforcement.
  Source: <https://en.cppreference.com/w/cpp/io/basic_ios/exceptions>.
- **`readsome` — a non-blocking API with implementation-defined semantics.**
  Source: <https://en.cppreference.com/w/cpp/io/basic_istream/readsome>.
- **`write` not setting `failbit` while `read` does.** The asymmetry is a
  documented standard decision and is exactly the kind of inconsistency a new
  API should avoid. Sources:
  <https://en.cppreference.com/w/cpp/io/basic_ostream/write>,
  <https://en.cppreference.com/w/cpp/io/ios_base/iostate>.
- **Ownership left in documentation.** The `streambuf` is a raw pointer; a
  replacement buffer via `setbuf` is borrowed; `spanbuf`/Boost.Iostreams/Asio
  all repeat "must outlive". A modern API should put the borrow in the type.
  Sources: <https://en.cppreference.com/w/cpp/io/basic_streambuf>,
  <https://en.cppreference.com/w/cpp/io/basic_spanbuf>,
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/faq.html>.
- **`codecvt`-hidden byte↔text conversion** driven by an imbued locale facet:
  a stream's byte output changes based on hidden global-ish locale state.
  Source: <https://en.cppreference.com/w/cpp/io/basic_streambuf>.
- **`gcount()` as a separate query reset by later operations.** "Returns the
  number of characters extracted by the last unformatted input operation ...
  The following functions set `gcount()` to zero: constructor, putback(),
  unget(), peek()." A per-call count should be returned by the call. Source:
  <https://en.cppreference.com/w/cpp/io/basic_istream/gcount>.
- **Two separate exception/error systems (`ios_base::failure` vs
  `std::error_code`) plus sentinels plus `expected`.** Four mechanisms for one
  job; the C++23 `<expected>` shows the standard now prefers the value-or-error
  shape. Source: <https://en.cppreference.com/w/cpp/header/expected>.
- **`tie()`'s implicit cross-stream flushing**, which can deadlock if two
  streams are tied to each other (documented as UB). Source:
  <https://en.cppreference.com/w/cpp/io/basic_ios/tie>.

## 12. Ideas fitting Mojo

- **The three-layer factoring (buffering / formatting / device) maps onto two
  Mojo traits.** A `Reader`/`Writer` trait pair is the device layer; the
  *formatting* layer already exists in Mojo as `Writable`/`Writer`
  (`mojov1/stdlib/format`: `Writable` "describes how a type converts itself to
  UTF-8 text", `Writer` "accepts formatted output ... one required method
  `write_string(mut self, string: StringSpan)`"). The C++ lesson is to keep
  the *byte* trait (`read`/`write` of `Span[UInt8]`) strictly separate from the
  *text* trait, rather than mixing formatted and unformatted operations on one
  object as `istream` does. Sources:
  <https://en.cppreference.com/w/cpp/io/basic_streambuf>,
  `mojov1/stdlib/format`.
- **`underflow`/`overflow` show the minimal refill/flush contract.** "Ensure at
  least one char is available" and "accept one char / flush the put area" are
  the two operations a backend genuinely needs; Mojo can expose exactly these
  as the trait's required methods and provide the bulk variants (`read_into`,
  `write_all`) as provided methods, mirroring `xsgetn`/`xsputn` defaults.
  Sources: <https://en.cppreference.com/w/cpp/io/basic_streambuf/underflow>,
  <https://en.cppreference.com/w/cpp/io/basic_streambuf/overflow>,
  `mojov1/keywords/trait`.
- **`Span[T]` makes `spanbuf`'s borrow checked instead of documented.**
  `basic_spanbuf` "does not own the underlying buffer"; Mojo's `Span` is
  "a non-owning view of contiguous data" *with a compiler-checked origin*, so
  the same design becomes safe. This is the single most direct C++ → Mojo
  translation here. Sources:
  <https://en.cppreference.com/w/cpp/io/basic_spanbuf>,
  `mojov1/types/collections`, `mojov1/memory/origin-and-borrowing`.
- **Use `raises` with a typed error where C++ uses `failbit` plus one
  `io_errc` value.** A Mojo `IoError` with distinct cases
  (`eof`, `would_block`, `short_read`, `device_error`) gives the exhaustive
  handling that `io_errc { stream }` cannot, and the compiler forces callers to
  declare `raises` (`mojov1/errors/error-model`). C++'s own retreat to
  `std::expected` and Asio's use of `error_code` both point the same way.
- **Return the byte count from the call, not from a `gcount()` query.**
  C++'s separate `gcount()` is reset by `putback`/`unget`/`peek`; a Mojo
  `read` returning a small result (`bytes_read: Int`, `eof: Bool`) removes the
  ordering trap. Sources: <https://en.cppreference.com/w/cpp/io/basic_istream/gcount>.
- **Model async on Asio's requirements, not on iostreams.** `read_some` /
  `write_some` as the *trait* methods and looping helpers (`read`/`write` to an
  exact count) as provided methods is exactly Asio's split and avoids the
  `readsome` mistake. Sources:
  <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/streams.html>.
- **Adopt cancellation guarantee levels, not a boolean cancel.** Asio's
  `terminal`/`partial`/`total` distinction tells the caller exactly what state
  the stream is left in; Mojo can encode this as an enum parameter to a
  cancellation call, or as distinct error cases on the read result. Source:
  <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/cancellation.html>.
- **A `with`-scoped stream replaces raw `streambuf*` lifetime management.**
  Mojo's `with` (`mojov1/keywords/with`) runs `__exit__`/`deinit` on every
  path, which turns C++'s "the streambuf must outlive the stream" prose
  warning into an enforced scope. Sources:
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/faq.html>,
  `mojov1/keywords/with`.
- **`syncbuf`'s atomic emission is a good model for a thread-safe writer.**
  Rather than sprinkling locks, stage output and emit atomically; in Mojo this
  is a `Writer` implementation that buffers then flushes under one lock.
  Source: <https://en.cppreference.com/w/cpp/io/basic_syncbuf>.
- **`in_avail()`'s hint as an optional method.** "N chars ready, or -1 if
  unknown" keeps availability out of the read contract and lets blocking
  backends simply not implement it — a clean optional trait method in Mojo.
  Source: <https://en.cppreference.com/w/cpp/io/basic_streambuf/in_avail>.
- **`std::stop_token` as the cancellation vocabulary.** Mojo's concurrency page
  documents `std::atomic` and locks but not a standard stop mechanism; a
  `stop_token`-like borrowed handle is the C++20 shape worth borrowing for a
  future cancellable read. Source: <https://en.cppreference.com/w/cpp/thread/stop_token>;
  Mojo concurrency: `mojov1/concurrency/async-and-parallelism`.

## Sources

- `std::basic_streambuf` (three-layer model, pointers, virtuals, codecvt):
  <https://en.cppreference.com/w/cpp/io/basic_streambuf>
- `basic_streambuf::underflow`:
  <https://en.cppreference.com/w/cpp/io/basic_streambuf/underflow>
- `basic_streambuf::overflow`:
  <https://en.cppreference.com/w/cpp/io/basic_streambuf/overflow>
- `basic_streambuf::sgetn`/`xsgetn` (short read contract):
  <https://en.cppreference.com/w/cpp/io/basic_streambuf/sgetn>
- `basic_streambuf::in_avail` (non-blocking hint, -1):
  <https://en.cppreference.com/w/cpp/io/basic_streambuf/in_avail>
- `basic_istream::read` (EOF sets failbit|eofbit):
  <https://en.cppreference.com/w/cpp/io/basic_istream/read>
- `basic_istream::readsome` (implementation-defined non-blocking):
  <https://en.cppreference.com/w/cpp/io/basic_istream/readsome>
- `basic_istream::gcount` (reset rules):
  <https://en.cppreference.com/w/cpp/io/basic_istream/gcount>
- `basic_ostream::write` (does not set failbit):
  <https://en.cppreference.com/w/cpp/io/basic_ostream/write>
- `ios_base::iostate` (goodbit/badbit/failbit/eofbit, setter table):
  <https://en.cppreference.com/w/cpp/io/ios_base/iostate>
- `basic_ios::exceptions` (exception mask):
  <https://en.cppreference.com/w/cpp/io/basic_ios/exceptions>
- `ios_base::failure` (system_error since C++11):
  <https://en.cppreference.com/w/cpp/io/ios_base/failure>
- `std::io_errc` (single required value `stream`):
  <https://en.cppreference.com/w/cpp/io/io_errc>
- `basic_ios::tie` (cross-stream flush, UB note):
  <https://en.cppreference.com/w/cpp/io/basic_ios/tie>
- `basic_stringbuf`:
  <https://en.cppreference.com/w/cpp/io/basic_stringbuf>
- `basic_spanbuf` (fixed, non-owning, C++23):
  <https://en.cppreference.com/w/cpp/io/basic_spanbuf>
- `basic_filebuf` (owns/closes the file):
  <https://en.cppreference.com/w/cpp/io/basic_filebuf>
- `basic_syncbuf` (atomic emit, C++20):
  <https://en.cppreference.com/w/cpp/io/basic_syncbuf>
- `std::FILE` (C stream state, incl. C++17 lock):
  <https://en.cppreference.com/w/cpp/io/c/FILE>
- C-style I/O in C++:
  <https://en.cppreference.com/w/cpp/io/c>
- `<print>` header (C++23, print/println, locking variants):
  <https://en.cppreference.com/w/cpp/header/print>
- C++ standard-library header list:
  <https://en.cppreference.com/w/cpp/header>
- `std::stop_token` (cooperative cancellation):
  <https://en.cppreference.com/w/cpp/thread/stop_token>
- Boost.Iostreams home (purpose, concepts, BSL-1.0):
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/home.html>
- Boost.Iostreams `Source` concept (read -> -1 = EOS; errors throw):
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/concepts/source.html>
- Boost.Iostreams `Sink` concept:
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/concepts/sink.html>
- Boost.Iostreams FAQ (streams must outlive chains):
  <https://www.boost.org/doc/libs/latest/libs/iostreams/doc/faq.html>
- Boost.Asio "Streams, Short Reads and Short Writes" (Sync/AsyncReadStream, EOF):
  <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/streams.html>
- Boost.Asio per-operation cancellation (terminal/partial/total):
  <https://www.boost.org/doc/libs/latest/doc/html/boost_asio/overview/core/cancellation.html>
- OpenSSL `bio` overview (source/sink vs filter, Apache-2.0):
  <https://docs.openssl.org/master/man7/bio/>
- zlib manual (`z_stream`, return codes):
  <https://zlib.net/manual.html>
- libcurl easy interface:
  <https://curl.se/libcurl/c/libcurl-easy.html>
- Linux `poll(2)` (timeout semantics):
  <https://man7.org/linux/man-pages/man2/poll.2.html>
- Mojo `mojov1` buch, `stdlib/format` (`Writable`/`Writer` as the text layer)
- Mojo `mojov1` buch, `stdlib/io` (`FileHandle`, `print`, `read_bytes`)
- Mojo `mojov1` buch, `keywords/trait` (required vs provided methods)
- Mojo `mojov1` buch, `keywords/with` (scoped cleanup)
- Mojo `mojov1` buch, `errors/error-model` (`raises`, typed errors)
- Mojo `mojov1` buch, `types/collections` (`Span`)
- Mojo `mojov1` buch, `memory/origin-and-borrowing` (checked borrows)
- Mojo `mojov1` buch, `concurrency/async-and-parallelism` (atomics, locks)
