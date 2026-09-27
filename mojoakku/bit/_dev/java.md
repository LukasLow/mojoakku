# bit research: Java

Reference: JDK 21 (Java SE 21). Java has no unsigned primitive type; `int` is
32-bit and `long` is 64-bit two's-complement, and `java.math.BigInteger` is the
arbitrary-precision escape hatch. The bit story splits cleanly into three layers:
scalar helpers on the wrapper classes, one growable container
(`java.util.BitSet`), and **no** standard-library bit-level stream I/O.

## 1. Standard library support

Three disjoint places in the JDK, plus one absence:

- **Scalar primitives** live as `static` methods on the boxed primitive classes
  `java.lang.Integer` and `java.lang.Long` (module `java.base`, package
  `java.lang`). The class javadoc explicitly names Hacker's Delight as the source
  of these "bit twiddling" methods. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Integer.html>
- **The container** is `java.util.BitSet` (module `java.base`, package
  `java.util`), "a vector of bits that grows as needed", present since Java 1.0.
  Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/BitSet.html>
- **Byte order for I/O** is `java.nio.ByteOrder`, applied through
  `java.nio.ByteBuffer`. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/ByteBuffer.html>
- **No bit-level stream reader/writer exists in the JDK.** `java.io` and
  `java.nio` read whole bytes/values; there is no `BitInputStream`/`BitReader`
  in the standard library. (Assessment: derived from the Java SE 21 API index —
  the only bit-oriented stdlib type is `java.util.BitSet`; no class reading
  sub-byte units exists. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/index-files/index-1.html>)

`java.util.BitSet` is **not** the same as `java.util.EnumSet` or `Set<Integer>`;
it is the canonical packed, indexable bit vector.

## 2. Relevant community libraries

