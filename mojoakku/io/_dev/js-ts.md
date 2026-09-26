# io research: JS/TS

## 1. Standard library support

JS/TS has **three competing stream surfaces** rather than one module:

- **Node.js `node:stream`** — "an abstract interface for working with streaming
  data in Node.js … Streams can be readable, writable, or both. All streams are
  instances of `EventEmitter`." Stability: 2 (Stable). Source:
  <https://nodejs.org/api/stream.html> (section "Stream").
- **WHATWG Streams Standard** — the web-platform standard: "readable streams,
  writable streams, and transform streams". Implemented in Node as
  `node:stream/web`; "No longer experimental" since v21.0.0, Stability 2.
  Sources: <https://streams.spec.whatwg.org/>,
  <https://nodejs.org/api/webstreams.html>.
- **`Uint8Array`/`Buffer`** as the byte container underneath both. `Buffer` "is
  a subclass of JavaScript's `Uint8Array`", Stability 2. Sources:
  <https://nodejs.org/api/buffer.html>.

Node's four fundamental stream types (Source: <https://nodejs.org/api/stream.html>):

- `stream.Writable` — "streams to which data can be written".
- `stream.Readable` — "streams from which data can be read".
- `stream.Duplex` — "streams that are both `Readable` and `Writable`".
- `stream.Transform` — "`Duplex` streams that can modify or transform the data
  as it is written and read".

Utilities in the same module: `stream.pipeline()`, `stream.finished()`,
`stream.compose()`, `stream.Readable.from(iterable)`,
`stream.addAbortSignal(signal, stream)`, the `stream/promises` API (Promises
instead of callbacks), and `stream.getDefaultHighWaterMark(objectMode)`.
Source: <https://nodejs.org/api/stream.html>.

The WHATWG side has `ReadableStream`, `WritableStream`, `TransformStream`,
`ByteLengthQueuingStrategy`/`CountQueuingStrategy`, `TextEncoderStream` /
`TextDecoderStream`, `CompressionStream`/`DecompressionStream`, the
`streamConsumers.*` helpers and `ReadableStream.from(iterable)`. Sources:
<https://streams.spec.whatwg.org/>, <https://nodejs.org/api/webstreams.html>.

Deno's standard library adds a **small `Reader`/`Writer`/`Closer`/`Seeker`
interface set** in `@std/io` (JSR, published by `denoland/std`, version 0.225.3,
"UNSTABLE"). Source: <https://jsr.io/@std/io/doc>.

There is **no built-in timeout** anywhere in the stream surface; timeouts are
borrowed from `AbortSignal`. (Assessment: derived from the three API references
above, none of which list a timeout parameter.)

## 2. Relevant community libraries

- **readable-stream** — "Node.js core streams for userland", "a mirror of the
  streams implementations in Node.js 18.19.0", maintained by the Node.js Streams
  Working Group (Mathias Buus, Matteo Collina, Robert Nagy, Vincent Weevers),
  MIT, 4.7.0, ~411M weekly downloads. It exists so a library gets a stable
  streams base independent of the host Node version. Sources:
  <https://www.npmjs.com/package/readable-stream>.
- **streamx** — "An iteration of the Node.js core streams with a series of
  improvements", author Mathias Buus (mafintosh), MIT, 2.28.1, weekly downloads
  ~54M. Improvements claimed: proper `_open`/`_destroy` lifecycle, `pipe()`
  error handling, "All streams are both binary and object mode streams" via a
  `map`/`byteLength` function pair, and `AbortSignal` support on every stream.
  Source: <https://www.npmjs.com/package/streamx>.
- **bl** (BufferList) — "A Node.js Buffer list collector, reader and streamer
  thingy", authors Rod Vagg, Matteo Collina, Jarett Cruger, MIT, 7.0.12, weekly
  downloads ~94M. It is a `Buffer`-array accumulator with `Buffer`'s read API
  and a `Duplex` variant; since v7 "ESM-only", "Zero runtime dependencies".
  Source: <https://www.npmjs.com/package/bl>.
