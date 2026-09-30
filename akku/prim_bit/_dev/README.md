# prim_bit research — frozen run configuration

Phase: `NewLibPhase1Research` for the MojoAkku library `prim_bit`.

## What the library is

`akku/prim_bit` is **bit twiddling and bitsets**: a small, predictable toolkit for
working at the bit level. It is a leaf library (no sibling dependencies) and a
general-purpose base block, useful far outside networking — flags, permission
sets, feature switches, bitfield parsing, packed data, and the primitive layer
that later libraries (`hash`, `digest`, `encoding`, `compression`) build on.

## Positioning fact (found during phase setup)

The Mojo standard library **already ships a `std.bit` package** with the scalar
primitives — `pop_count`, `count_leading_zeros`, `count_trailing_zeros`,
`bit_reverse`, `byte_swap`, `rotate_bits_left`, `rotate_bits_right`,
`next_power_of_two`, `prev_power_of_two`, `log2_floor`, `log2_ceil`, `bit_not`,
`bit_width`, plus `mask.is_negative` and `mask.splat`. Source:
`mojov1/stdlib/bit` and <https://mojolang.org/docs/std/bit/>. These functions are
**unstable by default** (no `@stable(since=...)` marker).

Consequence: the *scalar* functions are a **stdlib-first case** (wrap or extend),
not a reason to rebuild them. The library's real reason to exist is what
`std.bit` does **not** provide, and the research must establish that gap against
the reference languages:

1. a **bitset / flag-set container** — set, clear, toggle, test, union,
   intersection, difference, complement, iteration over set bits, cardinality,
   and a growth policy;
2. **bitfield extraction and insertion** over an arbitrary `[hi:lo]` range of an
   integer value (the classic `get_bits` / `set_bits` pair), which `std.bit`
   lacks;
3. **bit-level stream I/O** — an LSB-first / MSB-first bit reader and writer over
   bytes, the bridge that later connects to `io` and to wire protocols.

## Selected languages (frozen)

Bit manipulation exists in every language, so presence is not a discriminator.
The languages below are the ones whose **bit/set designs differ in a way worth
studying** — in particular their *container* type and their *bit-ordering* model.

Mandatory languages, always present in this run: **C, C++, Go, Rust, JS/TS,
Python** — plus **Mojo**, covered by the `mojov1` buch (no researcher).

| group | researcher | languages | reason |
| --- | --- | --- | --- |
| systems-lowlevel | 1 | C, C++ | C has only raw operators plus manual `uint64_t` words (no container); C++ adds `std::bitset` (fixed width, compile-time) and `std::vector<bool>` (the famous packed specialisation) — the two ancestral container models |
| systems-modern | 1 | Go, Rust | Go's `math/bits` gives scalar primitives but no bit-set type; Rust's integer primitives (`count_ones`, `leading_zeros`, `rotate_left`) plus the `bitvec`/`fixedbitset` ecosystem are the strongest container designs |
| scripting-web | 1 | Python, JS/TS | Python's integers are **arbitrary precision** (no fixed width — a distinct model) with `int.bit_count()`; JS numbers are 32-bit for bitwise ops while `BigInt` is unbounded — the sharpest width trap |
| managed-JVM | 1 | Java | `java.util.BitSet` is the canonical, best-documented growable bit-set class (auto-growth, word-based `long[]`, cardinality, logical ops) |
| functional/BEAM | 1 | Elixir | Erlang bit syntax / bitstrings have **arbitrary bit length** and a native LSB-vs-MSB binary-comprehension segment model — a distinct ordering and I/O story |
| data/science | 1 | Julia | `BitArray`/`BitSet` are packed bit containers with excellent iteration and set-operation design — the strongest "bitset as a first-class collection" reference |

All six groups are selected this run (6 researchers, the upper bound). No group is
dropped: bitsets span all of them in a way that adds signal.

## Question set (adapted for bit)

The standard 12 questions apply in order. The socket-specific questions are
replaced by bit equivalents; everything else is unchanged:

- Q7 (was IPv4/IPv6) → the **width and ordering model**: fixed vs arbitrary
  width, signed vs unsigned, and bit ordering (LSB-first vs MSB-first); how a
  container type relates to scalar integer functions.
- Q8 (was timeouts) → **bounds, overflow and growth**: out-of-range index,
  shift amount ≥ width, negative input, set growth/reallocation, and what is
  defined vs undefined.
- Q9 (was TLS) → the **three layers** and how the language divides them: raw
  integer bit functions, the set/container abstraction, and bit-level stream
  I/O; which of the three the language's stdlib actually provides.

Q1–Q6, Q10–Q12 are kept verbatim.

## Writing contract

Each researcher writes its language files **directly** into
`akku/prim_bit/_dev/<lang>.md`, one file per language of its group, using exactly
this section structure:

```
# bit research: <lang>
## 1. Standard library support
## 2. Relevant community libraries
## 3. Exposed APIs
## 4. Error representation
## 5. Ownership semantics
## 6. Blocking / non-blocking
## 7. Width and ordering model
## 8. Bounds, overflow and growth
## 9. Scalar functions, container type and bit-level I/O
## 10. Interesting design decisions
## 11. Decisions NOT to copy
## 12. Ideas fitting Mojo
## Sources
```

There is no reporting-project and no `docs` materialization pass. Every factual
claim cites a source (URL, or `repo/path:line`). Derived statements are marked
`(Assessment: derived from <sources>)`; unsourced statements are marked `GUESS:`
with the reason no source exists.

The Mojo side is **not** a researcher-written file: the facts live in the
`mojov1` buch (`mojov1/stdlib/bit`). `mojo.md` is a small pointer note that
records what the buch answers and which parts of the question set it does not —
those unanswered parts are the library's gap premise.

## Status

| lang | group | file | state |
| --- | --- | --- | --- |
| C | systems-lowlevel | `c.md` | done |
| C++ | systems-lowlevel | `cpp.md` | done |
| Go | systems-modern | `go.md` | done |
| Rust | systems-modern | `rust.md` | done |
| Python | scripting-web | `python.md` | done |
| JS/TS | scripting-web | `js-ts.md` | done |
| Java | managed-JVM | `java.md` | done |
| Elixir | functional/BEAM | `elixir.md` | done |
| Julia | data/science | `julia.md` | done |
| Mojo | (buch) | `mojo.md` → `mojov1/stdlib/bit` | covered by buch |

Researchers started: **6** (one per selected group; the upper bound).

All nine language files were written directly by their group's researcher: 6
researchers, one per selected group. Phase 1 is complete; the review happens in
`.agents/workflows/NewLibPhase2ResearchReview.md`.
