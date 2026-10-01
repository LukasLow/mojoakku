# prim_endian research: C++

## 1. Standard library support

- **`std::endian` (C++20, `<bit>`)** is the compile-time native-endianness query:
  `enum class endian { little = /* impl-defined */, big = /* impl-defined */,
  native = /* impl-defined */ };`. "Indicates the endianness of all scalar
  types": `native == little` if all scalars are little, `native == big` if all are
  big; on a mixed-endian platform native equals neither; if all scalar types have
  `sizeof == 1`, all three values are the same. Feature-test macro
  `__cpp_lib_endian` (cppreference, *std::endian*).
- **`std::byteswap` (C++23, `<bit>`)**:
  `template<class T> constexpr T byteswap(T n) noexcept;` "Reverses the bytes in
  the given integer value". `T` must be integral, must not have padding bits
  (otherwise ill-formed); feature-test macro `__cpp_lib_byteswap` (cppreference,
  *std::byteswap*). The reference implementation is
  `bit_cast<std::array<std::byte, sizeof(T)>>` + reverse + `bit_cast<T>`
  (cppreference, *std::byteswap*, "Possible implementation").
- **`std::bit_cast` (C++20, `<bit>`)**:
  `template<class To, class From> constexpr To bit_cast(const From& from) noexcept;`
  reinterprets the object representation bit-for-bit; requires
  `sizeof(To) == sizeof(From)` and both `TriviallyCopyable`; padding bits in the
  result are unspecified; the canonical replacement for `memcpy`/
  `reinterpret_cast` type punning (cppreference, *bit_cast*). The compiler
  intrinsic behind it is `__builtin_bit_cast` (GCC, *Other Built-in Functions*).
- **No `htobe`/`be*toh` names in the standard library.** Those are POSIX/glibc
  extensions; the C++ standard instead puts the native-endianness constant into
  `<bit>` and the raw reversal into `std::byteswap` (cppreference, *std::endian*,
  *std::byteswap*; man7 `endian(3)`).
- **No standardized byte-order conversion pair** (`native_to_big` etc.) exists in
  the ISO C++ standard library. `std::endian` + `std::byteswap` is the whole
  basis; building the conversions is left to the user or Boost (cppreference,
  *std::endian* *See also*, which points only to `byteswap` and to the C
  documentation).
- **C++23/26 gains the C headers:** C23 `<stdbit.h>` is exposed in C++ as
  `<stdbit.h>`/`<stdbit.h>` header page listed under C++26 (cppreference,
  *Standard library header `<stdbit.h>` (C++26)*). It carries the C23 endian
  macros, not new C++ functions (cppreference, C23 `<stdbit.h>`).
- `std::byteswap` deliberately does **not** touch byte order semantics: it is a
  pure reversal, so it is useful "for processing data of different endianness"
  (cppreference, *std::byteswap*, Notes).

## 2. Relevant community libraries

- **Boost.Endian** (Boost Software License 1.0; header-only, requires C++11 since
  1.84): the reference third-party design. It offers **three approaches**
  (Boost docs, *Introduction to the Boost.Endian library*):
  1. **Endian conversion functions** (`boost::endian::native_to_big`,
     `big_to_native`, `little_to_native`, `native_to_little`,
     `endian_reverse`, `conditional_reverse`, plus `*_inplace` and
     `endian_load`/`endian_store`, and `load_big_u32`/`store_little_s64`-style
     convenience wrappers) — header `boost/endian/conversion.hpp`.
  2. **Endian buffer types** (`endian_buffer`, `big_int32_buf_t`,
     `little_int32_buf_t`, `…_ut` unaligned forms) — header
     `boost/endian/buffers.hpp`; sizes 8/16/24/32/40/48/56/64 bits.
  3. **Endian arithmetic types** (`endian_arithmetic`, `big_int32_t`) — header
     `boost/endian/arithmetic.hpp`; same sizes, implicit conversions and full
     arithmetic.
  Maturity: long-lived, maintained, part of Boost since 1.58 (Boost, *Revision
  History*). It uses compiler byte-swap intrinsics when available
  (`__builtin_bswap16` etc.; `BOOST_ENDIAN_NO_INTRINSICS` disables) (Boost,
  *Built-in support for Intrinsics*).
