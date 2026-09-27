<!--
Design record for mojoakku/bit — NOT end-user documentation.
End-user documentation lives inline in the `*.mojo` files (the `# API-DOCS`
blocks) and in `__init__.mojo`. This file keeps the developer-facing reasoning:
status bookkeeping, tests, rationale, reference-API comparisons, non-goals and
open questions. It reflects the state after Phase 5 (docs: per-entry test lists).
-->

# bit — Design Record

## Purpose

`mojoakku/bit` is the MojoAkku **bit twiddling and bitset** library: a small,
predictable toolkit for working at the bit level. It is a leaf library (no
sibling dependency edges) and a general-purpose base block — useful far outside
networking for flags, permission sets, feature switches, bitfield parsing,
packed data and the primitive layer that later libraries (`hash`, `digest`,
`encoding`, `compression`) build on.

It is designed for a low-vision user: one error model, one ordering model, one
container, explicit bounds behaviour, and **no magic sentinels** — an absent bit
is `Optional`, an out-of-range field is a typed error, never a `-1`.

The Mojo standard library already ships `std.bit` with the **scalar**
primitives (`pop_count`, `count_leading_zeros`, `count_trailing_zeros`,
`bit_reverse`, `byte_swap`, `rotate_bits_left`, `rotate_bits_right`,
`next_power_of_two`, `prev_power_of_two`, `log2_floor`, `log2_ceil`, `bit_not`,
`bit_width`, plus `mask.is_negative` and `mask.splat`) — see `mojov1/stdlib/bit`.
Those are **unstable** (no `@stable` marker). They are the **stdlib-first case**:
MojoAkku wraps/extensions them, it does not rebuild them. The three things
`std.bit` does **not** provide — and this library's reason to exist — are the
three layers below.

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 8 entries in this document are `planned` at Phase 3; `Implementation
status:` is `not implemented` until Phase 11.

## Dependencies

`bit` has **no dependency edge to any sibling MojoAkku library**. It is a leaf
in the dependency graph: it depends only on the Mojo standard library.

| Library | Edge | Justification |
| --- | --- | --- |
| (none) | — | Every signature is built from the Mojo standard library (`Span`, `MutSpan`, `List`, `Optional`, `UInt64`, `Int`, `Bool`, `String`, `Some[Writer]`). No signature mentions a stream, socket, file, buffer, URL or other sibling concept, so no sibling edge can be technically justified. |

- **Why a leaf.** A dependency edge exists only when a library needs another
  library's public types or functions. `bit` needs none. Adding an edge would
  create coupling without a technical reason, which the dependency rules forbid.
  In particular `bit` does **not** depend on `mojoakku/io`: the bit reader/writer
  work directly over `Span[UInt8, _]` / `List[UInt8]`, and a byte-stream adapter
  (a `BitReader` over `mojoakku/io.Reader`) is a **future** library that would
  point *to* both `bit` and `io`, never the reverse.
- **No physical nesting.** `mojoakku/bit/` is a flat sibling under `mojoakku/`.
- **The stdlib `std.bit` relationship.** MojoAkku `bit` does **not** reimplement
  `std.bit`'s scalar functions; it consumes them (its bitfield functions and the
  container use `std.bit` internals such as `pop_count`). Where the stdlib is
  silent — a set container, `[hi:lo]` bitfield access, ordered bit-level I/O —
  MojoAkku extends. This is stated per entry under `Rationale`.
- **Direction of future edges.** Later libraries (`hash`, `digest`, `encoding`,
  `compression`) point *to* `bit`, never the reverse.

## Overview

MojoAkku `bit` is a pure, in-process, deterministic library with **three
layers**, each independently usable:

1. **Container layer — `BitSet`.** A growable, word-packed set of bits
   (`List[UInt64]`, 64-bit words) with LSB-first indexing (index 0 = least
   significant bit of word 0 — the cross-language consensus), value semantics,
   set algebra, cardinality and an ascending "next set bit" search. This is what
   `std.bit` has no analogue for.
2. **Bitfield layer — `get_bits` / `set_bits`.** Extract or insert a sub-range
   `[hi:lo]` of an integer value, with defined bounds and a defined overflow
   policy (a field that does not fit **raises**, it never truncates silently).
3. **Bit-I/O layer — `BitReader` / `BitWriter`.** Read and write individual bits
   and up to 64-bit groups over bytes, with an **explicit** bit order
   (`LSB_FIRST` / `MSB_FIRST`) passed by the caller — never a global switch and
   never a hidden default.

Cross-cutting shape:

- **One typed error** (`BitError`) with a small, **closed** `BitErrorKind`
  discriminant (`RANGE`, `BAD_RANGE`, `OVERFLOW`, `EOF`, `OTHER`) — no OS errno,
  no sentinel `-1`, no panic-as-error.
- **One ordering value** (`BitOrder`) reused by the bit-I/O layer.
- **Explicit bounds**: an out-of-range index/field is a typed error for the
  operations that can address outside data (index/range setters, readers,
  bitfield functions); an in-range query of a not-yet-set bit is `False`.
- **Value semantics**: `BitSet`, `BitError`, `BitErrorKind`, `BitOrder` are
  value types with Mojo lifecycle conformance; no hidden global state.

The problem space is covered by every reference language, so the value of this
library is not "another bit API". It is a *predictable, consistent and
easy-to-read* surface for a low-vision user. The research shows all reference
languages converge on the same verbs (`set`/`clear`/`toggle`/`test`), the same
LSB-first container indexing, the same four set operations, and the same
`read_bits`/`write_bits` stream pair — but **diverge** on naming (`count` vs
`cardinality` vs `length`), on ordering (containers LSB vs streams MSB), and on
out-of-range behaviour (raise vs truncate vs UB). `bit` picks one model and
justifies each pick below.

## Goals

- **G1 — Fill exactly the three gaps `std.bit` leaves:** a set container, a
  `[hi:lo]` bitfield pair, and ordered bit-level I/O. Do not rebuild the scalar
  functions.
- **G2 — One predictable convention set** a low-vision user can memorise once:
  LSB-first indexing for the container; `MSB_FIRST`/`LSB_FIRST` explicit for
  streams; inclusive `[lo, hi]` ranges; `snake_case` names; verbs
  `set`/`clear`/`toggle`/`test`.
- **G3 — No magic values.** Absence is `Optional`; a bad range or overflow is a
  typed error; a bit beyond the data in a query is `False`, not `-1`.
- **G4 — Value semantics and no hidden global state.** Everything is a value
  type; ordering is a parameter, never a package-global switch.
- **G5 — Implementable in pure Mojo**, no Python/FFI dependency, deterministic
  and fully testable with `mojo run`.

## Non-Goals

Decisions deliberately **not** copied from the reference languages (from the
`§11 Decisions NOT to copy` sections of the research files). Each name the
reference and why it does not fit Mojo.

- **Arbitrary-precision integers as the primary bit carrier** (Python `int`,
  Elixir bignum) — `python.md` §11. Mojo's numeric model is fixed-width
  (`SIMD`/`Int..UInt256`), and a packed word container is the efficient shape.
  `BitSet` uses `UInt64` words instead.
- **A mutable per-object bit-order property** (Python `bitarray(endian=...)`,
  and libraries that refuse to mix endianness) — `python.md` §11, `js-ts.md`
  §11. Order in `bit` is an explicit argument to a reader/writer, not a hidden
  object state that makes operations fail at runtime.
- **Silent truncation on an out-of-range pack** (Erlang/Elixir
  `<<16#ff:4>> == <<15:4>>`) — `elixir.md` §11. `set_bits` **raises**
  `OVERFLOW` when the field does not fit. A low-vision user must never silently
  lose bits.
- **A package-global mutable endianness/order switch** (Go `bitset`
  `BigEndian()/LittleEndian()`) — `go.md` §11. Order is passed per reader/writer.
