# base64 research: Java

## 1. Standard library support

The JDK ships Base64 in the `java.base` module, package `java.util`, class
`java.util.Base64` (since Java 8), plus the nested `Base64.Encoder` and
`Base64.Decoder` classes. It consists "exclusively of static methods for
obtaining encoders and decoders" and supports three base64 flavours defined by
RFC 4648 and RFC 2045.
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>.

The three flavours:

- **Basic** — "The Base64 Alphabet" of RFC 4648 Table 1 / RFC 2045; encoder adds
  no line feeds; decoder rejects characters outside the alphabet.
- **URL and Filename safe** — the RFC 4648 Table 2 alphabet; no line feeds;
  decoder rejects characters outside the alphabet.
- **MIME** — RFC 2045 Table 1; output in lines of at most 76 characters with CRLF
  (`\r\n`); no line separator at the end; "All line separators or other characters
  not found in the base64 alphabet table are ignored in decoding operation."

Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>.

**There is no Base32 in the JDK.** The Java 21 `java.util` package class list
contains `Base64`, `Base64.Decoder`, `Base64.Encoder` and the hex formatter
`HexFormat`, but no `Base32` class; the package description mentions only
"base64 encoding and decoding".
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/package-summary.html>.

Base16/hex is only partly present: `java.util.HexFormat` (since Java 17)
"converts between bytes and chars and hex-encoded strings which may include
additional formatting markup such as prefixes, suffixes, and delimiters". It
offers `formatHex`, `parseHex`, `toHexDigits*`, `fromHexDigits*`, case control
(`withUpperCase`/`withLowerCase`) and delimiters, is immutable and thread-safe,
and is a value-based class. It is a *formatter*, not a codec class shaped like
`Base64`.
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/HexFormat.html>.

The old XML-bound base64 surface (`javax.xml.bind.DatatypeConverter`, in module
`java.xml.bind`) was removed from the JDK in Java 11 by JEP 320, which explicitly
names `javax.xml.bind.DatatypeConverter` as a class some applications used "for
the Base64 support" and recommends `java.util.Base64` instead.
Source: <https://openjdk.org/jeps/320>.

## 2. Relevant community libraries

| Library | Coordinates / package | Maintainer | Maturity | License
|---|---|---|---|---|
Apache Commons Codec | `org.apache.commons.codec.binary.*` | Apache Software Foundation | 1.22.1, published 27 Jul 2026, Java 8+ | Apache-2.0
Guava | `com.google.common.io.BaseEncoding` | Google | since 14.0, actively maintained | Apache-2.0
Netty | `io.netty.handler.codec.base64.*` | The Netty Project | 4.1.138.Final in current API docs | Apache-2.0
Bouncy Castle | `org.bouncycastle.util.encoders.*` | Legion of the Bouncy Castle Inc. | bcprov-jdk18on 1.85 API docs | MIT

Sources:
- Commons Codec version/date/link and license link:
  <https://commons.apache.org/proper/commons-codec/> (page footer "Version:
  1.22.1", "Last Published: 27 Jul 2026", "requires Java 8 or above", License ->
  <https://www.apache.org/licenses/LICENSE-2.0>).
- Guava `BaseEncoding` "Since: 14.0", author Louis Wasserman:
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>;
  license Apache-2.0: <https://github.com/google/guava/blob/master/LICENSE>.
- Netty API reference header "Netty API Reference (4.1.138.Final)":
  <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>; license
  Apache-2.0: <https://github.com/netty/netty/blob/4.1/LICENSE.txt>.
- Bouncy Castle API doc title "prov 1.85 API":
  <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/Base64.html>;
  license "Bouncy Castle APIs are released under the MIT license":
  <https://www.bouncycastle.org/about/license/>.

Commons Codec is the de-facto pre-Java-8 base64 implementation; its own history
explains it was formed to consolidate the many competing Base64 classes in the ASF
repositories (the impetus page says approximately 34), and its Base64 doc says it
"implements RFC 2045 6.8 Base64 Content-Transfer-Encoding".
Sources: <https://commons.apache.org/proper/commons-codec/>,
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>.

