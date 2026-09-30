# bit research: js-ts

## 1. Standard library support

JavaScript has **no bitset/bit-array container** in the language or standard library. Bit work happens through two number types with sharply different widths.

- **`Number` bitwise operators** (`&`, `|`, `^`, `~`, `<<`, `>>`, `>>>`) are **32-bit signed**: "For numbers, the operator returns a 32-bit integer." They coerce operands with "fixed-width number conversion" (discard everything above bit 32) and operate in two's complement. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Bitwise_AND>.
- **Shift count is masked mod 32**: "The right operand will be converted to an unsigned 32-bit integer and then taken modulo 32, so the actual shift offset will always be a positive integer between 0 and 31, inclusive. For example, `100 << 32` is the same as `100 << 0`." Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Left_shift>.
- **`>>>`** is the only unsigned shift; it is the one bitwise operator `BigInt` does **not** support "as every BigInt value is signed." Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.
- **`BigInt`** represents integers too large for `Number`, has unbounded size, supports `& | ^ ~ << >>` and arithmetic, and does **not** truncate: "Conceptually, understand positive BigInts as having an infinite number of leading `0` bits, and negative BigInts having an infinite number of leading `1` bits." It cannot be mixed with `Number` in operators (`TypeError`), and explicit truncation is available via `BigInt.asIntN(n, x)` / `BigInt.asUintN(n, x)`. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.
- **Numbers are IEEE-754 doubles**, so exact integer arithmetic only holds up to `Number.MAX_SAFE_INTEGER = 2^53 − 1`; "`Number.MAX_SAFE_INTEGER + 1 === Number.MAX_SAFE_INTEGER + 2` will evaluate to true". Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER>.
- **Typed arrays** give fixed-width element storage (`Uint8Array`, `Int8Array`, `Uint16Array`, `Uint32Array`, `BigInt64Array`, `BigUint64Array`, …) over an `ArrayBuffer`, but "Typed arrays always use the platform's native byte order. If you want to specify the endianness when writing and reading from buffers, you should use a `DataView` instead." Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray>.
- **`DataView`** is the stdlib's explicit-endianness reader/writer over an `ArrayBuffer`: "provides a low-level interface for reading and writing multiple number types … without having to care about the platform's endianness", defaulting to big-endian, with per-call `littleEndian` flags; methods include `get/setInt8..32`, `get/setUint8..32`, `get/setBigInt64`, `get/setBigUint64`, `get/setFloat16/32/64`. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView>.
- **No stdlib bit *set*.** For a set of small integers the idiomatic substitute is `Set<number>`; a bitset requires a library (§2) or manual `Uint32Array` words.

## 2. Relevant community libraries

| library | npm package | maintainer | maturity | license | source |
| --- | --- | --- | --- | --- | --- |
| FastBitSet.js | `fastbitset` | Daniel Lemire | speed-optimized, benchmarked against peers, 32-bit-word bitset | Apache-2.0 | <https://github.com/lemire/FastBitSet.js> |
| TypedFastBitSet.js | `typedfastbitset` | Daniel Lemire | same design, typed arrays | Apache-2.0 | <https://github.com/lemire/TypedFastBitSet.js> |
| BitSet.js | `bitset` | Robert Eisele | arbitrary-length + infinite complement, TypeScript, v5.3.0 | MIT | <https://github.com/rawify/BitSet.js>, <https://registry.npmjs.org/bitset> |
| bit-buffer | `bit-buffer` | inolen | `BitView`/`BitStream`, bit-level DataView; npm 0.3.0 (2025-11-04), last commit 2025-10-31 | MIT | <https://github.com/inolen/bit-buffer>, <https://registry.npmjs.org/bit-buffer> |
| @thi.ng/bitstream | `@thi.ng/bitstream` | Karsten Schmidt | "STABLE — used in production", ES6 iterator streams | Apache-2.0 | <https://www.npmjs.com/package/@thi.ng/bitstream> |

(Assessment: derived from the repositories above. The ecosystem splits cleanly into *bitset containers* (FastBitSet, BitSet.js) and *bit-stream readers/writers* (bit-buffer, @thi.ng/bitstream); no library covers both.)

## 3. Exposed APIs

**FastBitSet** (`fastbitset`) — built on `this.words = []`, an array of 32-bit integers; bit ops use `index >>> 5` for the word and `1 << index` for the offset.