- **Undefined behaviour for out-of-range shifts or unchecked out-of-range
  access** (C UB, C++ `operator[]`, JS opt-in unchecked reads, `WriteBitsUnsafe`)
  — `c.md` §11, `cpp.md` §11, `js-ts.md` §11, `go.md` §11. `bit` raises or
  returns a defined value; there is no `unsafe_*` bit API in release 1.
- **A `-1` sentinel for "no more set bits"** (Java `nextSetBit`) — `java.md`
  §11. `find_next` returns `Optional[Int]`.
- **Masking a too-large shift distance** (Java/JS `x << 32 == x`) — `java.md`
  §11, `js-ts.md` §11. `bit` treats an invalid shift/field as `BAD_RANGE`.
- **A proxy reference type / a packed `vector<bool>` specialisation** (C++
  `std::vector<bool>::reference`) — `cpp.md` §11. `BitSet` exposes
  `test`/`set`/`clear`, never a borrowable bit reference.
- **Three algebra styles for every operation** (Go/Rust/JS materialise /
  in-place / cardinality-only) — `go.md` §10, `rust.md` §10, `js-ts.md` §10.
  `bit` ships **materialising** (`union`, …) and **in-place** (`union_with`, …);
  the cardinality-only third style stays a documented future addition.
- **`Bool <: Integer` coercion, `~n == -n-1` sign traps, negative shifts
  silently reversing** (Julia) — `julia.md` §11. `bit` keeps `Bool` and the bit
  operations separate and treats invalid ranges as errors.

## Release 2 additions

The four items below were release-1 Non-Goals and are **now shipped** (release
2), implemented additively with no change to any release-1 behaviour. The
release-1 deferral records are preserved in git history (phase-13 commit
`f335381`).

- **`BitSet.complement` / `complement_with`** — `c.md` §10
  (`bitmap_complement`), `julia.md` §12 (word-parallel complement). The hard
  part was the universe (a growable set has no fixed width); the resolution is an
  **explicit `width` argument**. `complement(width)` returns a new set of the
  bits `0..width-1` that are **not** set in the receiver; bits at or above
  `width` are outside the universe and are 0. `complement_with(width)` does the
  same in place. A negative `width` raises `RANGE`; `width == 0` yields the empty
  set. This matches Julia `BitSet`'s `complement` over a stated range and keeps
  Go's observation (`go.md` §3) that the four ops are the core — complement is
  added *on top*, not baked in.
- **`BitSet.to_bytes` / `BitSet.from_bytes`** — Go `WriteTo`/`ReadFrom`
  (`go.md` §3), Java `toByteArray`/`valueOf` (`java.md` §3). The fixed contract
  is **little-endian, LSB-first, minimal length**: byte 0 bit 0 is bit index 0,
  and the length is `ceil(len / 8)` (0 bytes for the empty set). `from_bytes`
  reverses it exactly, so `from_bytes(to_bytes(x)) == x` for every set. This is
  the layout the earlier deferral was waiting for: stable, one bit-order, aligned
  with the container's own LSB-first indexing.
- **Full iteration over set bits** — Julia `BitSet`, Go `EachSet`, JS
  `[Symbol.iterator]` (`julia.md` §3, `go.md` §3, `js-ts.md` §3). `BitSet.__iter__`
  returns a public `BitSetIter` that yields the set indices in ascending order,
  so `for i in bits:` works without `find_next` boilerplate. `BitSetIter` uses
  Mojo's iteration protocol (`__has_next__` / `__next__`; verified in the
  container, `mojov1/types/collections`). It holds a **snapshot copy** of the
  words, so mutating the set while iterating is safe and deterministic (the
  iterator sees the state at `__iter__` time). `find_next` and `to_list` remain
  the primitive and the bulk convenience.
- **Generic bitfield carriers** — Rust `T::BITS`, Go width-in-the-name
  (`rust.md` §7, `go.md` §7). `get_bits` / `set_bits` become generic over
  `[dtype: DType]` with a `Scalar[dtype]` carrier constrained by
  `where dtype.is_integral()` (verified: `Scalar[dtype]` shifts and `bit_width`
  work under a `dtype` parameter). The field bound is now the carrier's own width
  (`hi <= bit_width - 1`) instead of a hard-coded 63, so `UInt8` fields go to 7,
  `UInt16` to 15, `UInt64` to 63 unchanged. Every existing `UInt64` call keeps
  its exact behaviour and error kinds; the change is a widening, not a
  redefinition.

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| Container mutation verbs | Go `Set/Clear/Flip/Test`; Java `set/clear/flip/get`; Rust `insert/remove/toggle/contains`; C++ `set/reset/flip/test`; Elixir `set/reset/flip/test?` | `go.md` §3; `java.md` §3; `rust.md` §3; `cpp.md` §3; `elixir.md` §3 |
| Container indexing (LSB-first) | Java `bits[i/64]` at `i%64`; C/C++ index 0 = LSB; Go index 0 = LSB; Julia LSB-first per chunk | `java.md` §7; `c.md` §7; `cpp.md` §7; `go.md` §7; `julia.md` §7 |
| Container word size | Julia `Vector{UInt64}`; Java `long[]` (64); Go `[]uint64`; Boost block-parameterised | `julia.md` §7; `java.md` §7; `go.md` §7; `cpp.md` §10 |
| Set algebra (four ops) | Go `Union/Intersection/Difference/SymmetricDifference`; Rust `union/intersection/difference/symmetric_difference`; JS `union/intersection/difference/change`; Julia `union/intersect/setdiff/symdiff` | `go.md` §3; `rust.md` §3; `js-ts.md` §3; `julia.md` §3 |
| In-place vs materialising algebra | Go `InPlace*`; Rust `*_with`; JS `new_*` | `go.md` §3; `rust.md` §3; `js-ts.md` §3 |
| Iteration over set bits | Go `NextSet/EachSet`; Java `nextSetBit`/`stream`; Rust `ones()`; Python `search(1)`; C++ `find_first/find_next` | `go.md` §3; `java.md` §3; `rust.md` §3; `python.md` §3; `cpp.md` §3 |
| Optional over sentinel | Rust `Option`; Go `(value, ok)`; Java `-1` (rejected) | `rust.md` §4,§10; `go.md` §10; `java.md` §11 |
| Growth / shrink contract | Go grows to highest set bit, never auto-shrinks; Java doubling `ensureCapacity`; Rust `grow/shrink`; JS `resize/trim` | `go.md` §10; `java.md` §10; `rust.md` §10; `js-ts.md` §10 |
| Bitfield read/write over a bit range | C kernel `bitmap_read(map, start, nbits)` / `bitmap_write(map, value, start, nbits)`; Julia `BitOperations.bget/bset` (zero-based, LSB-up, reverse ranges rejected) | `c.md` §10; `julia.md` §12 |
| Mask-driven gather/scatter (future) | Java `Integer.compress/expand`; Go `Extract/Deposit`; Rust `extract_bits/deposit_bits` | `java.md` §3; `go.md` §3; `rust.md` §3 |
| Bit-I/O read/write pair | Go `ReadBits(n)/WriteBits(v,n)`; Java `readBits(int)/readBit()`; JS `readBits/writeBits`; Rust `read::<N,_>()/write/write_var` | `go.md` §3; `java.md` §3; `js-ts.md` §3; `rust.md` §3 |
| Bit-I/O ordering as explicit parameter | Rust generic `Endianness`; Java `ByteOrder`; numpy `bitorder`; C++ `LSBFirst/MSBFirst`; Rust `Lsb0/Msb0` | `rust.md` §3,§7; `java.md` §7; `python.md` §7; `cpp.md` §12; `rust.md` §7 |
| Container equality | Go `Equal(c)`; Java `equals` (ignores capacity); JS `equals()`; Julia `==` | `go.md` §3; `java.md` §3,§10; `js-ts.md` §3; `julia.md` §3 |
| Bit-I/O cursor + byte align | Java `alignWithByteBoundary()/bitsAvailable()`; Go `Align()`; Python `pos/bytealign()`; JS `bitsLeft/index` | `java.md` §3; `go.md` §3; `python.md` §3; `js-ts.md` §3 |
| Bit-I/O EOF signalling | Go `(value, error)`; Java `-1` for premature EOS; Python `ReadError`; Rust `Result` | `go.md` §3; `java.md` §3; `python.md` §4; `rust.md` §4 |
| Typed error + closed kind | Rust `ErrorKind` (non-exhaustive); Go sentinels + `OpError`; Java checked `IOException`; and MojoAkku `io`'s `IoError`/`IoErrorKind` | `rust.md` §4; `go.md` §4; `java.md` §4; `mojoakku/io/_dev/DESIGN.md` |
| Mojo language anchors | `Span`/`MutSpan` views; `List` owned; `Optional`; `comptime` members; typed `raises`; `mut self`; `Some[Writer]`; origin-parameterised struct | `mojov1/types/overview`; `mojov1/types/collections`; `mojov1/errors/error-model`; `mojoakku/io/_dev/DESIGN.md` |

