# prim_endian research: C

## 1. Standard library support

- **POSIX network-order family is the portable baseline:** `htonl`, `htons`,
  `ntohl`, `ntohs` declared in `<arpa/inet.h>`; `uint32_t htonl(uint32_t)`,
  `uint16_t htons(uint16_t)`, `uint32_t ntohl(uint32_t)`, `uint16_t ntohs(uint16_t)`.
  Converts "between host byte order and network byte order"; network order is
  Most-Significant-Byte-first (= big-endian). POSIX.1-2008; "No errors are
  defined" (POSIX `htonl` page; man7 `byteorder(3)`).
- **GNU/BSD host↔explicit-order family** in `<endian.h>`: `htobe16`, `htole16`,
  `be16toh`, `le16toh` and the 32- and 64-bit variants, `uint16_t htobe16(uint16_t host_16bits)`
  etc. `htobe*nn*` = host→big, `htole*nn*` = host→little, `be*nn*toh` = big→host,
  `le*nn*toh` = little→host (man7 `endian(3)`).
- **Byte-swap primitives** in `<byteswap.h>`: `bswap_16`, `bswap_32`, `bswap_64`
  return the argument with the order of its bytes reversed; "These functions
  always succeed"; standard: **GNU** (man7 `bswap(3)`).
- **Important glibc detail:** `<endian.h>` is built on `__BYTE_ORDER` at
  preprocessing time. On a little-endian target glibc defines
  `htobe32(x)` as `__bswap_32(x)` and `htole32(x)` as `__uint32_identity(x)`
  (and vice versa on a big-endian target); `be32toh`/`le32toh` mirror this
  (glibc `string/endian.h`). Consequence: a conversion that is a no-op for the
  target endianness compiles to nothing.
- **`__bswap_16/32/64`** themselves route to the compiler builtin when available:
  `__builtin_bswap16` (GCC ≥ 4.8), `__builtin_bswap32/64` (GCC ≥ 4.3), otherwise a
  constant mask/shift expression (glibc `bits/byteswap.h:36`, `:54`, `:81`).
- **Preprocessor endianness macros (GCC/Clang extension, not ISO C):**
  `__BYTE_ORDER__` equals one of `__ORDER_LITTLE_ENDIAN__`,
  `__ORDER_BIG_ENDIAN__`, `__ORDER_PDP_ENDIAN__`; `__FLOAT_WORD_ORDER__` reports
  the word order of multi-word floats (GCC, *Common Predefined Macros*).
- **C23 adds standardized endianness macros** in `<stdbit.h>`:
  `__STDC_ENDIAN_LITTLE__`, `__STDC_ENDIAN_BIG__`, `__STDC_ENDIAN_NATIVE__`;
  big and little are guaranteed unequal, native is one of them or neither for a
  mixed-endian platform; if all scalar types are size 1 all three are equal
  (cppreference, *`__STDC_ENDIAN_LITTLE__`, `__STDC_ENDIAN_BIG__`, `__STDC_ENDIAN_NATIVE__`*).
  There is **no `stdc_byteswap` function** in `<stdbit.h>`; the header's
  functions are bit-counting/rotate helpers (cppreference, *Bit manipulation (since C23)*).
- **Windows/MSVC:** no `<endian.h>` and no `__BYTE_ORDER__`; the network family
  lives in `winsock.h`/`Winsock2.h` (`htons`, header requirement `winsock.h
  (include Winsock2.h)`, library `Ws2_32.lib`) and byte-swap is
  `_byteswap_ushort/_byteswap_ulong/_byteswap_uint64` in `<stdlib.h>`
  (Microsoft Learn, `htons` function; `_byteswap_uint64, _byteswap_ulong,
  _byteswap_ushort`). The MSVC predefined-macro list contains `_M_IX86`,
  `_M_X64`, `_M_ARM`… but **no** `__BYTE_ORDER__` (Microsoft Learn, *Predefined macros*).
