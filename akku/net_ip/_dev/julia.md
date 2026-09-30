# ip research: Julia

## 1. Standard library support

Julia ships a **`Sockets`** standard-library module with distinct value types:

- `Sockets.IPv4` — a struct wrapping a `UInt32`; `Sockets.IPv6` — a struct
  wrapping a `UInt128`. Both are `isbits` value types.
- `parse(IPv4, str)` / `parse(IPv6, str)`, and the non-throwing
  `tryparse(IPv4, str)` / `tryparse(IPv6, str)`.
- Rich predicates: `isloopback`, `islinklocaladdr`/`islinklocal`, `ismulticast`,
  `isprivate`, `isunspecified`, `isglobal` (v6), `isipv4mapped` /
  `isipv4mapped`-style checks.
- `Sockets.InetAddr{T}` pairs an address with a port.

Sources: <https://docs.julialang.org/en/v1/stdlib/Sockets/> (types `IPv4`,
`IPv6`, `InetAddr`), and the `Sockets` API reference.

## 2. Relevant community libraries

`Sockets` is the standard and covers parse/format/predicates. `IPNets.jl` adds
CIDR/network types (`IPNet`) with `parse`, `contains`, `network`, `broadcast`.
`Netaddr.jl` provides range/set operations. Sources:
<https://github.com/JuliaNetworks/...> (Assessment: `IPNets.jl` is the main
companion; the address value itself needs no library.)

## 3. Exposed APIs

`Sockets`:

- `IPv4(host::Integer)` / `IPv6(host::Integer)` — construct from the integer.
- `UInt32(ipv4)` / `UInt128(ipv6)` — the reverse.
- `parse(IPv4, "127.0.0.1")`, `tryparse(IPv6, "::1")`.
- `string(ipv4)` / interpolation `"$ipv6"` — the compact textual form
  (RFC 5952 for v6).
- `isloopback(a)`, `islinklocaladdr(a)`, `ismulticast(a)`, `isprivate(a)`,
  `isunspecified(a)`, `isglobal(a)`.
- `count_ones`, bitwise `&`/`|`/`xor` on the wrapped integer via conversion.

Source: <https://docs.julialang.org/en/v1/stdlib/Sockets/>.

## 4. Error representation

`parse(IPv4, s)` **throws** an `ArgumentError`/`DomainError` on malformed input;
`tryparse(IPv4, s)` returns `nothing` on failure. So Julia offers the
throwing/non-throwing pair, with the throwing one carrying a message. Sources:
the `Sockets` docs and `Base.parse`/`Base.tryparse`
(<https://docs.julialang.org/en/v1/base/numbers/#Base.tryparse>).

## 5. Ownership semantics

`IPv4`/`IPv6` are **immutable, `isbits` value types** (bitstypes are copied by
value and stored inline, no heap, no pointers). Equality is structural, so they
are hashable and usable as `Dict`/`Set` keys. Sources:
<https://docs.julialang.org/en/v1/stdlib/Sockets/>;
<https://docs.julialang.org/en/v1/manual/types/> (`isbits`).

## 6. Blocking / non-blocking

Pure. DNS is `Sockets.getaddrinfo` / `getipaddr`, separate and blocking (can be
wrapped in a `Task`). Source: <https://docs.julialang.org/en/v1/stdlib/Sockets/>.

## 7. Family model (one type or two; mapped addresses)

**Two distinct concrete types** (`IPv4`, `IPv6`) with **no common supertype
carrying both** — though both are `<: IPAddr` for `InetAddr` pairing. Family is
the type; dispatch on it is compile-time. Mapped addresses: Julia exposes the
predicate (`isipv4mapped`) and lets you convert via the integer; there is no
single `to_v4`/`unmap` on all versions. Sources:
<https://docs.julialang.org/en/v1/stdlib/Sockets/>.

## 8. Bounds, overflow and validity

`parse(IPv4, s)` rejects out-of-range octets and wrong shapes with an error;
`tryparse` returns `nothing`. Constructing `IPv4(n)` from an integer is total
over `UInt32`. There is no successor/predecessor that can overflow a Julia
address; arithmetic goes through the integer (`UInt32(ipv4) + 1`), with `UInt`
wrap-around semantics. Sources: `Sockets` docs; Julia `UInt` semantics.

## 9. Classification and arithmetic

Predicate set: `isloopback`, `islinklocaladdr`, `ismulticast`, `isprivate`,
`isunspecified`, `isglobal`. Arithmetic is not defined on the address type; you
convert to `UInt32`/`UInt128`, compute, and convert back. CIDR math is in
`IPNets.jl`. Sources: `Sockets` docs; `IPNets.jl`.

## 10. Interesting design decisions

- **Two concrete `isbits` types, no unified wrapper.** Like Rust's structs but
  without the enum; the family is the type.
- **`parse`/`tryparse` pair** — Julia's standard throwing/non-throwing idiom.
- **Integer-backed with explicit conversions** (`UInt32(ipv4)`), so arithmetic
  is done on the integer and the type stays a thin, allocation-free wrapper.
- **A first-class predicate set** including `isprivate` and `isglobal`.
- **`InetAddr{T}`** cleanly pairs an address with a port — the socket-address
  layer on top of the pure address.

## 11. Decisions NOT to copy

- **No unified address type.** Passing "any address" requires a union
  (`Union{IPv4,IPv6}`) or generics; a single family-tagged type is friendlier
  for a flat Mojo API.
- **Arithmetic only via the integer.** It is safe but verbose; Mojo could offer
  named `next`/`prev` with a documented end-of-range result.
- **No `unmap` helper on every version** — mapped handling is thin.

## 12. Ideas fitting Mojo

- **Two concrete value structs + a family discriminant** is the closest analogue
  to the intended Mojo design (Julia proves the two-type shape, Rust/Go prove
  the unification).
- `tryparse`/`parse` → Mojo `try_parse`/`parse`.
- `UInt32`/`UInt128` backing → Mojo `UInt32`/`UInt128` carriers.
- The predicate names (`isprivate`, `islinklocaladdr`, `isglobal`) are a good
  naming reference for the Mojo predicate set.
- `InetAddr{T}` is a natural **deferred** companion (address+port), arguably part
  of a later `net_socket` layer, not `net_ip`.

## Sources

- Julia `Sockets` stdlib: <https://docs.julialang.org/en/v1/stdlib/Sockets/>
- Julia `Base.tryparse`:
  <https://docs.julialang.org/en/v1/base/numbers/#Base.tryparse>
- Julia types and `isbits`:
  <https://docs.julialang.org/en/v1/manual/types/>
- `IPNets.jl` (community CIDR): <https://github.com/JuliaNetworks/IPNets.jl>
