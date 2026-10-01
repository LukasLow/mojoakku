# prim_endian research: Java

> Endian adaptation note (see `_dev/README.md`): Q5 answers value-returning vs.
> in-place conversion and ownership of input/output; Q7 answers which byte orders
> are represented and whether one abstraction covers them; Q9 answers how host
> native endianness is detected and reported. Q6/Q8/Q10–Q12 are unchanged.
> Section headings follow `NewLibPhase1Research.md` verbatim.

## 1. Standard library support

The Java standard library handles byte order in two cooperating areas: the NIO
buffer layer (`java.nio`) and per-integer static byte-swap methods (`java.lang`).

- `java.nio.ByteOrder` is a "typesafe enumeration for byte orders" with exactly
  two constants, `LITTLE_ENDIAN` and `BIG_ENDIAN`
  (`ByteOrder.java:39-49`, `https://raw.githubusercontent.com/openjdk/jdk/master/src/java.base/share/classes/java/nio/ByteOrder.java`).
- `ByteOrder.nativeOrder()` "Retrieves the native byte order of the underlying
  platform" and returns one of the two constants; it is resolved once and cached
  in a static field via `Unsafe.getUnsafe().isBigEndian()`
  (`ByteOrder.java:55-72`).
- `java.nio.ByteBuffer` carries a *current* byte order. It defines six categories
  of operations, including "get and put methods that read and write values of
  other primitive types, translating them to and from sequences of bytes in a
  particular byte order" (`ByteBuffer` JDK 21 class description,
  `https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/ByteBuffer.html`).
- Per-integer swap: `Short.reverseBytes(short)` (since 1.5, `@IntrinsicCandidate`,
  implemented as `(short)(((i & 0xFF00) >> 8) | (i << 8))`),
  `Integer.reverseBytes(int)` and `Long.reverseBytes(long)` (both since 1.5)
  (`Short.java`, `https://raw.githubusercontent.com/openjdk/jdk/master/src/java.base/share/classes/java/lang/Short.java`;
  `Integer.reverseBytes` JDK 21,
  `https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Integer.html#reverseBytes(int)`;
  `Long.reverseBytes` SE 8,
  `https://docs.oracle.com/javase/8/docs/api/java/lang/Long.html#reverseBytes(long)`).
  These are value-returning swaps; there is no `Byte.reverseBytes` (1 byte).
- Byte-stream layer: `DataInput`/`DataOutput` (and `DataInputStream`/
  `DataOutputStream`, `RandomAccessFile`) read/write all multibyte primitives in
  **big-endian** order; e.g. `readShort()` is documented as
  `(short)((a << 8) | (b & 0xff))` and `readInt()` as
  `(((a & 0xff) << 24) | ((b & 0xff) << 16) | ((c & 0xff) << 8) | (d & 0xff))`
  (`DataInput` JDK 21,
  `https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/io/DataInput.html`).
- JNI: the Java Native Interface itself exposes **no** byte-order conversion
  function. `htonl`/`htons`/`ntohl`/`ntohs` come from the host C library
  (`<arpa/inet.h>`), not from JNI
  (`https://pubs.opengroup.org/onlinepubs/9699919799/functions/htonl.html`).
  (Assessment: derived from the JNI types chapter, which lists only the primitive
  mappings `jchar`/`jshort`/`jint`/`jlong` and no conversion entry points —
  `https://docs.oracle.com/en/java/javase/21/docs/specs/jni/types.html`.)

## 2. Relevant community libraries

- **Apache Commons IO — `org.apache.commons.io.EndianUtils`** (Apache-2.0):
  "read and write primitive numeric types … encoded in little-endian", plus
  `swapShort`/`swapInteger`/`swapLong`/`swapFloat`/`swapDouble`. It exists
  precisely because "Most methods and classes throughout Java … assume data is
  laid out in big-endian order"
  (`https://commons.apache.org/proper/commons-io/apidocs/org/apache/commons/io/EndianUtils.html`).
