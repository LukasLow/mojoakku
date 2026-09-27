# bit research: Go

## 1. Standard library support

Go's standard library provides **scalar bit functions** and **arbitrary-precision integers**, but **no bit-set container** and **no bit-level stream I/O**.

- `math/bits` — package doc: "implements bit counting and manipulation functions for the predeclared unsigned integer types." Functions "may be implemented directly by the compiler, for better performance. For which functions the code in this package will not be used." Source: <https://pkg.go.dev/math/bits>.
  - Counting: `Len`, `Len8/16/32/64`, `OnesCount`, `OnesCount8/16/32/64`, `LeadingZeros`, `LeadingZeros8/16/32/64`, `TrailingZeros`, `TrailingZeros8/16/32/64`. Source: <https://pkg.go.dev/math/bits>.
  - Rotation/permutation: `RotateLeft`, `RotateLeft8/16/32/64`, `Reverse`, `Reverse8/16/32/64`, `ReverseBytes`, `ReverseBytes16/32/64`. Source: <https://pkg.go.dev/math/bits>.
  - Multi-word arithmetic: `Add`, `Sub`, `Mul`, `Div`, `Rem` (and 32/64 variants) with carry/borrow/full-width products. Source: <https://pkg.go.dev/math/bits>.
  - Constant `UintSize = uintSize` — "UintSize is the size of a uint in bits." Source: <https://pkg.go.dev/math/bits#UintSize>.
- `math/big` — arbitrary-precision `Int` with word-level bit access: `Bit(i) uint`, `BitLen() int`, `SetBit(x *Int, i int, b uint) *Int`, `TrailingZeroBits() uint`, `SetBits(abs []Word) *Int`, `Bits() []Word`, `Lsh`/`Rsh`, `And`/`Or`/`Xor`/`AndNot`/`Not`. Source: <https://pkg.go.dev/math/big#Int>. This is the closest stdlib thing to a growable bit-indexed set, but it is an arithmetic type, not a set type — there is no union/intersection/cardinality/iteration-over-set-bits API. (Assessment: derived from <https://pkg.go.dev/math/big#Int> and <https://pkg.go.dev/github.com/bits-and-blooms/bitset>.)
- `encoding/binary` — `ByteOrder` interface (`Uint16/32/64`, `PutUint16/32/64`, `String`), implemented by `LittleEndian`, `BigEndian`, `NativeEndian`; plus varints and struct encode/decode. All of it is **byte-granular**, no bit fields. Source: <https://pkg.go.dev/encoding/binary#ByteOrder>.
- No stdlib bit-set: `math/bits`'s own "Types" section is empty; the stdlib package index has no bit-set type. (Assessment: derived from <https://pkg.go.dev/math/bits> and <https://pkg.go.dev/std>.)

## 2. Relevant community libraries

- `github.com/bits-and-blooms/bitset` — v1.25.0, BSD-3-Clause, "Go language library to map between non-negative integers and boolean values". Imported by 440 packages; production users listed include milvus, cubefs, bleve/vellum, Hugo, Apache Pulsar client, RoaringBitmap. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset>.
- `github.com/RoaringBitmap/roaring` — compressed bitmaps; the bitset README explicitly points to it "If you have lots of bits" and documents round-tripping `ToBitSet()` / `FromBitSet()`. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset> and <https://roaringbitmap.org>.
- `github.com/icza/bitio` — v1.1.0, Apache-2.0, "optimized bit-level Reader and Writer for Go", imported by 92 packages, last published 2021-12-07. Source: <https://pkg.go.dev/github.com/icza/bitio>.

## 3. Exposed APIs

