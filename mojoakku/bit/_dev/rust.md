# bit research: Rust

## 1. Standard library support

Rust's standard library provides **scalar bit methods on every integer primitive** and **byte-order methods**, but **no bit-set container** and **no bit-level stream I/O**.

- Integer primitives (`u8`…`u128`, `usize`, `i8`…`i128`, `isize`) carry the bit methods directly as inherent `const fn`s: `count_ones`, `count_zeros`, `leading_zeros`, `leading_ones`, `trailing_zeros`, `trailing_ones`, `rotate_left`, `rotate_right`, `swap_bytes`, `reverse_bits`, `bit_width`, `isolate_lowest_one`, `isolate_highest_one`, `highest_one`, `lowest_one`, `is_power_of_two`, `next_power_of_two`. Source: <https://doc.rust-lang.org/std/primitive.u32.html> (method index).
- Width metadata: associated constants `BITS` ("The size of this integer type in bits", e.g. `u32::BITS == 32`), `MIN`, `MAX`. Source: <https://doc.rust-lang.org/std/primitive.u32.html#associatedconstant.BITS>.
- Carrying/overflowing arithmetic: `carrying_add`, `borrowing_sub`, `carrying_mul`, `widening_mul`, `overflowing_add/sub/mul`, `wrapping_*`, `saturating_*`, `checked_*`, `strict_*`. Source: <https://doc.rust-lang.org/std/primitive.u32.html> (method index).
- `core::cmp` / `std`: no bit-set. `HashSet`/`BTreeSet` are set containers of values, not bits. (Assessment: derived from <https://doc.rust-lang.org/std/primitive.u32.html> and <https://doc.rust-lang.org/std/collections/>.)
- `std::io` gives byte-level `Read`/`Write` only; there is no bit-granular reader/writer. (Assessment: derived from <https://docs.rs/bitstream-io/latest/bitstream_io/>, which exists precisely because "Both big-endian and little-endian streams are supported" is not offered by std.)
- Two newer gather/scatter methods exist but are **unstable**: `extract_bits(self, mask)` and `deposit_bits(self, mask)` require `#![feature(uint_gather_scatter_bits)]`. Source: <https://doc.rust-lang.org/std/primitive.u32.html#method.extract_bits>, <https://doc.rust-lang.org/std/primitive.u32.html#method.deposit_bits>.

## 2. Relevant community libraries

- `bitvec` — v1.1.1, MIT, by `myrrlyn` / `github:ferrilab:maintainers`, repo <https://github.com/bitvecto-rs/bitvec>. "provides a foundational API for bitfields in Rust. It specializes standard-library data structures (slices, arrays, and vectors of `bool`) to use one-bit-per-`bool` storage." 100% documented. Source: <https://docs.rs/bitvec/latest/bitvec/>.
- `fixedbitset` — v0.5.7, MIT OR Apache-2.0, maintained under the `petgraph` org, repo <https://github.com/petgraph/fixedbitset>. "FixedBitSet is a simple fixed size set of bits." 94.2% documented. Written with SIMD in mind (SSE2/AVX/AVX2 on x86/x86_64, wasm32 SIMD) with graceful fallback. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/>.
- `bitflags` — v2.13.2, MIT OR Apache-2.0, by `KodrAus` / `rust-lang-owner`, repo <https://github.com/bitflags/bitflags>. "Generate types for C-style flags with ergonomic APIs." Has a formal spec (`spec.md`) and 98.23% documented. Source: <https://docs.rs/bitflags/latest/bitflags/>.
- `bitstream-io` — v4.10.0, MIT/Apache-2.0, by `tuffy`, repo <https://github.com/tuffy/bitstream-io>. "Traits and helpers for bitstream handling functionality ... Both big-endian and little-endian streams are supported." 100% documented. Source: <https://docs.rs/bitstream-io/latest/bitstream_io/>.
- `deku` — referenced by `bitvec` as the crate providing "syntax sugar" for C-style structural bitfields. Source: <https://docs.rs/bitvec/latest/bitvec/>.

## 3. Exposed APIs

Integer primitives (exact signatures and docs, using `u32` as the representative):
- `pub const fn count_ones(self) -> u32` — "Returns the number of ones in the binary representation of self." `n.count_ones()` for `0b01001100u32` is 3.
- `pub const fn count_zeros(self) -> u32` — "Returns the number of zeros ...", width-dependent; the docs warn it "is heavily dependent on the width of the type, and thus might give surprising results depending on type inference".
- `pub const fn leading_zeros(self) -> u32` — "Returns the number of leading zeros"; `0_u32.leading_zeros() == 32`.
- `pub const fn trailing_zeros(self) -> u32` — `0_u32.trailing_zeros() == 32`.
- `pub const fn rotate_left(self, n: u32) -> u32` — "`rotate_left(n)` is equivalent to applying `rotate_left(1)` a total of `n` times. In particular, a rotation by the number of bits in `self` returns the input value unchanged." (`n.rotate_left(1024) == n`.)
- `pub const fn swap_bytes(self) -> u32` — `0x12345678u32.swap_bytes() == 0x78563412`.
- `pub const fn reverse_bits(self) -> u32` — `0x12345678u32.reverse_bits() == 0x1e6a2c48`.
- `pub const fn bit_width(self) -> u32` — `0_u32.bit_width() == 0`, `0b111_u32.bit_width() == 3`, `u32::MAX.bit_width() == 32`.
- `pub const fn isolate_highest_one(self) -> u32`, `isolate_lowest_one(self) -> u32`.
- `pub const fn highest_one(self) -> Option<u32>`, `lowest_one(self) -> Option<u32>` — `Option` signals "no set bit", replacing a sentinel.
- `pub const fn extract_bits(self, mask: u32) -> u32`, `pub const fn deposit_bits(self, mask: u32) -> u32` — **unstable** (feature `uint_gather_scatter_bits`); `0b1011_1100u32.extract_bits(0xF0) == 0b0000_1011`.
- Shifts: `checked_shl`, `checked_shr` (return `Option`), `wrapping_shl`, `wrapping_shr` (mask the shift count), `overflowing_shl` (returns `(value, bool)`), `unchecked_shl` (unsafe), `unbounded_shl`. `0x1u32.checked_shl(4) == Some(0x10)`, `0x10u32.checked_shl(129) == None`, `0x1u32.overflowing_shl(132) == (0x10, true)`.
Source for all: <https://doc.rust-lang.org/std/primitive.u32.html>.

`bitvec`:
- Types: `BitArray` (statically allocated, fixed size), `BitSlice` (region type, "equivalent to `[bool]`"), `BitBox` (heap, fixed size), `BitVec` (heap, adjustable). Macro constructors: `bitarr!`, `bits!`, `bitbox!`, `bitvec!`. Source: <https://docs.rs/bitvec/latest/bitvec/>.
- Type parameters are the whole design story: `T: BitStore` chooses the storage element (`u8`…`usize`, atomic variants) and `O: BitOrder` chooses `Lsb0` or `Msb0`. "Type parameters enable users to select the precise memory representation they desire." Source: <https://docs.rs/bitvec/latest/bitvec/>.
- Viewing existing data: `data.view_bits::<Msb0>()`, `data.view_bits_mut::<Lsb0>()`, `BitView` module. Source: <https://docs.rs/bitvec/latest/bitvec/>.
- `BitSlice` is "never held directly, but only by references" and "cannot implement `IndexMut`, so `bitslice[index] = true;` does not work." Instead a proxy from `get_mut(0)` is used: "a proxy structure that can be used as nearly an `&mut bit` reference". Source: <https://docs.rs/bitvec/latest/bitvec/>.
- Slicing is bit-granular: `split_at(4)`, `split_at_mut(8)`, `[. . 4]`, `[4 . .]`, and `chunks_mut(5)` — "Bit-slices can split anywhere." Source: <https://docs.rs/bitvec/latest/bitvec/>.
- `BitField` trait: `load_le<I>`, `load_be<I>`, `store_le<I>`, `store_be<I>`, plus target-endian `load`/`store`. "The methods in this trait always operate on the `bitslice.len()` least significant bits of an integer, and ignore any remaining high bits." Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- Known limitations: "`BitSlice` cannot be used as a referent type in pointers, such as `Box`, `Rc`, or `Arc`." Source: <https://docs.rs/bitvec/latest/bitvec/>.

`fixedbitset::FixedBitSet`:
- Construction: `new()`, `with_capacity(bits)`, `with_capacity_and_blocks(bits, blocks)`, `Default`.
- Single bit: `insert`, `remove`, `toggle`, `set(bit, enabled)`, `put(bit) -> bool` ("Enable bit, and return its previous value"), `contains`, `contains_unchecked` (unsafe), `copy_bit(from, to)`.
- Ranges: `set_range`, `insert_range`, `remove_range`, `toggle_range`, `count_ones(range)`, `count_zeroes(range)`, `contains_all_in_range`, `contains_any_in_range` — ranges are Rust range syntax via the `IndexRange` trait.
- Query: `len()`, `is_empty()`, `is_clear()`, `is_full()`, `count_ones(..)`, `count_zeroes(..)`, `minimum()`, `maximum()`, `is_disjoint`.
- Algebra: lazy iterators `intersection`, `union`, `difference`, `symmetric_difference`; in-place `union_with`, `intersect_with`, `difference_with`, `symmetric_difference_with`; count-only `union_count`, `intersection_count`, `difference_count`, `symmetric_difference_count` ("potentially much faster ... does not mutate in place or require separate allocations"); plus operator traits `&`/`|`/`^` and their `*Assign` forms.
- Iteration: `ones()`, `zeroes()`, `into_ones()`.
- Growth: `grow(bits)` ("all new bits initialized to zero"), `grow_and_insert(bits)` ("cannot panic, but may allocate if the bit is outside of the existing buffer's range ... faster than calling grow then insert in succession").
- Raw access: `as_slice() -> &[Block]`, `as_mut_slice() -> &mut [Block]`, type alias `Block`. The mutable accessor warns that "Writing past the bitlength in the last will cause `contains` to return potentially incorrect results for bits past the bitlength."
Source for all: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.

`bitflags`: macro-generated newtype over a bits type (`u8`…`u128`, …) with `const A = 0b00000001;`, operators `|`, `&`, `-`, `!`, `contains`, `intersects`, `all`, `bits()`, plus text formatting/parsing with per-flag rename via `#[bitflags(flag_name = "...")]`. Source: <https://docs.rs/bitflags/latest/bitflags/>.

`bitstream-io`:
- Traits `BitRead`/`BitWrite` alongside concrete `BitReader`/`BitWriter`, generic over `Endianness` (`BigEndian`/`BE`, `LittleEndian`/`LE`).
- Constant-width vs variable-width read/write are distinct methods: `read::<N, _>()` / `read_var(n)` and `write`/`write_var`, explicitly "to emphasize using the constant-based one, which can do more validation at compile-time".
- `BitCount` + `read_count`/`read_counted` handle formats that encode the field width in the stream itself (FLAC example).
Source for all: <https://docs.rs/bitstream-io/latest/bitstream_io/>.

## 4. Error representation

Rust uses `Result`/`Option` and panics, with no error codes and no exceptions.
- Integer bit methods that cannot fail return a plain value, all `const fn`, and never panic: `count_ones`, `rotate_left(1024)`, `reverse_bits`, `bit_width`. Source: <https://doc.rust-lang.org/std/primitive.u32.html>.
- Failure-shaped inputs get a dedicated method family per policy:
  - `checked_shl` returns `Option<T>` (`checked_shl(129) == None`).
  - `overflowing_shl` returns `(T, bool)` (`overflowing_shl(132) == (0x10, true)`).
  - `wrapping_shl` masks the count (`42_u32.wrapping_shl(32) == 42`), and the docs point at `rotate_left` as the different thing.
  - `unchecked_shl` is `unsafe` and documented as UB if `rhs >= BITS`.
  Source: <https://doc.rust-lang.org/std/primitive.u32.html>.
- `highest_one`/`lowest_one` return `Option<u32>` rather than a sentinel for "no bit set". Source: <https://doc.rust-lang.org/std/primitive.u32.html#method.highest_one>.
- `bitvec`: "The trait methods all panic if called on a bit-slice that is wider than the integer type being transferred." `BitField::store` "panics if `self.len()` is 0, or greater than `I::BITS`". Round-trip correctness is a caller obligation: "You must always use the loading method that exactly corresponds to the storing method previously used ... `bitvec` is not required to, and will not, guarantee round-trip consistency if you change any of these parameters." Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- `fixedbitset`: two-tier API. Checked methods "Panics if bit is out of bounds" (`insert`, `remove`, `toggle`, `set`, `put`, `set_range`, …); `*_unchecked` variants are `unsafe` with "bit must be less than `self.len()`". `contains` does not panic — "bits outside the capacity are always disabled". `grow_and_insert` "cannot panic, but may allocate". Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
- `bitflags` defines an `Error` trait impl for its parse errors under the `std` feature. Source: <https://docs.rs/bitflags/latest/bitflags/>.
- `bitstream-io`: errors are `Result`-typed; the minimum-compiler note gives the canonical failure: `let x: Result<u32, _> = r.read_var(64); // reading 64 bits to u32 always fails at runtime`, while `read::<64, _>()` "doesn't compile at all". Source: <https://docs.rs/bitstream-io/latest/bitstream_io/>.

## 5. Ownership semantics

Rust's model is central to the design and visible in the API shape.
- Integers are `Copy`; all scalar bit methods take `self` by value and return a new value. Source: <https://doc.rust-lang.org/std/primitive.u32.html>.
- `bitvec` is built on `bool` collections and follows their ownership rules: `BitArray` is a value, `BitSlice` "is a view that alters the behavior of a borrowed memory region. It is never held directly, but only by references (created by borrowing integer memory) or the `BitArray` value type." Borrowing integer memory into a bit view (`data.view_bits::<Msb0>()`) is safe and zero-copy, including mutable views (`view_bits_mut`). Source: <https://docs.rs/bitvec/latest/bitvec/>.
- `split_at_mut` yields disjoint mutable sub-slices — "l and r each own one byte ... but now a, b, c, and d own a nibble" — so the borrow checker enforces non-overlapping writers. Source: <https://docs.rs/bitvec/latest/bitvec/>.
- Because `BitSlice` has no `IndexMut`, a place expression `bits[i] = true` is impossible; the crate offers a proxy handle instead, which is *not* a reference and therefore not covered by NLL ("`bit` is not a reference, so NLL rules do not apply"). Source: <https://docs.rs/bitvec/latest/bitvec/>.
- Atomic storage is a first-class option: `bitvec` has "Native support for atomic integers as bit-field storage" (Cargo feature `atomic`, via the `radium` crate), and "A memory model accounts for element-level aliasing and is safe for concurrent use." Source: <https://docs.rs/bitvec/latest/bitvec/>.
- `fixedbitset` is an owning, heap-backed container with `Clone`, `Drop`, and raw `as_slice`/`as_mut_slice`; `Send`/`Sync` are derived, so sharing across threads requires the usual Rust synchronization. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.

## 6. Blocking / non-blocking

- Scalar bit methods are pure `const fn` computation — they can run in `const` contexts and never block. Source: <https://doc.rust-lang.org/std/primitive.u32.html>.
- `bitstream-io` is the blocking-IO layer: readers/writers wrap any `io::Read`/`io::Write`; the only stream requirement is those traits. It buffers "only a single partial byte as needed", so it is a thin adapter over whatever blocking/non-blocking semantics the underlying stream has. Source: <https://docs.rs/bitstream-io/latest/bitstream_io/>.
- `bitvec`'s `std` feature "provides some `std::io::{Read,Write}` implementations" — i.e. IO is an optional add-on, not the core. Source: <https://docs.rs/bitvec/latest/bitvec/>.
- `no_std` support is explicit throughout the ecosystem: `bitvec` "supports `#![no_std]` targets" (disable default features, restore `atomic`/`alloc`); `fixedbitset`'s `std` feature "Disabling this feature disables using std and instead uses crate alloc."; `bitstream-io` also targets `no_std` via `no_std_io2`. Sources: <https://docs.rs/bitvec/latest/bitvec/>, <https://docs.rs/fixedbitset/latest/fixedbitset/>, <https://docs.rs/bitstream-io/latest/bitstream_io/>. (Assessment: derived from the three crate docs — the bit layer is designed to be usable without an OS, so "blocking" is a property of the wrapped stream, not of the bit layer.)

## 7. Width and ordering model

This is Rust's most distinctive contribution: **width, element ordering and bit ordering are three separate, explicit axes.**

- **Width** is the integer type (`u8`…`u128`), with `T::BITS` as the constant, and the type is a compile-time parameter of the bit collection (`BitSlice<T, O>`, `BitArray<A, O>`, `BitVec<T, O>`). Source: <https://doc.rust-lang.org/std/primitive.u32.html#associatedconstant.BITS>, <https://docs.rs/bitvec/latest/bitvec/>.
- **Bit ordering within an element** is the `BitOrder` type parameter, with two implementations:
  - `Lsb0` — "Least-Significant-First Bit Traversal"; "for any given bit index n and its position P(n), `P(n + 1)` is `P(n) + 1`." Indexing proceeds right-to-left in each element.
  - `Msb0` — "Most-Significant-First Bit Traversal"; "`P(n + 1)` is `P(n) - 1`." Indexing proceeds left-to-right in each element.
  Sources: <https://docs.rs/bitvec/latest/bitvec/order/index.html>, <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>. `LocalBits` is an alias for `Lsb0`.
- **Element (byte/word) significance ordering** is a *different* axis carried by the method suffix `_le` / `_be` on `BitField`, and the docs state the separation explicitly: "the `_le` and `_be` method suffixes are completely independent of the `Lsb0` and `Msb0` types! ... The `BitField` and `BitOrder` traits are **not** related." Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- The `BitOrder` module frames the whole architecture as separating "the semantic ordering of bits in an abstract memory space from the electrical ordering of latches in real memory", bridging them via `BitIdx` → `BitPos`/`BitSel`/`BitMask`. "Because `BitOrder` is open for client crates to implement", the module also ships verification functions (`verify`, `verify_for_type`). Source: <https://docs.rs/bitvec/latest/bitvec/order/index.html>.
- **Signedness**: `BitField` "can *only* store the signed or unsigned integer types. No other type is permitted, as the implementation relies on the 2's-complement significance behavior of processor integers. Record types and floating-point numbers do not have this property" — the docs then show a manual float transform via `to_bits()`/`from_bits()`. Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- **Portability warning** for the container: "If you do not care about the details of the memory layout of stored values, you can use the `.load()` / `.store()` unadorned methods. These each forward to their `_le` variant on little-endian targets, and their `_be` variant on big-endian. These will provide a reasonable default behavior, but do not guarantee a stable memory layout, and their buffers are not suitable for de/serialization." For wire protocols one must pin `T`, `O`, and the suffix: "TCP uses `<u8, Msb0>`, while IPv6 on a little-endian machine uses `<u32, Lsb0>`." Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- `fixedbitset` deliberately has **no ordering parameter**: it is always index 0 = lowest bit in block 0, exposed only through `Block` slices. (Assessment: derived from <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>, which exposes no order type or `_le`/`_be` methods, and from the ordering design documented in <https://docs.rs/bitvec/latest/bitvec/order/index.html>.)
- `bitstream-io` parameterises only stream endianness (`BigEndian`/`LittleEndian`) and keeps constant-bit-width and variable-bit-width reads as separate methods. Source: <https://docs.rs/bitstream-io/latest/bitstream_io/>.

## 8. Bounds, overflow and growth

- **Shift counts are strict by default.** The plain `<<`/`>>` operators have debug/release-dependent overflow behaviour, which is why the standard library offers the whole family `checked_shl`, `wrapping_shl`, `overflowing_shl`, `unchecked_shl`, `unbounded_shl`. Documented examples: `0x10u32.checked_shl(129) == None`; `0x1u32.overflowing_shl(132) == (0x10, true)`; `42_u32.wrapping_shl(32) == 42`; `unchecked_shl` is UB when `rhs >= BITS`. Source: <https://doc.rust-lang.org/std/primitive.u32.html>.
- `wrapping_shl` vs `rotate_left` are explicitly distinguished: "this is *not* the same as a rotate-left; the RHS of a wrapping shift-left is restricted to the range of the type, rather than the bits shifted out of the LHS being returned to the other end." Source: <https://doc.rust-lang.org/std/primitive.u32.html#method.wrapping_shl>.
- **Rotation is total**: `rotate_left(n)` for `n = 1024` on `u32` returns the input unchanged, i.e. the count is taken modulo `BITS` with no failure. Source: <https://doc.rust-lang.org/std/primitive.u32.html#method.rotate_left>.
- **`count_zeros` is width-sensitive** — the docs warn about type inference surprising callers (`u8` vs `u16` giving 5 vs 13 zeros for the same literal 7). Source: <https://doc.rust-lang.org/std/primitive.u32.html#method.count_zeros>.
- **Container growth**:
  - `fixedbitset.grow(bits)`: "Grow capacity to bits, all new bits initialized to zero"; `grow_and_insert(bits)` "cannot panic, but may allocate"; but the checked mutators panic out of bounds, and the `*_unchecked` ones are UB. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
  - `fixedbitset`'s `len()` is a capacity notion, not a cardinality: "`len` does not return the count of set bits. For that, use `bitset.count_ones(..)`." Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
  - `bitvec`'s `BitVec` is the growable variant ("Dynamically-Allocated, Adjustable-Size, Bit Buffer"), available only with the `alloc` feature. Source: <https://docs.rs/bitvec/latest/bitvec/>.
- **Bitfield width bound**: "The region may not be zero bits, nor wider than the destination type. Attempting to load a `u32` from a bit-slice of length 33 will panic the program." Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- **Raw-slice aliasing bound**: writing `as_mut_slice()` past the bit length "will cause `contains` to return potentially incorrect results for bits past the bitlength" — i.e. the invariant is only enforced by convention on the raw view. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.

## 9. Scalar functions, container type and bit-level I/O

| layer | provided by stdlib? | source |
| --- | --- | --- |
| scalar bit functions | **yes**, inherent `const fn` methods on every integer primitive | <https://doc.rust-lang.org/std/primitive.u32.html> |
| bit-set / flag-set container | **no** stdlib type; `bitvec` (general) and `fixedbitset` (fixed/simple) | <https://docs.rs/bitvec/latest/bitvec/>, <https://docs.rs/fixedbitset/latest/fixedbitset/> |
| bitfield get/set over `[hi:lo]` | **no** stable stdlib; `bitvec::BitField` over a bit-slice range, and unstable `extract_bits`/`deposit_bits` | <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>, <https://doc.rust-lang.org/std/primitive.u32.html#method.extract_bits> |
| bit-level stream I/O | **no** stdlib; `bitstream-io` (and `bitvec`'s optional `std::io` impls) | <https://docs.rs/bitstream-io/latest/bitstream_io/> |

Mojo's `std.bit` already covers the scalar layer (`bit_not`, `bit_reverse`, `bit_width`, `byte_swap`, `count_leading_zeros`, `count_trailing_zeros`, `log2_ceil`, `log2_floor`, `next_power_of_two`, `prev_power_of_two`, `pop_count`, `rotate_bits_left`, `rotate_bits_right`, plus `mask.is_negative` and `mask.splat` — unstable by default. Source: `mojov1/stdlib/bit`, <https://mojolang.org/docs/std/bit/>); Rust's integer methods are the same core set (`count_ones`, `leading_zeros`, `trailing_zeros`, `reverse_bits`, `swap_bytes`, `rotate_left`, `bit_width`). The notable **extra** Rust ships in core that `std.bit` lacks: `count_zeros`, `leading_ones`, `trailing_ones`, `isolate_lowest_one`, `isolate_highest_one`, `is_power_of_two`. (Assessment: derived from <https://doc.rust-lang.org/std/primitive.u32.html> and `mojov1/stdlib/bit`.)

## 10. Interesting design decisions

- **Per-policy method families instead of one panicking operator.** `checked_*` / `overflowing_*` / `wrapping_*` / `saturating_*` / `strict_*` / `unchecked_*` let the caller pick the failure policy at the call site without a configuration flag. Source: <https://doc.rust-lang.org/std/primitive.u32.html>.
- **`Option` over sentinels** for "no set bit" (`highest_one`, `lowest_one`) — removes the "is 0 a valid index?" ambiguity. Source: <https://doc.rust-lang.org/std/primitive.u32.html#method.highest_one>.
- **Bit ordering as a zero-cost type parameter.** `Lsb0`/`Msb0` are empty types; the ordering is monomorphised away, so choosing the wrong order is a type-level decision rather than a runtime flag, and the compiler can still produce "the same, or even better, object code than you would get from writing shift/mask instructions manually." Sources: <https://docs.rs/bitvec/latest/bitvec/order/index.html>, <https://docs.rs/bitvec/latest/bitvec/>.
- **Ordering is open for extension but verified.** `BitOrder` is a public trait clients may implement, and the crate ships `verify`/`verify_for_type` to check an implementation "for all the register types that it will govern". Source: <https://docs.rs/bitvec/latest/bitvec/order/index.html>.
- **Three-way separation of width / element significance / bit order**, documented with exhaustive memory diagrams per method and per ordering. Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- **`put` returns the previous value** (`fixedbitset`) — a read-modify-write that avoids a `contains` + `insert` pair and its race window. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
- **Count-only algebra variants** (`union_count`, `intersection_count`, …) that allocate nothing and mutate nothing. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
- **Range-typed bulk operations.** `set_range<T: IndexRange>(range, enabled)` accepts `..`, `a..`, `..b`, `c..d` — the language's own range syntax as the bit-range API. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
- **`bitflags` treats "unknown bits" as a first-class concept**, with an unnamed `const _ = !0;` flag to declare "the external source may set any bits", and a documented warning that some operators unset unknown bits while "In a future version of `bitflags`, all operators will unset unknown bits." Source: <https://docs.rs/bitflags/latest/bitflags/>.
- **`bitflags` warns about degenerate flag designs**: zero-bit flags "interact strangely with `Flags::contains` and `Flags::intersects`" (always contained, never intersected), and multi-bit flags without single-bit companions make `^` produce values that "don't correspond to either" named flag. Source: <https://docs.rs/bitflags/latest/bitflags/>.
- **Atomic-capable bit storage** in `bitvec` explicitly to make one data-race bug class impossible: "the 'Beware Bitfields' bug described in this Mozilla report is simply impossible to produce." Source: <https://docs.rs/bitvec/latest/bitvec/>.
- **Compile-time width validation in the stream layer.** `bitstream-io` 4.x uses const generics so `read::<64, _>()` into a `u32` "doesn't compile at all", versus a runtime error for the variable-width form. Source: <https://docs.rs/bitstream-io/latest/bitstream_io/>.
- **A formal spec for the flags macro.** `bitflags` defines its terminology and behaviour in `spec.md` (bits type / flag / flags type / flags value). Source: <https://docs.rs/bitflags/latest/bitflags/>.

## 11. Decisions NOT to copy

- **`unsafe` unchecked variants in the public API.** `fixedbitset::{contains,insert,remove,set,put,toggle}_unchecked` and `unchecked_shl` push a whole class of UB onto ordinary callers; a Mojo port should not expose an unsafe escape hatch in the first design. Sources: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>, <https://doc.rust-lang.org/std/primitive.u32.html#method.unchecked_shl>.
- **Panics for a too-wide bitfield transfer.** "Attempting to load a `u32` from a bit-slice of length 33 will panic the program." Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- **Round-trip correctness left to caller discipline.** "You must always use the loading method that exactly corresponds to the storing method previously used ... `bitvec` is not required to, and will not, guarantee round-trip consistency." This is easy to get silently wrong and hard to review. Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- **A separate "unadorned, non-portable" API tier.** `load()`/`store()` silently switch meaning with target endianness and "do not guarantee a stable memory layout, and their buffers are not suitable for de/serialization" — a portability trap that should not exist in a wire-facing library. Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- **`BitSlice` not being usable behind `Box`/`Rc`/`Arc` and not supporting `IndexMut`.** A `bits[i] = true` that does not compile, replaced by a proxy handle with its own lifetime rules, is a real usability cost for a low-vision-friendly API. Source: <https://docs.rs/bitvec/latest/bitvec/>.
- **`count_zeros`'s width-sensitivity.** The docs themselves flag that the same literal yields different results depending on inferred type — a silent surprise. Source: <https://doc.rust-lang.org/std/primitive.u32.html#method.count_zeros>.
- **Overloading `len()` to mean capacity rather than cardinality.** `fixedbitset.len()` counts bits in the set *including unset ones*; cardinality is `count_ones(..)`. Mojo should use distinct names. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
- **Raw mutable slice exposure with a convention-only invariant.** `as_mut_slice()` lets a caller break `contains` for indexes past the bit length. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
- **Behaviour that is documented as subject to change** ("In a future version of `bitflags`, all operators will unset unknown bits") — do not build on a moving contract. Source: <https://docs.rs/bitflags/latest/bitflags/>.

## 12. Ideas fitting Mojo

- **Mirror the per-policy method set, mapped to Mojo `raises`.** Rust's `checked_*` → `Option`, `overflowing_*` → tuple, `wrapping_*` → plain, `unchecked_*` → `unsafe` maps naturally onto Mojo: `raises` for the strict form, plain for the wrapping form. The `bit` library should decide one default and offer the other explicitly. (Assessment: derived from <https://doc.rust-lang.org/std/primitive.u32.html>.)
- **Return the previous bit from a write** (`put(bit) -> bool`) instead of forcing `test` + `set`. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
- **Provide count-only set algebra** (`union_count`, …) alongside materialising and in-place forms; on Mojo this is a cheap second entry point per operation. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
- **Use a range type for `[hi:lo]` bitfield operations** rather than two loose integers — `fixedbitset`'s `IndexRange`-typed `set_range`/`count_ones(range)` is the precedent, and it removes the hi/lo-swap failure mode. Source: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>.
- **Make ordering an explicit, non-global choice in the stream layer.** Rust's `Lsb0`/`Msb0` + `_le`/`_be` separation is the cleanest model researched; for Mojo a compile-time parameter or a distinct reader/writer type per order is preferable to Go's package-global endian switch. (Assessment: derived from <https://docs.rs/bitvec/latest/bitvec/order/index.html> and <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BigEndian>.)
- **Separate "element significance" from "bit order" in the docs and names**, because conflating them is the classic bitfield bug; `bitvec`'s explicit statement that the two traits are unrelated is worth reproducing as a design note. Source: <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>.
- **`view_bits_mut`-style zero-copy views** map well onto Mojo's `borrowed`/`mut` references: a bit-slice view over existing byte storage, with `split_at_mut`-style disjoint partitioning expressed as non-overlapping borrowed sub-views. Sources: <https://docs.rs/bitvec/latest/bitvec/>, plus Mojo value/borrow semantics per `_dev/README.md`. (Assessment: derived from <https://docs.rs/bitvec/latest/bitvec/>.)
- **A `bitflags`-style generated flags type** (newtype over an unsigned integer, named `const` bits, `contains`/`intersects`/`all`, text parse/format) is a compact, high-value container for the permission/feature-switch use case named in `_dev/README.md`, and is much smaller than a general bitset. Source: <https://docs.rs/bitflags/latest/bitflags/>.
- **Compile-time width checking in the bit reader/writer.** `bitstream-io`'s const-generic `read::<64, _>()` that refuses to compile into a `u32` is a strong idea for a Mojo library with comptime parameters. Source: <https://docs.rs/bitstream-io/latest/bitstream_io/>.
- **Treat "unknown bits" deliberately in the flags type** (allow or reject bits outside the declared mask) rather than leaving it implicit. Source: <https://docs.rs/bitflags/latest/bitflags/>.

## Sources

- Rust `u32` primitive reference (method index, `count_ones`, `leading_zeros`, `trailing_zeros`, `rotate_left`, `swap_bytes`, `reverse_bits`, `bit_width`, `highest_one`/`lowest_one`, `isolate_*`, `checked_shl`/`wrapping_shl`/`overflowing_shl`/`unchecked_shl`, `extract_bits`/`deposit_bits`): <https://doc.rust-lang.org/std/primitive.u32.html>
- `bitvec` crate (v1.1.1, MIT, ferrilab): <https://docs.rs/bitvec/latest/bitvec/>
  - `order` module (`Lsb0`/`Msb0`/`BitOrder`): <https://docs.rs/bitvec/latest/bitvec/order/index.html>
  - `BitField` trait (`load_le`/`load_be`/`store_le`/`store_be`): <https://docs.rs/bitvec/latest/bitvec/field/trait.BitField.html>
  - repository: <https://github.com/bitvecto-rs/bitvec>
- `fixedbitset` crate (v0.5.7, MIT OR Apache-2.0, petgraph): <https://docs.rs/fixedbitset/latest/fixedbitset/>
  - `FixedBitSet` type: <https://docs.rs/fixedbitset/latest/fixedbitset/struct.FixedBitSet.html>
  - repository: <https://github.com/petgraph/fixedbitset>
- `bitflags` crate (v2.13.2, MIT OR Apache-2.0): <https://docs.rs/bitflags/latest/bitflags/>
- `bitstream-io` crate (v4.10.0, MIT/Apache-2.0): <https://docs.rs/bitstream-io/latest/bitstream_io/>
- Cross-reference (ordering anti-pattern): Go `bitset` global `BigEndian()`/`LittleEndian()` — <https://pkg.go.dev/github.com/bits-and-blooms/bitset#BigEndian>