- **TypeScript typings**: `@types/readable-stream` ("This package has
  TypeScript declarations provided by the separate @types/readable-stream
  package"); Node's own types ship via `@types/node`. Sources:
  <https://www.npmjs.com/package/readable-stream>,
  <https://nodejs.org/api/stream.html>.
- **`@std/io`** (Deno std, MIT, `github.com/denoland/std`) — the only surveyed
  library that is *interface-first* rather than class-first (`Reader`,
  `ReaderSync`, `Writer`, `WriterSync`, `Closer`, `Seeker`) plus the helpers
  `readAll`, `writeAll`, `copy`, `iterateReader`, `toReadableStream`,
  `toWritableStream`, and a `Buffer` class. Source: <https://jsr.io/@std/io/doc>.

The pattern in this ecosystem: Node core streams are the de-facto contract,
`readable-stream`/`streamx` patch their lifecycle and error-handling warts, `bl`
is the practical accumulate-and-reparse buffer, and WHATWG streams + `@std/io`
are the two modern interface-first alternatives. (Assessment: derived from the
four library pages and the Node docs.)

## 3. Exposed APIs

### Node legacy streams (Source: <https://nodejs.org/api/stream.html>)

`Readable`:
`readable.read([size])`, `readable.push(chunk[, encoding])`,
`readable.pause()`, `readable.resume()`, `readable.isPaused()`,
`readable.pipe(destination[, options])`, `readable.unpipe([destination])`,
`readable.unshift(chunk[, encoding])`, `readable.setEncoding(encoding)`,
`readable.destroy([error])`, `readable.wrap(stream)`, `readable[Symbol.asyncIterator]()`,
`readable.toArray([options])`, `readable.map/filter/forEach/take/drop/reduce`,
plus properties `readable.readable`, `readable.readableEnded`,
`readable.readableFlowing` (`null`/`false`/`true`), `readable.readableLength`,
`readable.readableHighWaterMark`, `readable.readableObjectMode`,
`readable.errored`, `readable.destroyed`.

Events: `'data'`, `'readable'`, `'end'`, `'error'`, `'close'`, `'pause'`,
`'resume'`. For implementation: `new stream.Readable([options])`,
`readable._read(size)`, `readable.push(chunk[, encoding])`,
`readable._destroy(err, callback)`.

`Writable`:
`writable.write(chunk[, encoding][, callback])`, `writable.end([chunk[, encoding]][, callback])`,
`writable.cork()`, `writable.uncork()`, `writable.destroy([error])`,
`writable.setDefaultEncoding(encoding)`, plus properties `writable.writable`,
`writable.writableEnded`, `writable.writableFinished`,
`writable.writableHighWaterMark`, `writable.writableLength`,
`writable.writableNeedDrain`, `writable.errored`, `writable.closed`,
`writable.writableAborted`.

Events: `'drain'`, `'finish'`, `'error'`, `'close'`, `'pipe'`, `'unpipe'`.
For implementation: `writable._write(chunk, encoding, callback)`,
`writable._writev(chunks, callback)`, `writable._final(callback)`,
`writable._destroy(err, callback)`.

Module functions:
`stream.pipeline(source[, ...transforms], destination[, options])` (async
variants in `stream/promises`; options include `signal: AbortSignal` and
`end: boolean` default `true`), `stream.finished(stream[, options])`
(options `error`, `readable`, `writable`, `signal`, `cleanup`),
`stream.compose(...streams)`,
`stream.isReadable/isWritable/isDestroyed/isErrored(stream)`,
`stream.Readable.from(iterable[, options])`,
`stream.Readable.fromWeb(readableStream)`, `stream.Readable.toWeb(streamReadable)`,
`stream.Writable.fromWeb`/`toWeb`, `stream.Duplex.fromWeb`/`toWeb`,
`stream.addAbortSignal(signal, stream)`,
`stream.getDefaultHighWaterMark(objectMode)`,
`stream.setDefaultHighWaterMark(objectMode, value)`,
`stream.duplexPair([options])`.

### WHATWG web streams (Source: <https://nodejs.org/api/webstreams.html>)

- `new ReadableStream([underlyingSource[, strategy]])` with `start`, `pull`,
  `cancel`, `type: 'bytes'`, `autoAllocateChunkSize`; strategy
  `{ highWaterMark, size }`.
- `readableStream.locked`, `cancel([reason])`, `getReader([{mode:'byob'}])`,
  `pipeThrough(transform[, options])`, `pipeTo(destination[, options])`
  (options `preventAbort`, `preventCancel`, `preventClose`, `signal`), `tee()`,
  `values([options])`, async iteration, `ReadableStream.from(iterable)`.
- `ReadableStreamDefaultReader`: `read()` → promise of `{ value, done }`,
  `cancel([reason])`, `closed`, `releaseLock()`.
- `ReadableStreamBYOBReader`: `read(view[, options])` with
  `options.min` ("the returned promise will only be fulfilled as soon as `min`
  number of elements are available"), `cancel`, `closed`, `releaseLock`.
- `ReadableStreamBYOBRequest`: `view`, `respond(bytesWritten)`,
  `respondWithNewView(view)`.
- `ReadableStreamDefaultController`: `enqueue([chunk])`, `close()`,
  `error([error])`, `desiredSize`.
- `WritableStream` / `WritableStreamDefaultWriter`: `write([chunk])`, `close()`,
  `abort([reason])`, `closed`, `ready`, `desiredSize`, `releaseLock()`.
- `TransformStream([transformer[, writableStrategy[, readableStrategy]]])` with
  `.readable` / `.writable`; `TextEncoderStream()`, `TextDecoderStream([encoding[, options]])`.
- `ByteLengthQueuingStrategy({highWaterMark})`, `CountQueuingStrategy({highWaterMark})`.
- `streamConsumers.arrayBuffer/blob/buffer/bytes/json/text(stream)`.

### Buffer (Source: <https://nodejs.org/api/buffer.html>)

`Buffer.alloc(size[, fill[, encoding]])` (zero-filled),
`Buffer.allocUnsafe(size[, alignment])` (uninitialized),
`Buffer.allocUnsafeSlow`, `Buffer.from(array | arrayBuffer[, byteOffset[, length]] | buffer | string[, encoding])`,
`Buffer.byteLength(string[, encoding])`, `Buffer.isBuffer`, `Buffer.isEncoding`,
`Buffer.concat(list[, totalLength])`, `Buffer.compare`, `Buffer.copyBytesFrom`,
and on the instance `buf.slice`, `buf.subarray`, `buf.copy`, `buf.write`,
`buf.toString([encoding[, start[, end]]])`, `buf.indexOf`, `buf.includes`,
`buf.equals`, the fixed-width `read*`/`write*` (BE/LE) family, `buf.swap16/32/64`,
`buf.toJSON`, `buf.values/keys/entries`.

Encodings: `'utf8'` (default), `'utf16le'`, `'latin1'`, plus binary-to-text
`'base64'`, `'base64url'`, `'hex'`, and legacy `'ascii'`, `'binary'`, `'ucs2'`.

### `@std/io` (Source: <https://jsr.io/@std/io/doc>)

Interfaces `Reader`, `ReaderSync`, `Writer`, `WriterSync`, `Closer`, `Seeker`,
`SeekerSync`; enum `SeekMode`; class `Buffer(ab?: ArrayBufferLike | ArrayLike<number>)`
with `read(p)`, `readSync(p)`, `write(p)`, `writeSync(p)`, `readFrom(r)`,
`readFromSync(r)`, `bytes(options?)`, `capacity()`, `length()`, `empty()`,
`grow(n)`, `truncate(n)`, `reset()`;
functions `readAll`, `readAllSync`, `writeAll`, `writeAllSync`,
`iterateReader`, `iterateReaderSync`, `copy(src, dst, {bufSize?})`,
`readerFromStreamReader(streamReader)`, `toReadableStream(reader, {autoClose, chunkSize, strategy})`,
`toWritableStream(writer, {autoClose})`.

The `Reader` contract is stated precisely — this is the cleanest byte-reader
signature in the JS ecosystem (Source: <https://jsr.io/@std/io/doc>):

```ts
interface Reader {
  read(p: Uint8Array): Promise<number | null>;
}
// "Reads up to p.byteLength bytes into p. It resolves to the number of bytes
//  read (0 < n <= p.byteLength) and rejects if any error encountered. … If some
//  data is available but not p.byteLength bytes, read() conventionally resolves
//  to what is available instead of waiting for more."
```

`Writer` is the mirror image: "Writes `p.byteLength` bytes from `p` … resolves to
the number of bytes written from `p` (`0 <= n <= p.byteLength`) or reject with
the error … `write()` must reject with a non-null error if would resolve to
`n < p.byteLength`. `write()` must not modify the slice data, even temporarily."

## 4. Error representation

Node streams use **events**, not exceptions, as the primary error channel
(Source: <https://nodejs.org/api/stream.html>):

- A `Readable` "`'error'` event may be emitted by a `Readable` implementation at
  any time"; a `Writable` "`'error'` event is emitted if an error occurred while
  writing or piping data".
- Implementation contract: errors "must be propagated through the
  `readable.destroy(err)` method. Throwing an `Error` from within
  `readable._read()` or manually emitting an `'error'` event results in undefined
  behavior." Same for `writable._write()`: propagate "by invoking the callback
  and passing the error as the first argument".
- Post-hoc inspection: `readable.errored` "Returns error if the stream has been
  destroyed with an error"; `writable.errored` likewise.
- Callback-style APIs report via `callback(err, result)`:
  `BufferListStream`'s "callback will be called with an error argument followed
  by a reference to the bl instance" (<https://www.npmjs.com/package/bl>).

Web streams use **promise rejection** instead (Source:
<https://nodejs.org/api/webstreams.html>, <https://streams.spec.whatwg.org/>):

- `reader.closed` is "rejected if the stream errors"; `.read()`'s promise
  rejects "if the stream became errored".
- The spec's internal model: a stream's `[[state]]` is one of `"readable"`,
  `"closed"`, `"errored"`; `[[storedError]]` is "A value indicating how the
  stream failed, to be given as a failure reason or exception when trying to
  operate on an errored stream". `ReadableStreamCancel` on an errored stream
  "return[s] a promise rejected with stream.`[[storedError]]`".
- `WritableStreamDefaultController.error([error])`: "When called, the
  `WritableStream` will be aborted, with currently pending writes canceled."

`@std/io` uses **rejection for the async form and throw for the sync form**:
`read()` "rejects if any error encountered"; `readSync()` "returns … and any
error encountered that caused the write to stop early", with the interface note
"`readSync()` must throw a non-null error if it returns `n < p.byteLength`"
(Source: <https://jsr.io/@std/io/doc>).

Aborts have their own error identity: `stream.addAbortSignal()` — "Calling
`abort` on the `AbortController` … will behave the same way as calling
`.destroy(new AbortError())` on the stream"; `AbortSignal.timeout()` "aborts with
a `TimeoutError` `DOMException` on timeout". Sources:
<https://nodejs.org/api/stream.html>,
<https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal/timeout_static>.

## 5. Ownership semantics

JavaScript is garbage-collected; nobody frees a stream explicitly. As in Python,
ownership means *aliasing and copy-vs-view* (Source:
<https://nodejs.org/api/buffer.html>):

- **`Buffer` is a view or a copy depending on the constructor route.**
  `Buffer.from(arrayBuffer, byteOffset, length)` "creates a view of the
  `ArrayBuffer` without copying", while `Buffer.from(buffer)` copies.
- **`buf.slice()` is a view; `TypedArray#slice()` is a copy.** "While
  `TypedArray.prototype.slice()` creates a copy … `Buffer.prototype.slice()`
  creates a view over the existing `Buffer` without copying. This behavior can be
  surprising, and only exists for legacy compatibility."
- **`Buffer.allocUnsafe()` hands out uninitialized memory.** It "is faster than
  calling `Buffer.alloc()` but the returned `Buffer` instance might contain old
  data that needs to be overwritten" — the docs have a whole section "What makes
  `Buffer.allocUnsafe()` … 'unsafe'?".
- **BYOB moves the buffer in, and detaches it.** The caller supplies the view;
  after a BYOB `read` "the view's underlying `ArrayBuffer` is *detached*,
  invalidating all existing views that may exist on that `ArrayBuffer`. This can
  have disastrous consequences for your application." (Source:
  <https://nodejs.org/api/webstreams.html>.)
- **Writer must not mutate input.** `@std/io`'s `Writer`: "`write()` must not
  modify the slice data, even temporarily" (Source: <https://jsr.io/@std/io/doc>).
- **BufferList shares the original memory when it can.** "The original buffers
  are kept intact and copies are only done as necessary. Any reads that require
  the use of a single original buffer will return a slice of that buffer only
  (which references the same memory as the original buffer)." `shallowSlice()`
  does "No copies … All buffers in the result share memory with the original
  list." (Source: <https://www.npmjs.com/package/bl>.)
- **Blob is immutable and copies its sources.** "…sources are copied into the
  'Blob' and can therefore be safely modified after the 'Blob' is created."
  (Source: <https://nodejs.org/api/buffer.html>.)
- **Stream locking replaces handle ownership.** Instead of an owner, a stream
  has a *lock*: "A given readable or writable stream only has at most one reader
  or writer at a time. We say in this case the stream is locked"; releasing is
  `releaseLock()` (Source: <https://streams.spec.whatwg.org/>).
- **Internal buffer ownership is per-stream and per-side.** "Because `Duplex`
  and `Transform` streams are both `Readable` and `Writable`, each maintains
  *two* separate internal buffers used for reading and writing." (Source:
  <https://nodejs.org/api/stream.html>.)

## 6. Blocking / non-blocking

**Node streams are non-blocking by design.** I/O is event-driven; nothing waits
in the calling thread. The two consumer models are explicit (Source:
<https://nodejs.org/api/stream.html>):

- **Flowing mode**: "data is read from the underlying system automatically and
  provided to an application as quickly as possible using events via the
  `EventEmitter` interface" (`'data'` events).
- **Paused mode**: "the `stream.read()` method must be called explicitly to read
  chunks of data from the stream."
- "All `Readable` streams begin in paused mode"; state is visible as
  `readable.readableFlowing === null | false | true`, where `null` means "no
  mechanism for consuming the stream's data is provided. Therefore, the stream
  will not generate data."
- Warning attached to flowing mode: "If a `Readable` is switched into flowing
  mode and there are no consumers available to handle the data, that data will be
  lost."

**Backpressure** is the core flow-control primitive (Source:
<https://nodejs.org/api/stream.html>):

- `writable.write()` returns "`false` if the stream wishes for the calling code
  to wait for the `'drain'` event to be emitted before continuing to write
  additional data; otherwise `true`."
- "If a call to `stream.write(chunk)` returns `false`, the `'drain'` event will
  be emitted when it is appropriate to resume writing data to the stream."
- Read side: when the internal queue "reaches the threshold specified by
  `highWaterMark`, the stream will temporarily stop reading data from the
  underlying resource until the data currently buffered can be consumed".
- `readable.push(chunk)` "Returns … `true` if additional chunks of data may
  continue to be pushed; `false` otherwise."

**WHATWG backpressure** is a numeric signal, computed rather than returned
(Source: <https://streams.spec.whatwg.org/>, §2.5):

- "The queuing strategy assigns a size to each chunk, and compares the total size
  of all chunks in the queue to a specified number, known as the high water mark.
  The resulting difference, high water mark minus total size, is used to determine
  the desired size to fill the stream's queue."
- "For readable streams, an underlying source can use this desired size as a
  backpressure signal … For writable streams, a producer can behave similarly,
  avoiding writes that would cause the desired size to go negative."
- `WritableStreamDefaultWriter.desiredSize` is documented as "Returns the desired
  size to fill the stream's internal queue. It can be negative, if the queue is
  over-full." `ready` is "a promise that will be fulfilled when the desired size
  … transitions from non-positive to positive, signaling that it is no longer
  applying backpressure."

**async/await** is layered on top rather than being the stream model:
`readable[Symbol.asyncIterator]()` enables `for await (const chunk of stream)`;
`stream/promises` provides promise-returning `pipeline`/`finished`; `@std/io`'s
whole interface set is async (`Promise<number | null>`), with `*Sync` variants
as the parallel synchronous family. Sources:
<https://nodejs.org/api/stream.html>,
<https://jsr.io/@std/io/doc>.

## 7. Byte streams vs text streams

The distinction is **made at the point of encoding, not by separate stream
classes** (Source: <https://nodejs.org/api/stream.html>,
<https://nodejs.org/api/buffer.html>):

- Chunks are `Buffer`/`Uint8Array` by default: "By default, the data is returned
  as a `Buffer` object unless an encoding has been specified using the
  `readable.setEncoding()` method or the stream is operating in object mode."
- `readable.setEncoding(encoding)` switches the readable side to emit `string`s.
  With it comes a documented unit change: "Typically, the size of the current
  buffer is measured against the `highWaterMark` in *bytes*. However, after
  `setEncoding()` is called, the comparison function will begin to measure the
  buffer's size in *characters*."
- **Object mode** is the third chunk kind: "All streams created by Node.js APIs
  operate exclusively on strings, `Buffer`, `TypedArray` and `DataView` objects.
  … It is possible, however, for stream implementations to work with other types
  of JavaScript values (with the exception of `null` …). Such streams are
  considered to operate in 'object mode'."

WHATWG makes the byte case a *typed stream variant* instead (Source:
<https://streams.spec.whatwg.org/>):

- A readable byte stream is a `ReadableStream` created with
  `underlyingSource.type = "bytes"`; only such a stream can vend a **BYOB
  reader**.
- "BYOB … is short for 'bring your own buffer'. This is a pattern that allows for
  more efficient reading of byte-oriented data that avoids extraneous copying."
  (Source: <https://nodejs.org/api/webstreams.html>.)
- Text is a *transform*: `TextEncoderStream` / `TextDecoderStream`; Node's
  `Blob.textStream()` "is equivalent to piping `blob.stream()` through a
  `TextDecoderStream` set up with UTF-8" (Source:
  <https://nodejs.org/api/buffer.html>).

**Buffering is layered by decorator**, not by class: the raw stream is
`fs.createReadStream`/`net.Socket`, then `readable.setEncoding()` or a
`Transform`, then pipe/pipeline. `highWaterMark` is set per stream instance.
(Assessment: derived from the `highWaterMark` and `setEncoding` sections at
<https://nodejs.org/api/stream.html>.)

**Partial reads** have three different reporting shapes (all sourced):

- Node `readable.read(size)`: "If `size` bytes are not available to be read,
  `null` will be returned *unless* the stream has ended, in which case all of the
  data remaining in the internal buffer will be returned." "If the `size`
  argument is not specified, all of the data contained in the internal buffer
  will be returned." Source: <https://nodejs.org/api/stream.html>.
- `'readable'` "is emitted when there is data available to be read from the
  stream, up to the configured high water mark". Source:
  <https://nodejs.org/api/stream.html>.
- `@std/io` `Reader.read(p)`: "If some data is available but not `p.byteLength`
  bytes, `read()` conventionally resolves to what is available instead of waiting
  for more." Source: <https://jsr.io/@std/io/doc>.
- WHATWG default reader: `{ value, done }`; BYOB reader with `min`:
  "If the stream becomes closed, then the promise is fulfilled with the remaining
  elements in the stream, which might be fewer than the initially requested
  amount." Sources: <https://nodejs.org/api/webstreams.html>,
  <https://streams.spec.whatwg.org/>.

## 8. Timeouts

There is **no timeout parameter on any stream read/write API** in JS/TS. Timeout
and cancellation are expressed through `AbortSignal` (Sources:
<https://nodejs.org/api/stream.html>, <https://nodejs.org/api/webstreams.html>):

- `stream.addAbortSignal(signal, stream)` — "Attaches an AbortSignal to a
  readable or writable stream. This lets code control stream destruction using an
  `AbortController`." Aborting behaves "the same way as calling
  `.destroy(new AbortError())` on the stream, and `controller.error(new
  AbortError())` for webstreams."
- `stream.pipeline(..., { signal })` and `stream.finished(stream, { signal })`
  accept a signal; "When the signal is aborted, `destroy` will be called on the
  underlying pipeline, with an `AbortError`."
- WHATWG `pipeTo`/`pipeThrough` accept `{ signal }`: "Allows the transfer of data
  to be canceled using an `AbortController`."
- `streamx` makes this the headline feature: "all streams support a `signal`
  option that accepts a `AbortSignal` to as an alternative means to `.destroy`
  streams" (Source: <https://www.npmjs.com/package/streamx>).
- **Timeout is a signal factory**: `AbortSignal.timeout(time)` "returns an
  `AbortSignal` that will automatically abort after a specified time. The signal
  aborts with a `TimeoutError` `DOMException` on timeout." (Source:
  <https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal/timeout_static>.)

Caveat documented on `addAbortSignal`: "Using `stream.addAbortSignal()` to
destroy long-lived stream resources is documentation-only deprecated" — signals
are for bounded operations, not for owning a socket's lifetime. Source:
<https://nodejs.org/api/stream.html>.

Cancellation without abort: `readableStream.cancel([reason])`,
`writer.abort([reason])`, `reader.cancel([reason])` in WHATWG; `readable.destroy([error])`
in Node. Sources: <https://nodejs.org/api/webstreams.html>,
<https://nodejs.org/api/stream.html>.

## 9. End-of-stream and error signalling

EOF is **a value or an event**, an error is **an event or a rejection**, and
there is no "would block" state at all (JS/TS never blocks the caller):

| surface | EOF signal | short read | error |
| --- | --- | --- | --- |
| Node `Readable` | `'end'` event | `read(size)` → `null` "if `size` bytes are not available" | `'error'` event; `readable.errored` |
| Node implementation | `readable.push(null)` | — | `readable.destroy(err)` |
| WHATWG default reader | `{ value: undefined, done: true }` | `{ value, done: false }` with whatever chunk is ready | promise rejects with `[[storedError]]` |
| WHATWG BYOB reader | `{ value: newView, done: true }` "If the stream becomes closed" | `done: true` may carry "fewer than the initially requested amount" | promise rejects "If the stream becomes errored" |
| `@std/io` `Reader` | `null` | `n < p.byteLength` is normal, `read()` "resolves to what is available" | promise rejects |
| `bl` `BufferListStream` | end of the piped stream | — | callback `(err, bl)` |

Sources: <https://nodejs.org/api/stream.html>,
<https://nodejs.org/api/webstreams.html>,
<https://streams.spec.whatwg.org/>, <https://jsr.io/@std/io/doc>,
<https://www.npmjs.com/package/bl>.

Two sharp edges worth recording:

- **A short read is never EOF by itself.** `readable.read()` docs: "When reading
  a large file, `.read()` might return `null` temporarily, indicating that it has
  consumed all buffered content but there may be more data yet to be buffered."
  Node also says: "Less than size bytes being returned does not imply that EOF is
  imminent." Source: <https://nodejs.org/api/stream.html>.
- **Reading after end is silently `null`.** "Calling `stream.read([size])` after
  the `'end'` event has been emitted will return `null`. No runtime error will be
  raised." Source: <https://nodejs.org/api/stream.html>.
- **`'end'` requires full consumption.** "The `'end'` event **will not be
  emitted** unless the data is completely consumed." Source:
  <https://nodejs.org/api/stream.html>.
- **`push('')` is a footgun.** "Use of `readable.push('')` is not recommended.
  Because it *is* a call to `readable.push()`, the call will end the reading
  process. However, because the argument is an empty string, no data is added to
  the readable buffer so there is nothing for a user to consume." Source:
  <https://nodejs.org/api/stream.html>.

`@std/io` is the only surveyed surface that spells EOF out as a dedicated value
in the async type: `read(p): Promise<number | null>` — "If the buffer has no data
to return, resolves to EOF (`null`)." Sources: <https://jsr.io/@std/io/doc>.

## 10. Interesting design decisions

- **Two independent consumer styles on one object.** Node keeps flowing
  (`'data'`) *and* paused (`read()`) on the same `Readable`; the trade-off is a
  documented data-loss warning for flowing mode. Source:
  <https://nodejs.org/api/stream.html>.
- **Backpressure as a boolean from `write()` + a `'drain'` event**, rather than
  a numeric `desiredSize` + `ready` promise. The legacy design is simpler to call
  and easier to get wrong; the web design is symmetric between read and write.
  Sources: <https://nodejs.org/api/stream.html>,
  <https://streams.spec.whatwg.org/>.
- **`highWaterMark` as a threshold, not a limit**, is stated up front: "It does
  not enforce a strict memory limitation in general." Default is platform-
  dependent: "For byte streams, it defaults to `65536` (64 KiB) on non-Windows
  platforms and `16384` (16 KiB) on Windows", `16` for object mode. Source:
  <https://nodejs.org/api/stream.html>.
- **`{ value, done }` as a uniform read result.** One shape covers data,
  EOF and (by rejection) error. Sources:
  <https://streams.spec.whatwg.org/>,
  <https://nodejs.org/api/webstreams.html>.
- **BYOB with `min`** turns "give me a buffer and fill it" into an exact-count
  promise on the consumer side while keeping zero-copy on the producer side.
  Sources: <https://nodejs.org/api/webstreams.html>,
  <https://streams.spec.whatwg.org/>.
- **Locking as an explicit, observable state.** `locked` + `releaseLock()`
  prevent interleaved consumers without a mutex API. Source:
  <https://streams.spec.whatwg.org/>.
- **`setEncoding()` moving the buffer accounting from bytes to characters** is a
  documented inconsistency (its own section, "`highWaterMark` discrepancy after
  calling `readable.setEncoding()`"). Source:
  <https://nodejs.org/api/stream.html>.
- **`@std/io`'s tiny, orthogonal interface set** (`Reader`, `ReaderSync`,
  `Writer`, `WriterSync`, `Closer`, `Seeker`) with free functions
  (`readAll`, `writeAll`, `copy`, `iterateReader`) as adapters. Source:
  <https://jsr.io/@std/io/doc>.
- **`streamx` merging binary and object mode** by taking `map`/`byteLength`
  functions instead of a `objectMode` flag. Source:
  <https://www.npmjs.com/package/streamx>.
- **`bl` re-exposing `Buffer`'s whole read API across chunk boundaries** —
  `readUInt16BE(10)` transparently spanning the internal list. Source:
  <https://www.npmjs.com/package/bl>.
- **AbortSignal as the single cancellation/timeout currency** across legacy
  streams, web streams, fetch and files. Sources:
  <https://nodejs.org/api/stream.html>,
  <https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal/timeout_static>.

## 11. Decisions NOT to copy

- **Events as the error channel** (`'error'` emission, callback conventions,
  "manual emitting … results in undefined behavior"). A typed `raises` path is
  strictly easier to audit. Source: <https://nodejs.org/api/stream.html>.
- **Three parallel stream APIs** (legacy `node:stream`, `node:stream/web`,
  `@std/io` interfaces) with conversion shims (`fromWeb`/`toWeb`). One model per
  concept. Sources: <https://nodejs.org/api/stream.html>,
  <https://nodejs.org/api/webstreams.html>.
- **Two consumer modes on one object with data loss as a documented outcome**
  ("If a `Readable` is switched into flowing mode and there are no consumers
  available to handle the data, that data will be lost"). Force the consumer
  style to be chosen once. Source: <https://nodejs.org/api/stream.html>.
- **`highWaterMark` changing unit after `setEncoding()`** — byte and character
  accounting must not silently swap meaning. Source:
  <https://nodejs.org/api/stream.html>.
- **`Buffer.allocUnsafe()`** (uninitialized memory by default) and
  **`Buffer.prototype.slice()` returning a view while `TypedArray#slice()`
  copies** — two naming/aliasing traps. Source:
  <https://nodejs.org/api/buffer.html>.
- **Detaching the ArrayBuffer after a BYOB read**: "invalidating all existing
  views … can have disastrous consequences". A Mojo buffer should be borrowed for
  the duration and remain valid. Source: <https://nodejs.org/api/webstreams.html>.
- **`read(size)` returning `null` for both "buffer empty right now" and "stream
  ended"** and **`read()` after `'end'` returning `null` without error** — the
  EOF/again ambiguity Python avoids and JS inherits. Source:
  <https://nodejs.org/api/stream.html>.
- **`push('')` ending the stream while adding no data** — a silent state
  transition triggered by an empty chunk. Source: <https://nodejs.org/api/stream.html>.
- **`'end'` only after complete consumption** — an EOF signal that depends on the
  *consumer's* diligence. Source: <https://nodejs.org/api/stream.html>.
- **`stream.addAbortSignal` being "documentation-only deprecated" for long-lived
  resources** while still being the only cancellation route. Source:
  <https://nodejs.org/api/stream.html>.
- **Optional/variadic argument soups** (`Buffer.from` has 4 overloads;
  `write(chunk[, encoding][, callback])`; `pipe(destination[, options])`) vs
  named, single-signature methods. Sources:
  <https://nodejs.org/api/buffer.html>,
  <https://nodejs.org/api/stream.html>.

## 12. Ideas fitting Mojo

- **`@std/io`'s two-method core is the closest match to Mojo's gap.** A `Read`
  trait with one method `read(mut self, buffer: Span[UInt8]) -> Int` (or
  `Result`) and a `Write` trait with `write(mut self, data: Span[UInt8]) -> Int`
  mirrors `io.Reader`/`io.Writer` in Python and `@std/io`'s `Reader`/`Writer` in
  TypeScript, while staying compatible with Mojo's existing `Writer` trait.
  Sources: <https://jsr.io/@std/io/doc>, `mojov1` buch `stdlib/io`.
- **Return a small result struct instead of `null`/`b''`/`None`.** `@std/io`'s
  `Promise<number | null>` (n bytes, or EOF) plus `{ value, done }` from web
  streams both say: make the outcome explicit. In Mojo, a `ReadResult` value
  (`count`, `eof`) returned by value avoids both the exception and the sentinel.
  Sources: <https://jsr.io/@std/io/doc>,
  <https://streams.spec.whatwg.org/>.
- **Caller-provided buffer with a `mut` borrow** — the BYOB idea without the
  detach hazard: `read_into(mut buffer: Span[UInt8])` where ownership checking
  guarantees the buffer outlives and is exclusively used by the call. Sources:
  <https://streams.spec.whatwg.org/>,
  `mojov1` buch `keyword-conventions/imm` (`mut` = mutable reference; the
  `borrowed`/`inout`/`owned` set was replaced by `imm`/`mut`/`out`).
- **Backpressure as a value, not an event.** Translate
  `writable.write() -> Bool` + `'drain'` into a returned `desired_size`/`writable`
  value or an explicit `wait_writable()` that `raises` on abort — and keep the
  WHATWG `desiredSize` sign convention (negative = over-full). Sources:
  <https://streams.spec.whatwg.org/>, <https://nodejs.org/api/stream.html>.
- **A `comptime` high-water-mark / chunk size.** Node's `highWaterMark` is a
  per-instance option with a platform-dependent default (64 KiB Unix / 16 KiB
  Windows); a compile-time constant removes the branch and the platform
  difference. Source: <https://nodejs.org/api/stream.html>.
- **Cancellation as an explicit token type, not a signal property.** Model
  `AbortSignal` as a `CancelToken` value passed to read/write, so cancellation
  is a parameter the borrow checker sees rather than ambient state. Sources:
  <https://nodejs.org/api/stream.html>,
  <https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal/timeout_static>.
- **Layer text as a wrapper, not as an encoding flag on the byte stream** —
  follow `TextDecoderStream` rather than `readable.setEncoding()`, which changed
  the buffer accounting unit. Sources:
  <https://nodejs.org/api/stream.html>,
  <https://nodejs.org/api/buffer.html>.
- **A `Closer` trait with idempotent semantics**, matching `@std/io`'s
  `Closer.close()` ("Closes the resource, 'freeing' the backing file/resource")
  and the explicit "one reader at a time" lock from web streams. Source:
  <https://jsr.io/@std/io/doc>, <https://streams.spec.whatwg.org/>.
- **Small adapters instead of decorating classes.** `readAll`, `writeAll`,
  `copy`, `iterateReader` as free functions over the traits keep the trait
  surface minimal and the convenience layer replaceable. Source:
  <https://jsr.io/@std/io/doc>.
- **Typed errors via `raises`:** distinguish "stream closed/locked", "would
  block/aborted", "short read" and "broken". This merges web streams'
  `[[state]]`/`[[storedError]]` distinction and `@std/io`'s reject-vs-`null`
  split into one typed model. Sources:
  <https://streams.spec.whatwg.org/>, <https://jsr.io/@std/io/doc>,
  `mojov1` buch `appendix/cheat-sheet` ("`def f() raises MyError:`").

## Sources

- Node.js Stream docs: <https://nodejs.org/api/stream.html>
- Node.js Web Streams API: <https://nodejs.org/api/webstreams.html>
- Node.js Buffer: <https://nodejs.org/api/buffer.html>
- WHATWG Streams Standard: <https://streams.spec.whatwg.org/>
- MDN `AbortSignal.timeout()`:
  <https://developer.mozilla.org/en-US/docs/Web/API/AbortSignal/timeout_static>
- MDN `TextDecoder.decode()`:
  <https://developer.mozilla.org/en-US/docs/Web/API/TextDecoder/decode>
- Deno std `@std/io` on JSR: <https://jsr.io/@std/io/doc>
- readable-stream on npm: <https://www.npmjs.com/package/readable-stream>
- streamx on npm: <https://www.npmjs.com/package/streamx>
- bl on npm: <https://www.npmjs.com/package/bl>
- Mojo side (not researched here): `mojov1` buch `stdlib/io`,
  `keyword-conventions/imm`, `appendix/cheat-sheet`