(Assessment: derived from the four sources above: Java has a genuinely complete
stdlib Base64 since 8 and a hex formatter since 17, so the community libraries
add value mainly for Base32/Base58, richer policy control and streaming
integration, not for base64 core.)

## 3. Exposed APIs

### JDK `java.util.Base64` factories

`getEncoder()`, `getUrlEncoder()`, `getMimeEncoder()`,
`getMimeEncoder(int lineLength, byte[] lineSeparator)`, `getDecoder()`,
`getUrlDecoder()`, `getMimeDecoder()`. `getMimeEncoder(int, byte[])` documents
that `lineLength` is "rounded down to nearest multiple of 4", and throws
`IllegalArgumentException` if `lineSeparator` contains a Base64 alphabet
character.
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>.

### JDK `Base64.Encoder`

- `byte[] encode(byte[] src)` — newly allocated result.
- `int encode(byte[] src, byte[] dst)` — writes at offset 0; caller must size
  `dst`; throws `IllegalArgumentException` if `dst` is too small; no bytes are
  written if `dst` is too small.
- `String encodeToString(byte[] src)` — equivalent to
  `new String(encode(src), StandardCharsets.ISO_8859_1)`.
- `ByteBuffer encode(ByteBuffer buffer)` — encodes remaining bytes; on return
  source position = limit, result position 0, limit = encoded length.
- `Base64.Encoder withoutPadding()` — returns an equivalent encoder that omits
  the padding character.
- `OutputStream wrap(OutputStream os)` — returns an encoding stream; closing it
  flushes leftover bytes and closes the underlying stream.

Instances are "safe for use by multiple concurrent threads"; a failed output
allocation causes `OutOfMemoryError`; a null argument causes
`NullPointerException`.
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.

### JDK `Base64.Decoder`

- `byte[] decode(byte[] src)`, `byte[] decode(String src)`.
- `int decode(byte[] src, byte[] dst)` — "If the input byte array is not in valid
  Base64 encoding scheme then some bytes may have been written to the output byte
  array before IllegalArgumentException is thrown."
- `ByteBuffer decode(ByteBuffer buffer)` — on failure the input position is not
  advanced.
- `InputStream wrap(InputStream is)` — decoding stream; `read` throws
  `IOException` on undecodable bytes; closing closes the underlying stream.

Instances are thread-safe; null -> `NullPointerException`; allocation failure ->
`OutOfMemoryError`.
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.

### Apache Commons Codec

`org.apache.commons.codec.binary.Base64 extends BaseNCodec`; configuration is via
a builder (constructors are `@Deprecated`): `setDecodingPolicy`, `setEncodeTable`,
`setLineLength`, `setLineSeparator`, `setPadding`, `setUrlSafe`.
`BaseNCodec` supplies `encode(byte[])`, `encode(byte[],int,int)`,
`encodeAsString`, `encodeToString`, `decode(byte[])`, `decode(String)`,
`decode(Object)`, `isInAlphabet(...)`, `getEncodedLength(byte[])`,
`isStrictDecoding()`. Static helpers on `Base64`:
`encodeBase64`, `encodeBase64Chunked`, `encodeBase64String`,
`encodeBase64URLSafe`, `encodeBase64URLSafeString`, `decodeBase64`,
`decodeBase64Standard`, `decodeBase64UrlSafe` (since 1.21), `isBase64`,
`isBase64Standard`, `isBase64Url`, `encodeInteger`/`decodeInteger`.
Subclasses: `Base16`, `Base32`, `Base58`, `Base64`. Streaming:
`Base64InputStream` / `Base64OutputStream` (also Base16/Base32 variants).
Sources:
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>,
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>,
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base16.html>.

### Guava `BaseEncoding`

Static factories `base16()`, `base32()`, `base32Hex()`, `base64()`,
`base64Url()`. Instance methods: `encode(byte[]) -> String`,
`encode(byte[],int,int)`, `decode(CharSequence) -> byte[]`,
`canDecode(CharSequence)`, `encodingStream(Writer)`, `decodingStream(Reader)`,
`encodingSink(CharSink)`, `decodingSource(CharSource)`, and the configuration
methods `omitPadding()`, `withPadChar(char)`, `withSeparator(String,int)`,
`upperCase()`, `lowerCase()`, `ignoreCase()`. Instances are immutable; the
configuration methods return new instances and have no effect on the receiver.
Source: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.