- **Guava — `com.google.common.primitives.Ints`** (Apache-2.0): `toByteArray(int)`
  returns a big-endian 4-element array, `fromByteArray(byte[])` reads big-endian;
  the docs recommend `ByteBuffer` instead ("Arguably, it's preferable to use
  ByteBuffer") (`https://guava.dev/releases/19.0/api/docs/com/google/common/primitives/Ints.html`).
  Guava also carries an internal `LittleEndianByteArray`
  (`https://github.com/google/guava/blob/master/android/guava/src/com/google/common/hash/LittleEndianByteArray.java`).
- **Netty — `io.netty.buffer.ByteBuf`** (Apache-2.0): adds explicit
  little-endian accessors `getShortLE`/`getIntLE`/`getLongLE`, `read*LE`,
  `write*LE`, `set*LE` alongside the big-endian defaults
  (`https://netty.io/4.2/api/io/netty/buffer/ByteBuf.html`).

## 3. Exposed APIs

`java.nio.ByteOrder`
- `ByteOrder.BIG_ENDIAN`, `ByteOrder.LITTLE_ENDIAN` (`ByteOrder.java:39-49`).
- `static ByteOrder nativeOrder()` (`ByteOrder.java:71`).
- `String toString()` returns `"BIG_ENDIAN"`/`"LITTLE_ENDIAN"` (JDK 21 `ByteOrder`).

`java.nio.ByteBuffer`
- `final ByteOrder order()` — retrieve the buffer's byte order.
- `final ByteBuffer order(ByteOrder bo)` — modify it; both are chainable
  (JDK 21 `ByteBuffer` method summary).
- Type accessors: `getShort/getInt/getLong/getFloat/getDouble/getChar` (+ absolute
  `(int index)` overloads) and `putShort/putInt/putLong/putFloat/putDouble/putChar`
  (+ absolute overloads), all interpreted with the buffer's current order
  (JDK 21 `ByteBuffer`).
- `static ByteBuffer allocate(int)`, `allocateDirect(int)`, `wrap(byte[])` — newly
  created buffers are always `BIG_ENDIAN` (JDK 21 `ByteBuffer`).
- `slice()`, `slice(int,int)`, `duplicate()`, `asReadOnlyBuffer()` — all return
  buffers whose byte order is `BIG_ENDIAN`, **not** the source order (JDK 21
  `ByteBuffer`).

`java.lang` integer swaps
- `static short Short.reverseBytes(short)`, `static int Integer.reverseBytes(int)`,
  `static long Long.reverseBytes(long)` (since 1.5) (`Short.java`;
  JDK 21 `Integer`; SE 8 `Long`).

`java.io`
- `DataInput.readShort/readInt/readLong/readFloat/readDouble/readChar/readUnsignedShort`
  and the matching `DataOutput.write*` methods — always big-endian (JDK 21
  `DataInput`).

JNI native side
- POSIX `uint32_t htonl(uint32_t)`, `uint16_t htons(uint16_t)`,
  `ntohl`, `ntohs` from `<arpa/inet.h>`
  (`https://pubs.opengroup.org/onlinepubs/9699919799/functions/htonl.html`).

Netty `ByteBuf` (community, for comparison)
- `getShort(int)/getShortLE(int)`, `getInt/getIntLE`, `getLong/getLongLE`,
  `getMedium/getMediumLE`, `read*`/`write*`/`set*` twins, plus unsigned variants
  `getUnsignedShort/LE`, `getUnsignedInt/LE`
  (`https://netty.io/4.2/api/io/netty/buffer/ByteBuf.html`).
- `io.netty.buffer.ByteBufUtil.swapShort/swapMedium/swapInt/swapLong`; the 16/32/64
  ones delegate to `Short.reverseBytes`, `Integer.reverseBytes`,
  `Long.reverseBytes` (Netty `ByteBufUtil.java`,
  `https://raw.githubusercontent.com/netty/netty/4.2/buffer/src/main/java/io/netty/buffer/ByteBufUtil.java`).

## 4. Error representation

Byte-order conversion in Java is **exception-free** in the normal case:

- `Short/Integer/Long.reverseBytes` does not declare any `throws` clause; it is
  total for its fixed-width input and cannot fail on a valid argument (JDK
  javadoc, JDK 21 `Integer`, `Short.java`).
- Buffers report misuse through unchecked runtime exceptions rather than error
  codes: `BufferUnderflowException`/`BufferOverflowException` on relative
  get/put past the limit, `IndexOutOfBoundsException` on bad absolute index,
  `ReadOnlyBufferException` on writes to a read-only buffer (JDK 21 `ByteBuffer`).
- `ByteOrder.valueOf(String)` is the standard enum parse and throws
  `IllegalArgumentException` on an unknown name (Assessment: derived from the
  general `Enum.valueOf` contract and the fact that `ByteOrder` is an `enum`,
  `ByteOrder.java:33`).
- The I/O layer additionally uses checked `IOException`/`EOFException`:
  "if end of file is reached before the desired number of bytes has been read,
  an `EOFException` (which is a kind of `IOException`) is thrown"
  (JDK 21 `DataInput`).
- `EndianUtils` uses `IllegalArgumentException` when the backing array is too
  short and checked `IOException` on the stream overloads
  (`https://commons.apache.org/proper/commons-io/apidocs/org/apache/commons/io/EndianUtils.html`).

There is **no** sentinel value and **no** `Result`/`Either` type for conversion
failures; failures are only length/bounds/stream problems, never a
"wrong endianness" error (Assessment: derived from the API surface above — the
byte order is an explicit parameter, so a wrong order is a silent data bug, not
an error).

## 5. Ownership semantics

Endian adaptation (was: ownership of socket + handle).

- **Primitive swaps are value-returning and copy the value**: Java passes
  primitives by value, so `Integer.reverseBytes(int)` returns "the value obtained
  by reversing the order of the bytes" and cannot mutate the caller's value
  (JDK 21 `Integer`; `Short.java`). There is no in-place primitive swap.
- **`ByteBuffer` conversions are in-place with respect to the buffer, but the
  cursor state is owned by the buffer**: relative `getShort()`/`putShort()`
  advance the buffer's `position` and mutate its backing content; absolute
  `getShort(int index)`/`putShort(int index, ...)` leave the position unchanged
  (JDK 21 `ByteBuffer`).
- **Backing-array ownership is shared**: `wrap(byte[])` "will be backed by the
  given byte array; that is, modifications to the buffer will cause the array to
  be modified and vice versa" (JDK 21 `ByteBuffer`). `slice()`/`duplicate()`
  share content ("Changes to this buffer's content will be visible in the new
  buffer, and vice versa") but have independent position/limit/mark (JDK 21
  `ByteBuffer`).
- **`EndianUtils` writes into caller-owned storage**: `readSwapped*` return a
  value and take `byte[]`/`InputStream` as borrowed; `writeSwapped*(byte[] data,
  int offset, ...)` mutates the caller's array, while the `OutputStream`
  overloads write to a borrowed stream
  (`https://commons.apache.org/proper/commons-io/apidocs/org/apache/commons/io/EndianUtils.html`).
- **Netty derived buffers share the region**: `slice()`/`duplicate()` "shares the
  whole region, indexes, and marks"; `retainedSlice()`/`retainedDuplicate()`
  additionally bump the reference count, so ownership is explicit and manual via
  `retain()`/`release()` (`https://netty.io/4.2/api/io/netty/buffer/ByteBuf.html`).

## 6. Blocking / non-blocking

Byte-order conversion itself is a pure, CPU-only computation and is **neither
blocking nor non-blocking**; the question only becomes meaningful for the
adjacent I/O operations.

- `ByteBuffer.getShort()`/`putShort()` on a heap or direct buffer never block on
  external events (Assessment: derived from the `ByteBuffer` API, which is a
  memory abstraction; the documented throws are bounds/read-only exceptions, not
  timeouts — JDK 21 `ByteBuffer`).
- `DataInput.readShort()` etc. are **blocking stream reads** and "blocks until"
  the requested bytes are available or EOF/error occurs (`readFully` docs,
  JDK 21 `DataInput`).
- Mapped/direct buffers interact with paged memory and can fault, but that is
  memory behavior, not an async model (Assessment: derived from the `ByteBuffer`
  direct/non-direct description — JDK 21 `ByteBuffer`).
- Java's async concurrency (threads, NIO channels, `java.util.concurrent`) lives
  above these APIs; endianness conversion carries no async model of its own
  (Assessment: derived from the fact that none of the conversion APIs above
  expose a `Future`/callback/timeout parameter).

## 7. IPv4 / IPv6

Endian adaptation (was: IPv4/IPv6): which byte orders are represented and whether
one abstraction covers all of them.

- Exactly two concrete orders exist in the JDK: `BIG_ENDIAN` and `LITTLE_ENDIAN`
  (`ByteOrder.java:39-49`).
- "Network byte order" has **no separate constant**; it is big-endian. The JDK's
  own `Uses` pages state "`ByteOrder.BIG_ENDIAN` indicates network byte order and
  `ByteOrder.LITTLE_ENDIAN` indicates the reverse order"
  (`https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/class-use/ByteOrder.html`).
- "Native" is not a third value; `nativeOrder()` resolves at runtime to one of the
  two constants (`ByteOrder.java:71`).
- A single abstraction therefore covers big, little and native: `ByteOrder` plus
  a buffer's current order. There is no "network order" type to reconcile because
  network order *is* `BIG_ENDIAN`.
- Defaults are consistently big-endian: new `ByteBuffer`s and `DataInput`/
  `DataOutput` are big-endian (JDK 21 `ByteBuffer`, JDK 21 `DataInput`).
- `EndianUtils` deliberately covers only little-endian and provides
  `swap*` to flip big↔little (`.../EndianUtils.html`).
- Netty keeps big-endian as the default `getInt`/`setInt` order and adds explicit
  `*LE` accessors rather than a separate order object
  (`https://netty.io/4.2/api/io/netty/buffer/ByteBuf.html`).

## 8. Timeouts

Not applicable to endianness conversion; there is no timeout or cancellation
parameter on any conversion API (`ByteOrder`, `ByteBuffer.getShort/putShort`,
`Short/Integer/Long.reverseBytes`, `EndianUtils` — see sources in §3/§4).
I/O-layer operations that may be paired with conversion block until data or EOF
and rely on the surrounding stream/channel for any timeout
(Assessment: derived from JDK 21 `DataInput.readFully`, which documents blocking
on data/EOF/error and no timeout parameter). Cancellation of a conversion is
meaningless because the operation is a finite in-memory transformation; any
thread interruption would come from the caller's execution context, not the API
(Assessment: derived from the pure-computation nature of the APIs above).

## 9. TLS

Endian adaptation (was: TLS): how host native endianness is detected and reported.

- `ByteOrder.nativeOrder()` is the JDK's runtime query. It is computed once at
  class initialization via `Unsafe.getUnsafe().isBigEndian()` and stored in the
  static `NATIVE_ORDER` field, then returned on every call
  (`ByteOrder.java:55-72`).
- The detection is therefore a **runtime query backed by a JVM intrinsic**, not a
  compile-time constant visible to Java source.
- Importantly, the *default* buffer order is **not** native: new `ByteBuffer`s are
  always `BIG_ENDIAN` regardless of the platform (JDK 21 `ByteBuffer`).
- The JVM's own on-disk/on-wire encodings are fixed big-endian irrespective of
  host: "The bytes of multibyte characters are stored in the `class` file in
  big-endian (high byte first) order" (JNI types chapter,
  `https://docs.oracle.com/en/java/javase/21/docs/specs/jni/types.html`).
