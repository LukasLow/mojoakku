# bit research: Julia

Julia version basis: current manual (`docs.julialang.org/en/v1`) and `JuliaLang/julia` master.
Julia's distinguishing trait is that **bitsets are first-class collections** (`BitArray`,
`BitSet`) with the full generic collection surface (iteration, `findall`, set algebra),
while scalar bit functions are methods on `Integer` and bit-level stream I/O is *not* in
the stdlib.

## 1. Standard library support

- **Packed boolean container:** `BitArray{N} <: AbstractArray{Bool, N}` — a bit-packed
  boolean N-D array, "pack up to 64 values into every 8 bytes", returned by default from
  broadcasts producing booleans, `trues` and `falses`. `BitVector = BitArray{1}`,
  `BitMatrix = BitArray{2}`. Source: <https://docs.julialang.org/en/v1/base/arrays/>,
  `base/bitarray.jl#L7-L23`; aliases in `base/bitarray.jl`.
- **Dense integer set:** `BitSet <: AbstractSet{Int}` — "Construct a sorted set of `Int`s
  ... Implemented as a bit string, and therefore designed for dense integer sets. If the
  set will be sparse ... use `Set` instead." Source:
  `base/bitset.jl#L25-L32`, <https://docs.julialang.org/en/v1/base/collections/>.
  Internally `mutable struct BitSet <: AbstractSet{Int}` holds `bits::Vector{UInt64}` and
  an `offset::Int` ("1st stored Int equals 64*offset"); an empty set uses the sentinel
  `NO_OFFSET`. Source: `base/bitset.jl`.
- **Scalar integer bit functions** (all in `Base`, in `base/int.jl`): binary operators
  `~`, `&`, `|`, `xor`, `<<`, `>>`, `>>>`; and query/transform functions `count_ones`,
  `count_zeros`, `leading_zeros`, `leading_ones`, `trailing_zeros`, `trailing_ones`,
  `top_set_bit`, `bswap`, `bitreverse`, `bitrotate`, plus `bitstring(n)`. Sources:
  <https://docs.julialang.org/en/v1/base/math/> (shift/rotate),
  <https://docs.julialang.org/en/v1/base/numbers/> (counts, `bswap`, `bitstring`),
  `base/int.jl`.
- **No stdlib bitfield `[hi:lo]` get/set.** There is no `get_bits`/`set_bits` over an
  arbitrary bit range in `Base`; only mask/shift expressions the caller writes by hand.
  (Assessment: derived from the absence of such a function in the `Base` integer API
  listed above; the closest helpers are `masked`-style utilities in third-party packages,
  §2.)
- **No stdlib bit-level stream I/O.** `Base` offers byte-level `read`/`write`/`IOBuffer`,
  `ntoh`/`hton`/`ltoh`/`htol` for *byte* order, and `reinterpret` for type-punning, but no
  bit reader/writer. Sources: <https://docs.julialang.org/en/v1/base/io-network/>,
  `base/iobuffer.jl`, `base/reinterpretarray.jl`.

## 2. Relevant community libraries

| package | what | notes |
| --- | --- | --- |
| **BitOperations.jl** (oschulz) | Bit/register operations, "intended for Julia code that needs to communicate with hardware ... or work with intricate binary data formats" | MIT, maintained; docs at <https://oschulz.github.io/BitOperations.jl/stable/> |
| **BitBasis.jl** (QuantumBFS) | Bit-string literals `bit"11100"` over an integer buffer, `readbit`, `bmask`, masked ops, `bitarray`/`packbits` with stdlib `BitArray` | <https://yaoquantum.org/BitBasis.jl/dev/tutorial.html> |
| **FixedSizeBitVector.jl** (claud10cv) | `BitVectorX` structs for X ∈ {8,16,...,4096}, fixed at compile time; `|`, `&`, `⊻`, `flip`, `count_ones`, `any`, `none`, `issubset` | <https://github.com/claud10cv/FixedSizeBitVector.jl> |
| **PackedStructs.jl** (JuliaData) | `@packed` macro packing sub-byte integer fields; logical widths; `Pad{N}`; `pack`/unpack | <https://github.com/JuliaData/PackedStructs.jl> |
| **Bits.jl** (ma-laforge) | `bit`, `bits`, `bitsize`, `low0`, `low1`, `mask`, `masked`, `scan0`, `scan1`, `tstbit`, `weight`; index convention debated (0- vs 1-based) | listed at <https://juliapackages.com/p/bits>; docstrings <https://docs.juliahub.com/Bits/nwkk8/0.2.0/autodocs/> (link 404 at time of writing) |
| **BitPermutations.jl** | Bit-permutation networks using `bitreverse`/shifts | <https://juliapackages.com/p/bitpermutations> |