`math/bits` (exact signatures from the package index):
- `func Len(x uint) int`, `Len8/16/32/64` — "minimum number of bits required to represent x; the result is 0 for x == 0."
- `func OnesCount(x uint) int` — "number of one bits ('population count')."
- `func LeadingZeros(x uint) int` — "number of leading zero bits; the result is UintSize for x == 0." Per-width variants return the width (8/16/32/64) for zero.
- `func TrailingZeros(x uint) int` — same, result is `UintSize` for x == 0.
- `func RotateLeft(x uint, k int) uint` — "rotated left by (k mod UintSize) bits. To rotate x right by k bits, call RotateLeft(x, -k)."
- `func Reverse(x uint) uint` — "value of x with its bits in reversed order."
- `func ReverseBytes(x uint) uint` — "value of x with its bytes in reversed order."
Source for all: <https://pkg.go.dev/math/bits> (source lines e.g. <https://cs.opensource.google/go/go/+/go1.27.1:src/math/bits/bits.go>).

`bitset.BitSet` — non-negative index → bool, chaining methods returning `*BitSet`, plus constructors:
- Single bit: `Set(i)`, `Clear(i)`, `Flip(i)`, `Test(i) bool`, `SetTo(i, value bool)`.
- Bulk: `ClearAll()`, `SetAll()`, `FlipRange(start, end)`, `SetRange(start, end)`, `SetTo`.
- Query: `Len() uint`, `Count() uint` ("number of set bits ... also known as popcount"), `All() bool`, `Any() bool`, `None() bool`, `Equal(c)`, `IsSuperSet`/`IsStrictSuperSet`, `Rank(index)`, `Select(index)`, `OnesBetween(from, to)`.
- Iteration: `NextSet(i) (uint, bool)` / `NextClear` / `PreviousSet` / `PreviousClear` / `NextSetMany(i, buffer)`, and `EachSet() iter.Seq[uint]` — "iterator over the indices of all set bits in ascending order, for use with Go 1.23+ range-over-function loops."
- Set algebra: `Union`, `Intersection`, `Difference` ("equivalent of &^ (and not)"), `SymmetricDifference`, plus `InPlaceUnion`/`InPlaceIntersection`/`InPlaceDifference`/`InPlaceSymmetricDifference`, plus `UnionCardinality`/`IntersectionCardinality`/`DifferenceCardinality`/`SymmetricDifferenceCardinality`.
- Bit gather/scatter: `Extract(mask)` / `ExtractTo(mask, dst)` ("copies bits ... using positions specified in mask into a compacted form") and `Deposit(mask)` / `DepositTo(mask, dst)` (the inverse).
- Growth/storage: `New(length)`, `MustNew(length)`, `From(buf []uint64)`, `FromWithLength(length, set)`, `Shrink(lastbitindex)`, `Compact()`, `Clone()`, `Copy(c) (count)`, `CopyFull(c)`, `Words() []uint64`, `GetWord64AtBit(i)`, `AsSlice(buf)`, `AppendTo(buf)`, `BinaryStorageSize()`, `ShiftLeft(bits)`, `ShiftRight(bits)`, `InsertAt(idx)`, `DeleteAt(i)`.
- Serialization: `WriteTo(io.Writer) (int64, error)`, `ReadFrom(io.Reader) (int64, error)`, `MarshalBinary`/`UnmarshalBinary`, `MarshalJSON`/`UnmarshalJSON`, `DumpAsBits()`, `String()`.
Source for all: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.

`icza/bitio`: `Reader.ReadBits(n uint8) (uint64, error)`, `Reader.ReadBool()`, `Reader.ReadByte()`, `Reader.Read(p []byte)`, `Align() (skipped uint8)`, and the `TryReadXXX` no-error siblings; `Writer.WriteBits(r uint64, n uint8) error`, `WriteBitsUnsafe`, `WriteBool`, `WriteByte`, `Write`, `Align`, `Close`, and `TryWriteXXX`. `CountReader`/`CountWriter` add `BitsCount int64`. Source: <https://pkg.go.dev/github.com/icza/bitio>.

## 4. Error representation