- From native code there is no JNI call for this; a JNI library must detect the
  host itself (e.g. via `htonl`/a byte-probe) and may return the result as a
  `jlong`/`jint`, because a returned Java value is order-independent
  (Assessment: derived from the absence of a native-order JNI entry point in the
  JNI types chapter; POSIX `htonl` is the host C facility —
  `https://pubs.opengroup.org/onlinepubs/9699919799/functions/htonl.html`).
- Guava's internal `LittleEndianByteArray` similarly chooses an implementation
  based on the platform's native order at class-load time
  (`https://github.com/google/guava/blob/master/android/guava/src/com/google/common/hash/LittleEndianByteArray.java`).

## 10. Interesting design decisions

- **Byte order is mutable state on the buffer, not an argument.** `ByteBuffer`
  keeps a per-buffer order changed via `order(ByteOrder)`, and all subsequent
  relative/absolute `get*`/`put*` calls obey it (JDK 21 `ByteBuffer`). This makes
  a stream of mixed-endian reads ergonomic but hides the order inside object
  state.
- **Default is big-endian, i.e. network order.** New buffers are always
  `BIG_ENDIAN` (JDK 21 `ByteBuffer`), and `DataInput` is big-endian (JDK 21
  `DataInput`). The safe, protocol-friendly choice is the default; little-endian
  is opt-in.
