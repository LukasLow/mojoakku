# net_ip — design record

Design record for `akku/net_ip` — NOT end-user documentation.
End-user docs are the inline `# API-DOCS` blocks materialised in Phase 7.

## Purpose

`akku/net_ip` is the MojoAkku **IP addressing** library: the IPv4 and IPv6
address value type. It parses text to an address, formats an address to text,
classifies it (loopback/private/link-local/multicast/unspecified/…), and
converts between the text, byte and integer representations. It is a pure,
deterministic, in-process value library and a leaf in the dependency graph.

## Status legend

- **shipped** — implemented and tested in this release.
- **deferred** — a researched API candidate consciously left out; it is mirrored
  in `_dev/TODO.md`.
- **rejected** — a decision not wanted or not possible in Mojo; it stays only
  here as a Non-Goal.

## Dependencies

`net_ip` has **no dependency edge to any sibling MojoAkku library** and needs no
socket and no FFI. It is a leaf. Later libraries point *at* it
(`net_socket` → `net_tcp` → `web_http`, `proto_dns`, `web_url`), never the other
way: the address model is the foundation, not a consumer.

- **No FFI.** Address parse/format is integer arithmetic and text work. The
  capability ledger marks `net-sockets` as `have` (libc reachable via `c-ffi`),
  but `net_ip` deliberately does **not** use it: an address type never needs the
  kernel. It only requires `pure-mojo`.
- **No `akku.io_core` dependency in release 1.** Stream adapters that parse from
  a `Reader` are deferred (see `TODO.md`); shipping them would add an edge for
  no functional gain in a value library.
- **No `akku.text_string` dependency in release 1.** IPv6 compression has
  specific rules (RFC 5952) that are easier to implement locally than to express
  through generic text helpers; a text edge would also risk a later cycle when
  `text_string` grows networking-aware helpers.

## Overview

The address is a **value**: two concrete structs behind one family-tagged API.

- `Ipv4Address` wraps a `UInt32` (network order is not implied by the carrier;
  the accessors define it).
- `Ipv6Address` wraps a `UInt128`.
- `IpAddress` is the unifying family-tagged value with a `comptime` family
  discriminant, so "any address" is one type while each family keeps its own
  struct.

All three are `Copyable` + `Movable` value types with structural equality and a
total order. There is no heap allocation in the address itself, no hidden global
state, and no reference semantics.

Parse and format are free functions at the library level (not methods on the
value) so the family can be inferred or chosen explicitly:
`parse` (family-tagged), `parse_ipv4`/`parse_ipv6` (explicit), `try_parse`
(non-throwing), and `format`/`format_into` (textual, RFC 5952 for IPv6).

## Goals

