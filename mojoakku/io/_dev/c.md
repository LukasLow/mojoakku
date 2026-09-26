# io research: C

## 1. Standard library support

C's standard library provides **two distinct stream layers** plus the raw POSIX
calls the layers sit on:

- **Buffered, formatted/unformatted `FILE*` streams** from `<stdio.h>`.
  "I/O streams are denoted by objects of type `FILE` that can only be accessed
  and manipulated through pointers of type `FILE*`. Each stream is associated
  with an external physical device (file, standard input stream, printer,
  serial port, etc)." Source: <https://en.cppreference.com/w/c/io>.
  `<stdio.h>` is one of the fixed ISO C headers and is the only I/O header in
  that list; `<wchar.h>` adds wide-character variants.
  Source: <https://en.cppreference.com/w/c/header>.
- **Unbuffered file-descriptor I/O** from POSIX, not ISO C: `read(2)` and
  `write(2)` in `<unistd.h>`. "`read()` attempts to read up to *count* bytes
  from file descriptor *fd* into the buffer starting at *buf*."
  Source: <https://man7.org/linux/man-pages/man2/read.2.html>.

There is **no ISO C text-stream type distinct from the byte stream**: text vs
binary is a *mode* of the same `FILE*`. Source:
<https://en.cppreference.com/w/cpp/io/c/FILE> ("A *text stream* is an ordered
sequence of characters ... A *binary stream* is an ordered sequence of
characters that can transparently record internal data").

`FILE` carries explicit stream state. cppreference enumerates: character width
(narrow/wide), multibyte parse state, buffering state (unbuffered/line/fully),
the buffer (possibly user-provided), I/O mode, binary/text indicator, EOF
indicator, error indicator, and a file-position indicator. Since C++17 a
reentrant lock is also used to prevent data races. Source:
<https://en.cppreference.com/w/cpp/io/c/FILE>.

(Assessment: derived from the above: C's stdlib has a real byte-stream
abstraction (`FILE*`) and a real text/binary *mode* distinction, but no
separate Reader/Writer *interfaces* — every operation is a free function taking
a `FILE*` or an `int` fd.)

## 2. Relevant community libraries

The C stream ecosystem is layered on the POSIX fd model. The relevant
community libraries are event loops / buffered-stream frameworks rather than
"reader/writer interfaces":

| Library | Maintainer | Maturity | License | Stream model |
| --- | --- | --- | --- | --- |
| libuv | Node.js / libuv project | mature, widely deployed | MIT | `uv_stream_t` async handle + callbacks |
| libevent | Nick Mathewson et al. | mature | BSD-3-Clause | `bufferevent` (input/output `evbuffer` + callbacks) |
| OpenSSL BIO | OpenSSL Foundation | ubiquitous | Apache-2.0 | `BIO` source/sink + filter chain |
| zlib | Gailly/Adler | ubiquitous | zlib (MIT-like) | `z_stream` in/out pointer state machine |
| libcurl | Daniel Stenberg | ubiquitous | MIT-like | easy (blocking) / multi (async) handles, callbacks |

Sources:
- libuv MIT and stream model: <https://docs.libuv.org/en/v1.x/stream.html>
  (stream-handle docs) and the project README license (MIT).
- libevent `bufferevent`: <https://libevent.org/doc/bufferevent_8h.html>
  ("Functions for buffering data for network sending or receiving. ...
  A bufferevent provides input and output buffers that get filled and drained
  automatically."). License BSD-3-Clause (libevent project).
- OpenSSL BIO: <https://docs.openssl.org/master/man7/bio/> ("A BIO is an I/O
  abstraction ... There are two types of BIO, a source/sink BIO and a filter
  BIO."). License: the page footer states "Licensed under the Apache License
  2.0".
- zlib stream state: <https://zlib.net/manual.html> (`z_stream` struct and
  `deflate`/`inflate`). The manual preamble carries the zlib license text.
- libcurl easy vs multi: <https://curl.se/libcurl/c/libcurl-easy.html>.

(Assessment: derived from the sources above: in C the "reader/writer" concept
is not provided by a library at all — it is the *file descriptor* (`int`) plus
`read`/`write`, and every community framework adds its own buffering and
callback style on top. libuv's `uv_stream_t` and libevent's `bufferevent` are
two incompatible answers to "buffered async stream".)

## 3. Exposed APIs

### `<stdio.h>` — buffered `FILE*` streams

