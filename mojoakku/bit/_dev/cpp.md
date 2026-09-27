# bit research: C++

## 1. Standard library support

- **`<bitset>`** provides `std::bitset<N>` — a **fixed-width** (compile-time `N`)
  sequence of bits with logic operators, shifts, `set`/`reset`/`flip`,
  `test`/`count`/`size` and conversions. All member functions are `constexpr` since
  C++23 (cppreference, *std::bitset*). Header: `<bitset>`.
- **`std::vector<bool>`** is a **space-efficient, possibly-non-contiguous
  specialization** of `std::vector<bool>`; "The manner … is implementation defined.
  One potential optimization involves coalescing vector elements such that each
  element occupies a single bit" (cppreference, *std::vector<bool>*).
- **`<bit>` (C++20)** — free function templates on unsigned integers:
  `bit_cast`, `byteswap` (C++23), `has_single_bit`, `bit_ceil`, `bit_floor`,
  `bit_width`, `rotl`, `rotr`, `countl_zero`, `countl_one`, `countr_zero`,
  `countr_one`, `popcount`, plus `std::endian` and (C++29) `shl`/`shr`
  (no-UB shifts), `bit_reverse`, `bit_repeat`, `bit_compress`/`bit_expand`
  (PEXT/PDEP) (cppreference, *Standard library header `<bit>`*).
- **`<cstddef>` `std::byte` (C++17)**: `enum class byte : unsigned char {}` — "a
  mere collection of bits, supporting only bitshift operations with an integer, and
  bitwise and comparison operations with another `std::byte`" (cppreference,
  *std::byte*).
- **`<stdbit.h>` (C++26)** exposes the C23 `stdc_*` macros in C++ as well
  (cppreference, *Standard library header `<bit>`*, navigation).
- **No bit-level stream I/O in the standard library**: `istream`/`ostream` operate on
  bytes/words; bit packing is user code (Assessment: derived from cppreference
  `std::bitset` non-member operators `<<`/`>>`, which format/parse a whole bitset,
  not a bit stream).

## 2. Relevant community libraries

- **Boost.DynamicBitset** (Boost Software License): `boost::dynamic_bitset<Block,
  AllocatorOrContainer>` — "nearly identical to `std::bitset` … the size … can
  change at runtime" (Boost docs, *Boost.DynamicBitset* index and reference).
- **steinwurf/bitter** (BSD-3-Clause, header-only C++): compile-time-sized field
  reader/writer templates with explicit `lsb0`/`msb0` mode:
  `bitter::lsb0_writer<Type, Fields...>()`, `bitter::msb0_reader<...>(value)`.
  <https://github.com/steinwurf/bitter>
- **KredeGC/BitStream** (header-only C++): `bit_writer<T>`/`bit_reader<T>` with trait
  specializations, extension-oriented. <https://kredegc.github.io/BitStream/>
- **Martin Weihrauch `BitStream`**, **FranX1024 `bitstream`**: further C++ bit-stream
  libraries found in the ecosystem (GitHub search result listing).
- **LLVM `BitstreamReader.h`**: production low-level bitstream reader used by
  Clang/LLVM bitcode. <https://github.com/llvm/llvm-project/blob/main/llvm/include/llvm/Bitstream/BitstreamReader.h>
- **Michael Dipperstein `bitfile-cpp`** (LGPL): C++ wrapper using (not inheriting)
  `ifstream`/`ofstream`. <https://github.com/michaeldipperstein/bitfile-cpp>

## 3. Exposed APIs

- **`std::bitset<N>`**: `operator[]` (const returns `bool`, non-const returns
  `reference`), `test(pos)` (bounds-checked, throws), `all()/any()/none()` (C++11),
  `count()`, `size()`, `operator&=/|=/^=/~`, `operator<</>>=`, `set/reset/flip`
  (with and without a position), `to_string`, `to_ulong`, `to_ullong`, non-member
  `operator&/|/^` and stream `<<`/`>>` (cppreference, *std::bitset*; *all, any,
  none*; *operator[]*; *test*).