### Netty

`io.netty.handler.codec.base64.Base64` is a `ByteBuf`-oriented utility:
`encode(ByteBuf)`, `encode(ByteBuf, boolean breakLines)`,
`encode(ByteBuf, Base64Dialect)`, `encode(ByteBuf,int,int,boolean,Base64Dialect,
ByteBufAllocator)` and the mirroring `decode(...)` overloads. Dialects are the
enum `Base64Dialect`: `STANDARD`, `URL_SAFE`, `ORDERED`.
Sources:
<https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>,
<https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Dialect.html>.

### Bouncy Castle

Package `org.bouncycastle.util.encoders` contains `Base64`, `Base32`, `Hex`,
`UrlBase64`; streaming encoders `Base64Encoder`, `Base32Encoder`, `HexEncoder`;
the `Encoder` interface; buffering helpers `BufferedDecoder`/`BufferedEncoder`;
and `DecoderException`/`EncoderException`. `Base64` exposes
`toBase64String`, `encode(byte[])`, `encode(byte[],int,int)`,
`encode(byte[],OutputStream)`, `decode(byte[])`, `decode(byte[],int,int)`,
`decode(String)`, `decode(String,OutputStream)`.
Sources:
<https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>,
<https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/Base64.html>.

## 4. Error representation

Java uses **unchecked and checked exceptions**, split by layer:

- JDK in-memory codec: **unchecked** `IllegalArgumentException` on invalid input
  (`decode(byte[])` "Throws IllegalArgumentException if src is not in valid
  Base64 scheme"), `NullPointerException` for null arguments, and `OutOfMemoryError`
  when output cannot be allocated. Sources:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.
- JDK stream wrapper: **checked** `IOException` — "The read methods of the
  returned InputStream will throw IOException when reading bytes that cannot be
  decoded." Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.
- Guava: `decode` throws `IllegalArgumentException`; the decoding *stream* throws
  the dedicated `BaseEncoding.DecodingException`. Source:
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.
- Commons Codec: lenient by default; with `CodecPolicy.STRICT` decoding raises
  `IllegalArgumentException` "if trailing bits are not part of a valid encoding";
  the `Decoder`/`Encoder` object interfaces throw checked `DecoderException`/
  `EncoderException`, and the static helpers throw `IllegalArgumentException`.
  Sources:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>,
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>.
- Bouncy Castle: dedicated checked `DecoderException` / `EncoderException` types.

(Assessment: derived from the sources above: Java's error surface is fragmented
by layer and policy — `IllegalArgumentException` in memory, `IOException` in
streams, `DecoderException` for the codec interface, and a *decoding policy*
that turns malformed input from an error into silently discarded bits unless
strict mode is selected.)

## 5. Ownership semantics

Java has no user-visible ownership model; every byte container is a managed
reference on the heap, and the GC owns it. What matters for base64 is **which
side allocates the output buffer and who is responsible for its size**.

- **JDK input is borrowed.** `encode(byte[] src)` / `decode(byte[] src)` read the
  argument and never claim it; the caller keeps the array. `decode(String src)`
  documents "exactly the same effect as invoking
  `decode(src.getBytes(StandardCharsets.ISO_8859_1))`", i.e. it materialises a
  temporary copy internally. Sources:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.
- **Returning encode/decode allocate a fresh array** owned by the caller:
  "A newly-allocated byte array containing the resulting encoded bytes."
  Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.
- **Caller-allocated output variant** shifts the sizing responsibility onto the
  caller: `encode(byte[] src, byte[] dst)` — "It is the responsibility of the
  invoker ... to make sure the output byte array dst has enough space ... No
  bytes will be written ... if the output byte array is not big enough", and the
  method returns the number of bytes written.
  Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.
- **NIO variants transfer cursor state instead of ownership.** `encode(ByteBuffer)`
  advances the *source* position to its limit and returns a fresh buffer whose
  position is 0 and limit is the encoded length; there is no write-back into the
  source. `decode(ByteBuffer)` likewise returns a fresh buffer, and leaves the
  input position untouched on failure. Sources:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.
- **Streams own their delegate for the wrapped API only.** `wrap(OutputStream)`
  "Closing the returned output stream will close the underlying output stream";
  the same holds for the decoding `InputStream`. The wrapped stream object
  itself is the caller's to close. Sources:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.
- **Commons Codec mirrors this** with `encode(byte[])` (new array),
  `encode(byte[],int,int)` (offset/length view, new array),
  `getEncodedLength(byte[])` to size an output ahead of time, and
  `encode(Object)` returning a boxed `Object`.
  Source: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>.
- **Guava is String-centric**: `encode` returns a `String` (never a byte array),
  `decode(CharSequence)` returns a fresh `byte[]`.
  Source: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.

## 6. Blocking / non-blocking

Not applicable at the codec level, and this is explicit in two ways:

- The JDK's `java.io` stream wrappers (`Base64.Encoder.wrap`,
  `Base64.Decoder.wrap`) are **blocking** `java.io` streams. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.
