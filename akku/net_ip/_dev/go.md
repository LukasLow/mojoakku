# ip research: Go

## 1. Standard library support

Go ships **two generations** of IP-address support in the standard library:

- **Legacy:** `net.IP`, defined as `type IP []byte`. It is a byte-slice alias, so
  it has slice semantics (aliasing, mutation, no value equality). Parsing is
  `net.ParseIP(s string) IP`, returning `nil` on failure. Source:
  <https://pkg.go.dev/net#IP>.
- **Modern:** `net/netip` (added in Go 1.18), whose `Addr` is a
  **comparable value type** — "Addr represents an IPv4 or IPv6 address. Addr is
  a comparable value type (it supports == and can be a map key)". Source:
  <https://pkg.go.dev/net/netip#Addr>.

`net/netip` also defines `AddrPort` (address + port), `Prefix` (CIDR), and the
concrete types `netip.Addr` covering both families. Sources:
<https://pkg.go.dev/net/netip>.

The package documentation states the reason for the redesign: `net.IP` "is a
slice and thus is not comparable and requires care to use", whereas `Addr` is a
value type that is small and cheap to copy. Source:
<https://pkg.go.dev/net/netip#pkg-overview>.

## 2. Relevant community libraries

The standard library is considered sufficient; the modern `netip` explicitly
replaces the third-party `inet.af/netaddr` work that informed it. The `netip`
package doc references the proposal and the prior art. Source:
<https://pkg.go.dev/net/netip> (and `golang/go` proposal #46518).

## 3. Exposed APIs

`net/netip` (the model to study):

- `ParseAddr(s string) (Addr, error)` — strict parse; an IPv4-mapped IPv6 text
  form parses as an IPv6 address.
- `MustParseAddr(s string) Addr` — panics on error.
- `Addr.Is4() bool`, `Addr.Is4In6() bool`, `Addr.Is6() bool` — family tests.
- `Addr.Unmap() Addr` — returns the IPv4 form of an IPv4-mapped IPv6 address.
- `Addr.IsLoopback() bool`, `IsPrivate()`, `IsLinkLocalUnicast()`,
  `IsLinkLocalMulticast()`, `IsMulticast()`, `IsInterfaceLocalMulticast()`,
  `IsUnspecified()`, `IsGlobalUnicast()`.
