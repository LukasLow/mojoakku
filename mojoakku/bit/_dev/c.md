# bit research: C

## 1. Standard library support

- **Before C23 there is no dedicated bit library at all.** The language exposes only raw
  operators: bitwise NOT `~`, AND `&`, OR `|`, XOR `^`, and shifts `<<` / `>>`
  (cppreference, *Arithmetic operators*, "Bitwise logic" / "Shift operators").
- **C23 adds `<stdbit.h>`** (`__STDC_VERSION_STDBIT_H__ = 202311L`), a set of
  **type-generic function macros** over all standard unsigned integer types
  (cppreference, *Standard library header `<stdbit.h>`*):
  `stdc_leading_zeros`, `stdc_leading_ones`, `stdc_trailing_zeros`,
  `stdc_trailing_ones`, `stdc_first_leading_zero`, `stdc_first_leading_one`,
  `stdc_first_trailing_zero`, `stdc_first_trailing_one`, `stdc_count_zeros`,
  `stdc_count_ones`, `stdc_has_single_bit`, `stdc_bit_width`, `stdc_bit_floor`,
  `stdc_bit_ceil`, `stdc_rotate_left`, `stdc_rotate_right`.
- The same header adds endianness macros `__STDC_ENDIAN_LITTLE__`,
  `__STDC_ENDIAN_BIG__`, `__STDC_ENDIAN_NATIVE__` (cppreference, `<stdbit.h>`,
  "Macro constants").
- **There is no container type in the standard library.** Bitsets are built by hand
  from `unsigned` words; the standard offers only language-level *struct bit-fields*
  (`unsigned int b : 3;`), whose layout is largely implementation-defined
  (cppreference, *Bit-fields*).
- **No bit-level stream I/O in the standard library.** `stdio.h` reads/writes whole
  bytes only; bit packing is entirely user code.
- `CHAR_BIT` (in `<limits.h>`) is the number of bits per byte and is used by bit
  algorithms to be byte-width-agnostic (cppreference, *Bit-fields*, example;
  Bit Twiddling Hacks uses `CHAR_BIT` throughout).
- C23 adds bit-precise integer types `_BitInt(N)` / `unsigned _BitInt(N)`, which can
  be used as bit-field base types (`unsigned _BitInt(5) : 4;`) (cppreference,
  *Bit-fields*, "since C23"; Clang supports `_BitInt(N)` as `_ExtInt(N)` in older
  modes — Clang Language Extensions).

## 2. Relevant community libraries

- **Linux kernel `bitmap` / `bitops`** (GPL-2.0, `include/linux/bitmap.h`,
  `include/linux/bitops.h`): the de-facto C bitset container — arrays of
  `unsigned long` plus `set_bit`/`clear_bit`/`test_bit`, logical ops, and
  `bitmap_read`/`bitmap_write` for n-bit fields. Mature (kernel core).
- **Michael Dipperstein `bitfile`** (ANSI C, LGPL): canonical minimal bit
  reader/writer over `FILE*`, with an 8-bit buffer plus bit counter.
  <https://michaeldipperstein.github.io/bitfile.html>
- **Michael Dipperstein `bitarray`** (ANSI C, LGPL): arbitrary-length bit array as
  `unsigned char[]`, with `BitArrayAnd`/`BitArrayOr`/`BitArrayXor` etc.;
  explicitly MSB-first numbering. <https://michaeldipperstein.github.io/bitarray.html>
- **`eerimoq/bitstream`** (MIT): small C bit-stream library.
  <https://github.com/eerimoq/bitstream>
- **GStreamer `gstbitwriter.c`** (LGPL): production bit writer used in media
  pipelines. <https://github.com/GStreamer/gstreamer/blob/master/libs/gst/base/gstbitwriter.c>
- **Sean Eron Anderson, "Bit Twiddling Hacks"** (public domain snippets): the
  canonical scalar-algorithm reference (popcount, reversals, sign extension).
  <https://graphics.stanford.edu/~seander/bithacks.html>