- **Apache Commons Compress** — `org.apache.commons.compress.utils.BitInputStream`
  (reads bits from an `InputStream`, since 1.10, not thread-safe). Maintainer:
  Apache Software Foundation; license Apache-2.0. This is the de-facto bit-level
  *reader* in the Java ecosystem, used internally by its BZip2/DEFLATE decoders.
  Source:
  <https://commons.apache.org/proper/commons-compress/apidocs/org/apache/commons/compress/utils/BitInputStream.html>
  Note: there is **no public `BitOutputStream`** in the current package listing —
  writing is done ad hoc. (Assessment: derived from the package summary, which
  lists `BitInputStream` but no `BitOutputStream`. Source:
  <https://commons.apache.org/proper/commons-compress/apidocs/org/apache/commons/compress/utils/package-summary.html>)
- **tomgibara/bits** — a dedicated bit-level library: `BitStore` (interface),
  `BitVector`, `BitReader`, `BitWriter`, `GrowableBits`, `BitStreamException`,
  `EndOfBitStreamException`, plus adapters to `byte[]`, `int[]`, `long`,
  `BigInteger`, `BitSet`, `ByteBuffer`, `InputStream`, `CharSequence`. Author:
  Tom Gibara; license Apache-2.0; Maven `com.tomgibara.bits:bits:2.1.0`; ~30
  stars; last release 2016 (low maintenance). Source:
  <https://github.com/tomgibara/bits>
- **RoaringBitmap** — compressed bitset (`RoaringBitmap`, `ImmutableRoaringBitmap`,
  `MutableRoaringBitmap`, `Roaring64NavigableMap`, `Roaring64Bitmap`). Maintainer:
  the RoaringBitmap authors (Lemire et al.); license Apache-2.0; ~3.9k stars;
  used by Spark, Hive, Druid, Pinot, Flink. Sources:
  <https://github.com/RoaringBitmap/RoaringBitmap>
- Small ad-hoc readers/writers are widespread as gists/course files (e.g.
  <https://github.com/herbix/bitstream>, CSE143 `BitInputStream`), not libraries.
  Source: search result
  <https://gist.github.com/camertron/927115e5a2f43f27f4eb5801d87d2964>

## 3. Exposed APIs

**`java.util.BitSet`** — instance methods (source:
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/BitSet.html>):

- Single bit: `set(int)`, `set(int,boolean)`, `clear(int)`, `clear()`,
  `flip(int)`, `get(int) : boolean`.
- Range (half-open `[fromIndex, toIndex)`): `set(int,int)`, `set(int,int,boolean)`,
  `clear(int,int)`, `flip(int,int)`, `get(int,int) : BitSet`.
- Bulk logical (all **mutating, in place, `void`**): `and(BitSet)`, `or(BitSet)`,
  `xor(BitSet)`, `andNot(BitSet)`. No non-mutating variants; copy first via
  `clone()`.
- Query: `cardinality()`, `isEmpty()`, `intersects(BitSet)`, `length()` (logical
  size = highest set bit + 1), `size()` (physical capacity in bits),
  `equals(Object)`, `hashCode()`, `toString()` (`{2, 4, 10}` set notation).
- Iteration: `nextSetBit(int)` / `nextClearBit(int)` (forward), `previousSetBit(int)`
  / `previousClearBit(int)` (backward), `stream() : IntStream` (since 1.8).
- Serialization/conversion: `toByteArray()`, `toLongArray()`, `clone()`,
  `valueOf(byte[])`, `valueOf(long[])`, `valueOf(ByteBuffer)`,
  `valueOf(LongBuffer)`.

**`java.lang.Integer` / `java.lang.Long`** static helpers (source:
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Long.html>):

- `bitCount(i)` (popcount), `numberOfLeadingZeros(i)` (clz),
  `numberOfTrailingZeros(i)` (ctz), `highestOneBit(i)`, `lowestOneBit(i)`,
  `reverse(i)` (bit reversal), `reverseBytes(i)`, `rotateLeft(i,distance)`,
  `rotateRight(i,distance)`, `signum(i)`, `toBinaryString(i)`/`toHexString(i)`,
  `parseUnsignedInt`/`parseUnsignedLong`,
  `divideUnsigned`/`remainderUnsigned`/`compareUnsigned`.
- Since Java 19: `compress(i, mask)` and `expand(i, mask)` — mask-driven bit
  pack/unpack, mapped to x86 `PEXT`/`PDEP`. Source (CSR, Fix Version 19):
  <https://bugs.openjdk.org/browse/JDK-8283893>

**`java.nio.ByteBuffer`** — `order()` / `order(ByteOrder)` (default
`BIG_ENDIAN`), `getInt`/`putInt`/`getLong`/`putLong`/`getShort`, `slice()`,
`asIntBuffer()`/`asLongBuffer()`. Source:
<https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/ByteBuffer.html>

**`org.apache.commons.compress.utils.BitInputStream`** — constructor
`BitInputStream(InputStream in, ByteOrder byteOrder)`; `readBits(int count) :
long` (1..63), `readBit() : int` (0/1 or -1), `alignWithByteBoundary()`,
`bitsAvailable()`, `bitsCached()`, `clearBitCache()`, `getBytesRead()`,
`close()`. Sources:
<https://commons.apache.org/proper/commons-compress/apidocs/org/apache/commons/compress/utils/BitInputStream.html>,
source file
<https://raw.githubusercontent.com/apache/commons-compress/master/src/main/java/org/apache/commons/compress/utils/BitInputStream.java>

**tomgibara/bits** public surface: `BitStore` (size, getBit/setBit, range,
flipped/reversed views, `contains()/excludes()`, `xor().withLong(...)`,
`toBigInteger/toByteArray/toBitSet/toString`, `immutableCopy/mutableCopy`),
`BitReader`/`BitWriter` (`readBit`/`writeBit`, `openReader/openWriter`),
`GrowableBits`. Source: <https://github.com/tomgibara/bits>

**RoaringBitmap**: `add`, `contains`, `or`/`and`/`xor` (in-place and static),
`select(rank)`, `rank(value)`, `getLongCardinality`, iterator, `runOptimize()`,
`serialize`/`deserialize`/`validate`, `RangeBitmap`, `range()`. Source:
<https://github.com/RoaringBitmap/RoaringBitmap>

## 4. Error representation

Java uses **exceptions + sentinel values**, never error codes.

- `BitSet.set/clear/flip/get(int)` and `nextXxxBit` throw
  `IndexOutOfBoundsException` if the index is negative; range methods
  (`set(int,int)` etc.) throw it if `fromIndex < 0`, `toIndex < 0`, or
  `fromIndex > toIndex`; the `BitSet(int nbits)` constructor throws
  `NegativeArraySizeException` for a negative initial size. Source:
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/BitSet.html>
- Sentinel `-1` is overloaded as "none found": `nextSetBit`, `nextClearBit`,
  `previousSetBit`, `previousClearBit` all return `-1`. Source: same.
- `BitInputStream.readBits` returns `-1` for premature end-of-stream and throws
  `IOException` for I/O errors and for `count < 0 || count > 63`. Source:
  BitInputStream source file (link above).
- tomgibara/bits uses an **unchecked** `BitStreamException`, with
  `EndOfBitStreamException` as a subtype distinguishing end-of-stream from I/O
  failure. Source: <https://github.com/tomgibara/bits>

(Assessment: derived from the above — Java has no `Result`/`Either`; callers
either catch exceptions or check the `-1` sentinel, and the two styles coexist
even inside the same class `BitSet`.)

## 5. Ownership semantics

- `BitSet` is a heap object holding a private `long[] words`; the field is
  `private long[]` and `wordsInUse`/`sizeIsSticky` are private. Lifetime is
  managed entirely by the GC; there is **no explicit free/dispose**. Source:
  OpenJDK `BitSet.java`, declarations of `private long[] words;` and
  `private transient int wordsInUse`.
- `clone()` produces a new `BitSet` and **deep-copies** the word array
  (`result.words = words.clone()`). Source: OpenJDK `BitSet.clone()`.
- `valueOf(ByteBuffer)`/`valueOf(LongBuffer)` document explicitly: "The byte
  buffer is not modified by this method, and no reference to the buffer is
  retained by the bit set." The BitSet therefore owns an independent copy.
  Source: `BitSet.valueOf(ByteBuffer)` javadoc.
- `toByteArray()`/`toLongArray()` return **fresh** arrays ("a new byte array",
  "a new long array"), so the caller owns the result. Source: BitSet javadoc.
- The logical `equals` ignores physical `size()`: two BitSets are equal if they
  have the same set bits, regardless of capacity. Source: `BitSet.equals`.
- RoaringBitmap splits ownership into mutable vs immutable views: a
  `MutableRoaringBitmap` can be cast to `ImmutableRoaringBitmap` in constant time
  and the immutable form can be backed by a `ByteBuffer` "outside of the Java
  heap". Source: <https://github.com/RoaringBitmap/RoaringBitmap>

(Assessment: derived — Java never expresses ownership in the type system, so
"ownership" is a documented convention here, not an enforced property.)

## 6. Blocking / non-blocking

- `java.util.BitSet` is purely in-memory and **non-blocking**; there is no I/O.
  Source: BitSet class summary ("A BitSet is not safe for multithreaded use
  without external synchronization"). It offers **no** internal locking.
- `BitInputStream` wraps a blocking `java.io.InputStream`; reads block when the
  underlying stream does. `bitsAvailable()` is an *estimate* "of the number of
  bits that can be read ... without blocking"; `bitsCached()` is exact for the
  internal cache. Source: BitInputStream javadoc (link above).
- RoaringBitmap is likewise unsynchronized for performance; the immutable variant
  is safe to share across threads "as long as you abide by the
  `ImmutableBitmapDataProvider` interface". Source:
  <https://github.com/RoaringBitmap/RoaringBitmap>

(Assessment: derived — the Java answer is "no async model at all inside the
type"; concurrency is pushed onto the caller or onto higher-level frameworks.)

## 7. Width and ordering model

- **Fixed width, signed, two's complement.** `int` = 32 bits, `long` = 64 bits
  (`Integer.SIZE`, `Long.SIZE`). Source: Integer/Long API (links above). Java has
  **no unsigned primitive**; unsigned interpretation is opt-in per call
  (`compareUnsigned`, `toUnsignedLong`, `parseUnsignedInt`).
- **Bit-set indexing** is by `int`, 0-based, LSB = index 0 within a word: "the
  ith bit is stored in bits[i/64] at bit position i % 64 (where bit position 0
  refers to the least significant bit and 63 ... most significant)". Source:
  OpenJDK `BitSet.java` `@serialField bits` comment. The address split is
  `ADDRESS_BITS_PER_WORD = 6`, `BITS_PER_WORD = 1 << 6 = 64`.
- **Byte serialization is little-endian.** `valueOf(byte[])`: `get(n) ==
  ((bytes[n/8] & (1 << (n%8))) != 0)`, documented as "a little-endian
  representation". `toByteArray()`/`toLongArray()` are the same little-endian
  layout. Source: BitSet javadoc.
- **`ByteBuffer` defaults to `BIG_ENDIAN`.** "The initial order of a byte buffer
  is always BIG_ENDIAN." Source: ByteBuffer javadoc. `BitSet.valueOf(ByteBuffer)`
  therefore forces `bb.slice().order(ByteOrder.LITTLE_ENDIAN)` before reading.
  Source: OpenJDK `BitSet.valueOf(ByteBuffer)`.
- **Sharp edge:** `ByteBuffer.slice()`/`duplicate()` reset the order to
  `BIG_ENDIAN` even when the parent buffer was little-endian ("its byte order will
  be BIG_ENDIAN"). Source: ByteBuffer javadoc for `slice`/`duplicate`. BitSet's
  code depends on knowing this.
- **Bit-level stream order is an explicit parameter:** `BitInputStream` takes a
  `ByteOrder` where "BIG_ENDIAN (most significant bit first)" reads bit 7→0 of
  each byte and "LITTLE_ENDIAN (least significant bit first)" reads bit 0→7.
  Source: BitInputStream source file (link above).
- **Shift distance is masked, not checked.** JLS §15.19: for an `int`
  left-operand "only the five lowest-order bits of the right-hand operand are
  used as the shift distance ... masked by 0x1f", for `long` "the six
  lowest-order bits ... 0x3f". So `x << 32` on an `int` equals `x << 0`. Source:
  <https://docs.oracle.com/javase/specs/jls/se21/html/jls-15.html#jls-15.19>
- **Rotate distance is masked too:** "all but the last five bits of the rotation
  distance can be ignored" — `rotateLeft(val, distance) == rotateLeft(val,
  distance & 0x1F)`, and negative distance is equivalent to the opposite
  rotation. Source: Integer javadoc.

## 8. Bounds, overflow and growth

- **Negative index → exception** (never undefined). `set(-1)` throws
  `IndexOutOfBoundsException`; `new BitSet(-1)` throws
  `NegativeArraySizeException`. Sources above.
- **Growth is automatic and geometric.** `expandTo(wordIndex)` calls
  `ensureCapacity`, which allocates `Math.max(2 * words.length, wordsRequired)`
  — i.e. doubling. `sizeIsSticky` records a user-specified initial capacity (from
  `new BitSet(nbits)`) so it is preserved; growth resets it to `false`. Source:
  OpenJDK `BitSet.ensureCapacity`/`expandTo`.
- **Reads beyond bounds are safe:** `get(bitIndex)` returns `false` when
  `wordIndex >= wordsInUse`; `nextSetBit` returns `-1`; `clear(bitIndex)` returns
  without action when out of range. `clear(from,to)` clamps `toIndex` down to
  `length()`. Sources: OpenJDK `BitSet` methods.
- **`size()` vs `length()`:** `size()` = `words.length * 64` (allocated capacity),
  `length()` = highest set bit + 1 or 0 (logical). `toByteArray()` length is
  `(length()+7)/8`, `toLongArray()` length is `(length()+63)/64`. Sources: BitSet
  javadoc/OpenJDK source.
- **Integer overflow of the index:** the documented iteration idiom must guard
  `if (i == Integer.MAX_VALUE) break;` because `i+1` would overflow to negative.
  Source: `nextSetBit` javadoc code sample.
- **No undefined behavior** in shifts (masking instead); arithmetic overflow on
  `+`/`*` silently wraps modulo 2^n. (Assessment: derived from JLS §15.19 and the
  fixed-width signed primitive definition.)
- **RoaringBitmap growth** is different by design: it is chunked into 2^16
  containers, each stored as a dense array, a sorted list, or a run list, so
  sparse sets do not pay the dense cost. Source:
  <https://github.com/RoaringBitmap/RoaringBitmap>

## 9. Scalar functions, container type and bit-level I/O

How Java divides the three layers:

1. **Raw integer bit functions** — fully present, but only as `static` methods
   on `Integer`/`Long` (`bitCount`, `numberOfLeadingZeros`, `rotateLeft`,
   `reverse`, `reverseBytes`, `compress`, `expand`, ...). No dedicated `bit`
   module: the functions are scattered across the boxed primitive classes.
2. **Set/container abstraction** — present and mature as `java.util.BitSet`
   (growable, word-based `long[]`, cardinality, logical ops, set-bit iteration,
   `IntStream`). There is **no fixed-width bitset in the stdlib** (unlike C++
   `std::bitset`); fixed width is emulated with `long`/`int` plus masks.
3. **Bit-level bitfield `[hi:lo]` extraction/insertion** — **absent.** Neither
   `BitSet` nor `Integer`/`Long` offers `get_bits(value, hi, lo)` /
   `set_bits(value, hi, lo, x)`. The idiom is manual: `(v >>> lo) & ((1L << (hi -
   lo + 1)) - 1)` and masking with `~(...)` on write. (Assessment: derived from
   the complete `BitSet` and `Integer`/`Long` method listings, which contain no
   range-over-integer API; `BitSet.set(from,to)` operates on the *container*, not
   on a scalar.) `Integer.compress(i, mask)` is the closest stdlib relative —
   mask-driven selective packing, added in Java 19. Source:
   <https://bugs.openjdk.org/browse/JDK-8283893>
4. **Bit-level stream I/O** — **absent from the stdlib**; supplied by Apache
   Commons Compress `BitInputStream` (+ `ByteOrder` for LSB/MSB-first) and by
   tomgibara/bits `BitReader`/`BitWriter`. Sources above.

(Assessment: derived — Java's three layers map to exactly the three MojoAkku
gaps: layer 1 exists (`std.bit`), layers 3 and 4 do not; layer 2 exists here as
`BitSet` but not in `std.bit`.)

## 10. Interesting design decisions

- **Word size is 64 and chosen "purely for performance"**, with the address
  split derived from it (`ADDRESS_BITS_PER_WORD = 6`). Comments state the word
  size is not part of the contract. Source: OpenJDK `BitSet.java` header comment.
- **`size()` (capacity) is deliberately decoupled from `length()` (logical) and
  from `equals`.** Two BitSets with identical set bits but different capacities
  are equal. This is a clean separation of physical vs logical size. Source:
  BitSet javadoc for `size`/`length`/`equals`.
- **`sizeIsSticky`**: if the user explicitly sized the set, growth tries to
  preserve that size; otherwise `clone()` and serialization `trimToSize()` first.
  A small flag encodes a meaningful behavioral distinction. Source: OpenJDK
  `BitSet` (`sizeIsSticky`, `trimToSize`).
- **Logical ops are in-place `void` with self-alias shortcut:** `and`, `or`,
  `xor` first check `if (this == set) return;` (except `xor`, where `a^a=0` is
  still handled by the general path). No allocations. Source: OpenJDK `BitSet`.
- **Iteration over set bits is `nextSetBit(i+1)` with `-1` sentinel**, plus an
  explicit `Integer.MAX_VALUE` overflow guard in the documented idiom — a rare
  case of a library documenting its own boundary bug. Source: BitSet javadoc.
- **`stream()` uses a custom late-binding spliterator** that can split, estimate
  size, and reports `ORDERED | DISTINCT | SORTED`. Mutation during traversal is
  "undefined". Source: OpenJDK `BitSet.stream()`.
- **Little-endian is the serialization contract**, and `valueOf(ByteBuffer)`
  silently re-orders a slice to `LITTLE_ENDIAN` — the API encodes its endianness
  rather than inheriting it. Sources: BitSet javadoc + OpenJDK source.
- **`compress`/`expand` are justified by hardware**: the CSR explicitly maps them
  to x86 `PEXT`/`PDEP` and to succinct-data-structure `select`, and the JDK
  intrinsified them for ~10x speedup. Source:
  <https://bugs.openjdk.org/browse/JDK-8283893> and
  <https://mail.openjdk.org/pipermail/hotspot-compiler-dev/2022-May/055995.html>
- **Roaring's mutable/immutable split without copying** (`toImmutableRoaringBitmap`
  is a constant-time cast; COW variant copies containers lazily) is a textbook
  answer to "big object, avoid copies". Source:
  <https://github.com/RoaringBitmap/RoaringBitmap>
- **tomgibara/bits keeps nearly every operation on one `BitStore` interface**
  with default methods, precisely "to avoid the inefficiency of moving bits from
  one specialized object to another". Source:
  <https://github.com/tomgibara/bits>

## 11. Decisions NOT to copy

- **Do not scatter scalar bit functions across boxed types.** Putting
  `bitCount` on `Integer`, `numberOfLeadingZeros` on `Long` and nothing on a
  shared module forces callers to know which class to import; MojoAkku's flat
  per-API-file layout already avoids this. (Assessment: derived from the Java
  API layout, Integer/Long links above.)
- **Do not mask shift distances.** JLS §15.19 makes `x << 32 == x << 0`, which
  silently hides a caller bug; an explicit error or a well-defined
  "distance ≥ width" rule is safer. (Assessment: derived from JLS §15.19.)
- **Do not overload `size()` and `length()` as public names.** Both are ints and
  both plausible; the distinction has repeatedly confused users (capacity vs
  logical length). Prefer explicit names. (Assessment: derived from the BitSet
  javadoc wording of `size()` vs `length()`.)
- **Do not make logical ops mutate-only `void`.** `and/or/xor/andNot` mutate and
  return nothing; an allocating variant must be emulated via `clone()`. A Mojo
  API that states mutation in the type/signature is clearer. (Assessment: derived
  from BitSet signatures.)
- **Do not use the `-1` sentinel when the domain can be negative.** `fromIndex =
  -1` is "valid = empty" for `previousSetBit` but negative is banned elsewhere;
  the mixing is subtle. (Assessment: derived from BitSet `previousSetBit` docs.)
- **Do not inherit byte order implicitly.** `ByteBuffer.slice()` resetting to
  `BIG_ENDIAN` is a live footgun; make the ordering explicit in the type.
  (Assessment: derived from ByteBuffer `slice` javadoc and BitSet's workaround.)
- **Do not copy Roaring's complexity.** Chunked containers (dense/list/run) are
  excellent for huge sparse sets but a large surface for a small toolkit.
  (Assessment: derived from the RoaringBitmap README.)
- **Do not ship an unchecked exception hierarchy just for stream end.** tomgibara
  uses `BitStreamException`/`EndOfBitStreamException`; Mojo's `raises` plus a
  small error type is a better fit than an unchecked class hierarchy.
  (Assessment: derived from the tomgibara/bits README.)

## 12. Ideas fitting Mojo

- **Mirror the three-layer split explicitly.** Java accidentally has three
  layers; MojoAkku can name them: scalar `std.bit` extensions, the `bit`-library
  container type, and a bit reader/writer. The Mojo library should fill layers 3
  and 4 and *wrap* layer 1. (Assessment: derived from `_dev/README.md` and §9.)
- **`nextSetBit`-style iteration with an explicit "no more" signal** maps well to
  Mojo `Optional`/`raises`; the documented `Integer.MAX_VALUE` overflow guard
  shows the boundary must be handled, not assumed away. (Assessment: derived from
  BitSet `nextSetBit`.)
- **`compress`/`expand` as mask primitives** are a strong extension of
  `get_bits`/`set_bits`: they generalize range extraction to *arbitrary* masks
  and map to hardware. Worth providing next to the `[hi:lo]` pair. Source:
  <https://bugs.openjdk.org/browse/JDK-8283893>
- **Little-endian as the serialization default, ordering as an explicit
  parameter** is both a Java precedent (BitSet) and a Java lesson (ByteOrder
  parameter in `BitInputStream`). Mojo's bit reader/writer should take an
  LSB-first/MSB-first argument, not a separate type per order. Sources: BitSet
  javadoc, BitInputStream javadoc.
- **Separate physical capacity from logical length**, and make that distinction
  named clearly rather than `size`/`length`. (Assessment: derived from BitSet.)
- **Growth policy should be visible** (doubling in Java) so callers can avoid
  repeated reallocation; Mojo's value/ownership model may allow a caller-supplied
  buffer instead. (Assessment: derived from OpenJDK `ensureCapacity`.)
- **Mutable/immutable views without copying** (Roaring) is attractive, but Mojo's
  `borrowed`/`var` already expresses much of it; use references rather than a
  second class hierarchy. (Assessment: derived from RoaringBitmap README plus
  Mojo ownership terminology in `_dev/README.md`.)

## Sources

- `java.util.BitSet` API (JDK 21):
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/util/BitSet.html>
- `java.util.BitSet` source (OpenJDK master):
  <https://raw.githubusercontent.com/openjdk/jdk/master/src/java.base/share/classes/java/util/BitSet.java>
  (word size `ADDRESS_BITS_PER_WORD=6`; `ensureCapacity`; `sizeIsSticky`;
  `valueOf(ByteBuffer)`; `nextSetBit`; `stream`).
- `java.lang.Integer` API (JDK 21):
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Integer.html>
- `java.lang.Long` API (JDK 21):
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/lang/Long.html>
- `java.nio.ByteBuffer` API (JDK 21):
  <https://docs.oracle.com/en/java/javase/21/docs/api/java.base/java/nio/ByteBuffer.html>
- JLS §15.19 Shift Operators:
  <https://docs.oracle.com/javase/specs/jls/se21/html/jls-15.html#jls-15.19>
- JDK-8283893 "Compress and expand bits" (CSR, Java 19):
  <https://bugs.openjdk.org/browse/JDK-8283893>
- Intrinsification of compress/expand (OpenJDK hotspot-compiler-dev, 2022):
  <https://mail.openjdk.org/pipermail/hotspot-compiler-dev/2022-May/055995.html>
- Apache Commons Compress `BitInputStream` javadoc:
  <https://commons.apache.org/proper/commons-compress/apidocs/org/apache/commons/compress/utils/BitInputStream.html>
- Apache Commons Compress `utils` package summary:
  <https://commons.apache.org/proper/commons-compress/apidocs/org/apache/commons/compress/utils/package-summary.html>
- Apache Commons Compress `BitInputStream.java` source:
  <https://raw.githubusercontent.com/apache/commons-compress/master/src/main/java/org/apache/commons/compress/utils/BitInputStream.java>
- tomgibara/bits:
  <https://github.com/tomgibara/bits>
- RoaringBitmap:
  <https://github.com/RoaringBitmap/RoaringBitmap>