- `Addr.Compare(Addr) int` — total ordering, "the result is 0 if a == b". Family
  ordering is defined (source: <https://pkg.go.dev/net/netip#Addr.Compare>).
- `Addr.Next() Addr`, `Addr.Prev() Addr`, `Addr.BitLen()`, `Addr.Zone()`.
- `Addr.As4() [4]byte`, `Addr.As16() [16]byte` — fixed-size extraction.
- `Addr.AppendTo([]byte) []byte` — append the textual form to a buffer.
- `Addr.MarshalText`/`UnmarshalText` — textual (JSON) round trip.

`net` (the legacy surface): `ParseIP`, `IP.String`, `IP.To4`, `IP.To16`,
`IP.DefaultMask`, `IP.Mask`, `IP.IsLoopback`, `IP.IsPrivate`,
`IP.IsMulticast`, `IP.IsUnspecified`. Source: <https://pkg.go.dev/net#IP>.

## 4. Error representation

`netip.ParseAddr` returns `(Addr, error)`. The error is `*netip.ParseError`,
which carries a short reason string and the offending input; `errors.As` can
recover it. `errors.Is(err, netip.ErrInvalidAddr)` exists for the generic case.
Sources: <https://pkg.go.dev/net/netip#ParseError>,
<https://pkg.go.dev/net/netip#pkg-variables>.

`net.ParseIP` is the older style: it returns a bare `nil` on failure with **no
reason** — the parse error is lost. Source: <https://pkg.go.dev/net#ParseIP>.

## 5. Ownership semantics

`netip.Addr` is a value type: a small struct (a `[16]byte`-like array plus a
zone string and a family flag), copied by value, comparable with `==`, usable as
a map key. It contains no pointers to shared mutable state. Source:
<https://pkg.go.dev/net/netip#Addr>.

`net.IP` is a `[]byte` slice: assignment **aliases** the backing array; mutating
one `net.IP` mutates the other. `ParseIP` allocates a fresh slice per call, but
`To4()` may return a sub-slice of the original, so writing through it can
corrupt the source. This is the documented trap of the legacy type. Source:
<https://pkg.go.dev/net#IP> and the `netip` motivation.

## 6. Blocking / non-blocking

The address type itself is **pure and non-blocking**: `netip.ParseAddr` is a
string operation with no I/O. Blocking only appears with the *host* APIs:
`net.LookupIP` / `Resolver.LookupIP` perform DNS and can block; `netip.Addr` in
contrast never resolves. Source: <https://pkg.go.dev/net/netip#pkg-overview>
("Addr ... does not use DNS").

## 7. Family model (one type or two; mapped addresses)

`netip.Addr` is **one type over both families**. A zero `Addr` is the "invalid"
address and prints as `"invalid IP"`. Family is queried with `Is4`/`Is6`;
`Is4In6` reports an IPv4-mapped IPv6 address, and `Unmap` converts it back to
plain IPv4. Source: <https://pkg.go.dev/net/netip#Addr>.

Ordering note: `Compare` sorts IPv4 addresses before IPv6 ones, and
"IPv4-mapped IPv6 addresses sort after IPv4 addresses" unless `Unmap` is used
first. Source: <https://pkg.go.dev/net/netip#Addr.Compare>.

## 8. Bounds, overflow and validity

`ParseAddr` is strict: it rejects leading/trailing spaces, out-of-range octets
(`256.1.1.1`), and a missing zone where one is required. `net.ParseIP` in the
legacy package accepts a wider (more lenient) textual set. Sources:
<https://pkg.go.dev/net/netip#ParseAddr>, <https://pkg.go.dev/net#ParseIP>.

`Addr.As4()` panics if the address is not a 4-byte (unmapped) IPv4 address;
`As16()` always succeeds. Source: <https://pkg.go.dev/net/netip#Addr.As4>.

`Addr.Next()` returns the invalid `Addr` when there is no next address (i.e. at
`255.255.255.255` / the top of IPv6). Source:
<https://pkg.go.dev/net/netip#Addr.Next>.

## 9. Classification and arithmetic

The `Is*` predicate set above covers loopback, private (RFC 1918 / RFC 4193
ULA), link-local unicast/multicast, interface-local multicast, multicast,
unspecified and global-unicast. `Next`/`Prev` provide successor/predecessor.
`Prefix` provides `Contains`, `Masked`, `Overlaps` for subnet math. Sources:
<https://pkg.go.dev/net/netip#Addr>, <https://pkg.go.dev/net/netip#Prefix>.

There is **no** general bitwise operator over an `Addr` (you extract `As16()`
and do it yourself). Source: <https://pkg.go.dev/net/netip#Addr.As16>.

## 10. Interesting design decisions

- **A value type, not a slice.** The whole `netip` package exists to replace a
  slice alias with a comparable value; this is the single most transferable
  lesson for Mojo, where value semantics is the default.
- **One type with an explicit "invalid" zero value**, rather than two types plus
  an `Optional`-free sentinel — `Addr` has exactly one invalid state.
- **Mapped-address handling made explicit** via `Is4In6`/`Unmap` instead of
  hiding it.
- **Predicates as methods** with precise RFC-backed names (`IsLinkLocalUnicast`
  vs `IsLinkLocalMulticast`), not one vague `IsLocal`.
- **`Compare` defines a total order** including across families.

## 11. Decisions NOT to copy

- **`net.IP` as a `[]byte` alias.** Aliasing, mutation-through-`To4`, and
  non-comparability are exactly the defects `netip` was written to fix.
- **Silent `nil` on parse failure** (`net.ParseIP`). Losing the reason makes the
  error unusable; a typed error is better.
- **A host/resolver type on the address.** `netip.Addr` deliberately excludes
  DNS; keeping resolution out of the address value is correct and we should keep
  it out too.

## 12. Ideas fitting Mojo

- Model the address as a **value struct** (`Copyable`, `Movable`) — the direct
  analogue of `netip.Addr`, and the natural Mojo shape.
- A single type with an explicit invalid/unspecified state maps well onto a
  `comptime` family discriminant plus an `Optional` at the parse boundary.
- The `Is*` predicate set is a clean, testable API surface for Mojo.
- `As4`/`As16` map onto Mojo `Array[UInt8, N]` / `Span` extraction.
- A typed `ParseError` with reason + position fits Mojo's typed-`raises` model
  (compare `akku.codec_base64`'s error shape).

## Sources

- `net` package: <https://pkg.go.dev/net#IP>
- `net/netip` package and `Addr`: <https://pkg.go.dev/net/netip#Addr>
- `netip.ParseAddr` / `ParseError`: <https://pkg.go.dev/net/netip#ParseAddr>,
  <https://pkg.go.dev/net/netip#ParseError>
- `netip.Prefix`: <https://pkg.go.dev/net/netip#Prefix>
- Go issue/proposal for `netip`: golang/go#46518
