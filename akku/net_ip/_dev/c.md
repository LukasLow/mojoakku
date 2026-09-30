# ip research: C

## 1. Standard library support

C has **no address type in the language**. The address model lives in POSIX /
the BSD sockets headers:

- `<netinet/in.h>` defines `struct in_addr { uint32_t s_addr; }` (IPv4) and
  `struct in6_addr { unsigned char s6_addr[16]; }` (IPv6), plus the family
  constants `AF_INET` / `AF_INET6` and `struct sockaddr_in` / `sockaddr_in6`.
- `<arpa/inet.h>` defines the text conversions `inet_pton` and `inet_ntop`, and
  the older `inet_aton` / `inet_addr` / `inet_ntoa`.

Sources: POSIX `<netinet/in.h>`
(<https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/netinet_in.h.html>),
POSIX `inet_pton`/`inet_ntop`
(<https://pubs.opengroup.org/onlinepubs/9699919799/functions/inet_pton.html>,
<https://pubs.opengroup.org/onlinepubs/9699919799/functions/inet_ntop.html>).

## 2. Relevant community libraries

- BSD/POSIX `inet_*` and `getaddrinfo`/`getnameinfo` are the de-facto standard.
- `libcidr`, `ipaddr` (a single-header C library) provide parsing and CIDR math.
- `getaddrinfo` additionally does name resolution and is the "modern" successor
  to `gethostbyname` (deprecated). Source:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/getaddrinfo.html>.

(Assessment: `libcidr`/`ipaddr` are third-party and their maturity varies;
POSIX is the only guaranteed surface.)

## 3. Exposed APIs

- `int inet_pton(int af, const char *src, void *dst)` — presentation to
  network. `af` is `AF_INET` (writes 4 bytes) or `AF_INET6` (writes 16 bytes).
  Returns 1 on success, 0 for a malformed address, -1 with `errno = EAFNOSUPPORT`
  for an unsupported family.
- `const char *inet_ntop(int af, const void *src, char *dst, socklen_t size)` —
  network to presentation; returns `NULL` and sets `errno` (`ENOSPC`) if the
  buffer is too small.
- `inet_aton`/`inet_ntoa`: **IPv4 only**, legacy, and `inet_ntoa` returns a
  pointer to a **static buffer** (not thread-safe).

Sources: POSIX `inet_pton`, POSIX `inet_ntop` (cited above).

## 4. Error representation

Mixed and inconsistent:

- `inet_pton` → `1` / `0` / `-1` (three-valued int, with `errno` for the `-1`
  case).
- `inet_ntop` → `NULL` + `errno`.
- `inet_aton` → boolean int.
- `inet_addr` → `INADDR_NONE` (`0xffffffff`) on error, which **collides** with
  the valid broadcast address `255.255.255.255` — the classic ambiguity.

Sources: POSIX `inet_pton`/`inet_ntop`; `inet_addr` man page
(<https://man7.org/linux/man-pages/man3/inet_addr.3.html>).

## 5. Ownership semantics

The address is a **plain value** (`struct in_addr` is one `uint32_t`;
`struct in6_addr` is 16 bytes). The caller owns the storage and passes a pointer
to it (`void *dst` for parsing, `const void *src` for formatting). There is no
handle, no allocation and no lifetime — but also no type safety: `inet_pton`
writes into a `void *` whose size the compiler cannot check against `af`.
Sources: POSIX `inet_pton`/`inet_ntop`.

## 6. Blocking / non-blocking

The conversions are pure CPU work, non-blocking. Blocking appears only for
`getaddrinfo` (DNS), a separate function. Source: POSIX `getaddrinfo`.

## 7. Family model (one type or two; mapped addresses)

**Two separate structs, split by family**, with the family carried *outside* the
address as an `int af` argument to every function. There is no unified "address"
type in C; `sockaddr_storage` is the generic wrapper but it is a
`union` + length, not a typed value. Sources: POSIX `<sys/socket.h>`,
`<netinet/in.h>`.

IPv4-mapped IPv6 is representable only by convention (an IPv6 address whose
first 10 bytes are zero and bytes 10–11 are `0xff`); C provides no `To4`
conversion — the caller inspects the bytes. (Assessment: derived from RFC 4291.)

## 8. Bounds, overflow and validity

`inet_pton` writes `4` or `16` bytes into a caller buffer with **no size
argument** — passing a too-small buffer is undefined behaviour. `inet_ntop`
takes a `size` and is the safe one. `inet_aton` accepts abbreviated forms
(`"127.1"`) that the modern parsers reject. Sources: POSIX `inet_pton`/
`inet_ntop`; `inet_addr` man page.

## 9. Classification and arithmetic

There is **no predicate API**. The caller extracts the bytes and compares:
`INADDR_LOOPBACK`, `INADDR_ANY`, `INADDR_BROADCAST` are macros for well-known
IPv4 values. There is no `is_private`, no successor, no set order. Sources:
`<netinet/in.h>` (POSIX).

## 10. Interesting design decisions

- **Text conversion is a separate function family** (`inet_pton`/`inet_ntop`),
  not a method on the address — the type carries no behaviour.
- **The output buffer is caller-owned**, which avoids allocation but pushes the
  size-correctness burden onto the caller.
- **The family is a runtime parameter**, not part of the type — the root cause of
  the `void *` size-blindness.
- Network byte order is the storage convention; `htonl`/`ntohl` convert.

## 11. Decisions NOT to copy

- **`void *` + separate `af`**: no compile-time link between family and buffer
  size — the exact bug a typed value eliminates.
- **The three-valued int return** `1/0/-1` with `errno` for one branch only.
- **`INADDR_NONE` colliding with the broadcast address.**
- **`inet_ntoa`'s static buffer** (not reentrant).
- **No predicate/classification API at all.**

## 12. Ideas fitting Mojo

- The lesson is *negative*: a single typed value that knows its own family is
  strictly better than `void *` + `af`. This is the strongest argument for the
  Mojo value-struct design.
- `inet_pton`'s strict `1/0/-1` maps onto a typed `raises ParseError` in Mojo.
- Caller-owned output maps onto a Mojo `encode_into`/`format_into` overload that
  writes into a caller `Span`/buffer (compare `akku.codec_base64`'s
  `encode_into`).

## Sources

- POSIX `<netinet/in.h>`:
  <https://pubs.opengroup.org/onlinepubs/9699919799/basedefs/netinet_in.h.html>
- POSIX `inet_pton`:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/inet_pton.html>
- POSIX `inet_ntop`:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/inet_ntop.html>
- POSIX `getaddrinfo`:
  <https://pubs.opengroup.org/onlinepubs/9699919799/functions/getaddrinfo.html>
- `inet_addr(3)` man page: <https://man7.org/linux/man-pages/man3/inet_addr.3.html>
- RFC 4291 (IP Version 6 Addressing Architecture), IPv4-mapped addresses:
  <https://www.rfc-editor.org/rfc/rfc4291>