## Public API

Every entry below is listed here with its one-line meaning and is fully
specified in `## Semantics`. Names are stable: Phase 5 documents them and
Phase 7 stubs them, in this order.

**Error, order and result types**

1. `BitErrorKind` — closed discriminant for `BitError`: `RANGE`, `BAD_RANGE`,
   `OVERFLOW`, `EOF`, `OTHER`.
2. `BitError` — the one typed error: `kind: BitErrorKind`, `op: String`,
   `detail: String`.
3. `BitOrder` — the bit order of a reader/writer: `MSB_FIRST`, `LSB_FIRST`.

**Container layer**

4. `BitSet` — a growable, word-packed set of bits with LSB-first indexing,
   set algebra (incl. `complement` over an explicit width), cardinality,
   ascending search, full iteration and byte serialisation.
5. `BitSetIter` — ascending iterator over a `BitSet`'s set-bit indices, returned
   by `BitSet.__iter__` (snapshot semantics).

**Bitfield layer**

6. `get_bits` — extract the inclusive field `[hi:lo]` of an integral value as a
   right-aligned value of the same type (generic over the dtype).
7. `set_bits` — insert a field into the inclusive `[hi:lo]` range of an integral
   value, returning the new value (generic over the dtype).

**Bit-I/O layer**

8. `BitReader` — read individual bits and up to 64-bit groups over a borrowed
   byte span, in an explicit bit order.
9. `BitWriter` — write individual bits and up to 64-bit groups into an owned
   byte buffer, in an explicit bit order.

## Error Surface

One error type, `BitError`, with a closed five-value `BitErrorKind`. Which API
raises what:

| API | Raises | Kinds |
| --- | --- | --- |
| `BitSet` index setters (`set`, `clear`, `toggle`, `set_to`, `test`), range setters (`set_range`, `clear_range`, `toggle_range`) and `complement` / `complement_with` | `BitError` | `RANGE` (negative index / negative `lo` / negative `width`), `BAD_RANGE` (`lo > hi`) |
| `BitSet` queries (`find_next`, `count`, `is_empty`, `all`, `any`, `none`, `is_subset_of`, `is_superset_of`, `is_disjoint`, `to_list`, `reserve`, `shrink`, `clear_all`, `__len__`, `capacity`) and algebra (`union`, `intersection`, `difference`, `symmetric_difference`, `*_with`) | none | — |
| `get_bits` / `set_bits` | `BitError` | `RANGE` (`lo < 0` or `hi > 63`), `BAD_RANGE` (`hi < lo`), `OVERFLOW` (`set_bits` field does not fit) |
| `BitReader.read_bit` | `BitError` | `EOF` (no bits remaining) |
| `BitReader.read_bits` | `BitError` | `EOF` (not enough bits), `RANGE` (`count < 1` or `count > 64`) |
| `BitReader.align`, `bit_pos`, `bits_left`, `has_bits`, `order` | none | — |
| `BitWriter.write_bits` | `BitError` | `RANGE` (`count < 0` or `count > 64`), `OVERFLOW` (nonzero `value` bits above `count`) |
| `BitWriter.write_bit`, `align`, `bit_len`, `byte_len`, `to_bytes`, `order` | none | — |

Recoverability: every `BitError` is a recoverable **data** error — the caller can
retry with a corrected index/range/count, extend the buffer, or read fewer bits.
No operation is fatal and none aborts.

## Conventions

- **Indexing.** The container is **LSB-first, zero-based**: index `i` is bit
  `i % 64` of word `i / 64`. This is the cross-language consensus (`java.md` §7,
  `c.md` §7, `cpp.md` §7, `go.md` §7, `julia.md` §7).
- **Ranges are inclusive `[lo, hi]`** with `lo <= hi`. `lo > hi` is `BAD_RANGE`;
  a negative bound is `RANGE`. Inclusive is chosen so the range reads exactly
  like the bitfield pair (`get_bits(value, hi, lo)`), matching Julia's
  `BitOperations` (`julia.md` §12) and JS `setRange` (`js-ts.md` §3). Java's
  half-open `[from, to)` is **not** copied (`java.md` §3).
- **Ordering is explicit**, never global and never hidden: `BitReader`/
  `BitWriter` take a `BitOrder` argument. Container indexing is always LSB-first
  and is not configurable.
- **Names are `snake_case`** for functions and methods, `CamelCase` for types,
  `SCREAMING_CASE` for `comptime` constants — the Mojo style guide.
- **No sentinels.** Absence is `Optional`; a bad input is a typed error.
- **No hidden global state.** Nothing in `bit` mutates process-global state, and
  ordering is a value, not a switch (`go.md` §11).

## Ownership and Lifecycle

- **`BitSet` is an owning value type.** It owns a `List[UInt64]`; a `BitSet`
  value is independent of every other after a move or an explicit `.copy()`
  (`List` is copyable, not implicitly copyable, in 1.x — `mojov1/types/overview`).
  `BitSet` conforms to `Sized, Equatable, Copyable, Deinitable, Writable`.
- **The caller owns every buffer.** `BitReader` borrows a `Span[UInt8, _]` and
  never copies or retains the data (the `SpanCursor` pattern,
  `mojoakku/io/span_cursor.mojo`). `BitWriter` owns its `List[UInt8]` and hands
  bytes back by value through `to_bytes()`.
- **`BitError` is `Copyable` but not `ImplicitlyCopyable`,** so a re-raise must
  transfer with `raise e^` — the `IoError` convention (`mojoakku/io/_dev/DESIGN.md`).
- **`BitErrorKind`, `BitOrder` are `Equatable, ImplicitlyCopyable, Deinitable,
  Writable`** — small discriminants, the `IoErrorKind`/`SeekFrom` pattern.
- **ASAP destruction.** No library type holds a resource with a destructor side
  effect; everything is freed at its last use, and there is no `close`.

## Open Questions

None block this design. The two items that could have been open are closed
explicitly as **release-1 Non-Goals** with rationale above:

- *Generic integer widths for the bitfield carrier* → Non-Goal for release 1;
  carrier fixed to `UInt64`. Revisit with a verified Mojo integer-conversion
  trait; the `get_bits`/`set_bits` names stay stable so widening later is
  additive.
- *A full `__iter__` over set bits* → Non-Goal for release 1; `find_next` +
  `to_list` cover the need. Adding `Iterable`/`Iterator` later is additive.

---

## Semantics

#### Terminology

- **Word** — a 64-bit storage unit (`UInt64`) of a `BitSet`.
- **Index** — a zero-based bit position; LSB-first (index 0 = bit 0).
- **Field** — an inclusive bit range `[hi:lo]` of an integer value, `hi >= lo`.
- **Order** — the sequence in which bits of a byte are visited: `MSB_FIRST`
  (bit 7 first) or `LSB_FIRST` (bit 0 first).
- **Set bit** — a bit whose value is 1; its index is what `find_next`/`to_list`
  return.

All indices and lengths are in bits. All carriers in release 1 are `UInt64`;
signed/sub-word carriers are a documented Non-Goal.

---

### `BitErrorKind`

Status: planned

Signature:

```mojo
struct BitErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    def __eq__(self, other: Self) -> Bool

    comptime RANGE    = BitErrorKind(0)
    comptime BAD_RANGE = BitErrorKind(1)
    comptime OVERFLOW = BitErrorKind(2)
    comptime EOF      = BitErrorKind(3)
    comptime OTHER    = BitErrorKind(4)

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `BitError.kind`; never passed by a
  caller to a bit operation. The type is **opaque**: the five `comptime` members
  are the complete public set; `_id` and its `@doc_hidden` initializer are
  implementation details (Mojo has no access control —
  `mojov1/decorators/doc-hidden`). `__eq__` is written explicitly as an
  intentional override mirroring `IoErrorKind` (`mojov1/types/operator-support`).
- **Return / meaning:** the machine-testable reason a bit operation failed.
  - `RANGE` — an index, bit position or count is negative or outside its
    addressable span (`java.md` §4's `IndexOutOfBoundsException`, expressed as a
    value).
  - `BAD_RANGE` — a range is specified backwards (`hi < lo`); the "reverse range
    rejected" rule from Julia `BitOperations` (`julia.md` §12).
  - `OVERFLOW` — a field value does not fit in the requested field width
    (chosen over Elixir's silent truncation, `elixir.md` §11).
  - `EOF` — a bit read ran past the end of the buffer (Rust's `UnexpectedEof`
    analogue, `rust.md` §4).
  - `OTHER` — any other condition; the opaque `BitError.detail` holds it.

Errors:

none — it is a discriminant, not an operation.

Tests:

- `test_error_kind_distinct_ids` — each of the five `comptime` members has a
  distinct `_id`.
- `test_error_kind_eq` — `==` compares `_id` only.
- `test_error_kind_writable` — `write_to` prints the symbolic name, never the
  number.

Implementation status:

implemented

Rationale:

`MojoAkku uses a closed BitErrorKind because MojoAkku io already taught a
low-vision user one error shape (IoError/IoErrorKind) and Rust's non-exhaustive
ErrorKind (`rust.md` §4) shows a small closed set is enough; a `-1` sentinel
(java.md §11) and a panic channel (go.md §11) are rejected.` The five kinds are
the minimum that covers all eight entries' failure modes.

---

### `BitError`

Status: planned

Signature:

```mojo
@fieldwise_init
struct BitError(Copyable, Deinitable, Writable):
    var kind: BitErrorKind
    var op: String
    var detail: String

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** constructed by the library on failure; read in
  an `except` block. Fields: `kind` (see `BitErrorKind`), `op` (a short operation
  name, e.g. `"set"`, `"clear"`, `"toggle"`, `"set_to"`, `"test"`,
  `"set_range"`, `"clear_range"`, `"toggle_range"`, `"get_bits"`, `"set_bits"`,
  `"read_bit"`, `"read_bits"`, `"write_bits"`), `detail` (opaque human-readable
  context; must not be parsed). The `op` list is illustrative, not a closed enum:
  `op` names whichever call failed. Because `range` methods and `find_next` do not
  all fail, only the operations that can raise appear in practice.
- **Return / meaning:** raised, never returned. Every condition is recoverable:
  correct the index/range (`RANGE`/`BAD_RANGE`), widen the field (`OVERFLOW`),
  read fewer bits or supply more bytes (`EOF`).
- **EOF is a bit-read condition only.** There is no "end of set"; `find_next`
  signals absence with `Optional`, not with an error and not with `-1`.

Errors:

none — `BitError` *is* the error; constructing it cannot fail.

Tests:

- `test_error_writable` — `print(e)` yields kind + op + detail.
- `test_error_reraise_transfer` — a caught error re-raises with `raise e^`.
- `test_error_op_names_call` — `op` names the failing call.

Implementation status:

implemented

Rationale:

`MojoAkku uses one typed error BitError because Rust and Java both funnel all
stream failures through one error type (rust.md §4, java.md §4) and MojoAkku io
established the kind+op+detail shape; a per-operation exception hierarchy is
rejected as noise for a low-vision user (java.md §11 on scattered exceptions).`

---

### `BitOrder`

Status: planned

Signature:

```mojo
struct BitOrder(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    def __eq__(self, other: Self) -> Bool

    comptime MSB_FIRST = BitOrder(0)
    comptime LSB_FIRST = BitOrder(1)

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** passed explicitly to `BitReader.__init__` and
  `BitWriter.__init__`; also read from a stored reader/writer for inspection. The
  two `comptime` members are the complete set; `_id` is hidden.
- **Return / meaning:** the sequence in which bits of a byte are consumed or
  produced.
  - `MSB_FIRST` — the most significant bit of a byte is read/written first
    (bit 7 then … then bit 0). This is the network/wire-canonical order (Erlang
    bit syntax, `elixir.md` §7; Java `ByteOrder.BIG`, `java.md` §7).
  - `LSB_FIRST` — the least significant bit first (bit 0 then … then bit 7).
    Common for DEFLATE-class and little-endian formats (`c.md` §10).
- It is a **value passed in**, never a global setting: Go's global
  `BigEndian()/LittleEndian()` switch is explicitly rejected (`go.md` §11).
  Rust's `Lsb0`/`Msb0` type parameter is the strongest model (`rust.md` §7); a
  runtime value is chosen instead of a type parameter to keep one `BitReader`
  type and readable signatures for a low-vision user. Both constructors require
  an explicit `order`; there is **no parameter default** (the "never a hidden
  default" rule in `## Overview`).

Errors:

none — it is a value, not an operation.

Tests:

- `test_bit_order_distinct` — the two members differ.
- `test_bit_order_eq` — `==` compares `_id`.
- `test_bit_order_writable` — `write_to` prints `MSB_FIRST`/`LSB_FIRST`.

Implementation status:

implemented

Rationale:

`MojoAkku uses an explicit BitOrder value because Java (ByteOrder), Rust
(bitstream-io Endianness) and C++ (LSBFirst/MSBFirst) all make order explicit
per stream rather than global (java.md §7, rust.md §3, cpp.md §12), and Go's
global switch is a documented anti-pattern (go.md §11). There is no default: a
caller must name the order. The recommended order is MSB_FIRST because wire
formats are MSB-canonical (elixir.md §7); the container indexes LSB-first because
that is the cross-language consensus for bitsets (java.md §7).`

---

### `BitSet`

Status: planned

Signature:

```mojo
struct BitSet(Sized, Equatable, Copyable, Deinitable, Writable):
    var _words: List[UInt64]
    var _len: Int            # logical length in bits = highest set index + 1

    def __init__(out self)
    def __init__(out self, *, capacity: Int)

    def __len__(self) -> Int                 # logical length (highest set + 1)
    def __eq__(self, other: Self) -> Bool    # same set bits; capacity ignored
    def capacity(self) -> Int                # addressable bits (_words.len * 64)
    def count(self) -> Int                   # number of set bits (cardinality)
    def is_empty(self) -> Bool

    def all(self) -> Bool
    def any(self) -> Bool
    def none(self) -> Bool

    def test(self, index: Int) raises BitError -> Bool
    def set(mut self, index: Int) raises BitError
    def clear(mut self, index: Int) raises BitError
    def toggle(mut self, index: Int) raises BitError
    def set_to(mut self, index: Int, value: Bool) raises BitError

    def set_range(mut self, lo: Int, hi: Int) raises BitError       # inclusive
    def clear_range(mut self, lo: Int, hi: Int) raises BitError
    def toggle_range(mut self, lo: Int, hi: Int) raises BitError

    def clear_all(mut self)
    def reserve(mut self, bits: Int)
    def shrink(mut self)

    def find_next(self, from_index: Int) -> Optional[Int]
    def to_list(self) -> List[Int]

    def union(self, other: BitSet) -> BitSet
    def intersection(self, other: BitSet) -> BitSet
    def difference(self, other: BitSet) -> BitSet
    def symmetric_difference(self, other: BitSet) -> BitSet

    def union_with(mut self, other: BitSet)
    def intersection_with(mut self, other: BitSet)
    def difference_with(mut self, other: BitSet)
    def symmetric_difference_with(mut self, other: BitSet)

    def is_subset_of(self, other: BitSet) -> Bool
    def is_superset_of(self, other: BitSet) -> Bool
    def is_disjoint(self, other: BitSet) -> Bool

    def complement(self, width: Int) raises BitError -> BitSet
    def complement_with(mut self, width: Int) raises BitError

    def to_bytes(self) -> List[UInt8]
    @staticmethod
    def from_bytes(bytes: Span[UInt8, _]) -> BitSet

    def __iter__(self) -> BitSetIter

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Representation.** A growable `List[UInt64]`; bit `i` is bit `i % 64` of word
  `i / 64` (LSB-first). `_len` is the logical length (highest set index + 1; 0
  when no bit is set). There is no separate "unset trailing bits" invariant
  required of the public type beyond `_len`; trailing words above `_len` are
  zero.
- **Construction.** `__init__()` makes an empty set. `__init__(capacity=...)`
  (keyword-only) reserves room for `capacity` bits up front — a growth hint, not
  a logical length, so `len()` stays 0 and `count()` stays 0.
- **`__len__` / `capacity` / `count` — three distinct, deliberately named
  quantities** (the naming trap: Java `size()` = capacity vs `length()`, Rust
  `fixedbitset.len()` = capacity — `java.md` §11, `rust.md` §11):
  - `len(bs)` — logical length in bits: highest set index + 1, or 0.
  - `capacity()` — addressable bits currently allocated (`_words.len * 64`).
  - `count()` — cardinality: how many bits are set.
  A low-vision user never has to guess which of the three a name means.
- **Growth and allocation contract.** `set`/`set_range`/`toggle_range` grow the
  word list to cover the highest touched index, doubling/`reserve`-style so
  repeated growth is amortized. As in Go's container (`go.md` §10), the list
  never shrinks implicitly; only `shrink()` releases trailing all-zero words. A
  very large index (or `reserve(bits)`) requests a correspondingly large
  allocation; release 1 documents **no cap** and lets the underlying allocator
  fail — Mojo has no recoverable allocation-failure surface (`mojov1/memory/
  allocators`), so a cap is a future addition, not a release-1 guarantee.
- **Equality (`__eq__`).** Two `BitSet`s are equal iff they have the same set
  bits; **capacity and `_len` do not participate** below the highest set bit
  (Java's `equals` ignores capacity, `java.md` §10; Go's `Equal`, `go.md` §3).
  `{5}` is equal to another `{5}` that has a larger reserved capacity.
- **Index rules (total for queries, bounded mutations):**
  - `test(index)` — `False` when `index >= len(self)` (a not-yet-set bit is not
    an error; Go `Test` returns false out of range, `go.md` §9). A **negative**
    `index` raises `RANGE`.
  - `set(index)` — sets the bit; grows the container as needed. Negative raises
    `RANGE`.
  - `clear(index)` — clears the bit; a no-op when `index >= len(self)`; negative
    raises `RANGE`.
  - `toggle(index)` — flips the bit; grows only when flipping a zero to one.
    Negative raises `RANGE`.
  - `set_to(index, value)` — `set` or `clear` according to `value`; negative
    raises `RANGE`.
- **Ranges (`set_range`/`clear_range`/`toggle_range`, inclusive `[lo, hi]`):**
  `lo > hi` raises `BAD_RANGE` (Julia rejects reverse ranges, `julia.md` §12); a
  negative `lo` raises `RANGE`; `hi` may exceed `len(self)` and grows the
  container for `set_range`/`toggle_range`. `clear_range` with `hi >= len(self)`
  is defined: it clears every in-range bit and leaves `_len` at the highest
  remaining set bit (0 when none remain) — a clear past the end is a no-op, not
  an error, mirroring `clear(index)`.
- **`clear_all`** — clears every bit and resets `_len` to 0; capacity is kept.
- **`reserve(bits)`** — ensures at least `bits` bits are addressable; never
  changes `len()` or `count()`. A non-positive `bits` is a no-op.
- **`shrink()`** — releases trailing all-zero words down to what `_len` needs;
  never changes `len()` or `count()`.
- **`find_next(from_index)`** — the lowest set index `>= from_index`, or `None`.
  The primitive behind iteration (Go `NextSet`, Java `nextSetBit`, Rust
  `ones()` — `go.md` §3, `java.md` §3, `rust.md` §3). A **negative `from_index`
  is defined as 0** rather than raising: `find_next` is a total *query* like
  `test`, not an addressing mutation, and making it total keeps the iteration
  idiom `var i = -1; while ...` free of a special first-step branch. This is a
  deliberate deviation from Java's `nextSetBit`, which throws
  `IndexOutOfBoundsException` on a negative index (`java.md` §4) — the same
  total-query reasoning that makes `test(-)` `RANGE`-only and `clear` a no-op
  past the end. A `from_index` past the end returns `None`. **`Optional`, never
  `-1`** (`java.md` §11 rejected).
- **`to_list()`** — the set indices in ascending order as a `List[Int]`. Derived
  from `find_next`; a convenience for release 1 in place of a full iterator
  (Non-Goal).
- **Cardinality/emptiness queries:** `count`, `is_empty`, `any` (== not empty),
  `none` (== empty), `all` (every addressable bit 0..`len`-1 is set; `all` of an
  empty set is `True`, the standard convention, matching C++
  `bitset::all`/`none` — `cpp.md` §3).
- **Set algebra (materialising):** `union`, `intersection`, `difference`,
  `symmetric_difference` each return a **new** `BitSet`; the receiver is
  unchanged. The four names are the cross-language consensus (`go.md` §3,
  `rust.md` §3, `js-ts.md` §3, `julia.md` §3). `symmetric_difference` is the XOR
  set (JS `change`/`xor`).
- **Set algebra (in-place):** `union_with`/`…with` mutate `self` in place and
  return nothing (Rust's `*_with` convention, `rust.md` §3; Go `InPlace*`,
  `go.md` §3). Their `_len`/growth rule is defined per op:
  - `union_with(other)` — grows `self` to cover `other`'s highest set bit;
    `_len` becomes the max of the two logical lengths.
  - `intersection_with(other)` — keeps only bits present in both; `_len`
    becomes the highest surviving set bit (0 when none remain).
  - `difference_with(other)` — removes `other`'s bits from `self`; `_len`
    becomes the highest surviving set bit (0 when none remain).
  - `symmetric_difference_with(other)` — XOR; `_len` becomes the highest
    surviving set bit.
  Capacity is never reduced by any `*_with`; call `shrink()` explicitly. These
  are the two styles shipped in release 1; the cardinality-only third style is a
  Non-Goal.
- **Relation queries:** `is_subset_of`, `is_superset_of` (Boost's
  `is_subset_of`/`is_superset` — `cpp.md` §3), `is_disjoint` (Java `intersects`
  negated — `java.md` §3). All are `False` for the empty-set edge cases in the
  usual way (`is_subset_of` of an empty set is `True`).
- **Complement (release 2):** `complement(width)` returns a new `BitSet` of the
  bits `0..width-1` that are **not** set in the receiver; `complement_with(width)`
  does the same in place. Bits at or above `width` are outside the universe and
  become 0. `width < 0` raises `RANGE`; `width == 0` yields the empty set. The
  explicit `width` resolves the release-1 open question (a growable set has no
  fixed universe). The materialising form is a copy + in-place op, so the
  receiver is unchanged. Source: `c.md` §10 (`bitmap_complement`), `julia.md`
  §12 (word-parallel complement).
- **Byte serialisation (release 2):** `to_bytes` returns an owned `List[UInt8]`
  in the fixed layout little-endian, LSB-first, minimal length — byte `i` bit `j`
  is index `i * 8 + j`, length is `ceil(len / 8)`, and the empty set is 0 bytes.
  The `@staticmethod` `from_bytes(Span[UInt8, _])` is its exact inverse, so
  `from_bytes(to_bytes(x)) == x` for every set. Trailing zero bytes carry no set
  bit, so the decoded logical length is the highest set index + 1. Sources:
  `go.md` §3 (`WriteTo`/`ReadFrom`), `java.md` §3 (`toByteArray`/`valueOf`).
- **Iteration (release 2):** `__iter__` returns a public `BitSetIter` that yields
  the set indices in ascending order, so `for i in bits:` works without
  `find_next` boilerplate. It uses Mojo's iteration protocol (`__has_next__` /
  `__next__`; `mojov1/types/collections`) and holds a **snapshot copy** of the
  words taken at `__iter__` time, so mutating the set during iteration is safe
  and deterministic. `find_next` remains the primitive and `to_list` the bulk
  convenience. Sources: `julia.md` §3, `go.md` §3, `js-ts.md` §3.
- **`Writable`** — `write_to` prints a compact set notation (e.g.
  `{0, 3, 5}`); it never allocates a temporary `String` beyond the writer's own.

Errors:

- `RANGE` — a negative `index`/`lo` in `set`/`clear`/`toggle`/`test`/`set_to` and
  the range methods, and a negative `width` in `complement`/`complement_with`.
  (`find_next` is the one place a negative `from_index` is defined as 0 rather
  than an error.)
- `BAD_RANGE` — `lo > hi` in a range method.

Tests:

- `test_bitset_lsb_first_indexing` — `set(0)` sets word 0 bit 0.
- `test_bitset_len_capacity_count` — the three quantities stay distinct.
- `test_bitset_growth_on_set` — `set` grows; `clear` never shrinks capacity.
- `test_bitset_set_range_word_boundary` — a range spanning a 64-bit boundary.
- `test_bitset_clear_range_beyond_len` — `clear_range` past the end is a no-op
  and updates `_len` to the highest remaining set bit.
- `test_bitset_clear_all_resets_len` — `clear_all` resets `len` to 0, keeps
  capacity.
- `test_bitset_shrink_frees_trailing_words` — `shrink` releases trailing zero
  words without changing `len`/`count`.
- `test_bitset_find_next_ascending` — `find_next` ascends across words.
- `test_bitset_find_next_none_past_end` — `None` past the end; negative
  `from_index` behaves as 0.
- `test_bitset_to_list_ordering` — ascending order.
- `test_bitset_union` / `test_bitset_intersection` / `test_bitset_difference` /
  `test_bitset_symmetric_difference` — each on a hand-checked pair, receiver
  unchanged.
- `test_bitset_with_ops_len_growth` — `*_with` follow the documented `_len`
  rules; capacity never reduced.
- `test_bitset_subset_superset_disjoint` — edge cases incl. the empty set.
- `test_bitset_equality_ignores_capacity` — `{5}` equals a `{5}` with larger
  capacity.
- `test_bitset_negative_index_and_reverse_range_raise` — `RANGE` / `BAD_RANGE`.
- `test_bitset_write_to_set_notation` — `write_to` prints `{0, 3, 5}`.
- `test_bitset_complement_*` — hand-checked complement, width 0, negative width
  RANGE, narrower/wider than the set, double-complement identity.
- `test_bitset_to_bytes_*` / `test_bitset_from_bytes_*` — LSB-first minimal
  layout, empty set, word-boundary crossing, decode and round-trip.
- `test_bitset_iter_*` / `test_bitsetiter_protocol_manual_loop` — ascending
  iteration, empty set, snapshot semantics after and inside the loop.

Implementation status:

implemented

Rationale:

`MojoAkku uses one growable BitSet with LSB-first indexing because Java's
BitSet (java.md §3), Julia's BitSet (julia.md §3) and the C/Go container
convention (c.md §7, go.md §7) all index bit 0 at the LSB, and all four set
operations are the cross-language consensus (go.md §3, rust.md §3, js-ts.md §3,
julia.md §3). It is growable (not fixed-width like C++ bitset<N>, cpp.md §11)
because Mojo has `comptime` value parameters if a fixed size is ever wanted, and
a growable value type is the more general base block. It uses UInt64 words
(Julia/Java/Go agree on 64, julia.md §7, java.md §7, go.md §7) and exposes
test/set/clear instead of a bit reference because C++'s proxy reference
(cpp.md §11) is a known complexity to avoid. The release-2 `complement` takes an
explicit `width` because a growable set has no fixed universe (c.md §10,
julia.md §12); `to_bytes`/`from_bytes` fix one stable little-endian LSB-first
layout (go.md §3, java.md §3); and `__iter__` snapshots the words so mutation
during iteration is safe (julia.md §3, go.md §3).`

---

### `BitSetIter`

Status: planned

Signature:

```mojo
struct BitSetIter(Deinitable):
    var _words: List[UInt64]
    var _next: Int

    def __init__(out self, var words: List[UInt64])
    def __has_next__(self) -> Bool
    def __next__(mut self) -> Int
