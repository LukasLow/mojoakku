# io Phase 4 — Design Review

## Verdict: APPROVED (pass 4)

Pass 4 (same reviewer session) verified all pass-3 findings resolved and found
no blocking issues: 15 entries × seven fields, no bare `Span[UInt8]`, every
decision justified with a research reference, no Mojo-correctness problems.

## Pass 3 findings (addressed)

| # | Pass-3 finding | Fix |
| --- | --- | --- |
| 1 | `from` is a reserved Mojo keyword used as the `seek` argument name | renamed to `whence` (matches `mojov1/stdlib/tempfile` `seek(offset, whence)`); verified by compile probe |
| 2 | `Tuple[*Rs]` variadic pack storage unverified | switched `MultiReader` to the verified `List`-backed homogeneous form; the pack→`Tuple` conversion does not compile |
| 3 | `SeekFrom.__eq__` semantics unexplained | documented: compares both `_id` and `offset` |
| 4 | Open-Questions preamble stale | reworded to record conscious acceptance |
| 5 | "read ... appends" wrong verb | corrected to "accumulates" |

## Pass 1/2 findings (addressed)

Pass 1 returned `NEEDS_WORK` with 22 findings. All were addressed in the
`io phase 4:` rework commit. The Mojo-correctness blockers were verified against
the `mojov1` buch and by compiling probe programs in the container.

| # | Finding | Fix |
| --- | --- | --- |
| 1 | `Span` (immutable) used as a write destination | all read targets are now `MutSpan[UInt8, _]`; write inputs stay `Span[UInt8, _]`; prose corrected. Verified `MutSpan[UInt8, _]` compiles (`mojov1/types/collections`) |
| 2 | removed pre-1.x `borrowed` convention | replaced with a plain (imm) parameter / no annotation |
| 3 | `Cursor` "owned-or-borrowed" not expressible in one type | split into `Cursor` (owned, R/W/Seek) and `SpanCursor` (borrowed, R/Seek) |
| 4 | `BufferedReader`/`BufferedWriter` omitted the inner type parameter; placeholder fields | `[R: Stream]`/`[W: Sink]` + `Self.R`/`Self.W` fields; verified the bounds compile |
| 5 | buffered-data-loss contradiction | resolved: read side keeps data (owned drained buffer); write side requires explicit fallible `flush`/`close` and documents drop-without-flush as accepted loss |
| 6 | unsourced `cppcodec parse_error`/`symbol_error` | replaced with `go.md §4` (`OpError`/`PathError` `op` field) + `rust.md §4` |
| 7 | `CLOSED` misused for "non-seekable" | non-seekable is now `OTHER`; `CLOSED` reserved for a closed handle; decision recorded |
| 8 | `Equatable` without `__eq__` | explicit `__eq__` added to `IoErrorKind` and `SeekFrom`; verified it compiles |
| 9 | `copy`/`read_to_end` lose the partial count on failure | documented explicit partial-loss rule; `copy` cites Go's `(written, err)` |
| 10 | "all errors recoverable" too strong | added `UNEXPECTED_EOF` kind; recoverable-vs-lossy rule in Error Surface |
| 11 | `ByteWriter` naming vs Go's `io.ByteWriter` | collision named and justified (buffer writer vs single-byte `WriteByte`) |
| 12 | `MultiReader` under-specified/unverified | full signature; final form is `List`-backed homogeneous (see pass 3) |
| 13 | stdlib write-side claim not in the API | Dependencies states no stdlib-`Writer` adapter ships in release 1 |
| 14 | `flush` on the minimal trait not argued vs Go | rationale added (Rust `Write::flush` precedent vs Go's separate `bufio.Writer.Flush`) |
| 15 | `{0, eof=false}` kept legal vs rejecting Go's `0,nil` | now **not part of the contract**; helpers guard against it (`ErrNoProgress`) |
| 16 | `IoError.op` provenance thin | cites `go.md §4` `op` fields |
| 17 | close behavior absent per entry | per-entry "Close behavior" line; library-wide rule (`no close`; `CLOSED` reserved for the file/socket layer) |
| 18 | wrong `java.md §11` citation for `setSoTimeout` | corrected to `java.md §8` |
| 19 | `LimitReader` negative `limit` undefined | defined to behave as `0` (total-function style) |
| 20 | `BufferedWriter` redundantly redeclared `write_all` | removed (inherited from `ByteWriter`) |
| 21 | Overview claimed compile-time sizing for all adapters | narrowed to the buffered adapters |
| 22 | text scope vs "byte and text streams" | explicit "Scope of release 1: bytes" + a Non-Goal |

## Verdict: (pass 2) NEEDS_WORK → addressed; re-review pending

Pass 2 confirmed findings 1–22 of pass 1 resolved, but raised 1 new blocker and
8 warnings/notes; all are now addressed:

| # | Pass-2 finding | Fix |
| --- | --- | --- |
| 1 | `copy` used `Self.R`/`Self.W` at module scope | changed to `R`/`W` (no `Self` outside a struct); verified |
| 2 | `read_into` referenced but not in the API | removed; the text now says "`read` into a caller-owned `MutSpan[UInt8, _]`" |
| 3 | "Close behavior" missing on 7 entries | added to `ByteWriter`, `BufferedReader`, `BufferedWriter`, `LimitReader`, `TeeReader`, `MultiReader`, `copy` |
| 4 | `SpanCursor._buffer: Span[UInt8, _]` not concrete | `SpanCursor[origin: Origin[mut=False]]` with `Self.origin` in the field; verified by compile probe |
| 5 | `__eq__` rationale factually wrong | corrected: `Equatable` *does* synthesize `__eq__`; ours is an intentional override |
| 6 | `Span[UInt8]` vs `Span[UInt8, _]` inconsistency | normalized the write-trait signatures and the Dependencies prose |
| 7 | non-conforming-reader kind ambiguous | both sides use `OTHER` (`ErrNoProgress`/zero-write); stated |
| 8 | Open Questions self-deferred to Phase 4 | text scope recorded as resolved for release 1 (bytes only) |
| 9 | read-vs-write loss argument weak | rephrased to the real rule: owned-and-drained while live vs explicit terminal call |

## Verified facts (container probes, Mojo 1.x)

- `MutSpan[UInt8, _]` is the correct mutable-span spelling; a bare `Span` cannot
  be written through.
- A trait with one required (`: ...`) method plus a provided default compiles.
- Explicit `__eq__` on a comptime-member value type compiles.
- A generic stored field needs `Self.R` and a `Movable & Deinitable` bound
  (`comptime Stream = Reader & Movable & Deinitable`).
- `struct MultiReader[R: Stream]` with a `List[Self.R]` field and a variadic
  `def __init__(out self, *readers: Self.R)` compiles; a variadic **type-pack**
  stored in a `Tuple` (`Tuple[*Rs]`) does **not** compile.
- `struct SpanCursor[origin: Origin[mut=False]]` with `Span[UInt8, Self.origin]`
  field compiles; `Span[UInt8, _]` as a field is rejected.
- `from` cannot be an argument name (reserved keyword); `whence` compiles and the
  full-field `__eq__` behaves as documented.

**Handoff:** re-run `NewLibPhase4DesignReview.md` once (per its step 9).