- **Boost.DynamicBitset** is unrelated to endianness but is the community pattern
  for a runtime-sized bit container (Boost.DynamicBitset). `GUESS:` no distinct
  endian-focused community library beyond Boost.Endian and compiler/OS builtins
  was found in this run; the space is effectively covered by `<bit>` + glibc on
  the one side and Boost on the other.

## 3. Exposed APIs

- **`std::endian`**: three enumerators `little`, `big`, `native` in namespace
  `std` (cppreference, *std::endian*). The suggested implementation maps
  `little = __ORDER_LITTLE_ENDIAN__`, `big = __ORDER_BIG_ENDIAN__`,
  `native = __BYTE_ORDER__` on non-MSVC compilers, and
  `little = 0, big = 1, native = little` on MSVC (cppreference, *std::endian*,
  "Possible implementation"; P0463R1, Hinnant).
- **`std::byteswap(T)`**: one function template for any integral `T`, returns the
  byte-reversed value; `static_assert(std::byteswap('a') == 'a')` in the example
  (cppreference, *std::byteswap*).
- **`std::bit_cast<To>(From)`**: one function template, size-checked,
  `constexpr` under the documented conditions (cppreference, *bit_cast*).
- **Boost conversion functions** (value-returning):
  `endian_reverse(Endian x)`, `big_to_native`, `native_to_big`, `little_to_native`,
  `native_to_little`, `conditional_reverse<O1,O2>(x)` /
  `conditional_reverse(x, order1, order2)`; in-place overloads
  `endian_reverse_inplace`, `big_to_native_inplace`, `native_to_big_inplace`,
  `little_to_native_inplace`, `native_to_little_inplace`,
  `conditional_reverse_inplace`; generic `endian_load<T,N,Order>(p)` /
  `endian_store<T,N,Order>(p, v)`; and ~56 convenience load/store functions
  `load_big_u32`, `store_little_s64`, … for 16/24/32/40/48/56/64 bits (Boost,
  *Endian Conversion Functions*, Synopsis).
- **Boost `enum class order { native, big, little }`** as the runtime/compile-time
  order tag (Boost, conversion synopsis).
- **Boost buffer/arithmetic typedefs**: `big_int32_t`, `uint32_buf_t`,
  `big_uint16_ut`, etc., with `_buf_t` = buffer, `_t` = arithmetic, `u` =
  unaligned variants (Boost, *Endian Buffer Types* / *Endian Arithmetic Types*).

## 4. Error representation

- **`std::byteswap` and `std::endian` cannot fail.** `byteswap` is
  `constexpr … noexcept`; the only failure is a *compile-time* constraint (`T`
  integral, no padding bits — ill-formed otherwise) (cppreference, *std::byteswap*).
- **`std::bit_cast` cannot fail at run time**; size/trivially-copyable violations
  remove it from overload resolution or make it ill-formed, and indeterminate
  padding bits yield unspecified/UB outcomes documented as such (cppreference,
  *bit_cast*).
- **Wrong byte order is a silent logic error**, exactly as in C: nothing in the
  type system or runtime detects it. Boost states the failure mode explicitly —
  using a non-native integer with normal language rules gives a "silent failure"
  because the invariant does not hold (Boost, *Endianness invariants*).
- **Boost.Endian is `noexcept` throughout** for the conversion functions; it
  reports nothing and throws nothing (Boost, conversion synopsis signatures all
  `noexcept`). Its philosophy is not to raise: the `endian_reverse` contract
  disallows types whose byte-reversal may be invalid (bool, float, unscoped
  enums) as a *compile-time* error instead (Boost, *Definitions*).
- **Floating point was a deliberate error-avoidance decision:** by-value
  `endian_reverse` does not support `float`/`double` because reversing bytes "does
  not necessarily produce another valid floating point number" (e.g. a
  signaling-NaN), though in-place reversal is allowed (Boost, *Overall FAQ*,
  "Is there floating point support?").

