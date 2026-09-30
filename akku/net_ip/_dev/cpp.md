# ip research: C++

## 1. Standard library support

C++ has **no IP address type in the standard library** (there is no
`std::ip_address`; the proposed `std::net` was never standardized). The address
model is the C one, inherited through `<arpa/inet.h>` / `<netinet/in.h>`:
`in_addr`, `in6_addr`, `inet_pton`, `inet_ntop`. Sources: the C research file
`c.md`; ISO C++ has no networking TS in the standard.

(Assessment: C++23 added no address type; the Networking TS
(`<cpp-ms-networking-ts>`) remained a Technical Specification, never merged into
ISO C++.)

## 2. Relevant community libraries

- **Boost.Asio** — `boost::asio::ip::address`, `address_v4`, `address_v6`, plus
  `network_v4`/`network_v6`. The de-facto C++ IP model. Source:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference/ip__address.html>.
- **`asio`** (the standalone, header-only fork) mirrors Boost.Asio exactly.
  Source: <https://think-async.com/Asio/>.
- `cpp-ipc`, `cidr` and various single-header helpers exist but none is
  standard. (Assessment: ecosystem is fragmented; Boost.Asio is the reference.)

## 3. Exposed APIs

Boost.Asio:

- `ip::address` — an `any`-like class holding either an IPv4 or IPv6 address;
  `is_v4()`, `is_v6()`, `to_v4()`, `to_v6()`, `to_string()`.
- `ip::address_v4` — `from_string`, `to_string`, `to_bytes()`, `to_uint()`,
  `from_bytes`, `is_loopback()`, `is_multicast()`, `is_unspecified()`.
- `ip::address_v6` — same shape plus `scope_id`, `is_link_local()`,
  `is_site_local()`, `is_v4_mapped()`, `is_v4_compatible()`, `v4_mapped()`.
- `ip::network_v4` — `network()`, `broadcast()`, `hosts()`, `canonical()`,
  `is_subnet_of()`, `hosts()`.

Source: <https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference.html>
(ip::address, ip::address_v4, ip::address_v6, ip::network_v4).

## 4. Error representation

Boost.Asio uses a `boost::system::error_code` out-parameter plus throwing
overloads: `address_v4::from_string(str)` returns an invalid address and sets
`error_code` (or throws `system_error` in the throwing overload). Source:
<https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference/ip__address_v4/from_string.html>.

The C `inet_pton` layer underneath uses `1/0/-1` + `errno` (see `c.md`).

## 5. Ownership semantics

`address_v4` wraps a `uint_type` (a `uint32_t`) and `address_v6` wraps a
`bytes_type` (`std::array<unsigned char, 16>`): both are **value types**,
copyable, comparable. `ip::address` is a discriminated union with the same value
semantics. No manual memory management. Source:
<https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference/ip__address_v4.html>.

## 6. Blocking / non-blocking

Con/format are pure. `ip::basic_resolver` (DNS) is separate and can be async
(the whole point of Asio). Source: Boost.Asio resolver documentation.

## 7. Family model (one type or two; mapped addresses)

**Two concrete types (`address_v4`, `address_v6`) unified by a variant-like
`address` class** with `is_v4()`/`is_v6()` and `to_v4()`/`to_v6()` accessors —
the C++ mirror of Rust's enum model, but runtime-tagged rather than
template/`std::variant`. Mapped addresses are explicit:
`address_v6::is_v4_mapped()` / `v4_mapped()`. Source:
<https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference/ip__address_v6.html>.

## 8. Bounds, overflow and validity

`from_string` returns an invalid address (default-constructed) on failure in the
non-throwing form; the throwing form raises. Octet range and format errors are
not described in detail (the error is a generic `error_code`). Source:
<https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference/ip__address_v4/from_string.html>.

The underlying `inet_pton` has the C buffer hazards (see `c.md`).

## 9. Classification and arithmetic

`address_v4`: `is_loopback`, `is_multicast`, `is_unspecified`. `address_v6`:
`is_loopback`, `is_multicast`, `is_link_local`, `is_site_local`, `is_v4_mapped`,
`is_v4_compatible`, `is_unspecified`. `network_v4` adds subnet math. There is no
successor/predecessor on the address; numeric work goes through `to_uint()` /
`to_bytes()`. Source: Boost.Asio ip reference.

## 10. Interesting design decisions

- **Variant-like `address` over two concrete types**: the same "one abstraction,
  two families" idea as Rust, but resolved at runtime.
- **`from_string` + `error_code` / throwing overload pair** — the classic C++
  dual error style.
- **`to_uint()` / `from_uint()`** make the numeric representation explicit and
  round-trippable.
- **`is_v4_mapped` / `v4_mapped`** keep the mapped case visible.

## 11. Decisions NOT to copy

- **The throwing/non-throwing overload pair.** Two ways to call every parser
  doubles the surface; Mojo's typed `raises` gives one honest signature.
- **Runtime-tagged `address`.** A Mojo `comptime` family parameter or an
  `Optional`-free explicit family field is cleaner than a runtime `any`.
- **Generic `error_code` with no parse detail** (reason/position lost).

## 12. Ideas fitting Mojo

- The `address_v4`/`address_v6` + unified `address` split validates the intended
  Mojo shape: two concrete value structs behind one family-tagged API.
- `to_uint()`/`to_bytes()` map onto Mojo integer/`Array[UInt8, N]` conversions.
- `is_v4_mapped`/`v4_mapped` is a direct feature to mirror.
- `network_v4` (subnet) is a natural **deferred** follow-up library
  (`net_cidr` / `net_prefix`), not part of `net_ip` release 1.

## Sources

- Boost.Asio `ip::address`:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference/ip__address.html>
- Boost.Asio `ip::address_v4`:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference/ip__address_v4.html>
- Boost.Asio `ip::address_v6`:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference/ip__address_v6.html>
- Boost.Asio reference index:
  <https://www.boost.org/doc/libs/release/doc/html/boost_asio/reference.html>
- standalone Asio: <https://think-async.com/Asio/>