- The NIO `ByteBuffer` overloads are **pure in-memory transformations** — they
  consume a buffer's remaining bytes and return a new buffer, with no I/O at all.
  Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.

There is no async/reactive base64 API in the JDK. Thread-safety is the only
concurrency concern the docs address: "Instances of Base64.Encoder class are safe
for use by multiple concurrent threads", and likewise for `Decoder`; Commons
Codec `Base64` and `BaseNCodec` are likewise documented "thread-safe"; Guava
`BaseEncoding` instances are immutable and safe as static constants.
Sources: JDK javadocs above;
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>,
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>,
<https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.

(Assessment: derived from the sources above: for a pure codec, "blocking vs
non-blocking" reduces entirely to "in-memory vs streaming"; Java answers it by
offering both shapes and making neither asynchronous.)

## 7. Alphabet variants and padding

### JDK alphabets

Selected by *factory method*, not by passing an alphabet:

- `getEncoder()` / `getDecoder()` -> RFC 4648 Table 1 basic alphabet.
- `getUrlEncoder()` / `getUrlDecoder()` -> RFC 4648 Table 2 URL/filename-safe
  alphabet.
- `getMimeEncoder()` / `getMimeDecoder()` -> RFC 2045 alphabet with 76-char CRLF
  lines; decoding ignores all non-alphabet characters including line separators.

Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>.

There is no custom-alphabet entry point in the JDK. The only knob is padding:
`withoutPadding()` returns "an encoder instance that encodes equivalently to this
one, but without adding any padding character at the end".
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.

Padding on decode is **optional but consistent**: "'=' is accepted and interpreted
as the end of the encoded byte data, but is not required. So if the final unit of
the encoded byte data only has two or three Base64 characters ... they are decoded
as if followed by padding character(s). If there is a padding character present in
the final unit, the correct number of padding character(s) must be present,
otherwise IllegalArgumentException (IOException when reading from a Base64 stream)
is thrown."
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.

### Community alphabets

- Commons Codec: `Builder.setUrlSafe(boolean)`, custom `setEncodeTable` and
  `setDecodeTable`/`DecodeTableFormat`, `setPadding(char)`; `Base32` supports the
  RFC 4648 section 6 alphabet and the section 7 "base32hex" variant; `Base16`
  supports lower-/upper-case and a custom 16-byte table. **URL-safe encoding adds
  no padding.** Decoding "seamlessly handles both modes".
  Sources:
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>,
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>,
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base16.html>.
- Guava: `base16`, `base32`, `base32Hex`, `base64`, `base64Url`, all RFC 4648
  (sections 4/5/6/7/8); padding default `=`, adjustable via `omitPadding()` /
  `withPadChar(char)`, line breaks via `withSeparator(String,int)`, case via
  `upperCase()`/`lowerCase()`/`ignoreCase()`. The docs warn the class is
  "relatively strict and in accordance with RFC 4648. Decoding rejects characters
  in the wrong case, though padding is optional."
  Source: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.
- Netty: `Base64Dialect.STANDARD`, `URL_SAFE` and the rare `ORDERED` dialect from
  RFC 1940. Netty notes URL-safe data "is *not* officially valid Base64, or at the
  very least should not be called Base64 without also specifying that is was
  encoded using the URL-safe dialect."
  Source: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Dialect.html>.
