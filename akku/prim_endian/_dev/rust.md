# prim_endian research: Rust

> Scope note: this file is the Rust half of the `systems-modern` group for the
> frozen Phase-1 run of `prim_endian` (see `README.md`). Q7 and Q9 are the
> endian-adapted variants (byte orders represented; host-native-endianness
> detection); the socket wording of Q5/Q7/Q9 does not apply. Zig `@byteSwap` is
> noted as a cross-reference at the end, per the run config.

## 1. Standard library support

Rust's byte-order support is built into the **primitive integer types** in
`core` (`std` re-exports it); there is no endianness module of its own
(source: https://doc.rust-lang.org/core/num/index.html and
https://doc.rust-lang.org/std/primitive.u16.html).

- Per-integer **byte conversion**: `to_be`, `to_le`, `from_be`, `from_le`
  (converts between the target's endianness and a named endianness).
- Per-integer **byte-array conversion**: `to_be_bytes`, `to_le_bytes`,
  `to_ne_bytes`, `from_be_bytes`, `from_le_bytes`, `from_ne_bytes`
  (fixed-size `[u8; N]` arrays).
- **Byte reversal**: `swap_bytes`.
- These exist for every integer width (`i8`..`i128`, `u8`..`u128`, `isize`,
  `usize`); the examples below cite `u16`, the docs are structurally identical
  across widths (source: https://doc.rust-lang.org/std/primitive.u16.html).
- Const-ness: all eleven cited methods are `pub const fn`, so conversions work
  in `const`/`static` contexts (source:
  https://doc.rust-lang.org/std/primitive.u16.html; verified per-method
  annotations `const: 1.32.0` and `const: 1.44.0` below).
- Endianness of the build target is also a compile-time cfg: `target_endian` is
  "set once with either a value of 'little' or 'big' depending on the endianness
  of the target's CPU" (source:
  https://doc.rust-lang.org/reference/conditional-compilation.html).
- The built-in `cfg!` macro evaluates a configuration predicate to `true`/`false`
  at compile time, e.g. `cfg!(target_endian = "big")`
  (source: https://doc.rust-lang.org/reference/conditional-compilation.html).

## 2. Relevant community libraries

- **`byteorder`** — crate by BurntSushi, version 1.5.0 (17 Aug 2026), dual
  licensed `Unlicense OR MIT`, repository
  https://github.com/BurntSushi/byteorder
  (source: https://docs.rs/byteorder/latest/byteorder/).
- It "provides convenience methods for encoding and decoding numbers in either
  big-endian or little-endian order" via `ByteOrder`, `BigEndian`,
  `LittleEndian`, plus `ReadBytesExt`/`WriteBytesExt` for `Read`/`Write`,
  and the aliases `BE`/`LE`/`NetworkEndian`/`NativeEndian`
  (source: https://docs.rs/byteorder/latest/byteorder/).
- Its own docs note it is now largely superseded for integers: "as of Rust 1.32,
  the standard numeric types provide built-in methods like `to_le_bytes` and
  `from_le_bytes`, which support some of the same use cases"
  (source: https://docs.rs/byteorder/latest/byteorder/).
- The crate deliberately **excludes platform-sized integers**: it covers "each
  type of number in Rust (sans numbers that have a platform dependent size like
  `usize` and `isize`)" (source: https://docs.rs/byteorder/latest/byteorder/).
- Note the naming overlap with Go: Go has a `byteorder`-like stdlib package
  (`encoding/binary`), Rust has a third-party `byteorder` crate; the names are
  not related (see `go.md`).

## 3. Exposed APIs

All signatures are from https://doc.rust-lang.org/std/primitive.u16.html; the
same associated functions exist on every integer primitive.

Associated functions (take the array, return the integer):

| API | Signature | Since |
| --- | --- | --- |
| `from_be` | `pub const fn from_be(x: u16) -> u16` | 1.0.0 (const 1.32.0) |
| `from_le` | `pub const fn from_le(x: u16) -> u16` | 1.0.0 (const 1.32.0) |
| `from_be_bytes` | `pub const fn from_be_bytes(bytes: [u8; 2]) -> u16` | 1.32.0 (const 1.44.0) |
| `from_le_bytes` | `pub const fn from_le_bytes(bytes: [u8; 2]) -> u16` | 1.32.0 (const 1.44.0) |
| `from_ne_bytes` | `pub const fn from_ne_bytes(bytes: [u8; 2]) -> u16` | 1.32.0 (const 1.44.0) |

Methods (take `self`, return the integer or array):

| API | Signature | Since |
| --- | --- | --- |
| `swap_bytes` | `pub const fn swap_bytes(self) -> u16` | 1.0.0 (const 1.32.0) |
| `to_be` | `pub const fn to_be(self) -> u16` | 1.0.0 (const 1.32.0) |
| `to_le` | `pub const fn to_le(self) -> u16` | 1.0.0 (const 1.32.0) |
| `to_be_bytes` | `pub const fn to_be_bytes(self) -> [u8; 2]` | 1.32.0 (const 1.44.0) |
| `to_le_bytes` | `pub const fn to_le_bytes(self) -> [u8; 2]` | 1.32.0 (const 1.44.0) |
| `to_ne_bytes` | `pub const fn to_ne_bytes(self) -> [u8; 2]` | 1.32.0 (const 1.44.0) |

Doc semantics (verbatim, source:
https://doc.rust-lang.org/std/primitive.u16.html):

- `swap_bytes`: "Reverses the byte order of the integer."
- `to_be`: "Converts `self` to big endian from the target's endianness." /
  "On big endian this is a no-op. On little endian the bytes are swapped."
- `to_le`: "Converts `self` to little endian from the target's endianness." /
  "On little endian this is a no-op. On big endian the bytes are swapped."
- `from_be`: "Converts an integer from big endian to the target's endianness." /
  "On big endian this is a no-op. On little endian the bytes are swapped."
- `from_le`: "Converts an integer from little endian to the target's
  endianness." / "On little endian this is a no-op. On big endian the bytes are
  swapped."
- `to_be_bytes`: "Returns the memory representation of this integer as a byte
  array in big-endian (network) byte order."
- `to_le_bytes`: "... in little-endian byte order."
- `to_ne_bytes`: "... in native byte order." / "As the target platform's native
  endianness is used, portable code should use `to_be_bytes` or `to_le_bytes`,
  as appropriate, instead."
- `from_be_bytes`: "Creates a native endian integer value from its
  representation as a byte array in big endian."
- `from_le_bytes`: "... in little endian."
- `from_ne_bytes`: "... in native endianness." / "... portable code likely wants
  to use `from_be_bytes` or `from_le_bytes`, as appropriate instead."

## 4. Error representation

- The integer byte-order methods are **total and infallible**: fixed-size
  `[u8; N]` arrays make length errors unrepresentable, and no method returns
  `Result`/`Option` (source:
  https://doc.rust-lang.org/std/primitive.u16.html).
- Infallibility is a direct consequence of the fixed array type: the compiler
  guarantees exactly 2/4/8 bytes, so there is nothing to validate
  `(Assessment: derived from the `[u8; 2]` signatures in the docs above)`.
- `byteorder`'s `ReadBytesExt`/`WriteBytesExt` are the fallible layer: they
  extend `Read`/`Write` and therefore return `std::io::Result<T>`, surfacing
  I/O errors such as `UnexpectedEof` (source:
  https://docs.rs/byteorder/latest/byteorder/trait.ReadBytesExt.html; the
  crate doc example uses `.unwrap()` on such results,
  https://docs.rs/byteorder/latest/byteorder/).
- Slice-based parsing in idiomatic Rust uses `TryInto<[u8; N]>` /
  `slice::try_into`, which yields `Result`, when the input length is not
  statically known. `(Assessment: derived from the fixed-array API shape; the
  exact conversion trait is standard Rust, not part of the endianness API.)`

## 5. Ownership semantics

Adapted Q5: value-returning vs in-place, and the ownership semantics of the
integer vs buffer.

- Every std method here is **value-returning and by-value**: integers are `Copy`,
  so `to_be`/`swap_bytes` take `self` by value and return a new integer; nothing
  is mutated in place and nothing is borrowed (source:
  https://doc.rust-lang.org/std/primitive.u16.html). Rust's `Copy` for integers
  is a core language property (source: https://doc.rust-lang.org/std/primitive.u16.html
  trait list shows `Copy`).
- The byte-array forms return an **owned** `[u8; N]` by value; `from_*_bytes`
  take the array **by value**. No buffer borrowing appears anywhere in the std
  API (source: same page).
- Therefore the caller always owns both input and output; there is no handle,
  no allocation and no destructor. `(Assessment: derived from the by-value
  signatures and integer `Copy` semantics.)`
- In-place buffer mutation is pushed to `byteorder`'s extension traits, which
  borrow `&mut self` on a `Read`/`Write` and thus follow normal Rust borrow
  rules (source: https://docs.rs/byteorder/latest/byteorder/).

## 6. Blocking / non-blocking

- The std conversions (`to_be`, `to_le`, `from_be`, `from_le`, `to_*_bytes`,
  `from_*_bytes`, `swap_bytes`) are **pure synchronous CPU operations**; no
  I/O, no async, no runtime (source:
  https://doc.rust-lang.org/std/primitive.u16.html).
- They are `const fn`, so they run at compile time as well as at runtime
  (source: same page, `const:` annotations).
- Blocking enters only through `byteorder`'s `ReadBytesExt`/`WriteBytesExt`,
  which are synchronous `std::io` traits; async I/O would require the `tokio`
  ecosystem's own byte-order helpers, which are out of scope here
  (source: https://docs.rs/byteorder/latest/byteorder/). `(Assessment: derived
  from the trait bounds being `std::io::Read`/`Write`.)`

## 7. IPv4 / IPv6

Adapted Q7: which byte orders are represented, and does a single abstraction
cover all of them.

- Three orders are represented: **big**, **little**, **native**
  (`to_be`/`from_be`/`*_be_bytes`, `to_le`/`from_le`/`*_le_bytes`,
  `to_ne`/`from_ne`/`*_ne_bytes`) plus the raw **swap** operation
  (source: https://doc.rust-lang.org/std/primitive.u16.html).
- Network byte order is big-endian and is explicitly named as such:
  `to_be_bytes` "Returns ... in big-endian (network) byte order."
  (source: https://doc.rust-lang.org/std/primitive.u16.html).
- There is **no single trait/enum abstraction** in std: the three orders are
  separate named methods on each integer, not a `ByteOrder` trait. The third
  community crate `byteorder` *does* offer the trait+`BigEndian`/`LittleEndian`
  abstraction, and `NetworkEndian` is an alias for `BigEndian`
  (source: https://doc.rust-lang.org/std/primitive.u16.html and
  https://docs.rs/byteorder/latest/byteorder/).
- So: one integer type covers all orders via distinct methods; a single
  *abstraction* over the choice of order exists only in the community crate.
  `(Assessment: derived from the std method list vs the byteorder trait.)`

## 8. Timeouts

- Not applicable: the std conversions are pure, total, non-blocking operations
  with no deadline, cancellation token or context parameter
  (source: signatures, https://doc.rust-lang.org/std/primitive.u16.html).
- Timeouts can only arise through the I/O extension traits, where they belong to
  the underlying `Read`/`Write` (e.g. a `TcpStream` read timeout), not to the
  byte-order layer (source: https://docs.rs/byteorder/latest/byteorder/).
  `(Assessment: derived from the absence of any timeout/context parameter in
  both APIs.)`

## 9. TLS

Adapted Q9: how host native endianness is detected and reported.

- **Compile-time constant**: `target_endian` is a cfg key that is "set once with
  either a value of 'little' or 'big' depending on the endianness of the
  target's CPU" (source:
  https://doc.rust-lang.org/reference/conditional-compilation.html).
- It is queryable in code as a compile-time predicate via the `cfg!` macro
  (returns a `bool` literal) or by conditional compilation with
  `#[cfg(target_endian = "big")]`
  (source: https://doc.rust-lang.org/reference/conditional-compilation.html).
- There is **no `std::endian` runtime query** in stable Rust at the time of the
  page consulted (page version 1.99.0 / `b940084d7 2026-09-28`); `to_ne` and
  `to_ne_bytes` *encapsulate* native order without exposing an
  `is_big_endian()` value (source:
  https://doc.rust-lang.org/std/primitive.u16.html). `(Assessment: derived from
  the absence of any endianness constant on the primitive/integer pages; the
  `core::num` module index lists only the numeric types/traits, no endian
  query, https://doc.rust-lang.org/core/num/index.html.)`
- The community `byteorder` crate exposes `NativeEndian` as a *type alias* for
  the local platform's order, still resolved at compile time, not a runtime
  function (source: https://docs.rs/byteorder/latest/byteorder/).

## 10. Interesting design decisions

1. **Methods on the integer, not a separate module.** Byte order is an
   intrinsic property of every integer type, so the API is
   `x.to_be_bytes()` rather than `endian::to_be(x)`
   (source: https://doc.rust-lang.org/std/primitive.u16.html).
2. **Two layers: value-level and array-level.** `to_be`/`from_be` are no-ops or
   swaps in *native* representation; `to_be_bytes`/`from_be_bytes` always
   materialise a defined byte sequence. This cleanly separates
   "reinterpret for this machine" from "produce wire bytes"
   (source: https://doc.rust-lang.org/std/primitive.u16.html).
3. **Everything is `const fn`.** Byte conversions compose in `const` contexts
   and are zero-cost after inlining
   (source: https://doc.rust-lang.org/std/primitive.u16.html).
4. **Native is explicit but discouraged for portable data.** `to_ne_bytes` /
   `from_ne_bytes` exist, yet the docs steer portable code to `be`/`le`
   (source: https://doc.rust-lang.org/std/primitive.u16.html).
5. **Infallible by type.** `[u8; N]` makes length errors impossible; fallibility
   is moved to the I/O extension traits in `byteorder`
   (source: https://doc.rust-lang.org/std/primitive.u16.html and
   https://docs.rs/byteorder/latest/byteorder/).
6. **`swap_bytes` as the primitive.** Both `to_be` and `to_le` are documented as
   "no-op or swap", making `swap_bytes` the conceptual base operation
   (source: https://doc.rust-lang.org/std/primitive.u16.html).
7. **Compile-time target endianness via cfg**, never a runtime branch
   (source: https://doc.rust-lang.org/reference/conditional-compilation.html).

## 11. Decisions NOT to copy

- **Per-type method explosion**: eleven methods replicated across ten integer
  types. In Mojo a compile-time parameter over width/order avoids the matrix.
- **Splitting `to_*`/`from_*` into two directions** is explicit but repetitive;
  a single `from`/`to` with a compile-time order parameter is tighter
  (source: https://doc.rust-lang.org/std/primitive.u16.html).
- **Native order as a first-class method** (`to_ne*`) invites accidental
  non-portable serialisation; the docs themselves warn against it. A library may
  expose it, but should not lead with it.
  `(Assessment: derived from the `to_ne_bytes` doc warning.)`
- **Third-party trait + extension-trait layering** (`byteorder`) is a
  workaround for pre-1.32 Rust; a fresh API should not need a `ByteOrder` trait
  just to select an order.
- **Cfg-macro target detection** is Rust-toolchain-specific and should not be
  imitated as a Mojo mechanism.

## 12. Ideas fitting Mojo

> Mojo-specific capabilities below are candidate ideas to be validated against
> the `mojov1` buch in later phases; this phase makes no Mojo API decision.

- **`const fn`-style compile-time evaluation** maps directly onto Mojo
  compile-time parameters and `comptime`-like specialization: a single generic
  endian conversion parameterised by order and width, evaluated at compile time.
- **Fixed-size array returns** (`[u8; N]`) map onto Mojo fixed-size collections /
  SIMD-like values, giving an infallible `to_*_bytes` without buffer management.
- **Two-layer split** (`to_be` value-level vs `to_be_bytes` array-level) is a
  clean model for Mojo: value conversions are `borrowed`/by-value and total;
  buffer forms are a separate, length-checked, `raises` layer.
- **`swap_bytes` as the primitive** gives a small, testable core that
  big/little conversions and native handling build on.
- **Explicit native conversion** should be offered but documented as the
  non-portable path.

## Cross-reference: Zig `@byteSwap` (not selected this run)

Recorded because the run config says Zig's `@byteSwap` is noted from this group
file.

- Zig's byte swap is a **builtin**, not a library function:
  `@byteSwap(operand: anytype) T`, where `@TypeOf(operand)` "must be an integer
  type or an integer vector type with bit count evenly divisible by 8"
  (source: https://ziglang.org/documentation/master/#byteSwap).
- Semantics: "Swaps the byte order of the integer. This converts a big endian
  integer to a little endian integer, and converts a little endian integer to a
  big endian integer" (source: https://ziglang.org/documentation/master/#byteSwap).
- A subtle size caveat worth noting for fixed-width design: "`@sizeOf(u24) == 4`
  ... those 4 bytes are what are swapped ... On the other hand, if `T` is
  specified to be `u24`, then only 3 bytes are reversed"
  (source: https://ziglang.org/documentation/master/#byteSwap).
- A distinct builtin `@bitReverse(integer: anytype) T` reverses the bit pattern
  (source: https://ziglang.org/documentation/master/#bitReverse).
- Zig exposes target endianness at compile time via the `builtin` package, e.g.
  `@import("builtin").target.cpu.arch.endian()` (source:
  https://ziglang.org/documentation/master/#ptrCast, which uses this exact call).

## Sources

- Rust `u16` primitive documentation (methods, versions, const-ness) —
  https://doc.rust-lang.org/std/primitive.u16.html
- Rust `core::num` module index —
  https://doc.rust-lang.org/core/num/index.html
- The Rust Reference, Conditional compilation (`target_endian`, `cfg!`) —
  https://doc.rust-lang.org/reference/conditional-compilation.html
- `byteorder` crate 1.5.0 documentation (BurntSushi, Unlicense OR MIT) —
  https://docs.rs/byteorder/latest/byteorder/ (repo
  https://github.com/BurntSushi/byteorder)
- `byteorder::ReadBytesExt` —
  https://docs.rs/byteorder/latest/byteorder/trait.ReadBytesExt.html
- Zig Language Reference, `@byteSwap` / `@bitReverse` / `builtin` target
  endianness — https://ziglang.org/documentation/master/#byteSwap
