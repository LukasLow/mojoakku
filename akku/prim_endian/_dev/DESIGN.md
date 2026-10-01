<!--
Design record for akku/prim_endian — NOT end-user documentation.
End-user documentation lives inline in the `*.mojo` files (the `# API-DOCS`
blocks) and in `__init__.mojo`. This file keeps the developer-facing reasoning:
status bookkeeping, tests, rationale, reference-API comparisons, non-goals and
open questions. It reflects the state after Phase 3 (API design).
-->

# prim_endian — Design Record

## Purpose

`akku/prim_endian` is the MojoAkku **byte-order (endianness)** library: a small,
predictable toolkit that names byte order, detects the host order at compile
time, converts integer values between the host order and a named order, and
reads or writes an integer's bytes to/from a byte span with an explicit order
and a length check.

It is a **leaf** library (no sibling dependency edges): every signature is built
from the Mojo standard library (`Scalar`, `DType`, `Span`, `MutSpan`, `UInt8`,
`String`, `Some[Writer]`). Its only two dependencies are the standard-library
primitives `std.bit.byte_swap` (reverses an integer's bytes,
`mojov1/stdlib/bit`) and `std.sys.is_little_endian()` / `is_big_endian()`
(compile-time host-order predicates, `mojov1/stdlib/sys`). `prim_endian` wraps
and names those; it does not rebuild the swap.

It is designed for a low-vision user: **one order value**, **one typed error**
with a closed kind, **explicit order on every call — never a global switch and
never a hidden default**, value semantics throughout, and no magic sentinels.

The sibling `akku/prim_bit` deliberately left endianness out; `prim_endian`
fills exactly that gap.

## Status legend

Every API entry carries a `Status:` field with exactly one of these values:

| Status | Meaning |
| --- | --- |
| `planned` | Designed and documented; no code exists yet. |
| `scaffolded` | A stub with the documented signature exists; behaviour is not implemented. |
| `tested` | Tests exist and pass against the implementation. |
| `implemented` | Implemented and passing its tests. Default after Phase 12/13. |
| `benchmarked` | Implemented, tested and measured against the performance goals. |

All 9 entries in this document are `planned` at Phase 3; `Implementation
status:` is `not implemented` until Phase 11.

## Dependencies

`prim_endian` has **no dependency edge to any sibling MojoAkku library**. It is a
leaf in the dependency graph: it depends only on the Mojo standard library.

| Library | Edge | Justification |
| --- | --- | --- |
| (none) | — | Every signature is built from the Mojo standard library (`Scalar`, `DType`, `Span`, `MutSpan`, `UInt8`, `String`, `Some[Writer]`). No signature mentions a stream, socket, file, container or other sibling concept, so no sibling edge can be technically justified. |

- **Why a leaf.** `prim_endian` needs only `std.bit.byte_swap` and
  `std.sys.is_little_endian()`/`is_big_endian()`. Adding a sibling edge would
  create coupling without a technical reason, which the dependency rules forbid.
- **No physical nesting.** `akku/prim_endian/` is a flat sibling under `akku/`.
- **Direction of future edges.** Later protocol and serialisation libraries
  (`net_*`, `proto_*`, `serialize_*`, `format_*`) point *to* `prim_endian`,
  never the reverse.

## Overview

`akku/prim_endian` is a pure, in-process, deterministic library with **three
layers**, each independently usable:

1. **Order vocabulary — `EndianOrder`.** A value type with the two concrete
   orders `LITTLE` and `BIG` plus the compile-time alias `NATIVE`, which resolves
   at compile time to the host order. Network byte order is documented as
   `BIG`; there is no separate `NETWORK` value.
2. **Value conversion — `host_order`, `swap_bytes`, `to_order`, `from_order`.**
   `host_order()` reports the target's order; `swap_bytes` is the raw reversal
   primitive; `to_order`/`from_order` reinterpret an integer between the host
   order and a named order (a no-op when they already match).
3. **Buffer layer — `to_bytes_into`, `from_bytes`.** Write an integer's bytes
   into a caller-owned `MutSpan[UInt8]`, or read an integer from a borrowed
   `Span[UInt8]`, in an explicit order, with a length check that raises a typed
   error.

Cross-cutting shape:

- **One typed error** (`EndianError`) with a small, **closed** `EndianErrorKind`
  discriminant (`BAD_LENGTH`, `RANGE`, `OTHER`) — no OS errno, no sentinel, no
  panic-as-error.
- **One order value** (`EndianOrder`) reused by every conversion and buffer call.
- **Explicit order**, never global and never hidden; `NATIVE` is the only
  host-dependent value and is resolved at compile time.
- **Value semantics**: `EndianOrder`, `EndianErrorKind`, `EndianError` are value
  types with Mojo lifecycle conformance; no hidden global state.
- **Total where it can be total.** Value conversions cannot fail; only the
  buffer layer can, and then only for a wrong length. A 1-byte value is already
  order-independent, so `to_order`/`from_order` treat it as a no-op rather than
  an error.

Every reference language has byte-order handling, so the value of this library
is not "another endian API". It is a *predictable, consistent and easy-to-read*
surface for a low-vision user. The research shows all references converge on the
same three orders (`big`/`little`/`native`), on byte-swap as the primitive, and
on "big-endian is network order"; they **diverge** on how order is expressed
(C macro names, Go/Rust order values, Java mutable buffer state, Python
strings, JS booleans, Elixir syntax modifiers). `prim_endian` picks one model
and justifies each pick below.

