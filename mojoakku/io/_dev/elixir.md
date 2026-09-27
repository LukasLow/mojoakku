# io research: Elixir

Scope: the Elixir `IO`/`IO.Stream`/`Stream` stdlib layer **and** the underlying
Erlang/OTP I/O model (`:file`, `io` servers, the Erlang I/O Protocol, and the
`gen_tcp`/`inet` port+socket I/O model with passive vs active modes). All claims
cite the Elixir v1.20.4 docs/source and OTP 29.1.1 docs/source unless marked
otherwise. Every statement carries a source; derived statements are marked
`(Assessment: derived from <sources>)`.

## 1. Standard library support

On the BEAM, "byte and text streams" are split across two languages' stdlibs
that share one runtime:

Elixir stdlib (v1.20.4):
- **`IO`** — "Functions handling input/output (IO)", with functions
  `read/2`, `binread/2`, `write/2`, `binwrite/2`, `puts/2`, `gets/2`, `getn/2,3`,
  `inspect/2,3`, `stream/2`, `binstream/2`, `chardata_to_string/1`,
  `iodata_to_binary/1`, `iodata_length/1`, `iodata_empty?/1`
  (https://hexdocs.pm/elixir/IO.html#summary;
  `elixir/lib/elixir/lib/io.ex` v1.20.4).
- **`IO.Stream`** — "Defines an `IO.Stream` struct returned by `IO.stream/2` and
  `IO.binstream/2`", with public fields `device`, `raw`, `line_or_bytes`
  (https://hexdocs.pm/elixir/IO.Stream.html; source
  `elixir/lib/elixir/lib/io/stream.ex`).