```

Semantics:

- **Parameters / preconditions:** returned by `BitSet.__iter__`; constructing one
  directly is possible but not needed. It holds a copy of the set's words, so it
  is independent of the set from the moment it is created.
- **Return / meaning:** `__next__` returns the next set index in ascending order;
  `__has_next__` is the loop guard. `for i in bits:` yields exactly the indices
  `to_list` returns.
- **Snapshot semantics:** mutating the set after `__iter__` ran — including
  inside the loop — does not change what the iterator yields. The iterator sees
  the state at `__iter__` time.

Errors:

none — iterating a `BitSet` cannot fail.

Tests:

- `test_bitset_iter_ascending` — ascending across a word boundary.
- `test_bitset_iter_empty_yields_nothing` — the empty set yields nothing.
- `test_bitsetiter_protocol_manual_loop` — manual `__has_next__`/`__next__` loop.
- `test_bitset_iter_snapshot_after_iter` / `_snapshot_inside_loop` — snapshot
  semantics.

Implementation status:

implemented

Rationale:

`MojoAkku uses a public BitSetIter over a snapshot because Julia's BitSet and
Go's EachSet iterate set bits as a first-class operation (julia.md §3, go.md
§3), and Mojo's iteration protocol is __iter__ returning a type with
__has_next__/__next__ (mojov1/types/collections). The snapshot is deliberate:
returning a borrowing iterator would make every mutation during iteration a
compile error, which is unfriendly for a low-vision user; the copy is cheap (a
word list) and makes the loop total.`

---

### `get_bits`

Status: planned

Signature:

```mojo
def get_bits[dtype: DType](value: Scalar[dtype], hi: Int, lo: Int)
    raises BitError -> Scalar[dtype]
    where dtype.is_integral()
```

Semantics:

- **Parameters / preconditions:** `value` is the carrier of type `Scalar[dtype]`
  for any integral `dtype`; `[hi:lo]` is the inclusive field with
  `0 <= lo <= hi <= bit_width - 1`, where `bit_width` is the carrier's own width
  (`bit_width(~0)`; 8/16/32/64). `lo < 0` or `hi > bit_width - 1` raises `RANGE`;
  `hi < lo` raises `BAD_RANGE`. The `dtype` parameter is inferred from `value` or
  named explicitly.
- **Return / meaning:** the field, **right-aligned**, in the carrier's own type:
  `(value & field_mask) >> lo`. The width is `hi - lo + 1`; the result's high bits
  above the field width are zero. This is the extract half of the read/write pair
  on a raw carrier: C's kernel `bitmap_read(map, start, nbits)` (`c.md` §10) and
  Julia's zero-based LSB-up `BitOperations.bget` (`julia.md` §12).
- **Defined edges:** `hi == lo` is a one-bit field. `hi == bit_width - 1` is a
  full-width field (the `1 << bit_width` case is special-cased to an all-ones
  mask). Every release-1 `UInt64` call keeps its exact behaviour.

Errors:

- `RANGE` — `lo < 0` or `hi > bit_width - 1`.
- `BAD_RANGE` — `hi < lo`.

Tests:

- `test_get_bits_single_bit_field` — `hi == lo`.
- `test_get_bits_crossing_nibble` — a field spanning a nibble boundary.
- `test_get_bits_full_width` — `[63:0]` returns `value`; the mask special-case
  at `hi == 63`.
- `test_get_bits_out_of_range_raises` — `RANGE` for `lo < 0` / `hi > 63`.
- `test_get_bits_reversed_raises` — `BAD_RANGE` for `hi < lo`.
- `test_get_bits_uint8` / `test_get_bits_uint16_uint32` — per-width carriers.
- `test_get_bits_uint64_unchanged` — release-1 UInt64 behaviour preserved.
- `test_get_bits_per_width_bounds_raise_range` — bound is the carrier width.

Implementation status:

implemented

Rationale:

`MojoAkku uses get_bits[dtype](value, hi, lo) because it is the extract half of
the read/write pair the reference languages put on a raw carrier (C's kernel
bitmap_read, c.md §10; Julia BitOperations.bget, julia.md §12). It is generic
over Scalar[dtype] because Rust parameterizes the carrier width (rust.md §7) and
Go encodes it in the function name (go.md §7); the field bound is the carrier's
own width. A (offset, width) argument pair is the alternative and is rejected
because inclusive [hi:lo] reads the same as the value's own bit positions, which
is easier for a low-vision user to verify.`

---

### `set_bits`

Status: planned

Signature:

```mojo
def set_bits[dtype: DType](value: Scalar[dtype], hi: Int, lo: Int,
    field: Scalar[dtype]) raises BitError -> Scalar[dtype]
    where dtype.is_integral()