## Goals

- **G1 — Fill exactly the gap `prim_bit` left:** a named byte-order vocabulary,
  host-order detection, value-level order conversion and a length-checked buffer
  layer. Do not reimplement `std.bit.byte_swap`.
- **G2 — One predictable convention set** a low-vision user can memorise once:
  `LITTLE`/`BIG`/`NATIVE`; order always explicit; one byte-layout contract per
  order; `snake_case` functions and `CamelCase` types.
- **G3 — No magic values.** A bad input length is a typed `BAD_LENGTH` error; a
  byte width the swap primitive cannot handle is `RANGE`; there are no error
  sentinels and no `-1`-style returns.
- **G4 — Value semantics and no hidden global state.** Everything is a value
  type; order is a parameter, never a package-global switch.
- **G5 — Implementable in pure Mojo**, no Python/FFI dependency, deterministic
  and fully testable with `mojo run`.

## Non-Goals

Decisions deliberately **not** copied from the reference languages (from the
`§11 Decisions NOT to copy` sections of the research files). Each names the
reference and why it does not fit Mojo. Items that are concrete, Mojo-feasible
API candidates are mirrored in `_dev/TODO.md` and referenced below.

- **C's four overlapping conversion families** (`htonl`/`htons`, `htobe*`/
  `le*toh`, `bswap_*`) with different width coverage — `c.md` §11. A single
  generic API over every integral width replaces them; Boost rejects the Linux
  macro names for exactly this reason.
- **Carrying byte order in a plain untagged integer** — `c.md` §11,
  `cpp.md` §11. It silently breaks when an unconverted field is used later;
  `prim_endian` converts eagerly and returns an ordinary integer, and a tagged
  wrapper type is backlog, not release 1 (`_dev/TODO.md`).
- **`union` type-punning to inspect bytes** — `c.md` §11. Not possible portably
  and not wanted; Mojo's typed value model is used instead.
- **No 64-bit and no little-endian "network" family** — `c.md` §11. The generic
  API covers every width; network order is documented as `BIG`.
- **A "wrong byte order" error** — `c.md` §11. Order is a caller assertion that
  no value-level API can verify, so there is no such error; only a bad buffer
  *length* is detectable and raises.
- **Boost's three parallel user-facing concepts** (conversion / buffer /
  arithmetic) — `cpp.md` §11. One order value plus conversion functions is
  simpler.
- **Implicit conversion in arithmetic types** — `cpp.md` §11. Conversion is
  explicit; nothing converts behind the caller's back.
- **`bit_cast`'s unspecified padding bits / UB-adjacent reinterpretation** —
  `cpp.md` §11. The byte contract is fully defined per order.
- **Silently removing overloads for floats/bools** — `cpp.md` §11. Carriers are
  constrained to integral `DType`s at compile time; float carriers are backlog
  (`_dev/TODO.md`).
- **Runtime `conditional_reverse` with runtime branch in hot loops** —
  `cpp.md` §11. Order is a value and the target check is compile-time where
  possible; `NATIVE` resolves at compile time.
- **Compiler-intrinsic fallback macros leaking build config** — `cpp.md` §11.
  `std.bit.byte_swap` is the portable primitive.
- **Go's reflection-based `Read`/`Write(any)` serializer** — `go.md` §11. That
  is a serialiser, not an endianness primitive, and is out of scope.
- **Panic-on-short-buffer** — `go.md` §11, `js-ts.md` §11. The buffer layer
  **raises** `BAD_LENGTH`; it never panics.
- **Interface dispatch for a compile-time-known order** — `go.md` §11. The
  order is a value; no trait/interface is needed to select it.
- **Build-tag-embedded `NativeEndian`** — `go.md` §11. The *idea* (native order
  is known at compile time) transfers via `std.sys`; the Go toolchain mechanism
  does not.
- **Rust's eleven methods replicated across ten integer types** — `rust.md`
  §11. One generic function over `Scalar[dtype]` avoids the matrix.
- **Rust's `to_ne_bytes`/`from_ne_bytes` as the lead API** — `rust.md` §11.
  `NATIVE` is available but documented as the non-portable path; `BIG`/`LITTLE`
  are the recommended orders.
- **A third-party `ByteOrder` trait / extension-trait layering** — `rust.md`
  §11. Not needed; order is a value passed in.
- **Cfg-macro target detection as a mechanism** — `rust.md` §11. Mojo's
  `comptime` queries are used instead.
- **Python's stringly-typed `byteorder`** — `python.md` §11. A typed value makes
  an invalid order unrepresentable.
- **Two spellings of the same thing** (`'big'` vs `>`) — `python.md` §11. One
  vocabulary only.
- **An implicit native default in the buffer API** — `python.md` §11. Every
  buffer call takes an explicit order; there is no default.
- **Runtime-parsed format strings** — `python.md` §11. The type carries the
  width; nothing is re-parsed per call.
- **JS's boolean `littleEndian` flag** — `js-ts.md` §11. Use a named typed
  order.
- **Order encoded in the method name** (`readUInt16BE`/`LE`) — `js-ts.md` §11.
  That is a width × signedness × order explosion.
- **Platform-native typed arrays as an interchange primitive** — `js-ts.md`
  §11. Orders are always explicit.
- **`slice()` view-vs-copy inconsistencies** — `js-ts.md` §11. There are no
  sub-view types here; buffers are plain spans owned by the caller.