- **Compiler builtins**: GCC/Clang `__builtin_popcount`, `__builtin_clz`,
  `__builtin_ctz`, `__builtin_ffs`, `__builtin_parity`, `__builtin_clrsb` and the
  type-generic `g` variants (GCC *Bit Operation Builtins*).

## 3. Exposed APIs

- **Raw operators**: `~a`, `a&b`, `a|b`, `a^b`, `a<<b`, `a>>b` — no function
  wrapper (cppreference, *Arithmetic operators*).
- **`<stdbit.h>`** (C23), all take/return unsigned integers, e.g.:
  `unsigned int stdc_leading_zeros_ui(unsigned int value);` and the type-generic
  `stdc_leading_zeros(value)`; `stdc_count_ones`, `stdc_bit_width`,
  `stdc_bit_floor`, `stdc_bit_ceil`, `stdc_has_single_bit`,
  `stdc_rotate_left(value, count)` (cppreference, `<stdbit.h>`, "Synopsis"). All
  carry the `[[unsequenced]]` attribute (pure, unsequenced).
- **Compiler builtins** (GCC): `int __builtin_ffs(int x)` (1 + index of lowest set
  bit, or 0 for x==0), `__builtin_clz`, `__builtin_ctz`, `__builtin_popcount`,
  `__builtin_parity` (= popcount mod 2), `__builtin_clrsb` (leading redundant sign
  bits); type-generic `__builtin_clzg(x[, fallback])`,
  `__builtin_ctzg`, `__builtin_popcountg` (GCC *Bit Operation Builtins*).
- **Struct bit-fields**: `struct S { unsigned b1 : 5, : 11, b2 : 6, b3 : 2; };`,
  nameless `: 0` forces a new allocation unit; no address-of, no `sizeof` on a
  bit-field (cppreference, *Bit-fields*).
- **Linux `bitmap`** (kernel): `bitmap_zero/fill/copy`, `bitmap_and/or/xor/andnot`,
  `bitmap_complement`, `bitmap_equal/intersects/subset/empty/full`,
  `bitmap_weight`, `bitmap_set/clear`, `bitmap_shift_left/right`,
  `bitmap_read(map,start,nbits)` / `bitmap_write(map,value,start,nbits)`,
  `find_first_bit` / `find_next_bit` / `find_first_zero_bit`,
  `bitmap_alloc/bitmap_free` (`include/linux/bitmap.h`).
- **`bitfile`** (community): open/close, `GetBit`, `GetBits`, `PutBit`, `PutBits`,
  plus byte shortcuts that bypass the bit buffer (Dipperstein, *Bit File Stream
  Libraries*).

## 4. Error representation

- **No exceptions and no `Result` in C.** Errors are error codes, sentinel values,
  or `errno`. Out-of-range situations are typically **undefined behaviour**, not
  errors.
- **Shift out of range is UB**: "The behavior is undefined if rhs is negative or is
  greater or equal the number of bits in the promoted lhs" (cppreference,
  *Arithmetic operators*, "Shift operators").
- **Signed overflow is UB; unsigned overflow wraps** modulo 2^n (cppreference,
  *Arithmetic operators*, "Overflows").
- **Bit-field unsigned overflow wraps**: incrementing a `unsigned b:3` from 7
  yields 0 (cppreference, *Bit-fields*, example).
- **GCC builtins leave 0 as UB**: "`__builtin_clz` … If x is 0, the result is
  undefined." The type-generic `__builtin_clzg(x, fallback)` fixes this by taking a
  fallback (GCC *Bit Operation Builtins*).
- **`stdc_leading_zeros(0)` is well-defined** and returns the full width (cppreference,
  `stdc_leading_zeros`, example prints 8 for a zero `uint8_t`).
- The Linux `bitmap_read` contract: "For `@nbits` = 0 and `@nbits` > `BITS_PER_LONG`
  the return value is undefined" (documented as such in the header).