```

Semantics:

- **Parameters / preconditions:** `value` is the carrier of type `Scalar[dtype]`
  for any integral `dtype`; `[hi:lo]` is the inclusive field
  (`0 <= lo <= hi <= bit_width - 1`); `field` is the value to insert into that
  range, in the carrier's own type. `lo < 0` or `hi > bit_width - 1` raises
  `RANGE`; `hi < lo` raises `BAD_RANGE`. If `field` has any bit set above the
  field width (`hi - lo + 1`), it **raises `OVERFLOW`** — silent truncation is
  explicitly rejected (`elixir.md` §11).
- **Return / meaning:** the new carrier with bits `[hi:lo]` replaced by `field`
  and every other bit preserved: `(value & ~mask) | (field << lo)`, in the
  carrier's own type. This is the insert half of the pair (C `bitmap_write`,
  `c.md` §10; Julia `bset`, `julia.md` §12).
- **Defined edges:** `field == 0` clears the field. `hi == lo` inserts a single
  bit and requires `field` to be 0 or 1. Every release-1 `UInt64` call keeps its
  exact behaviour.

Errors:

- `RANGE` — `lo < 0` or `hi > 63`.
- `BAD_RANGE` — `hi < lo`.
- `OVERFLOW` — `field` does not fit in the field width.

Tests:

- `test_set_bits_insert_clear` — insert then clear a field.
- `test_set_bits_preserves_surrounding` — bits outside `[hi:lo]` unchanged.
- `test_set_bits_single_bit` — `hi == lo` with `field` 0 or 1.
- `test_set_bits_exact_capacity_ok` — a `field` that exactly fills passes.
- `test_set_bits_overflow_raises` — `field` one bit too wide raises `OVERFLOW`.
- `test_set_bits_out_of_range_and_reversed_raise` — `RANGE` / `BAD_RANGE`.
- `test_set_bits_uint8` / `test_set_bits_uint16_uint32` — per-width carriers.
- `test_set_bits_uint64_unchanged` — release-1 UInt64 behaviour preserved.
- `test_set_bits_overflow_per_width` — OVERFLOW is per carrier width.
- `test_get_set_roundtrip_per_width` — per-width extract/reinsert round-trip.
- `test_explicit_dtype_parameter` — the `[dtype]` parameter form.

Implementation status:

implemented

Rationale:

`MojoAkku uses set_bits[dtype](value, hi, lo, field) -> Scalar[dtype] because
extracting and reinserting is the round-trip that C's bitmap_read/bitmap_write
pair and Julia's bget/bset pair provide together (c.md §10, julia.md §12); it is
generic over Scalar[dtype] like Rust's width parameterization (rust.md §7); it
raises OVERFLOW instead of truncating because Elixir's silent truncation is a
documented trap (elixir.md §11), and a low-vision user must not lose bits
without a signal.`

---

### `BitReader`

Status: planned

Signature:

```mojo
struct BitReader[origin: Origin[mut=False]](Deinitable):
    var _buffer: Span[UInt8, Self.origin]
    var _order: BitOrder
    var _bit_pos: Int

    def __init__(out self, buffer: Span[UInt8, Self.origin], order: BitOrder)

    def read_bit(mut self) raises BitError -> Bool
    def read_bits(mut self, count: Int) raises BitError -> UInt64
    def align(mut self)

    def bit_pos(self) -> Int
    def bits_left(self) -> Int
    def has_bits(self) -> Bool
    def order(self) -> BitOrder
```

Semantics:

- **Construction.** Borrows a `Span[UInt8, _]` (the `SpanCursor` pattern,
  `mojoakku/io/span_cursor.mojo`); never owns, copies or retains the data. The
  lifetime checker ties the reader to the borrowed span. `order` sets the bit
  sequence (see `BitOrder`).
- **`read_bit`** — returns the next bit (`True` = 1). `MSB_FIRST` visits bit 7,
  6, … of each byte; `LSB_FIRST` visits bit 0, 1, …. Raises `EOF` when
  `_bit_pos == bits_left` (no bits remain).
- **`read_bits(count)`** — reads the next `count` bits (`1..64`) as a `UInt64`.
  The **first bit read is the most significant** of the returned value when
  `order == MSB_FIRST`, and the **least significant** when `order == LSB_FIRST`
  — the caller never has to reverse. `count < 1` or `count > 64` raises `RANGE`
  (a count of 0 is **not** a no-op here: a zero-bit read is meaningless, so it is
  rejected — unlike `write_bits(_, 0)`, where a zero-bit write is a harmless
  no-op; the asymmetry is deliberate, see Rationale). Not enough bits remaining
  raises `EOF`; **the read is atomic** — `_bit_pos` is advanced only when all
  `count` bits were available, so after an `EOF` the reader is unchanged and the
  caller can retry with a smaller `count` (the io convention for explicit
  partial progress, `mojoakku/io/_dev/DESIGN.md`). **No partial value is
  returned** — a short read is an error, not a truncated result (Python
  `ReadError`/Rust `Result`, `python.md` §4, `rust.md` §4; Java's `-1`
  premature-EOS sentinel is rejected, `java.md` §3).
- **`align`** — advances `_bit_pos` to the next byte boundary (a no-op when
  already aligned). Advancing past the last bit **clamps `_bit_pos` to the total
  bit count** so `bits_left()` never goes negative; alignment on a
  non-whole-byte buffer is therefore safe. The byte-alignment cursor reset from
  Java `alignWithByteBoundary`, Go `Align`, Python `bytealign` (`java.md` §3,
  `go.md` §3, `python.md` §3).
- **`bit_pos`** — the absolute bit offset consumed so far (never exceeds the
  total bit count).
- **`bits_left`** — total bits minus `bit_pos`; always `>= 0`.
- **`has_bits`** — `bits_left() > 0`.
- **`order`** — the reader's order, for inspection.

Errors:

- `EOF` — `read_bit`/`read_bits` with no bits remaining.
- `RANGE` — `read_bits` with `count < 1` or `count > 64`.

Tests:

- `test_bitreader_roundtrip_msb_first` — against a `BitWriter`.
- `test_bitreader_roundtrip_lsb_first` — against a `BitWriter`.
- `test_bitreader_read_bit_across_byte` — `read_bit` sequence across a byte
  boundary.
- `test_bitreader_read_bits_up_to_64` — `read_bits` up to 64 bits.
- `test_bitreader_align_to_next_byte` — `align` skips to the next byte.
- `test_bitreader_align_clamps_at_end` — `align` near the end clamps `_bit_pos`,
  `bits_left` stays `>= 0`.
- `test_bitreader_eof_atomic` — `EOF` on exhaustion leaves `_bit_pos` unchanged
  (no partial value).
- `test_bitreader_count_range_raises` — `RANGE` for count 0 and 65.
- `test_bitreader_pos_and_left_accounting` — `bits_left`/`bit_pos` accounting.
- `test_bitreader_cannot_outlive_span` — compile-time: the reader cannot
  outlive its borrowed span (documented).

Implementation status:

implemented

Rationale:

`MojoAkku uses a borrowed-span BitReader because io's SpanCursor already proved
the borrowed-view pattern works in Mojo (mojoakku/io/span_cursor.mojo) and Rust's
bitstream-io reads over an immutable source (rust.md §3); read_bits(n) returning
UInt64 is the pair named by Go/Java/JS (go.md §3, java.md §3, js-ts.md §3), with
an explicit BitOrder argument (java.md §7, rust.md §3) instead of a global
switch (go.md §11) or a hard-wired order (go.md §11, icza/bitio).`

---

### `BitWriter`

Status: planned

Signature:

```mojo
struct BitWriter(Copyable, Deinitable, Writable):
    var _bytes: List[UInt8]
    var _order: BitOrder
    var _bit_pos: Int        # bits written into the current partial byte

    def __init__(out self, order: BitOrder)

    def write_bit(mut self, value: Bool)
    def write_bits(mut self, value: UInt64, count: Int) raises BitError
    def align(mut self)

    def bit_len(self) -> Int
    def byte_len(self) -> Int
    def to_bytes(mut self) -> List[UInt8]
    def order(self) -> BitOrder
    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Construction.** Owns a growing `List[UInt8]`; `order` sets the bit sequence.
  Build-then-emit: the caller writes bits, then takes the bytes with `to_bytes`.
  This matches the Python `bitstring.BitArray` build model (`python.md` §3) and
  keeps the writer self-contained (no borrowed output buffer to size up front).