- **Validation only at swap time** (`ERR_INVALID_BUFFER_SIZE`) — `js-ts.md`
  §11. The type's byte width is derivable from the type and the length is
  checked at the call.
- **A hidden mutable byte order on a buffer** — `java.md` §11. Order is an
  explicit argument per call; there is no buffer object that carries it.
- **Silently resetting order on `slice()`/`duplicate()`** — `java.md` §11. There
  are no derived views.
- **Coupling conversion to I/O and checked exceptions** — `java.md` §11.
  Conversion is pure and raises only on a bad buffer length.
- **`Unsafe`/intrinsic host detection** — `java.md` §11. `std.sys` compile-time
  predicates are the stable mechanism.
- **Emulating unsigned widths with widening-to-signed variants** — `java.md`
  §11. Mojo has explicit unsigned `DType`s.
- **Elixir's hyphen-separated modifier soup** — `elixir.md` §11. Named
  functions and a value type read better for a low-vision user.
- **`native` silently depending on the host** — `elixir.md` §11. `NATIVE` is
  explicit and documented as non-portable.
- **Minimal-length output (`encode_unsigned`)** — `elixir.md` §11. The byte
  width is fixed by the carrier's `DType`.
- **Silent match failure on a short buffer** — `elixir.md` §11. A wrong length
  raises `BAD_LENGTH`.
- **Signedness that affects only matching / order-independent modifier lists**
  — `elixir.md` §11. The API carries one order and one signed carrier type.

## Reference APIs

The decision inputs, taken from the Phase-1 research files. The names in the
right column are the reference APIs cited in the justifications below.

| Area | Reference API(s) | Source |
| --- | --- | --- |
| Order vocabulary (little/big/native) | C++ `std::endian`; C23 `__STDC_ENDIAN_LITTLE__`/`BIG`/`NATIVE`; Go `ByteOrder`/`NativeEndian`; Rust `NativeEndian` alias; Java `ByteOrder`/`nativeOrder()`; Elixir `big`/`little`/`native` | `cpp.md` §1,§7; `c.md` §1; `go.md` §1,§7; `rust.md` §7; `java.md` §1,§9; `elixir.md` §1 |
| Host-order detection (compile-time) | C++ `std::endian::native`; C `__BYTE_ORDER__` / C23 native macro; Rust `cfg(target_endian)`; Go build-tag `NativeEndian`; Mojo `std.sys.is_little_endian()`/`is_big_endian()` | `cpp.md` §9; `c.md` §9; `rust.md` §9; `go.md` §9; `mojov1/stdlib/sys` |
| Host-order detection (runtime) | Java `ByteOrder.nativeOrder()` (`Unsafe.isBigEndian()`); Python `sys.byteorder`; JS `os.endianness()`; Elixir `system_info(endian)` | `java.md` §9; `python.md` §9; `js-ts.md` §9; `elixir.md` §9 |
| Byte-swap primitive | C `bswap_16/32/64`; C++ `std::byteswap`; Go `bits.ReverseBytes*`; Java `Short/Integer/Long.reverseBytes`; Rust `swap_bytes`; JS `Buffer.swap16/32/64`; Zig `@byteSwap`; Mojo `std.bit.byte_swap` | `c.md` §1; `cpp.md` §1; `go.md` §1; `java.md` §1; `rust.md` §1; `js-ts.md` §1; `rust.md` cross-ref; `mojov1/stdlib/bit` |
| Value conversion host ↔ named order | C `htobe*`/`htole*`/`be*toh`/`le*toh`; Rust `to_be`/`to_le`/`from_be`/`from_le`; Go `ByteOrder.Uint*/PutUint*`; Java `reverseBytes` + `nativeOrder` | `c.md` §3; `rust.md` §3; `go.md` §3; `java.md` §3 |
| Network order = big-endian | C `hton*`/`ntoh*`; Rust `to_be_bytes` "(network) order"; Elixir default `big`; Java `BIG_ENDIAN` "indicates network byte order" | `c.md` §7; `rust.md` §3; `elixir.md` §7; `java.md` §7 |
| Buffer write/read with explicit order | Go `PutUint*`/`Uint*`; Rust `to_*_bytes`/`from_*_bytes`; C++ Boost `endian_store`/`endian_load<T,N,Order>`; Java `ByteBuffer.put*/get*`; Python `int.to_bytes`/`from_bytes` and `struct.pack_into`; JS `DataView.set*/get*` | `go.md` §3; `rust.md` §3; `cpp.md` §3; `java.md` §3; `python.md` §3; `js-ts.md` §3 |
| Length-checked fallible buffer form | Go `errBufferTooSmall`; Rust `TryInto<[u8; N]>`; C++ `endian_load<T,N,Order>`; Python `struct.error`/`OverflowError`; Java `BufferUnderflowException` | `go.md` §4; `rust.md` §4; `cpp.md` §3; `python.md` §4; `java.md` §4 |
| Typed error + closed kind | Rust `ErrorKind`; Go sentinels + `OpError`; Java checked `IOException`; and MojoAkku `prim_bit`'s `BitError`/`BitErrorKind` | `rust.md` §4; `go.md` §4; `java.md` §4; `akku/prim_bit/_dev/DESIGN.md` |
| Mojo language anchors | `Scalar[dtype]`/`DType`; `comptime`/`comptime if`; typed `raises`; `Span`/`MutSpan`; `Some[Writer]`; `std.bit.byte_swap`; `std.sys` target queries | `mojov1/concurrency/vectorization-and-simd`; `mojov1/keywords/comptime`; `mojov1/errors/error-model`; `mojov1/types/collections`; `mojov1/stdlib/bit`; `mojov1/stdlib/sys` |

