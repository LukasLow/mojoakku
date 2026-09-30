# ip research: Rust

## 1. Standard library support

Rust's standard library ships an IP-address model in `std::net`:

- `std::net::IpAddr` — "An IP address, either IPv4 (Ipv4Addr) or IPv6
  (Ipv6Addr)." It is an **enum** with variants `V4(Ipv4Addr)` and `V6(Ipv6Addr)`.
- `std::net::Ipv4Addr` — a struct wrapping a `u32` stored in **network byte
  order** (`octets()` returns the big-endian octets).
- `std::net::Ipv6Addr` — a struct wrapping a `u128`.
- `std::net::SocketAddr` / `Ipv4Addr`/`Ipv6Addr` variants, plus `AddrParseError`.

Sources: <https://doc.rust-lang.org/std/net/enum.IpAddr.html>,
<https://doc.rust-lang.org/std/net/struct.Ipv4Addr.html>,
<https://doc.rust-lang.org/std/net/struct.Ipv6Addr.html>.

The type is `Copy`, `Eq`, `Hash`, `Ord`, and `no_std`-free only in `core` terms;
it lives in `std`, not `core`. Source:
<https://doc.rust-lang.org/std/net/enum.IpAddr.html> (trait impls list).

## 2. Relevant community libraries

- `ipnet` — IP network/CIDR arithmetic (`IpNet`, `Ipv4Net`, `Ipv6Net`); the
  common companion to `std::net`. Source: <https://docs.rs/ipnet>.
- `iprange` — compact IPv4 address ranges and set operations. Source:
  <https://docs.rs/iprange>.
- `no-std-net` — a `core`-only port of the address types. Source:
  <https://docs.rs/no-std-net>.
- `std::net` itself is otherwise considered complete for the address value.

## 3. Exposed APIs

`Ipv4Addr`:

- `Ipv4Addr::new(a, b, c, d) -> Ipv4Addr` (const).
- `Ipv4Addr::from(u32)`, `u32::from(addr)` — numeric (network-order) round trip.
- `Ipv4Addr::from([u8; 4])`, `addr.octets() -> [u8; 4]`.
- `Ipv4Addr::LOCALHOST`, `UNSPECIFIED`, `BROADCAST` associated constants.
- `is_loopback()`, `is_private()`, `is_link_local()`, `is_multicast()`,
  `is_broadcast()`, `is_documentation()`, `is_unspecified()`.
- `octets()`, `to_bits() -> u32`.
- `FromStr` via `"1.2.3.4".parse::<Ipv4Addr>()`.

Source: <https://doc.rust-lang.org/std/net/struct.Ipv4Addr.html>.

`Ipv6Addr`:

- `Ipv6Addr::new(...)`, `from(u128)`, `from([u8; 16])`, `octets()`, `segments()`.
- `is_loopback()`, `is_unspecified()`, `is_multicast()`, `is_unique_local()`
  (RFC 4193), `is_unicast_link_local()`.
- `to_ipv4()` / `to_ipv4_mapped()` — **recent additions** that convert an
  IPv4-mapped IPv6 address to `Ipv4Addr`.
- `Ipv6Addr::LOCALHOST`, `UNSPECIFIED`.

Sources: <https://doc.rust-lang.org/std/net/struct.Ipv6Addr.html>,
<https://doc.rust-lang.org/std/net/struct.Ipv6Addr.html#method.to_ipv4>.

`IpAddr`:

- `is_ipv4()`, `is_ipv6()`, `is_loopback()`, `is_multicast()`,
  `is_unspecified()`.
- Implements `From<Ipv4Addr>`/`From<Ipv6Addr>`, `Ord`, `Hash`, `Display`.

Source: <https://doc.rust-lang.org/std/net/enum.IpAddr.html>.

## 4. Error representation

Parsing uses `FromStr` with `type Err = AddrParseError`. `AddrParseError` is an
opaque zero-sized-ish struct whose `Display` is `"invalid IP address syntax"`;
it carries no position and no reason. Rust returns it inside a `Result<T, E>`.
Sources: <https://doc.rust-lang.org/std/net/struct.AddrParseError.html>,
<https://doc.rust-lang.org/std/net/struct.Ipv4Addr.html#impl-FromStr>.

## 5. Ownership semantics

The address types are plain **value types**: `Copy` + `Clone`, hold only `u32` /
`u128` integers, no heap, no pointers, no lifetime. Copying is a bitwise copy.
Sources: <https://doc.rust-lang.org/std/net/struct.Ipv4Addr.html> (trait impls).