- **`write_bit`** — appends one bit. `MSB_FIRST` fills bit 7 of the current byte
  first; `LSB_FIRST` fills bit 0 first. A fresh partial byte is started when the
  current one fills.
- **`write_bits(value, count)`** — writes the low `count` bits (`0..64`) of
  `value`, first-written bit being the most significant of those `count` when
  `order == MSB_FIRST` (least significant when `LSB_FIRST`), so it is the exact
  inverse of `BitReader.read_bits`. `count < 0` or `count > 64` raises `RANGE`.
  **`count == 0` with `value == 0` is a no-op; `count == 0` with a nonzero
  `value` raises `OVERFLOW`** (a nonzero value cannot be written in zero bits).
  **If `value` has any bit set above `count` (`value >> count != 0`),
  `write_bits` raises `OVERFLOW`** — silent bit-drop is rejected (Go's
  `WriteBits(0x1234, 8)` quietly writing `0x34` is a documented trap, `go.md`
  §11). The caller who genuinely wants to write the low `count` bits of a wider
  value masks explicitly first. A failing `write_bits` writes nothing (atomic).
  For `count == 64` the check is "no bits above 64 exist", so it is trivially
  satisfied and no `>> 64` is evaluated.
- **`align`** — zero-fills the remainder of the current partial byte and starts a
  fresh byte; a no-op when already byte-aligned.
- **`bit_len`** — total bits written (including the partial byte's bits).
- **`byte_len`** — number of bytes currently held (`_bytes.len`).
- **`to_bytes(mut self)`** — returns the writer's bytes as a **`List[UInt8]`
  copy**; the writer keeps its contents and stays writable. Taking `mut self`
  documents that this is a live read of the writer's buffer, not a destructive
  consume; a consuming variant is not offered in release 1 (the caller can drop
  the writer afterwards). The final partial byte is zero-padded in its unused
  bits.
- **`write_to`** — prints the writer's bytes as hex for debugging.

Errors:

- `RANGE` — `write_bits` with `count < 0` or `count > 64`.
- `OVERFLOW` — `write_bits` with a `value` that has nonzero bits above `count`.

Tests:

- `test_bitwriter_roundtrip_both_orders` — against a `BitReader`.
- `test_bitwriter_fill_byte_msb_vs_lsb` — bit placement in a full byte.
- `test_bitwriter_count_zero_noop` — `write_bits(0, 0)` writes nothing.
- `test_bitwriter_count_zero_nonzero_overflow` — `write_bits(1, 0)` raises
  `OVERFLOW`.
- `test_bitwriter_overflow_high_bits` — a value with bits above `count` raises
  `OVERFLOW` and writes nothing (atomic).
- `test_bitwriter_align_zero_fills` — `align` zero-fills the partial byte.
- `test_bitwriter_len_accounting` — `byte_len`/`bit_len` accounting.
- `test_bitwriter_to_bytes_pads_and_keeps_writable` — `to_bytes` zero-pads the
  final partial byte and the writer stays writable.
- `test_bitwriter_count_range_raises` — `RANGE` for count 65 and count -1.

Implementation status:

implemented

Rationale:

`MojoAkku uses an owning, build-then-emit BitWriter because it removes the
caller-side buffer sizing that the reference stream writers push onto the caller
(c.md §11 length-less pointers) and matches Python's BitArray build model
(python.md §3); write_bits(value, count) is the Go/Java/JS pair (go.md §3, java.md
§3, js-ts.md §3) with an explicit BitOrder (java.md §7). Silent bit-drop on a
too-wide write is rejected (go.md §11) and replaced by an OVERFLOW signal, the
same "never silently lose bits" rule that set_bits follows (elixir.md §11). The
count-0 asymmetry (write is a no-op, read raises) is deliberate: a zero-bit write
is a harmless uniform-loop convenience, while a zero-bit read would return a
value with no bits and is rejected as meaningless.`

---

## Traceability (research → API)

| Non-Goal / decision | Reference | Where handled |
| --- | --- | --- |
| LSB-first container indexing | `java.md` §7, `c.md` §7, `cpp.md` §7, `go.md` §7, `julia.md` §7 | `BitSet` Semantics; Conventions |
| Four set operations + in-place | `go.md` §3, `rust.md` §3, `js-ts.md` §3, `julia.md` §3 | `BitSet` Semantics |
| `Optional` over `-1` | `java.md` §11, `rust.md` §10 | `BitSet.find_next`; `BitError` |
| Inclusive `[hi:lo]` ranges | `julia.md` §12, `c.md` §10 | Conventions; `get_bits`/`set_bits` |
| Raise on overflow, never truncate | `elixir.md` §11, `go.md` §11 | `set_bits`; `BitWriter.write_bits`; `BitErrorKind.OVERFLOW` |
| Explicit order, no global switch | `go.md` §11, `java.md` §7, `rust.md` §7 | `BitOrder`; `BitReader`/`BitWriter` |
| `read_bits`/`write_bits` pair | `go.md` §3, `java.md` §3, `js-ts.md` §3 | `BitReader`/`BitWriter` |
| Atomic read (no partial progress on EOF) | `mojoakku/io` convention, `rust.md` §4 | `BitReader.read_bits` |
| Short read is an error, not a partial value | `python.md` §4, `rust.md` §4 | `BitReader.read_bits` |
| Named quantity separation (len/capacity/count) | `java.md` §11, `rust.md` §11 | `BitSet` Semantics |
| Container equality ignores capacity | `java.md` §10, `go.md` §3 | `BitSet.__eq__` |
| Stdlib-first scalar layer (wrap `std.bit`) | `mojov1/stdlib/bit` | Dependencies; Purpose |
| No `unsafe_*` bit API | `c.md` §11, `js-ts.md` §11 | Non-Goals |
| Generic widths are a Non-Goal | `rust.md` §7, `go.md` §7 | Non-Goals; `get_bits`/`set_bits` |
| `complement` deferred (width semantics) | `c.md` §10, `julia.md` §12, `go.md` §3 | Non-Goals |
| `BitSet` byte serialisation deferred | `go.md` §3, `java.md` §3 | Non-Goals |