- Bouncy Castle: separate classes `Base64`, `Base32` and `UrlBase64`
  (plus `Hex`), with streaming encoder equivalents.
  Source: <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>.

(Assessment: derived from the sources above: the recurring design split is
between factories/classes per alphabet (JDK, Bouncy Castle) and one configurable
immutable encoder type (Guava, Commons Codec builder). The JDK and Netty both
retain "MIME/ordered" legacies; Guava and Commons Codec converge on the RFC 4648
sections 4/5 pair plus an explicit padding toggle.)

## 8. Timeouts / cancellation

Not applicable. Nothing in the `java.util.Base64` surface accepts or documents a
timeout or cancellation token; the encode/decode methods are synchronous
in-memory transformations, and the only "slowness" they can express is
`OutOfMemoryError` when the output cannot be allocated.
Sources: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>,
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.

Interruption is likewise not modelled: there is no `InterruptedException` in the
codec API. For stream wrappers, the underlying `java.io` stream's own blocking
semantics and `IOException` are the only failure paths; the wrapper itself adds
none.
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.

(Assessment: derived from the sources above: a pure codec has no cancellation
surface, and Java deliberately does not invent one — it exposes stream wrappers so
that the *transport* owns blocking, timeouts and interruption.)

## 9. Streaming / incremental encode + decode, leftover-byte carry

### JDK: stream wrappers carry leftovers, in-memory API does not

- `Base64.Encoder.wrap(OutputStream)` returns an `OutputStream`. The doc is
  explicit about leftover handling: "It is recommended to promptly close the
  returned output stream after use, during which it will flush all possible
  leftover bytes to the underlying output stream." This is the leftover-byte
  carry: the wrapper buffers up to 2 unencoded input bytes plus the pending
  4-char group and flushes them on `close()`/`flush()`.
  Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.
- `Base64.Decoder.wrap(InputStream)` returns a decoding `InputStream`; it must be
  read to end for the final quantum to be produced, and "Closing the returned
  input stream will close the underlying input stream."
  Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.
- The in-memory overloads are **one-shot only**: `encode(byte[])`,
  `encodeToString`, `encode(ByteBuffer)` and the matching decoders take a complete
  input and return a complete output. There is no public incremental `update(...)`
  API on `Base64.Encoder`/`Decoder`; chunking across calls is available *only*
  through `wrap`, or by using Commons Codec/Guava streams.
  Sources: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.

### Community: explicit streaming classes

- Commons Codec: `Base64InputStream` / `Base64OutputStream` (and Base16/Base32
  equivalents), plus the generic `BaseNCodec` context mechanism (`Context`,
  `ensureBufferSize`, `getEncodedLength`) that holds partial-block state between
  calls.
  Sources: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>,
  <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>.
- Guava: `encodingStream(Writer)` returns an `OutputStream` that "when the
  returned OutputStream is closed, so is the backing Writer"; `decodingStream(Reader)`
  returns an `InputStream` that "throws a BaseEncoding.DecodingException upon
  decoding-specific errors", plus sink/source adapters `encodingSink`,
  `decodingSource`.
  Source: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.
- Bouncy Castle: explicit streaming encoders `Base64Encoder`, `Base32Encoder`,
  `HexEncoder` implementing the `Encoder` interface, plus
  `BufferedDecoder`/`BufferedEncoder`, "A buffering class to allow translation
  from one format to another to be done in discrete chunks."
  Source: <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>.

### Leftover-carry semantics in one sentence

Base64 encodes 3 input bytes to 4 output characters. Every streaming
implementation therefore buffers 0-2 trailing *input* bytes on the encoding side
and up to 3 trailing *characters* on the decoding side until a full quantum or
the end of stream; the JDK expresses this as "flush all possible leftover bytes"
on `close()`.
Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.
(Assessment: derived from
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
<https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>,
<https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>.)

## 10. Interesting design decisions

1. **Factories instead of constructor flags.** `Base64` is "exclusively of static
   methods for obtaining encoders and decoders"; you *ask* for `getUrlEncoder()`
   rather than passing `urlSafe=true`. This makes the three variants discoverable
   and keeps `Encoder`/`Decoder` as small capability objects.
   Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>.