- One predictable address model covering IPv4 and IPv6 with an explicit family.
- Strict, RFC-correct text parsing with a **typed** error that names the reason
  and the position (never a silent `nil` like Go's legacy `net.ParseIP`).
- Allocation-free where it matters: integer/byte accessors and a
  `format_into`/`from_bytes` path beside the convenience `String` path.
- A closed, RFC-named classification predicate set.
- Total ordering and equality so addresses work as keys and sort naturally.

## Non-Goals (decisions NOT copied)

Each is a `MojoAkku rejects … because …` statement. Items that are concrete,
theoretically-possible-in-Mojo API candidates are **also** listed in
`_dev/TODO.md` (marked *deferred* below); the rest are permanent Non-Goals.

- **A host/resolving type on the address.** MojoAkku rejects Java's
  `InetAddress.getByName` (which performs DNS inside the address type) because
  it conflates resolution with parsing and can block. `net_ip` parses *numeric
  literals only* and never touches the network. (Java's late `ofLiteral` fix —
  `java.md` §1 — is the evidence the split is correct.) **Rejected.**
- **`void *` + a separate family parameter.** MojoAkku rejects C's
  `inet_pton(af, src, void *dst)` because the compiler cannot link the buffer
  size to the family — the exact bug a typed value removes (`c.md` §11).
  **Rejected.**
- **A `[]byte`/slice address.** MojoAkku rejects Go's legacy `net.IP`
  (`type IP []byte`) because aliasing, mutation-through-`To4` and
  non-comparability are the defects `netip` was created to fix (`go.md` §11).
  **Rejected.**
- **Silent parse failure.** MojoAkku rejects a bare `nil`/`None`-only parse
  (`net.ParseIP`, Rust's detail-free `AddrParseError`) as the *primary* API;
  `parse` raises a typed error with a position, and `try_parse` is the explicit
  non-throwing path (`go.md` §4, `rust.md` §4). **Rejected as primary; the
  non-throwing form is kept as `try_parse`.**
- **A stringly-typed classification** (`ipaddr.js` `range()` returning a string).
  MojoAkku uses booleans/a closed `kind` because the compiler can check them
  (`js-ts.md` §11). **Rejected.**
- **Family by arity / no explicit tag** (Elixir's 4-tuple vs 8-tuple). MojoAkku
  carries an explicit family discriminant so usage is compiler-checked
  (`elixir.md` §11). **Rejected.**
- **Unbounded/integer-any-width arithmetic** (Python). MojoAkku uses fixed
  `UInt32`/`UInt128` with a defined out-of-range result (`python.md` §11).
  **Rejected.**
- **DNS, CIDR/prefix types, and an address+port pair** in this release.
  MojoAkku defers them because they are separate concerns/libraries — `net_ip`
  is the bare address (`go.md` §3, `python.md` §3, `julia.md` §3). Each is a
  concrete candidate and is recorded as *deferred* in `_dev/TODO.md`.

## Reference APIs

- **Rust `std::net::{IpAddr, Ipv4Addr, Ipv6Addr}`** — the value-type model and
  the `IpAddr` family enum (`rust.md` §3, §7).
- **Go `net/netip.Addr`** — the modern single value type with `Is4In6`/`Unmap`
  and a total `Compare` (`go.md` §3, §7).
- **Python `ipaddress`** — the integer-is-the-address model and the richest
  predicate set (`python.md` §3, §9).
- **Julia `Sockets.IPv4`/`IPv6`** — two concrete `isbits` types with
  `parse`/`tryparse` and `UInt` conversions (`julia.md` §3, §10).
- **Boost.Asio `ip::address_v4`/`address_v6`** — `to_uint`/`from_uint` and
  `is_v4_mapped`/`v4_mapped` (`cpp.md` §3, §10).
- **C `inet_pton`/`inet_ntop`** — strict parse (negative reference) and
  caller-owned output buffer (`c.md` §3, §10).

## Public API

Release 1 ships the following entries. Status: **shipped** unless noted.

### Types

- `AddressFamily` — `comptime`-style closed family tag (`ipv4`, `ipv6`).
- `Ipv4Address` — IPv4 address value.
- `Ipv6Address` — IPv6 address value.
- `IpAddress` — family-tagged address value unifying both.
- `IpParseErrorKind` — closed parse-error discriminant.
- `IpParseError` — typed parse error (kind + byte position).

### Construction and conversion

- `Ipv4Address.from_octets(a, b, c, d) -> Ipv4Address`
- `Ipv4Address.from_u32(value: UInt32) -> Ipv4Address`
- `Ipv4Address.from_bytes(bytes: Span[UInt8]) -> Ipv4Address`
- `Ipv4Address.to_u32(self) -> UInt32`
- `Ipv4Address.octets(self) -> Array[UInt8, 4]`
- `Ipv6Address.from_segments(...) -> Ipv6Address` (eight `UInt16` segments)
- `Ipv6Address.from_u128(value: UInt128) -> Ipv6Address`
- `Ipv6Address.from_bytes(bytes: Span[UInt8]) -> Ipv6Address`
- `Ipv6Address.to_u128(self) -> UInt128`
- `Ipv6Address.octets(self) -> Array[UInt8, 16]`
- `Ipv6Address.segments(self) -> Array[UInt16, 8]`
- `IpAddress.family(self) -> AddressFamily`

### Parsing and formatting

- `parse(text: String) raises IpParseError -> IpAddress`
- `parse_ipv4(text: String) raises IpParseError -> Ipv4Address`
- `parse_ipv6(text: String) raises IpParseError -> Ipv6Address`
- `try_parse(text: String) -> Optional[IpAddress]`
- `is_valid(text: String) -> Bool`
- `format(address: IpAddress) -> String`
- `format_into(address: IpAddress, mut out: ByteWriter) -> None` *(deferred in
  release 1 if it would force the `io_core` edge; see `TODO.md`)*

### Classification (predicates)

On both `Ipv4Address` and `Ipv6Address` (and, for the shared subset, on
`IpAddress`):

- `is_unspecified(self) -> Bool` — `0.0.0.0` / `::`.
- `is_loopback(self) -> Bool` — `127.0.0.0/8` / `::1` (RFC 1122).
- `is_private(self) -> Bool` — `10/8`, `172.16/12`, `192.168/16` (RFC 1918);
  v6 unique-local `fc00::/7` (RFC 4193).
- `is_link_local(self) -> Bool` — `169.254/16` (RFC 3927); `fe80::/10`
  (RFC 4291).
- `is_multicast(self) -> Bool` — `224/4`; `ff00::/8`.
- `is_broadcast(self) -> Bool` — IPv4 only `255.255.255.255`.
- `is_ipv4_mapped(self) -> Bool` — IPv6 only, `::ffff:0:0/96` (RFC 4291).

### Mapping and navigation

- `Ipv6Address.to_ipv4_mapped(self) -> Optional[Ipv4Address]` — `Some` only for
  an IPv4-mapped address; explicit, never implicit (`rust.md` §3, §7).
- `Ipv6Address.to_ipv4(self) -> Optional[Ipv4Address]` — mapped **or**
  compatible, one named operation (avoids Rust's confusing `to_ipv4`/`to_ipv4_mapped`
  pair — `rust.md` §11).
- `IpAddress.unmap(self) -> IpAddress` — Go-style normalize (`go.md` §3).
- `Ipv4Address.next(self) -> Optional[Ipv4Address]` / `prev` — `None` at
  `255.255.255.255` / `0.0.0.0`.
- `Ipv6Address.next(self) -> Optional[Ipv6Address]` / `prev` — `None` at the
  range ends.

### Equality and ordering

- `__eq__`, `__ne__` on all three (structural).
- `compare(self, other: ...) -> Int` — total order; IPv4 sorts before IPv6, and
  an IPv4-mapped IPv6 address sorts in the IPv6 block (Go's documented rule —
  `go.md` §7).

## Error Surface

- **`IpParseError`** — a value struct with `kind: IpParseErrorKind` and
  `position: Int` (byte offset into the input where the failure was detected).
  Closed kinds:
  - `empty_input`
  - `invalid_character` (a non-digit/non-hex byte where one was required)
  - `octet_out_of_range` (IPv4 octet > 255)
  - `segment_out_of_range` (IPv6 segment > 0xffff)
  - `too_few_groups` / `too_many_groups`
  - `bad_group_separator` (missing/extra `.` or `:`)
  - `bad_ipv6_compression` (a second `::`, or `::` covering the whole address
    ambiguously)
  - `zone_not_supported` (a `%zone` suffix; release 1 rejects zones — *deferred*)
- **Not raised, returned instead:** presence of an absent family
  (`to_ipv4_mapped` → `Optional`), end of range (`next`/`prev` → `Optional`).
- **Never returned:** a partially-constructed address. Parse is all-or-nothing;
  a failure yields no value.

Justification: `MojoAkku uses a closed IpParseErrorKind with a byte position
because Rust's `AddrParseError` and Go's `net.ParseIP` both discard the reason
(`rust.md` §4, `go.md` §4), and the typed-error + closed-kind shape is already
proven in this repository (`akku.codec_base64` `Base64Error`/`ErrorKind`,
`akku.io_core` `IoError`/`IoErrorKind`).`

## Conventions

- Library name `net_ip`; import prefix `akku` (`from akku.net_ip import …`).
- One public API entry per file under `akku/net_ip/`.
- Value types are `Copyable`/`Movable`; no `ImplicitlyCopyable` on the address
  structs (they are cheap, but value semantics should be explicit).
- Functions that can fail raise a **typed** error; functions that express
  expected absence return `Optional`.
- Predicate names are RFC-named (`is_link_local`, not `is_local`).
- Formatting target for IPv6 is RFC 5952 (lower-case hex, longest zero run
  compressed, no leading zeros).

## Ownership and Lifecycle

- The address is a value: copy and move are trivial and allocation-free.
- `from_bytes`/`octets` borrow/produce `Span`/`Array` views; no buffer is
  retained, so there is no lifetime beyond the call.
- `parse` returns an owned `String`-free value; `format` allocates one `String`.
- No destructor concerns (`__deinit__`) — the structs hold only integers.

## Open Questions

None at handoff. The two live design choices were resolved and recorded:

1. *One type or two?* → **one `IpAddress` + two concrete structs** (matches
   Rust/Go/C++ unification; Julia/Elixir's two-only model is rejected for the
   flat Mojo API).
2. *Mapped-address handling: reject (Python) or expose (Go/Rust)?* → **expose**
   `is_ipv4_mapped`/`to_ipv4_mapped`/`unmap`, because silent rejection hides a
   real wire form (`python.md` §7 vs `go.md` §7).

## API entry blocks

Each block: **Status**, **Signature**, **Semantics**, **Errors**, **Tests**,
**Implementation status**, **Rationale**.

### `Ipv4Address` / `Ipv6Address` / `IpAddress`

- **Status:** shipped.
- **Signature:** `struct Ipv4Address(Copyable, Movable)` wrapping `UInt32`;
  `struct Ipv6Address(Copyable, Movable)` wrapping `UInt128`;
  `struct IpAddress(Copyable, Movable)` with `family: AddressFamily` + carrier.
- **Semantics:** immutable value types; equality is structural; ordering is
  total (IPv4 before IPv6).
- **Errors:** none (construction from integers is total).
- **Tests:** equality, ordering across families, copy/move.
- **Implementation status:** not implemented (design phase).
- **Rationale:** `MojoAkku uses a value struct because Go's `netip.Addr` exists
  precisely to replace a slice alias with a comparable value type (`go.md` §10),
  and value semantics is Mojo's default (`mojov1/memory/value-semantics`).`

### `parse` / `parse_ipv4` / `parse_ipv6` / `try_parse` / `is_valid`

- **Status:** shipped.
- **Signature:** `parse(text: String) raises IpParseError -> IpAddress`;
  `try_parse(text: String) -> Optional[IpAddress]`; `is_valid(text: String) -> Bool`.
- **Semantics:** strict RFC-correct parsing, numeric literals only, no DNS and
  no zone (`%`) suffixes in release 1. `try_parse` and `is_valid` never raise.
- **Errors:** `IpParseError` kinds as listed above.
- **Tests:** valid v4/v6, compressed v6, mapped v6, every error kind, boundary
  octets/segments, empty input, trailing junk.
- **Implementation status:** not implemented (design phase).
- **Rationale:** `MojoAkku uses a raising `parse` plus a non-raising
  `try_parse`/`is_valid` because Python and Julia both expose the pair
  (`python.md` §3, `julia.md` §10), and `akku.codec_base64` already ships the
  same `is_valid`/`raises` split.`

### `format` (and `format_into`, deferred)

- **Status:** shipped (`format`); `format_into` **deferred**.
- **Signature:** `format(address: IpAddress) -> String`.
- **Semantics:** IPv4 dotted-quad; IPv6 RFC 5952 compressed lower-case. `format`
  accepts `IpAddress`; family-specific formatting is via `IpAddress`.
- **Errors:** none.
- **Tests:** RFC 5952 cases (longest-run compression, tie-break left-most, no
  compression for a single zero group), round-trip `parse(format(a)) == a`.
- **Implementation status:** not implemented (design phase).
- **Rationale:** `MojoAkku uses RFC 5952 output because Julia's `string(::IPv6)`
  and Go's `Addr.String` both emit the compressed form (`julia.md` §3,
  `go.md` §3); Rust follows the RFC too.`

### `from_*` / `to_u32`/`to_u128` / `octets` / `segments` / `from_bytes`

- **Status:** shipped.
- **Signature:** as listed under *Construction and conversion*.
- **Semantics:** explicit, total conversions; `from_bytes` validates the slice
  length (4 or 16) and raises on mismatch.
- **Errors:** `from_bytes` raises `IpParseError` (`too_few_groups`/
  `too_many_groups` semantics) for a wrong-length slice.
- **Tests:** integer round trips, byte round trips, wrong-length slices.
- **Implementation status:** not implemented (design phase).
- **Rationale:** `MojoAkku uses explicit `to_u32`/`to_u128` and
  `octets`/`segments` because Boost.Asio's `to_uint`/`from_uint` and Rust's
  `to_bits`/`octets` make the integer and byte views explicit rather than
  implicit (`cpp.md` §3, `rust.md` §3).`

### Predicate set

- **Status:** shipped.
- **Signature:** `is_unspecified`, `is_loopback`, `is_private`, `is_link_local`,
  `is_multicast`, `is_broadcast` (v4), `is_ipv4_mapped` (v6) → `Bool`.
- **Semantics:** each backed by its RFC; no vague catch-all predicate.
- **Errors:** none.
- **Tests:** one RFC example per predicate, per family, plus negatives.
- **Implementation status:** not implemented (design phase).
- **Rationale:** `MojoAkku uses a closed, RFC-named predicate set because
  Elixir's `:inet` provides none (`elixir.md` §9) and Java's set is
  host-oriented (`java.md` §9); Python/Julia/Rust show the useful names
  (`python.md` §9, `julia.md` §9, `rust.md` §9).`

### Mapped-address operations

- **Status:** shipped.
- **Signature:** `Ipv6Address.to_ipv4_mapped(self) -> Optional[Ipv4Address]`;
  `Ipv6Address.to_ipv4(self) -> Optional[Ipv4Address]`;
  `IpAddress.unmap(self) -> IpAddress`.
- **Semantics:** explicit only; nothing is converted implicitly.
- **Errors:** none (absence is `Optional`).
- **Tests:** mapped v6 → v4, non-mapped → `None`, `unmap` no-op on plain v4,
  `::ffff:127.0.0.1` round trip.
- **Implementation status:** not implemented (design phase).
- **Rationale:** `MojoAkku makes mapped handling explicit because Go's
  `Is4In6`/`Unmap` and Rust's `to_ipv4_mapped` both do (`go.md` §3,
  `rust.md` §3); Python's silent rejection hides the wire form (`python.md` §7).`

### `next` / `prev`

- **Status:** shipped.
- **Signature:** `next(self) -> Optional[Self]`, `prev(self) -> Optional[Self]`.
- **Semantics:** successor/predecessor in numeric order; `None` at the range
  ends (never wrap, never panic).
- **Errors:** none.
- **Tests:** normal step, both range ends → `None`.
- **Implementation status:** not implemented (design phase).
- **Rationale:** `MojoAkku uses `Optional` instead of Go's invalid-zero-`Addr`
  or a wrapping integer because Go's `Next` returns an invalid address at the
  top of the range (`go.md` §8) and Python raises `AddressValueError`
  (`python.md` §8); `Optional` makes the edge explicit and total.`