## 6. Blocking / non-blocking

Pure and non-blocking: parsing and formatting are pure functions. Blocking only
appears in `std::net::ToSocketAddrs` / DNS resolution, which is a separate
concern from the address type. Source: <https://doc.rust-lang.org/std/net/>.

## 7. Family model (one type or two; mapped addresses)

**Two concrete types under one enum.** `Ipv4Addr` and `Ipv6Addr` are separate
structs; `IpAddr` is the enum that unifies them, so a function can accept "any
address" as `IpAddr` while match arms recover the family. Source:
<https://doc.rust-lang.org/std/net/enum.IpAddr.html>.

Mapped addresses are handled explicitly: `Ipv6Addr::to_ipv4_mapped()` returns
`Option<Ipv4Addr>` only for an IPv4-mapped address, while `to_ipv4()` also
converts compatible/native forms. Sources:
<https://doc.rust-lang.org/std/net/struct.Ipv6Addr.html#method.to_ipv4_mapped>.

## 8. Bounds, overflow and validity

`FromStr` is strict: it rejects `"1.2.3"`, `"1.2.3.4.5"`, leading zeros beyond
the documented set and out-of-range octets. Source:
<https://doc.rust-lang.org/std/net/struct.Ipv4Addr.html#impl-FromStr>.

`Ipv4Addr` is `u32`-backed, so "overflow" cannot happen at the type level; the
parser guards the text. Numeric construction from a `u32` is total. Source:
<https://doc.rust-lang.org/std/net/struct.Ipv4Addr.html>.

`Ipv6Addr::segments()` returns `[u16; 8]`; there is no panicking indexer.

## 9. Classification and arithmetic

Rich predicate set (see §3). `is_private()` follows the IETF registry (RFC 1918
plus others). `ipnet` (community) adds `contains`, `overlaps`, `network`,
`broadcast` for CIDR math. Source: <https://doc.rust-lang.org/std/net/struct.Ipv4Addr.html#method.is_private>,
<https://docs.rs/ipnet>.

There is **no** built-in successor/predecessor or bitwise operator over the
address type; you go through `u32`/`u128` (`to_bits` / `from`).

## 10. Interesting design decisions

- **Enum over concrete types.** `IpAddr` is a Rust `enum` with data — the
  canonical "one abstraction, two families" model, resolved at compile time with
  exhaustive `match`.
- **Integer-backed, network order.** `Ipv4Addr` stores a `u32` in network byte
  order; `octets()`/`to_bits()` are the explicit conversions, so no hidden
  endianness surprise.
- **Associated constants for well-known addresses** (`LOCALHOST`,
  `UNSPECIFIED`, `BROADCAST`) instead of functions.
- **`From`/`FromStr`/`Display` integration**, so the type slots into the
  standard conversion and formatting machinery.
- Predicate names are precise and RFC-named.

## 11. Decisions NOT to copy

- **`AddrParseError` with no detail.** Like Go's legacy `nil`, it discards the
  reason and position; a typed error with a kind+offset is more useful for the
  Mojo design.
- **`to_ipv4()` vs `to_ipv4_mapped()` split.** Two near-identical conversions
  with subtly different semantics is easy to misuse; one explicit, named
  operation is better.

## 12. Ideas fitting Mojo

- The **enum/`.V4`/`.V6` unification** maps directly onto a Mojo `comptime`
  family discriminant in a value struct, matching the intended single-type
  design.
- `Copy`/`Eq`/`Hash` mirrors Mojo `Copyable`/`Movable` (+ a hash trait when one
  exists).
- `LOCALHOST`/`UNSPECIFIED`/`BROADCAST` as associated constants fit a Mojo
  `comptime` member or module-level `comptime` value.
- `octets()`/`from([u8;4])` map onto Mojo `Array[UInt8, 4]` / `Span`.
- The predicate set is a clean, RFC-named API surface to mirror.

## Sources

- `std::net::IpAddr`: <https://doc.rust-lang.org/std/net/enum.IpAddr.html>
- `std::net::Ipv4Addr`: <https://doc.rust-lang.org/std/net/struct.Ipv4Addr.html>
- `std::net::Ipv6Addr`: <https://doc.rust-lang.org/std/net/struct.Ipv6Addr.html>
- `AddrParseError`: <https://doc.rust-lang.org/std/net/struct.AddrParseError.html>
- `ipnet` crate: <https://docs.rs/ipnet>
- `iprange` crate: <https://docs.rs/iprange>
- `no-std-net` crate: <https://docs.rs/no-std-net>
