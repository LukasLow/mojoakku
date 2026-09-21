# base64 research: Java

Scope: base64/base32/base16 encoding and decoding in Java. Every factual claim
carries a source (URL or `repo/path:line`). Statements without a source are
marked `GUESS:` with the reason.

## 1. Standard library support

- The JDK ships **`java.util.Base64`** (module `java.base`) since **Java 8**. It
  "consists exclusively of static methods for obtaining encoders and decoders",
  and supports three schemes specified by RFC 4648 and RFC 2045: **Basic**,
  **URL and Filename safe**, and **MIME**. Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>
- The actual codec lives in the two nested classes `Base64.Encoder` and
  `Base64.Decoder`. Source: same page.
- The design was standardized by **JEP 135** ("Define a standard API for Base64
  encoding and decoding", delivered in release 8). JEP 135's motivation section
  records that the JDK previously had several internal implementations
  (`java.util.prefs.Base64`, `com.sun.org.apache.xml.internal.security.utils.Base64`,
  `com.sun.net.httpserver.Base64`) and that developers "resort[ed] to using JDK
  private and unsupported classes such as `sun.misc.BASE64Encoder` and
  `sun.misc.BASE64Decoder`". Source: <https://openjdk.org/jeps/135>
- **There is no `Base32` in the JDK.** JEP 135 defines only Base64, and the
  `java.util` package summary lists `Base64`, `Base64.Decoder`,
  `Base64.Encoder` and `HexFormat` — no Base32 class exists. Sources:
  <https://openjdk.org/jeps/135>, <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/package-summary.html>
- **Base16 (hex) in the JDK is `java.util.HexFormat`**, since **Java 17**.
  `HexFormat.of()` gives uppercase/lowercase hex digits plus optional
  prefix/suffix/delimiter; `formatHex(byte[])` and `parseHex(CharSequence)` are
  the byte-array codecs. Source: <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/HexFormat.html>
- Legacy Base64 access that predates Java 8: `javax.xml.bind.DatatypeConverter.printBase64Binary`
  (JAXB). JEP 320 removed the Java EE modules in **Java 11**; its risk section
  names exactly this use case ("some applications rely on JAXB not for XML
  binding, but rather, for the Base64 support offered by the class
  `javax.xml.bind.DatatypeConverter`"). Source: <https://openjdk.org/jeps/320>

## 2. Relevant community libraries

| Library | Package/class | Maturity signal | License (evidence) |
|---|---|---|---|
| Apache Commons Codec | `org.apache.commons.codec.binary.Base64`, `.Base32`, `.Base16` | Class docs at 1.22.1; Base64 since 1.0, Base32 since 1.5, Base64OutputStream since 1.4 | Apache-2.0 — POM header + parent `commons-parent` (<https://repo1.maven.org/maven2/commons-codec/commons-codec/1.17.1/commons-codec-1.17.1.pom>) |
| Guava | `com.google.common.io.BaseEncoding` | "Since: 14.0"; javadoc hosted at 999.0.0-HEAD | Apache-2.0 — repository LICENSE (<https://raw.githubusercontent.com/google/guava/master/LICENSE>) |
| Netty | `io.netty.handler.codec.base64.Base64`, `Base64Encoder`, `Base64Decoder`, `Base64Dialect` | 4.1.138.Final javadoc | Apache-2.0 — repository `LICENSE.txt` (<https://raw.githubusercontent.com/netty/netty/4.1/LICENSE.txt>) |
| Bouncy Castle | `org.bouncycastle.util.encoders.Base64` | current main branch source | MIT — repository `LICENSE.html` (<https://raw.githubusercontent.com/bcgit/bc-java/main/LICENSE.html>) |
| `wujikui/java-base-n-encodings` | third-party RFC 4648 base16/32/64 library | GitHub project (no version/download signal checked) | Apache-2.0 — repository `LICENSE` (<https://github.com/wujikui/java-base-n-encodings>) |

Sources for the table rows other than the license column:
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>,
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>,
<https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>,
<https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>,
<https://raw.githubusercontent.com/bcgit/bc-java/main/core/src/main/java/org/bouncycastle/util/encoders/Base64.java>,
<https://github.com/wujikui/java-base-n-encodings>.

## 3. Exposed APIs

### JDK `Base64` (factory methods)

`getEncoder()`, `getUrlEncoder()`, `getMimeEncoder()`,
`getMimeEncoder(int lineLength, byte[] lineSeparator)`, `getDecoder()`,
`getUrlDecoder()`, `getMimeDecoder()`. `getMimeEncoder` throws
`IllegalArgumentException` "if `lineSeparator` includes any character of 'The
Base64 Alphabet'" and rounds `lineLength` down to a multiple of 4.
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>

### JDK `Base64.Encoder`

| Method | Returns | Notes |
|---|---|---|
| `encode(byte[] src)` | `byte[]` | newly allocated, exact result length |
| `encode(byte[] src, byte[] dst)` | `int` | writes at `dst` offset 0; no bytes written if `dst` too small; throws `IllegalArgumentException` in that case |
| `encodeToString(byte[] src)` | `String` | equivalent to `new String(encode(src), ISO_8859_1)` |
| `encode(ByteBuffer buffer)` | `ByteBuffer` | source position advanced to its limit; output position 0, limit = encoded length |
| `wrap(OutputStream os)` | `OutputStream` | "flush all possible leftover bytes" on close; closing it closes the underlying stream |
| `withoutPadding()` | `Base64.Encoder` | returns a **new** encoder; original instance unchanged |

Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>

### JDK `Base64.Decoder`

| Method | Returns | Notes |
|---|---|---|
| `decode(byte[] src)` | `byte[]` | throws `IllegalArgumentException` if invalid |
| `decode(String src)` | `byte[]` | equivalent to `decode(src.getBytes(ISO_8859_1))` |
| `decode(byte[] src, byte[] dst)` | `int` | if input is invalid, "some bytes may have been written to the output byte array before IllegalArgumentException is thrown" |
| `decode(ByteBuffer buffer)` | `ByteBuffer` | input position **not** advanced on failure |
| `wrap(InputStream is)` | `InputStream` | read methods throw `IOException` on undecodable bytes |

Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>

Instance safety: both `Encoder` and `Decoder` instances "are safe for use by
multiple concurrent threads"; `Base64` itself is stateless/static. Sources: the
two pages above.

### Apache Commons Codec

Builder-configured `Base64.builder()` with `setUrlSafe`, `setLineLength`,
`setLineSeparator`, `setPadding`, `setEncodeTable`, `setDecodeTableFormat`,
`setDecodingPolicy`. Static helpers: `encodeBase64`, `encodeBase64Chunked`,
`encodeBase64String`, `encodeBase64URLSafe`, `encodeBase64URLSafeString`,
`decodeBase64`, `decodeBase64Standard`, `decodeBase64UrlSafe`,
`encodeInteger`/`decodeInteger`, and the predicates `isBase64`,
`isBase64Standard`, `isBase64Url`. `decodeBase64(byte[])` "seamlessly handles
data encoded in URL-safe or normal mode" and "skips unknown or unsupported
bytes". `encodeBase64String` has chunked in 1.4, non-chunked since 1.5.
Source: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>

`Base32` mirrors this with a `Builder` (`setDecodingPolicy`, `setLineLength`,
`setLineSeparator`, `setPadding`, `setEncodeTable`), a `boolean useHex` variant
selector, and `isInAlphabet(byte)`. It "operates directly on byte streams, and
not character streams" and is thread-safe. Source:
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>

### Guava `BaseEncoding`

Statics `base16()`, `base32()`, `base32Hex()`, `base64()`, `base64Url()`;
instance methods `encode(byte[])`, `encode(byte[],int,int)`, `decode(CharSequence)`,
`canDecode(CharSequence)`, `omitPadding()`, `withPadChar(char)`,
`withSeparator(String,int)`, `upperCase()`, `lowerCase()`, `ignoreCase()`,
`encodingStream(Writer)`, `encodingSink(CharSink)`, `decodingStream(Reader)`,
`decodingSource(CharSource)`. Instances are immutable and every configuration
method returns a new instance ("Invoking a configuration method has no effect on
the receiving instance"). Source:
<https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>

### Netty

`Base64` is a static utility over `ByteBuf`: `encode/decode` overloads with
optional `off`/`len`, `breakLines`, `Base64Dialect` and `ByteBufAllocator`.
`Base64Dialect` = `{STANDARD, URL_SAFE, ORDERED}` where `ORDERED` is the
"ordered" dialect of RFC 1940. `Base64Encoder`/`Base64Decoder` are channel
handlers (`Base64Encoder` is `@Sharable`). Source:
<https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>,
<https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Dialect.html>,
<https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Encoder.html>

### Bouncy Castle

`Base64.encode(byte[])`, `encode(byte[],int,int)`, `encode(byte[], OutputStream)`
(returns bytes produced), `toBase64String(...)`, `decode(byte[])`,
`decode(byte[],int,int)`, `decode(String)` (whitespace ignored),
`decode(String, OutputStream)`. Source:
<https://raw.githubusercontent.com/bcgit/bc-java/main/core/src/main/java/org/bouncycastle/util/encoders/Base64.java>

## 4. Error representation

Java uses **unchecked exceptions** (plus `IOException` for wrappers); there are
no error codes, `Result` values or sentinels in any of the surveyed libraries.

- JDK: null argument → `NullPointerException`; invalid Base64 input or too-small
  `dst` → `IllegalArgumentException`; un-allocatable output → `OutOfMemoryError`;
  the `wrap`ped streams use `IOException` instead of `IllegalArgumentException`.
  Sources: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>
- Guava `decode` throws `IllegalArgumentException`; stream decoding throws the
  nested `BaseEncoding.DecodingException` ("Exception indicating invalid
  base-encoded input encountered while decoding"). Source:
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>
- `GUESS:` `BaseEncoding.DecodingException`'s superclass (checked vs unchecked)
  is not stated on the javadoc page I read; I could not source it.
- Commons Codec wraps failures in `EncoderException`/`DecoderException` (the
  `org.apache.commons.codec` exception hierarchy), including
  `IllegalArgumentException` from the builder. Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>
- Bouncy Castle wraps failures: `EncoderException("exception encoding base64
  string: ...")` and `DecoderException("unable to decode base64 data: ...")`.
  Source: the BC source link in section 3.
- Netty's `Base64` utility javadoc documents **no** error contract for its
  `encode`/`decode` overloads; `Base64Encoder.encode` declares
  `throws Exception`. Source:
  <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>,
  <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Encoder.html>

## 5. Ownership semantics (buffer / input and output ownership)

Java has no user-visible ownership model; the contract is per-method buffer
discipline:

- **Allocating overloads own nothing**: `encode(byte[])` / `decode(byte[])`
  return "a newly-allocated byte array"; the caller owns it. Sources: the
  `Base64.Encoder`/`Base64.Decoder` pages.
- **Caller-supplied output** (`encode(src, dst)` / `decode(src, dst)`): the
  invoker "must make sure the output byte array `dst` has enough space"; the
  method returns the number of bytes written and writes starting at offset 0.
  Notably the encoder writes **nothing** when `dst` is too small, while the
  decoder may have written **partial output** before throwing. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>
- **`ByteBuffer`**: encoding consumes the source (position → limit) and returns
  a fresh buffer with position 0; on a decode failure the input position "will
  not be advanced". Source: the `ByteBuffer` method docs on both pages.
- **Streams**: `wrap(OutputStream)` / `wrap(InputStream)` transfer stream
  ownership; closing the returned stream closes the underlying stream. Sources:
  the `wrap` docs on both pages.
- Commons stream codecs add a hard lifecycle obligation: "It is mandatory to
  close the stream after the last byte has been written to it, otherwise the
  final padding will be omitted and the resulting data will be
  incomplete/inconsistent." Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64OutputStream.html>
- Commons `BaseNCodec` exposes `Context`-based internals (`ensureBufferSize`,
  `getEncodedLength`, `isWhiteSpace`) that a caller can drive; chunked
  `encode(byte[], int, int)` is the incremental entry point. Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>

## 6. Blocking / non-blocking

- All byte-array/ByteBuffer codecs in the JDK, Commons, Guava and Bouncy Castle
  are **pure in-memory, CPU-bound calls** with no I/O and therefore no blocking
  or async behavior; their signatures contain no `Future`, `CompletionStage` or
  async variants. Sources: the API pages cited in section 3.
- The only I/O in the JDK API is the pair `Encoder.wrap(OutputStream)` /
  `Decoder.wrap(InputStream)` (and Guava's `encodingStream`/`decodingStream`,
  Commons' `Base64OutputStream`/`Base64InputStream`). Blocking behavior there is
  inherited from the wrapped stream; the codec adds no threading, buffering
  policy or async layer. Sources:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>,
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64OutputStream.html>
- Netty is the exception in spirit, not in signature: `Base64Encoder` /
  `Base64Decoder` run inside a `ChannelPipeline` and are event-loop driven, so
  they never block the calling thread; the static `Base64` utility is still
  synchronous over a `ByteBuf`. Source:
  <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Encoder.html>

## 7. Alphabet variants (standard / URL-safe) and padding handling

| Variant | Alphabet difference | Padding | Line breaks |
|---|---|---|---|
| Basic | Table 1 of RFC 4648 (`+`, `/`) | `=`; decoder accepts missing padding but requires the correct count if any `=` is present | never added |
| URL and Filename safe | Table 2 (`-`, `_`) | same as Basic | never added |
| MIME | Table 1 (RFC 2045) | `=` | ≤ 76 chars/line, CRLF, no trailing separator; all non-alphabet characters ignored on decode |

Decoder rejects characters outside the alphabet for Basic and URL-safe. Sources:
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>,
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>

- `withoutPadding()` switches padding off by returning a new encoder. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>
- RFC 4648 §3.2 mandates padding "unless the specification ... explicitly states
  otherwise"; §5 notes base64url padding is often omitted when the length is
  known implicitly. Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>
- Commons: "The URL-safe parameter is only applied to encode operations.
  Decoding seamlessly handles both modes"; `urlSafe` "emit[s] - and _ instead
  of + and /", and "**No padding is added when using the URL-safe alphabet.**"
  A dedicated `DecodeTableFormat` can force strict standard or strict URL-safe
  decoding. Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>
- Guava: per-encoding table lists `base32` (`A-Z 2-7`), `base32Hex` (`0-9 A-V`),
  `base64`, `base64Url`; "By default, BaseEncoding's behavior is relatively
  strict and in accordance with RFC 4648. Decoding rejects characters in the
  wrong case, though padding is optional." `omitPadding()`, `withPadChar(char)`
  and `withSeparator(String,int)` change those aspects. Sources:
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>,
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- Netty: `Base64Dialect.URL_SAFE` carries an explicit warning — "data encoded
  this way is *not* officially valid Base64, or at the very least should not be
  called Base64 without also specifying that is was encoded using the URL-safe
  dialect"; `ORDERED` is an obsolete RFC 1940 dialect. Source:
  <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Dialect.html>
- Commons base32 has both the RFC 4648 §6 table and the §7 extended-hex table
  (`useHex`). Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>
- Contradiction worth noting: the `Base32` class description says "Line length:
  Default 76", while the no-argument `Base32()` constructor says "When encoding
  the line length is 0 (no chunking)". Both on the same page; the effective
  no-arg default is therefore ambiguous in the docs. Source: same page.
- `GUESS:` default padding behaviour of Netty's `Base64.encode(ByteBuf)` is not
  documented (the overload has no description), so I cannot state whether it
  pads or emits line breaks.

## 8. Timeouts and cancellation

Not applicable to the codec itself, and this is a design property rather than a
limitation:

- The JDK, Commons, Guava and Bouncy Castle APIs expose **no timeout,
  deadline, interrupt or cancellation parameter**; a full-buffer
  `encode`/`decode` call is a single non-interruptible computation. Sources: the
  API pages in section 3.
- Where I/O is involved via `wrap`/streams, timeouts belong to the wrapped
  stream (e.g. a socket's `setSoTimeout`), not to the codec; the codec's own
  contract only mentions `IOException` on bad bytes. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>
- Netty handlers inherit cancellation semantics from the channel lifecycle
  (`ChannelHandler`/`ChannelPipeline`), not from the Base64 codec. Source:
  <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Encoder.html>
- `GUESS:` whether an in-flight `IllegalArgumentException` can leave a
  `ByteBuffer` in a partially consumed state on the *error* path for the
  `encode(ByteBuffer)` overload is not stated (only the decode path documents
  "position will not be advanced").

## 9. Streaming: incremental/chunked encode/decode with leftover bytes

Java's answer is **decorate a stream**, not "feed chunks to a stateful function",
with one notable exception (Commons `BaseNCodec`).

- JDK: `Encoder.wrap(OutputStream)` and `Decoder.wrap(InputStream)`. The encoder
  is told to be closed promptly because closing "will flush all possible
  leftover bytes to the underlying output stream"; both wrappers close the
  underlying stream. Sources:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>
- Guava: `encodingStream(Writer)` and `decodingStream(Reader)`; "When the
  returned OutputStream is closed, so is the backing Writer."
  Source: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>
- Commons: `Base64OutputStream`/`Base32OutputStream` provide "Base64 encoding in a
  streaming fashion (unlimited size)"; again the stream must be closed or the
  final padding is lost. `BaseNCodec.encode(byte[], int, int)` plus an explicit
  `Context` is the lower-level incremental path. Sources:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64OutputStream.html>,
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>
- **Leftover bits** are the crux of streaming decode. Commons documents two
  policies for trailing, non-encodable bits: *lenient* (default) — "Any trailing
  bits are composed into 8-bit bytes where possible. The remainder are
  discarded" — and *strict* — decoding "will raise an IllegalArgumentException
  if trailing bits are not part of a valid encoding. Any unused bits from the
  final character must be zero. Impossible counts of entire final characters are
  not allowed." Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64OutputStream.html>
- The quantum arithmetic that defines how many bytes/characters must be carried
  between chunks comes from the RFC: base64 maps 3 octets to 4 characters
  (§4), base32 maps 5 octets to 8 characters (§6), and the legal partial final
  units are enumerated there. Source: <https://www.rfc-editor.org/rfc/rfc4648.txt>
- Netty splits the difference with an event-driven model: `Base64Encoder` /
  `Base64Decoder` accept one `ByteBuf` message at a time, and `Base64.encode` /
  `decode` accept `off`/`len` so a caller can process a window and keep its own
  bookkeeping. Netty's API, however, documents no explicit "carry N leftover
  bytes" state handle. Sources: the Netty pages in section 3.
- `GUESS:` line-breaking in `Base64Encoder(boolean breakLines)` is described only
  by the parameter name; the line length used is not documented on the javadoc
  page I read.

## 10. Interesting design decisions

- **Stateless codec objects obtained from factories** (`getEncoder()`,
  `getUrlDecoder()`, ...) instead of free functions. It makes the scheme a
  first-class value, keeps the three variants out of the call site, and makes
  thread-safety a documented property rather than an accident. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>
- **Immutability via copy-on-configure**: `withoutPadding()` returns a new
  encoder and leaves the receiver untouched; Guava turns this into the whole
  configuration API (`omitPadding()`, `withSeparator()`, `upperCase()`), with an
  explicit warning that ignoring the return value does nothing, and the
  guarantee `encoding.decode(encoding.encode(x)) == x` with the reverse *not*
  guaranteed. Sources: the JDK `Encoder` page, the Guava page.
- **MIME as a first-class third scheme** (line length + CRLF + ignore
  non-alphabet characters) rather than a bolt-on wrapper. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>
- **Two output strategies on the same encoder**: allocating (`byte[]`) and
  caller-provided (`byte[] dst`, returns count). The asymmetry between them on
  failure (encoder writes nothing; decoder may write a prefix) is a deliberate
  documented contract. Sources: the `Encoder` and `Decoder` pages.
- **Stream wrapping with an explicit "close to flush" contract** for the
  encoder, because the padding and the final partial quantum live in the
  wrapper. Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>
- **Strict vs lenient decoding as an enum** (`CodecPolicy`), with a precise
  definition of what "trailing bits" legality means, and a re-encode round-trip
  expectation under strict mode. Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64OutputStream.html>
- **A shared `BaseNCodec` core** for base16/32/64, parameterized by alphabet
  tables, decode tables, padding byte, line length/separator, plus per-instance
  `Builder`s. Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>
- **Validation as its own API** (`canDecode`, `isBase64(...)`,
  `isBase64Standard(...)`, `isBase64Url(...)`) instead of "decode and catch",
  with `canDecode` documented since Guava 20.0 and the strict predicates since
  Commons 1.21. Sources: the Guava page, the Commons `Base64` page.
- **A separate dedicated Base64 utility over a pooled buffer type** (Netty
  `ByteBuf`, with `ByteBufAllocator` passed in) and a pipeline handler with a
  dialect enum. Sources: the Netty `Base64` and `Base64Dialect` pages.
- Netty credits its algorithm to "Robert Harder's Public Domain Base64
  Encoder/Decoder" — a reminder that the core algorithm is public-domain prior
  art. Source:
  <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>

## 11. Decisions NOT to copy

- **MIME line-wrapping as a built-in scheme default.** RFC 4648 §3.1 is blunt:
  "Implementations MUST NOT add line feeds to base-encoded data unless the
  specification referring to this document explicitly directs base encoders to
  add line feeds after a specific number of characters." A MIME mode is fine as
  an explicit opt-in, but the default must be unframed. Source:
  <https://www.rfc-editor.org/rfc/rfc4648.txt>
- **Silently skipping non-alphabet characters.** Commons
  `decodeBase64`/`decodeBase64Standard`/`decodeBase64UrlSafe` "skip unknown or
  unsupported bytes/characters", and the JDK MIME decoder ignores them. RFC 4648
  §3.3 requires rejection by default and §12 explains why ignoring creates a
  covert channel: "If non-alphabet characters are ignored ... a covert channel
  that can be used to 'leak' information is made possible." Sources: the
  Commons `Base64` page, the JDK `Base64` page, RFC 4648 §3.3 and §12.
- **The partial-write-on-error contract** of `decode(byte[], byte[])` ("some
  bytes may have been written ... before IllegalArgumentException is thrown").
  Rejecting invalid input after mutating the caller's buffer is a foot-gun; a
  Mojo API should decode into a fresh buffer and only then hand it over.
  Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>
- **"Close or lose the padding" as an implicit obligation of a stream wrapper.**
  Commons has to document it in bold; a design where finalization is an
  explicit, checked step is safer. Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64OutputStream.html>
- **Surprising URL-safe/padding coupling**: Commons refuses to add padding for
  the URL-safe alphabet by default, which mixes two orthogonal concerns
  (alphabet vs padding). Sources:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>,
  RFC 4648 §5 and §3.2.
- **Unchecked exceptions for invalid input** (`IllegalArgumentException`) with
  no machine-readable error value; plus the builder's `IllegalArgumentException`
  for a bad line separator, and `OutOfMemoryError` as the documented failure of
  "cannot allocate". A typed error with distinct cases is strictly more
  informative. Sources: the JDK `Encoder`/`Decoder` pages, the Commons `Base64`
  page.
- **An obsolete dialect in a public enum** (`Base64Dialect.ORDERED`, RFC 1940)
  that RFC 4648 obsoletes. Sources:
  <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Dialect.html>,
  <https://www.rfc-editor.org/rfc/rfc4648.txt> ("Obsoletes: 3548"; the RFC 1940
  variant is not part of the base-N encodings it defines).
- **Mutable-superclass inheritance for configuration** (Commons
  `BaseNCodec` subclass constructors carry long parameter lists and are
  deprecated in favour of builders). Source:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>

## 12. Ideas fitting Mojo

- **Raising functions with a typed error.** The JDK/MIME contrast (reject vs
  ignore) and Commons' strict/lenient policy map cleanly onto a single Mojo
  error type carried out of a `raises Base64Error` signature; Mojo represents
  errors as alternate return values with no stack unwinding, and a `try` block
  handles exactly one error type — so one error type with variants is the right
  shape. Sources: <https://mojolang.org/docs/manual/errors/>; buch
  `mojov1/errors/raising-and-propagation` (same manual page).
- **Non-owning input, owned output.** A `Span[UInt8]` / `Pointer[mut=False, Byte, _]`
  input parameter is Mojo's native "view without a copy" (`Span` is documented
  as a non-owning view; `Pointer[mut=False, ...]` lets the compiler infer the
  origin while forbidding mutation), and a freshly returned `List[UInt8]` keeps
  the ownership story as simple as the JDK's allocating overloads. Sources:
  buch `mojov1/types/pointers-and-references` and `mojov1/appendix/cheat-sheet`
  (types table: `List[T]`, `Span[T, origin]`), citing
  <https://mojolang.org/docs/manual/pointers/using-pointers/>.
- **Explicit destination-buffer overload without Java's traps.** Keep "return
  bytes written", but either write nothing on failure (encoder semantics) or
  require a `mut` `Span` plus a documented precondition, rather than the
  decoder's partial-write behavior. Source (behavior being avoided):
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>
- **Compile-time alphabet/variant selection.** Java's scheme is a runtime
  factory value; in Mojo an alphabet can be a `comptime` parameter/alias so the
  table is chosen at compile time and the unused tables never materialize.
  Sources: buch `mojov1/appendix/cheat-sheet` (`comptime`, "Parameterized
  alias") citing <https://mojolang.org/docs/manual/metaprogramming/comptime-evaluation/>.
- **Precomputed lookup tables as compile-time constants.** The same "table
  indexed by a fixed-width chunk" technique Java libraries use at construction
  time can be a `comptime` constant in Mojo. Source (technique exists in Java):
  the Commons `BaseNCodec`/`Base32` builder-set tables, section 3.
- **Validation as a first-class, allocation-free operation.** Guava's
  `canDecode` and Commons' `isBase64*` predicates are exactly the shape of a
  Mojo `is_valid(...) -> Bool` over a `Span` that allocates nothing. Sources:
  the Guava page, the Commons `Base64` page.
- **Padding and alphabet as independent options.** Java's URL-safe-without-padding
  coupling is the anti-pattern; Mojo is better served by orthogonal
  `alphabet` / `padding` choices. Sources: the Commons `Base64` page, RFC 4648
  §3.2 and §5.
- **Strict-canonical rejection as the default.** RFC 4648 permits decoders to
  reject non-zero pad bits (§3.5), and Mojo can make the strict reading the
  default and the lenient one explicit — the inverse of Commons' default.
  Sources: <https://www.rfc-editor.org/rfc/rfc4648.txt>,
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64OutputStream.html>
- **No timeouts, no async, no blocking — by construction.** A pure
  `Span -> List[UInt8]` function has no cancellation surface, which suits the
  Mojo model as described in the buch. Sources: sections 6 and 8 here; buch
  `mojov1/errors/raising-and-propagation`.

## Sources

- Java SE 21 — `java.util.Base64`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>
- Java SE 21 — `java.util.Base64.Encoder`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>
- Java SE 21 — `java.util.Base64.Decoder`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>
- Java SE 21 — `java.util` package summary: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/package-summary.html>
- Java SE 17 — `java.util.HexFormat`: <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/util/HexFormat.html>
- JEP 135 — Base64 Encoding & Decoding: <https://openjdk.org/jeps/135>
- JEP 320 — Remove the Java EE and CORBA Modules: <https://openjdk.org/jeps/320>
- RFC 4648 — The Base16, Base32, and Base64 Data Encodings: <https://www.rfc-editor.org/rfc/rfc4648.txt>
- Apache Commons Codec — `Base64`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>
- Apache Commons Codec — `Base32`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>
- Apache Commons Codec — `Base64OutputStream`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64OutputStream.html>
- Apache Commons Codec — `BaseNCodec`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>
- Commons Codec 1.17.1 POM (license): <https://repo1.maven.org/maven2/commons-codec/commons-codec/1.17.1/commons-codec-1.17.1.pom>
- Guava — `BaseEncoding`: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>
- Guava LICENSE: <https://raw.githubusercontent.com/google/guava/master/LICENSE>
- Netty 4.1 — `Base64`: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>
- Netty 4.1 — `Base64Dialect`: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Dialect.html>
- Netty 4.1 — `Base64Encoder`: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Encoder.html>
- Netty LICENSE.txt: <https://raw.githubusercontent.com/netty/netty/4.1/LICENSE.txt>
- Bouncy Castle — `org.bouncycastle.util.encoders.Base64`: <https://raw.githubusercontent.com/bcgit/bc-java/main/core/src/main/java/org/bouncycastle/util/encoders/Base64.java>
- Bouncy Castle LICENSE: <https://raw.githubusercontent.com/bcgit/bc-java/main/LICENSE.html>
- `wujikui/java-base-n-encodings`: <https://github.com/wujikui/java-base-n-encodings>
- Mojo buch `mojov1`: `errors/raising-and-propagation`, `types/pointers-and-references`, `appendix/cheat-sheet` (<https://mojolang.org/docs/manual/errors/>, <https://mojolang.org/docs/manual/pointers/using-pointers/>, <https://mojolang.org/docs/reference/>)