2. **Three output shapes for one operation**: allocate-and-return
   (`encode(byte[])`), caller-buffer (`encode(src, dst) -> int`), and String
   (`encodeToString`). The caller picks allocation policy without a separate API.
   Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.
3. **A separate `withoutPadding()` returning a *new* encoder** rather than a
   boolean parameter — a small, composable, configuration-by-copy pattern (the
   same idea Guava uses throughout).
   Sources: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
   <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.
4. **Padding optional to read, exact if present.** Decoders accept unpadded final
   units but reject a *wrong* number of `=`. This is a deliberately
   lenient-in-but-strict-when-ambiguous rule.
   Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>.
5. **Thread-safety as a documented property**, not an implementation accident:
   "Instances of Base64.Encoder class are safe for use by multiple concurrent
   threads."
   Source: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.
6. **Commons Codec's decoding *policy*.** The default `CodecPolicy.LENIENT`
   "compose[s] trailing bits into 8-bit bytes where possible. The remainder are
   discarded"; `STRICT` "will raise an IllegalArgumentException if trailing bits
   are not part of a valid encoding. Any unused bits from the final character must
   be zero." This makes canonical-vs-non-canonical input an explicit, typed choice.
   Source: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>.
7. **Guava's immutability contract.** "BaseEncoding instances are immutable.
   Invoking a configuration method has no effect on the receiving instance; you
   must store and use the new encoding instance it returns." The doc even shows
   the anti-pattern (`hex.lowerCase();` does nothing). This is the cleanest
   config-by-copy design among the four.
   Source: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.
8. **Netty's `ByteBuf` plus `ByteBufAllocator` parameter**: the caller can supply
   the allocator used for the result, which matters in a pooled-buffer server where
   allocation strategy is global.
   Source: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>.
9. **One abstract `BaseNCodec` across Base16/32/58/64** in Commons Codec,
   sharing block-size/pad/policy logic. (Guava does the same with the single
   `BaseEncoding` type across five encodings.)
   Sources: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>,
   <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>.
10. **Commons Codec's separation of "combined" and "strict" tests**: `isBase64`
    treats both standard and URL-safe characters as valid, while
    `isBase64Standard` / `isBase64Url` verify one alphabet; the same split exists
    for decoders (`decodeBase64` vs `decodeBase64Standard`/`decodeBase64UrlSafe`,
    since 1.21).
    Source: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>.

## 11. Decisions NOT to copy

1. **Checked exceptions in a pure codec** (`IOException` from the JDK stream
   wrapper, `DecoderException`/`EncoderException` in Commons Codec and Bouncy
   Castle). A malformed base64 string is a data error, not an I/O condition.
   Sources:
   <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>,
   <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>,
   <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>.