- **`Stream`** — "composable, lazy enumerables" (`Stream.resource/3`,
  `Stream.transform/3,4,5`, `Stream.iterate/2`, `Stream.unfold/2`, `Stream.interval/1`,
  `Stream.timer/1`, ...) (https://hexdocs.pm/elixir/Stream.html#summary).
- **`File`** and **`File.Stream`** — `File.open/2`, `File.stream!/3`,
  `File.read/2`, and the low-level `:file` interop
  (https://hexdocs.pm/elixir/File.html; https://hexdocs.pm/elixir/File.Stream.html).
- **`StringIO`** — an in-memory IO device wrapping a string
  (https://hexdocs.pm/elixir/StringIO.html).
- **`Enumerable`** and **`Collectable`** protocols — the generic iteration and
  collection contracts; `IO.Stream` implements both read and write
  (https://hexdocs.pm/elixir/IO.html#stream/2).

Erlang/OTP stdlib + kernel (OTP 29.1.1):
- **`io`** — "Standard I/O server interface functions" (`io:get_chars/3`,
  `io:get_line/2`, `io:put_chars/2`, `io:fread/3`, `io:format/3`,
  `io:setopts/2`, `io:getopts/1`), all talking to an I/O server process
  (https://www.erlang.org/doc/apps/stdlib/io.html#summary).
- **The Erlang I/O Protocol** — the `io_request`/`io_reply` message protocol
  between clients and I/O server processes
  (https://www.erlang.org/doc/apps/stdlib/io_protocol.html).
- **`file`** — file interface with `file:open/2`, `file:read/2`,
  `file:read_line/1`, `file:write/2`, `file:position/2`, `file:pread/3`,
  `raw` mode and the buffering options `read_ahead`/`delayed_write`
  (https://www.erlang.org/doc/apps/kernel/file.html#summary).
- **`gen_tcp`/`inet`** — the socket/port I/O model with `gen_tcp:recv/3`,
  `gen_tcp:send/2` and the `{active, true|false|once|N}` option
  (https://www.erlang.org/doc/apps/kernel/gen_tcp.html).

`(Assessment: derived from the two stdlib summaries — the actual generic
stream/reader abstraction is the pair `IO.device` + the I/O protocol, not a
`Reader` trait.)`

## 2. Relevant community libraries

| name | maintainer / publisher | maturity | license | notes |
| --- | --- | --- | --- | --- |
| `gen_stage` (hex 1.3.2) | publisher `josevalim`; repo `elixir-lang/gen_stage` | last updated Jul 15 2025; 62,766,172 all-time downloads; 143 dependants | Apache-2.0 | "Producer and consumer actors with back-pressure for Elixir" (https://hex.pm/packages/gen_stage) |
| `flow` (hex 1.2.4) | publisher `josevalim`; repo `dashbitco/flow`; owner `dashbit` | last updated Mar 21 2023; 10,399,731 all-time downloads; 42 dependants | Apache-2.0 | "Computational parallel flows for Elixir" — `Flow.from_enumerable/1`+`Flow.partition/1` built on `gen_stage` (https://hex.pm/packages/flow) |
| `broadway` (hex 1.3.0) | publisher `josevalim`; repo `dashbitco/broadway`; owner `broadway` | last updated Apr 17 2026; 14,042,669 all-time downloads; 59 dependants | Apache-2.0 | "Build concurrent and multi-stage data ingestion and data processing pipelines" (https://hex.pm/packages/broadway) |

These three are pipeline/backpressure frameworks layered on `gen_stage`, not
byte-stream codecs; they are the community answer to "streaming with
backpressure" on the BEAM. `(Assessment: derived from the three Hex pages.)`

## 3. Exposed APIs

Elixir `IO` (https://hexdocs.pm/elixir/IO.html; line anchors from the
"View Source" links):
- Types: `device() :: atom | pid` (`io.ex:127`), `nodata() :: {:error, term} | :eof`
  (`io.ex:128`), `chardata() :: String.t() | maybe_improper_list(char | chardata, String.t() | [])`
  (`io.ex:129`).
- `read(device \\ :stdio, line_or_chars)` with
  `@spec read(device, :eof | :line | non_neg_integer) :: chardata | nodata`
  (`io.ex:177`) — delegates `:line` to `:io.get_line/2`, `count` to
  `:io.get_chars/3`, `:eof` to `getn/3` (`io.ex` read clauses).
- `binread(device \\ :stdio, line_or_chars)` with
  `@spec binread(device, :eof | :line | non_neg_integer) :: iodata | nodata`
  (`io.ex:234`) — `:line` → `:file.read_line/1`, count → `:file.read/2`,
  `:eof` → loop over `:file.read/2` in 4096-byte steps
  (`@read_all_size 4096`, `io.ex`).
- `write(device \\ :stdio, chardata)` `:: :ok` (`io.ex:284`) → `:io.put_chars/2`.
- `binwrite(device \\ :stdio, iodata)` `:: :ok` (`io.ex:306`) → `:file.write/2`
  (converts `{:error, reason}` into `:erlang.error(reason)`, `io.ex` `binwrite` body).
- `puts/2`, `gets/2`, `getn/2,3` (`:: chardata | nodata`), `inspect/2,3`.
- `stream(device \\ :stdio, line_or_codepoints)` `:: Enumerable.t()`
  (`io.ex:667`) and `binstream/2` (`io.ex:708`); both build
  `IO.Stream.__build__(device, raw, line_or_bytes)`
  (`elixir/lib/elixir/lib/io/stream.ex`).
- Conversion helpers: `chardata_to_string/1`, `iodata_to_binary/1`,
  `iodata_length/1`, `iodata_empty?/1` (since 1.20.0).

`IO.Stream` struct + protocol implementations (source
`elixir/lib/elixir/lib/io/stream.ex`):
- `%IO.Stream{device: IO.device(), raw: boolean(), line_or_bytes: :line | non_neg_integer()}`
  (https://hexdocs.pm/elixir/IO.Stream.html#t:t/0).
- `defimpl Collectable` — `into/1` returns a collector that calls
  `IO.binwrite(device, x)` when `raw: true`, else `IO.write(device, x)`.
- `defimpl Enumerable` — `reduce/3` wraps `IO.each_stream/2` or
  `IO.each_binstream/2` inside `Stream.resource(fn -> device end, next_fun, & &1)`;
  `count/1`, `member?/2`, `slice/1` all return `{:error, __MODULE__}` (i.e. no
  random access).
- `IO.StreamError` — `defexception [:reason]` with message
  `"error during streaming: #{inspect(reason)}"`.

Erlang `file` (https://www.erlang.org/doc/apps/kernel/file.html):
- `read(IoDevice, Number) -> {ok, Data} | eof | {error, Reason}` with
  `Data :: string() | binary()`, `Reason :: posix() | badarg | terminated | {no_translation, unicode, latin1}`
  (`file.erl:1618`).
- `read_line(IoDevice) -> {ok, Data} | eof | {error, Reason}` (`file.erl:1680`).
- `write(IoDevice, Bytes) -> ok | {error, Reason}`.
- `open(File, Modes)` modes include `read | write | append | raw | binary |
  {delayed_write, Size, Delay} | delayed_write | {read_ahead, Size} | read_ahead |
  {encoding, unicode:encoding()} | sync` (`file.erl` `mode()`).
- `io_device() :: io_server() | fd()`; `io_server() :: pid()` — normal files are
  processes, `raw` files are descriptors (`file.erl` `io_device/0`, `fd/0`).

Erlang `gen_tcp` (https://www.erlang.org/doc/apps/kernel/gen_tcp.html):
- `recv(Socket, Length, Timeout) -> {ok, Packet} | {error, Reason}`,
  `Reason :: closed | timeout | inet:posix()`.
- `send(Socket, Packet) -> ok | {error, Reason}`,
  `Reason :: closed | {timeout, RestData} | inet:posix()`.
- `accept(ListenSocket, Timeout) -> {ok, Socket} | {error, closed | timeout | system_limit | posix()}`,
  `connect(Address, Port, Opts, Timeout)`.
- Option `{active, true | false | once | -32768..32767}` (negative values select
  `{active, N}`) plus `{packet, 0|1|2|4|raw|line|http|...}`, `{mode, list | binary}`,
  `{send_timeout, timeout()}`, `{buffer, non_neg_integer()}`, `{deliver, port | term}`.

`Stream` (https://hexdocs.pm/elixir/Stream.html):
- `resource(start_fun, next_fun, after_fun)`, `transform/3,4,5`,
  `unfold(acc, next_fun)`, `iterate(start_value, next_fun)`, `interval(n)`,
  `timer(n)`, `run/1`.

## 4. Error representation

The BEAM stream layers use **three different error styles at once**, which is a
core observation:

1. **In-band atoms + tagged tuples** (`file`, `io` protocol). `file:read/2`
   returns `{ok, Data} | eof | {error, Reason}` (`file.erl:1618`); `gen_tcp:recv/3`
   returns `{ok, Packet} | {error, closed | timeout | posix()}`
   (https://www.erlang.org/doc/apps/kernel/gen_tcp.html#recv/3).
2. **Exception on write** (`io` module). The `io` docs state: "The output
   functions all return `ok` if they are successful, or **exit** if they are not"
   (https://www.erlang.org/doc/apps/stdlib/io.html). Elixir's `IO.binwrite/2`
   deliberately re-raises: it maps `{:error, reason}` from `:file.write/2` to
   `:erlang.error(reason)` so the caller sees an exception rather than an error
   tuple (`io.ex` `binwrite` body).
3. **A dedicated exception for stream enumeration**. `IO.each_stream/2` and
   `IO.each_binstream/2` raise `IO.StreamError` with `reason` on `{:error, reason}`
   (`io.ex`; `IO.StreamError` in `io/stream.ex`). So iterating
   `IO.stream/2` with `Enum` turns a mid-stream I/O error into a raised
   `IO.StreamError %{reason: reason}`.

`File` adds the Elixir-wide **dual API**: plain functions return
`:ok`/`{:ok, result}`/`{:error, reason}`, bang variants return the result or
raise `File.Error` — e.g. `File.read("invalid.txt") #=> {:error, :enoent}` vs
`File.read!("invalid.txt") #=> raises File.Error`
(https://hexdocs.pm/elixir/File.html#module-api). `IO` itself has **no** bang
variants. `(Assessment: derived from IO.html summary + File.html module-api.)`

POSIX reason atoms are shared vocabulary: `file:posix()` lists `eacces`,
`eagain`, `ebadf`, `eio`, `enoent`, `enospc`, `estale`, `epipe`, ... and
`inet:posix()` reuses it plus `econnrefused`, `econnreset`, `etimedout`,
`ewouldblock` (https://www.erlang.org/doc/apps/kernel/file.html#module-posix-error-codes;
https://www.erlang.org/doc/apps/kernel/inet.html#posix-error-codes).
`format_error/1` turns a reason atom into English (`file:format_error/1`).

## 5. Ownership semantics

Elixir/Erlang have **no manual ownership and no explicit free**; all terms are
immutable and reachable garbage is reclaimed by the per-process GC. The relevant
"ownership" questions are buffer representation, process ownership and buffering:

- **Buffers are values on the process heap.** A read returns a fresh
  `binary()` (or list) owned by the caller; no `free` exists
  `(Assessment: derived from file.erl read/2 return type + BEAM value semantics)`.
- **A normal (non-`raw`) file handle is a process that owns the OS descriptor.**
  Elixir docs: "Every time a file is opened, Elixir spawns a new process. Writing
  to a file is equivalent to sending messages to the process." The owner is the
  opening process; "if the owner process terminates, the file is closed and the
  process itself terminates too. If any process to which the `io_device` is
  linked terminates, the file will be closed"
  (https://hexdocs.pm/elixir/File.html#module-processes-and-raw-files and
  `#open/2-io-devices`).
- **`raw` mode removes the process.** With `:raw`/`:ram` the open returns a low
  `file:fd()` and the caller must use the `:file` module directly
  (https://hexdocs.pm/elixir/File.html#open/2). The `io_device()` type is
  `io_server() | fd()` (`file.erl`).
- **Buffering is owned by the handle/OS, configured at open:** `{read_ahead, Size}`
  "Activates read data buffering... The extra data is buffered and returned in
  subsequent `read/2` calls"; `{delayed_write, Size, Delay}` buffers writes until
  `Size` bytes or `Delay` ms, and "the buffered data is also flushed before some
  other file operation than `write/2` is executed"
  (https://www.erlang.org/doc/apps/kernel/file.html#open/2).
- **The I/O server owns the buffered leftover.** The I/O Protocol keeps
  `RestChars` server-side: when a `get_until` function returns
  `{done, Result, RestChars}`, "`RestChars` is kept in the I/O server as a buffer
  for later input" (https://www.erlang.org/doc/apps/stdlib/io_protocol.html#input-requests).
- **`iodata` avoids copies.** "Concatenating multiple pieces of IO data just
  means putting them together inside a list... Most of the IO-based APIs, such as
  `:gen_tcp` and `IO`, receive IO data and write it to the socket directly without
  converting it to binary" (https://hexdocs.pm/elixir/IO.html#module-io-data).

`(Assessment: derived from the above sources — "ownership" on the BEAM is really
process lifetime + value GC, never manual free.)`

## 6. Blocking / non-blocking

This is the distinct BEAM story, and it exists at **two levels**.

**Synchronous calls (Elixir `IO`, `file`, `io` server).** `IO.read/2` and
friends send an `io_request` to the I/O server and wait for the matching
`io_reply`; there is no timeout parameter on `IO`, so the call blocks until the
server answers (`io_protocol.html#protocol-basics`; `IO` has no timeout arg,
IO.html). For `raw` files `:file.read/2` is a direct driver call.

**Sockets: passive vs active mode** (the distinct concurrency model):
- **Passive (`{active, false}`)** — inbound data and errors are pulled with
  `gen_tcp:recv/2,3`, which **blocks the calling process** until data, timeout or
  close. "If `{active, false}` is specified in the option list for the socket,
  packets and errors are retrieved by calling `recv/2,3`"
  (https://www.erlang.org/doc/apps/kernel/gen_tcp.html#connect/4).
- **Active (`{active, true}`)** — inbound data is **delivered as messages** to
  the socket owner's mailbox: `{tcp, Socket, Data}`, `{tcp_closed, Socket}`,
  `{tcp_error, Socket, Reason}` (gen_tcp.html#active-mode-socket-messages).
- **`{active, once}` / `{active, N}`** — bounded active mode. `{active, N}`
  counts down; when the counter reaches `0` the socket transitions to passive and
  sends `{tcp_passive, Socket}` (gen_tcp.html#active-mode-socket-messages and
  `option() :: {active, true | false | once | -32768..32767}`). `{active, once}`
  must be re-armed explicitly per message (gen_tcp.html#module-examples).

There is **no async/await and no event loop**: concurrency is "one process per
task", and blocking is cheap because the scheduler runs other processes while
one waits. `(Assessment: derived from gen_tcp active/passive docs + the
process-per-connection model shown in the gen_tcp server example.)`

Note the backend caveat: with `inet_backend = inet` (default), `send/2` is
non-blocking because the driver buffers the rest; with `inet_backend = socket`,
"there is no buffering... the user hangs either until all data has been sent or
the `send_timeout` timeout has been reached"
(gen_tcp.html#non_blocking_send).

## 7. Byte streams vs text streams

The two are distinguished **explicitly by function**, not by separate handle
types:

- **`IO.read/2` (text/Unicode) vs `IO.binread/2` (raw bytes).** `binread` docs:
  "Reads from the IO `device`. The operation is Unicode unsafe... do not use this
  function on IO devices in Unicode mode as it will return the wrong result"
  (IO.html#binread/2). `write/2` vs `binwrite/2` mirror this: `binwrite` "is meant
  to be used with 'raw' devices that are started without an encoding. The given
  `iodata` is written as is to the device, without conversion"
  (IO.html#binwrite/2).
- **Data-type distinction: `iodata` (bytes) vs `chardata` (codepoints).**
  "The only difference is that integers in IO data represent bytes while integers
  in chardata represent Unicode code points. Bytes are integers within `0..255`,
  while Unicode code points are integers within `0..0x10FFFF`"
  (https://hexdocs.pm/elixir/IO.html#module-chardata). `chardata_to_string/1` vs
  `iodata_to_binary/1` convert the two; applying the wrong one raises
  `ArgumentError` (same page).
- **The file encoding is a mode, set at open.** "By default, a file is opened in
  binary mode, which requires the functions `IO.binread/2` and `IO.binwrite/2`...
  A developer may pass `:utf8` as an option when opening the file, then the slower
  `IO.read/2` and `IO.write/2` functions must be used as they are responsible for
  doing the proper conversions"
  (https://hexdocs.pm/elixir/File.html#module-encoding).
- **Count units follow the encoding.** `IO.getn/3`: "If the IO `device` is a
  Unicode device, `count` implies the number of Unicode code points to be
  retrieved. Otherwise, `count` is the number of raw bytes"
  (IO.html#getn/3). `file:read/2` likewise: "For files where `encoding` is set to
  something else than `latin1`, one character can be represented by more than one
  byte... The parameter `Number` always denotes the number of *characters*"
  (file.erl:1562).
- **Buffering layering.** Text reads go through the I/O server process (which may
  do Unicode conversion); byte reads on `raw` files go straight to
  `:file.read/2`/`:file.read_line/1`
  (`io.ex` `binread` clauses). On sockets, `{mode, list | binary}` chooses list vs
  binary delivery and `{packet, ...}` frames packets before delivery
  (gen_tcp.html#option).
- **Partial reads are legal and reported by length, not by a flag.**
  `file:read/2`: "`{ok, Data}` — ... The list or binary is shorter than the number
  of bytes requested if end of file was reached" (file.erl:1568). On `gen_tcp`,
  `recv(Socket, Length, ...)` with `Length > 0` returns exactly `Length` "or an
  error; except if the socket is closed from the other side, then the last read
  before the one returning `{error, closed}` may return less than `Length` bytes"
  (gen_tcp.html#recv/3); `Length = 0` means "all available bytes are returned".

`(Assessment: derived from the above — byte/text is a function-pair + mode flag,
there is no distinct `Reader[Byte]`/`Reader[Char]` type.)`

## 8. Timeouts

- **`IO` has no timeout.** No `IO` function accepts a timeout; output "exit[s]"
  on failure, input blocks on the server reply
  (https://www.erlang.org/doc/apps/stdlib/io.html).
- **File I/O has no timeout** (`file:read/2` has no timeout argument,
  file.html#read/2).
- **Sockets have timeouts on the pull side.** `gen_tcp:recv(Socket, Length, Timeout)`
  with `Timeout :: timeout()` (ms or `infinity`, default `infinity`) returns
  `{error, timeout}`; `accept/2` and `connect/4` likewise accept a timeout and
  return `{error, timeout}` (gen_tcp.html#recv/3, #accept/2, #connect/4).
- **Send timeout is a socket option, not an argument.** "There is no `send/2`
  call with a time-out option; use socket option `send_timeout` if time-outs are
  desired"; a timing-out send returns `{error, timeout}` and, with the `socket`
  backend, `{error, {timeout, RestData}}` (gen_tcp.html#send/2).
- **Cancellation is process-level.** There is no cancellation token; you stop a
  blocking read by killing/spawning the process, or by using `receive ... after`
  to time out an active-mode receive. `Stream.interval/1` and `Stream.timer/1`
  are explicitly *blocking*: "This operation will block the caller by the given
  interval" / "will block the caller by the given time"
  (https://hexdocs.pm/elixir/Stream.html#interval/1, #timer/1).
- **Streaming pipelines express backpressure rather than timeouts** —
  `gen_stage` is "Producer and consumer actors with back-pressure"
  (https://hex.pm/packages/gen_stage).

## 9. End-of-stream and error signalling

The BEAM has a **three-way reply shape** for reads, defined by the I/O Protocol:
`Data | eof | {error, Error}` (https://www.erlang.org/doc/apps/stdlib/io_protocol.html#input-requests).

- **EOF is the bare atom `:eof` (Erlang `eof`).** "`eof` is returned when input
  end is reached and no more data is available to the client process"
  (io_protocol.html#input-requests). `IO` models it in its type as
  `nodata() :: {:error, term} | :eof` (io.ex:128).
- **Short read ≠ error, short read ≠ eof.** `file:read/2` returns `eof` "if
  `Number>0` and end of file was reached **before anything at all could be
  read**", whereas a partial-but-nonempty read is `{ok, Data}` with a shorter
  binary (file.erl:1568–1570). Only `{error, Reason}` is an error. So the three
  cases are: `{ok, Data}` (some data, maybe fewer bytes than asked),
  `eof` (zero data, clean end), `{error, reason}` (failure).
- **Zero-request edge case.** `IO.read(device, :eof)` "iterated until `:eof`. If
  the device is already at the end, it returns `:eof` itself"
  (IO.html#read/2). `IO.binread/2`'s `:eof` loop returns `:eof` when the
  accumulator is empty, else the accumulated data (io.ex `binread_eof/2`).
- **Errors are distinguishable from EOF by shape.** `{:error, :estale}` (NFS) or
  `{error, closed}`/`{error, timeout}` vs the atom `eof`
  (IO.html#read/2; gen_tcp.html#recv/3).
- **Mid-enumeration errors become exceptions.** When `IO.stream/2` is enumerated,
  an `{:error, reason}` from `read/2` raises `IO.StreamError` rather than
  emitting an error element (io.ex `each_stream`); EOF instead halts the stream
  via `{:halt, device}`.
- **`read_line` normalizes CRLF.** `file:read_line/1` returns the line "including
  the LF, but excluding any CR immediately followed by an LF"; a final line
  without LF is returned as-is (file.erl:1757, :1765).

## 10. Interesting design decisions

1. **The I/O device is a process, and I/O is a message protocol.**
   `{io_request, From, ReplyAs, Request}` / `{io_reply, ReplyAs, Reply}`, with
   `ReplyAs` opaque so a client can have many outstanding requests
   (io_protocol.html#protocol-basics). This is what lets any client talk to any
   device, and lets a device be swapped without touching the client.
2. **Passive vs active modes as one socket's option.** The same socket can be
   pulled (`recv`) or pushed (`{tcp, ...}` messages), and `{active, N}` bounds the
   mailbox, turning "flow control" into a socket option
   (gen_tcp.html#active-mode-socket-messages). It is a genuinely different answer
   to backpressure than a `poll`/`readiness` abstraction.
3. **`iodata` as a first-class write format.** Nested lists + binaries that can
   be written without flattening; "on Unix hosts, scatter output... is used when
   possible. In this way `write(FD, [Bin1, Bin2 | Bin3])` writes the contents of
   the binaries without copying the data at all" (file.html#performance;
   IO.html#module-io-data).
4. **A `get_until` server-side continuation.** The server holds `RestChars` and
   calls a user function returning `{done, Result, RestChars}` / `{more, Continuation}`,
   so `get_line`/`get_chars`/`fread` are all special cases of one request
   (io_protocol.html#input-requests). This is a clean "parser as a fold over a
   stream" seam.
5. **`raw` mode as an opt-out of the process abstraction.** Performance vs
   uniformity is an explicit, documented trade-off rather than hidden
   (File.html#module-processes-and-raw-files; file.html#performance).
6. **Bidirectional streams via two protocols.** `IO.Stream` implements
   `Enumerable` (read) *and* `Collectable` (write); the `raw` boolean selects
   `binread`/`binwrite` vs `read`/`write` internally (io/stream.ex). One struct,
   both directions.
7. **Length-driven buffering options.** `read_ahead` for input and
   `delayed_write` for output are size+delay thresholds on the handle, not
   wrapper classes (file.html#open/2).
8. **`Stream.resource/3` as the canonical open/use/close stream constructor** —
   `start_fun`, `next_fun`, `after_fun` with `after_fun` guaranteed "both in cases
   of success and failure" (Stream.html#resource/3). This is the BEAM analogue of
   RAII without destructors.
9. **Documented danger of the deprecated `:all`.** `IO.read(device, :all)` warns
   and is scheduled for removal in v2.0, replaced by `:eof` (io.ex `read` clause).

## 11. Decisions NOT to copy

- **In-band atom `:eof` as a sentinel.** Mixing a control atom into the data type
  forces every caller to tag-check and makes `:eof` un-nameable as data.
  MojoAkku should use an explicit enum/`Result` (e.g. `ReadResult.Eof`) instead.
  `(Assessment: derived from nodata() = {:error, term} | :eof, io.ex:128.)`
- **Exceptions as the I/O success-path error channel** (`io` "exit[s]", and
  `IO.binwrite` re-raising via `:erlang.error(reason)`) — inconsistent with the
  tuple style of `file`, and costly/unclear. Use `raises` deliberately, not as a
  side channel.
- **A process per file handle by default.** The abstraction cost is real and the
  docs themselves push `raw` for performance
  (File.html#module-processes-and-raw-files). Mojo has no per-process GC or
  scheduler, so copying this shape would be pure overhead.
- **An unbounded active mode (`{active, true}`).** Messages land in the owner's
  mailbox with no bound; the fix (`{active, N}`) is an extra concept. A Mojo
  design should carry the bound in the type/state from the start.
  `(Assessment: derived from gen_tcp option() + active-mode messages.)`
- **Two overlapping, differently-shaped APIs on one VM** (`IO` text functions vs
  `:file` byte functions vs `io` server requests, with `IO` having no bang
  variants but `File` having them). Pick one error and one naming model.
- **Global mutable current working directory** (`File.cd/1`: "set for the BEAM
  globally. This can lead to race conditions if multiple processes are changing
  the current working directory concurrently",
  https://hexdocs.pm/elixir/File.html#cd/1). Never copy a global CWD into a
  library.
- **The full I/O Protocol surface** (`getopts`/`setopts`, `{requests, ...}`,
  `get_geometry`, `expand_fun`, `echo`) is too large for a first MojoAkku
  release; the docs themselves say "It can certainly be argued that the current
  protocol is too complex" (io_protocol.html#the-erlang-i-o-protocol).
- **Unicode correctness as a caller responsibility.** The `IO.read`/`IO.binread`
  footgun ("do not use this function on IO devices in Unicode mode as it will
  return the wrong result", IO.html#binread/2) should be impossible by
  construction in a typed API.

## 12. Ideas fitting Mojo

- **A `Reader`/`Writer` trait pair with an explicit read result.** Shape reads as
  `read(mut self, buf: Span[UInt8]) -> Result[Int, ReadError]` plus a distinct
  `Eof` signal, replacing the `Data | :eof | {:error, _}` union with a Mojo enum.
  The BEAM already separates `eof` from `{error, _}`; Mojo can make that
  type-level (Q9).
- **`raises` as the deliberate error channel.** Give each fallible operation a
  typed `raises IoError` alongside a non-raising variant that returns a
  `Result` — mirroring the Elixir `File` dual API (tuple vs bang), but with one
  consistent model instead of `IO`'s exception-only path
  (File.html#module-api; Q4).
- **Borrowed input, owned output.** Take `borrowed`/`Span[UInt8]` for the buffer
  to fill (no allocation, no GC interaction) and return owned `List[UInt8]` only
  where a fresh buffer is genuinely needed. This is the Mojo analogue of `iodata`
  write-without-copy (Q5).
- **Comptime byte-vs-text specialization instead of runtime mode flags.**
  Make `read_bytes`/`read_text` separate `comptime`-parameterized entry points
  (or a `comptime unit: Unit` parameter) so the caller cannot pick the wrong one
  the way `IO.read`/`IO.binread` allows (Q7).
- **Passive/active as an explicit state with a bounded read-ahead, not a
  mailbox.** Model the useful half of `{active, N}` as a `ReadAhead[n]` value
  type / comptime buffer bound inside the reader, giving the backpressure
  property without the message-passing machinery (Q6).
- **`Stream.resource`-style open/use/close as a value with an `after` hook.**
  A `Stream` value type carrying `start`/`next`/`finish` with the finish step
  guaranteed on both success and failure maps well onto Mojo ownership (RAII-like
  via `var`/lifecycle), giving the `Stream.resource/3` guarantee (Q10 item 8).
- **Length-driven buffering options as compile-time/typed parameters.**
  `read_ahead`/`delayed_write` show size+delay thresholds are a good buffering
  API; Mojo can carry them as typed config fields on the stream handle.
- **Explicit timeout parameter on every blocking operation.** `gen_tcp:recv/3`
  shows timeouts belong on the call (not only in options); adopt
  `read(..., timeout: Duration)` uniformly, unlike `IO` which has none (Q8).

## Sources

- Elixir `IO` docs (v1.20.4): https://hexdocs.pm/elixir/IO.html
- Elixir `IO` source (v1.20.4):
  https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/io.ex
  (line anchors via hexdocs: device L127, nodata L128, chardata L129, read L177,
  binread L234, write L284, binwrite L306, stream L667, binstream L708)
- Elixir `IO.Stream` docs: https://hexdocs.pm/elixir/IO.Stream.html
- Elixir `IO.Stream` source (incl. `IO.StreamError`, `Collectable`, `Enumerable`):
  https://github.com/elixir-lang/elixir/blob/v1.20.4/lib/elixir/lib/io/stream.ex
- Elixir `Stream` docs: https://hexdocs.pm/elixir/Stream.html
- Elixir `File` docs: https://hexdocs.pm/elixir/File.html
- Elixir `File.Stream` docs: https://hexdocs.pm/elixir/File.Stream.html
- Elixir `StringIO` docs: https://hexdocs.pm/elixir/StringIO.html
- Elixir `Port` docs: https://hexdocs.pm/elixir/Port.html
- Erlang/OTP `io` docs (OTP 29.1.1, stdlib 8.1):
  https://www.erlang.org/doc/apps/stdlib/io.html
- The Erlang I/O Protocol (OTP 29.1.1):
  https://www.erlang.org/doc/apps/stdlib/io_protocol.html
- Erlang/OTP `file` docs (kernel 11.0.4):
  https://www.erlang.org/doc/apps/kernel/file.html
- Erlang/OTP `file` source: `lib/kernel/src/file.erl` (OTP-29.1.1) —
  https://github.com/erlang/otp/blob/OTP-29.1.1/lib/kernel/src/file.erl
- Erlang/OTP `gen_tcp` docs: https://www.erlang.org/doc/apps/kernel/gen_tcp.html
- Erlang/OTP `inet` docs: https://www.erlang.org/doc/apps/kernel/inet.html
- `gen_stage`: https://hex.pm/packages/gen_stage
- `flow`: https://hex.pm/packages/flow
- `broadway`: https://hex.pm/packages/broadway