- There is **no portable ISO C way to reinterpret an object as bytes** other than
  `memcpy`/`char` aliasing; `union` type-punning is implementation-defined
  (Assessment: derived from the absence of such a function in the C23 bit API and
  the general C aliasing rules).

## 2. Relevant community libraries

- **Linux kernel byte-order headers** are the de-facto in-tree C solution:
  `include/linux/byteorder/generic.h` plus the per-arch
  `include/uapi/linux/byteorder/{little,big}_endian.h` define
  `cpu_to_le32`/`le32_to_cpu`/`cpu_to_be64`…, and `__le32`/`__be32` annotated
  integer types for sparse. `GUESS:` no kernel.org documentation URL for this
  page could be fetched in this run (kernel.org byteorder page returned 404), so
  the exact path is asserted from the kernel tree layout rather than a fetched
  source; the mechanism (typed `__le*`/`__be*` plus `cpu_to_*`) is nonetheless
  well established.
- **portable-snippets (`psnip_endian.h`)** by Jeff Walden / nemequ is a small
  public-domain header-only byte-order helper suite covering compilers without
  `__BYTE_ORDER__`. `GUESS:` the repository was not fetched in this run.
  (Assessment: derived from the fact that GCC's `__BYTE_ORDER__` and the C23
  macros are not available on older/MSVC compilers, so a polyfill is needed.)
- In practice, **C has almost no third-party endianness ecosystem** because the
  operating system or compiler supplies the conversion: glibc (`<endian.h>`,
  `<byteswap.h>`), the BSDs (`<sys/endian.h>`), and Windows (`winsock` +
  `<stdlib.h>`) already cover it (man7 `endian(3)`, *VERSIONS*; Microsoft Learn,
  `htons`).

## 3. Exposed APIs

- POSIX/network family (all value-returning, integer in → integer out):
  `uint32_t htonl(uint32_t hostlong)`, `uint16_t htons(uint16_t hostshort)`,
  `uint32_t ntohl(uint32_t netlong)`, `uint16_t ntohs(uint16_t netshort)`
  (POSIX `htonl`; man7 `byteorder(3)`).
- GNU explicit-order family (value-returning, macros or inline functions):
  `htobe16/htole16/be16toh/le16toh`, `htobe32/htole32/be32toh/le32toh`,
  `htobe64/htole64/be64toh/le64toh` (man7 `endian(3)`).
- GNU byte swap: `uint16_t bswap_16(uint16_t x)`, `uint32_t bswap_32(uint32_t x)`,
  `uint64_t bswap_64(uint64_t x)` (man7 `bswap(3)`).
- Feature-test gating: since glibc 2.19 the `htobe*`/`be*toh`/`le*toh` names need
  `_DEFAULT_SOURCE`; up to and including glibc 2.19 they needed `_BSD_SOURCE`
  (man7 `endian(3)`).
- Macros from `<endian.h>` under `__USE_MISC`: `LITTLE_ENDIAN`, `BIG_ENDIAN`,
  `PDP_ENDIAN`, `BYTE_ORDER` aliases of `__LITTLE_ENDIAN`, `__BIG_ENDIAN`,
  `__PDP_ENDIAN`, `__BYTE_ORDER` (glibc `string/endian.h:26-31`).
- GCC byte-swap builtins: `__builtin_bswap16/32/64` (glibc `bits/byteswap.h`;
  GCC, *Common Predefined Macros*).
- C23 macros: `__STDC_ENDIAN_LITTLE__`, `__STDC_ENDIAN_BIG__`,
  `__STDC_ENDIAN_NATIVE__`, in `<stdbit.h>` (cppreference).
- MSVC: `_byteswap_ushort/ulong/uint64` in `<stdlib.h>`; `htons` etc. in
  `winsock.h` (Microsoft Learn).

## 4. Error representation