**Non-Julia cross-reference (not a Julia package).** `novolang/bitstream-nv` is
listed here only as an ordering-API signal for §12: it is **not Julia**, but a
separate implementation with an explicit LSB-first vs MSB-first constructor
argument. Source: <https://github.com/novolang/bitstream-nv> — **not Julia** (see §10/§11).

## 3. Exposed APIs

**Scalar (on `Integer`; `Int8..Int128`, `UInt8..UInt128`, `Bool`)** — `base/int.jl`,
docs in §1:
- `count_ones(x)::Int`, `count_zeros(x) = count_ones(~x)`,
  `leading_zeros(x)`, `leading_ones(x) = leading_zeros(~x)`,
  `trailing_zeros(x)`, `trailing_ones(x) = trailing_zeros(~x)`.
  Example: `leading_zeros(Int32(1)) == 31`, `count_ones(Int32(-1)) == 32`.
- `top_set_bit(x)` = `8*sizeof(x) - leading_zeros(x)`, i.e. width excluding leading zeros.
- `bswap(n)` reverses byte order; `bitreverse(x)` reverses all bits (requires fixed width).
- `bitrotate(x, k)` rotates left by `k`, negative `k` rotates right; `k` is reduced mod
  the type width (`(sizeof(T)<<3 - 1) & k` in the implementation).
- `~`, `&`, `|`, `xor`, `<<`, `>>`, `>>>` (function names `~`, `&`, `|`, `xor`).
- `bitstring(n)` returns the literal bits **big-endian** ("most-significant bit first").
- `unsigned(x)`/`signed(x)` reinterpret same-width signed↔unsigned without checking.

**Container `BitArray`/`BitVector`/`BitMatrix`** — `base/bitarray.jl`,
<https://docs.julialang.org/en/v1/base/arrays/>:
- Constructors `BitArray(undef, dims...)`, `BitArray(itr)`, `BitVector()` (empty),
  `BitVector(::Tuple{Vararg{Bool}})`, `BitVector(::BitArray)` (copy); `trues(dims)`,
  `falses(dims)`.
- `chunks::Vector{UInt64}`, `len::Int`, `dims::NTuple{N,Int}` (public fields; `reinterpret`
  workarounds mutate `B.chunks`).
- Indexing `B[i]`/`B[i]=x` (bounds-checked), vector growth `push!`, `pushfirst!`, `pop!`,
  `popfirst!`, `append!`, `prepend!`, `insert!`, `deleteat!`, `splice!`, `resize!`,
  `sizehint!`, `empty!`.
- Collection algebra over chunks: `map(~/&/|/xor/nand/nor/... , A[,B])`, `all`, `any`,
  `count`, `findall`, `findfirst`, `findnext`, `findprev`, `findmax`, `findmin`,
  `filter`, `hcat`/`vcat`, `circshift!`, `reverse`/`reverse!` (uses `bitreverse` on
  chunks), `<<`/`>>`/`>>>` on the whole vector, `==` (compares `chunks`).
- `sum(BitArray)` = `count(B)` (documented as `_sum(B, ::Colon) = count(B)`).
- Invariant documented in the file: "bits are stored in contiguous chunks; unused bits
  must always be set to 0" (`base/bitarray.jl` header comment).

**Container `BitSet`** — `base/bitset.jl`:
- `BitSet([itr])`, `push!`, `push!(s, ns...)`, `pop!(s)`, `pop!(s, n)`,
  `pop!(s, n, default)`, `popfirst!`, `delete!`, `empty!`, `isempty`, `sizehint!`,
  `copy`/`copy!`/`copymutable`.
