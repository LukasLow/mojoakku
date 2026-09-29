# prim_bit — open backlog

API candidates the research showed are possible in Mojo but that are not
implemented. Remove a line once it ships; an empty list is the expected end
state. Format and rules: `.agents/workflows/LibraryLayout.md`.

## Deferred container additions

- `cardinality-only algebra variants` — union/intersection/difference that only return the count, without building the result set. (origin: `go.md` §10, `rust.md` §10, `js-ts.md` §10)
- `extract` / `deposit` (bit gather/scatter by mask) — compress/expand bits selected by a mask, the generalisation of `get_bits`/`set_bits`. (origin: `java.md` §3, `go.md` §3, `rust.md` §3)
- `BitSet.range query views` — count-ones / any-set over an inclusive `[lo, hi]` range without materialising a subset. (origin: `rust.md` §3)
- `BitSet.packed-struct view` — a typed overlay over a BitSet for sub-byte field access. (origin: `julia.md` §12)
- `BitSet allocation cap` — an optional maximum-bits bound so a huge index/reserve fails predictably instead of letting the allocator abort. (origin: `go.md` §10; `_dev/DESIGN.md` growth contract)

## Deferred bitfield generics

- `signed bitfield carriers` — `get_bits`/`set_bits` over signed integral types (excluded in release 2 because `bit_width(~0)` is 0 for signed). (origin: `rust.md` §7, `go.md` §7)

## Deferred bit-I/O additions

- `BitReader.peek` — non-consuming lookahead over the next bits. (origin: `go.md` §12, `cpp.md` §12)
- `bit-I/O over a borrowed MutSpan view` — read directly from a caller's buffer window instead of a whole span. (origin: `rust.md` §12)
- `bit-stream adapter over mojoakku/io_core.Reader` — a BitReader/BitWriter layered on the byte stream trait (a future library pointing to both `bit` and `io`). (origin: `io` byte layer; `_dev/DESIGN.md` Dependencies)
