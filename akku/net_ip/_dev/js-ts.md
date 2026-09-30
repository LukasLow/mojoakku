# ip research: JS/TS

## 1. Standard library support

JavaScript and TypeScript have **no built-in IP-address type**. `Number` is a
double (53-bit integer precision, so a v6 address is unrepresentable), `BigInt`
is arbitrary precision, and `String` is the only text carrier. There is no
`parseIP`, no `isLoopback`, no address class in any standard (ECMAScript, Node
core `net`/`dns`) — Node's `net.isIPv4`/`isIPv6` are **boolean validators only**
and return no value type. Sources:
<https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>,
<https://nodejs.org/api/net.html#netisipv4input>,
<https://nodejs.org/api/net.html#netisipv6input>.

This is the sharpest "the standard library does nothing" case in the corpus: it
defines the **minimum** an IP library must provide (parse, validate, classify,
format) because nothing is inherited for free.

## 2. Relevant community libraries

- `ipaddr.js` — the most-used JS IP library: `parse`, `process`, `range`,
  `subnetMatch`, with `IPv4`/`IPv6` classes. Source:
  <https://github.com/whitequark/ipaddr.js>.
- `ip-address` — a TypeScript-first implementation with `Address4`/`Address6`,
  `isValid`, `isCorrect`, and CIDR. Source:
  <https://github.com/beaugunderson/ip-address>.
- `@leichtgewicht/ip-codec`, `cidr-tools`, `ip-num` add encoding and range
  handling. (Assessment: the field is crowded precisely because nothing is
  built in.)

## 3. Exposed APIs

`ipaddr.js`:

- `ipaddr.parse(str) -> IPv4 | IPv6`; `ipaddr.process(str)` normalizes
  IPv4-mapped IPv6 to IPv4.
- `IPv4.isValid(str)`, `IPv6.isValid(str)` static validators.
- `ipv4.octets -> number[4]`, `ipv6.parts -> number[8]` (the raw arrays).
- `addr.kind()` → `'ipv4'` | `'ipv6'`.
- `addr.range()` → a classification string (`'loopback'`, `'private'`,
  `'linkLocal'`, `'multicast'`, `'unspecified'`, `'broadcast'`, …).
- `ipaddr.subnetMatch(addr, rangeList, fallback)` — map an address to a named
  group.
- `IPv6.prototype.toIPv4Address()`, `IPv4.prototype.toIPv6Address()`.

Source: <https://github.com/whitequark/ipaddr.js#readme>.

## 4. Error representation

`ipaddr.js` throws an `Error` with a short message (`"ipaddr: the address has
neither a valid IPv4 nor IPv6 format"`). `isValid` gives a non-throwing boolean
path. `ip-address` returns objects with `.isValid()`/`.isCorrect()`. Sources:
<https://github.com/whitequark/ipaddr.js>, <https://github.com/beaugunderson/ip-address>.

## 5. Ownership semantics

`IPv4`/`IPv6` are ordinary JS **objects** — mutable and reference-semantic.
`ip-address`'s `Address4`/`Address6` similarly hold mutable fields. There is no
value semantics; equality is reference equality unless the library defines an
`equals`/`isCorrect` method. Sources: <https://github.com/whitequark/ipaddr.js>,
<https://github.com/beaugunderson/ip-address>.

## 6. Blocking / non-blocking

Pure; no I/O in either library. DNS is Node's `dns` module, separate and
`async`/callback-based. Source: <https://nodejs.org/api/dns.html>.

## 7. Family model (one type or two; mapped addresses)

**Two classes** (`IPv4`, `IPv6`), with `kind()` to distinguish at runtime (the
`instanceof`-style test). Mapped addresses: `ipaddr.js` keeps them in the IPv6
class and offers `process()` / `toIPv4Address()` to normalize explicitly; the
`range()` of an IPv4-mapped address is reported as **`ipv4Mapped`**. Source:
<https://github.com/whitequark/ipaddr.js#readme>.

## 8. Bounds, overflow and validity

Strict parse: `ipaddr.parse('256.1.1.1')` throws. The `Number`-based parts are
safe for 8-bit segments; a v6 address is stored as `number[8]` of 16-bit
segments, so no `BigInt` is required. `ip-address`'s `isCorrect()` adds
"correctness" beyond format (e.g. group count). Sources:
<https://github.com/whitequark/ipaddr.js>, <https://github.com/beaugunderson/ip-address>.

## 9. Classification and arithmetic

`range()` returns a **string** classification (not booleans) — a distinct design
choice. `subnetMatch` maps an address to a caller-named group. There is no
successor/predecessor in `ipaddr.js`; CIDR math lives in `cidr-tools`/`ip-address`.
Source: <https://github.com/whitequark/ipaddr.js#readme>.

## 10. Interesting design decisions

- **Classification as a single `range()` string** instead of a dozen boolean
  predicates — compact, but stringly-typed.
- **A separate `process()` normalizer** for mapped addresses, so the default
  parse is faithful and normalization is opt-in.
- **`number[4]`/`number[8]` raw arrays** as the underlying model (no BigInt),
  which keeps arithmetic in safe-integer range.
- **Validation separated from construction** (`isValid` vs throwing `parse`).

## 11. Decisions NOT to copy

- **Reference-semantic mutable objects.** Mojo's value semantics is the whole
  point; a Mojo address must be a `Copyable` value.
- **Stringly-typed classification.** A Mojo API should expose booleans/`enum`,
  not a `range()` string, so the compiler can check callers.
- **Throwing generic `Error` with no reason/position.** A typed error is better.
- **`instanceof`-style family tests.** Use an explicit family discriminant.

## 12. Ideas fitting Mojo

- The `range()` idea, converted to a **closed set of predicates** (or a small
  `enum`), is a clean Mojo classification API.
- `toIPv4Address()`/`process()` validate the explicit mapped-address operations
  the Mojo design should offer.
- `number[8]` as the v6 model maps onto Mojo `Array[UInt16, 8]` or `UInt128`
  segments.
- `isValid` (non-throwing) beside `parse` (throwing) maps onto Mojo
  `is_valid(text) -> Bool` beside `parse(text) raises ParseError` — the same
  split used in `akku.codec_base64`.

## Sources

- ECMAScript `BigInt`:
  <https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/BigInt>
- Node `net.isIPv4`: <https://nodejs.org/api/net.html#netisipv4input>
- Node `net.isIPv6`: <https://nodejs.org/api/net.html#netisipv6input>
- Node `dns`: <https://nodejs.org/api/dns.html>
- `ipaddr.js`: <https://github.com/whitequark/ipaddr.js>
- `ip-address`: <https://github.com/beaugunderson/ip-address>