Go has no exceptions; errors are return values (`error`), and misuse of low-level primitives is signalled by panic.
- `math/bits`: no error returns. `Div`/`Div32`/`Div64` "panics for y == 0 (division by zero) or y <= hi (quotient overflow)." `Rem` "panics for y == 0 ... but, unlike Div, it doesn't panic on a quotient overflow." `Add`/`Sub`: "The carry input must be 0 or 1; otherwise the behavior is undefined." Source: <https://pkg.go.dev/math/bits>.
- `bitset`: a dedicated `type Error string` — "Error is used to distinguish errors (panics) generated in this package." Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#Error>. `New` degrades gracefully: "In case of allocation failure, the function will return a BitSet with zero capacity"; `MustNew` "panics if length exceeds the possible capacity or by a lack of memory"; `Compact` may panic "If you are memory constrained"; `Flip`/`FlipRange` warn "using a very large value ... may lead to a memory shortage and a panic". Serialization uses `(int64, error)` / `(int, error)`. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- `Test(i)` returns `bool`; the fetched documentation does not state a contract for `i` beyond `Len()` — GUESS: out-of-range `Test` returns false rather than panicking, by analogy with `Clear` ("It is always safe") and the `Copy` comment "bits outside the capacity are always disabled" on the Rust analogue; reason for the guess: the Go doc text for `Test` does not spell it out. Compare `math/big.Int.Bit`: documented as "Bit returns the value of the i'th bit of x. That is, it returns (x>>i)&1. The bit index i must be >= 0." (still no upper bound). Source: <https://pkg.go.dev/math/big#Int>. — GUESS.
- `icza/bitio`: "All ReadXXX() and WriteXXX() methods return an error which you are expected to handle." The `TryXXX` variants are no-ops after the first error and store it in the public `TryError` field. `WriteBitsUnsafe` "with an r that does not satisfy this is undefined behavior (might corrupt previously written bits)." Source: <https://pkg.go.dev/github.com/icza/bitio>.

## 5. Ownership semantics

Go is garbage-collected; there is no ownership/lifetime, only pointer aliasing.
- `BitSet` methods use a `*BitSet` receiver and many return the receiver for chaining (`b.Set(10).Set(11)`). The zero value is usable: "The zero value of a BitSet is an empty set of length 0." Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- Internal storage leaks by design: `Bytes() []uint64` "returns the bitset as array of 64-bit words, giving direct access to the internal representation. It is not a copy, so changes to the returned slice will affect the bitset." It is deprecated in favour of `Words()`. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- Concurrency is explicitly the caller's problem: "In general, it's not safe to access the same BitSet using different goroutines--they are unsynchronized for performance." Recommended patterns: "channels to pass the *BitSet around (in Go style; so there is only ever one owner), or by using sync.Mutex." Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset>.
- `math/big`: operations take `*Int` operands and a receiver that is the result; "Unless specified otherwise, operations permit aliasing of parameters, so it is perfectly ok to write sum.Add(sum, x)." There is no implicit copy — "shallow copies of Floats are not supported and may lead to errors" (stated for Float; Int follows the same receiver-result convention). Source: <https://pkg.go.dev/math/big>.

## 6. Blocking / non-blocking