- Mutation: `add(index)` (resizes then `words[index>>>5] |= 1 << index`), `remove(index)`, `flip(index)`, `checkedAdd(index)` (returns 1 if newly added), `clear()`, `trim()` (drop trailing zero words).
- Query: `has(index)`, `isEmpty()`.
- Size/iteration: `size()` (= cardinality, SWAR `hammingWeight` per word), `array()` (set-bit indices), `forEach(fnc)`, `[Symbol.iterator]()`.
- Set ops: **in-place** `intersection`, `union`, `difference` (A−B), `difference2` (B=A−B), `change` (XOR); **new-object** `new_intersection`/`new_union`/`new_difference`/`new_change`; **sizes without mutation** `intersection_size`, `union_size`, `difference_size`, `change_size`; `intersects`, `equals`, `clone`.
- Constructors: `new FastBitSet([iterable])`, `FastBitSet.fromWords(words)`; `resize(index)` allocates `(index + 32) >>> 5` words.
- Source: <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js> and the README.

**BitSet.js** (`bitset`) — arbitrary-length bit vector that "can also represent an infinite leading run of ones after complementing a value".

- Mutable, chainable, return the receiver: `set(ndx[, value=1])`, `setRange(from, to[, value=1])` (inclusive), `clear([from[, to]])`, `flip([from[, to]])`.
- Immutable, return new instances: `not()`, `and(x)`, `or(x)`, `xor(x)`, `andNot(x)`, `slice([from[, to]])`, `clone()`.
- Query: `get(ndx)`, `cardinality()`, `msb()`, `lsb()`, `ntz()`, `isEmpty()`, `equals()`, `toArray()`, `toString([base=2])`; static `BitSet.fromBinaryString`, `BitSet.fromHexString`, `BitSet.Random([n=32])`.
- Unbounded complement: `cardinality()` and `msb()` return `Infinity`, `toArray()` appends an `Infinity` sentinel, and the iterator is endless "and therefore requires an explicit stopping condition".
- Source: <https://github.com/rawify/BitSet.js>, <https://registry.npmjs.org/bitset>.

**bit-buffer** (`bit-buffer`) — `BitView` (an `ArrayBuffer` wrapper "similar to DataView, but with support for bit-level reads and writes") plus `BitStream` (maintains a current index).

- `BitView.getBits(offset, bits, signed)` / `setBits(offset, value, bits)`, shortcuts `get/set{Uint,Int}{8,16,32}`, `getFloat32/64`.
- "Reads `bits` number of bits starting at `offset`, twiddling the bits appropriately to return a proper 32-bit signed or unsigned value. **NOTE: While JavaScript numbers are 64-bit floating-point values, we don't bother with anything other than the first 32 bits.**"
- `BitStream`: `readBits(bits, signed)` / `writeBits(value, bits)`, `bitsLeft`, `index`, `readBoolean`/`writeBoolean`, typed read/write helpers, `readASCIIString`/`readUTF8String`, `readBytes`/`writeBytes`.
- **Endianness default is little-endian** (`bb.bigEndian = true` switches to big-endian) — the opposite of `DataView`'s big-endian default.
- Source: <https://raw.githubusercontent.com/inolen/bit-buffer/master/README.md>.

**@thi.ng/bitstream** — `BitOutputStream` / `BitInputStream` over `Uint8Array`, "**big endian order**", "Individual word sizes can range between 1-52 bits (in practice) and are not fixed".

- `write(value, n)` uses only the lowest `n` bits; `writeBit(0|1)`; `writeWords(iterable, size)`; generic buffer resizes ×2 on capacity; `seek(pos)` in bits.
- `read(n)` / `readBit()` / `readFields([...])` / `readStruct([["a",3],...])` / `readWords(count, size)`; `input.reader()`; `[Symbol.iterator]()` yields individual bits.
- Bounds: "By default, attempting to read beyond capacity will throw an EOF error. However, all available read methods … support an optional argument to disable bounds checking … These unsafe reads will result in undefined behavior once read past EOF."
- Barebones functional `bitWriter()` / `bitReader(bytes)` for word sizes ≤ 8 bits.
- Source: <https://www.npmjs.com/package/@thi.ng/bitstream>.

## 4. Error representation