- **`std::vector<bool>`**: the full `std::vector` interface plus
  `flip()` and static `swap(reference, reference)`; `reference` is a proxy class
  returned by `operator[]` **by value** (cppreference, *std::vector<bool>*).
- **`<bit>`** signatures (cppreference, *`<bit>`* synopsis):
  `template<class To, class From> constexpr To bit_cast(const From&) noexcept;`
  `template<class T> constexpr int popcount(T x) noexcept;`
  `constexpr T rotl(T x, int s) noexcept;` `countl_zero/countr_zero/…`,
  `has_single_bit`, `bit_ceil`, `bit_floor`, `bit_width`, `byteswap`.
- **`std::byte`**: `std::to_integer<IntegerType>(b)`, `operator<<=/>>=`, `<<`/`>>`
  (with integer shift), `|=/&=/^=`, `|/&/^/~` (cppreference, *std::byte*).
- **`boost::dynamic_bitset`** adds runtime API on top of the `bitset` set:
  `resize`, `push_back`/`pop_back`, `push_front`/`pop_front`, `append`,
  `find_first`/`find_first_off`, `find_next`/`find_next_off`, `intersects`,
  `is_subset_of`, `is_proper_subset_of`, `operator-` (set difference),
  `to_block_range`/`from_block_range`, `num_blocks`, `bits_per_block`, `npos`
  (Boost reference).

## 4. Error representation

- **Two deliberately different access idioms in `std::bitset`:**
  `operator[]` does **no** check — "If `pos < size()` is false, the behavior is
  undefined" (C++26: contract violation in hardened mode) — while `test()` **does**
  check and "Throws `std::out_of_range` if `pos` does not correspond to a valid bit
  position" (cppreference, *operator[]*, *test*).
- **`std::bitset::test` was made well-defined retroactively**: LWG 2250 "the
  behavior was undefined if pos does not correspond to a valid bit position" →
  "always throws an exception in this case" (cppreference, *test*, Defect reports).
- **`std::vector<bool>::at`** is the bounds-checked accessor and throws
  `std::out_of_range`; `operator[]` does not (cppreference, *std::vector<bool>*).
- **`<bit>` functions are `noexcept` and never raise**; they are defined for the
  whole input domain, including zero: `countl_zero(0) == bit width`
  (cppreference, *countl_zero*, example: `countl_zero(00000000) = 8`).
- **Boost.DynamicBitset deliberately does NOT throw**:
  "`dynamic_bitset` does not throw exceptions when a precondition is violated (as is
  done in `std::bitset`). Instead `BOOST_ASSERT()` is used." (Boost, *Rationale*).
- **Raw C++ operators keep C's UB**: shifts and signed overflow are still UB in C++
  pre-C++20; `<bit>`'s `shl`/`shr` (C++29) exist "without the possibility of
  undefined behavior" (cppreference, *`<bit>`*).

## 5. Ownership semantics

- **`std::bitset<N>` is a value type**: fixed size, no allocation, copy-constructible
  and copy-assignable; it "meets the requirements of CopyConstructible and
  CopyAssignable" (cppreference, *std::bitset*).
- **`std::vector<bool>` owns heap storage** via its `Allocator`, grows/shrinks at
  runtime, and **does not necessarily store its elements contiguously**; different
  elements in the same container **cannot** be modified concurrently by different
  threads (cppreference, *std::vector<bool>*).
- **The `reference` proxy is the famous ownership wrinkle**: `operator[]` returns
  `std::vector<bool>::reference` **by value**, and `std::bitset<N>::reference` for
  the mutable case ("proxy class representing a reference to a bit") — assignment
  through it writes the bit (cppreference, *std::vector<bool>*; *std::bitset*).
- **Boost.DynamicBitset owns a `Block[]` allocated through the `Allocator`, with an
  explicit `Block` template parameter (default `unsigned long`)** and
  `reserve`/`capacity`/`shrink_to_fit`; its iterators are non-`LegacyForwardIterator`
  because of the proxy reference (Boost reference + Rationale).
- **`std::byte` is trivially copyable and copyable by value**; it is the standard
  way to name raw storage without borrowing `char` (cppreference, *std::byte*).

