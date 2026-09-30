# bit research: python

## 1. Standard library support

Python's standard library has **no bitset/bit-array container**. Bit work is done on the unbounded built-in `int`; the only bit-specific library types are the flag enumerations in `enum` and the low-level `ctypes` bit-fields.

- **`int` is arbitrary precision** — "Integers have unlimited precision." Source: <https://docs.python.org/3/library/stdtypes.html#numeric-types-int-float-complex>.
- **Operators**: `|`, `^`, `&`, `<<`, `>>`, `~`. The result is computed "as though carried out in two's complement with an **infinite** number of sign bits." Negative shift counts raise `ValueError`; `x << n` is multiplication by `2**n`, `x >> n` is floor division by `2**n`. Source: <https://docs.python.org/3/library/stdtypes.html#bitwise-operations-on-integer-types>.
- **Scalar methods on `int`**:
  - `int.bit_length()` — number of bits excluding sign and leading zeros; `0` for zero. Added 3.1. Source: <https://docs.python.org/3/library/stdtypes.html#int.bit_length>.
  - `int.bit_count()` — population count of `abs(x)`. Added 3.10. Source: <https://docs.python.org/3/library/stdtypes.html#int.bit_count>.
  - `int.to_bytes(length=1, byteorder='big', *, signed=False)` — `OverflowError` if not representable in `length` bytes. Source: <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.
  - `int.from_bytes(bytes, byteorder='big', *, signed=False)`. Source: <https://docs.python.org/3/library/stdtypes.html#int.from_bytes>.
- **`enum.Flag` / `enum.IntFlag`** are the stdlib flag-set abstraction: "its members support the bitwise operators `&`, `|`, `^`, and `~`; the results of those operations are (aliases of) members of the enumeration." `auto` yields powers of two for `Flag`. Added 3.6. Source: <https://docs.python.org/3/library/enum.html#flag>.
- **`enum.FlagBoundary`** (3.11) controls out-of-range results: `STRICT` raises `ValueError` (default for `Flag`), `CONFORM` drops invalid bits, `EJECT` reverts to `int`, `KEEP` keeps them (default for `IntFlag`). Source: <https://docs.python.org/3/library/enum.html#flagboundary>.
- **`ctypes` bit-fields** exist in `Structure`/`Union` `_fields_` tuples (third item = bit width), but "bit field allocation and layout in memory are not defined as a C standard; their implementation is compiler-specific", and structs with bit-fields must be passed by pointer. Source: <https://docs.python.org/3/library/ctypes.html#bit-fields-in-structures-and-unions>.
- **No stdlib bit-level stream reader/writer.** (Assessment: derived from the stdlib index — `struct` and `io` operate on whole bytes, not bit offsets.)

Security note: since 3.11 integer↔string conversion is limited by default (`sys.set_int_max_str_digits`, `sys.flags.int_max_str_digits`) because huge-decimal parsing is quadratic. Source: <https://docs.python.org/3/library/sys.html#sys.set_int_max_str_digits>. This does not limit bit operations, only decimal string conversion.

## 2. Relevant community libraries

| library | maintainer | maturity | license | source |
| --- | --- | --- | --- | --- |
| `bitarray` | Ilan Schnell | mature, 3.11.0, 654 unit tests, wheels for all major platforms | PSF-style (see LICENSE) | <https://github.com/ilanschnell/bitarray>, <https://github.com/ilanschnell/bitarray/blob/master/LICENSE> |
| `bitstring` | Scott Griffiths | mature, docs v4.3, `Bits`/`BitArray`/`BitStream` | MIT | <https://github.com/scott-griffiths/bitstring>, <https://github.com/scott-griffiths/bitstring/blob/master/LICENSE> |
| `numpy.packbits`/`unpackbits` | NumPy devs | mature, in NumPy core | BSD | <https://numpy.org/doc/stable/reference/generated/numpy.packbits.html> |

