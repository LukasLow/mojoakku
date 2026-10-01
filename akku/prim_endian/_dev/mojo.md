# prim_endian research: Mojo

Mojo facts are not researched from the internet: they are read from the
`mojov1` buch, the self-sufficient Mojo 1.x reference. This file only links the
buch pages that matter for `prim_endian`; it does not duplicate them.

## What Mojo already provides (1.1.0, from the buch)

- **Byte swap primitive:** `std.bit.byte_swap` — "Byte-swaps an integer with an
  even number of bytes." Works on integers and SIMD vectors. Source:
  `mojov1/stdlib/bit` (→ <https://mojolang.org/docs/std/bit/bit/>).
- **Host endianness, compile time:** `std.sys.is_little_endian()`,
  `is_big_endian()` — compile-time predicates on the build target. Source:
  `mojov1/stdlib/sys` (→ <https://mojolang.org/docs/std/sys/info/>).
- **Numeric model:** every fixed-width numeric type is a one-lane `SIMD`
  (`Scalar[DType.*]`); `Int` is `Scalar[DType.int]`. `SIMD` supports
  construction, element access, elementwise ops, `cast[]`, `shuffle`/`slice`/
  `join`/`split` and bit operations (`& | ^ ~ << >>`). Source:
  `mojov1/concurrency/vectorization-and-simd`, `mojov1/stdlib/builtin`.
- **Other bit tools (context, not endian):** `std.bit` also has `bit_reverse`,
  `rotate_bits_left/right`, `pop_count`, `count_leading_zeros`,
  `count_trailing_zeros`. Source: `mojov1/stdlib/bit`.

## Consequence for the design

The stdlib gives the raw ingredients — a byte-swap and a host-endianness query —
but **no value-level API that names big/little/native order**, no buffer
(byte-array) conversion, and no typed error for a bad input length. Those are the
gaps this library is meant to fill; `prim_bit` deliberately left endianness out.

No Mojo API decision is made in Phase 1.

## Sources

- buch `mojov1/stdlib/bit` — <https://mojolang.org/docs/std/bit/bit/>
- buch `mojov1/stdlib/sys` — <https://mojolang.org/docs/std/sys/info/>
- buch `mojov1/stdlib/builtin` — <https://mojolang.org/docs/std/builtin/>
- buch `mojov1/concurrency/vectorization-and-simd` —
  <https://mojolang.org/docs/reference/numeric-types/>