- **`ByteOrder` is a two-value typesafe enum, and native is a runtime alias.**
  `nativeOrder()` collapses the platform question to one of the two constants
  (`ByteOrder.java:39-72`), so downstream code never branches on a third value.
- **Value-returning primitive swaps** (`Short/Integer/Long.reverseBytes`) are pure
  functions with no buffer coupling and are JVM-intrinsic candidates
  (`Short.java`, JDK 21 `Integer`). They compose well with any storage model.
- **Explicit little-endian accessors instead of a mutable order (Netty).** Netty
  moved away from `order(ByteOrder)` — it is `@Deprecated` in 4.2 in favour of
  `getShortLE`/`getIntLE`/… — to "avoid any confusion caused by keeping byte order
  as a state variable"
  (`https://netty.io/4.2/api/io/netty/buffer/ByteBuf.html`,
  `https://stackoverflow.com/questions/19850269/setting-bytebuf-endianness-in-netty4`).
  (Assessment: derived from the deprecation on the API page plus the
  `SwappedByteBuf` wrapper's `@deprecated` javadoc,
  `https://raw.githubusercontent.com/netty/netty/4.2/buffer/src/main/java/io/netty/buffer/SwappedByteBuf.java`.)
- **`duplicate()`/`slice()` reset the order to `BIG_ENDIAN`.** This is called out
  by third-party libraries as "error-prone": "`ByteBuffer.slice()` returns a
  buffer that is always BIG_ENDIAN"
  (`https://docs.stardog.com/javadoc/snarl/com/complexible/common/nio/ByteBuffers.html`,
  secondary source; the same reset is stated by Netty's own `SwappedByteBuf`
  wrapper, a primary source; Javamex, secondary:
  `https://www.javamex.com/tutorials/io/nio_byte_order.shtml`).
