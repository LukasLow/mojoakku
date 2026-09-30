# ip research: Elixir

## 1. Standard library support

Elixir/Erlang's address support lives in the **`:inet`** module
(`:inet.parse_ipv4_address/1`, `:inet.parse_ipv6_address/1`,
`:inet.parse_address/1`, `:inet.ntoa/1`, `:inet.pton/2`, `:inet.ntop/2`). An
address is represented as a **tagged tuple**, not a struct:

- IPv4: `{a, b, c, d}` with each element an integer `0..255`.
- IPv6: `{a, b, c, d, e, f, g, h}` with each element an integer `0..65535`.

Sources: <https://www.erlang.org/doc/man/inet.html#parse_ipv4_address-1>,
<https://www.erlang.org/doc/man/inet.html#parse_ipv6_address-1>,
<https://www.erlang.org/doc/man/inet.html#ntoa-1>.

`:inet.parse_address/1` accepts both IPv4 and IPv6 text and returns whichever
tuple matches (the family is the tuple size). Source:
<https://www.erlang.org/doc/man/inet.html#parse_address-1>.

## 2. Relevant community libraries

The OTP `:inet` module is the standard and is considered sufficient for
parsing/formatting. `:inet` also handles socket addresses (`{:inet, ip_tuple,
port}` / `{:inet6, ...}`). `cidr` (Hex package) and `:netaddr`-style helpers add
CIDR math. (Assessment: the address *value* itself needs no library; range/CIDR
needs one.)

## 3. Exposed APIs

- `:inet.parse_ipv4_address(charlist)` → `{:ok, {a,b,c,d}}` | `{:error,
  :einval}`.
- `:inet.parse_ipv6_address(charlist)` → `{:ok, {a,…,h}}` | `{:error, :einval}`.
- `:inet.parse_address(charlist)` → `{:ok, tuple}` | `{:error, :einval}`
  (either family).
- `:inet.ntoa(ip_tuple)` → `{:ok, charlist}` | `{:error, :einval}` (textual
  form).
- `:inet.pton/2`, `:inet.ntop/2` — binary (network) ↔ text for a given family.
- `:inet.is_ipv4_address/1`, `:inet.is_ipv6_address/1` — tuple shape tests.

Sources: <https://www.erlang.org/doc/man/inet.html>.

## 4. Error representation

A tagged result: `{:ok, value}` or `{:error, :einval}`. The reason is a single
atom — `:einval` — with **no position and no detail** about what was wrong.
Sources: `:inet.parse_ipv4_address/1`, `:inet.parse_ipv6_address/1`,
`:inet.parse_address/1` (cited above).

## 5. Ownership semantics

The tuple is an **immutable, copy-on-write term** with structural equality:
`{127,0,0,1} == {127,0,0,1}` is true, and the tuple is trivially hashable and
usable as a map/`MapSet` key. There is no aliasing or manual memory. Sources:
Erlang data-type semantics (<https://www.erlang.org/doc/reference_manual/data_types.html>).

## 6. Blocking / non-blocking

Parsing/formatting is pure and non-blocking. DNS is `:inet.getaddr/2` /
`:inet.gethostbyname/1`, which block in the calling process (offload to a task
for concurrency). Source: <https://www.erlang.org/doc/man/inet.html#getaddr-2>.

## 7. Family model (one type or two; mapped addresses)

**Two tuple shapes distinguished only by arity** — a 4-tuple is IPv4, an 8-tuple
is IPv6. The *family is implicit in the data*; there is no tag field. This makes
"one type" literal (everything is a tuple) but also means the family is
recovered by pattern matching on size. Source:
<https://www.erlang.org/doc/man/inet.html#parse_address-1>.

IPv4-mapped IPv6 addresses are just 8-tuples starting `{0,0,0,0,0,16#ffff,...}`;
`:inet` provides **no** `is_v4_mapped`/`to_v4` helper — the caller matches the
prefix bytes. (Assessment: derived from RFC 4291; Erlang has no mapped-address
API.)

## 8. Bounds, overflow and validity

Each IPv4 octet must be `0..255` and each IPv6 segment `0..65535` or the parse
returns `{:error, :einval}`. `parse_ipv4_address` rejects a string that has too
few/many groups. There is no separate "out of range" reason — everything is
`:einval`. Sources: `:inet.parse_ipv4_address/1`, `:inet.parse_ipv6_address/1`.

## 9. Classification and arithmetic

Almost **none**. Elixir/Erlang's `:inet` offers no `is_loopback`/`is_private`
predicates on the tuple, and no successor/predecessor. Classification is done by
the caller with pattern matching on the tuple (e.g. `{127, _, _, _}` for
loopback, `{10, _, _, _}`/`{192, 168, _, _}` for private). Source:
<https://www.erlang.org/doc/man/inet.html> (the listed functions are the whole
address API; no predicates are present).

## 10. Interesting design decisions

- **Addresses are plain tagged tuples, not structs.** The data *is* the
  representation; no method surface.
- **Family by arity**, so a single `parse_address` returns either family with no
  wrapper.
- **`{:ok, _}` / `{:error, reason}` everywhere** — the idiomatic BEAM result
  shape, never an exception.
- **Explicit `:pton`/`:ntop` (network bytes)** beside the tuple form, so the
  wire form is a first-class conversion, not an accident.

## 11. Decisions NOT to copy

- **Family by arity / no explicit tag.** Convenient in a dynamically typed
  language, but for Mojo an explicit family discriminant is required for the
  compiler to check usage.
- **`{:error, :einval}` with no detail.** One atom for every failure loses the
  reason and position.
- **No classification predicates at all** — pushing loopback/private tests onto
  every caller (with hand-written patterns) is exactly what a library should
  provide.

## 12. Ideas fitting Mojo

- The **`{ok, value}`/`{error, reason}` result** maps onto Mojo
  `parse() raises ParseError` plus a non-throwing `try_parse() -> Optional`.
- **`pton`/`ntop` as explicit conversions** mirror Mojo's need for
  `from_bytes`/`to_bytes` beside the text form.
- The tuple-of-segments view maps onto a Mojo `Array[UInt16, 8]`/`Array[UInt8, 4]`
  extraction.
- The *absence* of predicates is the strongest argument for shipping them in
  `net_ip` (loopback/private/link-local/multicast/unspecified).

## Sources

- Erlang `:inet` module: <https://www.erlang.org/doc/man/inet.html>
- `:inet.parse_ipv4_address/1`:
  <https://www.erlang.org/doc/man/inet.html#parse_ipv4_address-1>
- `:inet.parse_ipv6_address/1`:
  <https://www.erlang.org/doc/man/inet.html#parse_ipv6_address-1>
- `:inet.parse_address/1`:
  <https://www.erlang.org/doc/man/inet.html#parse_address-1>
- `:inet.ntoa/1`: <https://www.erlang.org/doc/man/inet.html#ntoa-1>
- Erlang data types (tuples, immutability):
  <https://www.erlang.org/doc/reference_manual/data_types.html>
- RFC 4291 (IPv4-mapped addresses): <https://www.rfc-editor.org/rfc/rfc4291>