- Scalar `math/bits` is pure computation — no IO, no blocking.
- `bitset.WriteTo(io.Writer)` / `ReadFrom(io.Reader)` and `icza/bitio`'s reader/writer are ordinary blocking `io` operations; the docs recommend wrapping streams in `bufio` for performance. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset> and <https://pkg.go.dev/github.com/icza/bitio>.
- There is no async model in the language. Concurrency is goroutines + channels; the bitset library delegates synchronization to the caller (see §5). (Assessment: derived from <https://pkg.go.dev/github.com/bits-and-blooms/bitset>.)

## 7. Width and ordering model

- Fixed-width unsigned types `uint8`, `uint16`, `uint32`, `uint64`, and platform-sized `uint`/`uintptr`; signed `int8`…`int64`, `int`. "The value of an n-bit integer is n bits wide and represented using two's complement arithmetic." `byte` is an alias for `uint8`, `rune` for `int32`. There is **no `uint128`**. Source: <https://go.dev/ref/spec#Numeric_types>.
- Width is encoded in the function name, not in a generic parameter: `LeadingZeros8/16/32/64`, `OnesCount8/16/32/64`, `RotateLeft8/16/32/64`. Source: <https://pkg.go.dev/math/bits>.
- Bit index convention inside a word: bit 0 is least significant. `DumpAsBits` "dumps a bit set as a string of bits. Following the usual convention in Go, the least significant bits are printed last (index 0 is at the end of the string)." Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- Byte ordering is a separate axis and is configured by `encoding/binary`'s `ByteOrder`, not by a bit-order type. `bitset` carries a package-global order switch: `LittleEndian()`, `BigEndian()`, `BinaryOrder() binary.ByteOrder`; both setter docs claim the default is `binary.BigEndian` ("BigEndian sets Marshal/Unmarshal Binary as Big Endian (Default: binary.BigEndian)"). Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BigEndian>.
- There is no LSB0/MSB0 concept for *bits within a byte* in the stdlib or in `bitset`. The only bit-order choice lives in the third-party stream layer: `icza/bitio` states "The more general highest-bits-first order is used" and then consumes `0x8f 0x55` as `1100 1111 0101 0101` (i.e. MSB-first), with `Align()` to return to byte boundaries. Source: <https://pkg.go.dev/github.com/icza/bitio>.
- (Assessment: derived from the above) Go therefore models width explicitly (name suffix) and ordering only at the byte level (ByteOrder) plus one hard-wired MSB-first bit-stream order; there is no parameterisable bit ordering, in sharp contrast to Rust's `bitvec`.

## 8. Bounds, overflow and growth

- Shifts: "The shift operators shift the left operand by the shift count ... which must be non-negative. If the shift count is negative at run time, a run-time panic occurs. ... There is no upper limit on the shift count. Shifts behave as if the left operand is shifted n times by 1 for a shift count of n." Source: <https://go.dev/ref/spec#Operators>. Consequence: shifting a `uint64` by 64 is well-defined (zero), never a panic, unlike Rust's `checked_shl` family.
- Unsigned overflow: "For unsigned integer values, the operations +, -, *, and << are computed modulo 2^n ... programs may rely on 'wrap around'." Signed overflow: "may legally overflow and the resulting value exists and is deterministically defined by the signed integer representation, the operation, and its operands. Overflow does not cause a run-time panic." Source: <https://go.dev/ref/spec#Integer_overflow>.
- Mixing numeric types requires explicit conversion: "Explicit conversions are required when different numeric types are mixed in an expression or assignment. For instance, int32 and int are not the same type." Source: <https://go.dev/ref/spec#Numeric_types>.
- `bitset` growth: "BitSets are expanded to the size of the largest set bit; the memory allocation is approximately Max bits, where Max is the largest set bit. BitSets are never shrunk automatically, but Shrink and Compact methods are available." Allocation can be triggered by `Set`/`Flip`/`SetRange`/`FlipRange` on a far-away index; `MustNew` panics when the requested length exceeds capacity/memory. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset>.
- `Clear` never allocates and "is always safe"; `DeleteAt` "may potentially be relatively slow, O(length)". Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- `icza/bitio` bounds: `WriteBits(r, n)` masks off bits above `n` ("Bits of r in positions higher than n are ignored"), while `WriteBitsUnsafe` requires the caller to have done that and is otherwise UB. Source: <https://pkg.go.dev/github.com/icza/bitio>.

## 9. Scalar functions, container type and bit-level I/O

| layer | provided by stdlib? | source |
| --- | --- | --- |
| scalar bit functions | **yes**, `math/bits` (+ `math/big` for arbitrary width) | <https://pkg.go.dev/math/bits>, <https://pkg.go.dev/math/big> |
| bit-set / flag-set container | **no** — third party only (`bits-and-blooms/bitset`, `roaring`) | <https://pkg.go.dev/math/bits>, <https://pkg.go.dev/github.com/bits-and-blooms/bitset> |
| bitfield get/set over `[hi:lo]` | **no** — closest are `math/big.Int.Bit`/`SetBit` (one bit at an index) and `bitset.Extract/Deposit` (mask-based gather/scatter) | <https://pkg.go.dev/math/big#Int>, <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet> |
| bit-level stream I/O | **no** — `encoding/binary` is byte-level; third party `icza/bitio` | <https://pkg.go.dev/encoding/binary>, <https://pkg.go.dev/github.com/icza/bitio> |

Compare with Mojo's `std.bit`, which already ships `pop_count`, `count_leading_zeros`, `count_trailing_zeros`, `bit_reverse`, `byte_swap`, `rotate_bits_left`, `rotate_bits_right`, `bit_width` (see `_dev/README.md`). Go's `math/bits` covers the same scalar set (`OnesCount`, `LeadingZeros`, `TrailingZeros`, `Reverse`, `ReverseBytes`, `RotateLeft`, `Len`) — so Go's evidence reinforces the README's "scalar is a stdlib-first case" assessment, and Go has the same two gaps: no container type and no bit-level I/O in std. (Assessment: derived from <https://pkg.go.dev/math/bits> and `_dev/README.md`.)

## 10. Interesting design decisions

- **Width in the name, not in a type parameter.** `LeadingZeros8` vs `LeadingZeros64` avoids generics/type switches and lets the compiler intrinsic-ise the call: "Functions in this package may be implemented directly by the compiler." Source: <https://pkg.go.dev/math/bits>.
- **Documented constant-time contracts.** Several functions carry "This function's execution time does not depend on the inputs." (`RotateLeft`, `RotateLeft8…64`, `ReverseBytes`, `ReverseBytes16…64`, `Add`, `Add32`, `Add64`, `Sub`, `Sub32`, `Sub64`, `Mul`, `Mul32`, `Mul64`). This is a security-relevant guarantee that a bit library feeding `hash`/`crypto` can advertise. Source: <https://pkg.go.dev/math/bits>.
- **Sentinel-free zero semantics.** `Len(0) == 0` and `LeadingZeros(0) == UintSize` / `LeadingZeros8(0) == 8` — the zero input is defined rather than special-cased by the caller. Source: <https://pkg.go.dev/math/bits>.
- **Signed rotation count.** `RotateLeft(x, k)` takes `int k` and documents `RotateLeft(x, -k)` for a right rotation, i.e. one entry point for both directions with the modulo applied internally. Source: <https://pkg.go.dev/math/bits>.
- **Chaining as the mutation idiom.** "Many of the methods, including Set, Clear, and Flip, return a BitSet pointer, which allows for chaining." Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset>.
- **Three operation styles for set algebra.** Materialising (`Union`), in-place (`InPlaceUnion`), and count-only without allocation (`UnionCardinality`) — the docs justify the third explicitly: "This is potentially much faster than using union(other).count()". Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- **Rank/Select/OnesBetween** bring succinct-data-structure queries into the everyday API, not just set algebra. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- **Extract/Deposit** implement PEXT/PDEP-style compaction on the container (bits chosen by a mask are packed to consecutive positions, and the inverse). Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- **Usable zero value** for both `bitset.BitSet` and `big.Int`. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>, <https://pkg.go.dev/math/big>.
- **`math/big` as an accidental bit vector.** `SetBit(x, i, b)` with an arbitrary non-negative `i` plus `BitLen`/`TrailingZeroBits`/`SetBits([]Word)` makes a big integer usable as an unbounded bit array — but with arithmetic semantics, not set semantics. (Assessment: derived from <https://pkg.go.dev/math/big#Int>.)

## 11. Decisions NOT to copy

- **Package-global mutable endianness.** `bitset.BigEndian()`, `bitset.LittleEndian()`, `bitset.BinaryOrder()` mutate a package-level setting that then governs every marshal/unmarshal in the process. For a predictable, low-vision-friendly API this is a hidden global mode; an explicit per-call/per-type ordering parameter is safer. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BigEndian>.
- **Panics as the error channel for ordinary misuse.** `mustNew` panics on allocation failure, `Div` panics on quotient overflow, `Flip` can panic on OOM. Source: <https://pkg.go.dev/math/bits>, <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- **Exposing internal storage without a copy.** `Bytes()` returns the live `[]uint64`; it is deprecated precisely because of the aliasing hazard. `Words()` carries the same "not a copy" property. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- **Unsafe variants with UB contracts.** `icza/bitio.WriteBitsUnsafe` corrupts previously written bits if the caller forgot to mask; such a footgun is not suitable as a default-facing API. Source: <https://pkg.go.dev/github.com/icza/bitio>.
- **Leaving concurrency entirely to the caller with an unsynchronized pointer type.** The library's own docs say a plain `*BitSet` may not be shared across goroutines. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset>.
- **Index type equal to the size type.** Every bit index is a `uint`, so "one past the end", "capacity" and "count" are all the same type and easily confused (`Len()` vs `Count()` vs `cap`-like notions). Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- **Silent bit-drop in the safe writer.** `WriteBits(0x1234, 8)` silently writes `0x34`; the masking behaviour is documented but forgiving of a wrong width argument. Source: <https://pkg.go.dev/github.com/icza/bitio>.

## 12. Ideas fitting Mojo

- **Wrap, do not rebuild, the scanner/word primitives.** `math/bits` confirms the README's positioning: the scalar set (`OnesCount`→`pop_count`, `LeadingZeros`→`count_leading_zeros`, `Reverse`→`bit_reverse`, `ReverseBytes`→`byte_swap`, `RotateLeft`→`rotate_bits_left`, `Len`→`bit_width`) is exactly `std.bit`. Go's lesson is to expose width-explicit variants and constant-time notes rather than re-implement. (Assessment: derived from <https://pkg.go.dev/math/bits> and `_dev/README.md`.)
- **A zero-value-ready container struct** (`var b BitSet` is immediately usable) maps to a Mojo `struct` whose default `__init__` yields an empty set. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- **Three operation styles** (materialise / in-place / count-only) is a good template for the set algebra surface, and the count-only variants are cheap to add. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- **Rank/Select/OnesBetween and Extract/Deposit** are set-level primitives worth designing for early, since they are expensive to retrofit. Source: <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.
- **`put(bit) -> previous value`** (Rust's `fixedbitset.put`; Go's `SetTo` plus a `Test`) is a useful read-modify-write primitive — in Mojo this is a natural place for a `borrowed`/`mut` receiver returning the old bit. (Assessment: derived from <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html#method.put> and <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BitSet>.)
- **`raises` instead of panics** for out-of-range index, bad `[hi:lo]` range, and shift ≥ width. Go's panic/UB boundary and `icza/bitio`'s error-or-UB split show the two extremes; Mojo's `raises` sits between them. (Assessment: derived from <https://pkg.go.dev/math/bits>, <https://pkg.go.dev/github.com/icza/bitio>.)
- **A documented constant-time flag** on the scalar wrappers, copying Go's explicit per-function guarantee, is valuable for the `hash`/`digest`/`crypto` libraries that will sit on top of `bit`. Source: <https://pkg.go.dev/math/bits>.
- **Make the bit order an explicit parameter of the stream layer, not a global.** Go's global endian switch and `icza/bitio`'s hard-wired MSB-first order are the two anti-patterns; Rust's `Lsb0`/`Msb0` types show the opposite (see `rust.md`). (Assessment: derived from <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BigEndian>, <https://pkg.go.dev/github.com/icza/bitio>.)

## Sources

- Go specification (numeric types, operators, shifts, overflow, representability): <https://go.dev/ref/spec>
- `math/bits` package reference: <https://pkg.go.dev/math/bits>; source: <https://cs.opensource.google/go/go/+/go1.27.1:src/math/bits/bits.go>
- `math/big` package reference: <https://pkg.go.dev/math/big>
- `encoding/binary` package reference: <https://pkg.go.dev/encoding/binary>
- `github.com/bits-and-blooms/bitset` (v1.25.0, BSD-3-Clause): <https://pkg.go.dev/github.com/bits-and-blooms/bitset>
- `github.com/RoaringBitmap/roaring` (compressed bitmaps): <https://roaringbitmap.org>, <https://github.com/RoaringBitmap/roaring>
- `github.com/icza/bitio` (v1.1.0, Apache-2.0): <https://pkg.go.dev/github.com/icza/bitio>