- **Unsigned widths are emulated.** Netty exposes `getUnsignedShortLE`/
  `getUnsignedIntLE`, and `EndianUtils` adds `readSwappedUnsignedShort`/
  `readSwappedUnsignedInteger`, because Java lacks unsigned integral types and
  widens to the next signed type
  (`https://netty.io/4.2/api/io/netty/buffer/ByteBuf.html`;
  `https://commons.apache.org/proper/commons-io/apidocs/org/apache/commons/io/EndianUtils.html`).
- **A dedicated swap for the non-standard 24-bit width.** Netty's
  `ByteBufUtil.swapMedium(int)` hand-rolls a 24-bit reversal
  (`value << 16 & 0xff0000 | value & 0xff00 | value >>> 16 & 0xff`) because no JDK
  method covers 3-byte integers (Netty `ByteBufUtil.java`).

## 11. Decisions NOT to copy

- **Do not carry byte order as hidden mutable state on a buffer.** The
  `ByteBuffer.order()` model forces every consumer to remember a hidden field;
  Netty deprecated exactly this (`https://netty.io/4.2/api/io/netty/buffer/ByteBuf.html`,
  primary) and the `slice()`/`duplicate()` reset to `BIG_ENDIAN` is a documented
  footgun (`https://www.javamex.com/tutorials/io/nio_byte_order.shtml`,
  secondary). An explicit order argument/parameter is easier to reason about.
