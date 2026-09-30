# io research: Java

Language group: **managed-JVM**. Reference: **Java SE 25 / JDK 25** (`docs.oracle.com/en/java/javase/25`), current as of this run. Java is the richest stream layering of all selected languages: two parallel hierarchies (bytes vs. characters), a decorator family, checked `IOException`, and three separate execution models (blocking `java.io`, readiness-multiplexing `java.nio`, asynchronous channels).

Conventions in this file: `GUESS:` marks an unsourced statement with the reason; `(Assessment: derived from <sources>)` marks a derived statement.

---

## 1. Standard library support

The core lives in the **`java.base` module**, packages:

- **`java.io`** — "Provides for system input and output through data streams, serialization and the file system." Four abstract superclasses: `InputStream` (since 1.0), `OutputStream` (1.0), `Reader` (1.1), `Writer` (1.1). Source: [java.io package summary](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/package-summary.html), [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [OutputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/OutputStream.html), [Reader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Reader.html), [Writer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Writer.html).
- **`java.nio`** — buffers (`ByteBuffer`, `CharBuffer`) with position/limit/mark state; **`java.nio.channels`** — `ReadableByteChannel`, `WritableByteChannel`, `SocketChannel`, `FileChannel`, `AsynchronousByteChannel`, `AsynchronousFileChannel`, `Selector`; **`java.nio.charset`** — `Charset`, `CharsetDecoder`, `CharsetEncoder`. Sources: [ByteBuffer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/ByteBuffer.html), [ReadableByteChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/ReadableByteChannel.html), [Channels](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Channels.html), [Selector](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Selector.html).
- **`java.lang`** — the interfaces `Readable` (since 1.5), `Appendable` (1.5) and `AutoCloseable`. Sources: [Readable](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Readable.html), [Appendable](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Appendable.html), [AutoCloseable](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/AutoCloseable.html).
- **Other `java.base` packages that contribute stream classes**: `java.util.zip` (`GZIPInputStream`, `InflaterInputStream`, `CheckedInputStream`, …), `java.security` (`DigestInputStream`), `javax.crypto` (`CipherInputStream`) — all listed as direct subclasses of `FilterInputStream`. Source: [FilterInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/FilterInputStream.html).
- **`java.net`** — `Socket`, whose `getInputStream()`/`getOutputStream()` return the `java.io` byte streams; **`java.net.http`** — the modern HTTP client with its own `BodySubscriber`/`Flow` model. Sources: [Socket](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/Socket.html), [IOException subclasses list](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/IOException.html).

The Mojo-facing gap: Mojo 1.x's `io` package has console I/O, files and the write traits (`Writer`/`Writable`) but **no `Reader` trait and no generic stream abstraction** (project README, `akku/io_core/_dev/README.md:7-12`; Mojo side from `mojov1/stdlib/io`). (Assessment: Java demonstrates what a full read side plus layering costs in API surface.)

---

## 2. Relevant community libraries

| Library | Maintainer | Maturity | License | Notes |
|---|---|---|---|---|
| **Okio** | Square | Very high; originated inside OkHttp, "well-exercised"; 3.x is Kotlin Multiplatform, supports Android 4.0.3+ (API 15+) / Java 8+, depends on Kotlin stdlib, "a small library with strong backward-compatibility" | Apache-2.0 | Redesigns `java.io`: `Source`/`Sink` + `BufferedSource`/`BufferedSink`, `Timeout` object. Sources: [square/okio README](https://github.com/square/okio), [okio docs index](https://github.com/square/okio/blob/master/docs/index.md), [Source.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt), [Sink.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Sink.kt), [Timeout.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Timeout.kt) |
| **Apache Commons IO** | Apache Software Foundation | Very high; current release **2.22.0** (published 19 Apr 2026), requires Java 8+ | Apache-2.0 | `IOUtils` static utility class: `read`, `readFully`, `readLines`, `copy`, `copyLarge`, `skip`, `skipFully`, `closeQuietly` (deprecated). Sources: [Commons IO overview](https://commons.apache.org/proper/commons-io/), [IOUtils javadoc](https://commons.apache.org/proper/commons-io/javadocs/api-release/org/apache/commons/io/IOUtils.html) |
| **Guava** (`com.google.common.io`) | Google | Very high | Apache-2.0 | `ByteStreams` (`copy`, `readFully`, `skipFully`, `read`, `limit`, `toByteArray`), `CharStreams`, `Closer`. Sources: [ByteStreams.java](https://raw.githubusercontent.com/google/guava/master/guava/src/com/google/common/io/ByteStreams.java) |

`GUESS:` Netty (`ByteBuf`) and kotlinx-io are further JVM stream/buffer libraries, but they were not fetched and are not cited here; they are out of the io-library scope because they are networking/framework specific.

---

## 3. Exposed APIs

### 3.1 `InputStream` (bytes, read side)
Abstract class, `implements Closeable, AutoCloseable`. All read methods `throws IOException`:
- `public abstract int read()` — next byte as `int` 0–255, or `-1` at EOF. Source: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html).
- `public int read(byte[] b)`, `public int read(byte[] b, int off, int len)` — "up to len bytes"; smaller number possible.
- `public byte[] readAllBytes()` (since 9) — reads to EOF; unbounded.
- `public byte[] readNBytes(int len)` (since 11), `public int readNBytes(byte[] b, int off, int len)` (since 9).
- `public long skip(long n)`, `public void skipNBytes(long n)` (since 12).
- `public int available()`, `public void close()`.
- `public void mark(int readlimit)`, `public void reset()`, `public boolean markSupported()`.
- `public long transferTo(OutputStream out)` (since 9).
- `public static InputStream nullInputStream()` (since 11).

### 3.2 `OutputStream` (bytes, write side)
Abstract, `implements Closeable, Flushable, AutoCloseable`:
- `public abstract void write(int b)` — "the eight low-order bits of the argument b"; high 24 bits ignored.
- `public void write(byte[] b)`, `public void write(byte[] b, int off, int len)`.
- `public void flush()`, `public void close()`.
- `public static OutputStream nullOutputStream()` (since 11).
Source: [OutputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/OutputStream.html).

### 3.3 `Reader` / `Writer` (characters)
`Reader implements Readable, Closeable`; only `read(char[],int,int)` and `close()` are abstract. `protected Object lock` is the synchronization object. Source: [Reader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Reader.html).
- `int read()` → char 0–65535 or `-1`; `read(char[])`; `abstract int read(char[],int,int)`; `int read(CharBuffer target)`.
- `long skip(long n)`, `boolean ready()`, `void close()`, `mark(int)`, `reset()`, `markSupported()`.
- `long transferTo(Writer out)` (since 10).
- Java 25 additions: `List<String> readAllLines()` and `String readAllAsString()` (both since 25).
- Java 24 addition: `static Reader of(CharSequence cs)`; Java 11: `static Reader nullReader()`.

`Writer implements Appendable, Closeable, Flushable`; only `write(char[],int,int)`, `flush()`, `close()` are abstract. Source: [Writer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Writer.html).
- `void write(int c)` (16 low bits used), `write(char[])`, `abstract write(char[],int,int)`, `write(String)`, `write(String,int,int)`.
- `Writer append(CharSequence)`, `append(CharSequence,int,int)`, `append(char)` — return `this`.
- `static Writer nullWriter()`.

### 3.4 The interfaces
- `Closeable extends AutoCloseable`: `void close() throws IOException`; "If the stream is already closed then invoking this method has no effect." Source: [Closeable](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Closeable.html).
- `Readable`: `int read(CharBuffer cb) throws IOException` — returns chars added "possibly zero, or -1 if this source of characters is at its end". Source: [Readable](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Readable.html).
- `Appendable`: three `append` overloads returning `Appendable`, all `throws IOException`. Source: [Appendable](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Appendable.html).

### 3.5 Decorators / filters
- **`FilterInputStream`** (`protected volatile InputStream in`): passes every method to `in`; `read(byte[])` is forced through `read(b,0,b.length)` because "certain subclasses of FilterInputStream depend on the implementation strategy actually used". Sources: [FilterInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/FilterInputStream.html). Parallel classes: `FilterOutputStream`, `FilterReader`, `FilterWriter`.
- **`BufferedInputStream`**: fields `protected volatile byte[] buf`, `int count`, `int pos`, `int markpos`, `int marklimit`; constructors `BufferedInputStream(InputStream in)` and `BufferedInputStream(InputStream in, int size)` (`IllegalArgumentException` if `size <= 0`). Its `read(byte[],int,int)` reads as many as possible until the requested count, `-1`, or `underlying.available() == 0`. `markSupported()` returns `true`. API note: "Once wrapped in a BufferedInputStream, the underlying InputStream should not be used directly nor wrapped with another stream." Source: [BufferedInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedInputStream.html).
- **`BufferedReader`**: adds `readLine()` (terminators `\n`, `\r`, `\r\n`, or EOF; returns `null` at EOF), `lines()` → `Stream<String>`, mark/reset support; the underlying `Reader` "should not be used directly nor wrapped with another reader". Source: [BufferedReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedReader.html).
- **`InputStreamReader`** / **`OutputStreamWriter`** (bridges, §7). Constructors take `Charset`, `CharsetDecoder`/`CharsetEncoder`, or a `String` charset name (`throws UnsupportedEncodingException`). Source: [InputStreamReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStreamReader.html).
- **`DataInputStream implements DataInput`**: `readBoolean`, `readByte`, `readUnsignedByte`, `readShort`, `readUnsignedShort`, `readChar`, `readInt`, `readLong`, `readFloat`, `readDouble`, `readUTF` (modified UTF-8), `readFully(byte[])`, `readFully(byte[],int,int)`, `skipBytes(int)`; `readLine()` deprecated. Typed reads throw `EOFException` if the end is reached mid-value. Source: [DataInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/DataInputStream.html).
- **`PushbackInputStream`**: `unread(int)`, `unread(byte[])`, `unread(byte[],int,int)`; 1-byte default buffer or explicit `size`; `markSupported()` returns `false`, `mark()` does nothing, `reset()` throws. Source: [PushbackInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/PushbackInputStream.html).
- In-memory / piping: `ByteArrayInputStream`/`OutputStream`, `CharArrayReader`/`Writer`, `StringReader`/`Writer`, `PipedInputStream`/`OutputStream`, `PipedReader`/`Writer`, `SequenceInputStream`. Source: [java.io package summary](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/package-summary.html).

### 3.6 Channel/buffer APIs (`java.nio`)
- `int ReadableByteChannel.read(ByteBuffer dst) throws IOException` — returns bytes read "possibly zero, or -1 if the channel has reached end-of-stream". Throws `ClosedChannelException`, `AsynchronousCloseException`, `ClosedByInterruptException`, `NonReadableChannelException`. Source: [ReadableByteChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/ReadableByteChannel.html).
- `ByteBuffer`: `static allocate(int)`, `static allocateDirect(int)`, `static wrap(byte[])`, `get()/put()`, bulk get/put, `flip()`, `clear()`, `compact()`, `rewind()`, `mark()/reset()`, `remaining()`, `order(ByteOrder)` (default `BIG_ENDIAN`), view buffers (`asIntBuffer()` …). Source: [ByteBuffer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/ByteBuffer.html).
- `Channels` factory: `newInputStream(ReadableByteChannel)`, `newOutputStream(WritableByteChannel)`, `newChannel(InputStream)`, `newChannel(OutputStream)`, `newReader(ReadableByteChannel, Charset|CharsetDecoder|String)`, `newWriter(...)`. Source: [Channels](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Channels.html).

---

## 4. Error representation

- **Checked exceptions.** `IOException extends Exception` "signals that an I/O exception of some sort has occurred". Every stream method declares `throws IOException`. Source: [IOException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/IOException.html).
- **Catch-or-Specify Requirement.** "Code that might throw certain exceptions must be enclosed by either … a `try` statement that catches the exception … [or] a method that specifies that it can throw the exception … Code that fails to honor the Catch or Specify Requirement will not compile." `IOException` is checked; `Error` and `RuntimeException` are unchecked. Source: [Java Tutorials — Catch or Specify](https://docs.oracle.com/javase/tutorial/essential/exceptions/catchOrDeclare.html).
- **Exception type tree** (all listed subclasses of `IOException`): `EOFException`, `InterruptedIOException`, `FileNotFoundException`, `SocketException`, `UnknownHostException`, `ClosedChannelException`, `CharacterCodingException`, `UTFDataFormatException`, `UnsupportedEncodingException`, `HttpTimeoutException`, `SocketTimeoutException` (via `InterruptedIOException`), `FileSystemException`, `SSLException`, `AsynchronousCloseException` (via `ClosedChannelException`). Source: [IOException known subclasses](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/IOException.html).
- **`InterruptedIOException`** carries `public int bytesTransferred` — "how many bytes had been transferred … before it was interrupted". Source: [InterruptedIOException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InterruptedIOException.html).
- **`EOFException`** "Signals that an end of file or end of stream has been reached unexpectedly during input… mainly used by data input streams". Source: [EOFException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/EOFException.html).
- **Unchecked wrappers.** `UncheckedIOException extends RuntimeException` wraps an `IOException` for lambda/stream contexts (e.g. `BufferedReader.lines()`). Source: [UncheckedIOException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/UncheckedIOException.html).
- **Unchecked argument/state errors**: `NullPointerException` (null buffer), `IndexOutOfBoundsException` (bad off/len), `IllegalArgumentException` (bad buffer size), `IllegalBlockingModeException extends IllegalStateException` ("blocking-mode-specific operation … upon a channel in the incorrect blocking mode"). Sources: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [IllegalBlockingModeException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/IllegalBlockingModeException.html).
- **`IOError extends Error`** is reserved for serious, usually-unrecoverable I/O failures. Source: [Catch or Specify](https://docs.oracle.com/javase/tutorial/essential/exceptions/catchOrDeclare.html) and the `java.io` package list.
- `GUESS:` no source gives a stable, documented mapping from OS `errno` to specific exception subclasses; the mapping lives in the (unspecified) native implementation.

---

## 5. Ownership semantics

Java has **garbage collection, not ownership**; stream resources are released explicitly. The relevant facts:

- **Who allocates the buffer.** In every `read(byte[] b, …)` the *caller* allocates and owns the destination array; the stream only writes into `b[off..off+len-1]`. The stream's *own* buffer is separate: `BufferedInputStream` allocates `protected volatile byte[] buf` at construction and refills it lazily; `BufferedReader` allocates a character buffer (size configurable). Sources: [InputStream.read(byte[],int,int)](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [BufferedInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedInputStream.html), [BufferedReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedReader.html).
- **Who frees/closes.** `close()` releases OS resources; `Closeable.close()` is idempotent ("already closed … has no effect"). The GC reclaims memory but **not** the OS resource: "A program has to do more than rely on the garbage collector (GC) to reclaim a resource's memory … The program must also release the resource back to the operating system, typically by calling the resource's close method." Source: [Try-with-resources](https://docs.oracle.com/javase/tutorial/essential/exceptions/tryResourceClose.html).
- **Chain semantics.** Closing a wrapper closes the wrapped stream (`FilterInputStream.close()` "simply performs `in.close()`"). Closing a socket's stream "will close the associated socket". Sources: [FilterInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/FilterInputStream.html), [Socket](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/Socket.html).
- **Wrapper ownership disclaimer.** Two API notes warn that once wrapped, the underlying stream "should not be used directly nor wrapped with another stream"; ownership of the read position moves to the outermost wrapper. Sources: [BufferedInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedInputStream.html), [BufferedReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedReader.html).
- **Buffer-view ownership (NIO).** `ByteBuffer.wrap` shares the caller's array ("modifications to the buffer will cause the array to be modified and vice versa"). `slice()`/`duplicate()` share content but have independent position/limit/mark. **Direct buffers may live outside the Java heap** — "their impact upon the memory footprint of an application might not be obvious", and deallocation is GC-driven. Source: [ByteBuffer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/ByteBuffer.html).
- **No finalizer guarantee.** `finalize()` is deprecated; the sanctioned mechanism is try-with-resources. Source: [Try-with-resources](https://docs.oracle.com/javase/tutorial/essential/exceptions/tryResourceClose.html).

`(Assessment: derived from the above)` Java's lifetime discipline is *convention + library*, not *type-enforced*; Mojo's ownership/`Deinitable` can make the same discipline compile-time-checked.

---

## 6. Blocking / non-blocking

Java exposes **three distinct models**:

1. **Blocking `java.io`.** "This method blocks until input data is available, the end of the stream is detected, or an exception is thrown." There is no non-blocking mode and no timeout parameter on `read()`/`write()`. Source: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html).
2. **Readiness multiplexing (`java.nio.Selector`).** A `SelectableChannel` registers with a `Selector`; `select()` blocks, `select(long timeout)` blocks up to a timeout, `selectNow()` does not block. The doc: "Whether or not a selection operation blocks to wait for one or more channels to become ready, and if so for how long, is the only essential difference between the three selection methods." A channel in non-blocking mode's `read` "cannot read any more bytes than are immediately available". Sources: [Selector](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Selector.html), [ReadableByteChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/ReadableByteChannel.html).
3. **Asynchronous completion (`AsynchronousByteChannel`, `AsynchronousFileChannel`, since 1.7).** Two styles: a `CompletionHandler` callback plus an attachment, and a `Future<Integer>` return. "The result passed to the completion handler is the number of bytes read or -1 if no bytes could be read because the channel has reached end-of-stream." Only one read may be outstanding per channel (`ReadPendingException` otherwise); `AsynchronousFileChannel` allows multiple outstanding reads but "the order that the completion handlers are invoked, is not specified". Sources: [AsynchronousByteChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/AsynchronousByteChannel.html), [AsynchronousFileChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/AsynchronousFileChannel.html).

There is **no `async`/`await` language construct**; asynchrony is a library model. Bridging back to blocking has a guard: `Channels.newInputStream(channel)` "will throw an IllegalBlockingModeException if invoked while the underlying channel is in non-blocking mode". Source: [Channels](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Channels.html).

**`available()`** is the only non-blocking hint on plain streams: "an estimate of the number of bytes that can be read (or skipped over) … without blocking, which may be 0". The default implementation returns `0`, and the docs warn: "It is never correct to use the return value of this method to allocate a buffer intended to hold all data in this stream." Source: [InputStream.available](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html).

`(Assessment: derived from the NIO docs)` Java's async model is not "structured concurrency"; it is a channel-level callback/Future contract, which is why most JVM code uses blocking streams on threads or virtual threads instead.

---

## 7. Byte streams vs text streams

- **Two parallel hierarchies, distinguished by class, not by a mode flag.** `InputStream`/`OutputStream` operate on `byte`; `Reader`/`Writer` operate on `char` (16-bit UTF-16 code units). Neither inherits from the other. Sources: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [Reader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Reader.html).
- **Explicit bridges** convert between them: `InputStreamReader` "is a bridge from byte streams to character streams: It reads bytes and decodes them into characters using a specified charset"; `OutputStreamWriter` is the inverse. `InputStreamReader` may read ahead: "more bytes may be read ahead from the underlying stream than are necessary to satisfy the current read operation." Source: [InputStreamReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStreamReader.html).
- **Charset errors are configurable.** `Channels.newReader(ch, charset)` uses a decoder whose default "action for malformed-input and unmappable-character errors is to report them"; the `CharsetDecoder` constructor allows overriding that. Source: [Channels](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Channels.html).
- **Buffering is layered by decorators, not built into the base class.** `BufferedInputStream`/`BufferedOutputStream` for bytes, `BufferedReader`/`BufferedWriter` for text; each has a no-arg (default size) and an explicit-size constructor. The `InputStreamReader` doc recommends `new BufferedReader(new InputStreamReader(in))` "for top efficiency". Sources: [BufferedInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedInputStream.html), [BufferedReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedReader.html), [InputStreamReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStreamReader.html).
- **Partial reads are reported as the return value.** `read(byte[],int,int)`: "An attempt is made to read as many as len bytes, but a smaller number may be read. The number of bytes actually read is returned." `read()` returns `-1` only if no byte is available at end of stream; otherwise "at least one byte is read". `readNBytes(...)` is the all-or-up-to-`len` variant and blocks until `len`, EOF, or error. Sources: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [DataInputStream.readFully](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/DataInputStream.html).
- **`DataInputStream.readFully`** is the "exactly N bytes or fail" contract, throwing `EOFException` on truncation. Source: [DataInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/DataInputStream.html).

`(Assessment: derived from the above)` The byte/text split costs a combinatorial bridge surface: `InputStreamReader`/`OutputStreamWriter`, `Channels.newReader`/`newWriter`, `CharsetDecoder`/`CharsetEncoder`, plus `Reader.of(CharSequence)`.

---

## 8. Timeouts

- **No timeout on `java.io` stream methods.** `read()` has no timeout parameter; blocking is bounded only by (a) closing the stream, (b) interrupting the thread, or (c) a socket-level `SO_TIMEOUT`.
- **Socket-level timeouts (`java.net`).** `Socket.setSoTimeout(int)` / `getSoTimeout()`: "0 returns implies that the option is disabled (i.e., timeout of infinity)"; on expiry a `SocketTimeoutException` ("Signals that a timeout has occurred on a socket read or accept") is thrown. `Socket.connect(SocketAddress, int timeout)` uses the same convention — "A timeout of zero is interpreted as an infinite timeout" — and throws `SocketTimeoutException` if it expires. Sources: [Socket](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/Socket.html), [SocketTimeoutException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/SocketTimeoutException.html).
- **Selector timeout.** `select(long timeout)`: "If positive, block for up to timeout milliseconds …; if zero, block indefinitely; must not be negative." The docs caveat: "This method does not offer real-time guarantees: It schedules the timeout as if by invoking the Object.wait(long) method." Source: [Selector](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Selector.html).
- **Cancellation = thread interruption.** For a channel, an interrupt during a read "closes the underlying channel and caus[es] this method to throw `ClosedByInterruptException` with the interrupt status set"; a concurrent `close()` yields `AsynchronousCloseException`. `InterruptedIOException.bytesTransferred` reports progress up to the interruption. `AsynchronousFileChannel.close()` "causes all outstanding asynchronous operations on the channel to complete with the exception `AsynchronousCloseException`." Sources: [ReadableByteChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/ReadableByteChannel.html), [InterruptedIOException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InterruptedIOException.html), [AsynchronousFileChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/AsynchronousFileChannel.html).
- **A cleaner community model: Okio `Timeout`.** It separates **timeouts** ("the maximum time to wait for a single operation") from **deadlines** ("the maximum time to spend on a job, composed of one or more operations"), offers `Timeout.NONE`, and states the failure contract: "When a task times out, it is left in an unspecified state and should be abandoned." Source: [Timeout.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Timeout.kt).
- `HttpTimeoutException` exists for the `java.net.http` client (listed under `IOException`). Source: [IOException subclasses](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/IOException.html).
- `GUESS:` `AsynchronousChannelGroup` exposes a documented timeout/thread-pool configuration, but its page was not fetched for this run, so no timeout signature is cited here.

---

## 9. End-of-stream and error signalling

Java mixes **sentinel** and **exception** signalling, deliberately, by API layer:

- **Sentinel `-1`** for the low-level read family: `read()` returns "the next byte of data, or -1 if the end of the stream is reached"; `read(byte[])` and `read(byte[],int,int)` return "the total number of bytes read into the buffer, or -1 if there is no more data". `Reader.read(CharBuffer)` returns "possibly zero, or -1". `ReadableByteChannel.read(ByteBuffer)` returns "The number of bytes read, possibly zero, or -1". Sources: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [Reader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Reader.html), [ReadableByteChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/ReadableByteChannel.html).
- **`0` vs `-1` is method-dependent.** `readNBytes(byte[],off,len)` returns "the actual number of bytes read, possibly zero"; "When this stream reaches end of stream, further invocations of this method will return zero." So the same EOF is `-1` for `read(byte[])` but `0` for `readNBytes`. Source: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html).
- **`EOFException`** for structured reads that need a fixed number of bytes: `DataInputStream.readInt()` throws `EOFException` "if this input stream reaches the end before reading four bytes"; `readFully` and `skipNBytes` likewise. The class doc summarises the split precisely: "This exception is mainly used by data input streams to signal end of stream. Note that many other input operations return a special value on end of stream rather than throwing an exception." Sources: [DataInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/DataInputStream.html), [EOFException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/EOFException.html).
- **`IOException`** is a genuine failure, never EOF: it is thrown "if the first byte cannot be read for any reason other than the end of the file, if the input stream has been closed, or if some other I/O error occurs". Source: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html).
- **Silent partial read on error (a documented trap).** The default `InputStream.read(b,off,len)` "simply calls read() repeatedly. … If any subsequent call to read() results in a IOException, the exception is caught and treated as if it were end of file; the bytes read up to that point are stored into b and the number of bytes read before the exception occurred is returned." Source: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html).
- **Post-error state is unspecified.** `readAllBytes`/`readNBytes`: "If an I/O error occurs … it may do so after some, but not all, bytes have been read. Consequently the input stream may not be at end of stream and may be in an inconsistent state. It is strongly recommended that the stream be promptly closed if an I/O error occurs." Source: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html).
- **Line-oriented EOF differs by method**: `BufferedReader.readLine()` returns `null` at EOF; Okio deliberately offers both `readUtf8Line()` returning `null` ("for human-generated data, where a trailing line break is optional") and `readUtf8LineStrict()` throwing `EOFException` ("for machine-generated data where a missing line break implies truncated input"). Sources: [BufferedReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedReader.html), [BufferedSource.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/BufferedSource.kt).

`(Assessment: derived from the above)` Java encodes EOF three different ways in one package (`-1`, `0`, `EOFException`) plus `null` for lines — a consistency cost the reader must learn per method.

---

## 10. Interesting design decisions

1. **Two orthogonal axes of composition.** Axis 1 = byte vs. character (`InputStream` vs. `Reader`); axis 2 = raw vs. decorated (`FilterInputStream` family). The `Filter*` classes give a clean decorator point: "wraps some other input stream, which it uses as its basic source of data, possibly transforming the data along the way". Source: [FilterInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/FilterInputStream.html).
2. **`-1` sentinel in an `int` return** lets one method carry both data (0–255) and control (`-1`), and `Reader.read()` extends it to 0–65535. Source: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [Reader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Reader.html).
3. **Checked `IOException` on every call** makes I/O failure impossible to ignore at compile time — the strongest "errors are part of the contract" stance of the selected languages. Source: [Catch or Specify](https://docs.oracle.com/javase/tutorial/essential/exceptions/catchOrDeclare.html).
4. **`mark`/`reset` for bounded lookahead**, with `markSupported()` as an invariant and `readlimit` bounding re-reading — the mechanism `PushbackInputStream`/`PushbackReader` generalise for lexers. Sources: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [PushbackInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/PushbackInputStream.html).
5. **`available()`** as a non-blocking hint with an intentionally weak contract ("never correct to use … to allocate a buffer"). Source: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html).
6. **Typed framing separated from raw I/O**: `DataInputStream`/`DataOutput` define a machine-independent big-endian encoding, so protocol code never hand-decodes bytes. Source: [DataInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/DataInputStream.html).
7. **Resource management as a language construct**: try-with-resources closes in "the opposite order of their creation" and **suppresses** exceptions from `close()` so the primary exception survives. Source: [Try-with-resources](https://docs.oracle.com/javase/tutorial/essential/exceptions/tryResourceClose.html).
8. **NIO buffers as explicit state machines** (`position`/`limit`/`mark`, `flip`/`clear`/`compact`) enable zero-copy paths (`transferTo`, direct buffers). Source: [ByteBuffer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/ByteBuffer.html).
9. **Two async shapes side by side** (`CompletionHandler` callback and `Future`) let callers choose inversion-of-control or polling on the same channel. Source: [AsynchronousByteChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/AsynchronousByteChannel.html).
10. **Okio's explicit redesign as a critique.** From `Source.kt`: `InputStream` "requires multiple layers when consumed data is heterogeneous: a DataInputStream for primitive values, a BufferedInputStream for buffering, and an InputStreamReader for strings. This library uses BufferedSource for all of the above." It also states: "Source avoids the impossible-to-implement available() method"; "Source omits the unsafe-to-compose mark and reset state"; and notes `read()` "is awkward to implement efficiently and returns one of 257 possible values". Source: [Source.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt).
11. **One-method minimal contract (Okio).** `Source` requires exactly `read(sink: Buffer, byteCount: Long): Long` (returning -1 at exhaustion) plus `timeout()` and `close()`; `Sink` requires `write`, `flush`, `timeout`, `close`. `buffered()` wraps for convenience, `require(n)`/`request(n)` replace `available()`, and `peek()` gives non-consuming lookahead. Sources: [Source.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt), [Sink.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Sink.kt), [BufferedSource.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/BufferedSource.kt).

---

## 11. Decisions NOT to copy

1. **Checked exceptions + `throws IOException` on every method.** It forces `throws` up the whole call graph, pushes people to `UncheckedIOException` wrappers or `catch (IOException e) { throw new RuntimeException(e); }`, and makes lambda/stream composition painful (Guava's own `ByteArrayDataInputStream` wraps every typed read in `catch (IOException e) { throw new IllegalStateException(e); }`). Mojo's `raises`/typed errors are part of the signature without forcing a catch at every frame. Sources: [Catch or Specify](https://docs.oracle.com/javase/tutorial/essential/exceptions/catchOrDeclare.html), [ByteStreams.java](https://raw.githubusercontent.com/google/guava/master/guava/src/com/google/common/io/ByteStreams.java). `(Assessment: derived from the cited API shapes.)`
2. **`-1` as an in-band EOF sentinel in an `int`.** It conflates data and control (Okio: "one of 257 possible values") and makes the return type carry three meanings. Mojo should express EOF in the type (`Optional`/result enum) or reserve `-1` behind an explicit, documented contract. Source: [Source.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt).
3. **`available()`.** The API itself warns it is an estimate, may return 0, and "It is never correct to use the return value … to allocate a buffer". Okio calls it "impossible-to-implement". Do not port it. Sources: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [Source.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt).
4. **`mark`/`reset` as mutable stream state.** It is "unsafe-to-compose" (Okio) and makes a stream's behaviour depend on hidden history. Prefer a explicit non-consuming peek/buffer construct. Source: [Source.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt).
5. **Two parallel hierarchies plus a combinatorial bridge set** (`InputStream`/`Reader` × `InputStreamReader`/`OutputStreamWriter`/`Channels.newReader`/`Channels.newWriter`/`CharsetDecoder`/`CharsetEncoder`). One byte source plus one compile-time decode adapter is smaller. Sources: [InputStreamReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStreamReader.html), [Channels](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Channels.html).
6. **Class inheritance as the extension mechanism.** Every stream is a subclass (Java has no traits/interfaces for behaviour composition in the `io` hierarchy; decorators must extend `Filter*`). Mojo's traits compose without single-inheritance limits. Source: [java.io package summary](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/package-summary.html).
7. **`abstract int read()` / `abstract void write(int b)` single-unit methods that subclasses must implement.** They are inefficient by construction and force the awkward `int`-range convention. Prefer a single buffer-oriented required method. Source: [Source.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt).
8. **The `-1`/`0`/`EOFException`/`null` inconsistency across the read family.** Same condition, four encodings. Pick one. Sources: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [EOFException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/EOFException.html), [BufferedReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedReader.html).
9. **`IOException`-swallowing default loop** in `InputStream.read(b,off,len)`: a mid-stream `IOException` is "caught and treated as if it were end of file", producing a silent partial read. Never copy this; errors must propagate. Source: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html).
10. **GC/finalizer-based resource release.** Not available in Mojo and not desirable; Java's own docs mark GC-reliance a leak risk. Source: [Try-with-resources](https://docs.oracle.com/javase/tutorial/essential/exceptions/tryResourceClose.html).
11. **Thread-interrupt status as the cancellation channel, plus a public mutable `bytesTransferred` field.** Both are "spooky action at a distance" / fragile public state. Sources: [ReadableByteChannel](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/ReadableByteChannel.html), [InterruptedIOException](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InterruptedIOException.html).
12. **`DataInputStream.readUTF` / modified UTF-8.** Java's own serialization encoding (not standard UTF-8) is a legacy footgun; text decoding should be an explicit charset step. Source: [DataInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/DataInputStream.html).
13. **Unbounded convenience reads** (`readAllBytes`, `readAllLines`) that can allocate arbitrary memory; their own docs warn about `OutOfMemoryError` and "unknown origin". Sources: [InputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [Reader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Reader.html).

---

## 12. Ideas fitting Mojo

1. **One minimal required method, buffer-oriented.** Model a `Reader` trait after Okio's `Source`/Go's `io.Reader`: `def read(mut self, buffer: Span[UInt8]) raises IoError -> Int` (bytes read; EOF is a distinct typed outcome, **not** a `0` sentinel — see item 2), with `buffer` as the caller's storage. This directly fills the documented Mojo gap ("no Reader trait", README:7-12), composes with the existing `Writer`/`Writable` write side, and avoids Java's 257-value `read()` and `-1` sentinel. Sources: README:7-12, [Source.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt).
2. **Errors as values, EOF in the type.** Use `raises IoError` (a typed error) for real failures, and make EOF an explicit value (`Optional`/a small result enum) rather than overloading the byte return. Mojo's model — "errors as alternate return values" with no unwinding — matches I/O failure far better than checked exceptions, and stack traces are opt-in. Source: `mojov1/errors/error-model` (Mojo manual — Errors).
3. **Ownership instead of GC + convention.** Make a stream handle a **move-only `Deinitable` struct**: `__deinit__(deinit self)` closes the handle deterministically; Java's `Closeable.close()` idempotence becomes a compile-time "consumed once" guarantee. `with` (Mojo context managers, `__enter__`/`__exit__`) gives the try-with-resources discipline, and `__exit__[ErrType]` can receive the error, so close-on-error is explicit, not suppressed-magic. Sources: `mojov1/memory/ownership-and-lifetimes`, `mojov1/keywords/with`.
4. **The caller owns the read buffer; the library owns only its own buffer.** Take `mut self` for the stream and `Span[UInt8]` for the destination; return the count. Argument exclusivity (Mojo rejects aliasing a `mut` reference) statically prevents the "same buffer as source and sink" bug class. Buffer allocation, where a layer needs one (a `Buffered*` adapter), goes through an `Allocator` parameter, mirroring `BufferedInputStream(in, size)`. Sources: `mojov1/memory/ownership-and-lifetimes`, [BufferedInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedInputStream.html).
5. **Byte vs. text at compile time, not two class trees.** Two traits (`ByteReader`, `TextReader`) plus a `comptime`-specialised decoder adapter (encoding as a parameter) gives Java's `InputStreamReader` semantics with zero virtual dispatch and without the `Channels.newReader`/`CharsetDecoder` bridge zoo. Charset malformed/unmappable handling becomes a compile-time policy value, as Java exposes via `CharsetDecoder`. Sources: [InputStreamReader](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStreamReader.html), `mojov1/functions/parameters-and-generics`.
6. **Layered adapters as generic wrappers over `Some[Reader]`/`Some[Writer]`.** Reproduce `FilterInputStream`/`BufferedInputStream`/`PushbackInputStream`/`DataInputStream` as thin generic structs constrained by traits, monomorphised — Java pays dynamic dispatch and a class per layer. Source: [FilterInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/FilterInputStream.html), `mojov1/keywords/trait`.
7. **`comptime` for buffer size and endianness.** `BufferedInputStream(in, size)` and `ByteBuffer.order(ByteOrder)` become compile-time parameters (size as a value parameter, byte order as an enum parameter) so the adapter is specialised and allocation-free at the call site. Sources: [BufferedInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedInputStream.html), [ByteBuffer](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/ByteBuffer.html), `mojov1/keywords/comptime`.
8. **Truncation as a typed error, not a sentinel.** `readFully`-style "exactly N bytes" is `read_exact(mut self, buffer: Span[UInt8]) raises TruncatedError` — Java's `EOFException` made a first-class typed error. Partial reads stay visible in the return count. Sources: [DataInputStream](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/DataInputStream.html), `mojov1/errors/error-model`.
9. **Stay blocking and synchronous in 1.x.** Mojo's `async`/`await` is documented unstable and async is "listed as a non-goal today"; Mojo's concurrency story is `parallelize`/threads and atomics. Fit the library to that: blocking read/write, no `Future`/`CompletionHandler`, no `Selector`-style readiness multiplexing in the core. Sources: `mojov1/concurrency/async-and-parallelism`, `mojov1/keyword-conventions/async-await`, `mojov1/intro/stability`.
10. **If readiness must be exposed, make it explicit and honest.** Replace `available()` with a documented capability on the handle (e.g. `def bytes_available(self) -> Optional[Int]`), returning `None` when unknown, so callers cannot misuse it as a size. Sources: [InputStream.available](https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html), [Source.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt).
11. **Timeouts as an owned policy object, not scattered ints.** Okio's `Timeout` (per-operation timeout + whole-job deadline, `NONE` sentinel, "task is left in an unspecified state and should be abandoned" on timeout) is a cleaner model than Java's `setSoTimeout(0 == infinite)` per socket. Fit it as a value struct passed to operations that support it. Source: [Timeout.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Timeout.kt).
12. **Explicit non-consuming lookahead instead of `mark`/`reset`.** A `peek()` that returns a view over buffered bytes, or a `Reader` that buffers internally, replaces Java's hidden mark state. Source: [BufferedSource.kt](https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/BufferedSource.kt).

---

## Sources

All Javadoc references are Java SE 25 / JDK 25 (`https://docs.oracle.com/en/java/javase/25/docs/api/java.base/...`).

- `java.io` package summary — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/package-summary.html>
- `InputStream` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStream.html>
- `OutputStream` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/OutputStream.html>
- `Reader` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Reader.html>
- `Writer` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Writer.html>
- `Closeable` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/Closeable.html>
- `IOException` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/IOException.html>
- `EOFException` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/EOFException.html>
- `InterruptedIOException` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InterruptedIOException.html>
- `UncheckedIOException` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/UncheckedIOException.html>
- `FilterInputStream` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/FilterInputStream.html>
- `BufferedInputStream` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedInputStream.html>
- `BufferedReader` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/BufferedReader.html>
- `InputStreamReader` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/InputStreamReader.html>
- `DataInputStream` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/DataInputStream.html>
- `PushbackInputStream` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/io/PushbackInputStream.html>
- `Readable` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Readable.html>
- `Appendable` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/lang/Appendable.html>
- `ByteBuffer` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/ByteBuffer.html>
- `ReadableByteChannel` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/ReadableByteChannel.html>
- `AsynchronousByteChannel` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/AsynchronousByteChannel.html>
- `AsynchronousFileChannel` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/AsynchronousFileChannel.html>
- `Channels` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Channels.html>
- `Selector` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/Selector.html>
- `IllegalBlockingModeException` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/channels/IllegalBlockingModeException.html>
- `Socket` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/Socket.html>
- `SocketTimeoutException` — <https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/net/SocketTimeoutException.html>
- Java Tutorials — The Catch or Specify Requirement — <https://docs.oracle.com/javase/tutorial/essential/exceptions/catchOrDeclare.html>
- Java Tutorials — The try-with-resources Statement — <https://docs.oracle.com/javase/tutorial/essential/exceptions/tryResourceClose.html>
- Okio README — <https://github.com/square/okio>
- Okio docs index — <https://github.com/square/okio/blob/master/docs/index.md>
- Okio `Source.kt` — <https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Source.kt>
- Okio `Sink.kt` — <https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Sink.kt>
- Okio `BufferedSource.kt` — <https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/BufferedSource.kt>
- Okio `Timeout.kt` — <https://raw.githubusercontent.com/square/okio/master/okio/src/commonMain/kotlin/okio/Timeout.kt>
- Apache Commons IO overview — <https://commons.apache.org/proper/commons-io/>
- Apache Commons IO `IOUtils` javadoc — <https://commons.apache.org/proper/commons-io/javadocs/api-release/org/apache/commons/io/IOUtils.html>
- Guava `ByteStreams.java` — <https://raw.githubusercontent.com/google/guava/master/guava/src/com/google/common/io/ByteStreams.java>
- Mojo buch `mojov1/stdlib/io` — local buch `mojov1`, page `stdlib/io`
- Mojo buch `mojov1/errors/error-model` — local buch `mojov1`
- Mojo buch `mojov1/memory/ownership-and-lifetimes` — local buch `mojov1`
- Mojo buch `mojov1/keywords/with` — local buch `mojov1`
- Mojo buch `mojov1/keywords/comptime`, `mojov1/keywords/trait`, `mojov1/functions/parameters-and-generics` — local buch `mojov1`
- Mojo buch `mojov1/concurrency/async-and-parallelism`, `mojov1/keyword-conventions/async-await`, `mojov1/intro/stability` — local buch `mojov1`
- Project frozen run config — `akku/io_core/_dev/README.md`