- **No error channel at all.** POSIX: "No errors are defined" for
  `htonl`/`htons`/`ntohl`/`ntohs` (POSIX `htonl`). `bswap_16/32/64`:
  "These functions always succeed" (man7 `bswap(3)`). `htobe*`/`be*toh`/`le*toh`
  return a value and define no error (man7 `endian(3)`).
- **A wrong byte order is a silent data error, never reported.** Nothing in the
  API can detect that bytes were interpreted in the wrong order; correctness rests
  entirely on the caller (Assessment: derived from the pure value-mapping
  signatures and the absence of any status/errno in the man pages above).
- **Portability trap via macros:** code guarded by `#if __BYTE_ORDER__ ==
  __ORDER_LITTLE_ENDIAN__` compiles the wrong branch when the macro is undefined
  (GCC defines it; MSVC does not — Microsoft Learn, *Predefined macros*), and an
  undefined identifier in `#if` is treated as `0` by the preprocessor
  (Assessment: standard C preprocessor behaviour; consequence of the MS/GCC macro
  split documented in those two sources).

## 5. Ownership semantics

*Adapted for endian (see `_dev/README.md`): whether conversion is value-returning
or in-place, and the ownership semantics of the integer input/output value.*

- **All standard/POSIX/glibc conversion functions are value-returning:** they take
  an integer by value and return a new integer; there is no in-place variant in
  the C standard library or glibc `<endian.h>` (man7 `byteorder(3)`,
  `endian(3)`). There is no buffer or handle to own.
- glibc implements them as macros/`static inline` functions returning a value
  (`__bswap_32` / `__uint32_identity`), so the source-level contract is still
  integer-in → integer-out (glibc `string/endian.h:33-44`,
  `bits/byteswap.h:37-44`).
- **Buffer-level use is caller-owned and entirely manual:** to read a big-endian
  field you copy the bytes into a `uintN_t` (e.g. via `memcpy`) and then call
  `beNtoh`, or combine bytes by hand. The buffer, its lifetime and its length are
  the caller's; the API carries neither order nor length (Assessment: derived
  from the value signatures in the man pages and the POSIX family carrying no
  buffer/length parameter).
- The Linux kernel is the notable C exception with both value (`cpu_to_le32`) and
  in-place/pointer (`…p`) forms. `GUESS:` the exact in-place names are asserted
  from the kernel byteorder layout, not from a fetched kernel page (see §2).

## 6. Blocking / non-blocking

- **Not applicable: the whole layer is pure computation.** It performs no I/O,
  does not block, and has no async/concurrency model (man7 `byteorder(3)`,
  `endian(3)`, `bswap(3)`).
- All four POSIX functions are **MT-Safe** ("Thread safety … MT-Safe"), i.e.
  safe to call concurrently (man7 `byteorder(3)`, *ATTRIBUTES*).
- No cancellation, no suspension, no scheduler interaction exists in the API.

## 7. IPv4 / IPv6

*Adapted for endian (see `_dev/README.md`): which byte orders are represented
(big, little, native, network) and whether a single abstraction covers all of them.*