- **Do not silently reset order on sub-views.** Returning `BIG_ENDIAN` from
  `slice()`/`duplicate()` is surprising and was flagged as "error-prone" by
  third parties (`https://docs.stardog.com/javadoc/snarl/com/complexible/common/nio/ByteBuffers.html`).
- **Do not couple conversion to I/O and checked exceptions.** `DataInput`'s
  `IOException`/`EOFException` (`https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/io/DataInput.html`)
  is stream machinery, irrelevant to a pure swap; a conversion primitive should
  not throw for byte-order reasons (§4 shows it never does).
- **Do not model "native" as a third concrete order.** Resolving native to one
  of two values (`ByteOrder.java:71`) is the clean design; a three-valued type
  invites dead branches.
- **Do not depend on `Unsafe`/intrinsics from library code.** The JDK may use
  `Unsafe.isBigEndian()` internally (`ByteOrder.java:55-60`), but a portable
  library should detect host order through a stable, documented mechanism rather
  than a private JVM API.
- **Do not emulate unsigned widths with a widening-to-signed API surface unless
  needed.** Netty's and Commons IO's extra unsigned variants exist to patch
  Java's missing unsigned types; in a language with explicit unsigned types this
  duplication is unnecessary (Assessment: derived from the unsigned-variant
  listings in §10).
- **Do not assume only power-of-two widths are needed.** Java has no standard
  24-bit swap; Netty had to hand-roll one (Netty `ByteBufUtil.java`). Decide
  explicitly whether non-power-of-two widths are in scope.

## 12. Ideas fitting Mojo

These are *candidate* directions; Mojo-specific feasibility must be confirmed in
the `mojov1` buch, not inferred from Java.

- **Pure value-returning swaps as the core API.** Java's
  `reverseBytes` functions are the most composable part of its design — no
  buffer, no hidden state, no exceptions (`Short.java`, JDK 21 `Integer`). Mojo's
  `var`/value semantics and `borrowed` parameters map naturally onto a
  `fn reverse_bytes(value: Int32) -> Int32` style (Assessment: derived from the
  value-returning, stateless nature of these methods).
- **Byte order as an explicit parameter/enum.** A two-valued order type matching
  `ByteOrder.BIG_ENDIAN`/`LITTLE_ENDIAN`, with native resolved at the boundary,
  is a clean contract (`ByteOrder.java:39-71`). In Mojo a comptime `Endian`
  parameter would let callers pick the order at compile time (Assessment:
  derived from Java's enum design plus Mojo's comptime-parameter model — needs
  buch confirmation).
- **Compile-time native endianness where the target is known.** Java can only
  query native order at runtime via an intrinsic (`ByteOrder.java:55-72`); a
  compile-time constant for known targets is strictly better and avoids a runtime
  lookup (Assessment: derived from the contrast with Java's runtime-only
  detection; Mojo target-query facilities to be checked in `mojov1`).
- **No `raises` for a pure swap.** Java's conversion never fails for
  byte-order reasons (§4); a Mojo API should likewise not declare `raises` unless
  it also takes a bounded buffer slice (bounds are then the only failure source).