## 5. Ownership semantics

*Adapted for endian (see `_dev/README.md`): value-returning vs in-place, and the
ownership semantics of the integer vs buffer slice.*

- **`std::byteswap` / `std::bit_cast` / `std::endian::native` are pure value
  operations:** integer in → integer out, no buffers, no handles, nothing to own
  or free (cppreference, *std::byteswap*, *bit_cast*, *std::endian*).
- **Boost deliberately provides both forms.** Value-returning is "the standard C
  and C++ idiom for functions that compute a value from an argument", while
  modify-in-place "allow[s] cleaner code in many real-world endian use cases and
  [is] more efficient for user-defined types that have members such as string data
  that do not need to be reversed" (Boost, *FAQ: Why are both value returning and
  modify-in-place functions provided?*). Example: `big_to_native_inplace(x)` takes
  `EndianReversibleInplace& x` and mutates the caller's object.
- **Boost's buffer/arithmetic types own their byte array by value.** The
  endianness invariant lives in the *type*, not in the caller's discipline:
  "Endian buffer and arithmetic types hold values internally as arrays of
  characters with an invariant that the endianness of the array never changes"
  (Boost, *Endianness invariants*). Copying/moving such a value carries the order
  with it.
- **Generic load/store take a raw `unsigned char const*` / `unsigned char*`** and
  only read/write the buffer; buffer ownership, length (`N`) and lifetime remain
  the caller's (Boost, conversion synopsis:
  `endian_load<T, N, Order>(unsigned char const* p)`,
  `endian_store<T, N, Order>(unsigned char* p, T const& v)`).
- **UDT support is by ADL customization, not by owning:** a user type participates
  by providing a free `endian_reverse` in its namespace; arrays are handled by the
  `endian_reverse_inplace(T (&x)[N])` overload (Boost, *Requirements /
  Customization points*).

## 6. Blocking / non-blocking

- **Not applicable.** `std::endian` is a compile-time enum, `std::byteswap`/
  `std::bit_cast` are `constexpr noexcept` pure functions, and Boost's whole
  conversion/buffer/arithmetic surface is `inline`/`noexcept` value code
  (cppreference, *std::endian*, *std::byteswap*, *bit_cast*; Boost synopsis).
  There is no I/O, no blocking, no async model, no cancellation (Assessment:
  derived from the `constexpr`/`noexcept`/`inline` contracts and the absence of
  any stream in these headers).
- **Thread safety follows from purity:** no shared mutable state means the scalar
  layer is freely usable from any thread (Assessment: derived from the pure
  signatures). The only ordering caveat is around byte buffers of a
  user-shared object, which is the user's synchronization problem (Boost:
  `endian_load`/`endian_store` take caller-owned memory).

## 7. IPv4 / IPv6

*Adapted for endian (see `_dev/README.md`): which byte orders are represented and
whether a single abstraction covers all of them.*

- **Orders represented: `little`, `big`, `native`** — a single closed enum
  (cppreference, *std::endian*). There is no separate "network" value; network
  order is simply big-endian (C heritage: man7 `byteorder(3)`).
- **A single abstraction covers all of them — as an enum, not as conversion
  functions.** `std::endian::native` is the only query; it can be compared against
  `little`/`big` at compile time and, because it is an enum class, used as a
  `constexpr`/`if constexpr` condition and as a class-static "order" tag
  (cppreference, *std::endian*; P0463R1 gives the `sha256` example with
  `static constexpr std::endian endian = std::endian::big;`).
- **Mixed-endian is representable** by `native` being equal to neither `little`
  nor `big`, and by all three being equal when `sizeof(scalar) == 1`
  (cppreference, *std::endian*; P0463R1, "Objection #3" and wording).