Note: `enum.auto`/`enum.Flag` is **not** a community library but CPython's own
stdlib (§1), and is therefore not listed here. (Assessment: derived from the
repositories/licenses above. `bitarray` and `bitstring` are the two reference
container/stream designs; NumPy is the reference *packing* design.)

## 3. Exposed APIs

**`bitarray.bitarray(initializer=0, /, endian='big', buffer=None)`** — sequence of bits, 8 bits per byte in C. Source: <https://raw.githubusercontent.com/ilanschnell/bitarray/master/README.rst>.

- Construction: `int` length (zeros), `bytes`/`bytearray` (direct buffer), `str` of 0/1, iterable of 0/1, or `buffer=` (buffer protocol).
- Sequence: indexing (single index → `int`, slice → `bitarray`), slice assignment to booleans or bitarray, `del`, `+`, `*`, `+=`, `*=`, `in`, `len`.
- Bitwise: `~ & | ^ << >>` and in-place `&= |= ^= <<= >>=`.
- Search/set-bit iteration: `search(sub, start, stop, right=False)` returns an iterator over match indices (e.g. `a.search(1)` iterates active bits), `find`, `index`, `count(value, start, stop, step)` (may count a sub-bitarray).
- Misc: `setall(value)`, `all()`, `any()`, `invert([index])`, `reverse()`, `sort()`, `rotate(k)`, `fill()` (pad to byte multiple, returns bits added), `copy()`, `clear()`, `remove`, `pop`, `insert`, `extend`, `to01()`, `tolist()`, `tobytes()`/`tofile()`, `frombytes()`/`fromfile()`, `unpack()`, `pack()`, `encode`/`decode` (prefix codes), `buffer_info()`, descriptors `endian`, `nbytes`, `padbits`, `readonly`.
- `bitarray.util`: `int2ba(int, length=None, endian=None, signed=False)` (raises `OverflowError` if not representable), `ba2int(a, signed=False)`, `ba2hex`/`hex2ba`, `ba2base`/`base2ba`, `count_n`, `parity`, `subset`, `intervals`, `zeros`/`ones`, `random_p`/`random_k`/`urandom`, `serialize`/`deserialize`, Huffman helpers, RLE codecs.
- Also `frozenbitarray` (immutable, hashable) and `decodetree`.
- Source: README.rst sections above, <https://raw.githubusercontent.com/ilanschnell/bitarray/master/README.rst>.

**`bitstring`** — `Bits` (immutable), `BitArray` (mutable), `ConstBitStream` / `BitStream` (stream with `pos`).

