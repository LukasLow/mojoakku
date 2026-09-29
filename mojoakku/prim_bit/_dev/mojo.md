# bit research: Mojo

Mojo is covered by the `mojov1` buch, not by a `researcher` (see
`.agents/workflows/NewLibPhase1Research.md`, Step 2). This note records what the
buch answers and, explicitly, which parts of the adapted question set it does
**not** answer — the latter are the design gap this library exists to close.

## Source of truth

- `mojov1/stdlib/bit` — the `std.bit` package page.
- `mojov1/stdlib/overview` — the 37-package list and the stability rule.
- `mojov1/basics/operators` (section "Bitwise operators").
- `mojov1/concurrency/vectorization-and-simd` — the `SIMD` numeric model.

## What the buch answers

- **Q1 (standard library support).** `std.bit` ships the scalar primitives:
  `bit_not`, `bit_reverse`, `bit_width`, `byte_swap`, `count_leading_zeros`,
  `count_trailing_zeros`, `log2_ceil`, `log2_floor`, `next_power_of_two`,
  `prev_power_of_two`, `pop_count`, `rotate_bits_left`, `rotate_bits_right`, plus
  `mask.is_negative` and `mask.splat`. Every function accepts and returns `SIMD`
  vectors; the scalar case is a one-lane `SIMD`. These APIs are **unstable by
  default** (no `@stable(since=...)` marker). Source: `mojov1/stdlib/bit`,
  `mojov1/stdlib/overview`, <https://mojolang.org/docs/std/bit/>.
- **Q9, scalar layer only.** The raw operators (`&`, `|`, `^`, `~`, `<<`, `>>`)
  are core language, not library. Source: `mojov1/basics/operators`.

## What the buch does NOT answer — the gap premise

For the adapted question set of this run, the `std.bit` page answers the
*scalar* part of Q9 and part of Q1, and nothing else. The following are **not
provided by Mojo's standard library** and are this library's reason to exist.
This must be read as the phase's explicit gap premise, not as a full Q1-Q12
answer about Mojo:

- **Q9, container layer.** There is no bitset / flag-set container type in
  `std.bit` (no set/clear/toggle/test, no union/intersection/difference/
  complement, no iteration over set bits, no cardinality). `std.bit`'s Types
  section is empty of such a container.
- **Q3 / Q9, bitfield layer.** There is no `get_bits` / `set_bits` over an
  arbitrary `[hi:lo]` range of an integer value.
- **Q9, bit-level I/O layer.** There is no LSB-first / MSB-first bit reader or
  writer over bytes. `mojoakku/io_core` is the byte layer; bits are above it.
- **Q7 (width and ordering model) for the container.** The buch documents the
  fixed-width integer and `SIMD` numeric model, but not a container's word size,
  bit order or growth policy — those are design decisions for Phase 3.

## Questions the buch leaves open for Mojo (design inputs, not facts)

- **Q2 (community libraries).** No Mojo-package bitset or bit-stream library is
  documented in the buch. Marked open; the Mojo Akku design is first-party.
- **Q4 (error representation) for a container.** Whether an out-of-range index
  raises a typed error or returns a sentinel is undecided; Mojo has both `raises`
  and `Optional`. Recorded in `mojov1/errors/error-model`.
- **Q5 (ownership) for a growable container.** Mojo value semantics and ASAP
  destruction apply (`mojov1/memory/value-semantics`); the concrete container
  lifecycle is a Phase-3 decision.
- **Q6, Q8, Q10, Q11, Q12.** Not answered by a stdlib page; Phase 3 decides them
  against the reference-language evidence in the sibling files.

## Sources

- `mojov1/stdlib/bit` (buch page)
- `mojov1/stdlib/overview` (buch page)
- `mojov1/basics/operators` (buch page, "Bitwise operators")
- Mojo `bit` package: <https://mojolang.org/docs/std/bit/>