- `bitfile` reports EOF/error by the underlying `FILE*` mechanics (e.g. a sentinel
  return), not by exceptions (Derived from Dipperstein, *Bit File Stream Libraries*).

## 5. Ownership semantics

- **C has no ownership model.** Buffers are caller-allocated and caller-owned; there
  is no destructor and no reference counting.
- Raw `unsigned char[]` / `unsigned long[]` decay to pointers: **length is not
  carried by the value**, so every operation needs an explicit `nbits` argument
  (Linux `bitmap.h` passes `unsigned int nbits` on essentially every function).
- Kernel bitmaps have explicit allocation/free pairs: `bitmap_alloc` /
  `bitmap_zalloc` allocate `unsigned long*`, `bitmap_free` releases
  (`include/linux/bitmap.h`).
- `fd_set` in `<sys/select.h>` is a **fixed-size, caller-owned buffer**;
  `FD_CLR`/`FD_SET` with an out-of-range fd is UB (man7 `select(2)`, NOTES).
- `bitfile` wraps a `FILE*` in a struct that also holds the bit buffer; the underlying
  file is owned by the caller (Dipperstein, *Bit File Stream Libraries*).
- Bit-fields cannot have their address taken, so no pointer/reference aliasing to a
  single field (cppreference, *Bit-fields*).

## 6. Blocking / non-blocking

- **The bit-manipulation layer is pure computation**: no I/O, no blocking, no async
  model. `<stdbit.h>` functions are marked `[[unsequenced]]`, i.e. side-effect free,
  which makes them freely reorderable and thread-safe (cppreference, `<stdbit.h>`,
  "Synopsis").
- **Bit-level stream I/O follows the underlying stream's model.** C `stdio` `FILE*`
  I/O is blocking by default; non-blocking I/O is achieved only by operating on a
  file descriptor opened `O_NONBLOCK` (the `O_NONBLOCK` flag itself is an fd-level
  concept; see `select(2)` NOTES on non-blocking sockets).
- No cancellation or timeout concept exists in the bit layer; both belong to the
  surrounding stream/`select`/`poll` code.

## 7. Width and ordering model

- **Width is fixed per integer type**, given by `sizeof(T) * CHAR_BIT`
  (Bit Twiddling Hacks uses this expression throughout).