## Public API

Every entry below is listed here with its one-line meaning and is fully specified
in the per-entry blocks. Names are stable: Phase 5 documents them and Phase 7
stubs them, in this order (one file per entry).

1. `EndianOrder` — the order of a conversion: `LITTLE`, `BIG`, and the
   compile-time alias `NATIVE` (resolved to the host order).
2. `EndianErrorKind` — closed discriminant for `EndianError`: `BAD_LENGTH`,
   `RANGE`, `OTHER`.
3. `EndianError` — the one typed error: `kind: EndianErrorKind`, `op: String`,
   `detail: String`.
4. `host_order()` — the host's order, resolved at compile time; returns `LITTLE`
   or `BIG` (never a third value).
5. `swap_bytes` — reverse an integer's byte order (even byte width; wraps
   `std.bit.byte_swap`).
6. `to_order` — reinterpret an integer from the host order into a named order
   (no-op or swap).
7. `from_order` — the inverse of `to_order` (interpret a value that is in a named
   order as a host-order value).
8. `to_bytes_into` — write an integer's bytes into a caller-owned
   `MutSpan[UInt8]` in a given order; length-checked.
9. `from_bytes` — read an integer from a borrowed `Span[UInt8]` in a given
   order; length-checked.

## Error Surface

One error type, `EndianError`, with a closed three-value `EndianErrorKind`.
Which API raises what:

| API | Raises | Kinds |
| --- | --- | --- |
| `EndianOrder` | none | — |
| `EndianErrorKind` | none | — |
| `EndianError` (construction) | none | — |
| `host_order` | none | — |
| `swap_bytes` | `EndianError` | `RANGE` (the carrier's byte width is odd — a 1-byte integer cannot be byte-swapped) |
| `to_order` | none | — |
| `from_order` | none | — |
| `to_bytes_into` | `EndianError` | `BAD_LENGTH` (`dst.len` does not equal the carrier's byte width) |
| `from_bytes` | `EndianError` | `BAD_LENGTH` (`src.len` does not equal the carrier's byte width) |

Recoverability: every `EndianError` is a recoverable **data** error — the caller
can pass a correctly sized buffer, or (for `RANGE`) choose the high-level
`to_order`/`from_order`, which are total. No operation is fatal and none aborts.
`OTHER` is reserved for any other condition and carries its context in the
opaque `detail` string; no release-1 operation raises it.

## Conventions

- **One order vocabulary.** `LITTLE`, `BIG`, and the compile-time alias
  `NATIVE`. Network byte order is **big-endian** and is documented as `BIG`;
  there is no separate `NETWORK` value (`c.md` §7, `rust.md` §3, `java.md` §7).
- **Order is always explicit.** Every conversion and buffer call takes an
  `EndianOrder`; there is no default, no global switch and no hidden buffer
  state (`java.md` §11, `go.md` §11).
- **`NATIVE` resolves at compile time.** It is an alias equal to `LITTLE` or
  `BIG` depending on the build target; `host_order()` returns it. Code that
  stores or compares an order sees a concrete two-value result
  (`cpp.md` §9, `java.md` §9).
- **Byte layout is per order.** For `BIG`, byte index 0 is the most significant
  byte; for `LITTLE`, byte index 0 is the least significant byte. `NATIVE`
  follows the host order and is the non-portable path.
- **Byte width is the carrier's own width.** For `Scalar[dtype]` it is
  `size_of[Scalar[dtype]]()` bytes; it is never inferred from a length argument.
- **Names are `snake_case`** for functions and methods, `CamelCase` for types,
  `SCREAMING_CASE` for `comptime` constants — the Mojo style guide.
- **No sentinels and no hidden global state.** Absence is not a concept in this
  library; every failure is a typed error, and nothing mutates process state.
- **Value conversions are total.** `to_order`/`from_order` can never fail; only
  the buffer layer raises, and only for a wrong length.

## Ownership and Lifecycle

- **All types are value types.** `EndianOrder` and `EndianErrorKind` conform to
  `Equatable, ImplicitlyCopyable, Deinitable, Writable`; `EndianError` conforms
  to `Copyable, Deinitable, Writable`.
- **`EndianError` is `Copyable` but not `ImplicitlyCopyable`**, so a re-raise
  must transfer with `raise e^` — the `prim_bit`/`io_core` convention.
- **The caller owns every buffer.** `to_bytes_into` borrows a `MutSpan[UInt8]`
  and writes into it; `from_bytes` borrows a `Span[UInt8]` and never copies or
  retains it. Both check the span length against the carrier's byte width before
  reading or writing.
- **Nothing is allocated by the library.** `to_bytes_into` writes in place;
  `from_bytes` returns a `Scalar[dtype]` by value.
- **ASAP destruction.** No library type holds a resource with a destructor side
  effect; everything is freed at its last use, and there is no `close`.

## Open Questions

None block this design. Two points are deliberately settled and recorded so a
later phase does not reopen them:

- *How is host order reported?* → `host_order() -> EndianOrder`, resolved at
  compile time over `std.sys.is_little_endian()` / `is_big_endian()`
  (`mojov1/stdlib/sys`). There is no runtime query and no third "mixed" value;
  mixed-endian hosts are not a supported target and, if ever needed, are a
  backlog classifier (`_dev/TODO.md`).
- *Is there a `NETWORK` order?* → No. Network order is big-endian and is
  documented as `EndianOrder.BIG`, the C/Rust/Elixir consensus (`c.md` §7,
  `rust.md` §3, `elixir.md` §7). A `to_network`/`to_host` alias pair stays
  backlog (`_dev/TODO.md`).

---

### `EndianOrder`

Status: planned

Signature:

```mojo
struct EndianOrder(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    def __eq__(self, other: Self) -> Bool

    comptime LITTLE = EndianOrder(0)
    comptime BIG    = EndianOrder(1)
    comptime NATIVE = EndianOrder.LITTLE if is_little_endian() else EndianOrder.BIG

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** passed explicitly to `to_order`/`from_order`
  and `to_bytes_into`/`from_bytes`; also read back for inspection. The two
  concrete `comptime` members `LITTLE` and `BIG` are the complete set; `NATIVE`
  is a compile-time **alias** equal to one of them, and `_id` is hidden.
- **Return / meaning:** which byte order a conversion targets.
  - `LITTLE` — byte 0 is the least significant byte.
  - `BIG` — byte 0 is the most significant byte. **Network byte order is
    big-endian** and is documented as `BIG` (`c.md` §7, `rust.md` §3,
    `elixir.md` §7).
  - `NATIVE` — an alias resolved at compile time to `LITTLE` or `BIG` for the
    build target (`cpp.md` §9, `java.md` §9). It is the non-portable path and
    should not be used for wire data (`rust.md` §11).
- **Value, not state.** Order is a value passed in; there is no global switch
  (`go.md` §11) and no buffer object that carries a mutable order (`java.md` §11).
- **`write_to`** prints the symbolic name (`LITTLE`/`BIG`), never the numeric
  `_id`.

Errors:

none — it is a value, not an operation.

Tests:

- `test_endian_order_distinct` — `LITTLE` and `BIG` differ.
- `test_endian_order_eq` — `==` compares `_id` only.
- `test_endian_order_writable` — `write_to` prints `LITTLE`/`BIG`.
- `test_endian_order_native_is_host` — `NATIVE` equals `host_order()`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses a named EndianOrder because C++ std::endian (cpp.md §1), Go
ByteOrder/NativeEndian (go.md §1) and Elixir big/little/native (elixir.md §1)
all make the order a named value, and resolving NATIVE at compile time mirrors
Java ByteOrder.nativeOrder() (java.md §9) and Rust target_endian (rust.md §9).
MojoAkku uses no JS-style boolean littleEndian flag because getUint16(0, true)
is unreadable and easy to invert silently (js-ts.md §11), and no Python-style
free string because a typed value makes an invalid order unrepresentable
(python.md §11).`

---

### `EndianErrorKind`

Status: planned

Signature:

```mojo
struct EndianErrorKind(Equatable, ImplicitlyCopyable, Deinitable, Writable):
    var _id: UInt8

    @doc_hidden
    def __init__(out self, id: UInt8)

    def __eq__(self, other: Self) -> Bool

    comptime BAD_LENGTH = EndianErrorKind(0)
    comptime RANGE      = EndianErrorKind(1)
    comptime OTHER      = EndianErrorKind(2)

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** read from `EndianError.kind`; never passed by a
  caller to a conversion. The type is **opaque**: the three `comptime` members
  are the complete public set; `_id` and its `@doc_hidden` initializer are
  implementation details (Mojo has no access control,
  `mojov1/decorators/doc-hidden`). `__eq__` is an intentional override
  mirroring `BitErrorKind`/`IoErrorKind`.
- **Return / meaning:** the machine-testable reason an endian operation failed.
  - `BAD_LENGTH` — a buffer's length did not equal the carrier's byte width
    (the fixed-size-array guarantee Rust gets from `[u8; N]` is replaced by a
    checked error because Mojo spans are runtime-sized; `rust.md` §4, `go.md` §4).
  - `RANGE` — a width is outside what the operation can address; here only
    `swap_bytes` on an odd byte width (a 1-byte integer), the analogue of
    `prim_bit`'s `RANGE` for an unaddressable span (`java.md` §4).
  - `OTHER` — any other condition; the opaque `EndianError.detail` holds it.
- **`write_to`** prints the symbolic name, never the number.

Errors:

none — it is a discriminant, not an operation.

Tests:

- `test_error_kind_distinct_ids` — each of the three `comptime` members has a
  distinct `_id`.
- `test_error_kind_eq` — `==` compares `_id` only.
- `test_error_kind_writable` — `write_to` prints the symbolic name, never the
  number.

Implementation status:

not implemented

Rationale:

`MojoAkku uses a closed three-value EndianErrorKind because Rust's ErrorKind
shows a small closed set is enough (rust.md §4) and prim_bit already taught the
low-vision user one kind+op+detail shape (akku/prim_bit/_dev/DESIGN.md); a
numeric errno or a sentinel value is rejected.`

---

### `EndianError`

Status: planned

Signature:

```mojo
@fieldwise_init
struct EndianError(Copyable, Deinitable, Writable):
    var kind: EndianErrorKind
    var op: String
    var detail: String

    def write_to(self, mut writer: Some[Writer])
```

Semantics:

- **Parameters / preconditions:** constructed by the library on failure; read
  in an `except` block (or `try`/`except`) after a buffer call. Fields:
  `kind` (see `EndianErrorKind`), `op` (a short operation name, e.g.
  `"to_bytes_into"`, `"from_bytes"`, `"swap_bytes"`), and `detail` (opaque
  human-readable context; must not be parsed). The `op` list is illustrative,
  not a closed enum.
- **Return / meaning:** raised, never returned. Every condition is recoverable:
  pass a correctly sized buffer (`BAD_LENGTH`) or use the total
  `to_order`/`from_order` when no swap is possible (`RANGE`).
- **`write_to`** prints a readable `EndianError(<kind>, op=..., detail=...)`
  message. Because `EndianError` is `Copyable` but not `ImplicitlyCopyable`, a
  re-raise transfers with `raise e^`.

Errors:

none — `EndianError` *is* the error; constructing it cannot fail.

Tests:

- `test_error_writable` — `print(e)` yields kind + op + detail.
- `test_error_reraise_transfer` — a caught error re-raises with `raise e^`.
- `test_error_op_names_call` — `op` names the failing call.

Implementation status:

not implemented

Rationale:

`MojoAkku uses one typed error EndianError because Rust and Java both funnel all
byte-order/stream failures through one error type (rust.md §4, java.md §4) and
prim_bit established the kind+op+detail shape (akku/prim_bit/_dev/DESIGN.md);
a per-operation exception hierarchy or a bare panic is rejected as noise for a
low-vision user (java.md §11, go.md §11).`

---

### `host_order`

Status: planned

Signature:

```mojo
def host_order() -> EndianOrder
```

Semantics:

- **Parameters / preconditions:** none. The result is fixed by the build target
  at compile time; `std.sys.is_little_endian()` / `is_big_endian()` are
  compile-time predicates (`mojov1/stdlib/sys`).
- **Return / meaning:** the host's byte order as an `EndianOrder` — `LITTLE` on
  a little-endian target, `BIG` on a big-endian target. It never returns a third
  value: mixed-endian hosts are not a supported target (the C `PDP`/C++
  mixed-endian case, `c.md` §9, `cpp.md` §7, is not represented).
- **Relation to `NATIVE`:** `host_order()` equals `EndianOrder.NATIVE`; both
  resolve at compile time to the same concrete value.
- **No runtime query:** there is no process-global switch and no per-run probe
  (`cpp.md` §9, P0463R1: "The compiler knows the answer!").

Errors:

none — it is a total query.

Tests:

- `test_host_order_is_little_or_big` — the result is `LITTLE` or `BIG`.
- `test_host_order_equals_native` — `host_order() == EndianOrder.NATIVE`.
- `test_host_order_matches_std_sys` — agrees with `is_little_endian()` /
  `is_big_endian()` on the build target.

Implementation status:

not implemented

Rationale:

`MojoAkku uses host_order() resolved at compile time because C++
std::endian::native (cpp.md §9), Rust target_endian (rust.md §9) and Go
NativeEndian (go.md §9) all make host order a compile-time property, and Mojo
target queries are comptime (mojov1/stdlib/sys); Java can only query at runtime
via an intrinsic (java.md §9), which is strictly weaker, and the Elixir
system_info(endian) runtime query (elixir.md §9) is therefore not copied.`

---

### `swap_bytes`

Status: planned

Signature:

```mojo
def swap_bytes[dtype: DType](x: Scalar[dtype]) raises EndianError -> Scalar[dtype]
    where dtype.is_integral()
```

Semantics:

- **Parameters / preconditions:** `x` is an integral `Scalar[dtype]` carrier
  (signed or unsigned). The carrier's byte width is `size_of[Scalar[dtype]]()`;
  it must be **even** (2, 4, 8, 16, … bytes), because `std.bit.byte_swap`
  byte-swaps "an integer with an even number of bytes" (`mojov1/stdlib/bit`). A
  1-byte carrier (e.g. `UInt8`, `Int8`) has an odd width and raises `RANGE`.
- **Return / meaning:** a new value of the same type with its byte order
  reversed — bit-for-bit byte reversal, not an order conversion. It is the
  small, testable core the order conversions are defined on (`rust.md` §10:
  `swap_bytes` is the conceptual base operation).
- **1-byte values:** already order-independent. `swap_bytes` surfaces the
  primitive's even-width contract as `RANGE`; the high-level
  `to_order`/`from_order` are total and treat a 1-byte carrier as a no-op.
- **Not a direction.** `swap_bytes` has no order argument; it always reverses.
  Direction is expressed by `to_order`/`from_order` (`cpp.md` §10).

Errors:

- `RANGE` — the carrier's byte width is odd (a 1-byte integer).

Tests:

- `test_swap_bytes_reverses_u16` / `_u32` / `_u64` — known bit patterns.
- `test_swap_bytes_involution` — `swap_bytes(swap_bytes(x)) == x`.
- `test_swap_bytes_signed_carrier` — `Int16`/`Int32` reverse the same bits.
- `test_swap_bytes_one_byte_raises_range` — `UInt8`/`Int8` raise `RANGE`.
- `test_swap_bytes_explicit_dtype_parameter` — the `[dtype]` parameter form.

Implementation status:

not implemented

Rationale:

`MojoAkku uses swap_bytes as the explicit raw reversal because Rust swap_bytes
(rust.md §3), C bswap_32 (c.md §1), C++ std::byteswap (cpp.md §3), Go
bits.ReverseBytes32 (go.md §3), Java Integer.reverseBytes (java.md §3) and Zig
@byteSwap (rust.md cross-ref) all expose a bare reversal, and Mojo already ships
it as std.bit.byte_swap (mojov1/stdlib/bit); primitive requires an even byte
count, so MojoAkku surfaces an odd width as RANGE instead of silently accepting
it. MojoAkku does not copy the Node/Java width-in-the-name explosion
(readUInt16BE/readUInt16LE, swap16/swap32/swap64) because one generic function
over Scalar[dtype] covers every width (js-ts.md §11).`

---

### `to_order`

Status: planned

Signature:

```mojo
def to_order[dtype: DType](x: Scalar[dtype], order: EndianOrder) -> Scalar[dtype]
    where dtype.is_integral()
```

Semantics:

- **Parameters / preconditions:** `x` is an integral `Scalar[dtype]` **in the
  host order** (an ordinary Mojo integer is native-endian in memory); `order` is
  the target order. There is no precondition failure and no default — `order`
  must always be named.
- **Return / meaning:** `x` reinterpreted into `order`.
  - If `order == host_order()` (including `NATIVE`), it is a **no-op** and `x`
    is returned unchanged.
  - Otherwise the bytes are swapped, i.e. the result equals
    `swap_bytes(x)` for an even-width carrier.
  - A 1-byte carrier is a no-op for every order (there is only one byte).
    This is why `to_order` itself never raises even though `swap_bytes` does
    (`cpp.md` §12: only the buffer read's length can fail).
- **Semantics are Rust's `to_be`/`to_le`** (`rust.md` §3): "converts self to big
  endian from the target's endianness; on big endian this is a no-op, on little
  endian the bytes are swapped". `to_order(x, EndianOrder.BIG)` is the
  `htobe*` direction of C (`c.md` §3).
- **Network order:** `to_order(x, EndianOrder.BIG)` is the network-order
  conversion; no separate function name exists (`c.md` §7).
- **`NATIVE`** makes `to_order(x, EndianOrder.NATIVE)` the identity, which is
  the documented non-portable path (`rust.md` §11).

Errors:

none — the conversion is total for every integral carrier. A matching target is
a compile-time-known no-op where the order is a `comptime` value.

Tests:

- `test_to_order_big_on_little` / `_little_on_big` — swap direction per target.
- `test_to_order_noop_when_matches_host` — identity when order == host.
- `test_to_order_native_is_identity` — `NATIVE` never swaps.
- `test_to_order_one_byte_noop` — `UInt8`/`Int8` are identity, no error.
- `test_to_order_per_width` — 2/4/8-byte carriers.
- `test_to_from_order_roundtrip` — `from_order(to_order(x, o), o) == x`.

Implementation status:

not implemented

Rationale:

`MojoAkku uses to_order(x, order) because Rust to_be/to_le (rust.md §3) and C
htobe*/htole* (c.md §3) name the host→named direction, and Go's ByteOrder value
(go.md §7) shows the order belongs in a value rather than in the function name;
it is total because fixed-width conversion cannot fail (cpp.md §4, rust.md §4)
and a low-vision user should not handle an error that cannot happen. Network
order is not given its own function because it is simply BIG (c.md §7, java.md
§7).`

---

### `from_order`

Status: planned

Signature:

```mojo
def from_order[dtype: DType](x: Scalar[dtype], order: EndianOrder) -> Scalar[dtype]
    where dtype.is_integral()
```

Semantics:

- **Parameters / preconditions:** `x` is an integral `Scalar[dtype]` whose
  **bytes are in `order`** (e.g. a value assembled from wire bytes); `order` is
  the source order. No default; always explicit.
- **Return / meaning:** `x` reinterpreted from `order` into the host order.
  - If `order == host_order()` (including `NATIVE`), it is a no-op.
  - Otherwise the bytes are swapped.
  - A 1-byte carrier is a no-op for every order.
- **Relationship to `to_order`.** Byte reversal is an involution, so for `BIG`
  and `LITTLE` the two functions compute the same result; they are kept as two
  names because the caller's intent differs and the name documents it at the
  call site: `to_order` says "make a value for the wire", `from_order` says
  "interpret wire bytes". This is exactly Rust's `to_be`/`from_be` split
  (`rust.md` §3) and C's `htobe*` vs `be*toh` split (`c.md` §3).
- **Semantics are Rust's `from_be`/`from_le`** (`rust.md` §3): "converts an
  integer from big endian to the target's endianness; on big endian this is a
  no-op, on little endian the bytes are swapped".

Errors:

none — total for every integral carrier, like `to_order`.

Tests:

- `test_from_order_big_on_little` / `_little_on_big` — inverse direction.
- `test_from_order_noop_when_matches_host` — identity when order == host.
- `test_from_order_native_is_identity` — `NATIVE` never swaps.
- `test_from_order_one_byte_noop` — identity, no error.
- `test_from_to_order_roundtrip` — `to_order(from_order(x, o), o) == x`.
- `test_from_order_matches_swap_bytes` — equals `swap_bytes(x)` off-host.

Implementation status:

not implemented

Rationale:

`MojoAkku uses from_order(x, order) because C's be*toh/le*toh (c.md §3) and
Rust from_be/from_le (rust.md §3) name the named→host direction, and keeping the
two directions distinct is what makes a call site self-describing for a
low-vision user; even though byte reversal makes to_order and from_order compute
the same result, a single ambiguous name was rejected because the intent
("prepare for the wire" vs "interpret wire bytes") would be lost.`

---

### `to_bytes_into`

Status: planned

Signature:

```mojo
def to_bytes_into[dtype: DType](x: Scalar[dtype], dst: MutSpan[UInt8], order: EndianOrder)
    raises EndianError
    where dtype.is_integral()
```

Semantics:

- **Parameters / preconditions:** `x` is an integral `Scalar[dtype]` in host
  order; `dst` is a caller-owned writable byte span; `order` is the order the
  bytes should be written in. `dst.len` **must equal** the carrier's byte width
  `size_of[Scalar[dtype]]()` (1, 2, 4, 8, 16, …); any other length raises
  `BAD_LENGTH` before anything is written. The whole span is written; there is
  no offset and no partial write.
- **Return / meaning:** nothing is returned; `dst` is mutated in place. The
  byte layout is defined by `order`:
  - `BIG` — `dst[0]` is the most significant byte, `dst[width-1]` the least.
  - `LITTLE` — `dst[0]` is the least significant byte, `dst[width-1]` the most.
  - `NATIVE` — the host layout; the non-portable path.
- **Ownership:** the caller owns `dst`; the function borrows it mutably and
  transfers no ownership. Nothing is allocated.
- **Atomicity on error:** the length is checked first, so a `BAD_LENGTH` call
  leaves `dst` untouched.
- **Equivalent to** `to_order(x, order)` followed by a memcpy of its bytes;
  `from_bytes` is its exact inverse.

Errors:

- `BAD_LENGTH` — `dst.len` does not equal the carrier's byte width.

Tests:

- `test_to_bytes_into_big_layout` / `_little_layout` — known byte patterns.
- `test_to_bytes_into_exact_length_required` — wrong length raises `BAD_LENGTH`.
- `test_to_bytes_into_native_matches_host` — `NATIVE` uses the host layout.
- `test_to_bytes_into_per_width` — 2/4/8-byte carriers.
- `test_to_bytes_into_error_writes_nothing` — `dst` unchanged after `BAD_LENGTH`.
- `test_to_bytes_from_bytes_roundtrip` — per order and width.

Implementation status:

not implemented

Rationale:

`MojoAkku uses to_bytes_into(x, dst, order) because Go's ByteOrder.PutUint*
(go.md §3), Rust's to_*_bytes (rust.md §3), C++ Boost endian_store
(cpp.md §3), Python struct.pack_into (python.md §3) and JS DataView.set*
(js-ts.md §3) all write a value's bytes into caller storage with an explicit
order; it takes MutSpan[UInt8] because Python's pack_into pattern shows the
no-allocation in-place form (python.md §5) and Mojo spans are the typed
equivalent (mojov1/types/collections). It raises BAD_LENGTH instead of Go's
panic-on-short-slice (go.md §11) or Rust's compile-time [u8; N] (rust.md §4),
because a Mojo span length is a runtime value; the fixed-size value-returning
byte-array form remains backlog (_dev/TODO.md).`

---

### `from_bytes`

Status: planned

Signature:

```mojo
def from_bytes[dtype: DType](src: Span[UInt8], order: EndianOrder)
    raises EndianError -> Scalar[dtype]
    where dtype.is_integral()
```

Semantics:

- **Parameters / preconditions:** `src` is a borrowed byte span whose bytes are
  in `order`; `order` is the source order. `src.len` **must equal** the
  carrier's byte width `size_of[Scalar[dtype]]()`; any other length raises
  `BAD_LENGTH`. `from_bytes` is the exact inverse of `to_bytes_into`.
- **Return / meaning:** the integer assembled from `src` and returned in the
  host order. Byte layout is read per `order`:
  - `BIG` — `src[0]` is the most significant byte.
  - `LITTLE` — `src[0]` is the least significant byte.
  - `NATIVE` — the host layout; the non-portable path.
- **Ownership:** the caller owns `src`; the function borrows it and never copies
  or retains it. The returned `Scalar[dtype]` is owned by the caller.
- **No offset and no streaming:** exactly one whole carrier is read from the
  start of the span. Stream/reader helpers are backlog (`_dev/TODO.md`).

Errors:

- `BAD_LENGTH` — `src.len` does not equal the carrier's byte width.

Tests:

- `test_from_bytes_big_layout` / `_little_layout` — known byte patterns.
- `test_from_bytes_exact_length_required` — wrong length raises `BAD_LENGTH`.
- `test_from_bytes_native_matches_host` — `NATIVE` reads the host layout.
- `test_from_bytes_per_width` — 2/4/8-byte carriers.
- `test_from_bytes_empty_and_short_raise` — `BAD_LENGTH` for 0/1 short spans.
- `test_from_bytes_matches_from_order` — agrees with `from_order` on a copied
  value.

Implementation status:

not implemented

Rationale:

`MojoAkku uses from_bytes(src, order) because Go's ByteOrder.Uint* (go.md §3),
Rust's from_*_bytes (rust.md §3), C++ Boost endian_load<T,N,Order> (cpp.md §3),
Python int.from_bytes (python.md §3) and JS DataView.get* (js-ts.md §3) all read
an integer from bytes with an explicit order; the length check raises BAD_LENGTH
because Mojo spans are runtime-sized (unlike Rust's [u8; N], rust.md §4) and a
short read must be a typed, recoverable error, never Go's panic (go.md §11) or
C's memcpy-and-combine-by-hand (c.md §5).`