- Set algebra: `union`/`union!`, `intersect`/`intersect!`, `setdiff`/`setdiff!`,
  `symdiff!`, implemented via `_matched_map!(|/&/(p,q)->p&~q/xor, ...)` across the two
  `bits` arrays (word-parallel).
- `in` → `_bits_getindex`; `iterate` (ascending, skips zero words via `trailing_zeros`);
  `first`, `last`, `minimum`, `maximum`, `extrema`, `issubset`, `⊊`, `length(s) =
  bitcount(s.bits)`, `==`, `issorted(s) = true`.

**Bitfield-style (community, BitOperations.jl)** — bit indices start at **zero** and
ranges are `UnitRange` counting up from the LSB:
- "Bit indices start at zero: `bmask(Int, 0) == 0x01`"; "Bit ranges also start at zero ...
  `bset(0x00, 0:7, 1) == 0xff`"; "Bit ranges must be of type `UnitRange` ... reverse
  indices are not supported." Source: <https://oschulz.github.io/BitOperations.jl/stable/>.
- Functions: `bsizeof`, `bmask`, `lsbmask`, `msbmask`, `bget`, `bset`, `bclear`, `bflip`,
  `lsbget`, `msbget`; plus protobuf-compatible `zigzagenc`/`zigzagdec`.

**Bit-string (community, BitBasis.jl)**: `bit"11100"` (`DitStr{2,5,Int64}`), integer
buffer in **little-endian order** ("integer `28` represents the bit string `11100`"),
`readbit(x, positions...)`, `bmask`, `btruncate`, `breflect`, `bdistance`,
`bitarray(integers, nbits)` and `packbits(...)` bridging to stdlib `BitArray`.
Source: <https://yaoquantum.org/BitBasis.jl/dev/tutorial.html>.

## 4. Error representation

Julia uses **exceptions**, not error codes or `Result`:
- Out-of-range index → `BoundsError`, thrown by `checkbounds` in `getindex`/`setindex!`
  (`base/bitarray.jl`); `copyto!`/`append!` check lengths and throw `BoundsError` or
  `DimensionMismatch`.
- Empty-container reductions → `ArgumentError`: `BitSet.first`/`last` call
  `_throw_bitset_notempty_error()` → `ArgumentError("collection must be non-empty")`;
  `minimum`/`maximum`/`findmax`/`findmin` on empty `BitArray` throw
  `ArgumentError("... must be non-empty")` (also generic `reduce` over empty without
  `init`). Source: `base/bitset.jl`, `base/bitarray.jl`,
  <https://docs.julialang.org/en/v1/base/collections/>.
- Infinite iterator into `BitArray` → `ArgumentError("infinite-size iterable used in
  BitArray constructor")` (`base/bitarray.jl`).
- `pop!(::BitSet, n)` without `default` on an absent key → `KeyError(n)`; the 3-arg form
  returns the default (`base/bitset.jl`).
- Shift semantics are **defined**, not errors: negative `n` flips direction
  (`x << n == x >> -n`); for `>>` on signed values "filling with ... `1`s if `x < 0`,
  preserving the sign"; `>>>` fills with zeros. Sources:
  <https://docs.julialang.org/en/v1/base/math/>, `base/int.jl`.
- `bitreverse(x)` requires a fixed-width type (docs: "`x` must have a fixed bit width");
  `bswap` is defined for all fixed-width integer types (identity for 8-bit).
- Integer conversions overflow/inexactness throw (`InexactError`), and "integers overflow
  without warning" in arithmetic. Source: <https://docs.julialang.org/en/v1/base/numbers/>.

## 5. Ownership semantics

- Julia is garbage-collected. A `BitArray` **owns** its `chunks::Vector{UInt64}`; copying
  is explicit (`copy`, `BitArray(x)`, `BitVector(::BitArray)` share the same backing
  array until copied — `BitArray(x::BitArray) = copy(x)`). `similar` allocates a new one.