## 6. Blocking / non-blocking

- **The whole `<bit>` / `<bitset>` / `std::byte` layer is pure computation**:
  `constexpr`, `noexcept`, no I/O, no blocking, no async. There is no concurrency
  model to choose (cppreference, *`<bit>`*, *std::bitset*).
- **`std::bitset` is not thread-safe at the element level after the proxy
  indirection**; the standard explicitly removes the per-element concurrent-write
  guarantee only for `std::vector<bool>` (cppreference, *std::vector<bool>*).
- **Bit-level I/O inherits the stream's blocking model**: `std::istream`/`ostream`
  block; non-blocking requires OS-level `O_NONBLOCK` on the underlying fd.
  (Assessment: derived from cppreference `std::bitset` stream operators and the
  general `iostream` model.)
- No cancellation or timeout abstraction is part of any bit API.

## 7. Width and ordering model

- **Width is a template parameter for `std::bitset<N>`** (fixed at compile time) and
  a runtime property for `std::vector<bool>`/`boost::dynamic_bitset`
  (cppreference, *std::bitset*, *std::vector<bool>*; Boost reference).
- **Defined bit numbering: index 0 is the least significant bit.** "For the purpose
  of the string representation and of naming directions for shift operations, the
  sequence is thought of as having its lowest indexed elements at the *right*, as in
  the binary representation of integers." (cppreference, *std::bitset*.) Boost states
  it explicitly: "The bit at position 0 is called the least significant bit"
  (Boost, *Definitions*).
- **Endianness of scalar types is queryable**: `std::endian` with `little`, `big`,
  `native` (cppreference, *`<bit>`*).
- **`std::byte` is ordering-agnostic by design**: only shifts and bitwise ops, no
  arithmetic, no interpretation (cppreference, *std::byte*).
- **`bit_cast` is the width-preserving reinterpretation tool**: requires
  `sizeof(To) == sizeof(From)` and both TriviallyCopyable, and every bit of the
  result corresponds to a bit of the source (cppreference, *bit_cast*).
- **`<bit>` functions take unsigned integer types only**; e.g. `countl_zero`
  participates in overload resolution only for unsigned types (cppreference,
  *countl_zero*).

## 8. Bounds, overflow and growth

- **`std::bitset<N>` cannot grow** — `N` is fixed; out-of-range `operator[]` is UB,
  `test()` throws (cppreference, *operator[]*, *test*).
- **`std::vector<bool>` grows/shrinks via the whole `vector` interface**
  (`resize`, `push_back`, `pop_back`, `reserve`), and `std::bitset` is explicitly the
  recommendation when the size is known at compile time (cppreference,
  *std::vector<bool>*, Notes).
- **`boost::dynamic_bitset` is the explicit growth API**: `resize(num_bits)`,
  `push_back` (new most significant bit), `push_front` (new least significant bit),
  `reserve`, `shrink_to_fit`, `clear` (size → 0) (Boost reference).
- **`std::vector<bool>` is not a full Container**: its `iterator` is
  implementation-defined and may fail `LegacyForwardIterator`, so algorithms like
  `std::search` can fail at compile time or runtime (cppreference,
  *std::vector<bool>*, Notes). Boost repeats this for `dynamic_bitset` (its
  iterators do not satisfy `LegacyForwardIterator`; C++20 ranges iterators are
  provided) (Boost, *Rationale*).
- **Shift/overflow UB remains in raw operators**; `<bit>`'s `shl`/`shr` (C++29) are
  the defined replacements (cppreference, *`<bit>`*).
- **`bit_cast` on padding/indeterminate bits**: "The values of padding bits in the
  returned `To` object are unspecified"; indeterminate bits in the result give UB
  unless the enclosing object is uninitialized-friendly (C++26 rules)
  (cppreference, *bit_cast*).

## 9. Scalar functions, container type and bit-level I/O

