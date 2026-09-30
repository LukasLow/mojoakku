# ip research: Python

## 1. Standard library support

Python ships the **`ipaddress` module** (PEP 3144), "a set of classes for
working with IPv4 and IPv6 addresses and networks". It defines:

- `IPv4Address`, `IPv6Address` — address value types.
- `IPv4Network`, `IPv6Network`, `IPv4Interface`, `IPv6Interface` — network and
  interface types.
- `ip_address(obj)` / `ip_network(obj)` — factory functions that pick the right
  class.
- Exception hierarchy: `AddressValueError`, `NetmaskValueError`,
  `NotRegisteredError` (all under `ValueError`).

Sources: <https://docs.python.org/3/library/ipaddress.html>; PEP 3144
<https://peps.python.org/pep-3144/>.

## 2. Relevant community libraries

- `ipaddress` is the standard; `netaddr` (third-party) predates it and adds
  registry/IANA data and set operations over ranges. Source:
  <https://netaddr.readthedocs.io/>.
- `py-radix`, `python-iptools` add trie/compact-range handling.
  (Assessment: `netaddr` remains the main alternative for registry-aware
  classification.)

## 3. Exposed APIs

`IPv4Address` (representative):

- Constructor `IPv4Address('192.0.2.1')` or `IPv4Address(0xC0000201)`;
  `str(addr)` is the dotted-quad form.
- `ip_address` factory; `IPv4Address.from_bytes` / `packed` property.
- Predicates: `is_private`, `is_global`, `is_multicast`, `is_loopback`,
  `is_link_local`, `is_reserved`, `is_unspecified`, `is_site_local` (v6).
- Arithmetic: `addr + 1`, `addr - 1`, `addr1 - addr2` (an `int`), `int(addr)`.
- `address_exclude`, `subnets`, `supernet` on **network** types.

Sources: <https://docs.python.org/3/library/ipaddress.html#ipaddress.IPv4Address>,
<https://docs.python.org/3/library/ipaddress.html#operators>.

## 4. Error representation

A typed exception hierarchy rooted at `ValueError`: `AddressValueError` for a
malformed address, `NetmaskValueError` for a bad netmask. The message names the
failing input (e.g. `'300.1.1.1' does not appear to be an IPv4 or IPv6
address`). Sources:
<https://docs.python.org/3/library/ipaddress.html#exceptions>.

## 5. Ownership semantics

`IPv4Address`/`IPv6Address` are **immutable value objects**: attributes are
read-only, instances are hashable, comparable and usable as dict keys. There is
no aliasing. The integer is the source of truth; `packed` gives the bytes.
Sources: <https://docs.python.org/3/library/ipaddress.html> (class description:
"The objects are immutable").

## 6. Blocking / non-blocking

Pure, non-blocking. The module never does DNS — there is deliberately **no**
hostname support ("ipaddress ... does not resolve DNS"). Sources:
<https://docs.python.org/3/library/ipaddress.html>.

## 7. Family model (one type or two; mapped addresses)

**Two concrete classes (`IPv4Address`, `IPv6Address`) with no shared base class
for the address itself**; the `ip_address()` factory returns the right one.
There is no generic "Address" type — callers test with `isinstance`. IPv4-mapped
IPv6 addresses are detected and **explicitly rejected**: "the constructor ...
does not accept an IPv4-mapped IPv6 address, because it is an error to create an
IPv4Address from it" (you must use `IPv6Address`). Sources:
<https://docs.python.org/3/library/ipaddress.html#ipaddress.ip_address>.

(Assessment: Python chose *rejection* of mapped addresses at the IPv4 boundary
rather than silent conversion.)

## 8. Bounds, overflow and validity

Strict parsing: `IPv4Address('256.1.1.1')` raises `AddressValueError`; the
constructor also raises on the wrong family's text. Arithmetic is **unbounded at
the Python level** but the class defines the end of the range: `IPv4Address` at
`255.255.255.255` plus one, or below `0.0.0.0`, raises `AddressValueError`
("address out of range"). Source:
<https://docs.python.org/3/library/ipaddress.html#operators>.

## 9. Classification and arithmetic

The richest predicate set of the references: `is_private`, `is_global`,
`is_multicast`, `is_loopback`, `is_link_local`, `is_reserved`,
`is_unspecified` on both families, plus `is_site_local` (v6). Arithmetic:
`+`/`-` integers, `-` another address (an `int`), and network helpers
(`subnets`, `supernet`, `address_exclude`, `hosts`). The network classes do the
CIDR math. Sources: <https://docs.python.org/3/library/ipaddress.html>.

## 10. Interesting design decisions

- **Two classes, one factory** (`ip_address`) — the caller rarely names the
  family explicitly; the factory picks it.
- **The integer is the model.** `int(addr)` is the address; every operation is
  defined through it, so arithmetic and comparison are natural and total.
- **Immutability + hashability** make addresses safe as keys and comparable with
  `<`.
- **A rich, registry-backed predicate set**, including `is_global` as the
  complement-ish of `is_private`.
- **Mapped IPv6 rejected at the IPv4 constructor** — forcing the caller to stay
  in the v6 family.

## 11. Decisions NOT to copy

- **No common address base type / relying on `isinstance`.** Dynamic dispatch is
  not a Mojo tool; an explicit family discriminant is better.
- **Unbounded Python integers** hide the fixed width; Mojo needs an explicit
  fixed-width carrier (and a defined out-of-range error).
- **`is_global` defined as "not private"** can surprise; a precise, documented
  predicate set matters more than a convenience complement.

## 12. Ideas fitting Mojo

- The **integer-is-the-address** model maps directly onto Mojo `UInt32`/`UInt128`
  carriers with `Array[UInt8, N]` views.
- The `ip_address` factory → a Mojo `parse`/`from_str` that returns a
  family-tagged value.
- The predicate set (with `is_global`/`is_private`) is the API surface to
  mirror, each backed by an RFC.
- Immutability + comparability → Mojo `Copyable`/`Movable` value struct with
  `__eq__` and an ordering.
- Mapped-address handling: Python's rejection is one defensible option; Mojo
  could instead expose `is_ipv4_mapped()` / `to_ipv4()` (Go/Rust style) — a
  design decision to record.

## Sources

- `ipaddress` module: <https://docs.python.org/3/library/ipaddress.html>
- PEP 3144 (IP Address Manipulation Library proposal):
  <https://peps.python.org/pep-3144/>
- `netaddr` (third-party): <https://netaddr.readthedocs.io/>