- `BitArray` methods: `append`, `prepend`, `insert(bs, pos)`, `overwrite(bs, pos)`, `set(value, pos=None)` (single index or iterable; `range` is a fast special case), `invert([pos])`, `reverse([start,end])`, `rol(bits)`, `ror(bits)` (negative → `ValueError`), `replace(old, new, ...)`, `byteswap(fmt=...)` (returns swap count), `clear`, `__setitem__` / `__delitem__`, in-place `&= |= ^=` (raise `ValueError` on length mismatch), `<<=`/`>>=`.
- Interpretation properties with optional bit-length suffix and byte-order suffix: `bin`, `hex` (must be multiple of 4 bits), `oct` (multiple of 3), `uint`, `int` (two's complement), `uintbe`/`uintle`/`uintne`, `intbe`/`intle`/`intne`, `float`, `floatle`, `bytes` (multiple of 8); single-letter aliases (`u`, `i`, `f`, …) and length-suffixed forms like `u8`, `floatle32`. Source: <https://bitstring.readthedocs.io/en/stable/interpretation.html>.
- Stream API: `ConstBitStream.read(fmt)` / `readlist(fmt)` / `peek` / `peeklist` / `readto`, `pos`/`bitpos`/`bytepos` (bytepos raises `ByteAlignError` when not byte-aligned), `bytealign()`. Format tokens include `uintN`, `intN`, `uintleN`, `hexN`, `binN`, `bitsN`, `padN`, exponential-Golomb (`ue`/`se`), and one "stretchy" token per readlist. Reading past the end raises `ReadError`. Source: <https://bitstring.readthedocs.io/en/stable/constbitstream.html>.

**`numpy.packbits(a, /, axis=None, bitorder='big')`** — packs a binary-valued array into `uint8`; padded with zero bits at the end; `bitorder='big'` mimics `bin(val)` (`[0,0,0,0,0,0,1,1] => 3`), `'little'` reverses it (`[1,1,0,0,0,0,0,0] => 3`). `unpackbits` is the inverse. Source: <https://numpy.org/doc/stable/reference/generated/numpy.packbits.html>.

## 4. Error representation

Python uses **exceptions**, not error codes or sentinels.

- Out-of-range index / slice assignment length mismatch → `IndexError` / `ValueError`. (Source: `bitstring.BitArray.set` / `invert` docs — "will raise `IndexError` if `pos < -len(s)` or `pos > len(s)`", <https://bitstring.readthedocs.io/en/stable/bitarray.html>.)
- Negative shift / negative rotate → `ValueError`. Source: <https://docs.python.org/3/library/stdtypes.html#bitwise-operations-on-integer-types> and <https://raw.githubusercontent.com/ilanschnell/bitarray/master/README.rst>.
- Value does not fit the requested width → `OverflowError` (`int.to_bytes`, `int2ba`). Source: <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>, README.rst.
- Unambiguous-interpretation failure (`bitstring`) → `InterpretError` (`hex` on non-4-bit multiple), `CreationError` (bad length/type), `ReadError` (past end), `ByteAlignError`. Source: <https://bitstring.readthedocs.io/en/stable/interpretation.html>, <https://bitstring.readthedocs.io/en/stable/constbitstream.html>.
- `enum.Flag` invalid values → `ValueError` under `boundary=STRICT`; `KEEP` silently retains unnamed bits. Source: <https://docs.python.org/3/library/enum.html#flagboundary>.

## 5. Ownership semantics

- Everything is reference-counted / garbage-collected; no manual free. `int` is immutable.
- `bitarray` objects **own their buffer**, but support the **buffer protocol** in both directions: a bitarray can wrap another object's writable buffer (`buffer=` constructor) or memory-mapped file, and can export its own. Source: <https://raw.githubusercontent.com/ilanschnell/bitarray/master/README.rst>.
- `frozenbitarray` is immutable and hashable (usable as a dict key); `bitarray` is mutable. Source: README.rst.
- `bitstring`: `Bits`/`ConstBitStream` immutable, `BitArray`/`BitStream` mutable; `pos` is not part of identity and "will be reset to zero if a bitstring is copied". Source: <https://bitstring.readthedocs.io/en/stable/constbitstream.html>.
- `enum.Flag` members are immutable singletons. Source: <https://docs.python.org/3/library/enum.html#flag>.

## 6. Blocking / non-blocking

Bit operations are synchronous, CPU-bound, in-memory — there is no non-blocking/async model. (Assessment: derived from the APIs above, which take values in and return values, with no awaitable/callback forms.)

The only I/O coupling is stream construction: `bitarray.fromfile(f, n)` reads from a binary stream and raises `EOFError` if fewer than `n` bytes are available; `bitstring.BitStream` may be backed by a file and load lazily, so reads can block on disk. Source: <https://raw.githubusercontent.com/ilanschnell/bitarray/master/README.rst>, <https://bitstring.readthedocs.io/en/stable/constbitstream.html>.

## 7. Width and ordering model

- **`int` has no fixed width** — arbitrary precision, and the bit model is "infinite two's complement", i.e. `~x == -x-1` for any size. Source: <https://docs.python.org/3/library/stdtypes.html#bitwise-operations-on-integer-types>. There is no overflow on shifts or bitwise ops; the value simply grows. (Assessment: derived from unlimited precision + infinite sign bits.)
- **Width must be stated explicitly** when materialising to bytes/bits: `int.to_bytes(length)` and `int2ba(int, length=None)` need a length, and `ba2int`/`from_bytes` need a byte order. Without a length the natural form is minimal (no leading zeros for big-endian; no trailing zeros for little-endian, per `int2ba` docs).
- **Two independent ordering axes**:
  1. **Bit order inside a byte/word** — `bitarray`'s `endian='big'|'little'` is a *property of the object*, fixed at creation: big-endian = "most-significant bit comes first", `a[0]` is the most significant bit of the first byte; little-endian reverses the index→significance mapping. Comparison ignores endianness (index→bit mapping matters); bitwise operators **cannot mix endianness**. Source: <https://raw.githubusercontent.com/ilanschnell/bitarray/master/doc/endianness.rst>.
  2. **Byte order** — `byteorder='big'|'little'` on `int.to_bytes`/`from_bytes`, and `uintbe`/`uintle`/`uintne` in `bitstring`. Source: <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>, <https://bitstring.readthedocs.io/en/stable/interpretation.html>.
- **`bitarray` shift direction is index-based, not endian-based**: "regardless of bit-endianness the bitarray left shift (`<<`) always shifts towards lower indices, and the right shift (`>>`) always shifts towards higher indices." Source: README.rst — i.e. `<<` lowers significance in the big-endian reading.
- `numpy` makes ordering an explicit per-call argument (`bitorder='big'|'little'`), default big. Source: <https://numpy.org/doc/stable/reference/generated/numpy.packbits.html>.
- `enum.Flag` has an implicit machine width (the integer's width); `~` returns only the flags named in the class, not an infinite complement. Source: <https://docs.python.org/3/library/enum.html#flag>.

## 8. Bounds, overflow and growth

- **`int`**: no overflow, no growth policy — values grow as needed. Negative shift counts are illegal (`ValueError`); shift amounts ≥ bit width are fine and simply produce large/zero values. Source: <https://docs.python.org/3/library/stdtypes.html#bitwise-operations-on-integer-types>.
- **`bitarray` shifts**: "the length of the bitarray is never changed by any shift operation; blanks are filled by 0; negative shifts raise `ValueError`; shifts larger or equal to the length of the bitarray result in bitarrays with all values 0." Source: <https://raw.githubusercontent.com/ilanschnell/bitarray/master/README.rst>.
- **`bitarray` growth**: constructed with an `int` length up front; `append`/`extend`/`frombytes` grow it; `int2ba`/`to_bytes` raise `OverflowError` when a value does not fit the requested width. Source: README.rst.
- **Index bounds**: `set`/`invert` raise `IndexError` when `pos < -len(s)` or `pos > len(s)`; negative indices follow slice rules. Source: <https://bitstring.readthedocs.io/en/stable/bitarray.html>.
- **`bitstring`**: length-specific getters raise `InterpretError` if the length does not match (e.g. `hex` on a 3-bit string); setters without a length raise `ValueError` if the value does not fit. Source: <https://bitstring.readthedocs.io/en/stable/interpretation.html>.
- **Integer string limit**: decimal conversion of huge ints is capped by default (DoS mitigation) → `ValueError` past the limit. Source: <https://docs.python.org/3/library/sys.html#sys.set_int_max_str_digits>.

## 9. Scalar functions, container type and bit-level I/O

Python spreads the three layers over different places:

1. **Scalar functions** live on `int` itself: `bit_length()`, `bit_count()`, plus the operators and `to_bytes`/`from_bytes`. There is **no stdlib `count_leading_zeros`/`count_trailing_zeros`/`rotate`/`bit_reverse`**; those are reimplemented per project (or come from `numpy.bitwise_count`, <https://numpy.org/doc/stable/reference/generated/numpy.bitwise_count.html>). (Assessment: derived from `int` method list at <https://docs.python.org/3/library/stdtypes.html#additional-methods-on-integer-types>.)
2. **Container type**: not in the stdlib for bits; `enum.Flag` is a named *flag set* but not a general bitset. The bitset container arrives via `bitarray.bitarray` / `bitstring.BitArray`, or via a plain `int` used as a bitmask. (Assessment: derived from §1 and §2.)
3. **Bit-level I/O**: no stdlib support; `bitstring.BitStream`/`ConstBitStream` provide `read`/`peek`/`readlist` with bit-exact positions and format strings, and `bitarray.fromfile`/`tofile` handle whole-byte streams. `numpy.packbits`/`unpackbits` convert between bit arrays and `uint8`. Source: §1/§3.

Ordering is a per-call or per-object parameter in every case (`bitorder=`, `endian=`, `byteorder=`), never a single global convention.

## 10. Interesting design decisions

- **Arbitrary-precision int as the default bit carrier** — no width, no overflow, infinite two's complement. Clean semantics, but no packed storage: a 1 000 000-bit mask is a ~125 KB int with big-int arithmetic costs, versus `bitarray`'s 125 KB buffer with word-parallel bitwise ops. (Assessment: derived from §1 and the `bitarray` "eight bits are represented by one byte in a contiguous block of memory" statement, README.rst.)
- **`bit_count()` on `abs(x)`** — "Return the number of ones in the binary representation of the absolute value", so `(-n).bit_count() == n.bit_count()`. Source: <https://docs.python.org/3/library/stdtypes.html#int.bit_count>.
- **`search()` returns an iterator of set-bit indices**, making active-bit enumeration a first-class, optimized operation rather than a scan. Source: README.rst.
- **Ordering as an explicit, immutable object property** (`bitarray.endian`) — comparison ignores it, but bitwise ops forbid mixing. Source: <https://raw.githubusercontent.com/ilanschnell/bitarray/master/doc/endianness.rst>.
- **`numpy`'s `bitorder` parameter** makes packing order a per-call choice with a well-documented default (`'big'` mimics `bin(val)`), avoiding a hidden convention. Source: <https://numpy.org/doc/stable/reference/generated/numpy.packbits.html>.
- **`enum.FlagBoundary`** models the out-of-range question as an explicit policy (`STRICT`/`CONFORM`/`EJECT`/`KEEP`) instead of leaving it undefined. Source: <https://docs.python.org/3/library/enum.html#flagboundary>.
- **`bitstring` length-suffixed properties** (`u8`, `floatle32`, `i7`): reading asserts the length, writing sets it — one syntax for both width check and width selection. Source: <https://bitstring.readthedocs.io/en/stable/interpretation.html>.
- **`frozenbitarray` vs `bitarray`** — immutability/hashability is a separate type, not a flag. Source: README.rst.

## 11. Decisions NOT to copy

- **Arbitrary-precision integers as the primary bitset representation.** It defeats the packed-word model and makes per-bit cost and memory unpredictable. Mojo needs a fixed-width word-based container. (Assessment: derived from §1, §10.)
- **No declared width for a bit value.** Python's "infinite sign bits" means `~x` is always negative and `bit_length()` is the only width signal; a Mojo bitfield API must take an explicit `[hi:lo]`/width. (Assessment: derived from §7.)
- **Making bit-order an immutable property of a container that bitwise ops refuse to mix** (`bitarray.endian`). Two incompatible objects that compare equal is a trap; ordering should be explicit at the read/write boundary. (Assessment: derived from <https://raw.githubusercontent.com/ilanschnell/bitarray/master/doc/endianness.rst>.)
- **Silent length-changing semantics around shifts** — in Python the container's length never changes and over-shift yields all zeros; this hides a likely bug. (Assessment: derived from README.rst.)
- **`ctypes` bit-field layout** — explicitly compiler-specific and not passable by value; never a portable contract. Source: <https://docs.python.org/3/library/ctypes.html#bit-fields-in-structures-and-unions>.
- **`enum.Flag`'s unbounded complement semantics / unnamed-bit handling complexity** — `~` only yields named flags, and boundary policy changes what out-of-range means; too much conceptual weight for a low-level bit library. (Assessment: derived from §1, §7.)
- **`bitarray`'s per-object endian plus buffer-protocol wrapping** — powerful but a large surface; not needed for a leaf bit library. (Assessment: derived from §5.)

## 12. Ideas fitting Mojo

- **Wrap the `std.bit` scalar functions** rather than rebuild them: Python shows the scalar layer belongs on the integer type itself (`bit_count`, `bit_length`) — in Mojo that is `std.bit`, which already ships `bit_not`, `bit_reverse`, `bit_width`, `byte_swap`, `count_leading_zeros`, `count_trailing_zeros`, `log2_ceil`, `log2_floor`, `next_power_of_two`, `prev_power_of_two`, `pop_count`, `rotate_bits_left`, `rotate_bits_right`, plus `mask.is_negative` and `mask.splat` — unstable by default. Source: `mojov1/stdlib/bit`, <https://mojolang.org/docs/std/bit/>.
- **Explicit `bitorder` / `endian` parameter with a documented default**, as in `numpy.packbits` — matches Mojo's preference for predictable, stated conventions. Source: <https://numpy.org/doc/stable/reference/generated/numpy.packbits.html>.
- **`search()`/set-bit iterator**: an iterator over set-bit indices is the ergonomic core of a bitset and maps well to Mojo's value/iterator model. Source: README.rst.
- **A boundary/policy concept for out-of-range writes** (`STRICT` raise vs silent mask), expressed as `raises` in Mojo: Python's `FlagBoundary` is evidence that users want to *choose*. Source: <https://docs.python.org/3/library/enum.html#flagboundary>.
- **Length-suffixed accessors / explicit `[hi:lo]` get/set** for bitfields — the `u8`/`i7` idea generalises directly to `get_bits(value, hi, lo)` / `set_bits`. Source: <https://bitstring.readthedocs.io/en/stable/interpretation.html>.
- **Immutable vs mutable split** (`frozenbitarray` vs `bitarray`, `Bits` vs `BitArray`) — Mojo can express immutability in the type system rather than at runtime. Source: README.rst, <https://bitstring.readthedocs.io/en/stable/constbitstream.html>.
- **`OverflowError`-style check when a value does not fit a stated width** → a Mojo `raises` on `set_bits`/`to_bytes`. Source: <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>.

## Sources

- Python built-in types / bitwise ops / int methods: <https://docs.python.org/3/library/stdtypes.html#bitwise-operations-on-integer-types>, <https://docs.python.org/3/library/stdtypes.html#additional-methods-on-integer-types>, <https://docs.python.org/3/library/stdtypes.html#int.bit_count>, <https://docs.python.org/3/library/stdtypes.html#int.bit_length>, <https://docs.python.org/3/library/stdtypes.html#int.to_bytes>, <https://docs.python.org/3/library/stdtypes.html#int.from_bytes>.
- `enum`: <https://docs.python.org/3/library/enum.html>, <https://docs.python.org/3/library/enum.html#flag>, <https://docs.python.org/3/library/enum.html#flagboundary>.
- `ctypes` bit fields: <https://docs.python.org/3/library/ctypes.html#bit-fields-in-structures-and-unions>.
- `sys` int string limit: <https://docs.python.org/3/library/sys.html#sys.set_int_max_str_digits>.
- `bitarray`: <https://github.com/ilanschnell/bitarray>, <https://raw.githubusercontent.com/ilanschnell/bitarray/master/README.rst>, <https://raw.githubusercontent.com/ilanschnell/bitarray/master/doc/endianness.rst>, <https://github.com/ilanschnell/bitarray/blob/master/LICENSE>.
- `bitstring`: <https://bitstring.readthedocs.io/en/stable/bitarray.html>, <https://bitstring.readthedocs.io/en/stable/constbitstream.html>, <https://bitstring.readthedocs.io/en/stable/interpretation.html>, <https://github.com/scott-griffiths/bitstring/blob/master/LICENSE>.
- NumPy packing: <https://numpy.org/doc/stable/reference/generated/numpy.packbits.html>, <https://numpy.org/doc/stable/reference/generated/numpy.unpackbits.html>, <https://numpy.org/doc/stable/reference/generated/numpy.bitwise_count.html>.
- Mojo positioning: `mojov1/stdlib/bit`, `akku/prim_bit/_dev/README.md`.