Types/objects (Source: <https://en.cppreference.com/w/c/io>):
- `typedef ... FILE;`, `fpos_t`.
- `stdin`, `stdout`, `stderr` — macro constants of type `FILE*`.

Open/close/buffer (Source: <https://en.cppreference.com/w/c/io/setbuf> and
<https://man7.org/linux/man-pages/man3/setbuf.3.html>):
- `FILE *fopen(const char *path, const char *mode);`
- `int fclose(FILE *stream);`
- `int fflush(FILE *stream);`
- `void setbuf(FILE *restrict stream, char *restrict buf);`
- `int setvbuf(FILE *restrict stream, char *restrict buf, int mode, size_t size);`
  with modes `_IONBF`, `_IOLBF`, `_IOFBF`.

Direct (binary) I/O (Source: <https://en.cppreference.com/w/c/io/fread>,
<https://en.cppreference.com/w/c/io/fwrite>):
- `size_t fread(void *restrict buffer, size_t size, size_t count, FILE *restrict stream);`
- `size_t fwrite(const void *restrict buffer, size_t size, size_t count, FILE *restrict stream);`

Unformatted character/line I/O
(Source: <https://en.cppreference.com/w/c/io/fgetc>,
<https://en.cppreference.com/w/c/io/fgets>):
- `int fgetc(FILE *stream);` / `int getc(FILE *stream);` / `int getchar(void);`
- `char *fgets(char *restrict str, int count, FILE *restrict stream);`
- `int fputc(int ch, FILE *stream);` / `int putchar(int ch);` / `int fputs(...)`.

Formatted I/O (Source: <https://en.cppreference.com/w/c/io>):
- `int printf(...)`, `int fprintf(FILE*, ...)`, `int sprintf(char*, ...)`,
  `int snprintf(char *restrict buffer, size_t bufsz, ...);`
- `int scanf(...)`, `int fscanf(FILE*, ...)`, `int sscanf(...)`.

File positioning: `int fseek(FILE*, long, int);` with `SEEK_SET`/`SEEK_CUR`/
`SEEK_END`; `long ftell(FILE*)`; `rewind`; `fgetpos`/`fsetpos`.

Error/EOF probes (Source: <https://en.cppreference.com/w/c/io>):
- `int feof(FILE*)`, `int ferror(FILE*)`, `void clearerr(FILE*)`,
  `void perror(const char*)`.
- Macro constant `EOF` — "integer constant expression of type `int` and
  negative value".

Constants: `BUFSIZ`, `_IOFBF`/`_IOLBF`/`_IONBF`, `FOPEN_MAX`, `FILENAME_MAX`.
Source: <https://en.cppreference.com/w/c/io>.

### POSIX file-descriptor layer

- `ssize_t read(int fd, void buf[count], size_t count);`
  Source: <https://man7.org/linux/man-pages/man2/read.2.html>.
- `ssize_t write(int fd, const void buf[count], size_t count);`
  Source: <https://man7.org/linux/man-pages/man2/write.2.html>.
- `int poll(struct pollfd *fds, nfds_t nfds, int timeout);` with
  `POLLIN`/`POLLOUT`/`POLLERR`/`POLLHUP`/`POLLNVAL`.
  Source: <https://man7.org/linux/man-pages/man2/poll.2.html>.
- `select`, `epoll_create1`/`epoll_ctl`/`epoll_wait` (Linux-only)
  Source: <https://man7.org/linux/man-pages/man7/epoll.7.html>.
- `ssize_t getline(char **restrict lineptr, size_t *restrict n, FILE *restrict stream);`
  and `getdelim(..., int delim, ...)` — the alloc-or-grow line reader.
  Source: <https://man7.org/linux/man-pages/man3/getline.3.html>.

### GNU/POSIX extensions for custom and memory streams

- `FILE *fmemopen(void buf[size], size_t size, const char *mode);`
  Source: <https://man7.org/linux/man-pages/man3/fmemopen.3.html>.
- `FILE *open_memstream(char **ptr, size_t *sizeloc);` — dynamically growing
  write buffer.
  Source: <https://man7.org/linux/man-pages/man3/open_memstream.3.html>.
- `FILE *fopencookie(void *restrict cookie, const char *restrict mode, cookie_io_functions_t io_funcs);`
  — the *extension point*: four hook functions `read`/`write`/`seek`/`close`.
  Source: <https://man7.org/linux/man-pages/man3/fopencookie.3.html>.

### Community API shapes

- **libuv**: `uv_stream_t` abstract handle; `int uv_read_start(uv_stream_t*, uv_alloc_cb, uv_read_cb);`,
  `int uv_read_stop(uv_stream_t*);`, `int uv_write(uv_write_t*, uv_stream_t*, const uv_buf_t[], unsigned int, uv_write_cb);`,
  `int uv_try_write(...)`. Callback signature
  `void (*uv_read_cb)(uv_stream_t*, ssize_t nread, const uv_buf_t*)`.
  Source: <https://docs.libuv.org/en/v1.x/stream.html>.
- **libevent**: `struct bufferevent *bufferevent_socket_new(...)`,
  `void bufferevent_setcb(bev, readcb, writecb, eventcb, ctx)`,
  `size_t bufferevent_read(bev, void *data, size_t size)`,
  `int bufferevent_write(bev, const void *data, size_t size)`,
  `int bufferevent_set_timeouts(bev, const struct timeval*, const struct timeval*)`,
  `void bufferevent_setwatermark(bev, short events, size_t lowmark, size_t highmark)`.
  Event flags `BEV_EVENT_EOF`, `BEV_EVENT_ERROR`, `BEV_EVENT_TIMEOUT`,
  `BEV_EVENT_READING`, `BEV_EVENT_WRITING`.
  Source: <https://libevent.org/doc/bufferevent_8h.html>.
- **zlib**: `z_stream` carries `const Bytef *next_in; uInt avail_in; uLong total_in;`
  and `Bytef *next_out; uInt avail_out; uLong total_out; const char *msg;`.
  `int deflate(z_streamp strm, int flush);`, `int inflate(z_streamp strm, int flush);`.
  Source: <https://zlib.net/manual.html>.
- **OpenSSL BIO**: `BIO *BIO_new(BIO_s_mem());`, source/sink BIOs (`BIO_s_*`)
  and filter BIOs (`BIO_f_*`), chained with `BIO_push`. Source:
  <https://docs.openssl.org/master/man7/bio/>.

## 4. Error representation

C has **no exceptions and no Result type**; errors are signalled by four
different mechanisms, depending on layer:

1. **Sentinel return + `errno`** (POSIX fd layer). `read`/`write` "On error,
   -1 is returned, and *errno* is set to indicate the error." Sources:
   <https://man7.org/linux/man-pages/man2/read.2.html>,
   <https://man7.org/linux/man-pages/man2/write.2.html>.
   `errno` is "the integer variable ... set by system calls and some library
   functions in the event of an error"; it is thread-local, is never set to
   zero by a call, and "is significant only when the return value of the call
   indicated an error".
   Source: <https://man7.org/linux/man-pages/man3/errno.3.html>.
   Representative codes: `EAGAIN`/`EWOULDBLOCK` (would block), `EINTR`
   (interrupted), `EBADF`, `EFAULT`, `EIO`, `EPIPE`. Sources: read(2)/write(2).
2. **Sentinel value with no reason** (`FILE*` layer). `fopen` returns `NULL`
   on failure (the reason is in `errno`). `fgetc` returns `EOF` on failure —
   and *conflates* EOF and error, which is why `feof`/`ferror` must be probed:
   `fread` "does not distinguish between end-of-file and error, and callers
   must use `feof` and `ferror` to determine which occurred."
   Sources: <https://en.cppreference.com/w/c/io>,
   <https://en.cppreference.com/w/c/io/fread>.
3. **Sticky stream flags.** The `FILE` keeps an *error indicator* and an *eof*
   indicator; `ferror`/`feof` read them, `clearerr` resets them.
   Sources: <https://en.cppreference.com/w/c/io/FILE>,
   <https://en.cppreference.com/w/c/io/fgetc>.
4. **Return of `-1` or `EOF` overloaded onto a *length*.** `getline` returns
   -1 both at EOF and on error, distinguished only by `feof`/`ferror` + `errno`.
   Source: <https://man7.org/linux/man-pages/man3/getline.3.html>.

Community libraries change the shape: libuv uses **negative status codes**
(`UV_EOF` as a distinct value; `nread < 0` = error), libevent uses **event
flags** (`BEV_EVENT_EOF|BEV_EVENT_ERROR|BEV_EVENT_TIMEOUT`), zlib uses
**negative error constants** (`Z_STREAM_ERROR (-2)`, `Z_DATA_ERROR (-3)`,
`Z_MEM_ERROR (-4)`, `Z_BUF_ERROR (-5)`, `Z_VERSION_ERROR (-6)`) with `Z_OK 0`
and `Z_STREAM_END 1`. Sources:
<https://docs.libuv.org/en/v1.x/stream.html>,
<https://libevent.org/doc/bufferevent_8h.html>,
<https://zlib.net/manual.html>.

(Assessment: derived from the sources above: C's core defect is that the
*absence of data, the end of stream, and a failure* are all represented by
in-band sentinels (`EOF`, `-1`, `NULL`, 0) that a caller must disambiguate by
reading side-channel state; the community libraries then invent their own
out-of-band error channels.)

## 5. Ownership semantics

C has no type-level ownership. The contracts are stated in prose and are
consistent across the layers:

- **The caller owns every buffer, on both sides of a read and a write.**
  `read` writes into a caller-provided `buf` of `count` bytes; "It is not an
  error if this number is smaller than the number of bytes requested."
  Source: <https://man7.org/linux/man-pages/man2/read.2.html>. `fread`/
  `fwrite` likewise take a caller `buffer`.
  Source: <https://en.cppreference.com/w/c/io/fread>.
- **The stream handle is a heap object owned by the open/close pair.**
  `fopen` returns a `FILE*`; `fclose` disassociates it, and "The value of a
  pointer to a `FILE` object is indeterminate after a file is closed
  (garbage)." Output streams are flushed before closing. All open files are
  closed at `exit`. Source: <https://man7.org/linux/man-pages/man3/stdio.3.html>.
- **The buffered state can be caller-provided.** `setvbuf(stream, buf, mode, size)`
  lets the caller supply the buffer; but it "may be used only after opening a
  stream and before any other operations have been performed on it", and the
  supplied buffer "must still exist by the time *stream* is closed, which also
  happens at program termination" — otherwise it is UB.
  Source: <https://man7.org/linux/man-pages/man3/setbuf.3.html>.
- **`fopencookie` transfers lifetime via a `void*` cookie.** The library
  "automatically supplies the cookie as the first argument when calling the
  hook functions"; the `close` hook is documented to "free buffers allocated
  for the stream". Source: <https://man7.org/linux/man-pages/man3/fopencookie.3.html>.
- **`getline` is the one stdlib function that allocates *for* the caller.**
  "If `*lineptr` is set to NULL before the call, then `getline()` will allocate
  a buffer ... This buffer should be freed by the user program even if
  `getline()` failed." Source: <https://man7.org/linux/man-pages/man3/getline.3.html>.
- **`open_memstream` allocates and hands back the buffer.** "After closing the
  stream, the caller should `free(3)` this buffer."
  Source: <https://man7.org/linux/man-pages/man3/open_memstream.3.html>.

(Assessment: derived from the sources above: C's rule is "caller allocates,
caller frees"; the only allocations are explicit, separate and documented, and
the stream handle itself is a caller-owned heap object whose lifetime is tied
to `fopen`/`fclose`.)

## 6. Blocking / non-blocking

- **`FILE*` streams are blocking by default.** `fread` reads "as if by calling
  `fgetc` *size* times"; `fgetc` blocks until a character is available.
  Source: <https://en.cppreference.com/w/c/io/fread>. The buffering modes
  (unbuffered/line/fully buffered) are a *latency* control, not a
  blocking-control: `setvbuf` "may be used ... to change its buffer."
  Source: <https://man7.org/linux/man-pages/man3/setbuf.3.html>.
- **The fd layer opts into non-blocking with `O_NONBLOCK`**, after which
  `read`/`write` return `EAGAIN`/`EWOULDBLOCK` instead of waiting.
  Sources: <https://man7.org/linux/man-pages/man2/read.2.html>,
  <https://man7.org/linux/man-pages/man2/write.2.html>.
- **Readiness multiplexing is a separate API.** `poll` waits for one of a set
  of fds; "If none of the events requested (and no error) has occurred for any
  of the file descriptors, then `poll()` blocks until one of the events
  occurs." `timeout` is in milliseconds, negative = infinite, zero = return
  immediately. Source: <https://man7.org/linux/man-pages/man2/poll.2.html>.
  `epoll` is the scalable Linux variant with level-triggered and
  edge-triggered modes: "the difference ... edge-triggered mode delivers events
  only when changes occur on the monitored file descriptor."
  Source: <https://man7.org/linux/man-pages/man7/epoll.7.html>.
- **Async I/O is a third, separate model.** POSIX AIO "allows applications to
  initiate one or more I/O operations that are performed asynchronously (i.e.,
  in the background) ... notified ... by delivery of a signal, by
  instantiation of a thread, or no notification at all."
  Source: <https://man7.org/linux/man-pages/man7/aio.7.html>.
- **Community answer: callback-driven buffered streams.** libuv
  `uv_read_start(stream, alloc_cb, read_cb)` "Read data from an incoming
  stream. The `uv_read_cb` callback will be made several times until there is
  no more data to read or `uv_read_stop()` is called."
  Source: <https://docs.libuv.org/en/v1.x/stream.html>. libevent bufferevents
  "get filled and drained automatically. The user ... no longer deals directly
  with the I/O, but instead is reading from input and writing to output
  buffers." Source: <https://libevent.org/doc/bufferevent_8h.html>.

(Assessment: derived from the sources above: C gives you *three disconnected
concurrency models* — blocking stdio, readiness-multiplexing on fds, and
signal/thread AIO — with no unified stream abstraction; any single
blocking/non-blocking story is an application-level choice.)

## 7. Byte streams vs text streams

C distinguishes them by **mode**, not by type:

- **Opening mode**, documented on `fopen` and on `FILE`: "A *text stream* is an
  ordered sequence of characters that can be composed into lines ... A *binary
  stream* is an ordered sequence of characters that can transparently record
  internal data." A binary stream round-trips bytes exactly (except trailing
  NULs may be appended); a text stream may translate: "C streams on Windows OS
  convert `'\n'` to `'\r\n'` on output, and convert `'\r\n'` to `'\n'` on
  input." Source: <https://en.cppreference.com/w/cpp/io/c/FILE>.
  POSIX implementations do not distinguish the two: "there is no special
  mapping for `'\n'` or any other characters." Same source.
- **Wide vs narrow** is a second, orthogonal axis: the first call to `fwide`
  or to any I/O function sets a stream's *orientation* (narrow or wide); once
  set, only `freopen` can change it, and mixing is forbidden.
  Source: <https://en.cppreference.com/w/cpp/io/c/FILE>.
- **Buffering is one layer, set per stream**, not layered by kind: `setvbuf`
  chooses `_IONBF`/`_IOLBF`/`_IOFBF`. "Normally, all files are block buffered.
  If a stream refers to a terminal ... it is line buffered. The standard error
  stream is always unbuffered by default." Source:
  <https://man7.org/linux/man-pages/man3/setbuf.3.html>. There is only **one**
  buffer per `FILE`; you cannot stack a text-buffering layer over a byte layer
  the way C++ or Java do.

**Partial reads are reported as a short return, and are *not* an error.**
`read`: "It is not an error if this number is smaller than the number of bytes
requested; this may happen for example because fewer bytes are actually
available right now ... or because `read()` was interrupted by a signal."
Source: <https://man7.org/linux/man-pages/man2/read.2.html>. `fread` returns
"Number of objects read successfully, which may be less than `count` if an
error or end-of-file condition occurs." Source:
<https://en.cppreference.com/w/c/io/fread>. Likewise `write` "Note that a
successful `write()` may transfer fewer than *count* bytes." Source:
<https://man7.org/linux/man-pages/man2/write.2.html>.

`fgets` shows the text-layer variant of "partial": it stops at a newline or
after `count - 1` characters, keeps the newline, and NUL-terminates — so a
"line read" is itself a bounded partial read. Source:
<https://en.cppreference.com/w/c/io/fgets>.

(Assessment: derived from the sources above: C reports a short read through the
*same* return channel as success and gives the caller no "you got a full
request" flag; the only way to know whether more bytes remain is to compare
against the requested count and then probe `feof`/`ferror`.)

## 8. Timeouts

There is **no timeout parameter on any C stream call**. `read`, `write`,
`fread`, `fwrite`, `fgetc` have no timeout argument; a blocked call blocks
until data, EOF or a signal. Sources: read(2)/write(2),
<https://en.cppreference.com/w/c/io/fread>.

Timeouts appear only at the multiplexing layer:
- `poll(..., int timeout)` — milliseconds; "The *timeout* argument specifies
  the number of milliseconds that `poll()` should block waiting for a file
  descriptor to become ready"; negative = infinite, zero = poll-once.
  Source: <https://man7.org/linux/man-pages/man2/poll.2.html>.
- `ppoll(..., const struct timespec *tmo_p, ...)` — nanosecond precision,
  "`ppoll()` allows an application to safely wait until either a file
  descriptor becomes ready or until a signal is caught." Same source.
- **Cancellation of a blocked read is by signal.** `read` returns `EINTR` "if
  the call was interrupted by a signal before any data was read."
  Source: <https://man7.org/linux/man-pages/man2/read.2.html>. Applications
  must handle `EINTR` and retry (or use `SA_RESTART`); this is the closest C
  has to cancellation of a pending read.
- **libevent adds per-bufferevent timeouts**: `bufferevent_set_timeouts(bev,
  timeout_read, timeout_write)`; on expiry "the corresponding operation (EV_READ
  or EV_WRITE) becomes disabled ... The bufferevent's event callback is called
  with the `BEV_EVENT_TIMEOUT|BEV_EVENT_READING` ...".
  Source: <https://libevent.org/doc/bufferevent_8h.html>.
- **POSIX AIO has cancellation**: `aio_cancel(fd, aiocbp)` with results
  `AIO_CANCELED`/`AIO_NOTCANCELED`/`AIO_ALLDONE`, and `aio_error` reports
  `ECANCELED`. Source: <https://man7.org/linux/man-pages/man7/aio.7.html>.

(Assessment: derived from the sources above: C represents a timeout as an
argument to a *separate wait function* (`poll`) or as a signal, never as a
property of the stream or the read call itself.)

## 9. End-of-stream and error signalling

This is C's sharpest design seam: **EOF and error share the return value and
must be separated by side-channel state.**

- **`fread`**: "If `size` or `count` is zero, `fread` returns zero and performs
  no other action. `fread` does not distinguish between end-of-file and error,
  and callers must use `feof` and `ferror` to determine which occurred."
  Source: <https://en.cppreference.com/w/c/io/fread>.
- **`fgetc`**: "On failure, returns `EOF`. If the failure has been caused by
  end-of-file condition, additionally sets the *eof* indicator ... If the
  failure has been caused by some other error, sets the *error* indicator."
  Source: <https://en.cppreference.com/w/c/io/fgetc>.
- **`read(2)`**: "On success, the number of bytes read is returned (**zero
  indicates end of file**) ... On error, -1 is returned, and *errno* is set."
  So the zero/short distinction is at least local to one call here.
  Source: <https://man7.org/linux/man-pages/man2/read.2.html>.
- **`fgets`**: returns `str` on success, "null pointer on failure. If the
  end-of-file condition is encountered, sets the *eof* indicator ... This is
  only a failure if it causes no bytes to be read". Source:
  <https://en.cppreference.com/w/c/io/fgets>.
- **`getline`**: "At end of file, both functions return -1 with the file
  stream end-of-file indicator set. On error, both functions return -1 with
  the file stream error indicator set, and *errno* is set." Source:
  <https://man7.org/linux/man-pages/man3/getline.3.html>.
- **Flush failure is sticky**: `fflush` "Returns zero on success. Otherwise
  `EOF` is returned and the error indicator of the file stream is set."
  Source: <https://en.cppreference.com/w/c/io/fflush>. Because output is
  buffered, a write error may surface only at `fflush`/`fclose`, not at the
  `fwrite` that produced the bytes.
- **Poll conflates readiness with error/hangup**: `POLLERR`, `POLLHUP`,
  `POLLNVAL` are returned in `revents`; for a stream socket `POLLHUP` "merely
  indicates that the peer closed its end of the channel. Subsequent reads from
  the channel will return 0 (end of file) only after all outstanding data in
  the channel has been consumed." Source:
  <https://man7.org/linux/man-pages/man2/poll.2.html>.
- **libuv makes EOF a distinct negative code**: "When we've reached EOF,
  *nread* will be set to `UV_EOF`. When *nread* < 0, the *buf* parameter might
  not point to a valid buffer." Also: "*nread* might be 0, which does *not*
  indicate an error or EOF. This is equivalent to `EAGAIN` or `EWOULDBLOCK`
  under `read(2)`." Source: <https://docs.libuv.org/en/v1.x/stream.html>.
- **zlib makes end-of-stream a positive code and errors negative**:
  `Z_STREAM_END 1` vs `Z_OK 0` vs `Z_DATA_ERROR (-3)`.
  Source: <https://zlib.net/manual.html>.

(Assessment: derived from the sources above: C's `FILE` layer forces the
caller into a *two-call* protocol (`op` then `feof`/`ferror`), and makes "short
read" indistinguishable from "exact read + nothing more" without that probe.
libuv's `UV_EOF` and zlib's `Z_STREAM_END` are the improvements the C
ecosystem itself adopted.)

## 10. Interesting design decisions

- **The `FILE` state blob as a single opaque carrier.** cppreference lists
  buffering mode, both indicators, position, parse state, orientation and
  (C++17) a lock as fields of the *same* object — the whole stream lifecycle
  travels in one handle. Source: <https://en.cppreference.com/w/cpp/io/c/FILE>.
- **`fopencookie` — a four-hook vtable that turns any data source into a
  `FILE*`.** `read`/`write`/`seek`/`close` are function pointers plus a
  `void*` cookie; the library supplies the cookie automatically.
  Source: <https://man7.org/linux/man-pages/man3/fopencookie.3.html>. This is
  the C ancestor of Go's `io.Reader`/`Writer`, inverted into a callback table.
- **The hook contract mirrors `read(2)` exactly**: `read` returns "the number
  of bytes copied into `buf`, 0 on end of file, or -1 on error"; `write` "must
  not return a negative value" — so write failure is signalled by short/zero
  return, not -1. Source: <https://man7.org/linux/man-pages/man3/fopencookie.3.html>.
  This asymmetry (read uses -1, write cannot) is a deliberate, quirky choice.
- **`open_memstream` — a *growable* write-only memory stream.** "The function
  dynamically allocates the buffer, and the buffer automatically grows as
  needed"; the caller retrieves pointer+size only after flush/close, and a NUL
  is maintained but excluded from the size. Source:
  <https://man7.org/linux/man-pages/man3/open_memstream.3.html>.
- **`getline` — the alloc-or-grow convention.** A single call takes
  `char**`/`size_t*` and both reads the line and maintains the buffer across
  calls; the returned length "can be used to handle embedded null bytes in the
  line read", i.e. it is length-based, not NUL-based. Source:
  <https://man7.org/linux/man-pages/man3/getline.3.html>.
- **Buffering as an explicit, one-shot, pre-I/O configuration.** `setvbuf`
  "may be used only after opening a stream and before any other operations
  have been performed"; there is no way to change buffering later.
  Source: <https://man7.org/linux/man-pages/man3/setbuf.3.html>.
- **The `(buffer, size, count)` triple in `fread`/`fwrite`.** Reading is
  expressed in *elements* of `size` bytes, and the return is a count of
  *complete elements*, so a partial element is silently indeterminate:
  "If a partial element is read, its value is indeterminate."
  Source: <https://en.cppreference.com/w/c/io/fread>.
- **Edge- vs level-triggered as a per-fd registration flag.** `EPOLLET`
  changes the *meaning* of a readiness notification; the docs warn that
  "application that employs the `EPOLLET` flag should use nonblocking file
  descriptors to avoid having a blocking read or write starve a task."
  Source: <https://man7.org/linux/man-pages/man7/epoll.7.html>.
- **libuv's explicit "0 ≠ EOF" rule.** Because the callback also carries
  `nread == 0` as a legal "no data / would block", it spells out that only
  `UV_EOF` means end and only `nread < 0` means error. Source:
  <https://docs.libuv.org/en/v1.x/stream.html>.
- **libevent's watermarks.** `bufferevent_setwatermark(bev, events, lowmark,
  highmark)` decouples *when the callback fires* (low watermark) from *when
  reading pauses* (high watermark) — an explicit backpressure knob. Source:
  <https://libevent.org/doc/bufferevent_8h.html>.
- **zlib's in/out pointer state machine.** The caller advances
  `next_in`/`avail_in` and `next_out`/`avail_out`; `total_in`/`total_out` are
  cumulative. Source: <https://zlib.net/manual.html>. This is a canonical
  "streaming transform over bounded buffers" contract.

## 11. Decisions NOT to copy

- **Signalling EOF through the same sentinel as error** (`EOF`, `-1`) and
  requiring `feof`/`ferror` as a follow-up probe. It forces every read site
  into a two-call protocol and is the single most error-prone part of stdio.
  Sources: <https://en.cppreference.com/w/c/io/fread>,
  <https://en.cppreference.com/w/c/io/fgetc>.
- **Returning the *length* of a short read without saying whether the request
  was satisfied.** Source: <https://man7.org/linux/man-pages/man2/read.2.html>.
- **`fread`/`fwrite`'s element-count return.** Reporting complete elements
  discards the number of bytes actually transferred when `size > 1`, and a
  partial element is "indeterminate". Source:
  <https://en.cppreference.com/w/c/io/fread>.
- **`errno` as a global side channel read *after* the fact.** The man page
  itself warns that any intervening call (even `printf`) may clobber `errno`,
  so the value must be saved immediately. Source:
  <https://man7.org/linux/man-pages/man3/errno.3.html>.
- **A buffering mode frozen at open time.** `setvbuf` must be called before
  any I/O; a modern stream should be able to change/adjust buffering during
  its life. Source: <https://man7.org/linux/man-pages/man3/setbuf.3.html>.
- **Text/binary as a hidden mode that silently rewrites bytes** (`\n` ↔
  `\r\n` on Windows). A byte stream should never mutate data; translation
  must be an explicit, separate layer. Source:
  <https://en.cppreference.com/w/cpp/io/c/FILE>.
- **Wide/narrow orientation that can never be changed** except by `freopen`.
  Source: <https://en.cppreference.com/w/cpp/io/c/FILE>.
- **The `fopencookie` read/write asymmetry** (read returns -1 on error, write
  may not return negative). Uniform error semantics are better.
  Source: <https://man7.org/linux/man-pages/man3/fopencookie.3.html>.
- **NUL-terminated text as the default interface.** `fgets` cannot represent
  embedded NULs and its buffer size is an `int`; `getline` had to be invented
  to fix exactly this. Sources: <https://en.cppreference.com/w/c/io/fgets>,
  <https://man7.org/linux/man-pages/man3/getline.3.html>.
- **`void*` cookie + function-pointer hooks as the only extension point.**
  Ownership is implicit and unchecked; a wrong hook is UB, not a type error.
  Source: <https://man7.org/linux/man-pages/man3/fopencookie.3.html>.

## 12. Ideas fitting Mojo

- **A `Reader`/`Writer` trait pair mirrors `fopencookie` without the UB.**
  Mojo traits (`mojov1/keywords/trait`) give the same "any source is a stream"
  extensibility with compile-time conformance instead of a `void*` cookie plus
  four raw function pointers. The hook signatures to model on are
  `read(buf, size) -> n` / `write(buf, size) -> n` (with 0 = EOF for read).
  Source: <https://man7.org/linux/man-pages/man3/fopencookie.3.html>; Mojo
  trait mechanism: `mojov1/keywords/trait`.
- **A typed error that separates EOF, short read and failure.** C collapses
  these into `EOF`/`-1`/`0`; Mojo's `raises` with a typed error
  (`mojov1/errors/error-model`) can make the three outcomes distinct at the
  type level, exactly as libuv's `UV_EOF` and zlib's `Z_STREAM_END` try to do
  with negative/positive codes but without compiler enforcement.
  Sources: zlib manual, libuv stream docs, `mojov1/errors/error-model`.
- **`Span[UInt8]` replaces the `(buffer, size, count)` triple.** C's
  `fread(void*, size_t, size_t, FILE*)` can express an element size > 1 and
  thereby lose the byte count; Mojo's `Span` is "a non-owning view of
  contiguous data" with an explicit length (`mojov1/types/collections`), so
  the byte count is always exact and the partial-read contract is unambiguous.
- **Return an explicit status carrying "wrote n of m".** Boost.Asio's
  stream requirements (from the sibling C++ survey) and C's `read` both need
  the caller to compare `n` with the request; a Mojo read that returns a
  small, explicit result type (`bytes_read`, `eof`) makes that check
  impossible to skip. Sources: read(2), Boost.Asio streams.
- **Keep the caller-owned buffer for the hot path, add an allocating
  convenience.** `getline`/`open_memstream` show the value of an allocator
  variant; in Mojo this is `def read_into(mut buf: Span[UInt8]) -> Int` plus
  `def read_all() raises -> List[UInt8]`, so the zero-copy path stays
  available (C's whole point) while the safe default is owned. Sources:
  getline(3), open_memstream(3), `mojov1/memory/ownership-and-lifetimes`.
- **`with`-scoped handles replace `fopen`/`fclose` + "pointer indeterminate
  after close".** Mojo's `with` (`mojov1/keywords/with`) guarantees the
  handle's `deinit` runs on every exit path, which is exactly what `setvbuf`'s
  "buffer must outlive the stream until close" caveat makes manual in C.
  Source: <https://man7.org/linux/man-pages/man3/setbuf.3.html>.
- **A `comptime` buffering policy instead of a runtime `setvbuf` mode** — the
  three `_IO*` modes become compile-time choices with the same semantics.
  Source: <https://man7.org/linux/man-pages/man3/setbuf.3.html>;
  `mojov1/keywords/comptime`.
- **Explicit readiness as a separate layer, not a stream method.** `poll`'s
  separation of "wait until ready" from "read" is a good boundary: Mojo should
  keep a `poll`-like readiness function out of the `Reader` trait, because
  C shows that mixing them (`O_NONBLOCK` + `FILE`) produces the worst of both.
  Sources: <https://man7.org/linux/man-pages/man2/poll.2.html>, read(2).
- **Borrowed `FILE*`-style FFI is expressible.** Mojo can wrap a C `FILE*` or
  fd via `Span(unsafe_ptr=..., length=...)` and `external_call` so the io
  library interoperates with the C ecosystem without copying — the same
  zero-copy spirit the C APIs demand. Source: `mojov1/interop/calling-c`.

## Sources

- ISO C / C++ `FILE` state, text vs binary, orientation, indicators:
  <https://en.cppreference.com/w/cpp/io/c/FILE>
- C file input/output overview (`FILE`, functions, `EOF`, buffering macros):
  <https://en.cppreference.com/w/c/io>
- C standard-library header list:
  <https://en.cppreference.com/w/c/header>
- `fread` (short read, EOF-vs-error, element count):
  <https://en.cppreference.com/w/c/io/fread>
- `fwrite`:
  <https://en.cppreference.com/w/c/io/fwrite>
- `fgetc`/`getc` (EOF sentinel + indicators):
  <https://en.cppreference.com/w/c/io/fgetc>
- `fgets` (bounded line read, NUL-termination):
  <https://en.cppreference.com/w/c/io/fgets>
- `fflush` (sticky error indicator):
  <https://en.cppreference.com/w/c/io/fflush>
- Linux `read(2)`:
  <https://man7.org/linux/man-pages/man2/read.2.html>
- Linux `write(2)`:
  <https://man7.org/linux/man-pages/man2/write.2.html>
- Linux `errno(3)`:
  <https://man7.org/linux/man-pages/man3/errno.3.html>
- Linux `stdio(3)` (open/close lifecycle, standard streams):
  <https://man7.org/linux/man-pages/man3/stdio.3.html>
- Linux `setbuf(3)`/`setvbuf(3)` (buffering modes, buffer lifetime):
  <https://man7.org/linux/man-pages/man3/setbuf.3.html>
- Linux `poll(2)` (readiness, timeout semantics, POLL* flags):
  <https://man7.org/linux/man-pages/man2/poll.2.html>
- Linux `epoll(7)` (level/edge triggering):
  <https://man7.org/linux/man-pages/man7/epoll.7.html>
- Linux `aio(7)` (async I/O, cancellation, notification):
  <https://man7.org/linux/man-pages/man7/aio.7.html>
- Linux `getline(3)` (alloc-or-grow, EOF-vs-error):
  <https://man7.org/linux/man-pages/man3/getline.3.html>
- Linux `fmemopen(3)` (memory-backed stream):
  <https://man7.org/linux/man-pages/man3/fmemopen.3.html>
- Linux `open_memstream(3)` (growable write buffer, caller frees):
  <https://man7.org/linux/man-pages/man3/open_memstream.3.html>
- Linux `fopencookie(3)` (custom stream hooks):
  <https://man7.org/linux/man-pages/man3/fopencookie.3.html>
- libuv `uv_stream_t` (async buffered stream, UV_EOF, 0 ≠ EOF):
  <https://docs.libuv.org/en/v1.x/stream.html>
- libevent `bufferevent` (input/output evbuffers, watermarks, timeouts):
  <https://libevent.org/doc/bufferevent_8h.html>
- OpenSSL `bio` overview (source/sink vs filter BIOs, Apache-2.0):
  <https://docs.openssl.org/master/man7/bio/>
- zlib manual (`z_stream`, flush values, return codes, license):
  <https://zlib.net/manual.html>
- libcurl easy interface (blocking perform):
  <https://curl.se/libcurl/c/libcurl-easy.html>
- Mojo `mojov1` buch, `stdlib/io` (Mojo-side reference for section 12)
- Mojo `mojov1` buch, `keywords/trait` (`Reader`/`Writer` trait shape)
- Mojo `mojov1` buch, `keywords/with` (scoped handle cleanup)
- Mojo `mojov1` buch, `errors/error-model` (`raises`, typed errors, EOF vs error)
- Mojo `mojov1` buch, `types/collections` (`Span`, borrowed buffers)
- Mojo `mojov1` buch, `memory/ownership-and-lifetimes` (owned vs borrowed)
- Mojo `mojov1` buch, `keywords/comptime` (compile-time buffering policy)
- Mojo `mojov1` buch, `interop/calling-c` (wrapping C buffers/handles)