- **Silent truncation for `Number` bitwise ops** — no error, just discarded high bits. MDN even warns that `& -1` / `<< 0` are truncation hacks, not safe integer conversion. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Bitwise_AND>, <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Left_shift>.
- **`TypeError`** when mixing `BigInt` and `Number` in an operator, when coercing a non-integer `Number` to `BigInt`, or on `JSON.stringify` of a `BigInt` (which "will raise a `TypeError`"). Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.
- **`RangeError`** from typed-array construction: bad `length`, non-integer offset, unaligned `byteOffset`/`byteLength`, or out-of-bounds view. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray>.
- **Library-level errors**: `@thi.ng/bitstream` throws an EOF error on reads past capacity unless bounds checking is explicitly disabled (→ undefined behavior). Source: <https://www.npmjs.com/package/@thi.ng/bitstream>.
- **Sentinel values**: BitSet.js returns `Infinity` for `cardinality()`/`msb()`/`ntz()` of an unbounded complement. Source: <https://github.com/rawify/BitSet.js>.

## 5. Ownership semantics

- GC-managed; no manual free. `ArrayBuffer` ownership is transferable/shared by reference — a `TypedArray` is a *view*, so several views can alias one buffer.
- A `TypedArray` that is not empty **cannot be frozen**: "`TypedArrays` that aren't empty cannot be frozen, as their underlying `ArrayBuffer` could be mutated through another `TypedArray` view of the buffer." Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray>.
- FastBitSet holds `this.words` and `clone()` copies it; `fromWords(words)` *adopts* the caller's array (no copy). Source: <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js>.
- BitSet.js is explicit about mutability: "`set()`, `setRange()`, `clear()`, and `flip()` mutate and return the receiver; bitwise operations such as `and()`, `or()`, `xor()`, `andNot()`, and `not()` return new instances." Source: <https://github.com/rawify/BitSet.js>.
- Concurrent access to a shared buffer uses `SharedArrayBuffer` + `Atomics`; `DataView`/`TypedArray` themselves are not synchronized. (Assessment: derived from the MDN TypedArray/DataView pages, which document `SharedArrayBuffer` views but no implicit locking.)

## 6. Blocking / non-blocking