| Layer | Provided by C++? | What exists |
| --- | --- | --- |
| Scalars | **Yes** | `<bit>` (`popcount`, `countl_zero`, `rotl`, `bit_ceil`, …), raw operators, C23 `<stdbit.h>` in C++26 |
| Container | **Yes, three models** | `std::bitset<N>` (fixed, value), `std::vector<bool>` (dynamic, packed), `boost::dynamic_bitset` (dynamic, block-parameterised) |
| Bit-level stream I/O | **No** | only community libs (`bitter`, `BitStream`, LLVM `BitstreamReader`) |

(Assessment: derived from cppreference *`<bit>`*, *std::bitset*, *std::vector<bool>;
Boost.DynamicBitset reference; and the listed community libraries.*)

## 10. Interesting design decisions

- **Two access verbs encode the safety/perf trade-off**: unchecked `operator[]` vs
  checked `test()`/`at()` that throws — and LWG 2250 deliberately moved `test` from
  UB to a guaranteed throw (cppreference, *operator[]*, *test*).
- **`reference` proxy types** let a packed container expose rvalue-like bit lvalues;
  Boost notes the cost: "Because of the proxy reference type, `dynamic_bitset` is not
  a Container and its iterators do not satisfy … LegacyForwardIterator" (Boost,
  *Rationale*).
- **`[[constexpr]]` everywhere**: `std::bitset` members are `constexpr` since C++23
  and `<bit>` since C++20, so bitset logic can run at compile time
  (cppreference, *std::bitset*, *`<bit>`*).
- **Block-parameterised storage**: `boost::dynamic_bitset<Block>` defaults to
  `unsigned long` and exposes `bits_per_block`/`to_block_range` — the container's
  word type is a first-class knob (Boost reference).
- **Set semantics are first-class for dynamic bitsets**: `intersects`,
  `is_subset_of`, `is_proper_subset_of`, and `operator-` (set difference) beyond the
  pure bitwise ops (Boost reference).
- **`std::byte` separates "collection of bits" from "character"/"arithmetic type"**,
  so raw bit work does not silently get integer semantics (cppreference,
  *std::byte*).
- **`<bit>`'s `shl`/`shr` (C++29) make shifts total**, replacing a decades-old UB
  surface (cppreference, *`<bit>`*).
- **`bit_cast` replaces `memcpy`/`reinterpret_cast` for bit reinterpretation with a
  constexpr, type-checked contract** (cppreference, *bit_cast*).