- **Signed vs unsigned is decisive**: right-shifting a negative signed value is
  implementation-defined ("in most implementations, this performs arithmetic right
  shift"); left-shifting a signed value that overflows is UB; the C23 bit functions
  are specified for **unsigned** types only (cppreference, *Arithmetic operators*;
  `<stdbit.h>`).
- **Bit numbering convention is LSB = bit 0**, increasing towards the MSB
  (cppreference `<stdbit.h>`; confirmed also by the C++ bit functions).
- The `<stdbit.h>` family separates *leading/trailing* zeros and ones and also
  *first* zero/one at both ends — a 8-way orthogonal decomposition rather than a
  minimal API.
- **Struct bit-field ordering is implementation-defined**: "The order of bit-fields
  within an allocation unit (on some platforms, bit-fields are packed
  left-to-right, on others right-to-left)" and whether a bit-field may straddle an
  allocation unit is also implementation-defined (cppreference, *Bit-fields*).
- **Endianness is a separate axis** and is queryable at compile time via
  `__STDC_ENDIAN_NATIVE__` (cppreference, `<stdbit.h>`, "Macro constants").
- Container-to-scalar relation: a bitset is just an array of unsigned words; the
  mapping from bit index to (word, bit-within-word) is the only ordering decision
  (`bitmap_read`/`bitmap_write` in `include/linux/bitmap.h` implement exactly that).

## 8. Bounds, overflow and growth

- **Shift by >= width or negative => UB; shift of a signed overflow => UB**
  (cppreference, *Arithmetic operators*, "Shift operators" / "Overflows").
- **Out-of-range bit index has no defined check** in the language; struct bit-fields
  silently truncate to their width (cppreference, *Bit-fields*).
- The kernel bitmap API is **fixed-size**: every call takes `nbits`, and
  `bitmap_alloc(nbits, flags)` allocates the storage; there is no automatic growth
  (`include/linux/bitmap.h`).
- `bitmap_read`/`bitmap_write` explicitly document that `nbits == 0` or
  `nbits > BITS_PER_LONG` yields an undefined / no-op result.
- `fd_set` is hard-capped at `FD_SETSIZE` (1024 in glibc); larger fds are UB, which
  is why `poll`/`epoll` exist (man7 `select(2)`, NOTES/BUGS).
- `stdc_leading_zeros` handles the all-zero input correctly (returns the width),
  unlike the raw builtin — a concrete example of a wrapper adding definedness
  (cppreference, `stdc_leading_zeros`).

## 9. Scalar functions, container type and bit-level I/O

| Layer | Provided by C? | What exists |
| --- | --- | --- |
| Scalars | **Yes (C23) + builtins** | raw operators; `<stdbit.h>` macros; `__builtin_popcount/clz/ctz/ffs/parity` |
| Container | **No** | only manual `unsigned long[]`; de-facto standard is the kernel `bitmap` API |
| Bit-level stream I/O | **No** | byte-only `stdio`; community `bitfile`/`bitstream`/`gstbitwriter` |

(Assessment: derived from cppreference `<stdbit.h>` & *Bit-fields*, GCC *Bit
Operation Builtins*, and the community library pages.)

## 10. Interesting design decisions

- **Type-generic macros** (`stdc_*`) give one name for every unsigned type without
  templates — the C answer to C++ function templates (cppreference, `<stdbit.h>`).
- **`[[unsequenced]]`** on every `stdc_*` function is an explicit purity contract:
  the compiler may vectorize/reorder them freely, and they are automatically
  thread-safe (cppreference, `<stdbit.h>`).
- **Unsigned-only, defined-for-zero API**: C23 deliberately defines
  `stdc_leading_zeros(0) = width`, repairing the builtin's UB hole (cppreference,
  `stdc_leading_zeros`).
- **`__builtin_clzg`/`ctzg` optional fallback argument** makes the zero case a
  caller choice rather than a trap (GCC *Bit Operation Builtins*).
- **`bitmap_read` / `bitmap_write`** are exactly the `get_bits`/`set_bits` pair over
  an arbitrary start and width, and they explicitly document the "as-if n calls to
  `__assign_bit`" semantics for writing (Linux `bitmap.h`).
- **The 8-bit-buffer + counter reader** in `bitfile` is the minimal, battle-tested
  LSB-first bit reader: read byte, emit LSB, shift right, decrement counter
  (Dipperstein, *Bit File Stream Libraries*).
- **Explicit MSB-first numbering choice** in Dipperstein's `bitarray`: bit 0 of the
  most significant byte is the array's MSB — a documented, deliberate convention
  (Dipperstein, *Bit Array Libraries*).

## 11. Decisions NOT to copy

- **UB for out-of-range shift amounts.** Mojo should either return a defined value
  or raise; silently invoking UB is an unacceptable contract (cppreference,
  *Arithmetic operators*).
- **Implementation-defined bit-field ordering / straddling.** The layout of struct
  bit-fields is not portable and must not be a model for a portable API
  (cppreference, *Bit-fields*).
- **Macro-based type-generic dispatch.** It cannot be documented per-type, cannot be
  overloaded and interacts badly with tooling; Mojo has generic parameters instead.
- **Fixed-size `fd_set` and value-result arguments.** The `select(2)` man page
  itself calls the value-result design "a design error" (man7 `select(2)`, BUGS).
- **Length-less pointers.** Passing `unsigned char*` plus a separate `nbits` on
  every call is error-prone and is what a Mojo value type should eliminate
  (Linux `bitmap.h`).
- **Caller-side `bitmap_free` bookkeeping.** Unnecessary in a language with
  destructors / value semantics (`include/linux/bitmap.h`).

## 12. Ideas fitting Mojo