2. **The `Object`-based `Encoder`/`Decoder` bridge** (`encode(Object)`,
   `decode(Object)`, throwing `EncoderException`/`DecoderException` "if the
   parameter supplied is not of type byte[]"). This is type-erasure legacy; a
   typed language should not reproduce it.
   Source: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>.
3. **Silent leniency by default**, i.e. Commons Codec's `LENIENT` policy that
   discards unused trailing bits, and the MIME decoder's blanket "all line
   separators or other characters not found in the base64 alphabet table are
   ignored". Silent acceptance of malformed input hides corruption.
   Sources: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>,
   <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>.
4. **Deprecated constructor sprawl.** Commons Codec's `Base64` has five
   `@Deprecated` constructors `(boolean urlSafe)`, `(int lineLength)`,
   `(int,byte[])`, `(int,byte[],boolean)`, `(int,byte[],boolean,CodecPolicy)` kept
   for compatibility, all superseded by the builder. Do not design a public API
   with a deprecated parallel universe from day one.
   Source: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>.
5. **Boolean-flag APIs** such as Netty's `encode(ByteBuf, boolean breakLines)`
   and Commons Codec's `encodeBase64(byte[], boolean isChunked, boolean urlSafe,
   int maxResultSize)`. Positional booleans are unreadable at the call site; a
   named alphabet/padding type is better.
   Sources: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>,
   <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>.
6. **Historic alphabets without modern justification.** Netty's `ORDERED` dialect
   (RFC 1940) is documented as a "Special" dialect. Carrying it into a new library
   adds surface with no user.
   Source: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Dialect.html>.
7. **"Caller must size the destination buffer" without a size query.** The JDK's
   `encode(src, dst)` can only fail with `IllegalArgumentException` after the fact;
   Commons Codec at least offers `getEncodedLength(byte[])`. A new library should
   expose the size computation, not just the failure.
   Sources: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
   <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>.
8. **String-only results** (Guava `encode(...) -> String`) force a charset
   decision into a binary codec; the JDK at least documents `encodeToString` as
   ISO-8859-1. Keep bytes as the primary result type and make the string form
   explicit.
   Sources: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>,
   <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>.
9. **`encode(Object)`-style overload sets that mix byte arrays and boxed values**
   in the same method name space — a Java-8-era accommodation that a statically
   typed library should avoid. (Assessment: derived from
   <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>.)

## 12. Ideas fitting Mojo

Anchored on the Mojo stdlib `base64` package as documented in the `mojov1` buch
(page `mojov1/stdlib/base64`): four functions `b64encode` (three overloads,
including an in-place `mut result: String` overload), `b64decode`, `b16encode`,
`b16decode`; borrowed spans in, fresh `List[UInt8]` out; decoders raise on
malformed input. Sources: <https://mojolang.org/docs/std/base64/base64/>,
<https://mojolang.org/docs/std/base64/base64/b64encode/>,
<https://mojolang.org/docs/std/base64/base64/b64decode/>.

1. **Borrowed-span input plus fresh output is the right default, and Java's split
   confirms it.** Mojo already takes `StringSpan`/`Span[UInt8]` by immutable
   reference and returns a new `List[UInt8]` (buch, see above) — the same stance as
   JDK `encode(byte[])` returning a newly allocated array. Java's extra
   caller-buffer overload suggests adding a Mojo variant that writes into an
   `out`/`mut` buffer (the buch's in-place `b64encode(input_bytes: Span[UInt8],
   mut result: String)` is exactly this pattern) plus a size function so the caller
   can reserve capacity. Source for the overload:
   <https://mojolang.org/docs/std/base64/base64/b64encode/>.
2. **Errors as values via `raises`, not exceptions.** Java's checked/unchecked
   split and Commons Codec's `DecoderException` show the cost of exception
   taxonomies. Mojo's model — `raises` declares the effect, typed errors carry
   structured detail — fits a codec far better. The buch documents that Mojo
   errors are alternate return values and that a function is non-raising unless it
   declares `raises`, and that typed errors may be declared (`raises
   DecodeError`). Sources: `mojov1/errors/error-model`,
   `mojov1/keyword-conventions/raises`; also
   <https://mojolang.org/docs/manual/errors/>.
3. **A typed decode error.** Commons Codec's `STRICT` policy distinguishes
   "trailing bits not zero" from "impossible final character count", and Bouncy
   Castle names a `DecoderException`. A Mojo `struct` error with fields such as
   `kind` and `position` implements `Writable` and gives callers structured
   diagnostics; the buch shows custom typed errors carried in `raises
   YourErrorType` with field access in `except e:`. Source:
   `mojov1/errors/error-model`.
4. **Alphabet/padding as compile-time parameters, not runtime flags.** Java needs
   a factory call per variant and Commons Codec a builder; Mojo's value parameters
   (`[alphabet: Alphabet, padded: Bool]`) specialize at compile time, removing
   branches and giving one call syntax. The buch documents value parameters for
   exactly this "feature selection / mode switches" purpose. Sources:
   `mojov1/functions/parameters-and-generics`;
   <https://mojolang.org/docs/manual/generics/>.
5. **Explicit padding toggle as a separate function/parameter, mirroring
   `withoutPadding()`.** The JDK's config-by-copy `withoutPadding()` and Guava's
   `omitPadding()` both show users expect padding to be a deliberate choice; the
   buch notes Mojo's current four functions expose no alphabet/padding parameter,
   which is a gap this library could close. Sources:
   <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
   <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>,
   `mojov1/stdlib/base64`.
6. **Streaming via `wrap`, with leftover carry as documented behaviour.** The JDK
   makes "flush all possible leftover bytes" on close an explicit contract;
   Commons Codec and Bouncy Castle keep the partial-block state in a context
   object or a `Buffered*` helper. A Mojo streaming encoder/decoder struct can
   hold the 0-2 leftover input bytes / up-to-3 leftover characters and document
   the same flush contract; its `deinit`/`__del__` should flush — the buch
   documents ASAP destruction and explicit destructors.
   Sources:
   <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
   <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>,
   `mojov1/lifecycle/death`.
7. **No `Object`/type-erased bridge.** Mojo is statically typed; the buch's
   migration guidance warns that types are not optional and that argument types
   are mandatory. Skip Commons Codec's `encode(Object)`/`Decoder` interfaces
   entirely. Sources: `mojov1/interop/migration-from-python`;
   <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>.
8. **Base32 belongs in the library, since neither the JDK nor Mojo's stdlib has
   it.** The JDK has no Base32 class; Guava (`base32`, `base32Hex`), Commons Codec
   (`Base32`) and Bouncy Castle (`Base32`) all have one. A MojoAkku `base64`
   library that also covers base32/base16 (mirroring the stdlib's `b16*`
   functions) is well-motivated by this gap. Sources:
   <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/package-summary.html>,
   <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>,
   <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>,
   `mojov1/stdlib/base64`.
9. **Return a size/`getEncodedLength` function.** Commons Codec's
   `getEncodedLength(byte[])` and the buch's advice to "reserve capacity with the
   in-place encoder" both point at exposing an `encoded_length(n) -> Int` pure
   function for pre-sizing buffers. Sources:
   <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>,
   `mojov1/stdlib/base64`.
10. **Round-trip as the invariant, and immutability of encoders.** Java documents
    thread-safety for its encoder/decoder objects and Guava declares its encodings
    immutable; in Mojo a config-by-value encoder (a struct whose "configuring"
    methods return a new value) with a documented round-trip guarantee
    `decode(encode(x)) == x` matches both the Java conventions and the buch's
    "round-trip as the test" idiom. Sources:
    <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>,
    <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>,
    `mojov1/stdlib/base64`.

## Sources

JDK:
- `java.util.Base64` (Java 21): <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.html>
- `java.util.Base64.Encoder`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Encoder.html>
- `java.util.Base64.Decoder`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/Base64.Decoder.html>
- `java.util.HexFormat`: <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/HexFormat.html>
- `java.util` package summary (shows no Base32): <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/package-summary.html>
- JEP 320 (removal of `java.xml.bind.DatatypeConverter`): <https://openjdk.org/jeps/320>

Apache Commons Codec:
- Project home (version, date, Java requirement, license link): <https://commons.apache.org/proper/commons-codec/>
- `Base64`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base64.html>
- `BaseNCodec`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/BaseNCodec.html>
- `Base32`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base32.html>
- `Base16`: <https://commons.apache.org/proper/commons-codec/apidocs/org/apache/commons/codec/binary/Base16.html>

Guava:
- `BaseEncoding`: <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/io/BaseEncoding.html>
- License (Apache-2.0): <https://github.com/google/guava/blob/master/LICENSE>

Netty:
- `Base64`: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64.html>
- `Base64Dialect`: <https://netty.io/4.1/api/io/netty/handler/codec/base64/Base64Dialect.html>
- License (Apache-2.0): <https://github.com/netty/netty/blob/4.1/LICENSE.txt>

Bouncy Castle:
- `org.bouncycastle.util.encoders` package summary: <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/package-summary.html>
- `Base64`: <https://downloads.bouncycastle.org/java/docs/bcprov-jdk18on-javadoc/org/bouncycastle/util/encoders/Base64.html>
- License (MIT): <https://www.bouncycastle.org/about/license/>
- Documentation index (jar names): <https://www.bouncycastle.org/documentation/documentation-java/>

Mojo (`mojov1` buch):
- Page `mojov1/stdlib/base64` (stdlib package, four functions, signatures)
- Page `mojov1/errors/error-model`
- Page `mojov1/keyword-conventions/raises`
- Page `mojov1/functions/parameters-and-generics`
- Page `mojov1/interop/migration-from-python`
- Page `mojov1/lifecycle/death`