- **Orders represented:** host/native, network (= big-endian), explicit big-endian
  and explicit little-endian.
  - "Network byte order" is defined as the Internet's canonical order, i.e.
    most-significant-byte first = big-endian (glibc manual, *Byte Order Conversion*;
    man7 `byteorder(3)`: "the network byte order, as used on the Internet, is Most
    Significant Byte first"; Microsoft Learn, `htons`: "network byte order (which
    is big-endian)").
  - native is not a value in C before C23; it is the endianness the code was
    compiled for, exposed only as macros (`__BYTE_ORDER__`, GCC; or C23
    `__STDC_ENDIAN_NATIVE__`, cppreference).
- **No single abstraction covers all of them.** The three families overlap but
  differ in coverage:
  - `htonl/htons` only 16- and 32-bit, only big/network; there is **no**
    `htonll`/64-bit and no little-endian network variant (man7 `endian(3)`,
    *HISTORY*: "the byteorder(3) functions … lack the 64-bit and little-endian
    variants").
  - `htobe*`/`htole*`/`be*toh`/`le*toh` cover big and little for 16/32/64 bits
    (man7 `endian(3)`).
  - `bswap_*` is an order-agnostic raw reversal, not a conversion (man7 `bswap(3)`).
- **Mixed endianness is acknowledged, not unified:** `__ORDER_PDP_ENDIAN__` exists
  as a possible `__BYTE_ORDER__` value (GCC), and `__FLOAT_WORD_ORDER__` can differ
  from the integer order (GCC), so "native" is not necessarily one uniform order.

## 8. Timeouts

- **Not applicable.** Endianness conversion is a pure value mapping: it has no
  blocking operation, no wait, no deadline and no cancellation point
  (man7 `byteorder(3)`, `endian(3)`, `bswap(3)`).
- The only timeout-like concerns in a real program (socket reads, file reads)
  belong to the surrounding I/O layer, not to the conversion functions
  (Assessment: derived from the functions' pure integer signatures).

## 9. TLS

*Adapted for endian (see `_dev/README.md`): how host native endianness is detected
and reported (compile-time constant, runtime query, or not at all).*

- **Compile-time, via preprocessor macros, is the C answer.**
  - GCC/Clang: `#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__` (GCC, *Common
    Predefined Macros*).
  - glibc exposes `__BYTE_ORDER` (from `bits/endian.h`) and, under `__USE_MISC`,
    the unsuffixed `BYTE_ORDER` alias plus `LITTLE_ENDIAN`/`BIG_ENDIAN`/`PDP_ENDIAN`
    (glibc `string/endian.h:26-31`, `:8`).
  - C23: `__STDC_ENDIAN_NATIVE__`, compared against `__STDC_ENDIAN_LITTLE__` /
    `__STDC_ENDIAN_BIG__` in `<stdbit.h>` (cppreference).
- **There is no standardized runtime query.** ISO C before C23 offers no function
  to ask the running machine its endianness; the property is fixed at compile
  time (Assessment: derived from the C23 macros being macro constants and from
  the absence of any query function in the standard headers).
- **MSVC reports the target, not endianness:** it defines `_M_IX86`, `_M_X64`,
  `_M_ARM*` but no `__BYTE_ORDER__` (Microsoft Learn, *Predefined macros*); on
  Windows the platforms are little-endian (Assessment: derived from `htons` in
  Winsock being documented as converting to big-endian, i.e. a real swap — MS
  `htons` docs).
- **Size-1 scalar case:** when every scalar type has size 1, endianness is
  irrelevant and the C23 big/little/native macros are all equal (cppreference).
- A common runtime idiom is `if (*(char*)&one == 0) /* big */ else /* little */`
  or `one == htons(one)`. `GUESS:` no fetched source was found that standardizes
  these idioms; they are folklore workarounds for the missing runtime query.

## 10. Interesting design decisions

- **Network order is pinned as a protocol constant while host order is a
  compile-time property.** `htons` encodes "big-endian" *inside a function name*
  rather than as a parameter, so the constant leaks into the API (glibc manual;
  POSIX `htonl`).
- **The explicit family encodes direction in the name:** `htobe`/`htole` vs
  `be*toh`/`le*toh` make both source order and target order readable, unlike
  `hton`/`ntoh` which hide "network == big" (man7 `endian(3)`).
- **Macro-or-function flexibility** is an explicit POSIX allowance ("On some
  implementations, these functions are defined as macros", POSIX `htonl`); glibc
  actually does this (glibc `string/endian.h`). This is powerful and the source
  of C++'s later criticism (see §11).
- **Compile-time elimination:** because glibc selects bswap vs identity by
  `__BYTE_ORDER`, a conversion that is a no-op for the target compiles to nothing
  (glibc `string/endian.h:33-44`).
- **`bswap` as the single primitive**, with every order conversion expressible on
  top of it, keeps the code small (man7 `bswap(3)`; glibc `bits/byteswap.h`).
- **Feature-test macros gate availability** (`_DEFAULT_SOURCE`/`_BSD_SOURCE`),
  treating endian conversion as an extension namespace (man7 `endian(3)`).
- **Non-uniform endianness is admitted** through `__ORDER_PDP_ENDIAN__` and
  `__FLOAT_WORD_ORDER__` instead of assuming one machine order (GCC).

## 11. Decisions NOT to copy

- **Macro names that cannot be namespaced.** Boost's endian FAQ rejects the Linux
  names precisely because they "vary even between POSIX-like operating systems"
  and are "sometimes implemented as macros … macros do not respect scoping and
  namespace rules" (Boost Endian, *Why not use the Linux names*). Mojo should have
  one namespaced API, not C's four incompatible sets (Boost, *Overall FAQ*:
  "at least four incompatible sets of functions in common use").
- **Three overlapping families with different width coverage.** `hton*` (16/32,
  big only) vs `htobe*/le*` (16/32/64, big+little) vs `bswap_*` (raw reversal)
  forces callers to know which one covers the width they need (man7 `endian(3)`).
  A single generic API over all integer widths is strictly better.
- **Carrying byte order in a plain untagged integer.** Boost calls out the broken
  invariant: the usual language rules apply only while the value happens to be in
  native order, which silently breaks when an unconverted field is used later
  (Boost, *Endianness invariants*). Mojo should tag order in the type or convert
  eagerly.
- **Unportable to Windows.** `<endian.h>`/`htobe*`/`__BYTE_ORDER__` do not exist
  on MSVC, which needs a different header and different names (Microsoft Learn).
  A portable library must not inherit that split.
- **`union` type-punning to inspect bytes.** It is implementation-defined for
  reading the non-active member and has no place in a new API (Assessment:
  derived from the value-only signatures plus the absence of a portable C
  reinterpret function in §1).
- **No 64-bit and no little-endian network conversion.** The POSIX family's
  missing widths/variants are a documented shortcoming (man7 `endian(3)`,
  *HISTORY*), not a model.
- **Silence on wrong order.** Since nothing can detect it, the design lesson is
  to make the order explicit in the API rather than to add an error code
  (Assessment: derived from §4).

## 12. Ideas fitting Mojo

- **Mojo already ships the low-level primitives; wrap, don't rebuild them.**
  `std.bit.byte_swap` byte-swaps an integer (scalar or SIMD) with an even number
  of bytes (mojov1 buch, `mojov1/stdlib/bit`;
  <https://mojolang.org/docs/std/bit/bit/byte_swap/>), and
  `std.sys.info` exposes compile-time `is_little_endian()` / `is_big_endian()`
  (mojov1 buch, `mojov1/stdlib/sys`;
  <https://mojolang.org/docs/std/sys/info/>). The library's job is the ordering
  abstraction on top, not the swap.
- **A `comptime` `Endian` value (little/big/native)** mirrors the C23
  `__STDC_ENDIAN_NATIVE__` / GCC `__BYTE_ORDER__` model and pairs with Mojo's
  compile-time predicates (cppreference; GCC; mojov1 buch `mojov1/stdlib/sys`).
- **Value-returning `to_be`/`to_le`/`from_be`/`from_le` for every integer width**
  generalizes `htobe*`/`be*toh` and fixes their 16/32-only gap (man7 `endian(3)`).
- **Compile-time no-op when the target already matches the requested order**:
  `comptime if is_little_endian(): ...` (mojov1 buch `mojov1/stdlib/sys`),
  reproducing glibc's bswap-vs-identity selection (glibc `string/endian.h`).
- **Name the network order as an explicit `Endian.big`**, keeping C's useful
  "network byte order = big-endian" fact without smuggling it into a function
  name (glibc manual; POSIX).
- **Buffer load/store with explicit order and width** (read/write N bytes as a
  big- or little-endian integer) fills the gap C leaves entirely to `memcpy` and
  manual combining (Assessment: derived from §5).
- **Both a value form and an in-place-on-buffer form**, following the kernel's
  value/pointer split while keeping the value form primary (Linux kernel
  byteorder headers; `GUESS` on exact in-place names, see §2).
- **An order-carrying integer wrapper type** (e.g. `BigEndian[Int32]`) to avoid
  Boost's documented "lost invariant" bug of storing a non-native value in a
  plain integer (Boost, *Endianness invariants*).
- **No error channel for fixed-width conversions** (they are total), and
  `raises` only where a buffer read can actually fail (Assessment: derived from
  §4 and §8).

## Sources

- <https://man7.org/linux/man-pages/man3/byteorder.3.html> — `htonl`/`htons`/`ntohl`/`ntohs`, POSIX.1-2008, MT-Safe, network = MSB first
- <https://man7.org/linux/man-pages/man3/endian.3.html> — `htobe*`/`htole*`/`be*toh`/`le*toh`, standards: None, glibc 2.9, `_DEFAULT_SOURCE`/`_BSD_SOURCE`, 64-bit/little missing from byteorder(3)
- <https://man7.org/linux/man-pages/man3/bswap.3.html> — `bswap_16/32/64`, "always succeed", standard: GNU
- <https://pubs.opengroup.org/onlinepubs/9699919799/functions/htonl.html> — POSIX `htonl` page, "No errors are defined", may be macros
- <https://sourceware.org/glibc/manual/latest/html_node/Byte-Order.html> — glibc manual, network byte order; `htons`/`htonl` usage
- <https://raw.githubusercontent.com/bminor/glibc/master/string/endian.h> — glibc `<endian.h>`: `__BYTE_ORDER` selection, `LITTLE_ENDIAN`/`BYTE_ORDER` aliases, bswap-vs-identity macros
- <https://raw.githubusercontent.com/bminor/glibc/master/bits/byteswap.h> — `__bswap_16/32/64`, builtin thresholds `__GNUC_PREREQ(4,8)` / `(4,3)`
- <https://raw.githubusercontent.com/bminor/glibc/master/bits/endian.h> — machine `__BYTE_ORDER` stub ("Machine byte order unknown.")
- <https://gcc.gnu.org/onlinedocs/cpp/Common-Predefined-Macros.html> — `__BYTE_ORDER__`, `__ORDER_LITTLE/BIG/PDP_ENDIAN__`, `__FLOAT_WORD_ORDER__`
- <https://en.cppreference.com/w/c/numeric/bit/endian> — C23 `__STDC_ENDIAN_LITTLE__/BIG/NATIVE__`, mixed-endian and size-1 rules
- <https://en.cppreference.com/w/c/numeric/bit_manip> — C23 `<stdbit.h>` function list (no byteswap)
- <https://learn.microsoft.com/en-us/windows/win32/api/winsock/nf-winsock-htons> — MS `htons`, network = big-endian, header `winsock.h`, `Ws2_32.lib`
- <https://learn.microsoft.com/en-us/cpp/c-runtime-library/reference/byteswap-uint64-byteswap-ulong-byteswap-ushort?view=msvc-170> — MS `_byteswap_ushort/ulong/uint64` in `<stdlib.h>`
- <https://learn.microsoft.com/en-us/cpp/preprocessor/predefined-macros?view=msvc-170> — MSVC predefined macros; no `__BYTE_ORDER__`, has `_M_IX86`/`_M_X64`/`_M_ARM*`
- <https://www.boost.org/doc/libs/1_86_0/libs/endian/doc/html/endian.html> — Boost Endian: "four incompatible sets", rejects Linux macro names, endianness-invariant bug (used as cross-language evidence)
- Mojo `byte_swap`: <https://mojolang.org/docs/std/bit/bit/byte_swap/>
- Mojo `sys.info` endian predicates: <https://mojolang.org/docs/std/sys/info/> (mojov1 buch, `mojov1/stdlib/bit`, `mojov1/stdlib/sys`)