Bitwise and bitset operations are synchronous and CPU-bound. There is no async/await or callback form. The only concurrency story is offloading to a **Web Worker** or using `SharedArrayBuffer` + `Atomics` (for shared-memory coordination). Sources: MDN TypedArray (<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray>) documents `SharedArrayBuffer` views; the library READMEs describe only synchronous APIs (<https://raw.githubusercontent.com/inolen/bit-buffer/master/README.md>, <https://www.npmjs.com/package/@thi.ng/bitstream>).

`bit-buffer`'s `BitStream` over a Node `Buffer` is backed by an in-memory `ArrayBuffer`, so reads do not block on I/O. (Assessment: derived from the BitStream constructor description.)

## 7. Width and ordering model

The width trap is the defining feature of the JS model:

- **`Number` bitwise = exactly 32 bits, signed.** "Numbers with more than 32 bits get their most significant bits discarded." Result is a signed 32-bit integer, so bit 31 is a sign bit. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Bitwise_AND>.
- **`Number` arithmetic = 53 safe bits.** Past `2^53 − 1` distinct integers are not representable, so bitwise-free packing of e.g. a 64-bit value into `Number` silently loses low bits. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER>.
- **`BigInt` = unbounded, signed-only.** No `>>>`, no mixing with `Number`; `BigInt.asUintN(n, x)`/`asIntN(n, x)` give explicit fixed-width truncation. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.
- **Container widths follow from the trap**: FastBitSet uses **32-bit words** precisely because `1 << index` / `|` only work up to 31; @thi.ng/bitstream documents a practical max word size of **52 bits** because "JS can only represent integers (w/o loss of precision) up to `2^53-1`". Sources: <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js>, <https://www.npmjs.com/package/@thi.ng/bitstream>. `bit-buffer` states outright it only uses the first 32 bits. Source: <https://raw.githubusercontent.com/inolen/bit-buffer/master/README.md>.
- **Bit ordering (MSB-first vs LSB-first) is a library choice, not a language one**:
  - `DataView` defaults to **big-endian** and offers a per-call `littleEndian` flag (byte order). Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView>.
  - `bit-buffer` defaults to **little-endian** (`bb.bigEndian = true` to switch). Source: <https://raw.githubusercontent.com/inolen/bit-buffer/master/README.md>.
  - `@thi.ng/bitstream` is **big-endian** order for its bit fields. Source: <https://www.npmjs.com/package/@thi.ng/bitstream>.
  - FastBitSet's index model is **LSB-first** (bit `i` lives in word `i >>> 5` at position `i & 31`). Source: <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js>.
  - Typed arrays are **platform-native byte order** only; there is no per-array bit order. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray>.
- (Assessment: derived from the sources above — JS has no single ordering convention; every bit-stream or word-packing API states its own, and they disagree.)

## 8. Bounds, overflow and growth

- **Shift amount ≥ 32**: no error — masked mod 32. `100 << 32 === 100`. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Left_shift>.
- **Index beyond 32 in a `Number` bitwise op**: silently wrong if the caller assumes a wider word (the high bits are discarded). Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Bitwise_AND>.
- **FastBitSet growth**: `add`/`flip`/`remove` call `resize(index)`, which grows `words` to `(index + 32) >>> 5` entries; repeatedly extending without a prior `resize(maxvalue)` "may be slower (possibly quadratic)". `trim()` releases trailing zero words. Source: <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js>.
- **BitSet.js `setRange` is inclusive** (`setRange(10, 18, 1)`), so range arithmetic must be explicit about inclusivity. Source: <https://github.com/rawify/BitSet.js>.
- **Typed arrays normalize silently**: out-of-range writes use fixed-width conversion (truncate fractional part, take lowest bits); `Uint8ClampedArray` clamps to 0..255 and rounds half-to-even instead. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray>.
- **Stream bounds**: `@thi.ng/bitstream` throws EOF past capacity by default and offers opt-in unchecked reads (undefined behavior); `bit-buffer`'s `getBits`/`setBits` take explicit `offset`/`bits` and do not document bounds errors. Sources: <https://www.npmjs.com/package/@thi.ng/bitstream>, <https://raw.githubusercontent.com/inolen/bit-buffer/master/README.md>.

## 9. Scalar functions, container type and bit-level I/O

JS divides the three layers as follows:

1. **Scalar functions**: only operators (`& | ^ ~ << >> >>>`), plus `Math.clz32` used for bit-scan and SWAR popcount hand-rolled per library (FastBitSet implements `hammingWeight` inline and uses `31 - Math.clz32(w & -w)` to find set bits). There are **no stdlib `popcount` / `ctz` / `rotate` / `bit_reverse` primitives**; `BigInt` adds no methods beyond `toString`/`valueOf`/`toLocaleString`. Sources: <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js>, <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.
2. **Container type**: not in the stdlib. `Set<number>` is the sparse substitute; `FastBitSet`/`BitSet.js` provide the packed container (`Uint32Array`-based or plain 32-bit word arrays). Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Set> (Set type), <https://github.com/lemire/TypedFastBitSet.js>.
3. **Bit-level I/O**: not in the stdlib. `DataView` is byte-level with explicit endianness; `bit-buffer` and `@thi.ng/bitstream` add bit-level readers/writers with an explicit/again-differing ordering. Sources: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView>, <https://raw.githubusercontent.com/inolen/bit-buffer/master/README.md>, <https://www.npmjs.com/package/@thi.ng/bitstream>.

(Assessment: derived from the above — JS has the *weakest* stdlib coverage of the three layers, which is why a two-part third-party ecosystem fills both the container and the stream gap.)

## 10. Interesting design decisions

- **32-bit signed words are a hard constraint, not a style choice** — because `1 << i` and `|` truncate to 32 bits, every correct JS bitset uses 32-bit words. FastBitSet encodes exactly that. Source: <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js>.
- **`BigInt` as the "escape hatch"** for widths > 32 / > 53, with explicit `asIntN`/`asUintN` truncation and a deliberate refusal to mix with `Number` (precision safety). Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.
- **The "infinite leading run of ones" model** in BitSet.js: complement of a finite set is well-defined but needs `Infinity` sentinels and an endless iterator. Source: <https://github.com/rawify/BitSet.js>.
- **In-place vs new-object set ops as parallel method families** (`intersection` vs `new_intersection`) with a documented performance gap, plus size-only variants that never allocate. Source: <https://github.com/lemire/FastBitSet.js>.
- **Ordering declared per library and explicitly disagreeing**: `DataView` big-endian default, `bit-buffer` little-endian default, `@thi.ng/bitstream` big-endian. Users must read each README. Sources: §7.
- **Opt-in unchecked stream reads** (`@thi.ng/bitstream`'s "pass `false` to disable bounds checking") — a deliberate escape hatch for hot paths. Source: <https://www.npmjs.com/package/@thi.ng/bitstream>.
- **`SharedArrayBuffer` + `Atomics`/Web Workers** as the only concurrency story for bit data. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray>.
- **Non-constant-time `BigInt`** — MDN explicitly warns BigInt ops are "not constant-time and are thus open to timing attacks" in cryptography. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.

## 11. Decisions NOT to copy

- **The 32-bit signed truncation of the natural operators.** A silent, sign-flipping, high-bit-discarding default is the single worst property of the JS model. A Mojo bit layer must make width explicit and reject overflow. (Assessment: derived from §7 and §8.)
- **Mod-32 shift masking.** `x << 32 == x` turns an off-by-one shift into silent data loss; Mojo should treat shift ≥ width as either a compile error or an explicit `raises`. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Left_shift>.
- **The 53-bit precision ceiling on the "normal" numeric path.** Two integer widths (32 for bitwise, 53 for arithmetic) that no API states at the call site is a trap. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER>.
- **`BigInt`'s signed-only model with no unsigned shift.** Making every value conceptually sign-extended to infinity is elegant but forbids a clean unsigned domain. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.
- **Library-specific ordering conventions that disagree and are not part of the value's type.** `DataView` big-endian vs `bit-buffer` little-endian vs `@thi.ng/bitstream` big-endian means silent interoperability bugs. Sources: §7.
- **"Infinite complement" semantics** — `Infinity` cardinality, endless iterators and `Infinity` sentinels push the problem to the caller. Source: <https://github.com/rawify/BitSet.js>.
- **Opt-in undefined behavior for unchecked reads.** An API that can silently read garbage past EOF is not a contract. Source: <https://www.npmjs.com/package/@thi.ng/bitstream>.
- **`BigInt` for cryptographic bit work** — non-constant-time operations. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.

## 12. Ideas fitting Mojo

- **Word-based packed container with an explicit growth policy.** FastBitSet's `resize(index)`/`trim()` pair (grow on demand, shrink trailing zeros) is a clean, testable policy. Source: <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js>.
- **In-place vs pure set-operation families, plus size-only variants** (`intersection` / `new_intersection` / `intersection_size`) map well to Mojo's ownership model: `inout self` vs returning a new value, and a `cardinality`-style query without allocation. Source: <https://github.com/lemire/FastBitSet.js>.
- **Explicit endianness/bit-order parameter on bit-stream I/O**, as `DataView`'s per-call flag models — no hidden convention. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView>.
- **Bit-level reader/writer over a byte buffer with a moving index** (`readBits`/`writeBits`, `bitsLeft`) is the right shape for Mojo's bit-level stream layer; bit-buffer's `getBits(offset, bits, signed)` is the closest single-call bitfield API. Source: <https://raw.githubusercontent.com/inolen/bit-buffer/master/README.md>.
- **`asIntN`/`asUintN` as explicit, named truncation** rather than implicit coercion — a good precedent for a Mojo `truncate`/`sign_extend` pair. Source: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.
- **Set-bit enumeration as a first-class API** (`array()`, `forEach`, iterator, `Math.clz32` low-bit extraction) — a bitset is only ergonomic if iterating set bits is cheap. Source: <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js>.
- **A 52/53-bit ceiling must be a documented, enforced limit** if any single-word API is offered; better: fixed widths (`UInt8`/`UInt64`) from the start. Source: <https://www.npmjs.com/package/@thi.ng/bitstream>.

## Sources

- MDN bitwise semantics: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Bitwise_AND>, <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Operators/Left_shift>.
- MDN BigInt: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>.
- MDN Number.MAX_SAFE_INTEGER: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Number/MAX_SAFE_INTEGER>.
- MDN TypedArray: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/TypedArray>.
- MDN DataView: <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/DataView>.
- FastBitSet.js: <https://github.com/lemire/FastBitSet.js>, <https://github.com/lemire/FastBitSet.js/blob/master/FastBitSet.js>, <https://github.com/lemire/TypedFastBitSet.js>.
- BitSet.js: <https://github.com/rawify/BitSet.js>, <https://registry.npmjs.org/bitset>.
- bit-buffer: <https://github.com/inolen/bit-buffer>, <https://raw.githubusercontent.com/inolen/bit-buffer/master/README.md>.
- @thi.ng/bitstream: <https://www.npmjs.com/package/@thi.ng/bitstream>.
- Mojo positioning: `mojov1/stdlib/bit`, `akku/prim_bit/_dev/README.md`.