- `BitSet.union(s, sets...) = union!(copy(s), sets...)` — non-mutating forms explicitly
  copy first; `union!`/`intersect!`/`setdiff!`/`symdiff!` mutate in place
  (`base/bitset.jl`). `copy!(dest, src)` resizes and copies `bits` and `offset`.
- Aliasing is a documented hazard: `copyto!`/`_copyto_int!` guard overlapping ranges, and
  `bit_map!` warns "DO NOT SEPARATE ONTO TWO LINES. Otherwise there will be bugs when
  `Ac` aliases `destc`" (`base/bitarray.jl`).
- `reinterpret(T, A)` produces a **view** over the same binary data ("Construct a view of
  the array with the same binary data ..."), so the new array and the original share
  storage. Source: `base/reinterpretarray.jl`.
- `IOBuffer`: "Once `write` is called on an `IOBuffer`, it is best to consider any
  previous references to `data` invalidated; in effect `IOBuffer` 'owns' this data until a
  call to `take!`." Source: <https://docs.julialang.org/en/v1/base/io-network/>.

## 6. Blocking / non-blocking

- The bit layer (`BitArray`, `BitSet`, scalar functions) is pure in-memory computation:
  no blocking, no I/O, no async. There is no concurrency model in these types.
- **Thread-safety limit (documented):** "Due to its packed storage format, concurrent
  access to the elements of a `BitArray` where at least one of them is a write is not
  thread-safe." Source: `base/bitarray.jl#L7-L23`,
  <https://docs.julialang.org/en/v1/base/arrays/>.
- Where I/O is involved, Julia's IO is **blocking by default**: `read(s::IOStream, nb)`
  with `all=true` "will block repeatedly trying to read all requested bytes"; `eof` may
  block to wait for data. `IOBuffer` is in-memory and effectively non-blocking. Source:
  <https://docs.julialang.org/en/v1/base/io-network/>.
- Async is expressed with `Task`s/channels outside the bit layer; `link_pipe!`'s
  `reader_supports_async`/`writer_supports_async` flags map to `O_NONBLOCK`/`OVERLAPPED`
  for pipes. Source: <https://docs.julialang.org/en/v1/base/io-network/>.

## 7. Width and ordering model

- **Fixed width for scalars:** `Bool`, `Int8..Int128`, `UInt8..UInt128`; `Int`/`UInt` are
  `Sys.WORD_SIZE`-wide. `BigInt` is **arbitrary precision** and "treated as if having
  infinite size" for `>>>`. Sources: <https://docs.julialang.org/en/v1/base/numbers/>,
  <https://docs.julialang.org/en/v1/base/math/>.
- **Signedness is explicit in the type**, but `Bool <: Integer` and `true == 1`; `~n =
  -n-1` for signed, while `~` on unsigned gives the complemented value. Source:
  `base/int.jl`, <https://docs.julialang.org/en/v1/base/numbers/>.
- **Container order is LSB-first per chunk:** indexing computes
  `get_chunks_id(i) = (_div64(i-1)+1, _mod64(i-1))` and tests
  `chunks[k] & (1 << bit)` — i.e. index 1 = bit 0 of chunk 1 = least-significant bit.
  `BitSet.iterate` likewise emits `trailing_zeros(word) + ...` in ascending order.
  Sources: `base/bitarray.jl`, `base/bitset.jl`.
- **Chunk word size is 64 bits** (`Vector{UInt64}`, `_msk64 = ~UInt64(0)`), with the tail
  masked by `_msk_end(len)` so unused bits stay 0 (`base/bitarray.jl`).
- **Display order is MSB-first:** `bitstring(n)` is "in bigendian order, i.e.
  most-significant bit first". So the same value has an LSB-first *bit index* model and an
  MSB-first *string* model. Source: <https://docs.julialang.org/en/v1/base/numbers/>.
- **Byte order is explicit only via helpers:** `bswap` reverses bytes; `ntoh`/`hton`
  convert native↔big-endian; `write` writes native endianness ("The endianness of the
  written value depends on the endianness of the host system"). Sources:
  <https://docs.julialang.org/en/v1/base/numbers/>,
  <https://docs.julialang.org/en/v1/base/io-network/>.
- **BitBasis** chooses the opposite naming: its integer buffer is little-endian but
  `bit"11100"` renders leftmost = most significant; `readbit(x, 2, 3)` reads "the 2nd and
  3rd bits as `x₃x₂`". Source: <https://yaoquantum.org/BitBasis.jl/dev/tutorial.html>.

## 8. Bounds, overflow and growth

- **Index bounds:** `BitArray`/`BitVector` indexing is bounds-checked
  (`@boundscheck checkbounds(B, i)`) → `BoundsError`; `resize!` rejects `n < 0` with
  `BoundsError`; array dims require `d >= 0` else `ArgumentError("dimension size must be
  ≥ 0")`. Source: `base/bitarray.jl`.
- **Container growth (BitArray):** `push!`/`pushfirst!` grow `chunks` one word at a time
  and zero the new word; `append!`/`prepend!` compute `num_bit_chunks(n)` and `_growend!`;
  `deleteat!`/`pop!` shrink and re-mask the last chunk with `_msk_end`. Growth is
  amortized through `Vector` semantics; `sizehint!(B, sz)` pre-allocates
  `num_bit_chunks(sz)`. Source: `base/bitarray.jl`.
- **Container growth (BitSet):** grows **in both directions** — `_setint!` sets `offset`
  on first insert, `_growend0!` for bits above, `_growbeg0!` (and lowers `offset`) for
  bits below ("we assume isempty(s.bits)" when `offset == NO_OFFSET`). `union!(s,
  AbstractUnitRange)` sets a whole range in one pass with a single mask expression.
  Newly allocated chunks are explicitly zeroed ("resize! gives dirty memory"). Source:
  `base/bitset.jl`.
- **No fixed capacity:** because Julia's default integers overflow *silently* and `BitSet`
  grows unboundedly, there is no "shift amount ≥ width" sentinel; `<<` with negative
  count shifts the other way. `1 << 64` on `Int64` is evaluated as `1 * 2^64`, which
  overflows to 0 (Assessment: derived from the documented equivalence
  `x << n ≡ x * 2^n` and "integers overflow without warning", both in
  <https://docs.julialang.org/en/v1/base/math/> and
  <https://docs.julialang.org/en/v1/base/numbers/>).
- **Negative input:** `delete!(s::BitSet, n)` on a non-`Int`-convertible integer is a
  no-op (`_is_convertible_Int` guard); `in(n::Integer, s)` returns `false` for
  out-of-`Int`-range values. `BitSet` can hold negative `Int`s (offset is signed).
  Source: `base/bitset.jl`.
- **Defined vs undefined:** all indexed access is bounds-checked; there is no documented
  "undefined" behavior in `BitArray`. `BitSet`'s `_matched_map!` carries explicit
  invariants in comments (e.g. `@assert f(false, x) == x`) rather than relying on caller
  discipline. Source: `base/bitset.jl`.

## 9. Scalar functions, container type and bit-level I/O

The three layers and where Julia puts them:

1. **Scalar integer functions — stdlib, rich.** `count_ones`/`leading_zeros`/
   `trailing_zeros`/`leading_ones`/`trailing_ones`/`top_set_bit`/`bswap`/`bitreverse`/
   `bitrotate`, `~`/`&`/`|`/`xor`/`<<`/`>>`/`>>>`; docs §§1, 3. Source: `base/int.jl`.
2. **Container — stdlib, split in two designs.** `BitArray` is a bit-packed
   `AbstractArray{Bool}` (ordered bits, broadcasting, per-bit indexing, growth); `BitSet`
   is a *set* over dense `Int`s (auto-growing, word-parallel union/intersect/diff/symdiff,
   ascending iteration, cardinality `length`). Both expose full generic collection
   behaviour (`findfirst`/`findall`/`count`/`any`/`all`). Sources:
   `base/bitarray.jl`, `base/bitset.jl`, docs §§1–3.
3. **Bitfield get/set — NOT stdlib.** No `get_bits(x, hi, lo)`/`set_bits` in `Base`.
   Closest: hand-written mask/shift; community `BitOperations.bget/bset/bmask` (0-based,
   `UnitRange`, reverse ranges rejected); `BitBasis.readbit`; `PackedStructs.@packed` for
   sub-byte struct fields. Sources: <https://oschulz.github.io/BitOperations.jl/stable/>,
   <https://yaoquantum.org/BitBasis.jl/dev/tutorial.html>,
   <https://github.com/JuliaData/PackedStructs.jl>.
4. **Bit-level stream I/O — NOT stdlib.** No bit reader/writer. `IOBuffer` and
   `read`/`write` are byte- or value-oriented; `reinterpret` gives a *typed view* over the
   same bytes but cannot reinterpret `Vector{UInt8}` as a `BitVector` directly
   (`ArgumentError: ... type BitArray{1} is not a bitstype`), and the community answers are
   manual bit loops or `unsafe_copy!` into `bv.chunks` (with the caller responsible for
   masking the tail). Sources: `base/iobuffer.jl`, `base/reinterpretarray.jl`,
   <https://discourse.julialang.org/t/i-have-vector-uint8-i-need-bitvector/2286>;
   non-Julia reference design: <https://github.com/novolang/bitstream-nv>.

## 10. Interesting design decisions

- **Two container philosophies in one stdlib.** `BitArray` = packed *array of booleans*
  (positional, broadcastable, growable at the end); `BitSet` = *set of integers*
  (auto-growing in both directions, word-parallel set algebra, sorted iteration). Julia
  does not force one type to be both. Sources: `base/bitarray.jl`, `base/bitset.jl`.
- **Word-parallel algebra via generic iterable ops.** `union`/`intersect`/`setdiff`/
  `symdiff` are generic over `AbstractSet`/iterables, but `BitSet` specializes them by
  `_matched_map!(f, s1, s2)` across the `bits` words with `f ∈ {|, &, (p,q)->p&~q, xor}`,
  handling differing lengths and offsets. Source: `base/bitset.jl`.
- **Chunk-level `map` specialization** is called out in the source: "there can be a 64x
  speedup by working at the level of Int64 instead of looping bit-by-bit"
  (`base/bitarray.jl`).
- **`BitSet` grows below zero too**, using a signed `offset` and a `NO_OFFSET` sentinel
  whose "bits field *must* be empty"; `NO_OFFSET` is chosen negative to speed up `in`.
  Source: `base/bitset.jl`.
- **Strict storage invariant:** "unused bits must always be set to 0" — every operation
  that shrinks or finalizes a chunk re-applies `_msk_end`; this is what makes
  chunk-pointer `==` comparisons valid. Source: `base/bitarray.jl`.
- **BitBasis reverses the integer-literal convention:** the string literal renders MSB
  leftmost while the integer buffer is little-endian; `breflect`/`bint_r` exist precisely
  because both readings are useful. Source:
  <https://yaoquantum.org/BitBasis.jl/dev/tutorial.html>.
- **BitOperations fixes ordering as API:** zero-based bit indices, LSB-up `UnitRange`
  (`bset(0x00, 0:7, 1) == 0xff`), and it *rejects* `StepRange`/reverse ranges instead of
  guessing. Source: <https://oschulz.github.io/BitOperations.jl/stable/>.
- **Fixed compile-time-size bitsets** (`BitVector8..BitVector4096`) with the same operator
  vocabulary as the dynamic type — a size-as-type-parameter design. Source:
  <https://github.com/claud10cv/FixedSizeBitVector.jl>.
- **Sub-byte fields are a separate concern in Julia:** `PackedStructs.@packed` packs
  logical-width integers into shared storage, with `Pad{N}` for explicit gaps and
  `pack(T, x)` extensible for non-`Integer` primitives. Source:
  <https://github.com/JuliaData/PackedStructs.jl>.

## 11. Decisions NOT to copy

- **`Bool <: Integer` / `true == 1` / no "truthy" values.** Julia's boolean is a number;
  a dedicated Mojo bit type should not inherit arithmetic/`Bool`-as-`Int` coercion.
  Source: <https://docs.julialang.org/en/v1/base/numbers/>.
- **`~n == -n-1` for signed integers.** Complement on a signed type means arithmetic
  negation semantics; a Mojo bit library should require/demand an explicit unsigned or mask
  operand to avoid the sign trap. Source: `base/int.jl`.
- **Negative shift counts silently reverse direction** (`x << -n == x >> n`). Convenient
  in Julia, surprising as a *bit* operation; a bit library should make the direction
  explicit (`shift_left`/`shift_right`) and reject negative counts. Sources:
  <https://docs.julialang.org/en/v1/base/math/>, `base/int.jl`.
- **No bitfield API in stdlib, so users hand-write masks.** Copying that gap is what the
  `bit` library exists to close; do not imitate the "figure out the mask yourself"
  situation (Assessment: derived from §1/§9 and the `_dev/README.md` gap statement).
- **`BitArray` is not thread-safe for concurrent writes.** A Mojo design should either
  make mutation ownership-exclusive or explicitly document single-writer semantics.
  Source: `base/bitarray.jl#L7-L23`.
- **Unsafe `reinterpret`/pointer tricks to build a bitset from bytes.** The community
  workaround (`unsafe_copy!` into `bv.chunks`, then mask the tail by hand) is a footgun;
  a first-class "build from bytes, bits, and a target length" API is preferable. Source:
  <https://discourse.julialang.org/t/i-have-vector-uint8-i-need-bitvector/2286>.
- **Exceptions as the sole error channel.** Mojo's `raises`/`Optional` model can express
  "may be out of range" in the signature; do not force every bounds error into a thrown
  exception (Assessment: derived from Julia's exception-only representation in §4 and the
  Mojo side of `_dev/README.md`).
- **Two disjoint container types with overlapping vocabulary.** `BitArray` vs `BitSet`
  both call `count`/`any`/`intersect` but mean different things (positional vs set);
  MojoAkku should pick one coherent container and add set algebra on top, rather than
  mirroring both. (Assessment: derived from `base/bitarray.jl` and `base/bitset.jl`.)
- **1-based container indexing with a 0-based convention in the bit ecosystem.** Julia
  arrays are 1-based while BitOperations/BitBasis use 0-based bit positions; do not mix
  the two without a stated rule. Sources:
  <https://docs.julialang.org/en/v1/base/arrays/>,
  <https://oschulz.github.io/BitOperations.jl/stable/>.

## 12. Ideas fitting Mojo

- **Match `std.bit` first, then add the container.** Mojo already has the scalar layer
  (`bit_not`, `bit_reverse`, `bit_width`, `byte_swap`, `count_leading_zeros`,
  `count_trailing_zeros`, `log2_ceil`, `log2_floor`, `next_power_of_two`,
  `prev_power_of_two`, `pop_count`, `rotate_bits_left`, `rotate_bits_right`, plus
  `mask.is_negative` and `mask.splat`; unstable by default — source:
  `mojov1/stdlib/bit`, <https://mojolang.org/docs/std/bit/>). The research signal is to
  *wrap, not rebuild*, those and spend the design on the container + bitfield + bit I/O.
- **Word-parallel set algebra on `UInt64` chunks** (`union`/`intersect`/`difference`/
  `complement` as single-word ops) is portable and fast; Julia's `_matched_map!` pattern
  shows how to handle unequal lengths/offsets. Source: `base/bitset.jl`.
- **LSB-first bit indexing with a masked tail invariant** (index 1 = bit 0; unused bits
  always 0) is simple to specify and to keep canonical for equality/serialization.
  Source: `base/bitarray.jl`.
- **Explicit ordering in the API, both directions.** Adopt BitBasis' framing — one value,
  two reading orders (`bitstring` MSB-first vs. bit index LSB-first) — and make the
  bit-stream ordering an explicit constructor/parameter (BitOperations' "order is
  API"/novolang's no-default ordering flag). Sources:
  <https://yaoquantum.org/BitBasis.jl/dev/tutorial.html>,
  <https://oschulz.github.io/BitOperations.jl/stable/>,
  <https://github.com/novolang/bitstream-nv>.
- **Zero-based `[hi:lo]` inclusive bitfields over an integer value**, modeled on
  `BitOperations.bget/bset/bmask` with `UnitRange` semantics and rejected invalid ranges
  (the gap `std.bit` leaves open). Source:
  <https://oschulz.github.io/BitOperations.jl/stable/>.
- **Compile-time-size bitsets via Mojo `comptime`/parameterized types**, mirroring
  `BitVector8..BitVector4096`, so fixed flag words have no heap allocation. Source:
  <https://github.com/claud10cv/FixedSizeBitVector.jl>.
- **A packed-struct/bitfield view for later layers**, following `PackedStructs.@packed`
  (logical width per field, explicit `Pad{N}`), useful for wire formats in later MojoAkku
  libraries. Source: <https://github.com/JuliaData/PackedStructs.jl>.
- **Value/ownership semantics with explicit copying.** Julia's `union(s,...) =
  union!(copy(s), ...)` and `copy!` model shows the read/write split; Mojo can express it
  as `owned`/`borrowed` in the signature instead of relying on copying conventions.
  Source: `base/bitset.jl`.

## Sources

Julia documentation (Base):
- Arrays / `BitArray`, `trues`, `falses`, `similar`: <https://docs.julialang.org/en/v1/base/arrays/>
- Collections / `BitSet`, `AbstractSet`, `union`, `intersect`, `setdiff`: <https://docs.julialang.org/en/v1/base/collections/>
- Mathematics / shift operators, `bitrotate`: <https://docs.julialang.org/en/v1/base/math/>
- Numbers / `count_ones`, `leading_zeros`, `trailing_zeros`, `bswap`, `bitstring`, widths: <https://docs.julialang.org/en/v1/base/numbers/>
- I/O and Network / `IOBuffer`, `read`, `write`, endianness: <https://docs.julialang.org/en/v1/base/io-network/>

Julia source (`JuliaLang/julia`, master):
- `base/bitarray.jl` (BitArray/BitVector/BitMatrix implementation) — <https://raw.githubusercontent.com/JuliaLang/julia/master/base/bitarray.jl>
- `base/bitset.jl` (BitSet implementation) — <https://raw.githubusercontent.com/JuliaLang/julia/master/base/bitset.jl>
- `base/int.jl` (scalar bit functions, shifts, `bitreverse`, `bswap`) — <https://raw.githubusercontent.com/JuliaLang/julia/master/base/int.jl>
- `base/reinterpretarray.jl` — <https://github.com/JuliaLang/julia/blob/master/base/reinterpretarray.jl>
- `base/iobuffer.jl` — (docstrings referenced via the I/O docs page above)
- Docs source anchors for `BitArray` (`base/bitarray.jl#L7-L23`), `BitSet`
  (`base/bitset.jl#L25-L32`), `int.jl` functions (`#L447-L528`), `bitrotate`
  (`base/int.jl#L607-L632`), `bswap` (`base/int.jl#L421-L442`) — from
  <https://docs.julialang.org/en/v1/base/arrays/>, <https://docs.julialang.org/en/v1/base/numbers/>,
  <https://docs.julialang.org/en/v1/base/math/>.

Community packages:
- BitOperations.jl — <https://oschulz.github.io/BitOperations.jl/stable/> and <https://github.com/oschulz/BitOperations.jl>
- BitBasis.jl tutorial — <https://yaoquantum.org/BitBasis.jl/dev/tutorial.html>
- FixedSizeBitVector.jl — <https://github.com/claud10cv/FixedSizeBitVector.jl>
- PackedStructs.jl — <https://github.com/JuliaData/PackedStructs.jl>
- Bits.jl package listing — <https://juliapackages.com/p/bits>
- BitPermutations.jl listing — <https://juliapackages.com/p/bitpermutations>
- bitstream-nv (non-Julia cross-reference, not a Julia package — ordering-API signal) — <https://github.com/novolang/bitstream-nv>

Discussion:
- "I have: Vector{UInt8}. I need: BitVector" (reinterpret limits, unsafe workaround) — <https://discourse.julialang.org/t/i-have-vector-uint8-i-need-bitvector/2286>