- **Wrap, don't rebuild, the scalars.** `std.bit` already has `pop_count`,
  `count_leading_zeros`, `count_trailing_zeros`, `bit_reverse`, `rotate_bits_left/right`,
  `next/prev_power_of_two`, `log2_floor/ceil` (mojov1 buch, `mojov1/stdlib/bit`).
  The C `<stdbit.h>` split into leading/trailing × zeros/ones × first/count is a
  good checklist for what a wrapper could add.
- **A `BitSet` container with explicit capacity** mirrors the kernel `bitmap`:
  set/clear/toggle/test, union/intersection/difference/complement, cardinality,
  `find_first_set` / `find_next_set` (Linux `bitmap.h`; Boost names
  `find_first`/`find_next`).
- **`get_bits(hi, lo)` / `set_bits(hi, lo, value)`** over an integer value is exactly
  the kernel `bitmap_read`/`bitmap_write` concept applied to a scalar
  (`include/linux/bitmap.h`).
- **A `BitReader`/`BitWriter` with an explicit ordering parameter** (`LSBFirst` vs
  `MSBFirst`) captures the C lesson that both orderings are legitimate tools
  (ryg, *Reading bits in far too many ways*; Dipperstein's LSB-first reader vs
  MSB-first bitarray).
- **Make the zero case defined.** Follow C23's `stdc_leading_zeros(0) == width`
  instead of the builtin's UB (cppreference).
- **Expose `Endian` as a compile-time query**, mirroring `__STDC_ENDIAN_NATIVE__`
  (cppreference, `<stdbit.h>`).
- **Use `raises` for out-of-range index/shift** where C uses UB or sentinels, and
  value semantics (owned buffer) where C uses pointer + length.

## Sources

- <https://en.cppreference.com/w/c/language/operator_arithmetic> — bitwise logic, shift operators, overflows, UB
- <https://en.cppreference.com/w/c/header/stdbit> — `<stdbit.h>` synopsis, `[[unsequenced]]`, endian macros
- <https://en.cppreference.com/w/c/numeric/bit_manip> — bit-manipulation function list
- <https://en.cppreference.com/w/c/numeric/bit/stdc_leading_zeros> — defined behaviour for 0
- <https://en.cppreference.com/w/c/language/bit_field> — bit-field rules, implementation-defined ordering, `_BitInt`
- <https://gcc.gnu.org/onlinedocs/gcc/Bit-Operation-Builtins.html> — `__builtin_popcount/clz/ctz/ffs/parity/clzg/ctzg`
- <https://gcc.gnu.org/onlinedocs/gcc/Other-Builtins.html> — `__builtin_bit_cast`, `__builtin_clear_padding`
- <https://clang.llvm.org/docs/LanguageExtensions.html> — `_BitInt(N)` / `_ExtInt(N)`, `__has_builtin`
- <https://graphics.stanford.edu/~seander/bithacks.html> — Bit Twiddling Hacks
- <https://raw.githubusercontent.com/torvalds/linux/master/include/linux/bitmap.h> — bitmap container, `bitmap_read`/`bitmap_write`
- <https://raw.githubusercontent.com/torvalds/linux/master/include/linux/bitops.h> — `set_bit`/`test_bit`, rotations, `sign_extend32/64`, `parity8`
- <https://michaeldipperstein.github.io/bitfile.html> — LSB-first bit stream reader/writer
- <https://michaeldipperstein.github.io/bitarray.html> — MSB-first bit array library
- <https://github.com/eerimoq/bitstream> — C bit stream library (MIT)
- <https://github.com/GStreamer/gstreamer/blob/master/libs/gst/base/gstbitwriter.c> — production bit writer
- <https://man7.org/linux/man-pages/man2/select.2.html> — `fd_set`, `FD_SETSIZE`, value-result design error
- <https://fgiesen.wordpress.com/2018/02/19/reading-bits-in-far-too-many-ways-part-1/> — LSB-first vs MSB-first bit packing, shift UB across architectures
