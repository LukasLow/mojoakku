# ip research: Java

## 1. Standard library support

Java's address type is **`java.net.InetAddress`** (since JDK 1.0), with
subclasses `Inet4Address` and `Inet6Address`. It models a **host** as much as an
address: `InetAddress.getByName(String)` "determines the IP address of a host,
given the host's name" and performs **DNS**, while the constructor path is
deprecated. Sources:
<https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/InetAddress.html>,
<https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/Inet4Address.html>,
<https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/Inet6Address.html>.

Since Java 16, `InetAddress` also offers `ofLiteral(String)` /
`Inet4Address.ofLiteral` / `Inet6Address.ofLiteral`, which **do not resolve DNS**
and parse only numeric literals — a deliberate separation added late. Source:
<https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/InetAddress.html#ofLiteral(java.lang.String)>.

## 2. Relevant community libraries

- Guava `com.google.common.net.InetAddresses` — `forString`, `isInetAddress`,
  `toAddrString`, `toUriString`, `isLoopbackAddress`, `isPrivateAddress`.
  Source:
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/net/InetAddresses.html>.
- Apache Commons Net `SubnetUtils` — IPv4 CIDR math. Source:
  <https://commons.apache.org/proper/commons-net/apidocs/org/apache/commons/net/util/SubnetUtils.html>.

## 3. Exposed APIs

`InetAddress`:

- `getByName(String)` (DNS), `getAllByName(String)`, `getLocalHost()`.
- `ofLiteral(String)` (numeric only, no DNS) — the modern parse entry.
- `getHostAddress() -> String` — the textual IP; **overloaded meaning** with
  `getHostName()` (reverse DNS).
- `isLoopbackAddress()`, `isAnyLocalAddress()`, `isMulticastAddress()`,
  `isLinkLocalAddress()`, `isSiteLocalAddress()`, `isMCGlobal()`, ….
- `getAddress() -> byte[]` — the raw bytes (4 or 16).
- `equals`/`hashCode` are defined *against the resolved address*, so two
  `InetAddress` for the same IP from different lookups can compare equal.

Sources: the `InetAddress`/`Inet4Address`/`Inet6Address` javadoc above.

## 4. Error representation

Checked exception **`UnknownHostException`** — thrown by `getByName` when the
name cannot be resolved. `ofLiteral` throws `IllegalArgumentException` for a
malformed literal. So the failure *type* is overloaded: "the name is unknown"
and "the literal is invalid" arrive through different channels. Sources:
`InetAddress` javadoc (`getByName`, `ofLiteral`).

## 5. Ownership semantics

`InetAddress` is an **immutable object** ("An immutable object" — instances are
serializable and the byte array from `getAddress()` is a defensive copy).
Equality and hashing are defined, so it is usable as a map key. Source:
<https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/InetAddress.html>.

## 6. Blocking / non-blocking

**`getByName` can block** (DNS / reverse lookup). `ofLiteral` and
`getHostAddress` do not. `getHostName()` may trigger a reverse lookup and block.
Sources: `InetAddress` javadoc.

## 7. Family model (one type or two; mapped addresses)

**One parent type with two subclasses** (`Inet4Address`, `Inet6Address`) and a
runtime `instanceof` test; there is no `enum` discriminant. Mapped addresses:
`Inet6Address` can hold an IPv4-mapped address; Java offers
`InetAddress.getByAddress(byte[])` and, since 16, `Inet6Address.ofLiteral`.
There is no public `map`/`unmap` helper (you convert via `getAddress().length`
and `InetAddress.getByAddress`). Sources: `Inet4Address`/`Inet6Address` javadoc.

## 8. Bounds, overflow and validity

`getAddress()` returns a **fresh 4- or 16-byte array**; length is the family
signal. Numeric range errors surface as `IllegalArgumentException` from
`ofLiteral`/`getByAddress` (e.g. an array of the wrong length). Source:
`InetAddress` javadoc (`getByAddress`, `ofLiteral`).

## 9. Classification and arithmetic

The predicate set is broad but **host-oriented**: `isLoopbackAddress`,
`isAnyLocalAddress`, `isMulticastAddress`, `isLinkLocalAddress`,
`isSiteLocalAddress`, and the multicast scope tests (`isMCGlobal`,
`isMCOrgLocal`, …). There is **no arithmetic** (no successor/predecessor, no
bitwise ops) and no CIDR math in the JDK. Sources: `InetAddress` javadoc;
Commons Net for CIDR.

## 10. Interesting design decisions

- **The host/address conflation**, and its late correction: `ofLiteral` (Java
  16) exists because `getByName` doing DNS was a long-standing footgun.
- **`getHostAddress()` vs `getHostName()`** as two distinct string operations
  (numeric vs reverse-DNS), an explicit separation of address text from name.
- **`equals`/`hashCode` against the resolved bytes**, so addresses from different
  lookups unify — convenient, but couples equality to resolution.
- **Broad but host-flavoured predicates** (`isSiteLocalAddress` rather than
  `isPrivate`).

## 11. Decisions NOT to copy

- **A DNS-resolving constructor/`getByName` as the primary parse.** This is the
  central anti-pattern for `net_ip`: a pure address parser must never touch DNS.
- **Checked `UnknownHostException` on a literal parse.** Conflates resolution
  failure with syntax failure.
- **`instanceof`-based family dispatch.** Use an explicit family discriminant.
- **Host-oriented naming** (`isSiteLocalAddress`, host name accessors) on the
  address type.

## 12. Ideas fitting Mojo

- The **`ofLiteral` separation** validates the Mojo split: `parse` is pure
  numeric text → address, with resolution kept out entirely.
- `getAddress() -> byte[]` maps onto a Mojo `Array[UInt8, N]`/`Span` extraction.
- The predicate set is a useful checklist, but Mojo should name predicates by
  RFC (private/link-local/multicast/unspecified/loopback) rather than by site
  scope.
- Java's late `map`/`unmap` gap argues for exposing the mapped-address
  operations explicitly in the Mojo design (Go/Rust style).

## Sources

- `java.net.InetAddress`:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/InetAddress.html>
- `java.net.Inet4Address`:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/Inet4Address.html>
- `java.net.Inet6Address`:
  <https://docs.oracle.com/en/java/javase/17/docs/api/java.base/java/net/Inet6Address.html>
- Guava `InetAddresses`:
  <https://guava.dev/releases/snapshot-jre/api/docs/com/google/common/net/InetAddresses.html>
- Commons Net `SubnetUtils`:
  <https://commons.apache.org/proper/commons-net/apidocs/org/apache/commons/net/util/SubnetUtils.html>