- **Runtime orders are a second axis.** Boost's `enum class order { native, big,
  little }` and `conditional_reverse`/`conditional_reverse_inplace` let one
  abstraction express "reverse only if order1 != order2" at compile time for the
  templated form and at run time for the `(x, order1, order2)` form (Boost,
  *Byte Reversal Functions*, `conditional_reverse`).
- **Boost explicitly rejects other orders:** "Why are only big and little native
  endianness supported? … PDP-11 and the other middle endian approaches are
  interesting curiosities but have no relevance", while the `order::native`
  specification is crafted so such an order would compare unequal to both
  (Boost, *Overall FAQ*).

## 8. Timeouts

- **Not applicable.** There is no wait, deadline, deadline propagation or
  cancellation anywhere in `<bit>`'s endian/byteswap/bit_cast or in Boost.Endian's
  conversion API (Assessment: derived from the pure `constexpr`/`noexcept`
  signatures in cppreference and the Boost synopsis).
- The only timeouts in a program that uses byte-order conversion belong to the
  surrounding I/O (sockets/streams), which are not part of these headers
  (Assessment: derived from the absence of any stream type in `<bit>` and the
  conversion header).

## 9. TLS

*Adapted for endian (see `_dev/README.md`): how host native endianness is detected
and reported (compile-time constant, runtime query, or not at all).*

- **Compile-time constant: `std::endian::native` (C++20).** The value is fixed at
  compile time and `constexpr`-usable; the standard's own example branches with
  `if constexpr (std::endian::native == std::endian::big)` /
  `== std::endian::little` / else "mixed-endian" (cppreference, *std::endian*,
  Example).
- **Implementation is macro-based under the hood:** the possible implementation
  maps `native = __BYTE_ORDER__`, `little = __ORDER_LITTLE_ENDIAN__`,
  `big = __ORDER_BIG_ENDIAN__`, and on MSVC hard-codes
  `little = 0, big = 1, native = little` because MSVC lacks `__BYTE_ORDER__`
  (cppreference, *std::endian*; P0463R1, "Implementation"). This is exactly the
  GCC/MSVC macro split seen on the C side (Microsoft Learn, *Predefined macros*).
- **Design rationale: "The compiler knows the answer!"** P0463R1 argues for a
  compile-time constant and answers the runtime-switching objection with "No
  operating system tolerates switching endian at run time once an application has
  launched" (P0463R1, *Proposal*).
- **Why not just a macro:** the enum gives a namespaced, typed value usable as a
  vocabulary type (e.g. a class advertising the order of its byte output), which a
  macro cannot (P0463R1, "Why not just a macro?").
- **Runtime query does not exist** — there is no `std::is_little_endian()`; the
  property is compile-time only (cppreference, *std::endian*).
- **Boost offers `order::native`** in addition, and specifies it equal to
  `order::big` or `order::little` by execution environment, or unequal to both
  otherwise (Boost, conversion synopsis, "The value of `order::native`").

## 10. Interesting design decisions

- **A vocabulary enum instead of a macro.** `std::endian::{little,big,native}`
  lets the order be a type-level value that can be a `constexpr` class member and
  compared at compile time (P0463R1; cppreference, *std::endian*).
- **`byteswap` is named for what it does (reverse bytes), not for a direction.**
  The direction is expressed by the caller combining `byteswap` with a
  `native == …` check, which is exactly the minimal primitive
  (cppreference, *std::byteswap*).
- **Three-tier Boost design separates "when conversion happens".** *Conversion
  functions* = explicit, no hidden conversion; *buffer types* = explicit
  conversions, value held as bytes; *arithmetic types* = implicit conversions,
  drop-in arithmetic. The docs recommend arithmetic types by default and buffers
  for control (Boost, *Choosing between Conversion Functions, Buffer Types, and
  Arithmetic Types*).
- **The stated invariant is the core idea:** the endianness of a buffer/arithmetic
  value never changes, so a maintainer cannot accidentally use an unconverted
  field (Boost, *Endianness invariants*).
- **Compile-time vs runtime order via two overload sets of `conditional_reverse`:**
  `conditional_reverse<O1,O2>(x)` decides at compile time, while
  `conditional_reverse(x, order1, order2)` decides at run time (Boost,
  *Byte Reversal Functions*, "Remarks: Whether x or endian_reverse(x) … determined
  at compile time").
- **`bit_cast` replaces `memcpy`/`reinterpret_cast`** for bit reinterpretation
  with a `constexpr`, size- and triviality-checked contract
  (cppreference, *bit_cast*, Notes: reinterpret_cast "shall not be used …
  because of the type aliasing rule").
- **`bit_cast` is the implementation vehicle for `byteswap`**, showing how the two
  C++20/23 features compose (cppreference, *std::byteswap*, possible
  implementation).
- **Refusal to support by-value float reversal** prevents producing invalid
  floating-point values; in-place is still allowed (Boost, *Overall FAQ*).
- **Performance is claimed to be equal when the compiler optimizes:** "There will
  be no performance difference between the two approaches in optimized builds",
  while the buffer types exist for users who want explicit conversion control
  (Boost, *Performance*, *FAQ*).
- **Rejection of glibc's macro names:** they are non-standard, vary between
  POSIX-like systems, and were sometimes macros, which "do not respect scoping
  and namespace rules" (Boost, *FAQ: Why not use the Linux names*).

## 11. Decisions NOT to copy

- **Fixed 16/32/64-bit-only conversion templates.** Boost's conversion functions
  "only support 8, 16, 32, and 64-bit aligned integers" (Boost, *Limitations*);
  Mojo can parameterize over width instead of enumerating.
- **Three parallel user-facing concepts (conversion / buffer / arithmetic) in the
  same namespace.** It is powerful but heavy; a single order-tagged value plus a
  conversion function is simpler (Assessment: derived from Boost's own *Choosing*
  chapter weighing three approaches).
- **Implicit conversion in the arithmetic types.** Boost notes this removes the
  explicit control of when conversion happens and can cause repeated conversions
  (Boost, *Conversion explicitness*). Explicit conversion is the safer default.
- **Storing an endian value in a plain untagged integer.** The documented silent
  failure when an unconverted field is later used argues for a tagged type
  (Boost, *Endianness invariants*).
- **`bit_cast`'s unspecified padding bits** should not be a contract; prefer a
  fully defined conversion (cppreference, *bit_cast*).
- **Disallowing by-value float/`bool` reversal by silently removing overloads**
  is a compile-time ergonomics cost; better to be explicit about which types are
  reversible (Assessment: derived from Boost's *Definitions* and FAQ).
- **Runtime `conditional_reverse` with runtime `order` arguments** invites
  per-call branching in hot loops; Mojo should steer to the compile-time form
  (Boost, *Byte Reversal Functions*; *Performance*).
- **Relying on compiler byte-swap intrinsics with a fallback macro escape hatch**
  (`BOOST_ENDIAN_NO_INTRINSICS`) leaks build configuration into the public API
  (Boost, *Built-in support for Intrinsics*); Mojo's `std.bit.byte_swap` covers
  the intrinsic portably.

## 12. Ideas fitting Mojo

- **Mojo already has the C++ pieces; compose, don't rebuild.** `std.bit.byte_swap`
  reverses bytes of a SIMD vector of integers with an even byte count (mojov1
  buch, `mojov1/stdlib/bit`;
  <https://mojolang.org/docs/std/bit/bit/byte_swap/>), and `std.sys.info` exposes
  the compile-time `is_little_endian()` / `is_big_endian()` predicates
  (mojov1 buch, `mojov1/stdlib/sys`; <https://mojolang.org/docs/std/sys/info/>).
  `prim_endian` should layer the `Endian` abstraction on both.
- **A `comptime` `Endian` vocabulary value (little/big/native)** mirrors
  `std::endian` and enables `comptime if` specialization exactly as P0463R1
  intended (cppreference, *std::endian*; P0463R1).
- **`to_be`/`to_le`/`from_be`/`from_le` as generic-over-width value functions**,
  matching Boost's `native_to_big`/`big_to_native` names but without the three
  parallel concepts (Boost, conversion synopsis).
- **An order-tagged wrapper type** (like `big_int32_t` but as a distinct Mojo
  struct) carrying the Boost invariant, using Mojo's value semantics so a copy
  preserves the order (Boost, *Endianness invariants*; mojov1 buch
  `mojov1/memory/value-semantics`).
- **Both value and in-place forms** — the Boost FAQ's justification (value is the
  idiom, in-place is cleaner and avoids reversing untouched members) applies
  directly to Mojo's `var`/`mut` conventions (Boost, *FAQ*; mojov1 buch
  `mojov1/keyword-conventions/mut`).
- **Buffer `load`/`store` with explicit order, width and (in Mojo) a length-aware
  slice**, generalizing `endian_load<T,N,Order>`/`endian_store` into a
  bounds-checked `Span` API that can `raises` on undersized input (Boost,
  conversion synopsis; Mojo error model per mojov1 buch `mojov1/errors`).
- **Compile-time `conditional` conversion** via `comptime if` on the `Endian`
  value, so a matching target compiles the conversion away, mirroring Boost's
  `conditional_reverse<O1,O2>` (Boost, *Byte Reversal Functions*; mojov1 buch
  `mojov1/stdlib/sys`).
- **No `raises` for total fixed-width conversions**; `raises` only where a buffer
  read's length can be violated (Assessment: derived from the `noexcept`/total
  contracts of `byteswap`/`bit_cast` and Boost's conversion functions).
- **Expose the network/big equivalence as a documented fact, not a function name**
  (`Endian.big` = network order), keeping C++'s clean enum while retaining the C
  fact (cppreference, *std::endian*; man7 `byteorder(3)`).
- **`byteswap`-style total shift/byte primitives already exist** in `std.bit`, so
  `prim_endian` need not define a raw reversal; it defines the order semantics on
  top (mojov1 buch `mojov1/stdlib/bit`).

## Sources

- <https://en.cppreference.com/w/cpp/types/endian> — `std::endian`, semantics, `__cpp_lib_endian`, possible implementation, `if constexpr` example
- <https://en.cppreference.com/w/cpp/numeric/byteswap> — `std::byteswap` (C++23), padding-bit constraint, `__cpp_lib_byteswap`, implementation
- <https://en.cppreference.com/w/cpp/numeric/bit_cast> — `std::bit_cast` (C++20), size/triviality requirements, padding/indeterminate rules, aliasing note
- <https://en.cppreference.com/w/cpp/header/bit> — `<bit>` synopsis (endian, byteswap, bit_cast)
- <https://en.cppreference.com/w/c/numeric/bit/endian> — C23 `__STDC_ENDIAN_*` macros (exposed in C++)
- <https://en.cppreference.com/w/c/numeric/bit_manip> — C23 `<stdbit.h>` functions, no byteswap
- <https://www.open-std.org/jtc1/sc22/wg21/docs/papers/2017/p0463r1.html> — P0463R1 "endian, Just endian" (Hinnant): rationale, implementation, wording
- <https://www.boost.org/doc/libs/1_86_0/libs/endian/doc/html/endian.html> — Boost.Endian: three approaches, conversion synopsis, `order`, performance, FAQ, limitations, invariants, license/C++11
- <https://gcc.gnu.org/onlinedocs/gcc/Other-Builtins.html> — `__builtin_bit_cast` (and `__builtin_clear_padding`)
- <https://learn.microsoft.com/en-us/cpp/preprocessor/predefined-macros?view=msvc-170> — MSVC predefined macros (no `__BYTE_ORDER__`; `_M_IX86`/`_M_X64`), the reason `std::endian` hard-codes little/native on MSVC
- <https://man7.org/linux/man-pages/man3/byteorder.3.html> — network byte order = MSB first (cross-language fact)
- Mojo `byte_swap`: <https://mojolang.org/docs/std/bit/bit/byte_swap/>
- Mojo `sys.info` endian predicates: <https://mojolang.org/docs/std/sys/info/> (mojov1 buch, `mojov1/stdlib/bit`, `mojov1/stdlib/sys`)