- **Buffered/bulk helpers separate from the scalar swap.** Java separates the
  scalar swap (`reverseBytes`) from the buffer translation (`ByteBuffer`) and the
  stream translation (`DataInput`). Mirroring that three-layer split keeps the
  scalar primitive testable in isolation (Assessment: derived from the Java
  layering in §1/§3).
- **Explicit LE/BE accessor naming over mutable order.** Netty's `getIntLE`
  naming (`https://netty.io/4.2/api/io/netty/buffer/ByteBuf.html`) is a better fit
  for predictable, low-vision-friendly MojoAkku naming than a hidden mutable
  order field.
- **Decide 24-bit/arbitrary-width support deliberately.** Java lacks it; Netty
  hand-rolled it (Netty `ByteBufUtil.java`). If MojoAkku's `prim_endian` claims
  width-generic swapping, it should say so and test 3-byte widths
  (Assessment: derived from the 24-bit gap in Java).

## Sources

- OpenJDK `ByteOrder.java` (master):
  https://raw.githubusercontent.com/openjdk/jdk/master/src/java.base/share/classes/java/nio/ByteOrder.java
- `ByteOrder` JDK 21:
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/ByteOrder.html
- `ByteOrder` JDK 25:
  https://docs.oracle.com/en/java/javase/25/docs/api/java.base/java/nio/ByteOrder.html
- `ByteBuffer` JDK 21:
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/ByteBuffer.html
- `Uses of Class java.nio.ByteOrder` JDK 21:
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/class-use/ByteOrder.html
- OpenJDK `Short.java` (master):
  https://raw.githubusercontent.com/openjdk/jdk/master/src/java.base/share/classes/java/lang/Short.java
- `Short` JDK 21:
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Short.html
- `Integer.reverseBytes` JDK 21:
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Integer.html#reverseBytes(int)
- `Long.reverseBytes` SE 8:
  https://docs.oracle.com/javase/8/docs/api/java/lang/Long.html#reverseBytes(long)
- Java `DataInput` JDK 21:
  https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/io/DataInput.html
- JNI types and data structures (JDK 21):
  https://docs.oracle.com/en/java/javase/21/docs/specs/jni/types.html
- POSIX `htonl`/`htons`/`ntohl`/`ntohs`:
  https://pubs.opengroup.org/onlinepubs/9699919799/functions/htonl.html
- Apache Commons IO `EndianUtils`:
  https://commons.apache.org/proper/commons-io/apidocs/org/apache/commons/io/EndianUtils.html
- Guava `Ints`:
  https://guava.dev/releases/19.0/api/docs/com/google/common/primitives/Ints.html
- Guava `LittleEndianByteArray.java`:
  https://github.com/google/guava/blob/master/android/guava/src/com/google/common/hash/LittleEndianByteArray.java
- Netty `ByteBuf` 4.2 API:
  https://netty.io/4.2/api/io/netty/buffer/ByteBuf.html
- Netty `ByteBufUtil.java` (4.2):
  https://raw.githubusercontent.com/netty/netty/4.2/buffer/src/main/java/io/netty/buffer/ByteBufUtil.java
- Netty `SwappedByteBuf.java` (4.2):
  https://raw.githubusercontent.com/netty/netty/4.2/buffer/src/main/java/io/netty/buffer/SwappedByteBuf.java
- Netty endianness discussion (Stack Overflow):
  https://stackoverflow.com/questions/19850269/setting-bytebuf-endianness-in-netty4
- Javamex, "How to set the byte order of a NIO buffer" (secondary source):
  https://www.javamex.com/tutorials/io/nio_byte_order.shtml
- Stardog `ByteBuffers` (slice-order gotcha; secondary source):
  https://docs.stardog.com/javadoc/snarl/com/complexible/common/nio/ByteBuffers.html