- **Explicit MSB0/LSB0 mode in `bitter`**: the library treats bit numbering as a
  configuration axis rather than a hard-coded convention
  (<https://github.com/steinwurf/bitter>).

## 11. Decisions NOT to copy

- **Compile-time `std::bitset<N>` width.** Fixed-width types force a template
  parameter and cannot express runtime-sized flag sets; Mojo needs a growable
  container (Assessment: derived from cppreference *std::bitset* Notes).
- **`std::vector<bool>`'s special-casing of one type.** A container whose behaviour
  and iterators depend on `T == bool` is surprising and breaks generic code
  (cppreference, *std::vector<bool>*, Notes). A dedicated `BitSet` type is clearer.
- **Proxy `reference` types with non-ForwardIterator iterators.** The Boost docs
  explicitly list the cost of the proxy design (Boost, *Rationale*); Mojo should not
  reproduce an iterator that silently breaks algorithms.
- **UB on out-of-range `operator[]`.** Undefined behaviour for an index error is not
  a contract worth copying (cppreference, *operator[]*).
- **Throwing `std::out_of_range` from a bit accessor** where Mojo can use `raises`
  with a documented error type (cppreference, *test*).
- **Implementation-defined `std::vector<bool>` layout.** "implementation defined"
  space efficiency must not be the basis of a documented behaviour
  (cppreference, *std::vector<bool>*).
- **`bit_cast`'s unspecified padding bits** should not be reproduced as a contract;
  prefer fully-defined conversions (cppreference, *bit_cast*).

## 12. Ideas fitting Mojo

- **Wrap `std.bit` scalars; don't rebuild them.** mojov1 already lists `pop_count`,
  `count_leading_zeros`, `count_trailing_zeros`, `bit_reverse`, `byte_swap`,
  `rotate_bits_left/right`, `next/prev_power_of_two`, `log2_floor/ceil`
  (mojov1 buch, `mojov1/stdlib/bit`). The C++ `<bit>` surface adds the useful
  complements: `countl_one`/`countr_one`, `bit_width`, `has_single_bit`, and the
  defined `shl`/`shr` (cppreference, *`<bit>`*).
- **Two access verbs, defined semantics**: mirror `operator[]` (unchecked, fast) vs
  `test()` (checked, `raises`) but with **no UB** and an explicit error type
  (cppreference, *operator[]*, *test*).
- **A growable `BitSet` value type** with the Boost API as the checklist:
  `set`/`clear`/`toggle`/`test`, `count`, `any`/`all`/`none`, `find_first` /
  `find_next` over set bits, union/intersection/difference/complement, `resize`,
  `push_back`/`pop_back` (Boost reference).
- **Expose the block/word type as a generic parameter** rather than hard-coding 64
  bits, as `boost::dynamic_bitset<Block>` does (Boost reference).
- **`bit_cast`-equivalent reinterpretation should be a safe, size-checked API**, not
  a raw pointer cast (cppreference, *bit_cast*).
- **A `byte`-like "collection of bits" type** for bit-level I/O, following
  `std::byte`'s separation from arithmetic types (cppreference, *std::byte*).
- **`get_bits(hi, lo)` / `set_bits(hi, lo, value)`** with defined behaviour for the
  full-width and zero-width cases, and total (non-UB) shifts, drawing on
  `<bit>::shl/shr` and `bit_cast` (cppreference, *`<bit>`*, *bit_cast*).
- **Explicit bit ordering (`LSBFirst`/`MSBFirst`) for the future `BitReader`/
  `BitWriter`**, mirroring `bitter::lsb0_*` / `msb0_*`
  (<https://github.com/steinwurf/bitter>).

## Sources

- <https://en.cppreference.com/w/cpp/utility/bitset> — `std::bitset` overview, member list, Notes
- <https://en.cppreference.com/w/cpp/utility/bitset/operator_at> — unchecked `operator[]`, UB / LWG 907
- <https://en.cppreference.com/w/cpp/utility/bitset/test> — checked `test`, `std::out_of_range`, LWG 2250
- <https://en.cppreference.com/w/cpp/utility/bitset/all_any_none> — `all`/`any`/`none`, LWG 693
- <https://en.cppreference.com/w/cpp/container/vector_bool> — packed specialization, proxy reference, Notes
- <https://en.cppreference.com/w/cpp/header/bit> — `<bit>` synopsis: `bit_cast`, `popcount`, `rotl`, `shl`/`shr`, `endian`
- <https://en.cppreference.com/w/cpp/numeric/bit_cast> — `bit_cast` requirements, padding/indeterminate rules
- <https://en.cppreference.com/w/cpp/numeric/countl_zero> — unsigned-only, `countl_zero(0) == width`
- <https://en.cppreference.com/w/cpp/types/byte> — `std::byte` (collection of bits, non-arithmetic)
- <https://www.boost.org/doc/libs/latest/libs/dynamic_bitset/doc/html/index.html> — Boost.DynamicBitset rationale, non-throwing
- <https://www.boost.org/doc/libs/latest/libs/dynamic_bitset/doc/html/dynamic_bitset/reference/boost/dynamic_bitset.html> — full member list, `Block`, `find_first`/`find_next`, subsets
- <https://github.com/steinwurf/bitter> — `lsb0`/`msb0` reader/writer templates (BSD-3-Clause)
- <https://kredegc.github.io/BitStream/> — header-only C++ bit stream with traits
- <https://github.com/llvm/llvm-project/blob/main/llvm/include/llvm/Bitstream/BitstreamReader.h> — production bitstream reader
- <https://github.com/michaeldipperstein/bitfile-cpp> — C++ bitfile wrapper over `ifstream`/`ofstream`
- <https://en.cppreference.com/w/cpp/language/operator_arithmetic> — C++ bitwise/shift operators and their UB
